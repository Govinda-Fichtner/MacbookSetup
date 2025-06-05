# syntax=docker/dockerfile:1

# Builder stage
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files and install all dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy source code and build
COPY . .
RUN npm run build

# Runner stage
FROM node:20-alpine AS runner
WORKDIR /app

# Install Heroku CLI - required for the MCP server to function
RUN apk add --no-cache curl bash \
    && curl -L https://cli-assets.heroku.com/install.sh | sh \
    && apk del curl

# Copy package files and install production dependencies without scripts
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --production --ignore-scripts

# Copy built artifacts from builder and bin directory
COPY --from=builder /app/dist ./dist
COPY bin ./bin

# Ensure executable permissions
RUN chmod +x dist/index.js bin/heroku-mcp-server.mjs

# Use node to run the MCP server via the correct entry point
ENTRYPOINT ["node", "bin/heroku-mcp-server.mjs"]
