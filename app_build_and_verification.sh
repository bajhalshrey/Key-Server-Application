#!/bin/bash

# Define constants
APP_NAME="key-server"
GRAFANA_NAMESPACE="prometheus-operator"

# Function for logging information messages
log_info() {
    echo -e "[INFO] $1"
}

# Function for logging success messages
log_success() {
    echo -e "[SUCCESS] $1"
}

# Function for logging error messages and exiting
log_error() {
    echo -e "[ERROR] $1"
    exit 1
}

# Function for logging step messages
log_step() {
    echo -e "\n[STEP] $1\n"
}

# Function to get a secure password for Grafana admin
get_grafana_password() {
    local password
    # Read password securely without echoing it
    read -s -p "Enter a secure password for Grafana admin user: " password
    echo # New line after password prompt
    # Ensure password is not empty
    if [ -z "$password" ]; then
        log_error "Grafana admin password cannot be empty. Exiting."
        exit 1
    fi
    echo -n "$password" # Print the password to stdout WITHOUT a trailing newline
}

# Function to test application API endpoints
# Arguments:
#   $1: Base URL (e.g., https://localhost:8443)
#   $2: Context (e.g., "Local Go App", "Docker Container", "Kubernetes Deployment")
test_api_endpoints() {
    local base_url="$1"
    local context="$2"
    log_info "Testing API endpoints for ${context} at ${base_url}..."

    # Test /health endpoint
    log_info "  Testing /health endpoint..."
    if curl -k --fail --silent "${base_url}/health" | grep -q "Healthy"; then
        log_success "  /health endpoint is Healthy."
    else
        log_error "  /health endpoint FAILED for ${context}."
    fi

    # Test /ready endpoint
    log_info "  Testing /ready endpoint..."
    if curl -k --fail --silent "${base_url}/ready" | grep -q "Ready"; then
        log_success "  /ready endpoint is Ready."
    else
        log_error "  /ready endpoint FAILED for ${context}."
    fi

    # Test /key/32 endpoint
    log_info "  Testing /key/32 endpoint..."
    local key_response
    key_response=$(curl -k --fail --silent "${base_url}/key/32")
    if echo "${key_response}" | jq -e '.key' > /dev/null; then
        log_success "  /key/32 endpoint returned a valid key."
    else
        log_error "  /key/32 endpoint FAILED to return a valid key for ${context}. Response: ${key_response}"
    fi

    # Test /metrics endpoint - CHECKING FOR 'http_requests_total'
    log_info "  Testing /metrics endpoint..."
    if curl -k --fail --silent "${base_url}/metrics" | grep -q "http_requests_total"; then
        log_success "  /metrics endpoint is accessible and contains expected metrics ('http_requests_total')."
    else
        log_error "  /metrics endpoint FAILED for ${context}. Expected 'http_requests_total' metric not found."
    fi

    log_success "All API tests PASSED for ${context}."
}

# Function to find a pod name robustly
# Arguments:
#   $1: Namespace
#   $2: Grep pattern for pod name
#   $3: Description for logging
find_pod_name_robustly() {
    local namespace="$1"
    local grep_pattern="$2"
    local description="$3"
    local pod_name=""
    local max_retries=24 # 24 * 5 seconds = 120 seconds (2 minutes)
    local retry_count=0

    log_info "  Searching for ${description} pod in namespace '${namespace}' with pattern '${grep_pattern}'..." >&2 # Redirect to stderr
    while [ -z "${pod_name}" ] && [ "${retry_count}" -lt "${max_retries}" ]; do
        # kubectl output is piped, so stderr is preserved for error messages, stdout is captured
        pod_name=$(kubectl get pods -n "${namespace}" -o name 2>/dev/null | grep "${grep_pattern}" | head -n 1 | sed 's/^pod\///')
        if [ -z "${pod_name}" ]; then
            log_info "    ${description} pod not found yet. Retrying in 5 seconds... (Attempt $((retry_count + 1))/${max_retries})" >&2 # Redirect to stderr
            sleep 5
            retry_count=$((retry_count + 1))
        fi
    done

    if [ -z "${pod_name}" ]; then
        log_error "${description} pod not found after multiple retries. Check 'kubectl get pods -n ${namespace}'."
    fi
    echo "${pod_name}" # Return the found pod name on stdout
}


