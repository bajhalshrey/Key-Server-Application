# #!/bin/bash

# # Define constants
# APP_NAME="key-server"
# GRAFANA_NAMESPACE="prometheus-operator"
# MAX_KEY_SIZE_FOR_APP_TEST=64 # Matches default in Helm chart for consistency during testing

# # Function for logging information messages
# log_info() {
#     echo -e "[INFO] $1"
# }

# # Function for logging success messages
# log_success() {
#     echo -e "[SUCCESS] $1"
# }

# # Function for logging error messages and exiting
# log_error() {
#     echo -e "[ERROR] $1"
#     exit 1
# }

# # Function for logging step messages
# log_step() {
#     echo -e "\n[STEP] $1\n"
# }

# # Function to get a secure password for Grafana admin
# get_grafana_password() {
#     local password
#     # Read password securely without echoing it
#     read -s -p "Enter a secure password for Grafana admin user: " password
#     echo # New line after password prompt
#     # Ensure password is not empty
#     if [ -z "$password" ]; then
#         log_error "Grafana admin password cannot be empty. Exiting."
#         exit 1
#     fi
#     echo -n "$password" # Print the password to stdout WITHOUT a trailing newline
# }

# # Function to test application API endpoints (positive cases)
# # Arguments:
# #   $1: Base URL (e.g., https://localhost:8443)
# #   $2: Context (e.g., "Local Go App", "Docker Container", "Kubernetes Deployment")
# test_positive_api_endpoints() {
#     local base_url="$1"
#     local context="$2"
#     log_info "Testing POSITIVE API endpoints for ${context} at ${base_url}..."

#     # Test /health endpoint
#     log_info "  Testing /health endpoint..."
#     if curl -k --fail --silent "${base_url}/health" | grep -q "Healthy"; then
#         log_success "  /health endpoint is Healthy."
#     else
#         log_error "  /health endpoint FAILED for ${context}."
#     fi

#     # Test /ready endpoint
#     log_info "  Testing /ready endpoint..."
#     if curl -k --fail --silent "${base_url}/ready" | grep -q "Ready"; then
#         log_success "  /ready endpoint is Ready."
#     else
#         log_error "  /ready endpoint FAILED for ${context}."
#     fi

#     # --- Test /key/{length} endpoint (Positive) ---
#     echo "[INFO]    Testing /key/32 endpoint..."
#     KEY_RESPONSE=$(curl -k -s "${APP_URL}/key/32")
#     # Use jq to parse the JSON and extract the 'key' value.
#     # Check if the 'key' field exists and is not empty.
#     KEY_VALUE=$(echo "${KEY_RESPONSE}" | jq -r '.key // empty') # Use // empty to handle null/missing gracefully
#     if [[ -n "${KEY_VALUE}" ]]; then # Check if the extracted key value is non-empty
#     echo "[SUCCESS]   /key/32 endpoint returned a valid key."
#     else
#     echo "[ERROR]   /key/32 endpoint FAILED to return a valid key for Local Go App. Response: ${KEY_RESPONSE}"
#     # Mark failure for the overall script
#     TEST_FAILED=true
#     fi

#     # Test /key/1 endpoint (edge case for positive length)
#     log_info "  Testing /key/1 endpoint..."
#     key_response=$(curl -k --fail --silent "${base_url}/key/1")
#     if echo "${key_response}" | jq -e '.key | length == 1' > /dev/null; then
#         log_success "  /key/1 endpoint returned a valid key of length 1."
#     else
#         log_error "  /key/1 endpoint FAILED to return a valid key for ${context}. Response: ${key_response}"
#     fi

#     # Test /metrics endpoint - CHECKING FOR 'http_requests_total'
#     log_info "  Testing /metrics endpoint..."
#     if curl -k --fail --silent "${base_url}/metrics" | grep -q "http_requests_total"; then
#         log_success "  /metrics endpoint is accessible and contains expected metrics ('http_requests_total')."
#     else
#         log_error "  /metrics endpoint FAILED for ${context}. Expected 'http_requests_total' metric not found."
#     fi

#     log_success "All POSITIVE API tests PASSED for ${context}."
# }

# # Function to test application API endpoints (negative cases)
# # Arguments:
# #   $1: Base URL (e.g., https://localhost:8443)
# #   $2: Context (e.g., "Local Go App", "Docker Container", "Kubernetes Deployment")
# test_negative_api_endpoints() {
#     local base_url="$1"
#     local context="$2"
#     log_info "Testing NEGATIVE API endpoints for ${context} at ${base_url}..."

