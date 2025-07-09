#!/bin/bash

# cleanup.sh
# This script performs a comprehensive cleanup of the Key Server application's
# build artifacts, Docker containers/images, and Kubernetes resources,
# including the monitoring stack.

echo "--- Cleanup script started. ---"

# Set options for robust script execution:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Exit if any unset variables are used.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- Configuration ---
APP_NAME="key-server"
TEST_APP_NAME="key-server-test" # Name for the test container/service
LOCAL_APP_BINARY="./${APP_NAME}" # Path to the local binary

# Derived Kubernetes full application name (release-name-chart-name)
# Based on Chart.yaml name: key-server-app and Helm release name: key-server
K8S_FULL_APP_NAME="${APP_NAME}-key-server-app"

# Monitoring Stack Configuration
PROMETHEUS_STACK_RELEASE_NAME="prometheus-stack"
PROMETHEUS_NAMESPACE="prometheus-operator"
GRAFANA_SECRET_NAME="grafana-admin-secret" # Name of the Kubernetes Secret for Grafana admin password

# --- Helper Functions ---
log_info() {
    echo -e "[INFO] $1"
}

log_success() {
    echo -e "[SUCCESS] $1"
}

log_error() {
    echo -e "[ERROR] $1"
    # Do not exit here, allow other cleanup steps to run, but print the error
}

# Function to clean up local Go processes
cleanup_local_go_processes() {
    log_info "Starting cleanup of local Go application processes and binary..."
    if pgrep -f "${APP_NAME}" > /dev/null; then
        log_info "Found existing '${APP_NAME}' processes. Killing them..."
        pkill -f "${APP_NAME}" || log_error "Failed to kill local '${APP_NAME}' processes."
        log_success "Killed existing '${APP_NAME}' processes."
    else
        log_info "No local '${APP_NAME}' processes found running."
    fi

    # Ensure the local binary is removed
    if [ -f "${LOCAL_APP_BINARY}" ]; then
        log_info "Found local application binary '${LOCAL_APP_BINARY}'. Removing it..."
        rm "${LOCAL_APP_BINARY}" || log_error "Failed to remove local '${LOCAL_APP_BINARY}'."
        log_success "Local application binary '${LOCAL_APP_BINARY}' removed."
    else
        log_info "No local application binary '${LOCAL_APP_BINARY}' found."
    fi
    log_info "Finished cleanup of local Go application processes and binary."
}

# Function to clean up Docker containers and images
cleanup_docker() {
    log_info "Starting cleanup of Docker containers and images..."

    log_info "Checking for Docker container '${APP_NAME}'..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
        log_info "Found Docker container '${APP_NAME}'. Stopping and removing it..."
        docker stop "${APP_NAME}" >/dev/null 2>&1 || true # Suppress errors if already stopped
        docker rm "${APP_NAME}" >/dev/null 2>&1 || true   # Suppress errors if already removed
        log_success "Docker container '${APP_NAME}' stopped and removed."
    else
        log_info "No Docker container '${APP_NAME}' found."
    fi

    log_info "Checking for Docker container '${TEST_APP_NAME}'..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_APP_NAME}$"; then
        log_info "Found Docker container '${TEST_APP_NAME}'. Stopping and removing it..."
        docker stop "${TEST_APP_NAME}" >/dev/null 2>&1 || true
        docker rm "${TEST_APP_NAME}" >/dev/null 2>&1 || true
        log_success "Docker container '${TEST_APP_NAME}' stopped and removed."
    else
        log_info "No Docker container '${TEST_APP_NAME}' found."
    fi
    
    log_info "Checking for Docker image '${APP_NAME}'..."
    if docker images -q "${APP_NAME}" > /dev/null; then
        log_info "Found Docker image '${APP_NAME}'. Removing it..."
        docker rmi "${APP_NAME}" >/dev/null 2>&1 || true # Suppress errors if image is in use (shouldn't be after container removal)
        log_success "Docker image '${APP_NAME}' removed."
    else
        log_info "No Docker image for '${APP_NAME}' found."
    fi
    log_info "Finished cleanup of Docker containers and images."
}

