I understand. I will provide the full `README.md` content, incorporating all the previously discussed changes, specifically the correctly formatted bash commands and the Grafana troubleshooting section. I will ensure no other content is altered or removed.

Here's the complete, updated `README.md` content:

```markdown
# Key Server Application - Comprehensive Guide for Team Members

-----

Welcome to the Key Server Application repository! This document will guide you through understanding the project, setting up your development environment, deploying the application end-to-end on a local Kubernetes cluster (using Docker Desktop and Kind), and setting up a local monitoring stack with Prometheus and Grafana.

-----

## Table of Contents

* [1. Project Overview](#1-project-overview)
* [2. Repository Structure](#2-repository-structure)
* [3. Prerequisites](#3-prerequisites)
* [4. Local Setup & Tools Installation](#4-local-setup--tools-installation)
    * [Initial Setup Script (`dev-setup.sh`)](#initial-setup-script-dev-setupsh)
* [5. Key Server Application Preparation for Monitoring](#5-key-server-application-preparation-for-monitoring)
* [6. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)](#6-automated-end-to-end-deployment--verification-app_build_and_verificationsh)
* [7. Cleanup Script (`cleanup.sh`)](#7-cleanup-script-cleanupsh)
* [8. Verify Monitoring Setup](#8-verify-monitoring-setup)
    * [8.1. Verify Kubernetes Pods and Services](#81-verify-kubernetes-pods-and-services)
    * [8.2. Access Prometheus UI (via `kubectl port-forward`)](#82-access-prometheus-ui-via-kubectl-port-forward)
    * [8.3. Access Grafana UI (via `kubectl port-forward`)](#83-access-grafana-ui-via-kubectl-port-forward)
    * [8.4. Stop Port-Forwarding Sessions](#84-stop-port-forwarding-sessions)
* [9. Troubleshooting Common Issues](#9-troubleshooting-common-issues)
    * [9.1. `kubectl` connectivity issues (`localhost:8080` errors)](#91-kubectl-connectivity-issues-localhost8080-errors)
    * [9.2. Grafana `CreateContainerConfigError` (missing `admin-user` in secret)](#92-grafana-createcontainerconfigerror-missing-admin-user-in-secret)
    * [9.3. Helm `UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`](#93-helm-upgrade-failed-another-operation-installupgraderollback-is-in-progress)
    * [9.4. Helm Templating Errors (`no template "key-server.fullname"` etc.)](#94-helm-templating-errors-no-template-key-serverfullname-etc)
    * [9.5. Ingress `pathType: Required value` error](#95-ingress-pathtype-required-value-error)
    * [9.6. Key Server Pod `secret "key-server-key-server-app-tls-secret" not found`](#96-key-server-pod-secret-key-server-key-server-app-tls-secret-not-found)
    * [9.7. Helm `context deadline exceeded`](#97-helm-context-deadline-exceeded)
    * [9.8. Resources not being destroyed by `cleanup.sh`](#98-resources-not-being-destroyed-by-cleanupsh)
    * [9.9. Symptom: `/ready` Endpoint Returns "404 Not Found"](#99-symptom-ready-endpoint-returns-404-not-found)
    * [9.10. Symptom: Docker Build Fails with "parent snapshot does not exist" or "rpc error"](#910-symptom-docker-build-fails-with-parent-snapshot-does-not-exist-or-rpc-error)
    * [9.11. Symptom: Kubernetes Ingress Verification Fails (Status: 000)](#911-symptom-kubernetes-ingress-verification-fails-status-000)
    * [9.12. General Troubleshooting Tips](#912-general-troubleshooting-tips)
    * [9.13. Symptom: Cannot log in to Grafana Dashboard (unknown username)](#913-symptom-cannot-log-in-to-grafana-dashboard-unknown-username)
* [10. API Endpoints](#10-api-endpoints)
* [11. Configuration](#11-configuration)
* [12. Local Development (Manual)](#12-local-development-manual)
* [13. Docker (Manual)](#13-docker-manual)
* [14. Kubernetes (Helm - Manual)](#14-kubernetes-helm---manual)

-----

## 1. Project Overview

-----

The Key Server Application is a simple Go-based microservice designed to generate cryptographically secure keys of a specified length. It exposes HTTP/HTTPS endpoints for health checks, readiness checks, and key generation, and also integrates with Prometheus for metrics collection.

**Key Features:**

* Generates random keys of a given length.
* HTTPS-enabled endpoints.
* `/health` and `/ready` probes for Kubernetes.
* `/metrics` endpoint for Prometheus.

-----

## 2. Repository Structure

-----

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
│   └── metrics/                \# Prometheus metrics instrumentation
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

-----

Before you begin, ensure you have the following tools installed on your system:

* **Go (v1.22 or later):** The programming language for the application.
    * [Download & Install Go](https://go.dev/doc/install)
* **Docker Desktop (with Kubernetes enabled):** For building Docker images and running a local Kubernetes cluster.
    * [Download & Install Docker Desktop](https://www.docker.com/products/docker-desktop/)
    * **Crucial:** After installation, open Docker Desktop, go to `Settings -> Kubernetes`, and ensure "Enable Kubernetes" is checked. Click "Apply & Restart" and wait for Kubernetes to fully start.
* **Kind:** Kubernetes in Docker, used for local Kubernetes cluster creation.
    * [Install Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
* **kubectl:** The Kubernetes command-line tool. Usually installed automatically with Docker Desktop.
    * [Install kubectl (if not already present)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* **Helm (v3 or later):** The Kubernetes package manager.
    * [Install Helm](https://helm.sh/docs/intro/install/)
* **jq:** A lightweight and flexible command-line JSON processor (used in scripts).
    * [Install jq](https://stedolan.github.io/jq/download/)
* **OpenSSL:** For generating self-signed SSL certificates. Pre-installed on macOS and most Linux distributions.

-----

## 4. Local Setup & Tools Installation

-----

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

-----

For Prometheus to automatically discover and scrape metrics from your Key Server application, its Kubernetes Service needs specific annotations.

**Action:** Ensure your `deploy/kubernetes/key-server-chart/templates/service.yaml` file includes the following annotations within its `metadata` section:

```yaml
metadata:
  # ... other metadata ...
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8443" # The port where your application exposes metrics
    prometheus.io/scheme: "https" # Use https if your metrics endpoint is TLS-enabled