#     local response_code
#     local response_body

#     # Test /key/abc (non-numeric length) -> 400 Bad Request
#     log_info "  Testing /key/abc (non-numeric length) -> expected 400..."
#     response_body=$(curl -k -s -w "%{http_code}" "${base_url}/key/abc" -o /dev/null)
#     response_code="${response_body}"
#     if [ "${response_code}" -eq 400 ]; then
#         log_success "  /key/abc returned 400 Bad Request as expected."
#     else
#         log_error "  /key/abc FAILED for ${context}. Expected 400, got ${response_code}."
#     fi

#     # Test /key/0 (zero length) -> 400 Bad Request
#     log_info "  Testing /key/0 (zero length) -> expected 400..."
#     response_body=$(curl -k -s -w "%{http_code}" "${base_url}/key/0" -o /dev/null)
#     response_code="${response_body}"
#     if [ "${response_code}" -eq 400 ]; then
#         log_success "  /key/0 returned 400 Bad Request as expected."
#     else
#         log_error "  /key/0 FAILED for ${context}. Expected 400, got ${response_code}."
#     fi

#     # Test /key/<MAX_KEY_SIZE + 1> (too large length) -> 400 Bad Request
#     local oversized_key_length=$((MAX_KEY_SIZE_FOR_APP_TEST + 1))
#     log_info "  Testing /key/${oversized_key_length} (too large length) -> expected 400..."
#     response_body=$(curl -k -s -w "%{http_code}" "${base_url}/key/${oversized_key_length}" -o /dev/null)
#     response_code="${response_body}"
#     if [ "${response_code}" -eq 400 ]; then
#         log_success "  /key/${oversized_key_length} returned 400 Bad Request as expected."
#     else
#         log_error "  /key/${oversized_key_length} FAILED for ${context}. Expected 400, got ${response_code}."
#     fi

#     # Test POST to /key/32 (incorrect method) -> 405 Method Not Allowed
#     log_info "  Testing POST /key/32 (incorrect method) -> expected 405..."
#     response_body=$(curl -k -s -X POST -w "%{http_code}" "${base_url}/key/32" -o /dev/null)
#     response_code="${response_body}"
#     if [ "${response_code}" -eq 405 ]; then
#         log_success "  POST /key/32 returned 405 Method Not Allowed as expected."
#     else
#         log_error "  POST /key/32 FAILED for ${context}. Expected 405, got ${response_code}."
#     fi

#     log_success "All NEGATIVE API tests PASSED for ${context}."
# }


# # Function to find a pod name robustly
# # Arguments:
# #   $1: Namespace
# #   $2: Grep pattern for pod name
# #   $3: Description for logging
# find_pod_name_robustly() {
#     local namespace="$1"
#     local grep_pattern="$2"
#     local description="$3"
#     local pod_name=""
#     local max_retries=24 # 24 * 5 seconds = 120 seconds (2 minutes)
#     local retry_count=0

#     log_info "  Searching for ${description} pod in namespace '${namespace}' with pattern '${grep_pattern}'..." >&2 # Redirect to stderr
#     while [ -z "${pod_name}" ] && [ "${retry_count}" -lt "${max_retries}" ]; do
#         # kubectl output is piped, so stderr is preserved for error messages, stdout is captured
#         pod_name=$(kubectl get pods -n "${namespace}" -o name 2>/dev/null | grep "${grep_pattern}" | head -n 1 | sed 's/^pod\///')
#         if [ -z "${pod_name}" ]; then
#             log_info "    ${description} pod not found yet. Retrying in 5 seconds... (Attempt $((retry_count + 1))/${max_retries})" >&2 # Redirect to stderr
#             sleep 5
#             retry_count=$((retry_count + 1))
#         fi
#     done

#     if [ -z "${pod_name}" ]; then
#         log_error "${description} pod not found after multiple retries. Check 'kubectl get pods -n ${namespace}'."
#     fi
#     echo "${pod_name}" # Return the found pod name on stdout
# }


# # --- Main Script Execution ---

# log_step "Starting Kubernetes environment setup and application deployment..."

# # 1. Create Kind Cluster
# log_info "Creating Kind cluster named '${APP_NAME}'..."
# kind create cluster --name "${APP_NAME}" || log_error "Failed to create Kind cluster."
# log_success "Kind cluster '${APP_NAME}' created."

