# Context7 MCP Server - Custom Build for MacbookSetup
# Built from source for enhanced control and customization
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S context7 -u 1001

# Copy package files for efficient caching
COPY package*.json ./

# Install ALL dependencies (including devDependencies needed for build)
RUN npm install && \
    npm cache clean --force

# Copy source code
COPY --chown=context7:nodejs . .

# Build the application (TypeScript compilation)
RUN npm run build

# Remove source files and reinstall only production dependencies
RUN rm -rf src/ node_modules/ && \
    npm install --only=production && \
    npm cache clean --force

# Switch to non-root user
USER context7

# Set entrypoint for MCP STDIO transport
ENTRYPOINT ["node", "dist/index.js", "--transport", "stdio"]
