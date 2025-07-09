#!/bin/bash

# cleanup.sh
# This script performs a comprehensive cleanup of the Key Server application's
# build artifacts, Docker containers/images, and Kubernetes resources.

set -euo pipefail

# --- Configuration ---
APP_NAME="key-server"
TEST_APP_NAME="key-server-test" # Name for the test container/service
LOCAL_APP_BINARY="./${APP_NAME}" # Path to the local binary

# Derived Kubernetes full application name (release-name-chart-name)
# Based on Chart.yaml name: key-server-app and Helm release name: key-server
K8S_FULL_APP_NAME="${APP_NAME}-key-server-app"


# --- Helper Functions ---
log_info() {
    echo -e "[INFO] $1"
}

log_success() {
    echo -e "[SUCCESS] $1"
}

log_error() {
    echo -e "[ERROR] $1"
    # Do not exit here, allow other cleanup steps to run
}

# Function to clean up local Go processes
cleanup_local_go_processes() {
    log_info "Cleaning up local Go application processes..."
    if pgrep -f "${APP_NAME}" > /dev/null; then
        pkill -f "${APP_NAME}" || log_error "Failed to kill local '${APP_NAME}' processes."
        log_info "Killed existing '${APP_NAME}' processes."
    else
        log_info "No local '${APP_NAME}' processes found running."
    fi
    # Ensure the local binary is removed
    if [ -f "${LOCAL_APP_BINARY}" ]; then
        rm "${LOCAL_APP_BINARY}" || log_error "Failed to remove local '${LOCAL_APP_BINARY}'."
        log_info "Removing local '${LOCAL_APP_BINARY}' executable..."
        log_success "Local '${LOCAL_APP_BINARY}' executable removed."
    else
        log_info "No local '${LOCAL_APP_BINARY}' executable found."
    fi
}

# Function to clean up Docker containers and images
cleanup_docker() {
    log_info "Stopping and removing Docker containers: ${APP_NAME}, ${TEST_APP_NAME}..."
    docker stop "${APP_NAME}" "${TEST_APP_NAME}" >/dev/null 2>&1 || true
    docker rm "${APP_NAME}" "${TEST_APP_NAME}" >/dev/null 2>&1 || true
    log_success "Docker containers stopped and removed."

    log_info "Removing Docker images for '${APP_NAME}'..."
    if docker images -q "${APP_NAME}" > /dev/null; then
        docker rmi "${APP_NAME}" >/dev/null 2>&1 || true
        log_success "Docker images for '${APP_NAME}' removed."
    else
        log_info "No Docker images for '${APP_NAME}' found."
    fi
}

# Function to clean up Kubernetes resources
cleanup_kubernetes() {
    log_info "Cleaning up Kubernetes deployments..."
    # Kill any kubectl port-forward sessions
    if pgrep -f "kubectl port-forward" > /dev/null; then
        pkill -f "kubectl port-forward" || log_error "Failed to kill kubectl port-forward sessions."
        log_info "Killed existing kubectl port-forward sessions."
    else
        log_info "No kubectl port-forward sessions found."
    fi

    # Check and delete Helm release if it exists
    if helm status "${APP_NAME}" &> /dev/null; then
        log_info "Uninstalling Helm release '${APP_NAME}'..."
        helm uninstall "${APP_NAME}" || log_error "Failed to uninstall Helm release."
        log_success "Helm release '${APP_NAME}' uninstalled."
    else
        log_info "No Helm release '${APP_NAME}' found."
    fi

    # Delete Kind cluster if it exists
    if command -v kind &> /dev/null && kind get clusters | grep -q "${APP_NAME}"; then
        log_info "Deleting Kind cluster '${APP_NAME}'..."
        kind delete cluster --name "${APP_NAME}" || log_error "Failed to delete Kind cluster."
        log_success "Kind cluster '${APP_NAME}' deleted."
    else
        log_info "No Kind cluster '${APP_NAME}' found."
    fi

    # Explicitly delete the kubectl context for the Kind cluster
    # This is crucial if Kind cluster creation was interrupted
    if kubectl config get-contexts | grep -q "kind-${APP_NAME}"; then
        log_info "Deleting kubectl context 'kind-${APP_NAME}'..."
        kubectl config delete-context "kind-${APP_NAME}" >/dev/null 2>&1 || log_error "Failed to delete kubectl context 'kind-${APP_NAME}'."
        log_success "Kubectl context 'kind-${APP_NAME}' deleted."
    else
        log_info "No kubectl context 'kind-${APP_NAME}' found."
    fi

    # Clean up any remaining kubectl resources (e.g., if Helm failed or wasn't used)
    log_info "Attempting to delete any remaining Kubernetes resources..."
    kubectl delete deployment "${K8S_FULL_APP_NAME}" --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl delete service "${K8S_FULL_APP_NAME}" --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl delete secret "${APP_NAME}-tls-secret" --ignore-not-found=true >/dev/null 2>&1 || true
    kubectl delete ingress "${K8S_FULL_APP_NAME}-ingress" --ignore-not-found=true >/dev/null 2>&1 || true
    log_success "Attempted cleanup of remaining Kubernetes resources."
}

# --- Main Cleanup Execution ---
echo "--- Starting Comprehensive Cleanup ---"
cleanup_local_go_processes
cleanup_docker
cleanup_kubernetes
echo "--- Comprehensive cleanup complete. Environment is ready for a fresh setup. ---"