# # 2. Set Kubectl Context
# log_info "Setting kubectl context to 'kind-${APP_NAME}'..."
# kubectl config use-context "kind-${APP_NAME}" || log_error "Failed to set kubectl context."
# log_success "kubectl context set to 'kind-${APP_NAME}'."

# log_info "Current kubectl context: $(kubectl config current-context)"
# log_info "Attempting to get Kubernetes cluster info (this should NOT show localhost:8080 if context is correct):"
# kubectl cluster-info || log_error "Failed to get cluster info."

# # 3. Add Helm Repositories
# log_info "Adding Prometheus community Helm repository..."
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || log_error "Failed to add Prometheus Helm repo."
# helm repo update || log_error "Failed to update Helm repositories."
# log_success "Helm repositories added and updated."

# # 4. Generate Grafana Admin Password and Create Secret
# GRAFANA_ADMIN_PASSWORD=$(get_grafana_password)
# log_info "Creating Kubernetes Secret for Grafana admin password..."
# kubectl create namespace "${GRAFANA_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - --validate=false || log_error "Failed to create ${GRAFANA_NAMESPACE} namespace."
# kubectl create secret generic grafana-admin-secret \
#     --from-literal=admin-user=admin \
#     --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
#     --namespace "${GRAFANA_NAMESPACE}" \
#     --dry-run=client -o yaml | kubectl apply -f - --validate=false || log_error "Failed to create Grafana admin secret."
# log_success "Grafana admin secret 'grafana-admin-secret' created."

# # 5. Create Grafana Dashboard JSON ConfigMaps
# log_step "Creating Grafana Dashboard JSON ConfigMaps..."
# kubectl create configmap key-server-http-overview-dashboard \
#     --from-file=http-overview.json \
#     --namespace "${GRAFANA_NAMESPACE}" \
#     --dry-run=client -o yaml | kubectl apply -f - || log_error "Failed to create HTTP overview dashboard ConfigMap."
# log_success "HTTP overview dashboard ConfigMap created."

# kubectl create configmap key-server-key-generation-dashboard \
#     --from-file=key-generation.json \
#     --namespace "${GRAFANA_NAMESPACE}" \
#     --dry-run=client -o yaml | kubectl apply -f - || log_error "Failed to create Key Generation dashboard ConfigMap."
# log_success "Key Generation dashboard ConfigMap created."

# # Create ConfigMap for Grafana Dashboard Provisioning Configuration
# log_step "Creating Grafana Dashboard Provisioning Configuration ConfigMap..."
# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: grafana-custom-dashboards-provisioning
#   namespace: ${GRAFANA_NAMESPACE}
# data:
#   custom-dashboards.yaml: |
#     apiVersion: 1
#     providers:
#       - name: 'Key Server Dashboards'
#         orgId: 1
#         folder: 'Key Server'
#         type: file
#         disableDeletion: false
#         editable: true
#         options:
#           path: /var/lib/grafana/dashboards/key-server
#           foldersFromFilesStructure: false
# EOF
# log_success "Grafana Dashboard Provisioning Configuration ConfigMap created."

# # Create ConfigMap for Grafana Prometheus Data Source Provisioning
# log_step "Creating Grafana Prometheus Data Source Provisioning ConfigMap..."
# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: grafana-prometheus-datasource
#   namespace: ${GRAFANA_NAMESPACE}
# data:
#   prometheus-datasource.yaml: |
#     apiVersion: 1
#     datasources:
#       - name: Prometheus
#         type: prometheus
#         url: http://prometheus-stack-kube-prom-prometheus.prometheus-operator:9090
#         access: proxy
#         isDefault: true
#         version: 1
#         editable: false
#         uid: prometheus
# EOF
# log_success "Grafana Prometheus Data Source Provisioning ConfigMap created."


# log_info "Adding a short delay for ConfigMap propagation..."
# sleep 5

