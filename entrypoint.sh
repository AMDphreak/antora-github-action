#!/bin/sh
# =============================================================================
# Antora Build Entrypoint Script
# =============================================================================
#
# This script is the entrypoint for the Docker-based Antora action.
# It handles:
#   1. Setting up Git credentials for private repository access
#   2. Installing additional extensions if specified
#   3. Running the Antora build
#
# Environment Variables:
#   GIT_CREDENTIALS        - Credentials in .git-credentials format
#   GIT_CREDENTIALS_PATH   - Path to credentials file
#   GITHUB_TOKEN           - GitHub token (convenience for GitHub-only setups)
#   ANTORA_EXTENSIONS      - Space-separated list of npm packages to install
#   PLAYBOOK               - Path to Antora playbook (default: antora-playbook.yml)
#   ANTORA_FETCH           - Whether to fetch content sources (default: true)
#   ANTORA_LOG_LEVEL       - Log level (default: warn)
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configure Git Credentials
# -----------------------------------------------------------------------------
# Antora needs credentials to access private repositories.
# This section sets up the .git-credentials file that Git uses for HTTPS auth.
#
# The .git-credentials file format is one credential per line:
#   https://<user>:<token>@<host>
#
# Examples:
#   https://x-access-token:ghp_xxxx@github.com     (GitHub PAT)
#   https://oauth2:glpat-xxxx@gitlab.com          (GitLab PAT)
#   https://x-token-auth:xxxx@bitbucket.org       (Bitbucket app password)
#
# Antora also reads the GIT_CREDENTIALS environment variable directly,
# which has the same format. This script sets up both methods for compatibility.
# -----------------------------------------------------------------------------

setup_credentials() {
    CREDS_FILE="$HOME/.git-credentials"
    
    # Priority: GIT_CREDENTIALS > GIT_CREDENTIALS_PATH > GITHUB_TOKEN
    if [ -n "$GIT_CREDENTIALS" ]; then
        echo "[credentials] Using GIT_CREDENTIALS environment variable"
        echo "$GIT_CREDENTIALS" > "$CREDS_FILE"
    elif [ -n "$GIT_CREDENTIALS_PATH" ]; then
        echo "[credentials] Using credentials file: $GIT_CREDENTIALS_PATH"
        if [ -f "$GIT_CREDENTIALS_PATH" ]; then
            cp "$GIT_CREDENTIALS_PATH" "$CREDS_FILE"
        else
            echo "[credentials] ERROR: Credentials file not found: $GIT_CREDENTIALS_PATH"
            exit 1
        fi
    elif [ -n "$GITHUB_TOKEN" ]; then
        echo "[credentials] Using GITHUB_TOKEN"
        echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > "$CREDS_FILE"
    else
        echo "[credentials] No credentials provided (public repos only)"
    fi
    
    # Configure git to use the credentials file
    if [ -f "$CREDS_FILE" ]; then
        chmod 600 "$CREDS_FILE"
        git config --global credential.helper "store --file=$CREDS_FILE"
    fi
}

# -----------------------------------------------------------------------------
# Install Additional Extensions
# -----------------------------------------------------------------------------
# Extensions are npm packages that add functionality to Antora.
# Common extensions include:
#   @antora/lunr-extension      - Full-text search
#   @antora/collector-extension - Collect content from various sources
#   @antora/pdf-extension       - Generate PDF output
#   asciidoctor-kroki           - Diagram generation (PlantUML, Mermaid, etc.)
# -----------------------------------------------------------------------------

install_extensions() {
    if [ -n "$ANTORA_EXTENSIONS" ]; then
        echo "[extensions] Installing: $ANTORA_EXTENSIONS"
        npm install -g $ANTORA_EXTENSIONS
    fi
}

# -----------------------------------------------------------------------------
# Run Antora Build
# -----------------------------------------------------------------------------

run_build() {
    # Default values
    PLAYBOOK="${PLAYBOOK:-antora-playbook.yml}"
    ANTORA_FETCH="${ANTORA_FETCH:-true}"
    ANTORA_LOG_LEVEL="${ANTORA_LOG_LEVEL:-warn}"
    
    # Build command arguments
    ARGS=""
    
    if [ "$ANTORA_FETCH" = "true" ]; then
        ARGS="$ARGS --fetch"
    fi
    
    ARGS="$ARGS --log-level $ANTORA_LOG_LEVEL"
    
    # Change to workspace directory if set
    if [ -n "$GITHUB_WORKSPACE" ]; then
        cd "$GITHUB_WORKSPACE"
    fi
    
    echo "[build] Running: antora $ARGS $PLAYBOOK"
    antora $ARGS "$PLAYBOOK"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    # If arguments are passed, run antora directly with those args
    # This allows using the container as a generic antora runner
    if [ $# -gt 0 ] && [ "$1" != "--help" ]; then
        exec antora "$@"
    fi
    
    # Otherwise, run the standard build process
    setup_credentials
    install_extensions
    run_build
}

main "$@"