# --- Main Script Execution ---

log_step "Starting Kubernetes environment setup and application deployment..."

# 1. Create Kind Cluster
log_info "Creating Kind cluster named '${APP_NAME}'..."
kind create cluster --name "${APP_NAME}" || log_error "Failed to create Kind cluster."
log_success "Kind cluster '${APP_NAME}' created."

# 2. Set Kubectl Context
log_info "Setting kubectl context to 'kind-${APP_NAME}'..."
kubectl config use-context "kind-${APP_NAME}" || log_error "Failed to set kubectl context."
log_success "kubectl context set to 'kind-${APP_NAME}'."

log_info "Current kubectl context: $(kubectl config current-context)"
log_info "Attempting to get Kubernetes cluster info (this should NOT show localhost:8080 if context is correct):"
kubectl cluster-info || log_error "Failed to get cluster info."

# 3. Add Helm Repositories
log_info "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || log_error "Failed to add Prometheus Helm repo."
helm repo update || log_error "Failed to update Helm repositories."
log_success "Helm repositories added and updated."

# 4. Generate Grafana Admin Password and Create Secret
GRAFANA_ADMIN_PASSWORD=$(get_grafana_password)
log_info "Creating Kubernetes Secret for Grafana admin password..."
kubectl create namespace "${GRAFANA_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - --validate=false || log_error "Failed to create ${GRAFANA_NAMESPACE} namespace."
kubectl create secret generic grafana-admin-secret \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
    --namespace "${GRAFANA_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f - --validate=false || log_error "Failed to create Grafana admin secret."
log_success "Grafana admin secret 'grafana-admin-secret' created."

# 5. Create Grafana Dashboard JSON ConfigMaps
log_step "Creating Grafana Dashboard JSON ConfigMaps..."
kubectl create configmap key-server-http-overview-dashboard \
    --from-file=http-overview.json \
    --namespace "${GRAFANA_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f - || log_error "Failed to create HTTP overview dashboard ConfigMap."
log_success "HTTP overview dashboard ConfigMap created."

kubectl create configmap key-server-key-generation-dashboard \
    --from-file=key-generation.json \
    --namespace "${GRAFANA_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f - || log_error "Failed to create Key Generation dashboard ConfigMap."
log_success "Key Generation dashboard ConfigMap created."

# Create ConfigMap for Grafana Dashboard Provisioning Configuration
log_step "Creating Grafana Dashboard Provisioning Configuration ConfigMap..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-custom-dashboards-provisioning
  namespace: ${GRAFANA_NAMESPACE}
data:
  custom-dashboards.yaml: |
    apiVersion: 1
    providers:
      - name: 'Key Server Dashboards'
        orgId: 1
        folder: 'Key Server'
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/key-server
          foldersFromFilesStructure: false
EOF
log_success "Grafana Dashboard Provisioning Configuration ConfigMap created."

log_info "Adding a short delay for ConfigMap propagation..."
sleep 5

