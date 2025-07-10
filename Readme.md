
# Key Server Application - Comprehensive Guide for Team Members
---
Welcome to the Key Server Application repository! This document will guide you through understanding the project, setting up your development environment, deploying the application end-to-end on a local Kubernetes cluster (using Docker Desktop and Kind), and setting up a local monitoring stack with Prometheus and Grafana.

-----

## Table of Contents

1.  **Project Overview**
2.  **Repository Structure**
3.  **Prerequisites**
4.  **Local Setup & Tools Installation**
      * Initial Setup Script (`dev-setup.sh`)
5.  **Key Server Application Preparation for Monitoring**
6.  **Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)**
7.  **Cleanup Script (`cleanup.sh`)**
8.  **Verify Monitoring Setup**
      * 8.1. Verify Kubernetes Pods and Services
      * 8.2. Access Prometheus UI (via `kubectl port-forward`)
      * 8.3. Access Grafana UI (via `kubectl port-forward`)
      * 8.4. Stop Port-Forwarding Sessions
9.  **Creating Load and Observing on Grafana Dashboards**
      * 9.1. Ensure Grafana is Accessible
      * 9.2. Generate Load on the Key Server
      * 9.3. Observe Metrics on Grafana Dashboards
10. **Troubleshooting Common Issues**
      * 10.1. `kubectl` connectivity issues (`localhost:8080` errors)
      * 10.2. Grafana `CreateContainerConfigError` (missing `admin-user` in secret)
      * 10.3. Helm `UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`
      * 10.4. Helm Templating Errors (`no template "key-server.fullname"` etc.)
      * 10.5. Ingress `pathType: Required value` error
      * 10.6. Key Server Pod secret `"key-server-key-server-app-tls-secret"` not found
      * 10.7. Helm `context deadline exceeded`
      * 10.8. Resources not being destroyed by `cleanup.sh`
      * 10.9. Symptom: `/ready` Endpoint Returns "404 Not Found"
      * 10.10. Symptom: Docker Build Fails with "parent snapshot does not exist" or "rpc error"
      * 10.11. Symptom: Kubernetes Ingress Verification Fails (Status: 000)
      * 10.12. General Troubleshooting Tips
      * 10.13. Symptom: Cannot log in to Grafana Dashboard (unknown username)
      * 10.14. Troubleshooting Grafana Dashboards & Metrics Display Issues (Deep Dive)
11. **API Endpoints**
12. **Configuration**
13. **Local Development (Manual)**
14. **Docker (Manual)**
15. **Kubernetes (Helm - Manual)**

-----

## 1. Project Overview

The Key Server Application is a simple Go-based microservice designed to generate cryptographically secure keys of a specified length. It exposes HTTP/HTTPS endpoints for health checks, readiness checks, and key generation, and also integrates with Prometheus for metrics collection.

**Key Features:**

  * Generates random keys of a given length.
  * HTTPS-enabled endpoints.
  * `/health` and `/ready` probes for Kubernetes.
  * `/metrics` endpoint for Prometheus.

-----

## 2. Repository Structure

```

.
├── Dockerfile                  \# Defines how to build the Docker image for the Go application
├── go.mod                      \# Go module definition
├── go.sum                      \# Go module checksums
├── main.go                     \# Main application entry point and HTTP server setup
├── certs/                      \# Directory for SSL certificates (server.crt, server.key)
│   ├── server.crt              \# SSL certificate for HTTPS (generated locally by dev-setup.sh)
│   └── server.key              \# SSL private key for HTTPS (generated locally by dev-setup.sh)
├── dev-setup.sh                \# Script for initial local development environment setup
├── app\_build\_and\_verification.sh \# Script to build, push, and locally verify the Docker image, then deploy and verify in Kubernetes
├── cleanup.sh                  \# Script to clean up local Docker and Kubernetes deployments
├── internal/                   \# Internal packages for application logic
│   ├── config/                 \# Application configuration loading
│   ├── handler/                \# HTTP request handlers (HealthCheck, ReadinessCheck, GenerateKey)
│   ├── keygenerator/           \# Logic for generating keys
│   ├── keyservice/             \# Business logic for key operations
│   ├── metrics/                \# Prometheus metrics instrumentation
└── deploy/
└── kubernetes/
└── key-server-chart/   \# Helm chart for deploying the application to Kubernetes
├── Chart.yaml      \# Helm chart metadata
├── values.yaml     \# Default configuration values for the Helm chart
└── templates/      \# Kubernetes manifest templates
├── \_helpers.tpl        \# Helm template helpers (contains helper functions like fullname, labels)
├── deployment.yaml     \# Kubernetes Deployment for the application pods
├── service.yaml        \# Kubernetes Service to expose the application
├── serviceaccount.yaml \# Kubernetes ServiceAccount for the application pods
└── ingress.yaml        \# Kubernetes Ingress for external access (if enabled)

````

-----

## 3. Prerequisites

Before you begin, ensure you have the following tools installed on your system:

  * **Go (v1.22 or later):** The programming language for the application.
      * [Download & Install Go](https://go.dev/doc/install)
  * **Docker Desktop (with Kubernetes enabled):** For building Docker images and running a local Kubernetes cluster.
      * [Download & Install Docker Desktop](https://www.docker.com/products/docker-desktop/)
      * **Crucial:** After installation, open Docker Desktop, go to **Settings -> Kubernetes**, and ensure "**Enable Kubernetes**" is checked. Click "**Apply & Restart**" and wait for Kubernetes to fully start.
  * **Kind:** Kubernetes in Docker, used for local Kubernetes cluster creation.
      * [Install Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
  * **`kubectl`:** The Kubernetes command-line tool. Usually installed automatically with Docker Desktop.
      * [Install kubectl (if not already present)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * **Helm (v3 or later):** The Kubernetes package manager.
      * [Install Helm](https://helm.sh/docs/intro/install/)
  * **`jq`:** A lightweight and flexible command-line JSON processor (used in scripts).
      * [Install jq](https://jqlang.github.io/jq/download/)
  * **OpenSSL:** For generating self-signed SSL certificates. Pre-installed on macOS and most Linux distributions.
  * **`hey` (Optional, for load generation):** A modern HTTP load generator.
      * Install `hey` (e.g., `go install github.com/rakyll/hey@latest`)

-----

## 4. Local Setup & Tools Installation

This section covers the initial setup of your development environment.

### Initial Setup Script (`dev-setup.sh`)

This script will:

  * Generate self-signed SSL certificates (`server.crt`, `server.key`) in the `certs/` directory.
  * Define and export essential environment variables for the project.

**How to Run `dev-setup.sh`:**

1.  **Locate the script:** The script content is available in `./dev-setup.sh`.
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

## 5. Key Server Application Preparation for Monitoring

For Prometheus to automatically discover and scrape metrics from your Key Server application, its Kubernetes Service needs specific annotations.

**Action:** Ensure your `deploy/kubernetes/key-server-chart/templates/service.yaml` file includes the following annotations within its `metadata` section:

```yaml
metadata:
  # ... other metadata ...
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8443" # The port where your application exposes metrics
    prometheus.io/scheme: "https" # Use https if your metrics endpoint is TLS-enabled
