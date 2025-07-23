#!/bin/bash

# app_build_and_verification.sh
# This script automates the end-to-end build, test, and deployment verification
# for the Key Server Application. It covers:
# 1. Local Go application build and API tests.
# 2. Docker image build and containerized API tests.
# 3. Kind Kubernetes cluster setup.
# 4. Deployment of Prometheus and Grafana monitoring stack.
# 5. Deployment of the Key Server application via Helm.
# 6. API tests against the Key Server deployed in Kubernetes.
# 7. Verification of Prometheus metrics scraping.

# --- Configuration ---
APP_NAME="key-server"
APP_DIR="." # Current directory for Go app
HELM_CHART_PATH="./deploy/kubernetes/key-server-chart"
KIND_CLUSTER_NAME="key-server"
PROMETHEUS_NAMESPACE="prometheus-operator"
APP_NAMESPACE="default" # Namespace for the Key Server app
APP_PORT="8443"
MAX_KEY_SIZE="64"
TLS_CERT_FILE="./certs/server.crt"
TLS_KEY_FILE="./certs/server.key"

# --- Colors for better output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---

log_step() {
  echo -e "\n${BLUE}[STEP]${NC} $1"
}

log_info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to wait for a pod to be ready by checking its conditions
wait_for_pod_ready() {
  local namespace=$1
  local name_label_value=$2 # This is the value for app.kubernetes.io/name
  local timeout=${3:-300} # Default to 300 seconds (5 minutes)
  local interval=5 # Check every 5 seconds
  local elapsed=0
  local pod_found_and_ready=false
  local last_checked_pod_name=""

  log_info "   Waiting for pod in namespace '$namespace' with label 'app.kubernetes.io/name=${name_label_value}' to be Ready (timeout: ${timeout}s)..."

  while [ ${elapsed} -lt ${timeout} ]; do
    # Get all pod names matching the label
    # Using '|| true' to prevent script from exiting if kubectl command fails temporarily
    POD_NAMES=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=${name_label_value}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

    if [ -z "$POD_NAMES" ]; then
      log_info "   No pods found with label 'app.kubernetes.io/name=${name_label_value}' yet. Retrying in ${interval}s..."
      sleep "${interval}"
      elapsed=$((elapsed + interval))
      continue
    fi

    pod_found_and_ready=false
    for P_NAME in ${POD_NAMES}; do
      last_checked_pod_name="$P_NAME" # Keep track of the last pod name checked

      # Check if the pod is running and ready
      # Using '|| echo "Unknown"' to handle cases where jsonpath might fail
      CURRENT_STATUS=$(kubectl get pod "$P_NAME" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
      READY_STATUS=$(kubectl get pod "$P_NAME" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
      
      # Count ready containers vs total containers
      # Using '|| echo "0"' for safety
      CONTAINERS_READY=$(kubectl get pod "$P_NAME" -n "$namespace" -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null | grep -o 'true' | wc -l || echo "0")
      TOTAL_CONTAINERS=$(kubectl get pod "$P_NAME" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | wc -w || echo "0")

      if [[ "$CURRENT_STATUS" == "Running" && "$READY_STATUS" == "True" && "$CONTAINERS_READY" -gt 0 && "$CONTAINERS_READY" -eq "$TOTAL_CONTAINERS" ]]; then
        log_success "   Pod '${P_NAME}' is Running and Ready."
        pod_found_and_ready=true
        break # Exit inner loop, found a ready pod
      else
        log_info "   Pod '${P_NAME}' not yet fully Ready. Status: ${CURRENT_STATUS}, Ready Condition: ${READY_STATUS} (Containers Ready: ${CONTAINERS_READY}/${TOTAL_CONTAINERS})."
      fi
    done

    if ${pod_found_and_ready}; then
      return 0 # A ready pod was found
    else
      log_info "   Still waiting for pods with label 'app.kubernetes.io/name=${name_label_value}'. Retrying in ${interval}s..."
      sleep "${interval}"
      elapsed=$((elapsed + interval))
    fi
  done

  log_error "   Pod with label 'app.kubernetes.io/name=${name_label_value}' did NOT become ready within ${timeout} seconds."
  log_info "   Current pods in ${namespace}:"
  kubectl get pods -n "$namespace" -o wide
  if [ -n "$last_checked_pod_name" ]; then # If we at least found a pod name, describe it
    log_info "   Describing problematic pod '${last_checked_pod_name}':"
    kubectl describe pod "$last_checked_pod_name" -n "$namespace"
  else
    log_info "   No specific pod name to describe as none were found or became ready."
  fi
  return 1
}


# Function to run API tests
run_api_tests() {
  local app_url=$1
  local test_name=$2
  local test_failed_local=false # Use a local flag for this function's result

  log_info "Testing POSITIVE API endpoints for ${test_name} at ${app_url}..."

  # Test /health endpoint
  log_info "   Testing /health endpoint..."
  HEALTH_RESPONSE=$(curl -k -s "${app_url}/health")
  CURL_STATUS=$?
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /health endpoint (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  elif [[ "${HEALTH_RESPONSE}" == "Healthy" ]]; then
    log_success "   /health endpoint is Healthy."
  else
    log_error "   /health endpoint FAILED for ${test_name}. Response: '${HEALTH_RESPONSE}'"
    test_failed_local=true
  fi

  # Test /ready endpoint
  log_info "   Testing /ready endpoint..."
  READY_RESPONSE=$(curl -k -s "${app_url}/ready")
  CURL_STATUS=$?
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /ready endpoint (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  elif [[ "${READY_RESPONSE}" == "Ready to serve traffic!" ]]; then
    log_success "   /ready endpoint is Ready."
  else
    log_error "   /ready endpoint FAILED for ${test_name}. Response: '${READY_RESPONSE}'"
    test_failed_local=true
  fi

  # Test /key/32 endpoint (Positive)
  log_info "   Testing /key/32 endpoint..."
  KEY_RESPONSE=$(curl -k -s "${app_url}/key/32")
  CURL_STATUS=$?
  log_info "   Raw /key/32 response: '${KEY_RESPONSE}'" # DEBUG
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /key/32 endpoint (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  else
    KEY_VALUE=$(echo "${KEY_RESPONSE}" | jq -r '.key // empty' 2>/dev/null) # Redirect stderr for jq errors
    JQ_STATUS=$?
    log_info "   jq exit status for /key/32: ${JQ_STATUS}" # DEBUG
    log_info "   Extracted /key/32 key value: '${KEY_VALUE}'" # DEBUG
    if [ ${JQ_STATUS} -ne 0 ]; then
      log_error "   jq failed to parse JSON for /key/32. Response: '${KEY_RESPONSE}'"
      test_failed_local=true
    elif [[ -n "${KEY_VALUE}" ]]; then # Check if the extracted key value is non-empty
      log_success "   /key/32 endpoint returned a valid key."
    else
      log_error "   /key/32 endpoint FAILED to return a valid key for ${test_name}. Response: '${KEY_VALUE}'"
      test_failed_local=true
    fi
  fi

  # Test /key/1 endpoint (Positive)
  log_info "   Testing /key/1 endpoint..."
  KEY_RESPONSE_1=$(curl -k -s "${app_url}/key/1")
  CURL_STATUS=$?
  log_info "   Raw /key/1 response: '${KEY_RESPONSE_1}'" # DEBUG
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /key/1 endpoint (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  else
    KEY_VALUE_1=$(echo "${KEY_RESPONSE_1}" | jq -r '.key // empty' 2>/dev/null) # Redirect stderr for jq errors
    JQ_STATUS=$?
    log_info "   jq exit status for /key/1: ${JQ_STATUS}" # DEBUG
    log_info "   Extracted /key/1 key value: '${KEY_VALUE_1}'" # DEBUG
    if [ ${JQ_STATUS} -ne 0 ]; then
      log_error "   jq failed to parse JSON for /key/1. Response: '${KEY_RESPONSE_1}'"
      test_failed_local=true
    elif [[ -n "${KEY_VALUE_1}" ]]; then # Check if the extracted key value is non-empty
      log_success "   /key/1 endpoint returned a valid key."
    else
      log_error "   /key/1 endpoint FAILED to return a valid key for ${test_name}. Response: '${KEY_VALUE_1}'"
      test_failed_local=true
    fi
  fi

  log_info "Testing NEGATIVE API endpoints for ${test_name}..."

  # Test /key/abc (Invalid length type)
  log_info "   Testing /key/abc (invalid length type)..."
  INVALID_LENGTH_RESPONSE_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${app_url}/key/abc")
  CURL_STATUS=$?
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /key/abc (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  elif [[ "${INVALID_LENGTH_RESPONSE_CODE}" == "400" ]]; then
    log_success "   /key/abc returned 400 Bad Request as expected."
  else
    log_error "   /key/abc FAILED for ${test_name}. Expected 400, got ${INVALID_LENGTH_RESPONSE_CODE}"
    test_failed_local=true
  fi

  # Test /key/0 (Length out of range)
  log_info "   Testing /key/0 (length out of range)..."
  ZERO_LENGTH_RESPONSE_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${app_url}/key/0")
  CURL_STATUS=$?
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /key/0 (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  elif [[ "${ZERO_LENGTH_RESPONSE_CODE}" == "400" ]]; then
    log_success "   /key/0 returned 400 Bad Request as expected."
  else
    log_error "   /key/0 FAILED for ${test_name}. Expected 400, got ${ZERO_LENGTH_RESPONSE_CODE}"
    test_failed_local=true
  fi

  # Test /key/oversized (Length exceeds MAX_KEY_SIZE)
  log_info "   Testing /key/$((${MAX_KEY_SIZE} + 1)) (length exceeds max)..."
  OVERSIZED_KEY_RESPONSE_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "${app_url}/key/$((${MAX_KEY_SIZE} + 1))")
  CURL_STATUS=$?
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for /key/oversized (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  elif [[ "${OVERSIZED_KEY_RESPONSE_CODE}" == "400" ]]; then
    log_success "   /key/$((${MAX_KEY_SIZE} + 1)) returned 400 Bad Request as expected."
  else
    log_error "   /key/$((${MAX_KEY_SIZE} + 1)) FAILED for ${test_name}. Expected 400, got ${OVERSIZED_KEY_RESPONSE_CODE}"
    test_failed_local=true
  fi

  # Test unsupported method (e.g., POST to /key/32)
  log_info "   Testing POST /key/32 (unsupported method)..."
  UNSUPPORTED_METHOD_RESPONSE_CODE=$(curl -k -s -X POST -o /dev/null -w "%{http_code}" "${app_url}/key/32")
  CURL_STATUS=$?
  if [ ${CURL_STATUS} -ne 0 ]; then
    log_error "   Curl command failed for POST /key/32 (${test_name}). Status: ${CURL_STATUS}"
    test_failed_local=true
  elif [[ "${UNSUPPORTED_METHOD_RESPONSE_CODE}" == "405" ]]; then
    log_success "   POST /key/32 returned 405 Method Not Allowed as expected."
  else
    log_error "   POST /key/32 FAILED for ${test_name}. Expected 405, got ${UNSUPPORTED_METHOD_RESPONSE_CODE}"
    test_failed_local=true
  fi


  if ${test_failed_local}; then
    log_error "${test_name} API tests FAILED."
    return 1 # Indicate failure
  else
    log_success "${test_name} API tests PASSED."
    return 0 # Indicate success
  fi
}

# --- Cleanup Function ---
cleanup_k8s_env() {
  log_step "Cleaning up Kubernetes environment..."
  log_info "Deleting Kind cluster '${KIND_CLUSTER_NAME}' (if it exists)..."
  if kind get clusters | grep -q "${KIND_CLUSTER_NAME}"; then
    kind delete cluster --name "${KIND_CLUSTER_NAME}" || log_error "Failed to delete Kind cluster."
  else
    log_info "Kind cluster '${KIND_CLUSTER_NAME}' does not exist, skipping deletion."
  fi

  log_info "Deleting Prometheus namespace '${PROMETHEUS_NAMESPACE}' (if it exists)..."
  if kubectl get namespace "${PROMETHEUS_NAMESPACE}" &>/dev/null; then
    kubectl delete namespace "${PROMETHEUS_NAMESPACE}" --wait=false || log_error "Failed to delete Prometheus namespace."
    log_info "Waiting for Prometheus namespace to terminate..."
    # Give it some time, but don't block indefinitely if it hangs
    timeout 120s bash -c "while kubectl get namespace ${PROMETHEUS_NAMESPACE} &>/dev/null; do sleep 5; done"
  else
    log_info "Prometheus namespace '${PROMETHEUS_NAMESPACE}' does not exist, skipping deletion."
  fi

  log_info "Deleting any remaining grafana-admin-secret..."
  kubectl delete secret grafana-admin-secret -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true

  log_info "Deleting any remaining key-server-http-overview-dashboard..."
  kubectl delete configmap key-server-http-overview-dashboard -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true

  log_info "Deleting any remaining key-server-key-generation-dashboard..."
  kubectl delete configmap key-server-key-generation-dashboard -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true

  log_info "Deleting any remaining grafana-custom-dashboards-provisioning..."
  kubectl delete configmap grafana-custom-dashboards-provisioning -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true

  log_info "Cleaning up temporary Helm values file..."
  rm -f temp_prometheus_values.yaml

  log_success "Kubernetes environment cleanup initiated."
}


# --- Main Script Execution ---

# Initialize global failure flag
TEST_FAILED=false

# Always clean up at the start to ensure a fresh environment
cleanup_k8s_env


# --- Pre-checks ---
log_step "Performing pre-checks..."
command_exists go || { log_error "Go is not installed."; exit 1; }
command_exists docker || { log_error "Docker is not installed or not in PATH."; exit 1; }
command_exists kubectl || { log_error "kubectl is not installed or not in PATH."; exit 1; }
command_exists helm || { log_error "Helm is not installed or not in PATH."; exit 1; }
command_exists jq || { log_error "jq is not installed. Please install it (e.g., 'sudo apt-get install jq' or 'brew install jq')."; exit 1; }
command_exists curl || { log_error "curl is not installed. Please install it."; exit 1; }
log_success "All required tools are installed."

# --- Initial Setup Script ---
log_step "Running initial setup script (dev-setup.sh)..."
if [ ! -f "./dev-setup.sh" ]; then
  log_error "dev-setup.sh not found. Please ensure it exists in the current directory."
  exit 1
fi
source "./dev-setup.sh" || { log_error "Failed to source dev-setup.sh."; exit 1; }
log_success "dev-setup.sh sourced successfully."

# --- Kubernetes Environment Setup ---
log_step "Starting Kubernetes environment setup and application deployment..."

log_info "Creating Kind cluster named '${KIND_CLUSTER_NAME}'..."
if ! kind get clusters | grep -q "${KIND_CLUSTER_NAME}"; then
  kind create cluster --name "${KIND_CLUSTER_NAME}" || { log_error "Failed to create Kind cluster."; exit 1; }
else
  log_info "Kind cluster '${KIND_CLUSTER_NAME}' already exists."
fi
log_success "Kind cluster '${KIND_CLUSTER_NAME}' created."

log_info "Setting kubectl context to '${KIND_CLUSTER_NAME}'..."
kubectl config use-context "kind-${KIND_CLUSTER_NAME}" || { log_error "Failed to set kubectl context."; exit 1; }
log_success "kubectl context set to 'kind-${KIND_CLUSTER_NAME}'."

log_info "Current kubectl context: $(kubectl config current-context)"
log_info "Attempting to get Kubernetes cluster info (this should NOT show localhost:8080 if context is correct):"
kubectl cluster-info || { log_error "Failed to get cluster info. Is Kubernetes running?"; exit 1; }

log_info "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || { log_error "Failed to add Helm repo."; exit 1; }
helm repo update || { log_error "Failed to update Helm repos."; exit 1; }
log_success "Helm repositories added and updated."

read -s -p "Enter a secure password for Grafana admin user: " GRAFANA_ADMIN_PASSWORD
echo # Newline after password input

log_info "Creating Kubernetes Secret for Grafana admin password..."
kubectl create namespace "${PROMETHEUS_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true # Ensure namespace exists
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
  --namespace "${PROMETHEUS_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - || { log_error "Failed to create Grafana admin secret."; exit 1; }
log_success "Grafana admin secret 'grafana-admin-secret' created."

# --- Grafana Dashboard and Data Source Provisioning ---
log_step "Creating Grafana Dashboard JSON ConfigMaps..."
# HTTP Overview Dashboard
kubectl create configmap key-server-http-overview-dashboard \
  --from-file=dashboards/http-overview.json \
  --namespace="${PROMETHEUS_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - || { log_error "Failed to create HTTP overview dashboard ConfigMap."; exit 1; }
log_success "HTTP overview dashboard ConfigMap created."

# Key Generation Dashboard
kubectl create configmap key-server-key-generation-dashboard \
  --from-file=dashboards/key-generation.json \
  --namespace="${PROMETHEUS_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - || { log_error "Failed to create Key Generation dashboard ConfigMap."; exit 1; }
log_success "Key Generation dashboard ConfigMap created."

log_step "Creating Grafana Dashboard Provisioning Configuration ConfigMap..."
# Grafana Dashboard Provisioning ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-custom-dashboards-provisioning
  namespace: ${PROMETHEUS_NAMESPACE}
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
      - name: 'Key Server'
        orgId: 1
        folder: 'Key Server'
        type: file
        disableDelete: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/key-server
EOF
if [ $? -ne 0 ]; then log_error "Failed to create Grafana Dashboard Provisioning Configuration ConfigMap."; exit 1; fi
log_success "Grafana Dashboard Provisioning Configuration ConfigMap created."

log_info "Adding a short delay for ConfigMap propagation and cleanup..."
sleep 5

log_info "Installing kube-prometheus-stack Helm chart (configured for direct dashboard provisioning and cross-namespace ServiceMonitor discovery)..."

# Create a temporary values file for kube-prometheus-stack
TEMP_PROM_VALUES_FILE="temp_prometheus_values.yaml"
cat <<EOF > "${TEMP_PROM_VALUES_FILE}"
grafana:
  admin:
    user: admin
    password: "${GRAFANA_ADMIN_PASSWORD}" # Directly set password for simplicity in this script
  dashboardProviders:
    dashboardProviders:
      default:
        disableDelete: false
        editable: true
  dashboards:
    custom:
      key-server:
        enabled: true
        folder: Key Server
        label: Key Server
        configMaps:
          - configMapName: key-server-http-overview-dashboard
            configMapNamespace: ${PROMETHEUS_NAMESPACE}
          - configMapName: key-server-key-generation-dashboard
            configMapNamespace: ${PROMETHEUS_NAMESPACE}
  grafana.ini:
    server:
      http_port: 3000
      root_url: "%(protocol)s://%(domain)s:%(http_port)s/"
    auth.anonymous:
      enabled: true
      org_name: Main Org.
      org_role: Viewer
    users:
      allow_sign_up: false
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector:
      matchLabels:
        app.kubernetes.io/name: key-server-app # This should match the ServiceMonitor for our app
    serviceMonitorNamespaceSelector:
      matchNames:
        - ${APP_NAMESPACE}
        - ${PROMETHEUS_NAMESPACE}
    ruleSelectorNilUsesHelmValues: false
EOF

helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "${PROMETHEUS_NAMESPACE}" \
  -f "${TEMP_PROM_VALUES_FILE}" \
  --wait --timeout 10m || { log_error "Failed to deploy Prometheus stack."; rm -f "${TEMP_PROM_VALUES_FILE}"; exit 1; }
log_success "Prometheus stack deployed successfully."
rm -f "${TEMP_PROM_VALUES_FILE}" # Clean up the temporary file

log_info "Waiting for Prometheus Operator pod to be scheduled and ready..."
# Corrected label for Prometheus Operator based on user's jsonpath output
wait_for_pod_ready "${PROMETHEUS_NAMESPACE}" "kube-prometheus-stack-prometheus-operator" || { log_error "Prometheus Operator not ready."; exit 1; }
log_success "Prometheus Operator pod is ready."

log_info "Waiting for remaining monitoring stack pods to be ready..."
# Corrected label for Prometheus Server (confirmed from previous output)
wait_for_pod_ready "${PROMETHEUS_NAMESPACE}" "prometheus" || { log_error "Prometheus Server not ready."; exit 1; }
# Corrected label for Grafana (confirmed from previous output)
wait_for_pod_ready "${PROMETHEUS_NAMESPACE}" "grafana" || { log_error "Grafana not ready."; exit 1; }
log_success "Remaining monitoring stack pods are ready."


# --- Build and Test Local Go Application ---
log_step "Building and testing local Go application..."
(
  cd "${APP_DIR}" || exit 1 # Exit subshell if cd fails
  go build -o "./${APP_NAME}" || exit 1 # Exit subshell if build fails
  log_success "Go application binary built: ./key-server"

  log_info "Running Go unit tests..."
  go test ./... || exit 1 # Exit subshell if tests fail
  log_success "Go unit tests passed."

  log_info "Starting local Go application in background for API tests..."
  mkdir -p certs
  PORT=${APP_PORT} MAX_KEY_SIZE=${MAX_KEY_SIZE} TLS_CERT_FILE=${TLS_CERT_FILE} TLS_KEY_FILE=${TLS_KEY_FILE} ./"${APP_NAME}" > app_local_run.log 2>&1 &
  LOCAL_APP_PID=$!
  log_info "Local Go application started with PID: ${LOCAL_APP_PID}. Logs redirected to app_local_run.log"
  sleep 10
  log_info "Proceeding with API tests after 10 seconds startup delay."

  run_api_tests "https://localhost:${APP_PORT}" "Local Go App" || exit 1 # Exit subshell if API tests fail

  log_info "Stopping local Go application (PID: ${LOCAL_APP_PID})..."
  kill "${LOCAL_APP_PID}"
  wait "${LOCAL_APP_PID}" 2>/dev/null
  log_success "Local Go application stopped."
)
if [ $? -ne 0 ]; then # Check exit code of the subshell
  log_error "Local Go application build/test phase FAILED."
  TEST_FAILED=true
else
  log_success "Local Go application build/test phase PASSED."
fi


# --- Build and Test Docker Image ---
log_step "Building and testing Docker image..."
(
  log_info "Building Docker image '${APP_NAME}'..."
  docker build -t "${APP_NAME}" "${APP_DIR}" || exit 1 # Exit subshell if build fails
  log_success "Docker image '${APP_NAME}' built."

  log_info "Running Docker container in background for API tests..."
  docker run -d --rm --name "${APP_NAME}-container" \
    -p "${APP_PORT}:${APP_PORT}" \
    -v "$(pwd)/certs:/etc/key-server/tls" \
    -e PORT="${APP_PORT}" \
    -e MAX_KEY_SIZE="${MAX_KEY_SIZE}" \
    -e TLS_CERT_FILE="/etc/key-server/tls/server.crt" \
    -e TLS_KEY_FILE="/etc/key-server/tls/server.key" \
    "${APP_NAME}" > docker_container_run.log 2>&1 || exit 1 # Exit subshell if run fails
  log_info "Docker container '${APP_NAME}-container' started. Logs redirected to docker_container_run.log"
  sleep 10
  log_info "Proceeding with API tests after 10 seconds startup delay."

  run_api_tests "https://localhost:${APP_PORT}" "Docker Container" || exit 1 # Exit subshell if API tests fail

  log_info "Stopping Docker container '${APP_NAME}-container'..."
  docker stop "${APP_NAME}-container" >/dev/null || true # Stop and ignore if already stopped
  log_success "Docker container stopped."
)
if [ $? -ne 0 ]; then
  log_error "Docker image build/test phase FAILED."
  TEST_FAILED=true
else
  log_success "Docker image build/test phase PASSED."
fi


# --- Load Docker Image into Kind Cluster ---
log_step "Loading Docker image into Kind cluster..."
kind load docker-image "${APP_NAME}" --name "${KIND_CLUSTER_NAME}" || { log_error "Failed to load Docker image into Kind."; exit 1; }
log_success "Docker image loaded into Kind cluster."


# --- Deploy Key Server Application to Kubernetes ---
log_step "Deploying Key Server Application to Kubernetes via Helm..."

log_info "Creating Kubernetes TLS secret for Key Server application..."
kubectl create secret tls key-server-key-server-app-tls-secret \
  --cert="${TLS_CERT_FILE}" \
  --key="${TLS_KEY_FILE}" \
  --namespace "${APP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - || { log_error "Failed to create TLS secret."; exit 1; }
log_success "Kubernetes TLS secret created."

log_info "Installing Key Server Helm chart..."
helm upgrade --install "${APP_NAME}" "${HELM_CHART_PATH}" \
  --namespace "${APP_NAMESPACE}" \
  --set image.repository="${APP_NAME}" \
  --set image.tag="latest" \
  --set service.type=NodePort \
  --set ingress.enabled=true \
  --set "ingress.tls[0].secretName=key-server-key-server-app-tls-secret" \
  --set "ingress.host=key-server.local" \
  --set config.maxKeySize="${MAX_KEY_SIZE}" \
  --set service.port="${APP_PORT}" \
  --set service.targetPort="${APP_PORT}" \
  --wait --timeout 5m || { log_error "Failed to deploy Key Server Helm chart."; exit 1; }
log_success "Key Server Helm chart deployed successfully."

log_info "Waiting for Key Server application pods to be ready..."
wait_for_pod_ready "${APP_NAMESPACE}" "${APP_NAME}-app" || { log_error "Key Server application pods not ready."; exit 1; }
log_success "Key Server application pods are ready."


# --- Test Key Server Application in Kubernetes ---
log_step "Testing Key Server Application deployed in Kubernetes..."
(
  log_info "Establishing kubectl port-forward to Key Server service (https://localhost:${APP_PORT})..."
  APP_SVC_NAME=$(kubectl get svc -n "${APP_NAMESPACE}" -l "app.kubernetes.io/name=${APP_NAME}-app" -o jsonpath='{.items[0].metadata.name}')
  if [ -z "${APP_SVC_NAME}" ]; then
    log_error "Could not find Key Server service in namespace ${APP_NAMESPACE}. Skipping Kubernetes API tests."
    exit 1 # Exit subshell
  fi
  kubectl port-forward svc/"${APP_SVC_NAME}" "${APP_PORT}:${APP_PORT}" -n "${APP_NAMESPACE}" > /dev/null 2>&1 &
  K8S_PF_PID=$!
  sleep 10
  log_info "kubectl port-forward established (PID: ${K8S_PF_PID})."

  run_api_tests "https://localhost:${APP_PORT}" "Kubernetes Deployment" || exit 1 # Exit subshell if API tests fail

  log_info "Stopping kubectl port-forward (PID: ${K8S_PF_PID})..."
  kill "${K8S_PF_PID}"
  wait "${K8S_PF_PID}" 2>/dev/null
  log_success "kubectl port-forward stopped."
)
if [ $? -ne 0 ]; then
  log_error "Kubernetes Deployment API tests FAILED."
  TEST_FAILED=true
else
  log_success "Kubernetes Deployment API tests PASSED."
fi


# --- Verify Prometheus Metrics Scraping ---
log_step "Verifying Prometheus metrics scraping..."
(
  log_info "Establishing kubectl port-forward to Prometheus UI (http://localhost:9090)..."
  # Directly use the known Prometheus service name
  PROMETHEUS_SVC_NAME="prometheus-stack-kube-prom-prometheus"
  if ! kubectl get svc "${PROMETHEUS_SVC_NAME}" -n "${PROMETHEUS_NAMESPACE}" &>/dev/null; then
    log_error "Prometheus service '${PROMETHEUS_SVC_NAME}' not found in namespace ${PROMETHEUS_NAMESPACE}. Cannot verify metrics scraping."
    log_info "Listing all services in ${PROMETHEUS_NAMESPACE} for debugging:"
    kubectl get svc -n "${PROMETHEUS_NAMESPACE}" -o wide
    exit 1 # Exit subshell
  fi
  log_info "Found Prometheus service: ${PROMETHEUS_SVC_NAME}"
  kubectl port-forward svc/"${PROMETHEUS_SVC_NAME}" 9090:9090 -n "${PROMETHEUS_NAMESPACE}" > /dev/null 2>&1 &
  PROM_PF_PID=$!
  sleep 10 # Give port-forward time to establish
  log_info "kubectl port-forward to Prometheus established (PID: ${PROM_PF_PID})."

  log_info "Querying Prometheus for 'up' status of Key Server target..."
  # Wait for Prometheus to scrape the target
  MAX_RETRIES=10
  RETRY_COUNT=0
  SCRAPE_SUCCESS=false
  while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
    TARGET_STATUS=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets[] | select(.labels.job | contains("key-server-app")) | .health')
    if [[ "${TARGET_STATUS}" == "up" ]]; then
      log_success "Key Server Prometheus target is UP."
      SCRAPE_SUCCESS=true
      break
    else
      log_info "   Target not yet 'up', retrying... (${RETRY_COUNT}/${MAX_RETRIES}) Status: ${TARGET_STATUS}"
      sleep 10 # Wait for 10 seconds before retrying
      RETRY_COUNT=$((RETRY_COUNT+1))
    fi
  done

  if ! ${SCRAPE_SUCCESS}; then
    log_error "Key Server Prometheus target did not come UP within the expected time."
    exit 1 # Exit subshell
  fi

  log_info "Querying Prometheus for 'key_generations_total' metric..."
  KEY_GEN_METRIC=$(curl -s "http://localhost:9090/api/v1/query?query=key_generations_total%7Bjob%3D%22key-server-key-server-app%22%7D" | jq -r '.data.result[0].value[1] // "0"')
  if [[ "${KEY_GEN_METRIC}" -ge 1 ]]; then
    log_success "Prometheus is collecting 'key_generations_total' metrics (Value: ${KEY_GEN_METRIC})."
  else
    log_error "Prometheus is NOT collecting 'key_generations_total' metrics as expected (Value: ${KEY_GEN_METRIC})."
    exit 1 # Exit subshell
  fi

  log_info "Stopping kubectl port-forward to Prometheus (PID: ${PROM_PF_PID})..."
  kill "${PROM_PF_PID}"
  wait "${PROM_PF_PID}" 2>/dev/null
  log_success "kubectl port-forward to Prometheus stopped."
)
if [ $? -ne 0 ]; then
  log_error "Prometheus metrics scraping verification FAILED."
  TEST_FAILED=true
else
  log_success "Prometheus metrics scraping verification PASSED."
fi


# --- Final Result ---
log_info "DEBUG: Value of TEST_FAILED before final check: ${TEST_FAILED}"
if ${TEST_FAILED}; then
  log_step "${RED}--- END-TO-END VERIFICATION FAILED ---${NC}"
  exit 1
else
  log_step "${GREEN}--- END-TO-END VERIFICATION PASSED ---${NC}"
  exit 0
fi
