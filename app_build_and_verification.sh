#!/bin/bash

# Comprehensive Application Lifecycle Script
# This script handles building, testing, containerization, running,
# and deploying the Key Server application across different environments.

set -e # Exit immediately if a command exits with a non-zero status

# Configuration
PROJECT_NAME="key-server"
DEFAULT_PORT="8080"
DEFAULT_MAX_SIZE="1024"
HELM_CHART_PATH="./deploy/kubernetes/key-server-chart" # Ensure this path is correct relative to your script

# --- Helper Functions for Output ---
print_header() {
    echo "════════════════════════════════════════"
    echo "  Key Server Application Lifecycle Script"
    echo "════════════════════════════════════════"
    echo ""
}

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
    echo "[STEP] $1"
}

# --- Core Functions ---

# Detect operating system (needed for Docker start and some messages)
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            OS="ubuntu"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    print_status "Detected OS: $OS"
}

# Generate self-signed certificates
generate_certificates() {
    print_step "Generating self-signed SSL certificates (server.crt, server.key)..."
    if [ -f "server.crt" ] && [ -f "server.key" ]; then
        print_warning "server.crt and server.key already exist. Skipping generation."
    else
        openssl genrsa -out server.key 2048
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=localhost"
        if [ $? -ne 0 ]; then
            print_error "Failed to generate SSL certificates. Please check OpenSSL installation."
            exit 1
        fi
        print_success "Certificates generated: server.crt, server.key"
    fi
}

# Build and test the project locally
build_and_test_local() {
    print_step "Building and testing the project locally..."
    
    # Check for Go
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed. Please install Go before running this script."
        exit 1
    fi

    print_status "Tidying Go modules..."
    go mod tidy
    if [ $? -ne 0 ]; then print_error "Go mod tidy failed."; exit 1; fi

    print_status "Downloading Go modules..."
    go mod download
    go mod verify
    
    print_status "Building application executable..."
    go build -o "$PROJECT_NAME" .
    if [ $? -ne 0 ]; then print_error "Go application build failed."; exit 1; fi
    print_success "Application built: ./$PROJECT_NAME"
    
    print_status "Running local unit tests..."
    go test -v ./... # Run all tests in current dir and subdirs
    if [ $? -ne 0 ]; then print_error "Go unit tests failed. Please review test results."; exit 1; fi
    print_success "Local unit tests completed."
}

