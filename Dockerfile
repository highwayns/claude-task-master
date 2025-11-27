# =============================================================================
# Base Stage - Common dependencies
# =============================================================================
FROM node:18-alpine AS base

# Install essential build tools
RUN apk add --no-cache git

WORKDIR /app

# Copy root package files first
COPY package.json package-lock.json ./

# Copy configuration files
COPY turbo.json tsconfig.json tsdown.config.ts biome.json ./

# Copy workspace package files - create directories first
RUN mkdir -p apps/cli apps/mcp packages

# Copy app package files
COPY apps/cli/package*.json ./apps/cli/
COPY apps/mcp/package*.json ./apps/mcp/

# Copy package subdirectories - list them explicitly instead of wildcard
# Adjust these based on your actual package structure
COPY packages/tm-core/package*.json ./packages/tm-core/
COPY packages/tm-bridge/package*.json ./packages/tm-bridge/
COPY packages/build-config/package*.json ./packages/build-config/

# =============================================================================
# Dependencies Stage - Install all dependencies
# =============================================================================
FROM base AS dependencies

# Clear npm cache and install with better error reporting
RUN npm cache clean --force && \
    npm ci --include=dev --loglevel=verbose

# =============================================================================
# Build Stage - Build the application
# =============================================================================
FROM dependencies AS builder

# Copy source files
COPY . .

# Build the project
RUN npm run build

# =============================================================================
# Production Stage - Final production image
# =============================================================================
FROM node:18-alpine AS production

# Install runtime essentials
RUN apk add --no-cache \
    git \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S taskmaster && \
    adduser -S taskmaster -u 1001

WORKDIR /app

# Copy package files
COPY --from=base /app/package*.json ./

# Copy production dependencies
COPY --from=dependencies /app/node_modules ./node_modules

# Copy built artifacts from builder
COPY --from=builder /app/dist ./dist

# Copy assets and necessary runtime files
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/README.md ./
COPY --from=builder /app/LICENSE ./
COPY --from=builder /app/CHANGELOG.md ./

# Copy workspace packages (only built artifacts)
COPY --from=builder /app/apps/cli/dist ./apps/cli/dist
COPY --from=builder /app/apps/mcp/dist ./apps/mcp/dist
COPY --from=builder /app/packages/tm-core/dist ./packages/tm-core/dist
COPY --from=builder /app/packages/tm-bridge/dist ./packages/tm-bridge/dist
COPY --from=builder /app/packages/build-config/dist ./packages/build-config/dist

# Set ownership
RUN chown -R taskmaster:taskmaster /app

# Switch to non-root user
USER taskmaster

# Set environment variables
ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('healthy')" || exit 1

# Default to MCP server (can be overridden)
ENTRYPOINT ["node"]
CMD ["dist/mcp-server.js"]

# =============================================================================
# Development Stage - For local development with hot reload
# =============================================================================
FROM dependencies AS development

# Copy all source files
COPY . .

# Set environment
ENV NODE_ENV=development

# Expose common ports
EXPOSE 3000 8080

# Use development mode
CMD ["npm", "run", "dev"]

# =============================================================================
# CLI Stage - Optimized for CLI usage
# =============================================================================
FROM production AS cli

# Override entrypoint for CLI
ENTRYPOINT ["node", "dist/task-master.js"]
CMD ["--help"]

# =============================================================================
# MCP Stage - Optimized for MCP server
# =============================================================================
FROM production AS mcp

# Expose MCP server port if needed
EXPOSE 3000

# Set MCP server as default
ENTRYPOINT ["node"]
CMD ["dist/mcp-server.js"]
