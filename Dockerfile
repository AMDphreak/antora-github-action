# =============================================================================
# Antora Build Docker Image
# =============================================================================
#
# This Dockerfile creates an image for building Antora documentation sites.
# It's used as an alternative to the composite action for users who prefer
# Docker-based execution or need additional system dependencies.
#
# The composite action (action.yml with 'using: composite') is recommended
# for most users as it's faster (no Docker build overhead) and more flexible.
#
# This Docker approach is useful when:
#   - You need system-level dependencies not available in GitHub runners
#   - You want reproducible builds with a fixed environment
#   - You're running in a self-hosted runner without Node.js
#
# =============================================================================

FROM node:20-alpine

# Install git (required for Antora to fetch content sources)
# Also install ca-certificates for HTTPS support
RUN apk add --no-cache git ca-certificates

# Create non-root user for security
RUN addgroup -S antora && adduser -S antora -G antora

# Set up npm global directory for non-root user
ENV NPM_CONFIG_PREFIX=/home/antora/.npm-global
ENV PATH=$NPM_CONFIG_PREFIX/bin:$PATH
RUN mkdir -p /home/antora/.npm-global && chown -R antora:antora /home/antora

# Switch to non-root user
USER antora
WORKDIR /home/antora

# Install Antora globally
# Using specific version for reproducibility; override with build args if needed
ARG ANTORA_VERSION=latest
RUN npm install -g @antora/cli@${ANTORA_VERSION} @antora/site-generator@${ANTORA_VERSION}

# Copy and set up entrypoint script
USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER antora

# The entrypoint handles credential setup and runs Antora
ENTRYPOINT ["/entrypoint.sh"]

# Default command shows help (overridden by action inputs)
CMD ["--help"]

