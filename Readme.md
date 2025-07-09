# Key Server Application - Comprehensive Guide for Team Members
-----

Welcome to the Key Server Application repository\! This document will guide you through understanding the project, setting up your development environment, and deploying the application end-to-end on a local Kubernetes cluster (using Docker Desktop and Kind).

-----

## Table of Contents

1.  [Project Overview](https://www.google.com/search?q=%231-project-overview)
2.  [Repository Structure](https://www.google.com/search?q=%232-repository-structure)
3.  [Prerequisites](https://www.google.com/search?q=%233-prerequisites)
4.  [Local Setup & Tools Installation](https://www.google.com/search?q=%234-local-setup--tools-installation)
      * [Initial Setup Script (`dev-setup.sh`)](https://www.google.com/search?q=%23initial-setup-script-dev-setupsh)
5.  [End-to-End Deployment Workflow](https://www.google.com/search?q=%235-end-to-end-deployment-workflow)
      * [5.1. Manual Deployment and Verification](https://www.google.com/search?q=%2351-manual-deployment-and-verification)
          * [5.1.1. Build & Verify Go Application](https://www.google.com/search?q=%23511-build--verify-go-application)
          * [5.1.2. Build & Verify Docker Image](https://www.google.com/search?q=%23512-build--verify-docker-image)
          * [5.1.3. Kubernetes Deployment and Verification](https://www.google.com/search?q=%23513-kubernetes-deployment-and-verification)
      * [5.2. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)](https://www.google.com/search?q=%2352-automated-end-to-end-deployment--verification-app_build_and_verificationsh)
6.  [Cleanup Script (`cleanup.sh`)](https://www.google.com/search?q=%236-cleanup-script-cleanupsh)
7.  [Troubleshooting Guide](https://www.google.com/search?q=%237-troubleshooting-guide)
      * [Symptom 7.1: `/ready` Endpoint Returns "404 Not Found"](https://www.google.com/search?q=%23symptom-71-ready-endpoint-returns-404-not-found)
      * [Symptom 7.2: Docker Build Fails with "parent snapshot does not exist" or "rpc error"](https://www.google.com/search?q=%23symptom-72-docker-build-fails-with-parent-snapshot-does-not-exist-or-rpc-error)
      * [Symptom 7.3: Kubernetes Cluster Unreachable / "Connection Refused" by `kubectl` or `helm`](https://www.google.com/search?q=%23symptom-73-kubernetes-cluster-unreachable--connection-refused-by-kubectl-or-helm)
      * [Symptom 7.4: Kubernetes Ingress Verification Fails (Status: 000)](https://www.google.com/search?q=%23symptom-74-kubernetes-ingress-verification-fails-status-000)
      * [General Troubleshooting Tips](https://www.google.com/search?q=%23general-troubleshooting-tips)

<!-- end list -->

  * [API Endpoints](https://www.google.com/search?q=%23api-endpoints)
  * [Configuration](https://www.google.com/search?q=%23configuration)
  * [Local Development](https://www.google.com/search?q=%23local-development)
  * [Docker](https://www.google.com/search?q=%23docker)
  * [Kubernetes (Helm)](https://www.google.com/search?q=%23kubernetes-helm)

-----

## 1\. Project Overview

-----

The Key Server Application is a simple Go-based microservice designed to generate cryptographic keys of a specified length. It exposes HTTP/HTTPS endpoints for health checks, readiness checks, and key generation, and also integrates with Prometheus for metrics collection.

**Key Features:**

  * Generates random keys of a given length.
  * HTTPS-enabled endpoints.
  * `/health` and `/ready` probes for Kubernetes.
  * `/metrics` endpoint for Prometheus.

-----

## 2\. Repository Structure

-----

```
.
├── Dockerfile                  # Defines how to build the Docker image for the Go application
├── go.mod                      # Go module definition
├── go.sum                      # Go module checksums
├── main.go                     # Main application entry point and HTTP server setup
├── server.crt                  # SSL certificate for HTTPS (generated locally by dev-setup.sh)
├── server.key                  # SSL private key for HTTPS (generated locally by dev-setup.sh)
├── dev-setup.sh                # Script for initial local development environment setup
├── app_build_and_verification.sh # Script to build, push, and locally verify the Docker image, then deploy and verify in Kubernetes
├── cleanup.sh                  # Script to clean up local Docker and Kubernetes deployments
├── internal/                   # Internal packages for application logic
│   ├── config/                 # Application configuration loading
│   ├── handler/                # HTTP request handlers (HealthCheck, ReadinessCheck, GenerateKey)
│   ├── keygenerator/           # Logic for generating keys
│   ├── keyservice/             # Business logic for key operations
│   └── metrics/                # Prometheus metrics instrumentation
└── deploy/
    └── kubernetes/
        └── key-server-chart/   # Helm chart for deploying the application to Kubernetes
            ├── Chart.yaml      # Helm chart metadata
            ├── values.yaml     # Default configuration values for the Helm chart
            └── templates/      # Kubernetes manifest templates
                ├── _helpers.tpl        # Helm template helpers
                ├── deployment.yaml     # Kubernetes Deployment for the application pods
                ├── service.yaml        # Kubernetes Service to expose the application
                └── serviceaccount.yaml # Kubernetes ServiceAccount for the application pods
```

-----

## 3\. Prerequisites

-----

Before you begin, ensure you have the following tools installed on your system:

  * **Go (v1.22 or later):** The programming language for the application.
      * [Download & Install Go](https://go.dev/doc/install)
  * **Docker Desktop (with Kubernetes enabled):** For building Docker images and running a local Kubernetes cluster.
      * [Download & Install Docker Desktop](https://www.docker.com/products/docker-desktop/)
      * **Crucial:** After installation, open Docker Desktop, go to `Settings -> Kubernetes`, and ensure "Enable Kubernetes" is checked. Click "Apply & Restart" and wait for Kubernetes to fully start.
  * **Kind:** Kubernetes in Docker, used for local Kubernetes cluster creation.
      * [Install Kind](https://www.google.com/search?q=https://kind.sigs.k8s.io/docs/user/quick-start/%23installation)
  * **kubectl:** The Kubernetes command-line tool. Usually installed automatically with Docker Desktop.
      * [Install kubectl (if not already present)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * **Helm (v3 or later):** The Kubernetes package manager.
      * [Install Helm](https://helm.sh/docs/intro/install/)
  * **jq:** A lightweight and flexible command-line JSON processor (used in scripts).
      * [Install jq](https://jqlang.github.io/jq/download/)
  * **OpenSSL:** For generating self-signed SSL certificates. Pre-installed on macOS and most Linux distributions.

-----

## 4\. Local Setup & Tools Installation

-----

This section covers the initial setup of your development environment.

### Initial Setup Script (`dev-setup.sh`)

This script will:

  * Generate self-signed SSL certificates (`server.crt`, `server.key`).
  * Define and export essential environment variables for the project.

**How to Run `dev-setup.sh`:**

1.  **Save the script:** Create a file named `dev-setup.sh` in your project's root directory and paste the content provided in our previous discussions.
2.  **Make it executable:**
    ```bash
    chmod +x dev-setup.sh
    ```
3.  **Run it (source it) in your terminal:**
    ```bash
    source dev-setup.sh
    ```
    **Important:** Use `source` (or `.`) instead of `./` to ensure the environment variables are set in your current shell session. You'll need to source this script in every new terminal session you open for this project.

-----

## 5\. End-to-End Deployment Workflow

-----

This section guides you through building, verifying, and deploying the application in stages. You can choose either a manual approach for step-by-step control or an automated script for a streamlined end-to-end process.

### 5.1. Manual Deployment and Verification

This approach allows you to build and verify each component (Go application, Docker image, Kubernetes deployment) individually.

#### 5.1.1. Build & Verify Go Application

This initial step ensures your Go application code compiles and runs correctly on your local machine before involving Docker or Kubernetes. This is a fundamental check for Go-specific issues.

1.  **Navigate to the project root:**

    ```bash
    cd /path/to/your/Key-Server-Application
    ```

2.  **Generate SSL Certificates (if not already done by `dev-setup.sh`):**

    ```bash
    openssl genrsa -out server.key 2048
    openssl req -new -x509 -sha256 -key server.key -out server.crt -days 365 -subj "/CN=localhost"
    ```

    Your `main.go` will look for these files.

3.  **Build the Go Application Binary:**

    ```bash
    go build -o key-server .
    ```

    This compiles your `main.go` and its dependencies into a single executable file named `key-server` in your current directory.

4.  **Run the Go Application Binary:**

    ```bash
    ./key-server
    ```

    This will start your application. You should see log messages indicating routes being configured (including `/health` and `/ready`) and the server starting on HTTPS port 8443. Keep this terminal window open while you perform manual verification.

5.  **Verify Endpoints Manually:**
    Open a **NEW TERMINAL WINDOW**.
    Test the endpoints using `curl`. Since it's HTTPS with a self-signed certificate, use `--insecure`.

    ```bash
    curl --insecure https://localhost:8443/health
    # Expected: Healthy

    curl --insecure https://localhost:8443/ready
    # Expected: Ready

    curl --insecure https://localhost:8443/key/32
    # Expected: {"key":"<base64_encoded_key_of_length_44_chars>"}

    curl --insecure https://localhost:8443/metrics
    # Expected: Prometheus metrics output (lines starting with # HELP, # TYPE, etc.)
    ```

    If these tests pass, your Go application code is working correctly.

6.  **Stop the Application:** Go back to the terminal running `./key-server` and press `Ctrl+C`.

#### 5.1.2. Build & Verify Docker Image

This step focuses on manually building your Docker image and verifying that the application runs correctly within a Docker container.

1.  **Navigate to the project root:**
    ```bash
    cd /path/to/your/Key-Server-Application
    ```
2.  **Build the Docker Image:**
    ```bash
    docker build -t key-server .
    ```
3.  **Verify Image Build:**
    ```bash
    docker images | grep "key-server"
    ```
    Confirm the `CREATED` timestamp is recent.
4.  **Run the Docker Container:**
    First, stop and remove any previous container with the same name to ensure a clean start:
    ```bash
    docker stop key-server-test 2>/dev/null || true
    docker rm key-server-test 2>/dev/null || true
    ```
    Then, run the container in detached mode, mapping the application's port:
    ```bash
    docker run \
      --name key-server-test \
      -p 8443:8443 \
      -v "$(pwd)/certs:/etc/key-server/tls" \
      -e PORT=8443 \
      -e TLS_CERT_FILE=/etc/key-server/tls/server.crt \
      -e TLS_KEY_FILE=/etc/key-server/tls/server.key \
      -d \
      key-server
    ```
5.  **Verify Endpoints Manually (in Docker Container):**
    Wait a few seconds for the containerized application to start.
    Test the endpoints using `curl` via the mapped local port:
    ```bash
    curl --insecure https://localhost:8443/health
    # Expected: Healthy

    curl --insecure https://localhost:8443/ready
    # Expected: Ready

    curl --insecure https://localhost:8443/key/32
    # Expected: {"key":"<base64_encoded_key_of_length_44_chars>"}

    curl --insecure https://localhost:8443/metrics
    # Expected: Prometheus metrics output
    ```
6.  **Check Container Logs:**
    ```bash
    docker logs key-server-test
    ```
    Verify the application's startup logs and route configurations.
7.  **Stop and Remove Container:**
    ```bash
    docker stop key-server-test && docker rm key-server-test
    ```

#### 5.1.3. Kubernetes Deployment and Verification

This section guides you through manually preparing and deploying your application to Kubernetes using Helm, and then verifying its functionality.

1.  **Prepare for Kubernetes Deployment (Manual Configuration):**
      * **Create a Kind cluster (if not already running):**
        ```bash
        kind create cluster --name key-server
        ```
      * **Load the Docker image into Kind:**
        ```bash
        kind load docker-image key-server --name key-server
        ```
      * **Create Kubernetes TLS Secret:**
        This secret will hold your `server.crt` and `server.key` for your pods.
        ```bash
        kubectl create secret tls key-server-tls-secret --cert=certs/server.crt --key=certs/server.key -n default
        ```
        Verify its creation: `kubectl get secret key-server-tls-secret -n default`
2.  **Deploy with Helm:**
    ```bash
    helm upgrade --install key-server ./deploy/kubernetes/key-server-chart --wait -n default
    ```
      * `--wait`: Helm will wait until all resources are in a ready state.
3.  **Verify Kubernetes Deployment:**
      * **Check Pod Status:**
        ```bash
        kubectl get pods -n default -l app.kubernetes.io/name=key-server-app
        ```
        Expected: Your pod should eventually show `STATUS` as `Running`.
      * **Check Service Status:**
        ```bash
        kubectl get service key-server-key-server-app -n default
        ```
        Expected: Verify the service type (`NodePort`) and that `8443:3xxxx/TCP` is listed (where `3xxxx` is the assigned NodePort).
      * **Check Pod Logs (Crucial for Application Startup Verification):**
        Get the exact name of your running pod from `kubectl get pods`.
        View its logs:
        ```bash
        kubectl logs <your-key-server-app-pod-name> -n default
        ```
        Expected Output: Look for lines confirming route configuration, especially `Route configured: [GET] /ready`, and `Key Server starting on HTTPS port 8443....` This confirms your application started correctly with the latest code and HTTPS inside Kubernetes.
      * **Test Application Endpoints in Kubernetes (Recommended Method: Port-Forward):**
          * **Establish Port Forwarding to the Service:**
            Open a **NEW TERMINAL WINDOW**.
            Forward a local port (e.g., `8443`) to the Kubernetes Service's internal port (`8443`).
            ```bash
            kubectl port-forward service/key-server-key-server-app 8443:8443
            ```
            Keep this terminal window open; it will forward traffic as long as it's running.
          * **Test with `curl` (in another new terminal):**
            Since your application uses HTTPS with self-signed certificates, you'll need the `--insecure` (or `-k`) flag with `curl` to bypass certificate validation.
              * **Health Check:**
                ```bash
                curl --insecure https://localhost:8443/health
                # Expected Output: Healthy
                ```
              * **Readiness Check:**
                ```bash
                curl --insecure https://localhost:8443/ready
                # Expected Output: Ready
                ```
              * **Generate Key (e.g., length 32):**
                ```bash
                curl --insecure https://localhost:8443/key/32
                # Expected Output: A JSON object containing a generated key, e.g., {"key":"YourGeneratedKeyStringHere"}
                ```
              * **Metrics Check:**
                ```bash
                curl --insecure https://localhost:8443/metrics
                # Expected Output: Prometheus metrics output
                ```
          * **Stop the Port-Forward:** Go back to the terminal running `kubectl port-forward` and press `Ctrl+C`.
      * **Test Application Endpoints in Kubernetes (Alternative Method: NodePort):**
        This method attempts to access the service directly via the Kind cluster's IP address and the NodePort. This might not work on all systems (especially macOS with default configurations) if there are host-level network routing issues.
          * **Get the Kind Cluster IP and NodePort:**
            ```bash
            KIND_IP=$(docker inspect key-server-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}')
            NODE_PORT=$(kubectl get svc key-server-key-server-app -o=jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
            echo "Kind Cluster IP: ${KIND_IP}"
            echo "NodePort: ${NODE_PORT}"
            ```
            (Example output: `Kind Cluster IP: 172.18.0.4`, `NodePort: 31690`)
          * **Use `curl` with the IP and NodePort:**
            Replace `<KIND_IP>` and `<NODE_PORT>` with the actual values you obtained.
            ```bash
            curl -k https://<KIND_IP>:<NODE_PORT>/health
            curl -k https://<KIND_IP>:<NODE_PORT>/ready
            curl -k https://<KIND_IP>:<NODE_PORT>/key/32
            curl -k https://<KIND_IP>:<NODE_PORT>/metrics
            ```
            Expected Behavior: If your host networking is correctly configured to route to the Docker network, these commands should return successful responses. If they time out or fail with a `Status: 000`, it indicates a host-level network routing problem (see [Symptom 7.4](https://www.google.com/search?q=%23symptom-74-kubernetes-ingress-verification-fails-status-000)).

### 5.2. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)

This script provides a fully automated workflow that handles everything from building your Go application to deploying and verifying it in your local Kubernetes cluster. It's designed for rapid iteration and confidence, combining many manual steps into a single command.

**How `app_build_and_verification.sh` Works (End-to-End Automation):**

The `app_build_and_verification.sh` script automates the following comprehensive sequence:

  * **Go Application Build & Local Test:** Compiles the Go source code and runs local unit tests and functional tests against the locally running binary.
  * **Docker Image Build & Test:** Creates a Docker image and runs a brief functional test against the containerized application.
  * **Kind Cluster Setup:** Creates a local Kind Kubernetes cluster (if one doesn't exist) and loads the Docker image into it.
  * **Kubernetes TLS Secret Creation:** Creates the necessary TLS secret in Kubernetes.
  * **Helm Deployment:** Installs or upgrades the application's Helm chart to the Kind cluster.
  * **Kubernetes Deployment Verification (via `kubectl port-forward`):** Waits for the deployment to be ready and then establishes a temporary `kubectl port-forward` tunnel to the service. It automatically tests the `/health`, `/ready`, `/key`, and `/metrics` endpoints via localhost. This step should report `[SUCCESS]` if the application is running correctly within Kubernetes.
  * **Kubernetes Ingress Verification:** Attempts to verify the Ingress endpoint. (Note: This step might still fail on macOS due to specific host network routing issues, as detailed in [Symptom 7.4](https://www.google.com/search?q=%23symptom-74-kubernetes-ingress-verification-fails-status-000)).
  * **Reports Status:** Provides clear "OK" or "FAILED" messages for each stage and test. If any stage or test fails, the script will exit with an error, guiding you to the specific troubleshooting section.

**How to Run `app_build_and_verification.sh`:**

1.  **Save the script:** Ensure your `app_build_and_verification.sh` file is updated with the latest version we discussed.
2.  **Make it executable:**
    ```bash
    chmod +x app_build_and_verification.sh
    ```
3.  **Run it:**
    ```bash
    ./app_build_and_verification.sh
    ```
    **Expected Output:** The script will provide detailed logs for each stage of the process, including build progress, local container test results, Kubernetes deployment progress, and final Kubernetes endpoint verification. It will exit with an error if any stage fails, providing a clear indication of where to troubleshoot.

-----

## 6\. Cleanup Script (`cleanup.sh`)

-----

This script helps you clean up local Docker containers and Kubernetes deployments, useful for starting fresh or freeing up resources.

**How to Run `cleanup.sh`:**

1.  **Save the script:** Ensure your `cleanup.sh` file is updated with the latest version we discussed.
2.  **Make it executable:** `chmod +x cleanup.sh`
3.  **Run it:**
    ```bash
    ./cleanup.sh
    ```
    **Important:** It's a good practice to run `cleanup.sh` before running `app_build_and_verification.sh` to ensure a clean environment.

-----

## 7\. Troubleshooting Guide

-----

This section provides solutions for common issues you might encounter.

### Symptom 7.1: `/ready` Endpoint Returns "404 Not Found"

**Problem:** After modifying `main.go` and deploying, calls to `/ready` (and possibly `/health`) return `404 Not Found`. Application logs inside the container don't show the expected `"Route configured: [GET] /ready"` message.

**Root Cause:** The `main.go` code changes for route registration aren't being correctly compiled into the Docker image, or Kubernetes is deploying an outdated image.

**Solution:**

1.  **Verify `main.go`:** Double-check that `router.HandleFunc("/ready", httpHandler.ReadinessCheck).Methods("GET")` is correctly present in `main.go` and that the explicit `log.Printf` for `/ready` is there.
2.  **Run `app_build_and_verification.sh`:** This script will ensure a fresh Docker image build and push. Check its output for any errors.
3.  **Ensure `imagePullPolicy: Always`:** In `deploy/kubernetes/key-server-chart/values.yaml`, set `image.pullPolicy: Always`.
4.  **Clean & Re-deploy Helm:** Run `./cleanup.sh` followed by `helm upgrade --install key-server ./deploy/kubernetes/key-server-chart --wait -n default`.
5.  **Check New Pod Logs:** Verify the `"Route configured: [GET] /ready"` message appears in the logs of the newest pod.

### Symptom 7.2: Docker Build Fails with "parent snapshot does not exist" or "rpc error"

**Problem:** The `docker build` command fails with errors related to Docker's internal state or connection.

**Root Cause:** Corrupted Docker build cache or an unresponsive Docker daemon.

**Solution:**

1.  **Clear Docker Build Cache:** `docker builder prune --force` (or `docker system prune --all --force --volumes` for a more aggressive cleanup).
2.  **Restart Docker Desktop:** Click the Docker whale icon in your menu bar and select "Restart".
3.  **Wait for Docker:** Allow Docker Desktop to fully start and report "Docker Engine is running".
4.  **Retry Build:** Run `app_build_and_verification.sh` again.

### Symptom 7.3: Kubernetes Cluster Unreachable / "Connection Refused" by `kubectl` or `helm`

**Problem:** `kubectl` or `helm` commands fail to connect to the Kubernetes API server (e.g., `The connection to the server 127.0.0.1:64420 was refused`).

**Root Cause:** The Docker Desktop Kubernetes cluster isn't running, is still starting, or is in a bad state.

**Solution:**

1.  **Verify Docker Desktop Kubernetes Status:** Open Docker Desktop and confirm "Kubernetes is running" (green light).
2.  **Thorough Kubernetes Restart in Docker Desktop:**
      * Go to Docker Desktop `Settings > Kubernetes`.
      * Uncheck "Enable Kubernetes", "Apply & Restart".
      * Wait for Docker Desktop to fully restart and Kubernetes to stop.
      * Re-check "Enable Kubernetes", "Apply & Restart" again.
3.  **Wait Patiently:** Allow 5-10 minutes for Kubernetes to fully re-initialize.
4.  **Verify `kubectl` Connectivity:** Run `kubectl cluster-info`. It should now output cluster details without errors.
5.  **Retry Helm Deployment.**

### Symptom 7.4: Kubernetes Ingress Verification Fails (Status: 000)

**Problem:** The `app_build_and_verification.sh` script reports `[ERROR] Kubernetes Ingress health endpoint: FAILED (Status: 000)`. This means `curl` couldn't establish a connection to `https://key-server.local`.

**Root Cause:** This is typically a host network routing issue on your machine (common on macOS) that prevents direct access to the Kind cluster's internal IP address (e.g., `172.18.0.x`) via the `key-server.local` hostname. Your host is unable to route traffic to the Docker network where Kind resides.

**Solution:**

1.  **Verify `/etc/hosts` Entry:**
    Ensure you have the following line in your `/etc/hosts` file. This maps `key-server.local` to `127.0.0.1`. Docker Desktop typically handles the routing from `127.0.0.1` to the Kind cluster's internal IP for Ingress traffic.
    ```
    127.0.0.1 key-server.local
    ```
    After modifying `/etc/hosts`, you might need to flush your DNS cache (e.g., `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` on macOS).
2.  **Check and Temporarily Disable macOS Packet Filter (`pf`) Firewall:**
    The macOS built-in `pf` firewall can sometimes interfere with Docker Desktop's network routing, even with custom rules.
      * **Check `pf` status:**
        ```bash
        sudo pfctl -s info
        ```
        Look for `Status: Enabled` or `Status: Disabled`.
      * **Temporarily Disable `pf` (for testing):**
        **WARNING:** Disabling your firewall reduces your system's security. Only do this temporarily for testing on a trusted network.
        ```bash
        sudo pfctl -d
        ```
        Then, immediately re-run `./app_build_and_verification.sh` to see if the Ingress test passes.
      * **Re-enable `pf`:**
        ```bash
        sudo pfctl -e
        ```
3.  **Full Docker Desktop Reinstallation (Last Resort):**
    If the above steps don't resolve the issue, the underlying Docker Desktop networking stack might be deeply corrupted.
      * Backup any important Docker volumes or images you might have outside this project.
      * **Uninstall Docker Desktop completely:** Drag the "Docker" application from your `/Applications` folder to the Trash. You might also want to manually remove lingering Docker files/folders (e.g., `~/.docker`, `/Library/PrivilegedHelperTools/com.docker.vmnetd`, `/usr/local/bin/docker*`).
      * **Reboot your Mac.**
      * Download the latest Docker Desktop installer from docker.com and reinstall it.
      * After reinstallation and Docker Desktop is running, run:
        ```bash
        ./cleanup.sh
        ./app_build_and_verification.sh
        ```

### General Troubleshooting Tips

  * **Always start with `cleanup.sh`:** Before running `app_build_and_verification.sh`, execute `./cleanup.sh` to ensure a clean environment. This prevents conflicts from previous runs.
  * **Check Prerequisites:** Double-check that all [Prerequisites](https://www.google.com/search?q=%233-prerequisites) are installed and accessible in your `PATH`.
  * **Review Logs:** If a step fails, carefully read the error messages in the console output.
  * **Increase Sleep Times:** In the `app_build_and_verification.sh` script, you can temporarily increase sleep durations (e.g., after starting local app, Docker container, or port-forward) to give services more time to become ready, especially on slower machines.

-----

## API Endpoints

-----

The application exposes the following HTTPS endpoints:

  * `/health` (GET):
      * Returns `Healthy` if the server is running.
      * Used for liveness probes.
  * `/ready` (GET):
      * Returns `Ready` if the server is ready to accept requests.
      * Used for readiness probes.
  * `/key/{length}` (GET):
      * Generates a cryptographically secure, base64-encoded random key of the specified length (in bytes).
      * `length` must be an integer between 1 and `MAX_KEY_SIZE` (default 64).
      * Example: `/key/32` returns `{"key":"<32-byte_base64_encoded_key>"}`
  * `/metrics` (GET):
      * Exposes Prometheus metrics.

-----

## Configuration

-----

The application can be configured using environment variables:

  * `PORT`: The port the server listens on (default: `8443`).
  * `MAX_KEY_SIZE`: The maximum allowed length for generated keys in bytes (default: `64`).
  * `TLS_CERT_FILE`: Path to the TLS certificate file (e.g., `/etc/key-server/tls/server.crt`).
  * `TLS_KEY_FILE`: Path to the TLS private key file (e.g., `/etc/key-server/tls/server.key`).

-----

## Local Development

-----

1.  Clone the repository and navigate into the directory.
2.  **Generate TLS certificates:**
    ```bash
    mkdir -p certs
    openssl req -x509 -newkey rsa:4096 -nodes -keyout certs/server.key -out certs/server.crt -days 365 -subj "/CN=localhost"
    ```
3.  **Run the application:**
    ```bash
    PORT=8443 MAX_KEY_SIZE=64 TLS_CERT_FILE=./certs/server.crt TLS_KEY_FILE=./certs/server.key go run main.go
    ```
4.  **Test endpoints using `curl`:**
    ```bash
    curl -k https://localhost:8443/health
    curl -k https://localhost:8443/key/32
    ```

-----

## Docker

-----

1.  **Build the Docker image:**
    ```bash
    docker build -t key-server .
    ```
2.  **Run the Docker container:**
    Ensure `certs/server.crt` and `certs/server.key` exist (generate them as shown in [Local Development](https://www.google.com/search?q=%23local-development)).
    ```bash
    docker run -d --name key-server -p 8443:8443 \
      -v "$(pwd)/certs:/etc/key-server/tls" \
      -e PORT=8443 \
      -e TLS_CERT_FILE=/etc/key-server/tls/server.crt \
      -e TLS_KEY_FILE=/etc/key-server/tls/server.key \
      key-server
    ```
3.  **Test endpoints:**
    ```bash
    curl -k https://localhost:8443/health
    ```
4.  **Stop and remove the container:**
    ```bash
    docker stop key-server
    docker rm key-server
    ```

-----

## Kubernetes (Helm)

-----

The `app_build_and_verification.sh` script automates this, but here are the manual steps:

1.  **Create a Kind cluster (if not already running):**
    ```bash
    kind create cluster --name key-server
    ```
2.  **Load the Docker image into Kind:**
    ```bash
    kind load docker-image key-server --name key-server
    ```
3.  **Create Kubernetes TLS secret:**
    Ensure `certs/server.crt` and `certs/server.key` exist.
    ```bash
    kubectl create secret tls key-server-tls-secret --cert="./certs/server.crt" --key="./certs/server.key"
    ```
4.  **Install/Upgrade the Helm chart:**
    ```bash
    helm upgrade --install key-server ./deploy/kubernetes/key-server-chart \
      --set image.repository=key-server \
      --set image.tag=latest \
      --set service.type=NodePort \
      --set ingress.enabled=true \
      --set ingress.tls[0].secretName=key-server-tls-secret \
      --set config.maxKeySize=64 \
      --set service.port=8443 \
      --set service.targetPort=8443 \
      --wait
    ```
5.  **Verify deployment** (using `kubectl port-forward` as described in [5.1.3. Kubernetes Deployment and Verification](https://www.google.com/search?q=%23513-kubernetes-deployment-and-verification)).