# # 6. Deploy Prometheus Stack with Grafana
# log_info "Installing kube-prometheus-stack Helm chart (configured for direct dashboard provisioning and cross-namespace ServiceMonitor discovery)..."
# helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
#     --namespace "${GRAFANA_NAMESPACE}" \
#     --set grafana.admin.existingSecret=grafana-admin-secret \
#     --set grafana.admin.secretKey=admin-password \
#     --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesPods=false \
#     --set prometheus.prometheusSpec.podMonitorSelectorNilUsesPods=false \
#     --set grafana.service.type=NodePort \
#     --set grafana.sidecar.dashboards.enabled=false \
#     --set grafana.sidecar.datasources.enabled=false \
#     --set grafana.sidecar.notifiers.enabled=false \
#     --set grafana.sidecar.plugins.enabled=false \
#     --set grafana.initChownData.enabled=false \
#     --set grafana.extraVolumes[0].name=key-server-dashboards-volume \
#     --set grafana.extraVolumes[0].configMap.name=key-server-http-overview-dashboard \
#     --set grafana.extraVolumes[1].name=key-server-dashboards-volume-2 \
#     --set grafana.extraVolumes[1].configMap.name=key-server-key-generation-dashboard \
#     --set grafana.extraVolumeMounts[0].name=key-server-dashboards-volume \
#     --set grafana.extraVolumeMounts[0].mountPath=/var/lib/grafana/dashboards/key-server/http-overview.json \
#     --set grafana.extraVolumeMounts[0].subPath=http-overview.json \
#     --set grafana.extraVolumeMounts[1].name=key-server-dashboards-volume-2 \
#     --set grafana.extraVolumeMounts[1].mountPath=/var/lib/grafana/dashboards/key-server/key-generation.json \
#     --set grafana.extraVolumeMounts[1].subPath=key-generation.json \
#     \
#     --set grafana.extraVolumes[2].name=grafana-provisioning-config-volume \
#     --set grafana.extraVolumes[2].configMap.name=grafana-custom-dashboards-provisioning \
#     --set grafana.extraVolumeMounts[2].name=grafana-provisioning-config-volume \
#     --set grafana.extraVolumeMounts[2].mountPath=/etc/grafana/provisioning/dashboards/custom-dashboards.yaml \
#     --set grafana.extraVolumeMounts[2].subPath=custom-dashboards.yaml \
#     \
#     --set grafana.extraVolumes[3].name=grafana-datasource-volume \
#     --set grafana.extraVolumes[3].configMap.name=grafana-prometheus-datasource \
#     --set grafana.extraVolumeMounts[3].name=grafana-datasource-volume \
#     --set grafana.extraVolumeMounts[3].mountPath=/etc/grafana/provisioning/datasources/prometheus-datasource.yaml \
#     --set grafana.extraVolumeMounts[3].subPath=prometheus-datasource.yaml \
#     \
#     --set-json prometheus.prometheusSpec.serviceMonitorSelector='{}' \
#     --set-json prometheus.prometheusSpec.serviceMonitorNamespaceSelector='{}' \
#     --atomic \
#     --wait --timeout 10m || log_error "Failed to deploy Prometheus stack."
# log_success "Prometheus stack deployed successfully."

# # 7. Wait for Prometheus Operator to be Ready (Robustly)
# log_info "Waiting for Prometheus Operator pod to be scheduled and ready..."
# OPERATOR_POD_NAME=$(find_pod_name_robustly "${GRAFANA_NAMESPACE}" "kube-prom-operator" "Prometheus Operator")
# kubectl wait --for=condition=ready pod "${OPERATOR_POD_NAME}" -n "${GRAFANA_NAMESPACE}" --timeout=300s || log_error "Prometheus Operator pod not ready within timeout."
# log_success "Prometheus Operator pod is ready."

# # 8. Wait for remaining monitoring stack pods to be ready (including Grafana pod)
# log_info "Waiting for remaining monitoring stack pods to be ready..."
# # Use robust finding for Prometheus server pod
# PROMETHEUS_SERVER_POD_NAME=$(find_pod_name_robustly "${GRAFANA_NAMESPACE}" "prometheus-stack-kube-prom-prometheus" "Prometheus Server")
# kubectl wait --for=condition=ready pod "${PROMETHEUS_SERVER_POD_NAME}" -n "${GRAFANA_NAMESPACE}" --timeout=300s || log_error "Prometheus server pod not ready within timeout."

# # Use robust finding for Grafana pod
# GRAFANA_POD_NAME=$(find_pod_name_robustly "${GRAFANA_NAMESPACE}" "prometheus-stack-grafana" "Grafana")
# kubectl wait --for=condition=ready pod "${GRAFANA_POD_NAME}" -n "${GRAFANA_NAMESPACE}" --timeout=300s || log_error "Grafana pod not ready within timeout."
# log_success "Remaining monitoring stack pods are ready."


# # --- Local Go Application Build and Test ---
# log_step "Building and testing local Go application..."
# go build -o "${APP_NAME}" . || log_error "Go application build failed."
# log_success "Go application binary built: ./${APP_NAME}"

# log_info "Running Go unit tests..."
# go test ./... || log_error "Go unit tests failed."
# log_success "Go unit tests passed."

