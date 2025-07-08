#!/bin/bash

# cleanup_all_deployments.sh
# This script stops and removes all local deployments related to the Key Server application.
# It should be run from the project's root directory.

set -e # Exit immediately if a command exits with a non-zero status

# Configuration (must match your project's naming)
PROJECT_NAME="key-server" # Name used for local executable, Docker container, and Helm release
HELM_CHART_PATH="./deploy/kubernetes/key-server-chart" # Path to your Helm chart

# Function to print colored output
print_status() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_warning() {
    echo "[WARNING] $1"
}

print_error() {
    echo "[ERROR] $1"
}

print_step() {
    echo "--- $1 ---"
}

# --- Cleanup Local Go Application ---
cleanup_local_app() {
    print_step "Cleaning up local Go application processes"
    if pgrep -f "./$PROJECT_NAME --srv-port" > /dev/null; then
        print_status "Stopping running local '$PROJECT_NAME' processes..."
        pkill -f "./$PROJECT_NAME --srv-port"
        print_success "Local '$PROJECT_NAME' processes stopped."
    else
        print_status "No local '$PROJECT_NAME' processes found running."
    fi
    # Optionally remove the executable itself
    if [ -f "./$PROJECT_NAME" ]; then
        print_status "Removing local '$PROJECT_NAME' executable..."
        rm "./$PROJECT_NAME"
        print_success "Local '$PROJECT_NAME' executable removed."
    fi
}

# --- Cleanup Docker Containers and Images ---
cleanup_docker() {
    print_step "Cleaning up Docker containers and images"

    # Stop and remove running/exited containers
    local containers_to_remove=$(docker ps -aq --filter "name=$PROJECT_NAME" --filter "name=${PROJECT_NAME}-test")
    if [ -n "$containers_to_remove" ]; then
        print_status "Stopping and removing Docker containers: $PROJECT_NAME, ${PROJECT_NAME}-test..."
        docker stop $containers_to_remove >/dev/null 2>&1 || true
        docker rm $containers_to_remove >/dev/null 2>&1 || true
        print_success "Docker containers stopped and removed."
    else
        print_status "No Docker containers for '$PROJECT_NAME' found."
    fi

    # Remove images (optional, but good for clean slate)
    local images_to_remove=$(docker images -q "$PROJECT_NAME")
    if [ -n "$images_to_remove" ]; then
        print_status "Removing Docker images for '$PROJECT_NAME'..."
        docker rmi $images_to_remove >/dev/null 2>&1 || true
        print_success "Docker images removed."
    else
        print_status "No Docker images for '$PROJECT_NAME' found."
    fi
}

# --- Cleanup Kubernetes Deployments (Helm and Kind) ---
cleanup_kubernetes() {
    print_step "Cleaning up Kubernetes deployments"

    # Stop any active kubectl port-forward sessions
    if pgrep -f "kubectl port-forward service/$PROJECT_NAME" > /dev/null; then
        print_status "Stopping kubectl port-forward sessions..."
        pkill -f "kubectl port-forward service/$PROJECT_NAME"
        print_success "kubectl port-forward sessions stopped."
    else
        print_status "No kubectl port-forward sessions found for '$PROJECT_NAME'."
    fi

    # Uninstall Helm release
    if helm status "$PROJECT_NAME" &> /dev/null; then
        print_status "Uninstalling Helm release '$PROJECT_NAME'..."
        helm uninstall "$PROJECT_NAME"
        print_success "Helm release '$PROJECT_NAME' uninstalled."
    else
        print_status "No Helm release '$PROJECT_NAME' found."
    fi

    # Delete Kind cluster
    if kind get clusters | grep -q "^$PROJECT_NAME$"; then
        print_status "Deleting Kind cluster '$PROJECT_NAME'..."
        kind delete cluster --name "$PROJECT_NAME"
        print_success "Kind cluster '$PROJECT_NAME' deleted."
    else
        print_status "No Kind cluster '$PROJECT_NAME' found."
    fi
}

# --- Main Cleanup Logic ---
main_cleanup() {
    echo "--- Starting Comprehensive Cleanup ---"
    
    cleanup_local_app
    cleanup_docker
    cleanup_kubernetes

    print_success "Comprehensive cleanup complete. Environment is ready for a fresh setup."
    echo "--------------------------------------"
}

# Execute the main cleanup function
main_cleanup