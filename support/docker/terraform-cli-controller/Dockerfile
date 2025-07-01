# Use Alpine Rust image for building
FROM rust:1.82-alpine as builder

# Install build dependencies for Alpine
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev

# Install tfmcp from crates.io, targeting musl
RUN cargo install tfmcp

# Use minimal Alpine runtime image
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl

# Install Terraform for Alpine
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip -o terraform.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform.zip && \
    chmod +x /usr/local/bin/terraform

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -h /app

# Set working directory
WORKDIR /app

# Copy the tfmcp binary from builder with proper ownership
COPY --from=builder --chown=appuser:appgroup /usr/local/cargo/bin/tfmcp /usr/local/bin/tfmcp

# Make sure the binary is executable
RUN chmod +x /usr/local/bin/tfmcp

# Ensure appuser has access to terraform binary
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Set the entrypoint
ENTRYPOINT ["tfmcp"]
CMD ["mcp"]
