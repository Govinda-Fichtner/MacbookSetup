FROM golang:latest AS builder

WORKDIR /app

COPY ./ ./
RUN make build

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
WORKDIR /app

# Create non-root user for security
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid 1001 --no-create-home --home-dir /app appuser && \
    chown -R appuser:appgroup /app

COPY --from=builder --chown=appuser:appgroup /app/kubernetes-mcp-server /app/kubernetes-mcp-server

# Switch to non-root user
USER appuser

ENTRYPOINT ["/app/kubernetes-mcp-server"]
