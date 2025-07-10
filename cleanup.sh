#!/bin/bash

# cleanup.sh
# This script performs a comprehensive cleanup of local build artifacts,
# Docker containers/images, and Kubernetes resources created by the
# app_build_and_verification.sh script.

set -euo pipefail

# --- Configuration ---
APP_NAME="key-server" # This is the Helm Release Name and Docker Image Name
TEST_APP_NAME="key-server-test" # Name for the test container/service

# Derived Kubernetes full application name (release-name-chart-name)
# Based on Chart.yaml name: key-server-app and Helm release name: key-server
K8S_FULL_APP_NAME="${APP_NAME}-key-server-app"

# Monitoring Stack Configuration
PROMETHEUS_STACK_RELEASE_NAME="prometheus-stack"
PROMETHEUS_NAMESPACE="prometheus-operator"
GRAFANA_SECRET_NAME="grafana-admin-secret"

# Helm Repository Names
PROMETHEUS_HELM_REPO_NAME="prometheus-community"

# --- Helper Functions ---
log_step() {
    echo -e "\n[STEP] $1"
}

log_info() {
    echo -e "[INFO] $1"
}

log_success() {
    echo -e "[SUCCESS] $1"
}

log_error() {
    echo -e "[ERROR] $1"
    # Do NOT exit immediately on error within cleanup functions unless truly critical.
    # The 'set -e' is handled by specific checks or '|| true'.
    return 1 # Indicate failure, but allow script to continue if possible
}
# --- End Helper Functions ---


# Function to check if kubectl can connect to a cluster
# Returns 0 if connected, 1 otherwise
check_kubectl_connection() {
    # Check if a context is set and if the API server is reachable
    kubectl cluster-info > /dev/null 2>&1
    return $?
}

# Function to clean up local Go processes
cleanup_local_go_processes() {
    log_info "Starting cleanup of local Go application processes and binary..."
    # Find and kill processes named APP_NAME (e.g., key-server)
    if pgrep -f "${APP_NAME}" > /dev/null; then
        log_info "Killed existing '${APP_NAME}' processes."
        pkill -f "${APP_NAME}" || true # Use || true to prevent exit if process is already gone
    else
        log_info "No local '${APP_NAME}' processes found running."
    fi

    # Remove the local application binary
    if [ -f "./${APP_NAME}" ]; then
        log_info "Found local application binary './${APP_NAME}'. Removing it..."
        rm "./${APP_NAME}" || log_error "Failed to remove local application binary."
        log_success "Local application binary './${APP_NAME}' removed."
    else
        log_info "No local application binary './${APP_NAME}' found."
    fi
    log_info "Finished cleanup of local Go application processes and binary."
}

# Function to clean up Docker containers and images
cleanup_docker() {
    log_info "Starting cleanup of Docker containers and images..."
    # Stop and remove test container
    log_info "Checking for Docker container '${TEST_APP_NAME}'..."
    if docker ps -a --format '{{.Names}}' | grep -q "${TEST_APP_NAME}"; then
        log_info "Found Docker container '${TEST_APP_NAME}'. Stopping and removing it..."
        docker stop "${TEST_APP_NAME}" >/dev/null 2>&1 || true
        docker rm "${TEST_APP_NAME}" >/dev/null 2>&1 || true
        log_success "Docker container '${TEST_APP_NAME}' stopped and removed."
    else
        log_info "No Docker container '${TEST_APP_NAME}' found."
    fi

    # Stop and remove main app container (if it was run directly)
    log_info "Checking for Docker container '${APP_NAME}'..."
    if docker ps -a --format '{{.Names}}' | grep -q "${APP_NAME}"; then
        log_info "Found Docker container '${APP_NAME}'. Stopping and removing it..."
        docker stop "${APP_NAME}" >/dev/null 2>&1 || true
        docker rm "${APP_NAME}" >/dev/null 2>&1 || true
        log_success "Docker container '${APP_NAME}' stopped and removed."
    else
        log_info "No Docker container '${APP_NAME}' found."
    fi

    log_info "Checking for Docker image '${APP_NAME}'..."
    if docker images -q "${APP_NAME}" > /dev/null; then
        log_info "Found Docker image '${APP_NAME}'. Removing it..."
        docker rmi "${APP_NAME}" >/dev/null 2>&1 || true
        log_success "Docker image '${APP_NAME}' removed."
    else
        log_info "No Docker image '${APP_NAME}' found."
    fi
    log_info "Finished cleanup of Docker containers and images."
}

