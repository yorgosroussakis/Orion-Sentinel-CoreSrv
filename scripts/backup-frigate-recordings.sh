#!/usr/bin/env bash
# ============================================================================
# Frigate Recording Backup & Retention Script
# ============================================================================
#
# PURPOSE:
#   Implements a two-tier retention strategy for Frigate camera recordings:
#   - Primary storage (SSD): Keep event clips for 14 days
#   - Backup storage (HDD): Archive clips for another 30 days
#   - Total retention: ~44 days before final deletion
#
# USAGE:
#   Run this script daily via cron or systemd timer
#
# EXAMPLE CRON ENTRY (runs daily at 03:30 AM):
#   30 3 * * * /usr/bin/env bash /path/to/Orion-Sentinel-CoreSrv/scripts/backup-frigate-recordings.sh >> /var/log/frigate-backup.log 2>&1
#
# EXAMPLE SYSTEMD TIMER (save as /etc/systemd/system/frigate-backup.timer):
#   [Unit]
#   Description=Frigate Recording Backup & Retention
#   
#   [Timer]
#   OnCalendar=daily
#   OnCalendar=03:30
#   Persistent=true
#   
#   [Install]
#   WantedBy=timers.target
#
# REQUIREMENTS:
#   - ORION_CCTV_MEDIA_DIR must be set (primary storage path)
#   - ORION_CCTV_BACKUP_DIR must be set (backup storage path)
#   - Both directories must be mounted and accessible
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Source environment variables from .env file if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

# Primary storage directory (hot/fast storage - 14 days)
PRIMARY_DIR="${ORION_CCTV_MEDIA_DIR:-}"

# Backup storage directory (archive/slow storage - 30 days)
BACKUP_DIR="${ORION_CCTV_BACKUP_DIR:-}"

# Retention periods in days
PRIMARY_RETENTION_DAYS=14
BACKUP_RETENTION_DAYS=44  # Total: 14 days primary + 30 days backup = 44 days

# Dry run mode (set to 1 to see what would be done without making changes)
DRY_RUN="${DRY_RUN:-0}"

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

die() {
    error "$*"
    exit 1
}