# Function to clean up Kubernetes resources
cleanup_kubernetes() {
    log_info "Starting cleanup of Kubernetes resources..."

    log_info "Checking for active kubectl port-forward sessions..."
    if pgrep -f "kubectl port-forward" > /dev/null; then
        log_info "Found active kubectl port-forward sessions. Killing them..."
        pkill -f "kubectl port-forward" || log_error "Failed to kill kubectl port-forward sessions."
        log_success "Killed existing kubectl port-forward sessions."
    else
        log_info "No kubectl port-forward sessions found."
    fi # This 'fi' was potentially missing or misplaced in previous snippets.

    # Check and delete Helm release if it exists
    log_info "Checking for Helm release '${APP_NAME}'..."
    if helm status "${APP_NAME}" &> /dev/null; then
        log_info "Found Helm release '${APP_NAME}'. Uninstalling it..."
        helm uninstall "${APP_NAME}" || log_error "Failed to uninstall Helm release '${APP_NAME}'."
        log_success "Helm release '${APP_NAME}' successfully uninstalled."
    else
        log_info "No Helm release '${APP_NAME}' found."
    fi

    # Uninstall Prometheus stack if it exists
    log_info "Checking for Helm release '${PROMETHEUS_STACK_RELEASE_NAME}' in namespace '${PROMETHEUS_NAMESPACE}'..."
    if helm status "${PROMETHEUS_STACK_RELEASE_NAME}" --namespace "${PROMETHEUS_NAMESPACE}" &> /dev/null; then
        log_info "Found Helm release '${PROMETHEUS_STACK_RELEASE_NAME}'. Uninstalling it..."
        helm uninstall "${PROMETHEUS_STACK_RELEASE_NAME}" --namespace "${PROMETHEUS_NAMESPACE}" || log_error "Failed to uninstall Prometheus stack Helm release '${PROMETHEUS_STACK_RELEASE_NAME}'."
        log_success "Prometheus stack Helm release '${PROMETHEUS_STACK_RELEASE_NAME}' successfully uninstalled."
    else
        log_info "No Prometheus stack Helm release '${PROMETHEUS_STACK_RELEASE_NAME}' found."
    fi

    # Delete Grafana admin secret if it exists
    log_info "Checking for Grafana admin secret '${GRAFANA_SECRET_NAME}' in namespace '${PROMETHEUS_NAMESPACE}'..."
    if kubectl get secret "${GRAFANA_SECRET_NAME}" -n "${PROMETHEUS_NAMESPACE}" &> /dev/null; then
        log_info "Found Grafana admin secret '${GRAFANA_SECRET_NAME}'. Deleting it..."
        kubectl delete secret "${GRAFANA_SECRET_NAME}" -n "${PROMETHEUS_NAMESPACE}" || log_error "Failed to delete Grafana admin secret '${GRAFANA_SECRET_NAME}'."
        log_success "Grafana admin secret '${GRAFANA_SECRET_NAME}' successfully deleted."
    else
        log_info "Grafana admin secret '${GRAFANA_SECRET_NAME}' not found."
    fi

    # Delete the prometheus-operator namespace
    log_info "Checking for namespace '${PROMETHEUS_NAMESPACE}'..."
    if kubectl get ns "${PROMETHEUS_NAMESPACE}" &> /dev/null; then
        log_info "Found namespace '${PROMETHEUS_NAMESPACE}'. Attempting to delete it..."
        # Use --wait=false to not block on initial delete, then loop for termination
        kubectl delete ns "${PROMETHEUS_NAMESPACE}" --wait=false || log_error "Initial attempt to delete namespace '${PROMETHEUS_NAMESPACE}' failed."
        log_info "Waiting for namespace '${PROMETHEUS_NAMESPACE}' to terminate (timeout: 120s)..."
        local timeout=120 # 2 minutes timeout
        local start_time=$(date +%s)
        while kubectl get ns "${PROMETHEUS_NAMESPACE}" &> /dev/null; do
            current_time=$(date +%s)
            if (( current_time - start_time > timeout )); then
                log_error "Timeout waiting for namespace '${PROMETHEUS_NAMESPACE}' to terminate. Attempting aggressive deletion."
                # Aggressive deletion as a last resort
                kubectl delete ns "${PROMETHEUS_NAMESPACE}" --force --grace-period=0 --timeout=60s || log_error "Forced deletion of namespace '${PROMETHEUS_NAMESPACE}' failed."
                break
            fi
            sleep 5
        done
        if ! kubectl get ns "${PROMETHEUS_NAMESPACE}" &> /dev/null; then
            log_success "Namespace '${PROMETHEUS_NAMESPACE}' successfully deleted."
        else
            log_error "Namespace '${PROMETHEUS_NAMESPACE}' still exists after cleanup attempts. Manual intervention may be required."
        fi
    else
        log_info "Namespace '${PROMETHEUS_NAMESPACE}' not found."
    fi

    # Delete Kind cluster if it exists
    log_info "Checking for Kind cluster '${APP_NAME}'..."
    if command -v kind &> /dev/null && kind get clusters | grep -q "^${APP_NAME}$"; then
        log_info "Found Kind cluster '${APP_NAME}'. Deleting it..."
        kind delete cluster --name "${APP_NAME}" || log_error "Failed to delete Kind cluster '${APP_NAME}'."
        log_success "Kind cluster '${APP_NAME}' successfully deleted."
    else
        log_info "No Kind cluster '${APP_NAME}' found."
    fi

    # Explicitly delete the kubectl context for the Kind cluster
    log_info "Checking for kubectl context 'kind-${APP_NAME}'..."
    if kubectl config get-contexts | grep -q "kind-${APP_NAME}"; then
        log_info "Found kubectl context 'kind-${APP_NAME}'. Deleting it..."
        kubectl config delete-context "kind-${APP_NAME}" >/dev/null 2>&1 || log_error "Failed to delete kubectl context 'kind-${APP_NAME}'."
        log_success "Kubectl context 'kind-${APP_NAME}' successfully deleted."
    else
        log_info "No kubectl context 'kind-${APP_NAME}' found."
    fi

    # Clean up any remaining kubectl resources for Key Server (e.g., if Helm failed or wasn't used)
    log_info "Attempting to delete any remaining Kubernetes resources for '${K8S_FULL_APP_NAME}' not managed by Helm uninstall..."
    
    log_info "Checking for Deployment '${K8S_FULL_APP_NAME}'..."
    if kubectl get deployment "${K8S_FULL_APP_NAME}" &> /dev/null; then
        kubectl delete deployment "${K8S_FULL_APP_NAME}" --ignore-not-found=true || true
        log_success "Deployment '${K8S_FULL_APP_NAME}' deletion attempted and command completed."
    else
        log_info "No Deployment '${K8S_FULL_APP_NAME}' found."
    fi

    log_info "Checking for Service '${K8S_FULL_APP_NAME}'..."
    if kubectl get service "${K8S_FULL_APP_NAME}" &> /dev/null; then
        kubectl delete service "${K8S_FULL_APP_NAME}" --ignore-not-found=true || true
        log_success "Service '${K8S_FULL_APP_NAME}' deletion attempted and command completed."
    else
        log_info "No Service '${K8S_FULL_APP_NAME}' found."
    fi

    log_info "Checking for Secret '${K8S_FULL_APP_NAME}-tls-secret'..."
    if kubectl get secret "${K8S_FULL_APP_NAME}-tls-secret" &> /dev/null; then
        kubectl delete secret "${K8S_FULL_APP_NAME}-tls-secret" --ignore-not-found=true || true
        log_success "Secret '${K8S_FULL_APP_NAME}-tls-secret' deletion attempted and command completed."
    else
        log_info "No Secret '${K8S_FULL_APP_NAME}-tls-secret' found."
    fi

    log_info "Checking for Ingress '${K8S_FULL_APP_NAME}-ingress'..."
    if kubectl get ingress "${K8S_FULL_APP_NAME}-ingress" &> /dev/null; then
        kubectl delete ingress "${K8S_FULL_APP_NAME}-ingress" --ignore-not-found=true || true
        log_success "Ingress '${K8S_FULL_APP_NAME}-ingress' deletion attempted and command completed."
    else
        log_info "No Ingress '${K8S_FULL_APP_NAME}-ingress' found."
    fi
    log_info "Finished cleanup of remaining Kubernetes resources."
}

# --- Main Cleanup Execution ---
comprehensive_cleanup() {
    echo "--- Starting Comprehensive Cleanup ---"
    cleanup_local_go_processes
    cleanup_docker
    cleanup_kubernetes
    echo "--- Comprehensive cleanup complete. Environment is ready for a fresh setup. ---"
}

# Execute the comprehensive cleanup
comprehensive_cleanup

echo "--- Cleanup script finished. ---"