```
```
Refer to `deploy/kubernetes/key-server-chart/templates/service.yaml` for the complete file content.

Additionally, ensure your Helm chart templates are consistent with the naming conventions. Verify the content of the following files in `deploy/kubernetes/key-server-chart/templates/`:

  * `_helpers.tpl`
  * `serviceaccount.yaml`
  * `ingress.yaml`
  * `deployment.yaml`
  * `values.yaml`

These files should correctly use `key-server-app` as the prefix for helper functions (e.g., `include "key-server-app.fullname" .`).

-----

## 6. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)

This script provides a fully automated workflow that handles everything from building your Go application to deploying and verifying it and the monitoring stack in your local Kubernetes cluster. It's designed for rapid iteration and confidence, combining many manual steps into a single command.

### How `app_build_and_verification.sh` Works (End-to-End Automation):

The `app_build_and_verification.sh` script automates the following comprehensive sequence:

1.  **Go Application Build & Local API Test:** Compiles the Go source code. It then runs the compiled binary locally, starts it in the background, and performs API tests against its `/health`, `/ready`, `/key/{length}`, and `/metrics` endpoints.
2.  **Docker Image Build & Local Container API Test:** Creates a Docker image. It then runs this image as a standalone container, port-forwards it, and performs API tests against its `/health`, `/ready`, `/key/{length}`, and `/metrics` endpoints.
3.  **Kind Cluster Setup:** Creates a local Kind Kubernetes cluster (if one doesn't exist) and loads the Docker image into it.
4.  **Kubernetes TLS Secret Creation:** Creates the necessary TLS secret in Kubernetes.
5.  **Prometheus Helm Repository:** Adds the Prometheus Community Helm repository.
6.  **Grafana Admin Secret Creation:** Prompts for a secure Grafana admin password and creates a Kubernetes Secret to store it.
7.  **Monitoring Stack Deployment:** Installs the `kube-prometheus-stack` Helm chart (Prometheus, Grafana, Alertmanager) into the `prometheus-operator` namespace, referencing the new Grafana admin password Secret.
8.  **Monitoring Stack Readiness:** Waits for all monitoring components to be ready.
9.  **Key Server Helm Deployment:** Installs or upgrades the Key Server application's Helm chart to the Kind cluster.
10. **Kubernetes Deployment API Test (via `kubectl port-forward`):** Waits for the Key Server deployment to be ready and then establishes a temporary `kubectl port-forward` tunnel to its service. It automatically tests the `/health`, `/ready`, `/key/{length}`, and `/metrics` endpoints via `localhost`. This step should report `[SUCCESS]` if the application is running correctly within Kubernetes.
11. **Kubernetes Ingress Verification:** Attempts to verify the Ingress endpoint (if enabled). (Note: This step might still fail on macOS due to specific host network routing issues, as detailed in **10.11. Symptom: Kubernetes Ingress Verification Fails (Status: 000)**).
12. **Reports Status:** Provides clear "OK" or "FAILED" messages for each stage and test. If any stage or test fails, the script will exit with an error, guiding you to the specific troubleshooting section.

### How to Run `app_build_and_verification.sh`:

1.  **Locate the script:** The full script content is available in `./app_build_and_verification.sh`.
2.  **Make it executable:**
    ```bash
    chmod +x app_build_and_verification.sh
    ```
3.  **Run it:**
    ```bash
    ./app_build_and_verification.sh
    ```
    **Expected Output:** The script will provide detailed logs for each stage of the process, including build progress, local container test results, Kubernetes deployment progress, and final Kubernetes endpoint verification. It will prompt you for the Grafana admin password. It will exit with an error if any stage fails, providing a clear indication of where to troubleshoot.

-----

## 7\. Cleanup Script (`cleanup.sh`)

This script helps you clean up local Docker containers and Kubernetes deployments, including the Kind cluster and monitoring stack. It's designed to be robust and provides verbose output to confirm resource destruction.

### How to Run `cleanup.sh`:

1.  **Locate the script:** The full script content is available in `./cleanup.sh`.
2.  **Make it executable:**
    ```bash
    chmod +x cleanup.sh
    ```
3.  **Run it:**
    ```bash
    ./cleanup.sh
    ```
    **Important:** It's a good practice to run `cleanup.sh` before running `app_build_and_verification.sh` to ensure a clean environment. The verbose output will confirm which resources are being cleaned up.

-----

## 8\. Verify Monitoring Setup

Once the `app_build_and_verification.sh` script completes successfully, you can manually verify that Prometheus and Grafana are running and monitoring your application.

### 8.1. Verify Kubernetes Pods and Services

Open a new terminal and run these commands to check the status of the monitoring components:

  * **Check the status of all pods in the `prometheus-operator` namespace:**
    ```bash
    kubectl get pods -n prometheus-operator
    ```
    **Expected Output:** You should see pods for `grafana`, `prometheus-stack-kube-prometheus-prometheus`, `alertmanager`, `kube-state-metrics`, etc. All of them should eventually show `Running` status. If any are not running, examine their logs (`kubectl logs <pod-name> -n prometheus-operator`) for errors.
  * **List all services in the `prometheus-operator` namespace:**
    ```bash
    kubectl get svc -n prometheus-operator
    ```
    **Expected Output:** You should see services named similar to `prometheus-stack-grafana` and `prometheus-stack-kube-prom-prometheus`. Note their exact names, as these will be used for port-forwarding.

### 8.2. Access Prometheus UI (via `kubectl port-forward`)

1.  **Get the Prometheus Service Name:**
    We'll try to get the service name programmatically. If this fails, use the name you found in `kubectl get svc -n prometheus-operator`.
    ```bash
    PROMETHEUS_SVC_NAME=$(kubectl get svc -n prometheus-operator \
      -l app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus-stack \
      -o jsonpath='{.items[0].metadata.name}')
    echo "Prometheus Service Name: ${PROMETHEUS_SVC_NAME}"
    ```
2.  **Start Port-Forward to Prometheus UI:**
    Open a **new terminal window** and run:
    ```bash
    kubectl port-forward svc/${PROMETHEUS_SVC_NAME} 9090:9090 -n prometheus-operator
    ```
    This command will run continuously in this terminal.
3.  **Access Prometheus UI in your browser:**
    Navigate to **`http://localhost:9090`**.
      * Go to **Status -\> Targets**. You should see your `key-server-key-server-app` service listed as a target, with its state as **UP**. This confirms Prometheus is successfully scraping your application's metrics.
      * Go to **Graph**. In the expression bar, type `http_requests_total{job="key-server-key-server-app"}` and click "Execute" to see your application's HTTP request metrics. You can also try `key_generations_total{job="key-server-key-server-app"}`.

### 8.3. Access Grafana UI (via `kubectl port-forward`)

1.  **Get the Grafana Service Name:**
    Similar to Prometheus, we'll try to get the service name programmatically.
    ```bash
    GRAFANA_SVC_NAME=$(kubectl get svc -n prometheus-operator \
      -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack \
      -o jsonpath='{.items[0].metadata.name}')
    echo "Grafana Service Name: ${GRAFANA_SVC_NAME}"
    ```
2.  **Get Grafana 'admin' user password:**
    ```bash
    kubectl --namespace prometheus-operator get secrets grafana-admin-secret \
      -o jsonpath="{.data.admin-password}" | base64 -d ; echo
    ```
    This will print the password you entered during the `app_build_and_verification.sh` script.
3.  **Start Port-Forward to Grafana UI:**
    Open **another new terminal window** (separate from the Prometheus port-forward) and run:
    ```bash
    kubectl port-forward svc/${GRAFANA_SVC_NAME} 3000:80 -n prometheus-operator
    ```
    This command will also run continuously in its terminal.
4.  **Access Grafana UI in your browser:**
    Navigate to **`http://localhost:3000`**.
      * **Login:** Use username `admin` and the password you retrieved in step 2.
      * **Explore Dashboards:**
          * Click the "**Dashboards**" icon (four squares) on the left sidebar.
          * Navigate to **Browse**. You should find a folder named "**Key Server**".
          * Inside the "**Key Server**" folder, you will see your custom dashboards:
              * **Key Server HTTP Overview**
              * **Key Server Key Generation**
      * **To see data on the dashboards:** While Grafana is running and port-forwarded, open another terminal and make some requests to your Key Server application (e.g., `curl -k https://localhost:8443/key/32` or use `hey` as described in Section 9.2). This will generate metrics that Prometheus scrapes and Grafana visualizes. **Ensure your dashboard's time range is set to a recent interval and auto-refresh is enabled.**

### 8.4. Stop Port-Forwarding Sessions

Remember to go back to the terminals where `kubectl port-forward` commands are running and press **Ctrl+C** to terminate them once you are done with your manual verification.

-----

## 9\. Creating Load and Observing on Grafana Dashboards

Once your Key Server application and monitoring stack are deployed and verified, you can generate load on the application and observe the metrics in real-time on your Grafana dashboards.

### 9.1. Ensure Grafana is Accessible

Make sure you have a terminal running the Grafana port-forward (as described in **8.3. Access Grafana UI**). Keep this terminal open.

### 9.2. Generate Load on the Key Server

You can generate load using `curl` in a simple loop or a more sophisticated tool like `hey`.

#### Option 1: Using `curl` (Simple Loop)

Open a new terminal window and run the following command. This will continuously send requests to the `/key/32` endpoint, simulating load.

```bash
# First, ensure the Key Server is port-forwarded if you're not using Ingress
# In a separate terminal, if not already done by app_build_and_verification.sh's final test:
kubectl port-forward svc/key-server-key-server-app 8443:8443 -n default

# Now, generate load
while true; do
  curl -k -s -o /dev/null https://localhost:8443/key/32
  sleep 0.1 # Adjust this value to increase/decrease load
done
```

Press **Ctrl+C** in this terminal to stop generating load.
Adjust `sleep 0.1` to change the rate of requests (smaller number = higher load).

#### Option 2: Using `hey` (Recommended for Controlled Load)

If you have `hey` installed (see **Prerequisites**), it provides more control over the load generation.
Open a new terminal window and run:

```bash
# First, ensure the Key Server is port-forwarded if you're not using Ingress
# In a separate terminal, if not already done by app_build_and_verification.sh's final test:
kubectl port-forward svc/key-server-key-server-app 8443:8443 -n default

# Generate 1000 requests with 10 concurrent workers
hey -n 1000 -c 10 -host "key-server.local" https://localhost:8443/key/32
```

  * `-n 1000`: Send a total of 1000 requests.
  * `-c 10`: Use 10 concurrent workers.
  * `-host "key-server.local"`: Important for TLS certificate validation if you're using `key-server.local` hostname.

You can run this command multiple times or adjust `-n` (number of requests) and `-c` (concurrency) to create different load profiles.

### 9.3. Observe Metrics on Grafana Dashboards

While the load generation is running, switch back to your browser with the Grafana UI (`http://localhost:3000`).

1.  **Navigate to Dashboards:** Click the "**Dashboards**" icon on the left sidebar, then go to **Browse** and open the "**Key Server**" folder.
2.  **Open "Key Server HTTP Overview" Dashboard:**
      * You should immediately start seeing activity on graphs related to "HTTP Requests Rate", "HTTP Request Duration", and "HTTP Status Codes".
      * The **HTTP Requests Rate** panel should show a steadily increasing count.
      * The **HTTP Request Duration** panels will show the latency of your API calls under load.
3.  **Open "Key Server Key Generation" Dashboard:**
      * This dashboard will show metrics specific to key generation, such as "Key Generation Rate" and "Key Server Key Generation Duration (99th Percentile)".
      * The **Key Generation Rate** panel should increase with each `/key/{length}` request.
      * The **Key Server Key Generation Duration (99th Percentile)** will show the latency distribution of key generation.

**Tips for Observation:**

  * **Time Range:** Ensure the time range selector in Grafana (usually top-right corner) is set to a recent interval (e.g., "Last 5 minutes" or "Last 15 minutes") and set to "Refresh every 5s" or "Refresh every 10s" to see live updates.
  * **Generate More Load:** If you don't see much activity, increase the load by running more `curl` loops concurrently or increasing the `-n` and `-c` values for `hey`.
  * **Prometheus Scrape Interval:** Prometheus typically scrapes metrics every 15 seconds by default. There might be a slight delay between generating load and seeing it reflected in Grafana due to this scrape interval.

-----

## 10\. Troubleshooting Common Issues

### 10.1. `kubectl` connectivity issues (`localhost:8080` errors)

**Symptom:** Commands like `kubectl get pods` return errors like "The connection to the server localhost:8080 was refused - did you specify the right host or port?".
**Root Cause:** `kubectl` is not configured to connect to your Kind cluster. This usually means the context is wrong or the Kind cluster isn't running.
**Fix:**

1.  Ensure Docker Desktop is running and Kubernetes is enabled.
2.  Verify your Kind cluster is running: `kind get clusters`. If not, create it using `kind create cluster --name key-server`.
3.  Set your kubectl context: `kubectl config use-context kind-key-server`.

### 10.2. Grafana `CreateContainerConfigError` (missing `admin-user` in secret)

**Symptom:** Grafana pod fails to start with `CreateContainerConfigError` or similar messages in its `Events` (from `kubectl describe pod <grafana-pod> -n prometheus-operator`), indicating issues accessing `admin-user` or `admin-password` from the secret.
**Root Cause:** The `grafana-admin-secret` was either created incorrectly or missing the `admin-user` key.
**Fix:**

1.  Delete the existing secret (if any): `kubectl delete secret grafana-admin-secret -n prometheus-operator`
2.  Re-run the secret creation step from `app_build_and_verification.sh` or the entire script. Ensure you enter a password when prompted.

### 10.3. Helm `UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`

**Symptom:** Helm commands fail with `UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`.
**Root Cause:** A previous Helm operation failed or was interrupted, leaving a lock.
**Fix:**

1.  Check Helm releases: `helm list -n <namespace>`.
2.  If you see a release stuck in a pending state, you can roll it back to the last successful release or force delete it.
      * `helm rollback <release-name> <revision-number> -n <namespace>`
      * `helm uninstall <release-name> -n <namespace> --no-hooks` (use with caution)

### 10.4. Helm Templating Errors (`no template "key-server.fullname"` etc.)

**Symptom:** Helm install/upgrade fails with errors indicating that templates like `key-server.fullname` or `key-server.labels` cannot be found or are incorrect.
**Root Cause:** This almost always means there's a typo in the `_helpers.tpl` file or in how you're calling the helpers (e.g., `include "key-server-app.fullname" .` vs `include "key-server.fullname" .`). The Helm chart `name` in `Chart.yaml` usually dictates the prefix.
**Fix:**

1.  Ensure your Helm chart's `Chart.yaml` has `name: key-server-app`.
2.  In all templates (`deployment.yaml`, `service.yaml`, `ingress.yaml`, etc.), ensure you are consistently using `include "key-server-app.fullname" .` and `include "key-server-app.labels" .` where appropriate.

### 10.5. Ingress `pathType: Required value` error

**Symptom:** Ingress deployment fails with `pathType: Required value`.
**Root Cause:** Kubernetes Ingress API version `networking.k8s.io/v1` requires `pathType` to be explicitly defined for each path. Older examples might omit it.
**Fix:**

  * Ensure your `ingress.yaml` file explicitly sets `pathType: Prefix` (or `Exact`) for each path. For example:
    ```yaml
    - path: /
      pathType: Prefix # Add this line
      backend:
        service:
          name: {{ include "key-server-app.fullname" . }}
          port:
            number: {{ .Values.service.port }}
    ```

### 10.6. Key Server Pod secret `"key-server-key-server-app-tls-secret"` not found

**Symptom:** Key Server pod fails to start with errors indicating it cannot find the TLS secret for mounting.
**Root Cause:** The Kubernetes TLS secret was not created before the Deployment, or its name doesn't match what the Deployment expects.
**Fix:**

1.  Verify the secret name in `deploy/kubernetes/key-server-chart/templates/deployment.yaml` volume mounts. It should match the secret created by `app_build_and_verification.sh` (which is `key-server-key-server-app-tls-secret`).
2.  Ensure the secret is created in the correct namespace (usually `default` for the app) before the Helm chart is installed/upgraded. The `app_build_and_verification.sh` script handles this.

### 10.7. Helm `context deadline exceeded`

**Symptom:** Helm commands hang and eventually fail with `context deadline exceeded`.
**Root Cause:** The Kubernetes cluster is unresponsive, or the pods Helm is waiting for (`--wait`) are not becoming ready within the default timeout (5 minutes). This can happen if pods are crash-looping or stuck pending.
**Fix:**

1.  Check pod status: `kubectl get pods -n <namespace>`. Look for `CrashLoopBackOff`, `Pending`, or pods that aren't reaching `Running`/`Ready`.
2.  Check pod logs: `kubectl logs <pod-name> -n <namespace>`.
3.  Describe pod: `kubectl describe pod <pod-name> -n <namespace>` to see events and detailed errors.
4.  Increase Helm timeout: Use `--timeout 10m` (for 10 minutes) with your Helm commands.

### 10.8. Resources not being destroyed by `cleanup.sh`

**Symptom:** After running `cleanup.sh`, some resources (like the Kind cluster or Docker images) persist.
**Root Cause:** Permissions issues, or the resource name is slightly different than what the script expects, or a resource is stuck.
**Fix:**

1.  Run `cleanup.sh` again.
2.  Manually inspect:
      * Kind clusters: `kind get clusters`
      * Docker images: `docker images`
      * Docker containers: `docker ps -a`
      * Kubernetes namespaces: `kubectl get ns`
3.  Manually delete:
      * `kind delete cluster --name <cluster-name>`
      * `docker rmi <image-id>`
      * `docker rm <container-id>`
      * `kubectl delete ns <namespace-name>` (use with caution)

### 10.9. Symptom: `/ready` Endpoint Returns "404 Not Found"

**Problem:** When testing the `/ready` endpoint, you receive a "404 Not Found" error instead of "Ready".
**Root Cause:** This typically indicates that the application's HTTP server is running, but the `/ready` handler either isn't registered correctly or there's a routing issue within the application preventing that path from being handled.
**Fix:**

1.  **Verify `main.go`:** Ensure `main.go` correctly registers the `/ready` endpoint handler (e.g., `router.HandleFunc("/ready", appHandler.ReadinessCheck).Methods("GET")`).
2.  **Check Application Logs:** If the app starts but the endpoint returns 404, check the application's logs for any startup errors related to routing or handler registration.

### 10.10. Symptom: Docker Build Fails with "parent snapshot does not exist" or "rpc error"

**Problem:** Docker build command fails with errors like `failed to solve: parent snapshot does not exist` or `rpc error: code = Unknown desc = failed to solve: rpc error: code = Canceled desc = context canceled`.
**Root Cause:** These are often transient Docker buildkit issues, corrupted Docker cache, or low disk space/memory for Docker Desktop.
**Fix:**

1.  **Clean Docker Build Cache:** `docker builder prune -a`
2.  **Restart Docker Desktop:** A full restart often resolves these issues.
3.  **Check Disk Space:** Ensure your Docker Desktop has sufficient disk space allocated and that your machine has enough free disk space.
4.  **Increase Docker Desktop Resources:** In Docker Desktop settings, increase CPU and Memory allocated to the Docker engine.

### 10.11. Symptom: Kubernetes Ingress Verification Fails (Status: 000)

**Problem:** The `app_build_and_verification.sh` script's Kubernetes Ingress verification step fails, typically showing a `Status: 000` or connection refused.
**Root Cause:**

  * **Ingress Controller Not Ready:** The NGINX Ingress controller (part of `kube-prometheus-stack` or separately installed) might not be fully ready or its service might not be exposed on a host port accessible by `curl`.
  * **macOS Specific Routing:** On macOS, `kind` clusters (and Docker Desktop's Kubernetes) often have difficulty routing external traffic back into the cluster's Ingress controller via `localhost`. While Windows and Linux often work with `localhost`, macOS might require different network configurations or direct pod IP access (which is less stable for testing).
    **Fix:**

<!-- end list -->

1.  **Verify Ingress Controller:**
    ```bash
    kubectl get pods -n prometheus-operator -l app.kubernetes.io/name=ingress-nginx
    kubectl get svc -n prometheus-operator -l app.kubernetes.io/name=ingress-nginx
    ```
    Ensure the `ingress-nginx` controller pod is `Running` and its service has external access (e.g., NodePort on Kind).
2.  **Focus on Port-Forwarding:** For local testing, rely on `kubectl port-forward` directly to the Key Server service (as done in the `app_build_and_verification.sh` script's later API tests, and detailed in **8.2/8.3** and **9.2**) rather than Ingress for verification. The Ingress can still be useful for other internal cluster routing, but direct host verification can be tricky locally.
3.  **Check Ingress Resource Status:** `kubectl get ingress -n default` to see if your Ingress is configured and has an address.

### 10.12. General Troubleshooting Tips

  * **Read Logs:** Always check the logs of failing pods: `kubectl logs <pod-name> -n <namespace>`.
  * **Describe Resources:** Use `kubectl describe <resource-type> <resource-name> -n <namespace>` to get detailed information about a resource's state, events, and configuration.
  * **Clean Environment:** If you encounter persistent issues, run `cleanup.sh` and then `app_build_and_verification.sh` again for a fresh start.
  * **Verify Port-Forwards:** Ensure all necessary `kubectl port-forward` commands are running in separate terminals.
  * **Check Docker Desktop:** Make sure Docker Desktop is running and healthy.

### 10.13. Symptom: Cannot log in to Grafana Dashboard (unknown username)

**Problem:** You try to log in to Grafana with username `admin` but get an "invalid username or password" error.
**Root Cause:** The `grafana-admin-secret` was either not created, or it was created without the correct `admin-user` key, or a typo was made in the password during secret creation.
**Fix:**

1.  **Retrieve Password:** Use the command from **8.3. Access Grafana UI** to retrieve the stored password:
    ```bash
    kubectl --namespace prometheus-operator get secrets grafana-admin-secret \
      -o jsonpath="{.data.admin-password}" | base64 -d ; echo
    ```
    Copy this password carefully.
2.  **Verify Secret Content:**
    ```bash
    kubectl get secret grafana-admin-secret -n prometheus-operator -o yaml
    ```
    Look for `admin-user` and `admin-password` under `data` (they will be base64 encoded).
3.  **Re-run Setup:** If still problematic, run `./cleanup.sh` followed by `./app_build_and_verification.sh` to recreate the secret cleanly. Ensure you enter a password when prompted.

### 10.14. Troubleshooting Grafana Dashboards & Metrics Display Issues (Deep Dive)

This section covers common and complex issues encountered when setting up Grafana dashboards, especially when metrics are not displaying as expected.

#### Symptom: Prometheus Not Scraping Key Server Metrics (Targets DOWN)

**Problem:** The Key Server application's metrics target appears `DOWN` in the Prometheus UI (`http://localhost:9090/targets`) or is not discovered at all.

**Root Causes:**

  * **ServiceMonitor Configuration Mismatch:** The Kubernetes `ServiceMonitor` resource for the Key Server application was configured with incorrect `port`, `scheme`, or `tlsConfig` settings, preventing Prometheus from successfully connecting to the `/metrics` endpoint. Specifically, if your application exposes metrics over HTTPS on port 8443, the `ServiceMonitor` must reflect this. For self-signed certificates, Prometheus needed to be told to skip TLS verification.
  * **Prometheus Discovery Labels:** The `kube-prometheus-stack` (deployed by Helm) typically uses selectors to discover `ServiceMonitor`s. By default, it might look for `ServiceMonitor`s with the `release: prometheus-stack` label. If your Key Server's `ServiceMonitor` lacks this label, Prometheus's operator might ignore it.

**How to Verify/Fix:**

1.  **Check `ServiceMonitor` YAML:** Inspect your `deploy/kubernetes/key-server-chart/templates/servicemonitor.yaml` to ensure it has:
    ```yaml
    # ... metadata ...
    labels:
      release: prometheus-stack # IMPORTANT for Prometheus to discover
    # ... spec ...
    endpoints:
      - port: https # Use the named port from your Service (e.g., 'https')
        scheme: https # Must match your application's metrics endpoint scheme
        path: /metrics
        tlsConfig:
          insecureSkipVerify: true # Required for self-signed certificates
    ```
2.  **Verify ServiceMonitor Deployment:**
    ```bash
    kubectl get servicemonitor -n default key-server-key-server-app
    kubectl describe servicemonitor -n default key-server-key-server-app
    ```
3.  **Check Prometheus Targets UI:** Access `http://localhost:9090/targets` and confirm `key-server-key-server-app` target is `UP`.

#### Symptom: Grafana "Datasource prometheus was not found" Error

**Problem:** When opening a Grafana dashboard, the browser's developer console (F12 -\> Console) shows errors like `PanelQueryRunner Error {message: 'Datasource prometheus was not found'}`. This occurs even if you can manually see "Prometheus" listed under Grafana's "Data sources".

**Root Cause:**

  * **Inconsistent Data Source UID:** Grafana dashboards, especially when provisioned from files, explicitly reference data sources by their Unique Identifier (UID). If the provisioned Prometheus data source doesn't have the exact UID expected by the dashboards (which is `prometheus` in our case), Grafana's panel runner cannot link the query to the correct data source.

**How to Verify/Fix:**

1.  **Inspect Grafana Data Source ConfigMap:**
    ```bash
    kubectl get configmap grafana-prometheus-datasource -n prometheus-operator -o yaml
    ```
2.  **Verify `prometheus-datasource.yaml` content:** Ensure the `data` section includes the `uid` field:
    ```yaml
    data:
      prometheus-datasource.yaml: |
        apiVersion: 1
        datasources:
          - name: Prometheus
            type: prometheus
            url: [http://prometheus-stack-kube-prom-prometheus.prometheus-operator:9090](http://prometheus-stack-kube-prom-prometheus.prometheus-operator:9090)
            access: proxy
            isDefault: true
            version: 1
            editable: false
            uid: prometheus # <--- This line is CRUCIAL
    ```
3.  **Solution:** The `app_build_and_verification.sh` script should ensure this ConfigMap is correctly applied. Re-running `cleanup.sh` followed by `app_build_and_verification.sh` will apply the correct configuration.

#### Symptom: Blank Grafana Panels / "Unexpected Error" Pop-ups

**Problem:** Grafana dashboards would either show no data or display "An unexpected error happened" pop-ups, even after the data source was found. Prometheus confirmed it was scraping and had the data.
**Root Causes:**

  * **PromQL Query Label Mismatch (Subtle):** Even if the `job` label is correct, other labels (e.g., `code`, `length`, `handler`) used in `sum by (...)` aggregations or `legendFormat` might not exist on the metrics as expected, causing queries to return empty series.
  * **Incorrect Metric Names:** Simple typos or incorrect metric names in the PromQL queries will result in no data.
  * **Grafana UI Rendering Bug (Historical):** A specific color configuration (`"paletteColor"`) in the dashboard JSON caused a frontend rendering error in Grafana.

**Fixes Implemented:**

  * **Dashboard JSONs (`http-overview.json` and `key-generation.json`) were updated:**
      * The `job` label in all PromQL queries was corrected to `job="key-server-key-server-app"`.
      * Metric names (e.g., `key_generation_duration_seconds_bucket`) and aggregation labels (`sum by (le, code)` or `sum by (le, length)`) were adjusted to match the actual metrics exposed by the application.
      * The `legendFormat` was updated to use correct labels like `{{code}}` or `{{length}}`.
      * The `color.mode` in `fieldConfig.defaults` was changed from `"paletteColor"` to `"fixed"` (with a `fixedColor: "blue"`) to bypass the rendering bug.

#### Symptom: Blank Grafana Panels (No Data Displayed, No Errors)

**Problem:** Grafana dashboards appeared but showed no data, and there were no errors in the UI or browser console. Prometheus's "Explore" view *did* show data for raw metrics.
**Root Cause:**

  * **`rate()` function interval mismatch:** The `rate()` function in PromQL, used in the dashboard queries, requires at least two data points within its specified time window to calculate a rate. If Grafana uses a dynamic `$__interval` variable, this window could sometimes be too small or misaligned with the Prometheus scrape interval (e.g., 15s scrape interval and 15s `$__interval`), leading to insufficient data points for `rate()` to reliably calculate. This results in an empty series being returned to Grafana, which then displays as "no data" on the panel.

**How to Verify/Fix:**

1.  **Use Grafana's Query Inspector:**
      * On a blank panel, click the "..." menu -\> "Inspect" -\> "Query Inspector" -\> "Data" tab.
      * Click the "Refresh" button.
      * If you see `status: 200` but the `frames` array is empty or the table says "No data", then the query itself is returning no results from Prometheus.
2.  **Verify PromQL in Prometheus UI:**
      * Access `http://localhost:9090/graph`.
      * **Copy the exact `expr` (PromQL query) from your Grafana panel's JSON model** (e.g., `rate(http_requests_total{job="key-server-key-server-app"}[$__interval])` or `rate(http_requests_total{job="key-server-key-server-app"}[5m])`).
      * Paste it into the Prometheus "Expression" field.
      * Set the time range (e.g., "Last 5m", "Last 15m") and click "Execute".
      * If data *appears* here but not in Grafana, proceed to the next step.
3.  **Adjust `rate()` Interval (The Common Solution):**
      * If your Prometheus scrape interval is 15s (default for `kube-prometheus-stack`), change the `rate()` interval in your dashboard JSONs to a slightly larger, fixed value like `[30s]` or `[1m]`. This gives `rate()` a wider window to find data points.
      * **Modify `http-overview.json` and `key-generation.json`:**
        Change lines like:
        `"expr": "rate(http_requests_total{job=\"key-server-key-server-app\"}[$__interval])"`
        To:
        `"expr": "rate(http_requests_total{job=\"key-server-key-server-app\"}[30s])"`
        (Apply similar changes for all `rate()` or `histogram_quantile(..., rate(...))` queries).
4.  **Re-apply Dashboard ConfigMaps:** After modifying the JSON files, you must run `./cleanup.sh` followed by `./app_build_and_verification.sh` to redeploy the ConfigMaps and restart the Grafana pod so it picks up the new dashboard definitions.

-----

## 11\. API Endpoints

The Key Server application exposes the following HTTP/HTTPS endpoints:

  * **`/health` (GET):** Returns `{"status": "Healthy"}` if the application is running.
  * **`/ready` (GET):** Returns `{"status": "Ready"}` if the application is ready to serve traffic.
  * **`/key/{length}` (GET):** Generates a cryptographically secure random key of the specified `length` (integer). Example: `/key/32`.
  * **`/metrics` (GET):** Prometheus metrics endpoint. Exposes application-specific metrics (e.g., `http_requests_total`, `key_generations_total`, `key_generation_duration_seconds_bucket`).

-----

## 12\. Configuration

The Key Server application can be configured using environment variables:

  * **`PORT` (default: `8080`):** The port the HTTP server listens on.
  * **`MAX_KEY_SIZE` (default: `2048`):** The maximum allowed key length.
  * **`TLS_CERT_FILE` (optional):** Path to the TLS certificate file (e.g., `./certs/server.crt`). If set, HTTPS will be enabled.
  * **`TLS_KEY_FILE` (optional):** Path to the TLS private key file (e.g., `./certs/server.key`). If set, HTTPS will be enabled.

-----

## 13\. Local Development (Manual)

For manual local development without Docker or Kubernetes:

1.  **Build the application:**
    ```bash
    go build -o key-server .
    ```
2.  **Generate certificates (if not already done):**
    ```bash
    source dev-setup.sh
    ```
3.  **Run the application:**
    ```bash
    PORT=8443 MAX_KEY_SIZE=64 TLS_CERT_FILE=./certs/server.crt TLS_KEY_FILE=./certs/server.key ./key-server
    ```
4.  **Test endpoints:**
    ```bash
    curl -k https://localhost:8443/health
    curl -k https://localhost:8443/key/32
    curl -k https://localhost:8443/metrics
    ```

-----

## 14\. Docker (Manual)

To manually build and run the application using Docker:

1.  **Build the Docker image:**
    ```bash
    docker build -t key-server .
    ```
2.  **Generate certificates (if not already done):**
    ```bash
    source dev-setup.sh
    ```
3.  **Run the Docker container:**
    ```bash
    docker run -d --rm --name key-server-app -p 8443:8443 \
      -v "$(pwd)/certs:/etc/key-server/tls" \
      -e PORT=8443 \
      -e TLS_CERT_FILE=/etc/key-server/tls/server.crt \
      -e TLS_KEY_FILE=/etc/key-server/tls/server.key \
      key-server
    ```
4.  **Test endpoints:**
    ```bash
    curl -k https://localhost:8443/health
    curl -k https://localhost:8443/key/32
    curl -k https://localhost:8443/metrics
    ```
5.  **Stop the container:**
    ```bash
    docker stop key-server-app
    ```

-----

## 15\. Kubernetes (Helm - Manual)

To manually deploy the application to Kubernetes using Helm (requires a running Kubernetes cluster and `kubectl` context set):

1.  **Generate certificates (if not already done):**
    ```bash
    source dev-setup.sh
    ```
2.  **Create Kubernetes TLS secret:**
    ```bash
    kubectl create secret tls key-server-key-server-app-tls-secret \
        --cert=./certs/server.crt \
        --key=./certs/server.key \
        --dry-run=client -o yaml | kubectl apply -f -
    ```
3.  **Load Docker image into Kind (if using Kind):**
    ```bash
    kind load docker-image key-server --name key-server
    ```
4.  **Install/Upgrade Helm chart:**
    ```bash
    helm upgrade --install key-server ./deploy/kubernetes/key-server-chart \
        --set image.repository=key-server \
        --set image.tag=latest \
        --set service.type=NodePort \
        --set ingress.enabled=true \
        --set "ingress.tls[0].secretName=key-server-key-server-app-tls-secret" \
        --set config.maxKeySize=64 \
        --set service.port=8443 \
        --set service.targetPort=8443 \
        --wait
    ```
5.  **Verify deployment:**
    ```bash
    kubectl get pods
    kubectl get svc
    kubectl get ingress
    ```
6.  **Port-forward to test (if Ingress is not externally accessible):**
    ```bash
    kubectl port-forward svc/key-server-key-server-app 8443:8443 -n default
    ```
    Then, in another terminal:
    ```bash
    curl -k https://localhost:8443/health
    ```
7.  **Uninstall Helm chart:**
    ```bash
    helm uninstall key-server
    ```