check_directory() {
    local dir="$1"
    local name="$2"
    
    if [[ -z "$dir" ]]; then
        die "$name directory is not set. Please set it in .env file or environment."
    fi
    
    if [[ ! -d "$dir" ]]; then
        die "$name directory does not exist: $dir"
    fi
    
    if [[ ! -r "$dir" ]] || [[ ! -w "$dir" ]]; then
        die "$name directory is not readable/writable: $dir"
    fi
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

log "=========================================="
log "Frigate Recording Backup & Retention"
log "=========================================="
log "Primary storage: $PRIMARY_DIR"
log "Backup storage:  $BACKUP_DIR"
log "Primary retention: $PRIMARY_RETENTION_DAYS days"
log "Total retention:   $BACKUP_RETENTION_DAYS days"

if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY RUN MODE - No changes will be made"
fi

# ============================================================================
# STEP 1: Validate directories
# ============================================================================

log "Validating directories..."
check_directory "$PRIMARY_DIR" "Primary"
check_directory "$BACKUP_DIR" "Backup"

# ============================================================================
# STEP 2: Create backup directory structure if needed
# ============================================================================

log "Ensuring backup directory structure exists..."
if [[ "$DRY_RUN" != "1" ]]; then
    mkdir -p "$BACKUP_DIR"
fi

# ============================================================================
# STEP 3: Move recordings older than 14 days from primary to backup
# ============================================================================

log "Moving recordings older than $PRIMARY_RETENTION_DAYS days to backup..."

# Find directories/files in primary storage older than PRIMARY_RETENTION_DAYS
# Frigate stores recordings in: /media/frigate/{camera_name}/{date}/
# We need to preserve directory structure when moving

MOVED_COUNT=0
MOVED_SIZE=0

# Process each camera directory
for camera_dir in "$PRIMARY_DIR"/*; do
    if [[ ! -d "$camera_dir" ]]; then
        continue
    fi
    
    # Find date directories older than PRIMARY_RETENTION_DAYS days
    while IFS= read -r -d '' date_dir; do
        if [[ ! -d "$date_dir" ]]; then
            continue
        fi
        
        relative_path="${date_dir#"$PRIMARY_DIR"/}"
        backup_path="$BACKUP_DIR/$relative_path"
        
        # Calculate size before moving
        dir_size=$(du -sb "$date_dir" 2>/dev/null | cut -f1 || echo "0")
        
        log "Moving: $relative_path ($(numfmt --to=iec-i --suffix=B "$dir_size" 2>/dev/null || echo "${dir_size}B"))"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            # Create parent directory in backup location
            mkdir -p "$(dirname "$backup_path")"
            
            # Move the entire date directory
            if mv "$date_dir" "$backup_path"; then
                MOVED_COUNT=$((MOVED_COUNT + 1))
                MOVED_SIZE=$((MOVED_SIZE + dir_size))
            else
                error "Failed to move: $date_dir"
            fi
        else
            MOVED_COUNT=$((MOVED_COUNT + 1))
            MOVED_SIZE=$((MOVED_SIZE + dir_size))
        fi
    done < <(find "$camera_dir" -mindepth 1 -maxdepth 1 -type d -mtime +$PRIMARY_RETENTION_DAYS -print0 2>/dev/null)
done

log "Moved $MOVED_COUNT directories ($(numfmt --to=iec-i --suffix=B "$MOVED_SIZE" 2>/dev/null || echo "${MOVED_SIZE}B"))"

# ============================================================================
# STEP 4: Delete recordings older than 44 days from both locations
# ============================================================================

log "Purging recordings older than $BACKUP_RETENTION_DAYS days..."

PURGED_COUNT=0
PURGED_SIZE=0

# Purge from primary storage (shouldn't be many, but clean up just in case)
for camera_dir in "$PRIMARY_DIR"/*; do
    if [[ ! -d "$camera_dir" ]]; then
        continue
    fi
    
    while IFS= read -r -d '' date_dir; do
        if [[ ! -d "$date_dir" ]]; then
            continue
        fi
        
        relative_path="${date_dir#"$PRIMARY_DIR"/}"
        dir_size=$(du -sb "$date_dir" 2>/dev/null | cut -f1 || echo "0")
        
        log "Purging from primary: $relative_path ($(numfmt --to=iec-i --suffix=B "$dir_size" 2>/dev/null || echo "${dir_size}B"))"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            if rm -rf "$date_dir"; then
                PURGED_COUNT=$((PURGED_COUNT + 1))
                PURGED_SIZE=$((PURGED_SIZE + dir_size))
            else
                error "Failed to purge: $date_dir"
            fi
        else
            PURGED_COUNT=$((PURGED_COUNT + 1))
            PURGED_SIZE=$((PURGED_SIZE + dir_size))
        fi
    done < <(find "$camera_dir" -mindepth 1 -maxdepth 1 -type d -mtime +$BACKUP_RETENTION_DAYS -print0 2>/dev/null)
done

# Purge from backup storage
for camera_dir in "$BACKUP_DIR"/*; do
    if [[ ! -d "$camera_dir" ]]; then
        continue
    fi
    
    while IFS= read -r -d '' date_dir; do
        if [[ ! -d "$date_dir" ]]; then
            continue
        fi
        
        relative_path="${date_dir#"$BACKUP_DIR"/}"
        dir_size=$(du -sb "$date_dir" 2>/dev/null | cut -f1 || echo "0")
        
        log "Purging from backup: $relative_path ($(numfmt --to=iec-i --suffix=B "$dir_size" 2>/dev/null || echo "${dir_size}B"))"
        
        if [[ "$DRY_RUN" != "1" ]]; then
            if rm -rf "$date_dir"; then
                PURGED_COUNT=$((PURGED_COUNT + 1))
                PURGED_SIZE=$((PURGED_SIZE + dir_size))
            else
                error "Failed to purge: $date_dir"
            fi
        else
            PURGED_COUNT=$((PURGED_COUNT + 1))
            PURGED_SIZE=$((PURGED_SIZE + dir_size))
        fi
    done < <(find "$camera_dir" -mindepth 1 -maxdepth 1 -type d -mtime +$BACKUP_RETENTION_DAYS -print0 2>/dev/null)
done

log "Purged $PURGED_COUNT directories ($(numfmt --to=iec-i --suffix=B "$PURGED_SIZE" 2>/dev/null || echo "${PURGED_SIZE}B"))"

# ============================================================================
# STEP 5: Report storage usage
# ============================================================================

log "Storage usage:"

if command -v df &> /dev/null; then
    PRIMARY_USAGE=$(df -h "$PRIMARY_DIR" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}' || echo "unknown")
    BACKUP_USAGE=$(df -h "$BACKUP_DIR" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}' || echo "unknown")
    log "  Primary: $PRIMARY_USAGE"
    log "  Backup:  $BACKUP_USAGE"
else
    log "  (df command not available, skipping usage report)"
fi

# ============================================================================
# DONE
# ============================================================================

log "=========================================="
log "Backup & retention completed successfully"
log "=========================================="

exit 0