# 6. Deploy Prometheus Stack with Grafana
log_info "Installing kube-prometheus-stack Helm chart (configured for direct dashboard provisioning and cross-namespace ServiceMonitor discovery)..."
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace "${GRAFANA_NAMESPACE}" \
    --set grafana.admin.existingSecret=grafana-admin-secret \
    --set grafana.admin.secretKey=admin-password \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesPods=false \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesPods=false \
    --set grafana.service.type=NodePort \
    --set grafana.sidecar.dashboards.enabled=false \
    --set grafana.sidecar.datasources.enabled=false \
    --set grafana.sidecar.notifiers.enabled=false \
    --set grafana.sidecar.plugins.enabled=false \
    --set grafana.initChownData.enabled=false \
    --set grafana.extraVolumes[0].name=key-server-dashboards-volume \
    --set grafana.extraVolumes[0].configMap.name=key-server-http-overview-dashboard \
    --set grafana.extraVolumes[1].name=key-server-dashboards-volume-2 \
    --set grafana.extraVolumes[1].configMap.name=key-server-key-generation-dashboard \
    --set grafana.extraVolumeMounts[0].name=key-server-dashboards-volume \
    --set grafana.extraVolumeMounts[0].mountPath=/var/lib/grafana/dashboards/key-server/http-overview.json \
    --set grafana.extraVolumeMounts[0].subPath=http-overview.json \
    --set grafana.extraVolumeMounts[1].name=key-server-dashboards-volume-2 \
    --set grafana.extraVolumeMounts[1].mountPath=/var/lib/grafana/dashboards/key-server/key-generation.json \
    --set grafana.extraVolumeMounts[1].subPath=key-generation.json \
    \
    --set grafana.extraVolumes[2].name=grafana-provisioning-config-volume \
    --set grafana.extraVolumes[2].configMap.name=grafana-custom-dashboards-provisioning \
    --set grafana.extraVolumeMounts[2].name=grafana-provisioning-config-volume \
    --set grafana.extraVolumeMounts[2].mountPath=/etc/grafana/provisioning/dashboards/custom-dashboards.yaml \
    --set grafana.extraVolumeMounts[2].subPath=custom-dashboards.yaml \
    \
    --set-json prometheus.prometheusSpec.serviceMonitorSelector='{}' \
    --set-json prometheus.prometheusSpec.serviceMonitorNamespaceSelector='{}' \
    --atomic \
    --wait --timeout 10m || log_error "Failed to deploy Prometheus stack."
log_success "Prometheus stack deployed successfully."

# 7. Wait for Prometheus Operator to be Ready (Robustly)
log_info "Waiting for Prometheus Operator pod to be scheduled and ready..."
OPERATOR_POD_NAME=$(find_pod_name_robustly "${GRAFANA_NAMESPACE}" "kube-prom-operator" "Prometheus Operator")
kubectl wait --for=condition=ready pod "${OPERATOR_POD_NAME}" -n "${GRAFANA_NAMESPACE}" --timeout=300s || log_error "Prometheus Operator pod not ready within timeout."
log_success "Prometheus Operator pod is ready."

# 8. Wait for remaining monitoring stack pods to be ready (including Grafana pod)
log_info "Waiting for remaining monitoring stack pods to be ready..."
# Use robust finding for Prometheus server pod
PROMETHEUS_SERVER_POD_NAME=$(find_pod_name_robustly "${GRAFANA_NAMESPACE}" "prometheus-stack-kube-prom-prometheus" "Prometheus Server")
kubectl wait --for=condition=ready pod "${PROMETHEUS_SERVER_POD_NAME}" -n "${GRAFANA_NAMESPACE}" --timeout=300s || log_error "Prometheus server pod not ready within timeout."

# Use robust finding for Grafana pod
GRAFANA_POD_NAME=$(find_pod_name_robustly "${GRAFANA_NAMESPACE}" "prometheus-stack-grafana" "Grafana")
kubectl wait --for=condition=ready pod "${GRAFANA_POD_NAME}" -n "${GRAFANA_NAMESPACE}" --timeout=300s || log_error "Grafana pod not ready within timeout."
log_success "Remaining monitoring stack pods are ready."


# --- Local Go Application Build and Test ---
log_step "Building and testing local Go application..."
go build -o "${APP_NAME}" . || log_error "Go application build failed."
log_success "Go application binary built: ./${APP_NAME}"

log_info "Starting local Go application in background for API tests..."
# Ensure certs are available for local app
if [ ! -f "./certs/server.crt" ] || [ ! -f "./certs/server.key" ]; then
    log_error "TLS certificates not found in ./certs/. Run 'dev-setup.sh' first."
fi
PORT=8443 MAX_KEY_SIZE=64 \
TLS_CERT_FILE=./certs/server.crt \
TLS_KEY_FILE=./certs/server.key \
./"${APP_NAME}" > /dev/null 2>&1 &
LOCAL_APP_PID=$!
log_info "Local Go application started with PID: ${LOCAL_APP_PID}"
sleep 5 # Give app time to start

test_api_endpoints "https://localhost:8443" "Local Go App"

log_info "Stopping local Go application (PID: ${LOCAL_APP_PID})..."
kill "${LOCAL_APP_PID}" || true
wait "${LOCAL_APP_PID}" 2>/dev/null || true # Wait for it to terminate
log_success "Local Go application stopped."


