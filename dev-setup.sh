#!/bin/bash

# Universal Development Environment Setup Script for Key Server

# set -e # <--- KEEP THIS COMMENTED OUT FOR NOW, UNTIL WE CONFIRM IT RUNS CLEANLY

# --- Configuration ---
PROJECT_NAME="key-server"
DEFAULT_PORT="8443" # Default port for HTTPS
DEFAULT_MAX_SIZE="1024"
HELM_CHART_PATH="./deploy/kubernetes/key-server-chart"
K8S_NAMESPACE="default" # Namespace where the secret and app will be deployed

# --- Utility Functions for Colored Output (MOVED TO TOP) ---
print_header() {
    echo "════════════════════════════════════════"
    echo "  Key Server Development Setup"
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

# --- OS Detection ---
detect_os() {
    echo "DEBUG: Running detect_os"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            OS="ubuntu"
        elif command -v yum &> /dev/null; then
            OS="centos" # Add specific installation steps for CentOS if needed
        else
            OS="linux" # Generic Linux, will require manual install guidance
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        OS="windows" # Add specific installation steps for Windows if needed
    else
        OS="unknown"
    fi
    print_status "Detected OS: $OS"
    echo "DEBUG: detect_os finished"
}

# --- Install Prerequisites based on OS ---
install_prerequisites() {
    print_step "Checking and installing prerequisites for $OS..."
    echo "DEBUG: Running install_prerequisites"
    
    case $OS in
        "macos")
            # Check if Homebrew is installed
            if ! command -v brew &> /dev/null; then
                print_status "Homebrew not found. Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                echo "DEBUG: Homebrew install exit code: $?"
                if [ $? -ne 0 ]; then print_error "Homebrew installation failed."; exit 1; fi
            fi
            
            # Install tools via Homebrew
            print_status "Installing/updating Go, Docker, kubectl, Helm, Kind, OpenSSL, curl via Homebrew..."
            brew install go docker kubectl helm kind openssl curl
            echo "DEBUG: brew install tools exit code: $?"
            if [ $? -ne 0 ]; then print_error "Homebrew installation of tools failed."; exit 1; fi
            ;;
            
        "ubuntu")
            print_status "Updating apt repositories..."
            sudo apt update
            echo "DEBUG: apt update exit code: $?"

            # Install Go
            if ! command -v go &> /dev/null; then
                print_status "Installing Go..."
                sudo apt-get install -y golang-go
                echo "DEBUG: Go install exit code: $?"
                if [ $? -ne 0 ]; then print_error "Go installation failed."; exit 1; fi
            fi
            
            # Install Docker (using official convenience script)
            if ! command -v docker &> /dev/null; then
                print_status "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                echo "DEBUG: curl get-docker.sh exit code: $?"
                sudo sh get-docker.sh
                echo "DEBUG: sh get-docker.sh exit code: $?"
                sudo usermod -aG docker "$USER" # Add current user to docker group
                echo "DEBUG: usermod exit code: $?"
                rm get-docker.sh
                print_warning "Docker group added. You might need to logout and log back in for changes to take effect."
                print_warning "After logging back in, run 'docker info' to verify."
            fi
            
            # Install kubectl
            if ! command -v kubectl &> /dev/null; then
                print_status "Installing kubectl..."
                sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
                echo "DEBUG: apt-get update/install exit code: $?"
                curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                echo "DEBUG: kubectl key install exit code: $?"
                echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
                echo "DEBUG: kubectl repo add exit code: $?"
                sudo apt-get update
                echo "DEBUG: apt-get update 2 exit code: $?"
                sudo apt-get install -y kubectl
                echo "DEBUG: kubectl install exit code: $?"
                if [ $? -ne 0 ]; then print_error "kubectl installation failed."; exit 1; fi
            fi
            
            # Install Helm
            if ! command -v helm &> /dev/null; then
                print_status "Installing Helm..."
                curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
                echo "DEBUG: helm key install exit code: $?"
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null
                echo "DEBUG: helm repo add exit code: $?"
                sudo apt-get update
                echo "DEBUG: apt-get update 3 exit code: $?"
                sudo apt-get install -y helm
                echo "DEBUG: helm install exit code: $?"
                if [ $? -ne 0 ]; then print_error "Helm installation failed."; exit 1; fi
            fi
            
            # Install Kind
            if ! command -v kind &> /dev/null; then
                print_status "Installing Kind..."
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
                echo "DEBUG: curl kind exit code: $?"
                chmod +x ./kind
                echo "DEBUG: chmod kind exit code: $?"
                sudo mv ./kind /usr/local/bin/kind
                echo "DEBUG: mv kind exit code: $?"
                if [ $? -ne 0 ]; then print_error "Kind installation failed."; exit 1; fi
            fi

            # Install OpenSSL (usually pre-installed, but for completeness)
            if ! command -v openssl &> /dev/null; then
                print_status "Installing OpenSSL..."
                sudo apt-get install -y openssl
                echo "DEBUG: openssl install exit code: $?"
                if [ $? -ne 0 ]; then print_error "OpenSSL installation failed."; exit 1; fi
            fi

            # Install curl (usually pre-installed)
            if ! command -v curl &> /dev/null; then
                print_status "Installing curl..."
                sudo apt-get install -y curl
                echo "DEBUG: curl install exit code: $?"
                if [ $? -ne 0 ]; then print_error "curl installation failed."; exit 1; fi
            fi
            ;;
            
        *)
            print_warning "Automated installation not fully supported for $OS."
            print_status "Please install the following tools manually:"
            echo "  - Go 1.22+"
            echo "  - Docker Desktop (with Kubernetes enabled for macOS/Windows)"
            echo "  - kubectl"
            echo "  - Helm 3+"
            echo "  - Kind (for local Kubernetes testing)"
            echo "  - OpenSSL"
            echo "  - curl"
            read -p "Press Enter when all tools are installed..."
            ;;
    esac
    echo "DEBUG: install_prerequisites finished"
}

