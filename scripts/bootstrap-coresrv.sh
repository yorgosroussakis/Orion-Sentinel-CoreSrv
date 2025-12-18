#!/usr/bin/env bash
# ============================================================================
# bootstrap-coresrv.sh - Orion-Sentinel-CoreSrv Bootstrap Script
# ============================================================================
#
# This script automates the initial setup of Orion-Sentinel-CoreSrv:
#   1. Checks and installs Docker + Docker Compose if needed
#   2. Creates necessary directory structure
#   3. Copies .env.example to .env if not present
#   4. Creates Docker networks
#   5. Prompts user to edit configuration
#
# This script is idempotent and safe to re-run.
#
# Usage:
#   ./scripts/bootstrap-coresrv.sh
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default data root - can be overridden
DEFAULT_DATA_ROOT="/srv/orion-sentinel-core"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repo root
cd "$REPO_ROOT"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo -e "\n${CYAN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $*${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
}

info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*"
}

fail() {
    error "$*"
    exit 1
}

# Ensure a path is a directory (not a file)
# If it exists as a file, remove and recreate as directory
ensure_dir() {
    local dir_path="$1"
    if [ -f "$dir_path" ]; then
        warn "Path $dir_path exists as file, converting to directory..."
        rm -f "$dir_path"
    fi
    mkdir -p "$dir_path"
}

