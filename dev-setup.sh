#!/bin/bash

# Universal Development Environment Setup Script for Key Server

set -e # Exit immediately if a command exits with a non-zero status

# --- Configuration ---
PROJECT_NAME="key-server"
DEFAULT_PORT="8080"
DEFAULT_MAX_SIZE="1024"
HELM_CHART_PATH="./deploy/kubernetes/key-server-chart"

# --- Utility Functions for Colored Output ---
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
}

# --- Install Prerequisites based on OS ---
install_prerequisites() {
    print_step "Checking and installing prerequisites for $OS..."
    
    case $OS in
        "macos")
            # Check if Homebrew is installed
            if ! command -v brew &> /dev/null; then
                print_status "Homebrew not found. Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [ $? -ne 0 ]; then print_error "Homebrew installation failed."; exit 1; fi
            fi
            
            # Install tools via Homebrew
            print_status "Installing/updating Go, Docker, kubectl, Helm, Kind, OpenSSL, curl via Homebrew..."
            brew install go docker kubectl helm kind openssl curl
            if [ $? -ne 0 ]; then print_error "Homebrew installation of tools failed."; exit 1; fi
            ;;
            
        "ubuntu")
            print_status "Updating apt repositories..."
            sudo apt update
            
            # Install Go
            if ! command -v go &> /dev/null; then
                print_status "Installing Go..."
                sudo apt-get install -y golang-go
                if [ $? -ne 0 ]; then print_error "Go installation failed."; exit 1; fi
            fi
            
            # Install Docker (using official convenience script)
            if ! command -v docker &> /dev/null; then
                print_status "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker "$USER" # Add current user to docker group
                rm get-docker.sh
                print_warning "Docker group added. You might need to logout and log back in for changes to take effect."
                print_warning "After logging back in, run 'docker info' to verify."
            fi
            
            # Install kubectl
            if ! command -v kubectl &> /dev/null; then
                print_status "Installing kubectl..."
                sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
                curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y kubectl
                if [ $? -ne 0 ]; then print_error "kubectl installation failed."; exit 1; fi
            fi
            
            # Install Helm
            if ! command -v helm &> /dev/null; then
                print_status "Installing Helm..."
                curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y helm
                if [ $? -ne 0 ]; then print_error "Helm installation failed."; exit 1; fi
            fi
            
            # Install Kind
            if ! command -v kind &> /dev/null; then
                print_status "Installing Kind..."
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
                if [ $? -ne 0 ]; then print_error "Kind installation failed."; exit 1; fi
            fi

            # Install OpenSSL (usually pre-installed, but for completeness)
            if ! command -v openssl &> /dev/null; then
                print_status "Installing OpenSSL..."
                sudo apt-get install -y openssl
                if [ $? -ne 0 ]; then print_error "OpenSSL installation failed."; exit 1; fi
            fi

            # Install curl (usually pre-installed)
            if ! command -v curl &> /dev/null; then
                print_status "Installing curl..."
                sudo apt-get install -y curl
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
}

# --- Verify all tools are installed ---
verify_tools() {
    print_step "Verifying tool installations..."
    
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
}

# --- Generate self-signed certificates ---
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

# --- Define and Export Environment Variables ---
define_env_vars() {
    print_step "Defining and exporting environment variables..."
    
    export CLUSTER_NAME="$PROJECT_NAME"
    export IMAGE_NAME="$PROJECT_NAME-app" # Using key-server-app as image name
    export IMAGE_TAG="latest" # Using 'latest' for development, consider unique tags for production
    export DOCKER_USERNAME="your-dockerhub-username" # <--- IMPORTANT: REPLACE WITH YOUR DOCKER HUB USERNAME!
    export HELM_CHART_PATH="./deploy/kubernetes/key-server-chart"
    export HELM_RELEASE_NAME="$PROJECT_NAME"
    export APP_SERVICE_NAME="$PROJECT_NAME-app"
    export APP_CONTAINER_PORT="$DEFAULT_PORT"
    export APP_LOCAL_PORT="8443" # Consistent with previous guidance

    echo "Environment variables set. Please verify DOCKER_USERNAME is correct."
    echo "HELM_RELEASE_NAME: $HELM_RELEASE_NAME"
    echo "HELM_CHART_PATH: $HELM_CHART_PATH"
    echo "IMAGE_NAME: $IMAGE_NAME"
    echo "IMAGE_TAG: $IMAGE_TAG"
    echo "DOCKER_USERNAME: $DOCKER_USERNAME"
    echo "APP_LOCAL_PORT: $APP_LOCAL_PORT"
    echo "APP_CONTAINER_PORT: $APP_CONTAINER_PORT"
}

# --- Main Execution ---
main() {
    print_header
    
    detect_os
    install_prerequisites
    verify_tools
    generate_certificates
    define_env_vars
    
    print_success "Key Server development environment setup completed successfully!"
    echo ""
    echo "--- Next Steps ---"
    echo "1. If you just installed Docker, you might need to logout and log back in for Docker group changes to take effect."
    echo "2. Ensure Docker Desktop (if on macOS/Windows) has Kubernetes enabled and running."
    echo "3. Proceed to the 'End-to-End Deployment Workflow' section in the README.md to build, deploy, and verify the application."
    echo "   Remember to 'source dev-setup.sh' in any new terminal session."
}

# Run main function
main "$@"