# Verify local application functionality
verify_local_app() {
    print_step "Verifying local application functionality (brief run)..."
    
    # Start the application in background for verification
    ./"$PROJECT_NAME" --srv-port "$DEFAULT_PORT" --max-size "$DEFAULT_MAX_SIZE" &
    APP_PID=$!
    sleep 3 # Give app time to start

    if ! command -v curl &> /dev/null; then
        print_warning "Curl is not installed. Skipping local application verification."
        kill "$APP_PID" 2>/dev/null || true
        return
    fi

    # Check for jq, needed for parsing JSON response from key generation
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq (e.g., 'brew install jq' on macOS, 'sudo apt-get install jq' on Debian/Ubuntu) to verify key generation."
        kill "$APP_PID" 2>/dev/null || true
        exit 1
    fi

    # Check for base64 command
    if ! command -v base64 &> /dev/null; then
        print_error "base64 command is not installed. Please install base64 (e.g., 'brew install coreutils' on macOS, 'sudo apt-get install coreutils' on Debian/Ubuntu) to verify key generation."
        kill "$APP_PID" 2>/dev/null || true
        exit 1
    fi

    # Test health endpoint
    if curl -sfk https://localhost:"$DEFAULT_PORT"/health > /dev/null; then
        print_success "Local health endpoint: SUCCESS"
    else
        print_error "Local health endpoint: FAILED"
        kill "$APP_PID" 2>/dev/null || true
        exit 1
    fi
    
    # Test key generation endpoint
    KEY_GEN_FULL_RESPONSE=$(curl -sfk https://localhost:"$DEFAULT_PORT"/key/16)
    echo "DEBUG: Raw Key Generation Response: '${KEY_GEN_FULL_RESPONSE}'"

    # Extract the key value from JSON using jq -r to get raw string
    KEY_VALUE=$(echo "${KEY_GEN_FULL_RESPONSE}" | jq -r '.key')
    
    echo "DEBUG: Extracted Key Value: '${KEY_VALUE}'"
    KEY_VALUE_LENGTH=${#KEY_VALUE}
    echo "DEBUG: Extracted Key Value Length: ${KEY_VALUE_LENGTH}"

    # Verify length and that it can be decoded to the expected byte length
    EXPECTED_KEY_BYTES=16 # For a /key/16 request
    
    # Check if the Base64 string has the expected length
    if [[ "${KEY_VALUE_LENGTH}" -ne 24 ]]; then
        print_error "Local key generation: FAILED (Expected 24-char Base64, Got: '${KEY_VALUE}' of length ${KEY_VALUE_LENGTH})"
        kill "$APP_PID" 2>/dev/null || true
        exit 1
    fi

    # Attempt to decode the Base64 string and check byte length
    # Use tr -d ' ' to remove any spaces from wc -c output
    # Use 2>/dev/null to suppress base64 errors if the string is malformed
    DECODE_CMD="base64 --decode"
    if [[ "$OS" == "macos" ]]; then
        DECODE_CMD="base64 -D"
    fi

    DECODED_KEY_BYTES=$(echo "${KEY_VALUE}" | ${DECODE_CMD} 2>/dev/null | wc -c | tr -d ' ')
    
    if [[ "$DECODED_KEY_BYTES" -eq "$EXPECTED_KEY_BYTES" ]]; then
        print_success "Local key generation (length 16): SUCCESS (Decoded to ${DECODED_KEY_BYTES} bytes)"
    else
        print_error "Local key generation: FAILED (Expected to decode to ${EXPECTED_KEY_BYTES} bytes, Got: ${DECODED_KEY_BYTES} bytes from '${KEY_VALUE}')"
        kill "$APP_PID" 2>/dev/null || true
        exit 1
    fi
    
    # Stop the application
    kill "$APP_PID" 2>/dev/null || true
    print_success "Local application verification complete."
}


# Build and run Docker image
build_and_run_docker() {
    print_step "Building and running Docker image..."

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker before running this script."
        exit 1
    fi
    
    # Start Docker if not running
    if ! docker info &> /dev/null; then
        print_status "Docker daemon is not running. Attempting to start Docker Desktop (macOS) or daemon (Linux)..."
        case $OS in
            "macos")
                open -a Docker
                print_status "Waiting for Docker Desktop to start... (This might take a moment)"
                sleep 20 # Give Docker Desktop some time to fully initialize
                ;;
            "ubuntu"|"linux")
                sudo systemctl start docker || true # Use || true to prevent script exit if already running
                sleep 5
                ;;
        esac
    fi

    if ! docker info &> /dev/null; then
      print_error "Docker daemon is not running after attempt to start. Please start Docker Desktop/daemon manually and rerun."
      exit 1
    fi
    print_success "Docker daemon is running."

    print_status "Building Docker image: $PROJECT_NAME:latest"
    docker build -t "$PROJECT_NAME":latest .
    if [ $? -ne 0 ]; then print_error "Docker image build failed."; exit 1; fi
    print_success "Docker image built."

    print_status "Stopping and removing any existing Docker container for '$PROJECT_NAME'..."
    docker stop "$PROJECT_NAME" >/dev/null 2>&1 || true
    docker rm "$PROJECT_NAME" >/dev/null 2>&1 || true

    print_status "Running Docker container: $PROJECT_NAME"
    docker run -d --name "$PROJECT_NAME" -p "$DEFAULT_PORT":"$DEFAULT_PORT" "$PROJECT_NAME":latest
    if [ $? -ne 0 ]; then print_error "Docker container failed to run."; exit 1; fi
    print_success "Docker container running on port $DEFAULT_PORT."
    sleep 5 # Give container time to start up
}