````

**Refer to `deploy/kubernetes/key-server-chart/templates/service.yaml` for the complete file content.**

Additionally, ensure your Helm chart templates are consistent with the naming conventions. **Verify the content of the following files in `deploy/kubernetes/key-server-chart/templates/`:**

  * `_helpers.tpl`
  * `serviceaccount.yaml`
  * `ingress.yaml`
  * `deployment.yaml`
  * `values.yaml`

These files should correctly use `key-server-app` as the prefix for helper functions (e.g., `include "key-server-app.fullname" .`).

-----

## 6\. Automated End-to-End Deployment & Verification (`app_build_and_verification.sh`)

-----

This script provides a fully automated workflow that handles everything from building your Go application to deploying and verifying it and the monitoring stack in your local Kubernetes cluster. It's designed for rapid iteration and confidence, combining many manual steps into a single command.

**How `app_build_and_verification.sh` Works (End-to-End Automation):**

The `app_build_and_verification.sh` script automates the following comprehensive sequence:

  * **Go Application Build & Local Test:** Compiles the Go source code and runs local unit tests and functional tests against the locally running binary.
  * **Docker Image Build & Test:** Creates a Docker image and runs a brief functional test against the containerized application.
  * **Kind Cluster Setup:** Creates a local Kind Kubernetes cluster (if one doesn't exist) and loads the Docker image into it.
  * **Kubernetes TLS Secret Creation:** Creates the necessary TLS secret in Kubernetes.
  * **Prometheus Helm Repository:** Adds the Prometheus Community Helm repository.
  * **Grafana Admin Secret Creation:** Prompts for a secure Grafana admin password and creates a Kubernetes Secret to store it.
  * **Monitoring Stack Deployment:** Installs the `kube-prometheus-stack` Helm chart (Prometheus, Grafana, Alertmanager) into the `prometheus-operator` namespace, referencing the new Grafana admin password Secret.
  * **Monitoring Stack Readiness:** Waits for all monitoring components to be ready.
  * **Key Server Helm Deployment:** Installs or upgrades the Key Server application's Helm chart to the Kind cluster.
  * **Kubernetes Deployment Verification (via `kubectl port-forward`):** Waits for the Key Server deployment to be ready and then establishes a temporary `kubectl port-forward` tunnel to its service. It automatically tests the `/health`, `/ready`, `/key`, and `/metrics` endpoints via localhost. This step should report `[SUCCESS]` if the application is running correctly within Kubernetes.
  * **Kubernetes Ingress Verification:** Attempts to verify the Ingress endpoint (if enabled). (Note: This step might still fail on macOS due to specific host network routing issues, as detailed in [9.11. Symptom: Kubernetes Ingress Verification Fails (Status: 000)](https://www.google.com/search?q=%23911-symptom-kubernetes-ingress-verification-fails-status-000)).
  * **Reports Status:** Provides clear "OK" or "FAILED" messages for each stage and test. If any stage or test fails, the script will exit with an error, guiding you to the specific troubleshooting section.

**How to Run `app_build_and_verification.sh`:**

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

-----

This script helps you clean up local Docker containers and Kubernetes deployments, including the Kind cluster and monitoring stack. It's designed to be robust and provides verbose output to confirm resource destruction.

**How to Run `cleanup.sh`:**

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

-----

Once the `app_build_and_verification.sh` script completes successfully, you can manually verify that Prometheus and Grafana are running and monitoring your application.

#### 8.1. Verify Kubernetes Pods and Services

Open a new terminal and run these commands to check the status of the monitoring components:

1.  **Check the status of all pods in the `prometheus-operator` namespace:**

    ```bash
    kubectl get pods -n prometheus-operator
    ```

    **Expected Output:** You should see pods for `grafana`, `prometheus-stack-kube-prometheus-prometheus`, `alertmanager`, `kube-state-metrics`, etc. All of them should eventually show `Running` status. If any are not running, examine their logs (`kubectl logs <pod-name> -n prometheus-operator`) for errors.

2.  **List all services in the `prometheus-operator` namespace:**

    ```bash
    kubectl get svc -n prometheus-operator
    ```

    **Expected Output:** You should see services named similar to `prometheus-stack-grafana` and `prometheus-stack-kube-prom-prometheus`. Note their exact names, as these will be used for port-forwarding.

#### 8.2. Access Prometheus UI (via `kubectl port-forward`)

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
    Navigate to `http://localhost:9090`.

      * Go to **Status -\> Targets**. You should see your `key-server-key-server-app` service listed as a target, with its state as `UP`. This confirms Prometheus is successfully scraping your application's metrics.
      * Go to **Graph**. In the expression bar, type `key_server_http_requests_total` and click "Execute" to see your application's HTTP request metrics. You can also try `key_server_key_length_bytes_histogram_count`.

#### 8.3. Access Grafana UI (via `kubectl port-forward`)

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
    Open another **new terminal window** (separate from the Prometheus port-forward) and run:

    ```bash
    kubectl port-forward svc/${GRAFANA_SVC_NAME} 3000:80 -n prometheus-operator
    ```

    This command will also run continuously in its terminal.

4.  **Access Grafana UI in your browser:**
    Navigate to `http://localhost:3000`.

      * **Login:** Use username `admin` and the password you retrieved in step 2.
      * **Explore Dashboards:**
          * Grafana comes with many pre-built dashboards for Kubernetes. You can explore them by clicking the "Dashboards" icon (four squares) on the left sidebar.
          * To verify your Key Server metrics, you can create a simple new dashboard:
              * Click the `+` icon on the left sidebar -\> `Dashboard` -\> `New dashboard`.
              * Click `Add visualization`.
              * Select `Prometheus` as the data source.
              * In the "Metric" field, type `key_server_http_requests_total`.
              * You can refine the query (e.g., `sum by (code) (rate(key_server_http_requests_total[1m]))`) to visualize the HTTP status code distribution over time.
              * Click "Apply" and then "Save" your dashboard.

#### 8.4. Stop Port-Forwarding Sessions

Remember to go back to the terminals where `kubectl port-forward` commands are running and press `Ctrl+C` to terminate them once you are done with your manual verification.

-----

## 9\. Troubleshooting Common Issues

-----

This section provides solutions for common issues you might encounter during setup and deployment. **Always try running `./cleanup.sh` before re-running `./app_build_and_verification.sh` to ensure a clean slate.**

### 9.1. `kubectl` connectivity issues (`localhost:8080` errors)

**Problem:** `kubectl` or `helm` commands fail to connect to the Kubernetes API server (e.g., `error: unable to recognize "STDIN": Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused`).

**Root Cause:** `kubectl` is misconfigured (e.g., its `kubeconfig` context or an environment variable is pointing to an incorrect address like `localhost:8080`), or there's a lingering process/proxy confusing it.

**Solution:**

1.  **Ensure Docker Desktop Kubernetes is running:** Open Docker Desktop and confirm "Kubernetes is running" (green light).
2.  **Thorough Kubernetes Restart in Docker Desktop:**
      * Go to Docker Desktop `Settings > Kubernetes`.
      * Uncheck "Enable Kubernetes", "Apply & Restart".
      * Wait for Docker Desktop to fully restart and Kubernetes to stop.
      * Re-check "Enable Kubernetes", "Apply & Restart" again.
3.  **Wait Patiently:** Allow 5-10 minutes for Kubernetes to fully re-initialize.
4.  **Run Cleanup Script:** Execute `./cleanup.sh` to ensure all contexts and clusters are reset.
5.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`.

### 9.2. Grafana `CreateContainerConfigError` (missing `admin-user` in secret)

**Problem:** The Grafana pod (e.g., `prometheus-stack-grafana-xxxx`) is stuck in `CreateContainerConfigError` status. `kubectl describe pod <grafana-pod-name> -n prometheus-operator` shows `Error: couldn't find key admin-user in Secret prometheus-operator/grafana-admin-secret`.

**Root Cause:** The `grafana-admin-secret` was created with only the `admin-password` key, but the Grafana pod expects both `admin-user` and `admin-password`.

**Solution:**

1.  **Verify `app_build_and_verification.sh`:** Ensure the `kubectl create secret generic` command for `grafana-admin-secret` includes `--from-literal="admin-user=${GRAFANA_ADMIN_USERNAME}"`. **Refer to the `./app_build_and_verification.sh` file for the complete script.**
2.  **Run Cleanup Script:** Execute `./cleanup.sh` to delete the old, incorrect secret and other resources.
3.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`. The script will create the secret correctly this time.

### 9.3. Helm `UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`

**Problem:** Helm fails with this message when trying to install or upgrade a release.

**Root Cause:** A previous Helm operation was interrupted or failed, leaving the release in a "pending" state. Helm prevents new operations until the old one is cleared.

**Solution:**

1.  **Run Cleanup Script:** Execute `./cleanup.sh`. The `cleanup.sh` script is designed to uninstall Helm releases, including those in a stuck state. This is the most reliable way to clear the pending operation.
2.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`.

### 9.4. Helm Templating Errors (`no template "key-server.fullname"` etc.)

**Problem:** Helm errors like `Error: template: key-server-app/templates/service.yaml:4:11: executing "key-server-app/templates/service.yaml" at <include "key-server.fullname" .>: error calling include: template: no template "key-server.fullname" associated with template "gotpl"`. This type of error can occur for `service.yaml`, `serviceaccount.yaml`, `ingress.yaml`, or `deployment.yaml`.

**Root Cause:** The Helm chart templates are trying to use helper functions with an incorrect prefix (e.g., `key-server.fullname`) instead of the correct one defined in `_helpers.tpl` (which is `key-server-app.fullname`).

**Solution:**

1.  **Ensure all Helm chart template files are consistent:** Verify that `_helpers.tpl`, `service.yaml`, \`\`serviceaccount.yaml` ,  `ingress.yaml\`, and \`deployment.yaml\` all use \`key-server-app.\<helper\_name\>\` for \`include\` calls (e.g., \`include "key-server-app.fullname" .\`). **Refer to the YAML files in \`deploy/kubernetes/key-server-chart/templates/\` for the complete content.**
2.  **Run Cleanup Script:** Execute `./cleanup.sh`. This is crucial to ensure Helm picks up the corrected template files.
3.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`.

### 9.5. Ingress `pathType: Required value` error

**Problem:** Helm deployment fails with `Ingress.networking.k8s.io "key-server-key-server-app-ingress" is invalid: spec.rules[0].http.paths[0].pathType: Required value: pathType must be specified`.

**Root Cause:** For Kubernetes Ingress API version `networking.k8s.io/v1`, the `pathType` field is mandatory. The Helm template logic might not be correctly rendering this field due to a scope issue in conditional checks.

**Solution:**

1.  **Verify `ingress.yaml`:** Ensure the template correctly captures the Ingress API version into a local variable and uses it consistently in the `pathType` conditional. **Refer to the `deploy/kubernetes/key-server-chart/templates/ingress.yaml` file for the complete content.**
2.  **Run Cleanup Script:** Execute `./cleanup.sh` to clear the previous failed Ingress resource.
3.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`.

### 9.6. Key Server Pod `secret "key-server-key-server-app-tls-secret" not found`

**Problem:** The Key Server pod is stuck in `ContainerCreating` or `Pending` state, and `kubectl describe pod <pod-name>` shows `Warning FailedMount ... secret "key-server-key-server-app-tls-secret" not found`.

**Root Cause:** The name of the TLS secret created by `app_build_and_verification.sh` does not match the name expected by the Helm chart's `deployment.yaml`.

**Solution:**

1.  **Verify Script Consistency:** Ensure both `app_build_and_verification.sh` (for secret creation) and `cleanup.sh` (for secret deletion) use `"${K8S_FULL_APP_NAME}-tls-secret"` for the TLS secret name. **Refer to the `./app_build_and_verification.sh` and `./cleanup.sh` files for the correct commands.**
2.  **Run Cleanup Script:** Execute `./cleanup.sh` to remove any incorrectly named secrets.
3.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`. The secret will be created with the correct name, allowing the pod to mount it.

### 9.7. Helm `context deadline exceeded`

**Problem:** The Helm deployment of your Key Server application fails with `Error: UPGRADE FAILED: context deadline exceeded`.

**Root Cause:** The Helm operation (with `--wait`) timed out because the Key Server pod(s) did not reach a ready state within the default 5-minute timeout. This could be due to slow startup or an underlying issue preventing the pod from becoming healthy.

**Solution:**

1.  **Increased Helm Timeout:** The `app_build_and_verification.sh` script has been updated to include `--timeout 10m` for the Key Server Helm deployment, providing more time. **Refer to the `./app_build_and_verification.sh` file.**
2.  **Run Cleanup Script:** Execute `./cleanup.sh` to clear the previous failed Helm release.
3.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`.
4.  **If it still fails:**
      * **Check Key Server Pod Status:**
        ```bash
        kubectl get pods -n default -l app.kubernetes.io/instance=key-server
        ```
        Look for the `STATUS` and `RESTARTS` columns.
      * **Describe the Pod for Events:**
        ```bash
        kubectl describe pod <key-server-pod-name> -n default
        ```
        Look at the `Events` section at the bottom for clues (e.g., `CrashLoopBackOff`, `ImagePullBackOff`, `Liveness probe failed`).
      * **Check Pod Logs:**
        ```bash
        kubectl logs <key-server-pod-name> -n default
        ```
        This will show your application's internal logs, which are crucial for debugging why it's not starting or becoming ready.

### 9.8. Resources not being destroyed by `cleanup.sh`

**Problem:** Even after running `cleanup.sh`, some Docker or Kubernetes resources (e.g., Kind cluster, namespaces, Helm releases) seem to persist. The script might not print detailed cleanup messages.

**Root Cause:**

  * A syntax error in `cleanup.sh` preventing it from executing fully.
  * Permissions issues.
  * Resources being truly stuck and requiring more aggressive manual intervention.

**Solution:**

1.  **Update `cleanup.sh` with the latest verbose version:** Ensure your `cleanup.sh` file matches the content provided in [Section 7](https://www.google.com/search?q=%237-cleanup-script-cleanupsh). This version includes extensive `log_info` and `log_success` messages for every step, even when resources are not found. It also has robust error handling and aggressive deletion attempts.
2.  **Ensure Executable Permissions:**
    ```bash
    chmod +x cleanup.sh
    ```
3.  **Run `cleanup.sh` and capture its full output:**
    ```bash
    ./cleanup.sh
    ```
    **Analyze the output carefully.** This will show you exactly where the script is executing, which resources it's finding/not finding, and any errors it encounters during deletion. If it still doesn't print anything, there's a very fundamental shell issue (e.g., file corruption, or not running it as `./cleanup.sh`).
4.  **Manual Intervention (if `cleanup.sh` reports persistent failures):**
      * **For stuck namespaces:**
        ```bash
        kubectl get namespace <namespace-name> -o json > <namespace-name>.json
        # Edit the JSON file and remove the "finalizers" array under "metadata"
        # Then, apply the modified JSON:
        kubectl replace --raw "/api/v1/namespaces/<namespace-name>/finalize" -f ./<namespace-name>.json
        ```
      * **For stuck Kind clusters:**
        ```bash
        kind delete cluster --name <cluster-name> --kubeconfig=/dev/null # Force delete, ignoring kubeconfig
        ```
      * **For stuck Helm releases:**
        ```bash
        helm uninstall <release-name> --namespace <namespace> --no-hooks --cascade=foreground --timeout 5m
        # If still stuck, try:
        helm uninstall <release-name> --namespace <namespace> --dry-run # To see what it would do
        # Manual deletion of Helm release record if all else fails (use with extreme caution):
        kubectl delete secret sh.helm.release.v1.<release-name>.v<revision> -n <namespace>
        ```

### 9.9. Symptom: `/ready` Endpoint Returns "404 Not Found"

**Problem:** After modifying `main.go` and deploying, calls to `/ready` (and possibly `/health`) return `404 Not Found`. Application logs inside the container don't show the expected `"Route configured: [GET] /ready"` message.

**Root Cause:** The `main.go` code changes for route registration aren't being correctly compiled into the Docker image, or Kubernetes is deploying an outdated image.

**Solution:**

1.  **Verify `main.go`:** Double-check that `router.HandleFunc("/ready", httpHandler.ReadinessCheck).Methods("GET")` is correctly present in `main.go` and that the explicit `log.Printf` for `/ready` is there.
2.  **Run Automated Deployment:** Execute `./app_build_and_verification.sh`. This script will ensure a fresh Docker image build and push. Check its output for any errors.
3.  **Ensure `imagePullPolicy: Always`:** In `deploy/kubernetes/key-server-chart/values.yaml`, set `image.pullPolicy: Always`.
4.  **Clean & Re-deploy:** Run `./cleanup.sh` followed by `./app_build_and_verification.sh`.
5.  **Check New Pod Logs:** Verify the `"Route configured: [GET] /ready"` message appears in the logs of the newest pod.

### 9.10. Symptom: Docker Build Fails with "parent snapshot does not exist" or "rpc error"

**Problem:** The `docker build` command fails with errors related to Docker's internal state or connection.

**Root Cause:** Corrupted Docker build cache or an unresponsive Docker daemon.

**Solution:**

1.  **Clear Docker Build Cache:**
    ```bash
    docker builder prune --force
    # or for a more aggressive cleanup:
    # docker system prune --all --force --volumes
    ```
2.  **Restart Docker Desktop:** Click the Docker whale icon in your menu bar and select "Restart".
3.  **Wait for Docker:** Allow Docker Desktop to fully start and report "Docker Engine is running".
4.  **Retry Automated Deployment:** Run `./app_build_and_verification.sh`.

### 9.11. Symptom: Kubernetes Ingress Verification Fails (Status: 000)

**Problem:** The `app_build_and_verification.sh` script reports `[ERROR] Kubernetes Ingress health endpoint: FAILED (Status: 000)`. This means `curl` couldn't establish a connection to `https://key-server.local`.

**Root Cause:** This is typically a host network routing issue on your machine (common on macOS) that prevents direct access to the Kind cluster's internal IP address (e.g., `172.18.0.x`) via the `key-server.local` hostname. Your host is unable to route traffic to the Docker network where Kind resides.

**Solution:**

1.  **Verify `/etc/hosts` Entry:**
    Ensure you have the following line in your `/etc/hosts` file. This maps `key-server.local` to `127.0.0.1`. Docker Desktop typically handles the routing from `127.0.0.1` to the Kind cluster's internal IP for Ingress traffic.
    ```bash
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

### 9.12. General Troubleshooting Tips

  * **Always start with `cleanup.sh`:** Before running `app_build_and_verification.sh`, execute `./cleanup.sh` to ensure a clean environment. This prevents conflicts from previous runs.
  * **Check Prerequisites:** Double-check that all [Prerequisites](https://www.google.com/search?q=%233-prerequisites) are installed and accessible in your `PATH`.
  * **Review Logs:** If a step fails, carefully read the error messages in the console output.
  * **Increase Sleep Times:** In the `app_build_and_verification.sh` script, you can temporarily increase sleep durations (e.g., after starting local app, Docker container, or port-forward) to give services more time to become ready, especially on slower machines.

### 9.13. Symptom: Cannot log in to Grafana Dashboard (unknown username)

**Problem:** You are unable to log in to the Grafana dashboard, even after retrieving the password, potentially due to an incorrect or unknown username.

**Root Cause:** While the `app_build_and_verification.sh` script is designed to set the Grafana admin username to `admin` in a Kubernetes secret, there might be an issue where Grafana's internal database doesn't correctly reflect this, or a previous installation left conflicting credentials.

**Solution:**

1.  **Verify the Grafana Admin Username from the Secret:**
    First, confirm the username stored in the Kubernetes secret:

    ```bash
    kubectl --namespace prometheus-operator get secrets grafana-admin-secret \
      -o jsonpath="{.data.admin-user}" | base64 -d ; echo
    ```

    This command should output `admin`. If it outputs something else, use that as your username.

2. **If `admin` is confirmed but login still fails, reset the admin password directly in the Grafana pod:**
    This ensures Grafana's internal database is updated with the correct credentials.

    a.  **Get the Grafana Pod Name:**
    ` GRAFANA_POD_NAME=$(kubectl get pods -n prometheus-operator \ -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus-stack \ -o jsonpath='{.items[0].metadata.name}') echo "Grafana Pod Name: ${GRAFANA_POD_NAME}"  `

    b.  **Reset the Grafana Admin Password inside the Pod:**
    Replace `<YOUR_SECURE_PASSWORD>` with the password you wish to use (you can use the same one you entered during the `app_build_and_verification.sh` script, or a new one).
    ` kubectl exec -it ${GRAFANA_POD_NAME} -n prometheus-operator \ -- grafana-cli admin reset-admin-password <YOUR_SECURE_PASSWORD>  `
    You should see output confirming the password reset, e.g., `Admin password reset successfully`.

    c.  **Restart the Grafana Pod (Recommended):**
    To ensure Grafana picks up the changes, it's often helpful to restart the pod. Kubernetes will automatically create a new one.
    ` kubectl delete pod ${GRAFANA_POD_NAME} -n prometheus-operator  `
    Wait a minute or two for the new Grafana pod to become `Running` and `Ready` (verify with `kubectl get pods -n prometheus-operator`).

    d.  **Try logging in again:**
    \* Ensure your Grafana port-forward is active (refer to [8.3. Access Grafana UI (via `kubectl port-forward`)](https://www.google.com/search?q=%2383-access-grafana-ui-via-kubectl-port-forward)).
    \* Navigate to `http://localhost:3000`.
    \* Use username: `admin` and the password you set in step 2b.

-----

## 10\. API Endpoints

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

## 11\. Configuration

-----

The application can be configured using environment variables:

  * `PORT`: The port the server listens on (default: `8443`).
  * `MAX_KEY_SIZE`: The maximum allowed length for generated keys in bytes (default: `64`).
  * `TLS_CERT_FILE`: Path to the TLS certificate file (e.g., `/etc/key-server/tls/server.crt`).
  * `TLS_KEY_FILE`: Path to the TLS private key file (e.g., `/etc/key-server/tls/server.key`).

-----

## 12\. Local Development (Manual)

-----

This section outlines the manual steps for local development, independent of Docker or Kubernetes.

1.  Clone the repository and navigate into the directory.
2.  **Generate TLS certificates:**
    ```bash
    mkdir -p certs
    openssl req -x509 -newkey rsa:4096 -nodes -keyout certs/server.key -out certs/server.crt -days 365 -subj "/CN=localhost"
    ```
3.  **Build the Go application binary:**
    ```bash
    go build -o key-server .
    ```
4.  **Run the application:**
    ```bash
    PORT=8443 MAX_KEY_SIZE=64 \
    TLS_CERT_FILE=./certs/server.crt \
    TLS_KEY_FILE=./certs/server.key ./key-server
    ```
    Keep this terminal open while testing.
5.  **Test endpoints using `curl` (in a new terminal):**
    ```bash
    curl -k https://localhost:8443/health
    curl -k https://localhost:8443/key/32
    ```
6.  **Stop the application:** Press `Ctrl+C` in the terminal running the application.

-----

## 13\. Docker (Manual)

-----

This section outlines the manual steps for building and running the application as a Docker container.

1.  **Build the Docker image:**
    ```bash
    docker build -t key-server .
    ```
2.  **Run the Docker container:**
    Ensure `certs/server.crt` and `certs/server.key` exist (generate them as shown in [Local Development (Manual)](https://www.google.com/search?q=%2312-local-development-manual)).
    ```bash
    docker run -d --name key-server-test -p 8443:8443 \
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
    docker stop key-server-test
    docker rm key-server-test
    ```

-----

## 14\. Kubernetes (Helm - Manual)

-----

The `app_build_and_verification.sh` script automates this, but here are the manual steps for deploying just the Key Server application with Helm (without the full monitoring stack setup).

1.  **Create a Kind cluster (if not already running):**
    ```bash
    kind create cluster --name key-server
    ```
2.  **Load the Docker image into Kind:**
    ```bash
    kind load docker-image key-server --name key-server
    ```
3.  **Create Kubernetes TLS secret:**
    Ensure `certs/server.crt` and `certs/server.key` exist. The secret name must match what the Helm chart expects (`key-server-key-server-app-tls-secret`).
    ```bash
    kubectl create secret tls key-server-key-server-app-tls-secret --cert="./certs/server.crt" --key="./certs/server.key"
    ```
4.  **Install/Upgrade the Helm chart:**
    ```bash
    helm upgrade --install key-server ./deploy/kubernetes/key-server-chart \
      --set image.repository=key-server \
      --set image.tag=latest \
      --set service.type=NodePort \
      --set ingress.enabled=true \
      --set ingress.tls[0].secretName=key-server-key-server-app-tls-secret \
      --set config.maxKeySize=64 \
      --set service.port=8443 \
      --set service.targetPort=8443 \
      --wait --timeout 10m
    ```
5.  **Verify deployment** (using `kubectl port-forward` as described in [8.1. Verify Kubernetes Pods and Services](https://www.google.com/search?q=%2381-verify-kubernetes-pods-and-services)).