# --- Verify all tools are installed ---
verify_tools() {
    print_step "Verifying tool installations..."
    echo "DEBUG: Running verify_tools"
    
    local tools=("go" "docker" "kubectl" "helm" "kind" "openssl" "curl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_status "$tool: Installed"
        else
            print_error "$tool: Not found"
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing tools: ${missing_tools[*]}"
        print_status "Please install missing tools and run the script again."
        exit 1
    fi
    
    print_success "All required tools are installed!"
    echo "DEBUG: verify_tools finished"
}

# --- Generate self-signed certificates ---
generate_certificates() {
    print_step "Generating self-signed SSL certificates (server.crt, server.key)..."
    echo "DEBUG: Running generate_certificates"
    if [ -f "server.crt" ] && [ -f "server.key" ]; then
        print_warning "server.crt and server.key already exist. Skipping generation."
    else
        openssl genrsa -out server.key 2048
        echo "DEBUG: openssl genrsa exit code: $?"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=localhost"
        echo "DEBUG: openssl req exit code: $?"
        if [ $? -ne 0 ]; then
            print_error "Failed to generate SSL certificates. Please check OpenSSL installation."
            exit 1
        fi
        print_success "Certificates generated: server.crt, server.key"
    fi
    echo "DEBUG: generate_certificates finished"
}

# --- Create Kind Cluster ---
create_kind_cluster() {
    print_step "Creating Kind cluster '$PROJECT_NAME' (if it doesn't exist)..."
    echo "DEBUG: Running create_kind_cluster"
    
    # Check if Kind cluster already exists
    if kind get clusters | grep -q "^$PROJECT_NAME$"; then
        print_warning "Kind cluster '$PROJECT_NAME' already exists. Skipping creation."
    else
        # Ensure Docker Desktop is running if on macOS/Windows
        if [[ "$OS" == "macos" || "$OS" == "windows" ]]; then
            if ! docker info &> /dev/null; then
                print_status "Docker Desktop is not running. Attempting to start it..."
                open -a Docker # macOS specific command to open Docker Desktop
                echo "DEBUG: open Docker exit code: $?"
                sleep 15 # Give Docker Desktop some time to fully initialize
                if ! docker info &> /dev/null; then
                    print_error "Docker Desktop failed to start. Please start it manually and rerun this script."
                    exit 1
                fi
            fi
        fi

        kind create cluster --name "$PROJECT_NAME"
        echo "DEBUG: kind create cluster exit code: $?"
        if [ $? -ne 0 ]; then print_error "Kind cluster creation failed."; exit 1; fi
        print_success "Kind cluster '$PROJECT_NAME' created successfully."
    fi

    print_status "Waiting for Kind cluster node to be Ready..."
    # Node name in Kind is typically <cluster-name>-control-plane
    kubectl wait --for=condition=ready node/"$PROJECT_NAME"-control-plane --timeout=300s
    echo "DEBUG: kubectl wait node exit code: $?"
    if [ $? -ne 0 ]; then
        print_error "Kind cluster node did not become ready in time. Please check 'kubectl get nodes'."
        exit 1
    fi
    print_success "Kind cluster node is Ready."
    echo "DEBUG: create_kind_cluster finished"
}

# --- Create Kubernetes TLS Secret ---
create_k8s_tls_secret() {
    print_step "Creating Kubernetes TLS secret '$PROJECT_NAME-tls-secret' in namespace '$K8S_NAMESPACE'..."
    echo "DEBUG: Running create_k8s_tls_secret"
    local secret_name="$PROJECT_NAME-tls-secret"

    # Check if secret already exists
    if kubectl get secret "$secret_name" -n "$K8S_NAMESPACE" &> /dev/null; then
        print_warning "Kubernetes secret '$secret_name' already exists. Skipping creation."
        return 0
    fi

    # Check if cert files exist before creating secret
    if [ ! -f "server.crt" ] || [ ! -f "server.key" ]; then
        print_error "server.crt or server.key not found. Please generate certificates first."
        exit 1
    fi

    kubectl create secret tls "$secret_name" \
      --cert=server.crt \
      --key=server.key \
      --namespace "$K8S_NAMESPACE"
    echo "DEBUG: kubectl create secret exit code: $?"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create Kubernetes TLS secret '$secret_name'."
        exit 1
    fi
    print_success "Kubernetes TLS secret '$secret_name' created successfully."
    echo "DEBUG: create_k8s_tls_secret finished"
}

# --- Define and Export Environment Variables ---
define_env_vars() {
    print_step "Defining and exporting environment variables..."
    echo "DEBUG: Running define_env_vars"
    
    export CLUSTER_NAME="$PROJECT_NAME"
    export IMAGE_NAME="$PROJECT_NAME-app" # Using key-server-app as image name
    export IMAGE_TAG="latest" # Using 'latest' for development, consider unique tags for production
    export DOCKER_USERNAME="your-dockerhub-username" # <--- IMPORTANT: REPLACE WITH YOUR DOCKER HUB USERNAME!
    export HELM_CHART_PATH="./deploy/kubernetes/key-server-chart"
    export HELM_RELEASE_NAME="$PROJECT_NAME"
    export APP_SERVICE_NAME="${HELM_RELEASE_NAME}-${IMAGE_NAME}" # Corrected service name derivation
    export APP_CONTAINER_PORT="$DEFAULT_PORT" # The port your app listens on for HTTPS inside the container
    export APP_LOCAL_PORT="8443" # The local port to use for kubectl port-forward
    export K8S_NAMESPACE="$K8S_NAMESPACE" # Ensure K8S_NAMESPACE is exported

    echo "Environment variables set. Please verify DOCKER_USERNAME is correct."
    echo "HELM_RELEASE_NAME: $HELM_RELEASE_NAME"
    echo "HELM_CHART_PATH: $HELM_CHART_PATH"
    echo "IMAGE_NAME: $IMAGE_NAME"
    echo "IMAGE_TAG: $IMAGE_TAG"
    echo "DOCKER_USERNAME: $DOCKER_USERNAME"
    echo "APP_LOCAL_PORT: $APP_LOCAL_PORT"
    echo "APP_CONTAINER_PORT: $APP_CONTAINER_PORT"
    echo "K8S_NAMESPACE: $K8S_NAMESPACE"
    echo "APP_SERVICE_NAME: $APP_SERVICE_NAME"
    echo "DEBUG: define_env_vars finished"
}

# --- Main Execution ---
main() {
    print_header
    
    detect_os
    install_prerequisites
    verify_tools
    create_kind_cluster # Call the function to create/verify the Kind cluster
    generate_certificates
    create_k8s_tls_secret
    define_env_vars
    
    print_success "Key Server development environment setup completed successfully!"
    echo ""
    echo "--- Next Steps ---"
    echo "1. If you just installed Docker, you might need to logout and log back in for Docker group changes to take effect."
    echo "2. Build your Go application's Docker image: "
    echo "   docker build -t $IMAGE_NAME:$IMAGE_TAG ."
    echo "3. Load the image into your Kind cluster:"
    echo "   kind load docker-image $IMAGE_NAME:$IMAGE_TAG --name $CLUSTER_NAME"
    echo "4. Deploy the application using Helm:"
    echo "   helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART_PATH -f $HELM_CHART_PATH/values.yaml"
    echo "5. Access the application using kubectl port-forward:"
    echo "   kubectl port-forward service/$APP_SERVICE_NAME $APP_LOCAL_PORT:$APP_CONTAINER_PORT --namespace $K8S_NAMESPACE"
    echo "   Then access via curl (requires --insecure for self-signed certs):"
    echo "   curl --insecure https://localhost:$APP_LOCAL_PORT/health"
    echo "   curl --insecure https://localhost:$APP_LOCAL_PORT/key/32"
    echo "   In a browser, you will need to accept the self-signed certificate warning."
    echo ""
    echo "   Remember to 'source dev-setup.sh' in any new terminal session to reload environment variables."
}

# Run main function
main "$@"