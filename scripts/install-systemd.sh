#!/usr/bin/env bash
# ============================================================================
# install-systemd.sh - Install Orion Sentinel Systemd Units
# ============================================================================
#
# Installs the systemd service and timer units for automatic external SSD
# replication. This script:
#   1. Copies unit files to /etc/systemd/system/
#   2. Reloads systemd daemon
#   3. Enables the timer
#   4. Runs a dry-run test
#
# Usage:
#   sudo ./scripts/install-systemd.sh
#
# This script requires root privileges.
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Determine script location and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Systemd unit paths
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_FILE="orion-replica-sync.service"
TIMER_FILE="orion-replica-sync.timer"

# Default installation path for repo
INSTALL_PATH="/opt/orion/Orion-Sentinel-CoreSrv"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo -e "\n${CYAN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $*${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

err() {
    echo -e "${RED}[ERR]${NC} $*"
}

fail() {
    err "$*"
    exit 1
}

# ============================================================================
# CHECKS
# ============================================================================

# Check for root
if [[ $EUID -ne 0 ]]; then
    fail "This script requires root privileges. Run with sudo."
fi

# Check for systemctl
if ! command -v systemctl &> /dev/null; then
    fail "systemctl not found. This script requires systemd."
fi

# Check for unit files
if [[ ! -f "$REPO_ROOT/systemd/$SERVICE_FILE" ]]; then
    fail "Service file not found: $REPO_ROOT/systemd/$SERVICE_FILE"
fi

if [[ ! -f "$REPO_ROOT/systemd/$TIMER_FILE" ]]; then
    fail "Timer file not found: $REPO_ROOT/systemd/$TIMER_FILE"
fi

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Installing Orion Sentinel Systemd Units"

echo "Configuration:"
echo "  Repository root: $REPO_ROOT"
echo "  Install path:    $INSTALL_PATH"
echo "  Systemd dir:     $SYSTEMD_DIR"
echo ""

# ============================================================================
# STEP 1: Symlink or Copy Repository (if needed)
# ============================================================================

print_header "Step 1: Setting Up Repository Path"

if [[ "$REPO_ROOT" != "$INSTALL_PATH" ]]; then
    if [[ -L "$INSTALL_PATH" ]]; then
        CURRENT_TARGET=$(readlink -f "$INSTALL_PATH")
        if [[ "$CURRENT_TARGET" == "$REPO_ROOT" ]]; then
            success "Symlink already exists: $INSTALL_PATH -> $REPO_ROOT"
        else
            warn "Symlink points elsewhere: $INSTALL_PATH -> $CURRENT_TARGET"
            info "Updating symlink..."
            rm -f "$INSTALL_PATH"
            ln -s "$REPO_ROOT" "$INSTALL_PATH"
            success "Updated symlink: $INSTALL_PATH -> $REPO_ROOT"
        fi
    elif [[ -d "$INSTALL_PATH" ]]; then
        warn "Directory exists at $INSTALL_PATH (not a symlink)"
        warn "Skipping symlink creation - using existing directory"
    else
        info "Creating symlink: $INSTALL_PATH -> $REPO_ROOT"
        mkdir -p "$(dirname "$INSTALL_PATH")"
        ln -s "$REPO_ROOT" "$INSTALL_PATH"
        success "Created symlink"
    fi
else
    success "Repository is already at install path: $INSTALL_PATH"
fi

# ============================================================================
# STEP 2: Install Systemd Units
# ============================================================================

print_header "Step 2: Installing Systemd Unit Files"

# Copy service file
info "Installing $SERVICE_FILE..."
cp "$REPO_ROOT/systemd/$SERVICE_FILE" "$SYSTEMD_DIR/$SERVICE_FILE"
success "Installed $SYSTEMD_DIR/$SERVICE_FILE"

# Copy timer file
info "Installing $TIMER_FILE..."
cp "$REPO_ROOT/systemd/$TIMER_FILE" "$SYSTEMD_DIR/$TIMER_FILE"
success "Installed $SYSTEMD_DIR/$TIMER_FILE"

# ============================================================================
# STEP 3: Reload Systemd
# ============================================================================

print_header "Step 3: Reloading Systemd Daemon"

info "Running systemctl daemon-reload..."
systemctl daemon-reload
success "Daemon reloaded"

# ============================================================================
# STEP 4: Enable Timer
# ============================================================================

print_header "Step 4: Enabling Timer"

info "Enabling $TIMER_FILE..."
systemctl enable "$TIMER_FILE"
success "Timer enabled"

info "Starting $TIMER_FILE..."
systemctl start "$TIMER_FILE"
success "Timer started"

# ============================================================================
# STEP 5: Test Run (Dry-Run)
# ============================================================================

print_header "Step 5: Running Test (Dry-Run)"

info "Running replication script in dry-run mode..."
echo ""

SCRIPT_PATH="$INSTALL_PATH/scripts/replicate-external.sh"
if [[ -x "$SCRIPT_PATH" ]]; then
    # Run dry-run test (allow failure since mounts may not exist in CI)
    if "$SCRIPT_PATH" --dry-run 2>&1; then
        success "Dry-run test completed successfully"
    else
        warn "Dry-run test failed (mounts may not be available)"
        warn "This is expected if external SSDs are not mounted"
    fi
else
    warn "Script not executable: $SCRIPT_PATH"
    warn "Run: chmod +x $SCRIPT_PATH"
fi

# ============================================================================
# STEP 6: Show Status
# ============================================================================

print_header "Status Information"

echo "Timer Status:"
echo ""
systemctl status "$TIMER_FILE" --no-pager || true

echo ""
echo "Service Status:"
echo ""
systemctl status "$SERVICE_FILE" --no-pager || true

echo ""
echo "Upcoming Timer Schedule:"
echo ""
systemctl list-timers | grep -E "orion|NEXT|PASSED" || true

# ============================================================================
# STEP 7: Show Recent Logs (if any)
# ============================================================================

print_header "Recent Logs"

echo "Last 20 log entries:"
echo ""
journalctl -u orion-replica-sync.service -n 20 --no-pager 2>/dev/null || echo "(No logs yet)"

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Installation Complete!"

echo "Installed units:"
echo "  - $SYSTEMD_DIR/$SERVICE_FILE"
echo "  - $SYSTEMD_DIR/$TIMER_FILE"
echo ""
echo "Timer schedule: Nightly at 02:30"
echo ""
echo "Management commands:"
echo ""
echo "  # View timer status:"
echo "  systemctl list-timers | grep orion-replica"
echo ""
echo "  # Run replication manually:"
echo "  sudo systemctl start orion-replica-sync.service"
echo ""
echo "  # View logs:"
echo "  journalctl -u orion-replica-sync.service -f"
echo ""
echo "  # Disable timer:"
echo "  sudo systemctl disable --now orion-replica-sync.timer"
echo ""
echo "  # Uninstall:"
echo "  sudo systemctl disable --now orion-replica-sync.timer"
echo "  sudo rm $SYSTEMD_DIR/orion-replica-sync.{service,timer}"
echo "  sudo systemctl daemon-reload"
echo ""

success "Installation completed successfully!"
