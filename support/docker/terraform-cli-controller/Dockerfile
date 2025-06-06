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

# Copy the tfmcp binary from builder
COPY --from=builder /usr/local/cargo/bin/tfmcp /usr/local/bin/tfmcp

# Make sure the binary is executable
RUN chmod +x /usr/local/bin/tfmcp

# Set working directory
WORKDIR /app

# Set the entrypoint
ENTRYPOINT ["tfmcp"]
CMD ["mcp"]