# Ensure a path is a file (not a directory)
# If it exists as a directory, remove and recreate as file
# Args: path, default_content (optional), source_template (optional)
ensure_file() {
    local file_path="$1"
    local default_content="${2:-}"
    local source_template="${3:-}"
    
    # Make sure parent directory exists
    mkdir -p "$(dirname "$file_path")"
    
    if [ -d "$file_path" ]; then
        warn "Path $file_path exists as directory, converting to file..."
        rm -rf "$file_path"
    fi
    
    if [ ! -f "$file_path" ]; then
        if [ -n "$source_template" ] && [ -f "$source_template" ]; then
            info "Creating $file_path from template..."
            cp "$source_template" "$file_path"
        elif [ -n "$default_content" ]; then
            info "Creating $file_path with default content..."
            echo "$default_content" > "$file_path"
        else
            info "Creating empty $file_path..."
            touch "$file_path"
        fi
        success "Created file: $file_path"
    else
        success "File already exists: $file_path"
    fi
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Orion-Sentinel-CoreSrv Bootstrap Script"

echo "This script will set up your Orion Sentinel CoreSrv environment."
echo "It will:"
echo "  1. Check for Docker and install if needed"
echo "  2. Create directory structure"
echo "  3. Set up environment files"
echo "  4. Create Docker networks"
echo ""
read -p "Continue? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    info "Bootstrap cancelled"
    exit 0
fi

# ============================================================================
# STEP 1: Check Docker Installation
# ============================================================================

print_header "Step 1: Checking Docker Installation"

if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    success "Docker is installed (version $DOCKER_VERSION)"
else
    warn "Docker is not installed"
    read -p "Install Docker now? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker "$USER"
        success "Docker installed"
        warn "You need to log out and back in for group changes to take effect"
    else
        fail "Docker is required. Please install Docker and run this script again."
    fi
fi

# Check Docker Compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version | cut -d' ' -f4 | tr -d 'v')
    success "Docker Compose is installed (version $COMPOSE_VERSION)"
else
    warn "Docker Compose plugin not found"
    read -p "Install Docker Compose plugin? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        info "Installing Docker Compose plugin..."
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        success "Docker Compose plugin installed"
    else
        fail "Docker Compose is required. Please install it and run this script again."
    fi
fi

# ============================================================================
# STEP 2: Create Directory Structure
# ============================================================================

print_header "Step 2: Creating Directory Structure"

echo "Default data root: $DEFAULT_DATA_ROOT"
read -p "Use this location? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    read -p "Enter custom data root path: " DATA_ROOT
else
    DATA_ROOT="$DEFAULT_DATA_ROOT"
fi

info "Creating directories under $DATA_ROOT..."

# Create main directories
sudo mkdir -p "$DATA_ROOT"/{core,media,monitoring,home-automation,cloud,maintenance,nvr}

# Core services
sudo mkdir -p "$DATA_ROOT"/core/{traefik/{dynamic,acme},authelia,redis}

# Media stack
sudo mkdir -p "$DATA_ROOT"/media/config/{jellyfin,qbittorrent,sonarr,radarr,prowlarr,jellyseerr,bazarr}
sudo mkdir -p "$DATA_ROOT"/media/content/{downloads,library}/{movies,tv}

# Monitoring
sudo mkdir -p "$DATA_ROOT"/monitoring/{prometheus/{data,rules},grafana/{data,provisioning,dashboards},loki,promtail,uptime-kuma}

# Home automation
sudo mkdir -p "$DATA_ROOT"/home-automation/{homeassistant,zigbee2mqtt,mosquitto/{config,data,log},mealie,dsmr}

# NVR / Frigate (camera recording)
sudo mkdir -p "$DATA_ROOT"/nvr/frigate

# Cloud
sudo mkdir -p "$DATA_ROOT"/cloud/{nextcloud,postgresql}

# Maintenance
sudo mkdir -p "$DATA_ROOT"/maintenance/{homepage,watchtower}

# Set ownership
info "Setting directory ownership..."
sudo chown -R "$USER":"$USER" "$DATA_ROOT"

success "Directory structure created"

# ============================================================================
# STEP 3: Environment Files
# ============================================================================

print_header "Step 3: Setting Up Environment Files"

# Check if .env exists
if [ -f .env ]; then
    success ".env already exists, skipping copy"
else
    if [ -f .env.example ]; then
        info "Copying .env.example to .env..."
        cp .env.example .env
        success ".env created from template"
        warn "You MUST edit .env before starting services!"
    else
        warn ".env.example not found, skipping"
    fi
fi

# Module-specific env files
declare -a ENV_FILES=(
    "env/.env.media:env/.env.media.modular.example"
    "env/.env.gateway:env/.env.gateway.example"
    "env/.env.observability:env/.env.observability.example"
    "env/.env.homeauto:env/.env.homeauto.example"
)

for env_mapping in "${ENV_FILES[@]}"; do
    IFS=':' read -r target source <<< "$env_mapping"
    if [ -f "$target" ]; then
        success "$target already exists"
    else
        if [ -f "$source" ]; then
            info "Copying $source to $target..."
            cp "$source" "$target"
            success "$target created"
        else
            warn "$source not found, skipping"
        fi
    fi
done

# Update paths in .env if it was just created
if [ -f .env ] && [ "$DATA_ROOT" != "$DEFAULT_DATA_ROOT" ]; then
    info "Updating paths in .env to use $DATA_ROOT..."
    sed -i "s|$DEFAULT_DATA_ROOT|$DATA_ROOT|g" .env
    success "Paths updated in .env"
fi

# ============================================================================
# STEP 4: Copy Configuration Templates
# ============================================================================

print_header "Step 4: Copying Configuration Templates"

# IMPORTANT: These must be FILES, not directories
# Using ensure_file to prevent "is a directory" mount errors

# Traefik configuration - MUST be a file, not directory
if [ -f core/traefik/traefik.yml ]; then
    ensure_file "$DATA_ROOT/core/traefik/traefik.yml" "" "core/traefik/traefik.yml"
    # Copy dynamic config directory
    ensure_dir "$DATA_ROOT/core/traefik/dynamic"
    if [ -d core/traefik/dynamic ]; then
        cp -n core/traefik/dynamic/* "$DATA_ROOT/core/traefik/dynamic/" 2>/dev/null || true
        success "Traefik dynamic config copied"
    fi
    ensure_dir "$DATA_ROOT/core/traefik/acme"
fi

# Mosquitto configuration - MUST be a file, not directory
if [ -f home-automation/mosquitto/mosquitto.conf.example ]; then
    ensure_file "$DATA_ROOT/home-automation/mosquitto/mosquitto.conf" "" "home-automation/mosquitto/mosquitto.conf.example"
    ensure_dir "$DATA_ROOT/home-automation/mosquitto/data"
    ensure_dir "$DATA_ROOT/home-automation/mosquitto/log"
fi

# Prometheus configuration - MUST be a file, not directory
if [ -f monitoring/prometheus/prometheus.yml ]; then
    ensure_file "$DATA_ROOT/monitoring/prometheus/prometheus.yml" "" "monitoring/prometheus/prometheus.yml"
    ensure_dir "$DATA_ROOT/monitoring/prometheus/data"
fi

# Loki configuration - MUST be a file, not directory
if [ -f monitoring/loki/config.yml ]; then
    ensure_file "$DATA_ROOT/monitoring/loki/config.yml" "" "monitoring/loki/config.yml"
fi

# Promtail configuration - MUST be a file, not directory
if [ -f monitoring/promtail/config.yml ]; then
    ensure_file "$DATA_ROOT/monitoring/promtail/config.yml" "" "monitoring/promtail/config.yml"
fi

# Authelia configuration (optional - not used in Traefik-only mode)
if [ -f core/authelia/configuration.yml.example ] && [ ! -f "$DATA_ROOT"/core/authelia/configuration.yml ]; then
    info "Copying Authelia configuration (optional)..."
    cp core/authelia/configuration.yml.example "$DATA_ROOT"/core/authelia/configuration.yml
    success "Authelia configuration copied"
fi

if [ -f core/authelia/users.yml.example ] && [ ! -f "$DATA_ROOT"/core/authelia/users.yml ]; then
    info "Copying Authelia users template (optional)..."
    cp core/authelia/users.yml.example "$DATA_ROOT"/core/authelia/users.yml
    success "Authelia users template copied"
fi

# Frigate NVR configuration
if [ -f config/frigate/config.example.yml ] && [ ! -f "$DATA_ROOT"/nvr/frigate/config.yml ]; then
    info "Copying Frigate configuration template..."
    cp config/frigate/config.example.yml "$DATA_ROOT"/nvr/frigate/config.yml
    success "Frigate configuration copied"
    warn "Edit $DATA_ROOT/nvr/frigate/config.yml with your camera details before starting NVR"
fi

# Grafana provisioning
if [ -d monitoring/grafana/provisioning ] && [ ! -d "$DATA_ROOT"/monitoring/grafana/provisioning/datasources ]; then
    info "Copying Grafana provisioning..."
    cp -r monitoring/grafana/provisioning "$DATA_ROOT"/monitoring/grafana/
    success "Grafana provisioning copied"
fi

# ============================================================================
# STEP 5: Generate Secrets
# ============================================================================

print_header "Step 5: Generating Secrets"

if command -v openssl >/dev/null 2>&1; then
    info "Generating Authelia secrets..."
    
    JWT_SECRET=$(openssl rand -hex 32)
    SESSION_SECRET=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    
    # Update .env if it exists - use unique placeholders for each secret
    if [ -f .env ]; then
        sed -i "s|AUTHELIA_JWT_SECRET=changeme-run-openssl-rand-hex-32-to-generate|AUTHELIA_JWT_SECRET=$JWT_SECRET|" .env
        sed -i "s|AUTHELIA_SESSION_SECRET=changeme-run-openssl-rand-hex-32-to-generate|AUTHELIA_SESSION_SECRET=$SESSION_SECRET|" .env
        sed -i "s|AUTHELIA_STORAGE_ENCRYPTION_KEY=changeme-run-openssl-rand-hex-32-to-generate|AUTHELIA_STORAGE_ENCRYPTION_KEY=$ENCRYPTION_KEY|" .env
        success "Authelia secrets generated and updated in .env"
    fi
    
    # Also update env/.env.gateway if it exists
    if [ -f env/.env.gateway ]; then
        sed -i "s|AUTHELIA_JWT_SECRET=change-me-run-openssl-rand-hex-32|AUTHELIA_JWT_SECRET=$JWT_SECRET|" env/.env.gateway
        sed -i "s|AUTHELIA_SESSION_SECRET=change-me-run-openssl-rand-hex-32|AUTHELIA_SESSION_SECRET=$SESSION_SECRET|" env/.env.gateway
        sed -i "s|AUTHELIA_STORAGE_ENCRYPTION_KEY=change-me-run-openssl-rand-hex-32|AUTHELIA_STORAGE_ENCRYPTION_KEY=$ENCRYPTION_KEY|" env/.env.gateway
        success "Authelia secrets updated in env/.env.gateway"
    fi
else
    warn "openssl not found, skipping secret generation"
    warn "You must manually generate secrets for Authelia"
fi

# ============================================================================
# STEP 6: Create Docker Networks
# ============================================================================

print_header "Step 6: Creating Docker Networks"

declare -a NETWORKS=(
    "orion_media_net"
    "orion_gateway_net"
    "orion_backbone_net"
    "orion_observability_net"
    "orion_homeauto_net"
)

for network in "${NETWORKS[@]}"; do
    if docker network inspect "$network" >/dev/null 2>&1; then
        success "$network already exists"
    else
        info "Creating network $network..."
        docker network create "$network"
        success "$network created"
    fi
done

# ============================================================================
# STEP 7: Final Instructions
# ============================================================================

print_header "Bootstrap Complete!"

echo ""
echo "✓ Directory structure created at: $DATA_ROOT"
echo "✓ Environment files created"
echo "✓ Configuration templates copied"
echo "✓ Secrets generated"
echo "✓ Docker networks created"
echo ""
echo "${BOLD}Next Steps:${NC}"
echo ""
echo "1. Review and edit your configuration:"
echo "   ${CYAN}nano .env${NC}"
echo "   ${CYAN}nano env/.env.media${NC}"
echo "   ${CYAN}nano env/.env.gateway${NC}"
echo ""
echo "2. Important settings to configure:"
echo "   - DOMAIN (e.g., 'local' or 'yourdomain.com')"
echo "   - PUID and PGID (run 'id' to find yours)"
echo "   - VPN credentials (if using VPN for torrents)"
echo "   - Grafana admin password"
echo "   - MQTT credentials"
echo ""
echo "3. Start your services:"
echo "   ${CYAN}make up-media${NC}           # Media stack only"
echo "   ${CYAN}make up-traefik${NC}         # Add reverse proxy"
echo "   ${CYAN}make up-observability${NC}   # Add monitoring"
echo "   ${CYAN}make up-nvr${NC}             # Start NVR/Frigate (cameras)"
echo "   ${CYAN}make up-full${NC}            # Start everything"
echo ""
echo "4. For NVR/Frigate setup (camera recording):"
echo "   ${CYAN}nano $DATA_ROOT/nvr/frigate/config.yml${NC}"
echo "   - Add your camera IPs and credentials"
echo "   - Set ORION_CCTV_MEDIA_DIR and ORION_CCTV_BACKUP_DIR in .env"
echo "   - See README.md 'Orion Camera NVR' section for details"
echo ""
echo "5. Check service status:"
echo "   ${CYAN}make status${NC}"
echo ""
echo "6. View logs:"
echo "   ${CYAN}make logs${NC}"
echo "   ${CYAN}make logs SVC=jellyfin${NC}"
echo ""
echo "${YELLOW}Important Security Notes:${NC}"
echo "  - Change default passwords in .env"
echo "  - Set up Authelia users (edit $DATA_ROOT/core/authelia/users.yml)"
echo "  - Never commit .env files to version control"
echo ""
echo "For more information, see README.md"
echo ""

success "Bootstrap complete! Ready to deploy."
