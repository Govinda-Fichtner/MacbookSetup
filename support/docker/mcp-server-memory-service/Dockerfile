# MCP Memory Service - Secure Dockerfile with non-root user
# Based on https://github.com/doobidoo/mcp-memory-service

# Stage 1: Build stage
FROM python:3.11-slim AS builder

# Force container paths for the application
# These will override any host environment variables
ENV MCP_MEMORY_CHROMA_PATH=/app/chroma_db \
    MCP_MEMORY_BACKUPS_PATH=/app/backups \
    CHROMA_DB_PATH=/app/chroma_db \
    BACKUP_PATH=/app/backups

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    build-essential \
    libffi-dev \
    libssl-dev \
    libsqlite3-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install core dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Install the package in development mode
RUN pip install --no-cache-dir -e .

# Stage 2: Runtime stage
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user and set up the environment
RUN addgroup --system --gid 1001 appuser && \
    adduser --system --uid 1001 --gid 1001 --no-create-home appuser

WORKDIR /app

# Create necessary directories with correct permissions
RUN mkdir -p /app/chroma_db /app/backups \
    /home/appuser/.local/share/mcp-memory \
    /home/appuser/.cache/huggingface/hub && \
    chown -R appuser:appuser /app /home/appuser && \
    chmod -R 777 /app/chroma_db /app/backups

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

# Set other environment variables
ENV PYTHONPATH=/app/src \
    MCP_MEMORY_USE_ONNX=0 \
    MCP_MEMORY_BATCH_SIZE=4 \
    PYTORCH_ENABLE_MPS_FALLBACK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/appuser \
    XDG_CACHE_HOME=/home/appuser/.cache \
    XDG_DATA_HOME=/home/appuser/.local/share \
    TRANSFORMERS_CACHE=/home/appuser/.cache/huggingface/hub \
    HF_HOME=/home/appuser/.cache/huggingface

# Ensure these use the container paths, ignoring any host environment
ENV CHROMA_DB_PATH=/app/chroma_db \
    BACKUP_PATH=/app/backups

# Create a simple entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/sh

# Ensure the application directories exist
mkdir -p /app/chroma_db /app/backups
chown -R appuser:appuser /app/chroma_db /app/backups
chmod 777 /app/chroma_db /app/backups

# Log the environment for debugging
echo "=== Environment Variables ==="
printenv | sort
echo "=========================="

# Run the application as appuser
exec python -m mcp_memory_service.server "$@"
EOF

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command for the entrypoint
CMD ["--chroma-path", "/app/chroma_db"]

# Switch to non-root user
USER appuser

# Set the entrypoint for MCP stdio transport
ENTRYPOINT ["python", "-c", "from mcp_memory_service.server import main; main()"]