# Function to clean up Kubernetes resources
cleanup_kubernetes() {
    log_info "Starting cleanup of Kubernetes resources..."

    # Kill any kubectl port-forward sessions BEFORE cluster deletion
    log_info "Checking for active kubectl port-forward sessions..."
    if pgrep -f "kubectl port-forward" > /dev/null; then
        pkill -f "kubectl port-forward" || true
        log_info "Killed existing kubectl port-forward sessions."
    else
        log_info "No kubectl port-forward sessions found."
    fi

    # 1. Delete Kind cluster FIRST
    log_info "Checking for Kind cluster '${APP_NAME}'..."
    if command -v kind &> /dev/null && kind get clusters | grep -q "${APP_NAME}"; then
        log_info "Found Kind cluster '${APP_NAME}'. Deleting it..."
        kind delete cluster --name "${APP_NAME}" || log_error "Failed to delete Kind cluster."
        log_success "Kind cluster '${APP_NAME}' successfully deleted."
    else
        log_info "No Kind cluster '${APP_NAME}' found."
    fi

    # 2. Explicitly delete the kubectl context for the Kind cluster
    log_info "Checking for kubectl context 'kind-${APP_NAME}'..."
    if kubectl config get-contexts | grep -q "kind-${APP_NAME}"; then
        log_info "Found kubectl context 'kind-${APP_NAME}'. Deleting it..."
        kubectl config delete-context "kind-${APP_NAME}" >/dev/null 2>&1 || true
        log_success "Kubectl context 'kind-${APP_NAME}' successfully deleted."
    else
        log_info "No kubectl context 'kind-${APP_NAME}' found."
    fi

    # Now, check if kubectl can connect to *any* cluster before trying to delete resources
    if ! check_kubectl_connection; then
        log_info "kubectl is not connected to any cluster. Skipping in-cluster resource deletion."
        # If no connection, assume resources are already gone or unreachable, and exit this function gracefully.
        return 0
    fi

    # 3. Delete Helm releases
    log_info "Checking for Helm release '${APP_NAME}'..."
    if helm status "${APP_NAME}" --namespace default &> /dev/null; then
        log_info "Uninstalling Helm release '${APP_NAME}'..."
        helm uninstall "${APP_NAME}" --namespace default || true
        log_success "Helm release '${APP_NAME}' uninstalled."
    else
        log_info "No Helm release '${APP_NAME}' found."
    fi

    log_info "Checking for Helm release '${PROMETHEUS_STACK_RELEASE_NAME}' in namespace '${PROMETHEUS_NAMESPACE}'..."
    if helm status "${PROMETHEUS_STACK_RELEASE_NAME}" --namespace "${PROMETHEUS_NAMESPACE}" &> /dev/null; then
        log_info "Uninstalling Helm release '${PROMETHEUS_STACK_RELEASE_NAME}' in namespace '${PROMETHEUS_NAMESPACE}'..."
        helm uninstall "${PROMETHEUS_STACK_RELEASE_NAME}" --namespace "${PROMETHEUS_NAMESPACE}" || true
        log_success "Prometheus stack Helm release uninstalled."
    else
        log_info "No Prometheus stack Helm release '${PROMETHEUS_STACK_RELEASE_NAME}' found."
    fi

    # 4. Delete specific Kubernetes resources (secrets, configmaps)
    log_info "Deleting specific Grafana admin secret and dashboard ConfigMaps..."
    kubectl delete secret "${GRAFANA_SECRET_NAME}" -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true
    kubectl delete configmap key-server-http-overview-dashboard -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true
    kubectl delete configmap key-server-key-generation-dashboard -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true
    kubectl delete configmap grafana-custom-dashboards-provisioning -n "${PROMETHEUS_NAMESPACE}" --ignore-not-found=true || true
    log_success "Specific Grafana secrets and dashboard ConfigMaps deletion attempted."

    # 5. Delete the prometheus-operator namespace
    log_info "Checking for namespace '${PROMETHEUS_NAMESPACE}'..."
    if kubectl get ns "${PROMETHEUS_NAMESPACE}" &> /dev/null; then
        log_info "Attempting to force delete namespace '${PROMETHEUS_NAMESPACE}'..."
        kubectl delete ns "${PROMETHEUS_NAMESPACE}" --timeout=120s --grace-period=0 --force --ignore-not-found=true >/dev/null 2>&1 || true
        log_success "Namespace '${PROMETHEUS_NAMESPACE}' deletion attempted."
    else
        log_info "Namespace '${PROMETHEUS_NAMESPACE}' not found."
    fi

    # 6. Delete specific Prometheus CRDs that might be left behind
    log_info "Attempting to delete Prometheus-related CRDs..."
    CRDS_TO_DELETE=(
        "alertmanagerconfigs.monitoring.coreos.com"
        "alertmanagers.monitoring.coreos.com"
        "podmonitors.monitoring.coreos.com"
        "probes.monitoring.coreos.com"
        "prometheuses.monitoring.coreos.com"
        "prometheusrules.monitoring.coreos.com"
        "servicemonitors.monitoring.coreos.com"
        "thanosrulers.monitoring.coreos.com"
    )
    for crd in "${CRDS_TO_DELETE[@]}"; do
        log_info "Deleting CRD: $crd..."
        kubectl delete crd "$crd" --ignore-not-found=true --timeout=60s || true
        log_success "CRD $crd deletion attempted."
    done
    log_info "Finished attempting to delete Prometheus-related CRDs."

    # 7. Clean up any remaining kubectl resources (e.g., if Helm failed or wasn't used)
    log_info "Attempting to delete any remaining Kubernetes resources..."
    kubectl delete deployment "${K8S_FULL_APP_NAME}" --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl delete service "${K8S_FULL_APP_NAME}" --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl delete secret "${K8S_FULL_APP_NAME}-tls-secret" --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl delete ingress "${K8S_FULL_APP_NAME}-ingress" --ignore-not-found=true >/dev/null 2>&1 || true
    log_success "Attempted cleanup of remaining Kubernetes resources."

    # 8. Remove Helm repositories to clear local cache
    log_info "Removing Helm repositories to clear local cache..."
    if helm repo list | grep -q "${PROMETHEUS_HELM_REPO_NAME}"; then
        helm repo remove "${PROMETHEUS_HELM_REPO_NAME}" || true
        log_success "Prometheus Helm repository removed."
    else
        log_info "Prometheus Helm repository not found to remove."
    fi
    log_info "Finished cleanup of Kubernetes resources."
}


# --- Main Cleanup Function ---
comprehensive_cleanup() {
    echo "--- Starting Comprehensive Cleanup ---"
    cleanup_local_go_processes
    cleanup_docker
    cleanup_kubernetes
    echo "--- Comprehensive cleanup complete. Environment is ready for a fresh setup. ---"
}

# Call the main cleanup function
comprehensive_cleanup
