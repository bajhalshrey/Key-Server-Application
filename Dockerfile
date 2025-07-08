# --- Stage 1: Builder ---
FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN go build -o key-server -ldflags "-s -w" .

# --- Stage 2: Runner ---
FROM alpine:latest AS runner

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set the working directory for the runner stage
WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/key-server /app/key-server

# --- CHANGE IS HERE ---
# Copy the SSL certificates for HTTPS from your project and set their ownership
COPY --chown=appuser:appgroup server.crt server.key /app/
# --- END CHANGE ---

# Set the non-root user
USER appuser

# Expose the port your application listens on
EXPOSE 8080

# Define the command to run when the container starts
ENTRYPOINT ["/app/key-server"]
CMD ["--srv-port", "8080", "--max-size", "1024"]