# --- Docker Image Build and Local Container Test ---
log_step "Building Docker image and testing local container..."
docker build -t "${APP_NAME}" . || log_error "Docker image build failed."
log_success "Docker image built: ${APP_NAME}"

log_info "Running Docker container for API tests..."
docker run -d --rm --name "${APP_NAME}-test" -p 8443:8443 \
  -v "$(pwd)/certs:/etc/key-server/tls" \
  -e PORT=8443 \
  -e TLS_CERT_FILE=/etc/key-server/tls/server.crt \
  -e TLS_KEY_FILE=/etc/key-server/tls/server.key \
  "${APP_NAME}" || log_error "Failed to run Docker container."
log_success "Docker container '${APP_NAME}-test' started."
sleep 5 # Give container time to start

test_api_endpoints "https://localhost:8443" "Docker Container"

log_info "Stopping and removing Docker container '${APP_NAME}-test'..."
docker stop "${APP_NAME}-test" >/dev/null 2>&1 || true
docker rm "${APP_NAME}-test" >/dev/null 2>&1 || true
log_success "Docker container stopped and removed."


# --- Kubernetes Deployment and API Test ---
log_step "Deploying Key Server to Kubernetes using Helm..."

log_info "Loading Docker image '${APP_NAME}' into Kind cluster..."
kind load docker-image "${APP_NAME}" --name "${APP_NAME}" || log_error "Failed to load Docker image into Kind cluster."
log_success "Docker image loaded into Kind cluster."

log_info "Creating Kubernetes TLS secret from generated certificates..."
kubectl create secret tls key-server-key-server-app-tls-secret \
    --cert=./certs/server.crt \
    --key=./certs/server.key \
    --dry-run=client -o yaml | kubectl apply -f - || log_error "Failed to create TLS secret."
log_success "Kubernetes TLS secret created."

log_info "Installing/Upgrading Helm chart for 'key-server'..."
helm upgrade --install "${APP_NAME}" ./deploy/kubernetes/key-server-chart \
    --set image.repository="${APP_NAME}" \
    --set image.tag=latest \
    --set service.type=NodePort \
    --set ingress.enabled=true \
    --set "ingress.tls[0].secretName=key-server-key-server-app-tls-secret" \
    --set config.maxKeySize=64 \
    --set service.port=8443 \
    --set service.targetPort=8443 \
    --wait --timeout 10m || log_error "Helm deployment failed."
log_success "Helm deployment completed."

log_info "Dashboards are expected to be loaded directly by Grafana from the /var/lib/grafana/dashboards/key-server path."

# Kubernetes API Test
log_info "Performing API tests on Kubernetes deployed application..."
K8S_SVC_NAME="${APP_NAME}-key-server-app" # Corrected service name for port-forward
log_info "Starting kubectl port-forward for Kubernetes API tests..."
kubectl port-forward "svc/${K8S_SVC_NAME}" 8443:8443 -n default > /dev/null 2>&1 &
K8S_PF_PID=$!
log_info "Kubectl port-forward started with PID: ${K8S_PF_PID}"
sleep 5 # Give port-forward time to establish

test_api_endpoints "https://localhost:8443" "Kubernetes Deployment"

log_info "Stopping kubectl port-forward (PID: ${K8S_PF_PID})..."
kill "${K8S_PF_PID}" || true
wait "${K8S_PF_PID}" 2>/dev/null || true # Wait for it to terminate
log_success "Kubectl port-forward stopped."


log_success "All deployments and verifications completed successfully!"

echo "\n--- GRAFANA ACCESS INSTRUCTIONS ---"
echo "Grafana is deployed and should have your custom dashboards."
echo "1. In a NEW terminal tab/window, run the following to port-forward Grafana:"
echo "   kubectl port-forward svc/prometheus-stack-grafana 3000:3000 -n ${GRAFANA_NAMESPACE}"
echo "2. Open your web browser to: http://localhost:3000"
echo "3. Log in with Username: admin and Password: The secure password you entered earlier."
echo "4. Navigate to Dashboards -> Browse (or Search for 'Key Server') and verify 'Key Server HTTP Overview' and 'Key Server Key Generation' are present and show data."
echo "Note: It might take a minute or two for Grafana to fully load dashboards from ConfigMaps after its pod becomes ready."