# Verify Dockerized application functionality
verify_docker_app() {
    print_step "Verifying Dockerized application functionality..."

    if ! command -v curl &> /dev/null; then
        print_warning "Curl is not installed. Skipping Dockerized application verification."
        return
    fi
    # Check for jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq to verify Dockerized key generation."
        return
    fi

    # Check for base64 command
    if ! command -v base64 &> /dev/null; then
        print_error "base64 command is not installed. Please install base64 (e.g., 'brew install coreutils' on macOS, 'sudo apt-get install coreutils' on Debian/Ubuntu) to verify key generation."
        return
    fi
    
    # Test health endpoint
    if curl -sfk https://localhost:"$DEFAULT_PORT"/health > /dev/null; then
        print_success "Docker health endpoint: SUCCESS"
    else
        print_error "Docker health endpoint: FAILED. Check container logs: docker logs $PROJECT_NAME"
        exit 1
    fi
    
    # Test key generation endpoint
    KEY_GEN_FULL_RESPONSE=$(curl -sfk https://localhost:"$DEFAULT_PORT"/key/16)
    KEY_VALUE=$(echo "${KEY_GEN_FULL_RESPONSE}" | jq -r '.key')

    EXPECTED_KEY_BYTES=16 # For a /key/16 request

    if [[ "${#KEY_VALUE}" -ne 24 ]]; then
        print_error "Docker key generation: FAILED (Expected 24-char Base64, Got: '${KEY_VALUE}' of length ${#KEY_VALUE})"
        exit 1
    fi

    DECODE_CMD="base64 --decode"
    if [[ "$OS" == "macos" ]]; then
        DECODE_CMD="base64 -D"
    fi

    DECODED_KEY_BYTES=$(echo "${KEY_VALUE}" | ${DECODE_CMD} 2>/dev/null | wc -c | tr -d ' ')

    if [[ "$DECODED_KEY_BYTES" -eq "$EXPECTED_KEY_BYTES" ]]; then
        print_success "Docker key generation (length 16): SUCCESS (Decoded to ${DECODED_KEY_BYTES} bytes)"
    else
        print_error "Docker key generation: FAILED (Expected to decode to ${EXPECTED_KEY_BYTES} bytes, Got: ${DECODED_KEY_BYTES} bytes from '${KEY_VALUE}'). Check container logs: docker logs $PROJECT_NAME"
        exit 1
    fi
    
    print_success "Dockerized application verification complete."
}

# Deploy and verify Kubernetes deployment
deploy_and_verify_kubernetes() {
    print_step "Deploying and verifying application on Kubernetes..."

    # Check for kubectl, helm, kind
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl."
        exit 1
    fi
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm."
        exit 1
    fi
    if ! command -v kind &> /dev/null; then
        print_error "Kind is not installed. Please install Kind."
        exit 1
    fi
    
    print_status "Creating Kind cluster (if not exists): $PROJECT_NAME"
    if ! kind get clusters | grep -q "^$PROJECT_NAME$"; then
        kind create cluster --name "$PROJECT_NAME"
        if [ $? -ne 0 ]; then print_error "Kind cluster creation failed."; exit 1; fi
        print_success "Kind cluster '$PROJECT_NAME' created."
    else
        print_warning "Kind cluster '$PROJECT_NAME' already exists. Reusing existing cluster."
    fi
    
    print_status "Setting kubectl context to kind-$PROJECT_NAME..."
    kubectl cluster-info --context kind-"$PROJECT_NAME"
    
    print_status "Building Docker image for Kubernetes and loading into Kind cluster..."
    docker build -t "$PROJECT_NAME":latest .
    if [ $? -ne 0 ]; then print_error "Docker image build failed for Kubernetes."; exit 1; fi
    
    kind load docker-image "$PROJECT_NAME":latest --name "$PROJECT_NAME"
    if [ $? -ne 0 ]; then print_error "Failed to load Docker image into Kind cluster."; exit 1; fi
    print_success "Docker image loaded into Kind cluster."
    
    print_status "Deploying with Helm: $PROJECT_NAME"
    # Ensure HELM_CHART_PATH points to the correct directory containing Chart.yaml
    if [ ! -d "$HELM_CHART_PATH" ]; then
        print_error "Helm chart path not found: $HELM_CHART_PATH. Please ensure the 'deploy/kubernetes/key-server-chart' directory exists."
        exit 1
    fi

    helm upgrade --install "$PROJECT_NAME" "$HELM_CHART_PATH" \
        --set image.pullPolicy=Never \
        --set application.maxSize=$DEFAULT_MAX_SIZE \
        --set application.srvPort=$DEFAULT_PORT \
        --wait --timeout=5m
    if [ $? -ne 0 ]; then print_error "Helm deployment failed."; exit 1; fi
    print_success "Helm chart deployed."
    
    print_status "Waiting for Kubernetes pods to be ready..."
    kubectl wait --for=condition=ready pod \
        --selector=app.kubernetes.io/name=$PROJECT_NAME \
        --timeout=300s
    if [ $? -ne 0 ]; then print_error "Kubernetes pods did not become ready in time."; exit 1; fi
    print_success "Kubernetes pods are ready."
}

# Verify Kubernetes deployed application functionality
verify_kubernetes_app() {
    print_step "Verifying Kubernetes deployed application functionality..."
    
    print_status "Setting up kubectl port-forward for verification..."
    # Ensure the service name matches your Helm chart's service name if different from PROJECT_NAME
    kubectl port-forward service/"$PROJECT_NAME" 8080:"$DEFAULT_PORT" &
    PORT_FORWARD_PID=$!
    sleep 5 # Give port-forward time to establish
    
    if ! command -v curl &> /dev/null; then
        print_warning "Curl is not installed. Skipping Kubernetes application verification."
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        return
    fi
    # Check for jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq to verify Kubernetes key generation."
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        return
    fi

    # Check for base64 command
    if ! command -v base64 &> /dev/null; then
        print_error "base64 command is not installed. Please install base64 (e.g., 'brew install coreutils' on macOS, 'sudo apt-get install coreutils') to verify key generation."
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        return
    fi

    # Test health endpoint (optional but good practice)
    if curl -sfk https://localhost:8080/health > /dev/null; then
        print_success "Kubernetes health endpoint: SUCCESS"
    else
        print_error "Kubernetes health endpoint: FAILED. Check pod logs: kubectl logs -f deployment/$PROJECT_NAME"
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        exit 1
    fi

    # Test key generation endpoint
    KEY_GEN_FULL_RESPONSE=$(curl -sfk https://localhost:8080/key/16)
    KEY_VALUE=$(echo "${KEY_GEN_FULL_RESPONSE}" | jq -r '.key')

    EXPECTED_KEY_BYTES=16 # For a /key/16 request

    if [[ "${#KEY_VALUE}" -ne 24 ]]; then
        print_error "Kubernetes key generation: FAILED (Expected 24-char Base64, Got: '${KEY_VALUE}' of length ${#KEY_VALUE})"
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        exit 1
    fi

    DECODE_CMD="base64 --decode"
    if [[ "$OS" == "macos" ]]; then
        DECODE_CMD="base64 -D"
    fi

    DECODED_KEY_BYTES=$(echo "${KEY_VALUE}" | ${DECODE_CMD} 2>/dev/null | wc -c | tr -d ' ')

    if [[ "$DECODED_KEY_BYTES" -eq "$EXPECTED_KEY_BYTES" ]]; then
        print_success "Kubernetes key generation (length 16): SUCCESS (Decoded to ${DECODED_KEY_BYTES} bytes)"
    else
        print_error "Kubernetes key generation: FAILED (Expected to decode to ${EXPECTED_KEY_BYTES} bytes, Got: ${DECODED_KEY_BYTES} bytes from '${KEY_VALUE}'). Check logs: kubectl logs -f deployment/$PROJECT_NAME"
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        exit 1
    fi
    
    # Stop port forwarding
    kill "$PORT_FORWARD_PID" 2>/dev/null || true
    print_success "Kubernetes application verification complete."
}

# --- Main Execution Flow ---
main() {
    print_header
    
    detect_os
    generate_certificates
    
    build_and_test_local
    verify_local_app # Verify local executable

    # --- Docker and Kubernetes verification ---
    build_and_run_docker
    verify_docker_app # Verify Docker container

    deploy_and_verify_kubernetes # UNCOMMENTED
    verify_kubernetes_app # Verify Kubernetes deployment # UNCOMMENTED

    print_success "All stages of the application lifecycle completed successfully!"
    echo ""
    echo "To clean up all deployments, run the separate 'cleanup_all_deployments.sh' script."
}

# --- Cleanup on Exit (for processes started by THIS script) ---
cleanup() {
    print_status "Performing cleanup of processes started by this script..."
    # Kill any lingering kubectl port-forwards
    pkill -f "kubectl port-forward service/$PROJECT_NAME" 2>/dev/null || true
    # Kill any local key-server processes (from local verification)
    pkill -f "./$PROJECT_NAME --srv-port $DEFAULT_PORT" 2>/dev/null || true # Use DEFAULT_PORT
    # Stop and remove temporary Docker container (if accidentally left)
    if docker ps -a --format '{{.Names}}' | grep -q "^$PROJECT_NAME$"; then
      docker stop "$PROJECT_NAME" >/dev/null 2>&1 || true
      docker rm "$PROJECT_NAME" >/dev/null 2>&1 || true
    fi
}

# Set up signal handling
trap cleanup SIGINT SIGTERM EXIT # Trap on EXIT as well for consistent cleanup

# Run the main function
main "$@"