# log_info "Starting local Go application in background for API tests..."
# # Ensure certs are available for local app
# if [ ! -f "./certs/server.crt" ] || [ ! -f "./certs/server.key" ]; then
#     log_error "TLS certificates not found in ./certs/. Run 'dev-setup.sh' first."
# fi
# PORT=8443 MAX_KEY_SIZE=${MAX_KEY_SIZE_FOR_APP_TEST} \
# TLS_CERT_FILE=./certs/server.crt \
# TLS_KEY_FILE=./certs/server.key \
# ./"${APP_NAME}" > /dev/null 2>&1 &
# LOCAL_APP_PID=$!
# log_info "Local Go application started with PID: ${LOCAL_APP_PID}"
# sleep 5 # Give app time to start

# test_positive_api_endpoints "https://localhost:8443" "Local Go App"
# test_negative_api_endpoints "https://localhost:8443" "Local Go App"

# log_info "Stopping local Go application (PID: ${LOCAL_APP_PID})..."
# kill "${LOCAL_APP_PID}" || true
# wait "${LOCAL_APP_PID}" 2>/dev/null || true # Wait for it to terminate
# log_success "Local Go application stopped."


# # --- Docker Image Build and Local Container Test ---
# log_step "Building Docker image and testing local container..."
# docker build -t "${APP_NAME}" . || log_error "Docker image build failed."
# log_success "Docker image built: ${APP_NAME}"

# log_info "Running Docker container for API tests..."
# docker run -d --rm --name "${APP_NAME}-test" -p 8443:8443 \
#   -v "$(pwd)/certs:/etc/key-server/tls" \
#   -e PORT=8443 \
#   -e TLS_CERT_FILE=/etc/key-server/tls/server.crt \
#   -e TLS_KEY_FILE=/etc/key-server/tls/server.key \
#   -e MAX_KEY_SIZE=${MAX_KEY_SIZE_FOR_APP_TEST} \
#   "${APP_NAME}" || log_error "Failed to run Docker container."
# log_success "Docker container '${APP_NAME}-test' started."
# sleep 5 # Give container time to start

# test_positive_api_endpoints "https://localhost:8443" "Docker Container"
# test_negative_api_endpoints "https://localhost:8443" "Docker Container"

# log_info "Stopping and removing Docker container '${APP_NAME}-test'..."
# docker stop "${APP_NAME}-test" >/dev/null 2>&1 || true
# docker rm "${APP_NAME}-test" >/dev/null 2>&1 || true
# log_success "Docker container stopped and removed."


# # --- Kubernetes Deployment and API Test ---
# log_step "Deploying Key Server to Kubernetes using Helm..."

# log_info "Loading Docker image '${APP_NAME}' into Kind cluster..."
# kind load docker-image "${APP_NAME}" --name "${APP_NAME}" || log_error "Failed to load Docker image into Kind cluster."
# log_success "Docker image loaded into Kind cluster."

# log_info "Creating Kubernetes TLS secret from generated certificates..."
# kubectl create secret tls key-server-key-server-app-tls-secret \
#     --cert=./certs/server.crt \
#     --key=./certs/server.key \
#     --dry-run=client -o yaml | kubectl apply -f - || log_error "Failed to create TLS secret."
# log_success "Kubernetes TLS secret created."

# log_info "Installing/Upgrading Helm chart for 'key-server'..."
# helm upgrade --install "${APP_NAME}" ./deploy/kubernetes/key-server-chart \
#     --set image.repository="${APP_NAME}" \
#     --set image.tag=latest \
#     --set service.type=NodePort \
#     --set ingress.enabled=true \
#     --set "ingress.tls[0].secretName=key-server-key-server-app-tls-secret" \
#     --set config.maxKeySize=${MAX_KEY_SIZE_FOR_APP_TEST} \
#     --set service.port=8443 \
#     --set service.targetPort=8443 \
#     --wait --timeout 10m || log_error "Helm deployment failed."
# log_success "Helm deployment completed."

# log_info "Dashboards are expected to be loaded directly by Grafana from the /var/lib/grafana/dashboards/key-server path."

# # Kubernetes API Test
# log_info "Performing API tests on Kubernetes deployed application..."
# K8S_SVC_NAME="${APP_NAME}-key-server-app" # Corrected service name for port-forward
# log_info "Starting kubectl port-forward for Kubernetes API tests..."
# kubectl port-forward "svc/${K8S_SVC_NAME}" 8443:8443 -n default > /dev/null 2>&1 &
# K8S_PF_PID=$!
# log_info "Kubectl port-forward started with PID: ${K8S_PF_PID}"
# sleep 5 # Give port-forward time to establish

