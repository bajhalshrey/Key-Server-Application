# Key Server Application - Comprehensive Guide for Team Members#

-----

Welcome to the Key Server Application repository\! This document will guide you through understanding the project, setting up your development environment, and deploying the application end-to-end on a local Kubernetes cluster (using Docker Desktop).

-----

### Table of Contents

  * [1. Project Overview](https://www.google.com/search?q=%231-project-overview)
  * [2. Repository Structure](https://www.google.com/search?q=%232-repository-structure)
  * [3. Prerequisites](https://www.google.com/search?q=%233-prerequisites)
  * [4. Local Setup & Tools Installation](https://www.google.com/search?q=%234-local-setup--tools-installation)
      * [Initial Setup Script (`dev-setup.sh`)](https://www.google.com/search?q=%23initial-setup-script-dev-setupsh)
  * [5. End-to-End Deployment Workflow](https://www.google.com/search?q=%235-end-to-end-deployment-workflow)
      * [5.1. Manual Deployment and Verification](https://www.google.com/search?q=%2351-manual-deployment-and-verification)
          * [5.1.1. Build & Verify Go Application](https://www.google.com/search?q=%23511-build--verify-go-application)
          * [5.1.2. Build & Verify Docker Image](https://www.google.com/search?q=%23512-build--verify-docker-image)
          * [5.1.3. Kubernetes Deployment and Verification](https://www.google.com/search?q=%23513-kubernetes-deployment-and-verification)
      * [5.2. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)](https://www.google.com/search?q=%2352-automated-end-to-end-deployment--verification-app_build_and_verificationsh)
  * [6. Cleanup Script (`cleanup.sh`)](https://www.google.com/search?q=%236-cleanup-script-cleanupsh)
  * [7. Troubleshooting Guide](https://www.google.com/search?q=%237-troubleshooting-guide)
      * [Symptom 7.1: `/ready` Endpoint Returns "404 Not Found"](https://www.google.com/search?q=%23symptom-71-ready-endpoint-returns-404-not-found)
      * [Symptom 7.2: Docker Build Fails with "parent snapshot does not exist" or "rpc error"](https://www.google.com/search?q=%23symptom-72-docker-build-fails-with-parent-snapshot-does-not-exist-or-rpc-error)
      * [Symptom 7.3: Kubernetes Cluster Unreachable / "Connection Refused" by `kubectl` or `helm`](https://www.google.com/search?q=%23symptom-73-kubernetes-cluster-unreachable--connection-refused-by-kubectl-or-helm)

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
### 2. Repository Structure
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
  * **kubectl:** The Kubernetes command-line tool. Usually installed automatically with Docker Desktop.
      * [Install kubectl (if not already present)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * **Helm (v3 or later):** The Kubernetes package manager.
      * [Install Helm](https://helm.sh/docs/intro/install/)
  * **OpenSSL:** For generating self-signed SSL certificates. Pre-installed on macOS and most Linux distributions.

-----

### 4. Local Setup & Tools Installation

-----

This section covers the initial setup of your development environment.

#### Initial Setup Script (`dev-setup.sh`)

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
    **Important:** Use `source` (or `.`) instead of `./` to ensure the environment variables are set in your current shell session. You will need to source this script in every new terminal session you open for this project.

-----
### 5. End-to-End Deployment Workflow
-----

This section guides you through building, verifying, and deploying the application in stages. You can choose either a manual approach for step-by-step control or an automated script for a streamlined end-to-end process.

#### 5.1. Manual Deployment and Verification

This approach allows you to build and verify each component (Go application, Docker image, Kubernetes deployment) individually.

##### 5.1.1. Build & Verify Go Application

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

    This will start your application. You should see log messages indicating routes being configured (including `/health` and `/ready`) and the server starting on HTTPS port 8080. Keep this terminal window open while you perform manual verification.

5.  **Verify Endpoints Manually:**
    Open a **NEW TERMINAL WINDOW**.
    Test the endpoints using `curl`. Since it's HTTPS with a self-signed certificate, use `--insecure`.

    ```bash
    curl --insecure https://localhost:8080/health
    # Expected: Healthy

    curl --insecure https://localhost:8080/ready
    # Expected: Ready to serve traffic!

    curl --insecure https://localhost:8080/key/16
    # Expected: {"key":"<16-character-key>"}
    ```

    If these tests pass, your Go application code is working correctly.

6.  **Stop the Application:** Go back to the terminal running `./key-server` and press `Ctrl+C`.

##### 5.1.2. Build & Verify Docker Image

This step focuses on manually building your Docker image and verifying that the application runs correctly within a Docker container.

1.  **Navigate to the project root:**
    ```bash
    cd /path/to/your/Key-Server-Application
    ```
2.  **Build the Docker Image:**
    ```bash
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
    ```
    **Note:** For initial manual verification, `--no-cache` is not strictly necessary unless you're troubleshooting build issues.
3.  **Verify Image Build:**
    ```bash
    docker images | grep "$IMAGE_NAME"
    ```
    Confirm the `CREATED` timestamp is recent.
4.  **Run the Docker Container:**
    First, stop and remove any previous container with the same name to ensure a clean start:
    ```bash
    docker stop "$IMAGE_NAME-container" 2>/dev/null || true
    docker rm "$IMAGE_NAME-container" 2>/dev/null || true
    ```
    Then, run the container in detached mode, mapping the application's port:
    ```bash
    docker run \
      --name "$IMAGE_NAME-container" \
      -p "$APP_LOCAL_PORT":"$APP_CONTAINER_PORT" \
      -d \
      "$IMAGE_NAME:$IMAGE_TAG"
    ```
    `$APP_LOCAL_PORT` (e.g., `8443`) will be mapped to `$APP_CONTAINER_PORT` (`8080`).
5.  **Verify Endpoints Manually (in Docker Container):**
    Wait a few seconds for the containerized application to start.
    Test the endpoints using `curl` via the mapped local port:
    ```bash
    curl --insecure https://localhost:"$APP_LOCAL_PORT"/health
    # Expected: Healthy

    curl --insecure https://localhost:"$APP_LOCAL_PORT"/ready
    # Expected: Ready to serve traffic!

    curl --insecure https://localhost:"$APP_LOCAL_PORT"/key/16
    # Expected: {"key":"<16-character-key>"}
    ```
6.  **Check Container Logs:**
    ```bash
    docker logs "$IMAGE_NAME-container"
    ```
    Verify the application's startup logs and route configurations.
7.  **Stop and Remove Container:**
    ```bash
    docker stop "$IMAGE_NAME-container" && docker rm "$IMAGE_NAME-container"
    ```

##### 5.1.3. Kubernetes Deployment and Verification

This section guides you through manually preparing and deploying your application to Kubernetes using Helm, and then verifying its functionality.

1.  **Prepare for Kubernetes Deployment (Manual Configuration):**

      * **Create Kubernetes TLS Secret:**
        This secret will hold your `server.crt` and `server.key` for your pods.
        ```bash
        kubectl create secret tls key-server-tls-secret --cert=server.crt --key=server.key -n default
        ```
        Verify its creation: `kubectl get secret key-server-tls-secret -n default`
      * **Update Helm Chart Configuration Files:**
          * `deploy/kubernetes/key-server-chart/values.yaml`:
              * Update `image.repository` to `"$DOCKER_USERNAME/$IMAGE_NAME"`.
              * Ensure `image.tag` matches your desired tag (e.g., `latest`).
              * Set `image.pullPolicy: Always`.
              * Verify `app.containerPort` is `8080`.
              * Set `service.port` to `443`.
          * `deploy/kubernetes/key-server-chart/templates/deployment.yaml`:
              * Add `volumeMounts` for `/app/server.crt` and `/app/server.key` referencing the `key-server-tls-secret` (using `subPath: tls.crt` and `subPath: tls.key`).
              * Add a `volumes` definition at the `spec.template.spec` level to define `tls-cert-volume` from the secret.
              * Ensure the container's `ports` section has a named port `https` mapping to `containerPort: 8080`.
          * `deploy/kubernetes/key-server-chart/templates/service.yaml`:
              * Ensure the service's `ports` section maps `port: 443` to `targetPort: https` (the named port from your deployment).
              * Set `type: ClusterIP` (or `NodePort` for direct node access, `LoadBalancer` for cloud environments).
                Refer to the [Repository Structure](https://www.google.com/search?q=%232-repository-structure) section for file locations, and our previous discussions for the exact YAML snippets.

2.  **Deploy with Helm:**

    ```bash
    helm upgrade --install "$HELM_RELEASE_NAME" "$HELM_CHART_PATH" --timeout 15m --wait -n default
    ```

      * `--timeout 15m`: Gives the deployment ample time to complete.
      * `--wait`: Helm will wait until all resources are in a ready state.

3.  **Verify Kubernetes Deployment:**

      * **Check Pod Status:**
        ```bash
        kubectl get pods -n default -l app.kubernetes.io/name=key-server-app
        ```
        Expected: Your pod should eventually show `STATUS` as `Running`.
      * **Check Service Status:**
        ```bash
        ```

    kubectl get service "$HELM\_RELEASE\_NAME" -n default
    \`\`\`
    Expected: Verify the service type (e.g., `ClusterIP`) and that port \`443\` is listed.

      * **Check Pod Logs (Crucial for Application Startup Verification):**
        Get the exact name of your running pod from `kubectl get pods`.
        View its logs:
        ```bash
        kubectl logs <your-key-server-app-pod-name> -n default
        ```
        Expected Output: Look for lines confirming route configuration, especially `Route configured: [GET] /ready - (Explicit Log)`, and `Key Server starting on HTTPS port 8080....` This confirms your application started correctly with the latest code and HTTPS inside Kubernetes.
      * **Test Application Endpoints in Kubernetes:**
          * **Establish Port Forwarding to the Service:**
            Open a **NEW TERMINAL WINDOW**.
            Forward a local port (e.g., `$APP_LOCAL_PORT` which is `8443`) to the Kubernetes Service's HTTPS port (`443`).
            ```bash
            kubectl port-forward service/"$HELM_RELEASE_NAME" -n default "$APP_LOCAL_PORT":443
            ```
            Keep this terminal window open; it will forward traffic as long as it's running.
          * **Test with `curl` (in another new terminal):**
            Since your application uses HTTPS with self-signed certificates, you'll need the `--insecure` (or `-k`) flag with `curl` to bypass certificate validation.
              * **Health Check:**
                ```bash
                curl --insecure https://localhost:"$APP_LOCAL_PORT"/health
                # Expected Output: Healthy
                ```
              * **Readiness Check:**
                ```bash
                curl --insecure https://localhost:"$APP_LOCAL_PORT"/ready
                # Expected Output: Ready to serve traffic!
                ```
              * **Generate Key (e.g., length 32):**
                ```bash
                curl --insecure https://localhost:"$APP_LOCAL_PORT"/key/32
                # Expected Output: A JSON object containing a generated key, e.g., {"key":"YourGeneratedKeyStringHere"}
                ```

#### 5.2. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)

This script provides a fully automated workflow that handles everything from building your Go application to deploying and verifying it in your local Kubernetes cluster. It's designed for rapid iteration and confidence, combining many manual steps into a single command.

**How `app_build_and_verification.sh` Works (End-to-End Automation):**

The `app_build_and_verification.sh` script automates the following comprehensive sequence:

  * **Go Application Build:** Compiles the Go source code into an executable binary (`key-server`).
  * **Docker Image Build:** Creates a Docker image from the compiled Go binary and your `Dockerfile` (using `--no-cache` to ensure the latest code is always included).
  * **Docker Image Push:** Tags the built Docker image with your Docker Hub username and pushes it to your Docker Hub repository, making it accessible to Kubernetes.
  * **Local Docker Container Verification:**
      * Stops and removes any existing local container with the same name.
      * Starts a new Docker container from the newly pushed image, mapping `$APP_LOCAL_PORT` (e.g., `8443`) to `$APP_CONTAINER_PORT` (`8080`).
      * Waits for the application inside the container to start.
      * Automatically tests its `/health`, `/ready`, and `/key` endpoints using `curl --insecure` via the mapped local port. If these tests pass, it proceeds.
      * Stops and removes the local container after verification.
  * **Kubernetes TLS Secret Creation:** Creates (or updates) the `key-server-tls-secret` in Kubernetes (in the `default` namespace) using your `server.crt` and `server.key`.
  * **Helm Deployment:**
      * Uninstalls any previous Helm release of the application (`$HELM_RELEASE_NAME`).
      * Performs a fresh `helm upgrade --install` using your Helm chart (`$HELM_CHART_PATH`).
      * It explicitly sets `image.repository`, `image.tag`, and `image.pullPolicy=Always` during the Helm command to ensure the correct image is deployed.
      * Waits for the Helm deployment to complete and all Kubernetes resources to become ready.
  * **Kubernetes Deployment Verification:**
      * Waits for the application pod to reach a `Running` state within Kubernetes.
      * Establishes a background `kubectl port-forward` process to the deployed Kubernetes Service, mapping `$APP_LOCAL_PORT` to the service's HTTPS port (`443`).
      * Automatically tests the `/health`, `/ready`, and `/key` endpoints via this port-forward, ensuring the application is fully functional and accessible within the Kubernetes environment.
      * Kills the background `kubectl port-forward` process upon completion.
  * **Reports Status:** Provides clear "OK" or "FAILED" messages for each stage and test. If any stage or test fails, the script will exit with an error, guiding you to the specific troubleshooting section.

**How to Run `app_build_and_verification.sh`:**

1.  **Save the script:** Create a file named `app_build_and_verification.sh` in your project's root directory and paste the content provided in our previous discussions.
2.  **Make it executable:**
    ```bash
    chmod +x app_build_and_verification.sh
    ```
3.  **Run it:**
    ```bash
    ./app_build_and_verification.sh
    ```
    **Expected Output:** The script will provide detailed logs for each stage of the process, including build progress, push status, local container test results, Kubernetes deployment progress, and final Kubernetes endpoint verification. It will exit with an error if any stage fails, providing a clear indication of where to troubleshoot.

-----
### 6. Cleanup Script (`cleanup.sh`)
-----

This script helps you clean up local Docker containers and Kubernetes deployments, useful for starting fresh or freeing up resources.

**How to Run `cleanup.sh`:**

1.  **Save the script:** Create a file named `cleanup.sh` in your project's root directory and paste the content provided in our previous discussions.
2.  **Make it executable:** `chmod +x cleanup.sh`
3.  **Run it:**
    ```bash
    ./cleanup.sh
    ```
    **Important:** Ensure your environment variables are sourced (`source dev-setup.sh`) before running this script.

-----
### 7. Troubleshooting Guide
-----

This section provides solutions for common issues you might encounter.

#### Symptom 7.1: `/ready` Endpoint Returns "404 Not Found"

**Problem:** After modifying `main.go` and deploying, calls to `/ready` (and possibly `/health`) return `404 Not Found`. Application logs inside the container do not show the expected `"Route configured: [GET] /ready"` message.
**Root Cause:** The `main.go` code changes for route registration are not being correctly compiled into the Docker image, or Kubernetes is deploying an outdated image.
**Solution:**

1.  **Verify `main.go`:** Double-check that `router.HandleFunc("/ready", httpHandler.ReadinessCheck).Methods("GET")` is correctly present in `main.go` and that the explicit `log.Printf` for `/ready` is there.
2.  **Run `app_build_and_verification.sh`:** This script will ensure a fresh Docker image build and push. Check its output for any errors.
3.  **Ensure `imagePullPolicy: Always`:** In `deploy/kubernetes/key-server-chart/values.yaml`, set `image.pullPolicy: Always`.
4.  **Clean & Re-deploy Helm:** Run `./cleanup.sh` followed by `helm upgrade --install "$HELM_RELEASE_NAME" "$HELM_CHART_PATH" --timeout 15m --wait -n default`.
5.  **Check New Pod Logs:** Verify the `"Route configured: [GET] /ready"` message appears in the logs of the newest pod.

#### Symptom 7.2: Docker Build Fails with "parent snapshot does not exist" or "rpc error"

**Problem:** The `docker build` command fails with errors related to Docker's internal state or connection.
**Root Cause:** Corrupted Docker build cache or an unresponsive Docker daemon.
**Solution:**

1.  **Clear Docker Build Cache:** `docker builder prune --force` (or `docker system prune --all --force --volumes` for a more aggressive cleanup).
2.  **Restart Docker Desktop:** Click the Docker whale icon in your menu bar and select "Restart".
3.  **Wait for Docker:** Allow Docker Desktop to fully start and report "Docker Engine is running".
4.  **Retry Build:** Run `app_build_and_verification.sh` again.

#### Symptom 7.3: Kubernetes Cluster Unreachable / "Connection Refused" by `kubectl` or `helm`

**Problem:** `kubectl` or `helm` commands fail to connect to the Kubernetes API server (e.g., `The connection to the server 127.0.0.1:64420 was refused`).
**Root Cause:** The Docker Desktop Kubernetes cluster is not running, is still starting, or is in a bad state.
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