# Stage 1: Builder
# Use a Go base image for building the application
FROM golang:1.22-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy go.mod and go.sum files to leverage Docker layer caching
COPY go.mod go.sum ./

# Download Go modules (this step is cached if go.mod/go.sum don't change)
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go application
# -o key-server: Specifies the output binary name
# -ldflags "-s -w": Reduces the binary size by omitting debug information
RUN go build -o key-server -ldflags "-s -w" .

# Stage 2: Runner
# Use a minimal Alpine Linux image for the final application
FROM alpine:latest

# Create a non-root user and group for security best practices
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set the working directory for the application
WORKDIR /app

# Copy the compiled application binary from the builder stage
COPY --from=builder /app/key-server /app/key-server

# IMPORTANT: DO NOT COPY TLS CERTIFICATES HERE.
# They will be mounted from Kubernetes Secrets at runtime.
# The previous problematic line: COPY --chown=appuser:appgroup server.crt server.key /app/
# This line is intentionally REMOVED to ensure secrets are not baked into the image.

# Set permissions for the application binary
RUN chown appuser:appgroup /app/key-server
RUN chmod +x /app/key-server

# Expose the port the application listens on (e.g., 8443 for HTTPS)
EXPOSE 8443

# Set the non-root user to run the application
USER appuser

# Define the command to run the application when the container starts
ENTRYPOINT ["/app/key-server"]