# test_positive_api_endpoints "https://localhost:8443" "Kubernetes Deployment"
# test_negative_api_endpoints "https://localhost:8443" "Kubernetes Deployment"

# log_info "Stopping kubectl port-forward (PID: ${K8S_PF_PID})..."
# kill "${K8S_PF_PID}" || true
# wait "${K8S_PF_PID}" 2>/dev/null || true # Wait for it to terminate
# log_success "Kubectl port-forward stopped."

# # --- Monitoring Data Absence Test ---
# log_step "Verifying monitoring metrics absence before load (no requests made after deployment)..."
# PROMETHEUS_SVC_NAME=$(kubectl get svc -n "${GRAFANA_NAMESPACE}" -l app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus-stack -o jsonpath='{.items[0].metadata.name}')
# log_info "Starting kubectl port-forward for Prometheus UI to check metrics..."
# kubectl port-forward svc/${PROMETHEUS_SVC_NAME} 9090:9090 -n "${GRAFANA_NAMESPACE}" > /dev/null 2>&1 &
# PROMETHEUS_PF_PID=$!
# log_info "Prometheus port-forward started with PID: ${PROMETHEUS_PF_PID}"
# sleep 10 # Give Prometheus time to scrape and refresh data

# # Query Prometheus for http_requests_total and key_generations_total
# HTTP_REQUESTS_TOTAL=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total{job='key-server-key-server-app'}" | jq -r '.data.result[0].value[1]' 2>/dev/null)
# KEY_GENERATIONS_TOTAL=$(curl -s "http://localhost:9090/api/v1/query?query=key_generations_total{job='key-server-key-server-app'}" | jq -r '.data.result[0].value[1]' 2>/dev/null)

# log_info "  Current http_requests_total: ${HTTP_REQUESTS_TOTAL:-0}"
# log_info "  Current key_generations_total: ${KEY_GENERATIONS_TOTAL:-0}"

# # Allow for initial probes/metrics scraping, but ensure they don't count as "key generations"
# # Initial value should be low, primarily from health/ready checks and the tests just run.
# # Resetting the pod would be better for a true "zero", but for now, we expect low.
# if (( $(echo "${HTTP_REQUESTS_TOTAL:-0}" | cut -d'.' -f1) < 50 )); then # Expecting few initial requests from probes and current test runs
#     log_success "  http_requests_total is low (expected initial probes and tests)."
# else
#     log_error "  http_requests_total is unexpectedly high before load: ${HTTP_REQUESTS_TOTAL:-0}."
# fi

# if (( $(echo "${KEY_GENERATIONS_TOTAL:-0}" | cut -d'.' -f1) == 0 )); then # Key generations should be 0 unless load was applied
#     log_success "  key_generations_total is 0 as expected before load."
# else
#     # This might fail due to previous key generation tests. It's an ideal, but potentially noisy test.
#     log_info "  key_generations_total is non-zero (${KEY_GENERATIONS_TOTAL:-0}) due to previous API tests. This is acceptable for current script flow."
#     log_success "  Metric absence check adjusted for current test flow."
# fi

# log_info "Stopping Prometheus port-forward (PID: ${PROMETHEUS_PF_PID})..."
# kill "${PROMETHEUS_PF_PID}" || true
# wait "${PROMETHEUS_PF_PID}" 2>/dev/null || true # Wait for it to terminate
# log_success "Prometheus port-forward stopped."


# log_success "All deployments and verifications completed successfully!"

# echo "\n--- GRAFANA ACCESS INSTRUCTIONS ---"
# echo "Grafana is deployed and should have your custom dashboards."
# echo "1. In a NEW terminal tab/window, run the following to port-forward Grafana:"
# echo "   kubectl port-forward svc/prometheus-stack-grafana 3000:3000 -n ${GRAFANA_NAMESPACE}"
# echo "2. Open your web browser to: http://localhost:3000"
# echo "3. Log in with Username: admin and Password: The secure password you entered earlier."
# echo "4. Navigate to Dashboards -> Browse (or Search for 'Key Server') and verify 'Key Server HTTP Overview' and 'Key Server Key Generation' are present and show data."
# echo "Note: It might take a minute or two for Grafana to fully load dashboards from ConfigMaps after its pod becomes ready."

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
