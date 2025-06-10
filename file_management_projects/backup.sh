#!/bin/bash
# backup.sh - A comprehensive file backup system
# Author: Clement MUGISHA
# Last modified: 16th May 2025
# Version: 1.0.2
#
# Usage: ./backup.sh [options]
# If no options are specified, uses the default configuration.
#
# Features:
# - Full and incremental backups
# - Compression options (gzip, bzip2, xz, none)
# - Scheduling capabilities through cron
# - Retention policy management
# - Detailed logging
# - Backup restoration
#
# Options:
#   -s, --source DIR       Source directory to backup
#   -d, --destination DIR  Destination directory for backups
#   -t, --type TYPE        Backup type: full or incremental
#   -c, --compression TYPE Compression type: gzip, bzip2, xz, none
#   -r, --retention DAYS   Number of days to keep backups
#   -l, --log FILE         Log file location
#   --schedule CRON        Schedule the backup using a cron expression
#   --list                 List all available backups
#   --restore ID           Restore a specific backup by ID
#   -h, --help             Display help message

# Default configuration
SOURCE_DIR="$(pwd)"  # Changed from $HOME to current directory
BACKUP_DIR="$HOME/backups"
BACKUP_TYPE="full"  # Options: full, incremental
COMPRESSION="gzip"  # Options: gzip, bzip2, xz, none
RETENTION_DAYS=30   # Number of days to keep backups
LOG_FILE="$HOME/backups/backup.log"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
TIMESTAMP=$(date +%s)
INCREMENTAL_MARKER="$BACKUP_DIR/.last_backup_timestamp"

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -s, --source DIR       Source directory to backup (default: $SOURCE_DIR)"
    echo "  -d, --destination DIR  Destination directory for backups (default: $BACKUP_DIR)"
    echo "  -t, --type TYPE        Backup type: full or incremental (default: $BACKUP_TYPE)"
    echo "  -c, --compression TYPE Compression type: gzip, bzip2, xz, none (default: $COMPRESSION)"
    echo "  -r, --retention DAYS   Number of days to keep backups (default: $RETENTION_DAYS)"
    echo "  -l, --log FILE         Log file location (default: $LOG_FILE)"
    echo "  --schedule CRON        Schedule the backup using a cron expression"
    echo "  --list                 List all available backups"
    echo "  --restore ID           Restore a specific backup by ID"
    echo "  -h, --help             Display this help message"
    echo
    echo "Examples:"
    echo "  $0 --source /home/user --destination /mnt/backup --type incremental"
    echo "  $0 --schedule \"0 2 * * *\"  # Schedule backup at 2 AM daily"
    echo "  $0 --list              # List all available backups"
    exit 1
}

# Function to log messages - updated to create log file if it doesn't exist
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Create log directory and file if they don't exist
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    
    # Touch the log file to create it if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check if required tools are installed
check_dependencies() {
    local missing_deps=0
    
    for cmd in tar gzip bzip2 xz find date; do
        if ! command -v "$cmd" &> /dev/null; then
            log_message "Required command '$cmd' not found" "ERROR"
            missing_deps=$((missing_deps + 1))
        fi
    done
    
    if [ $missing_deps -gt 0 ]; then
        log_message "Please install missing dependencies and try again" "ERROR"
        exit 1
    fi
}

# Function to create backup directories if they don't exist
prepare_directories() {
    if [ ! -d "$SOURCE_DIR" ]; then
        log_message "Source directory '$SOURCE_DIR' does not exist" "ERROR"
        exit 1
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "Creating backup directory '$BACKUP_DIR'"
        mkdir -p "$BACKUP_DIR"
        if [ $? -ne 0 ]; then
            log_message "Failed to create backup directory" "ERROR"
            exit 1
        fi
    fi
}

# Function to perform a full backup
perform_full_backup() {
    local backup_file="$BACKUP_DIR/full_backup_${DATE}"
    local file_list="$BACKUP_DIR/full_backup_${DATE}.filelist"
    
    log_message "Starting full backup of '$SOURCE_DIR' to '$backup_file'"
    
    # Create file list for future reference
    find "$SOURCE_DIR" -type f | sort > "$file_list"
    
    # Perform backup with appropriate compression
    case "$COMPRESSION" in
        gzip)
            tar -czf "${backup_file}.tar.gz" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
            compression_result=$?
            backup_file="${backup_file}.tar.gz"
            ;;
        bzip2)
            tar -cjf "${backup_file}.tar.bz2" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
            compression_result=$?
            backup_file="${backup_file}.tar.bz2"
            ;;
        xz)
            tar -cJf "${backup_file}.tar.xz" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
            compression_result=$?
            backup_file="${backup_file}.tar.xz"
            ;;
        none)
            tar -cf "${backup_file}.tar" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
            compression_result=$?
            backup_file="${backup_file}.tar"
            ;;
        *)
            log_message "Unknown compression type: $COMPRESSION" "ERROR"
            exit 1
            ;;
    esac
    
    if [ $compression_result -eq 0 ]; then
        log_message "Full backup completed successfully: $backup_file"
        
        # Store the timestamp for incremental backups
        echo "$TIMESTAMP" > "$INCREMENTAL_MARKER"
        
        # Calculate and log backup size
        local backup_size=$(du -h "$backup_file" | cut -f1)
        log_message "Backup size: $backup_size"
    else
        log_message "Full backup failed with error code $compression_result" "ERROR"
        # Remove incomplete backup file
        rm -f "$backup_file"
        exit 1
    fi
}

# Function to perform an incremental backup
perform_incremental_backup() {
    local last_backup_time=0
    local backup_file="$BACKUP_DIR/incremental_backup_${DATE}"
    local file_list="$BACKUP_DIR/incremental_backup_${DATE}.filelist"
    
    # Check if we have a previous backup timestamp
    if [ -f "$INCREMENTAL_MARKER" ]; then
        last_backup_time=$(cat "$INCREMENTAL_MARKER")
    else
        log_message "No previous backup timestamp found. Performing full backup instead."
        perform_full_backup
        return
    fi
    
    log_message "Starting incremental backup of '$SOURCE_DIR' to '$backup_file'"
    log_message "Including files modified since $(date -d "@$last_backup_time" "+%Y-%m-%d %H:%M:%S")"
    
    # Find files newer than the last backup
    find "$SOURCE_DIR" -type f -newermt "@$last_backup_time" | sort > "$file_list"
    
    # Check if there are any files to backup
    if [ ! -s "$file_list" ]; then
        log_message "No files have been modified since last backup. Skipping."
        return
    fi
    
    # Create temporary directory for incremental backup
    local temp_dir=$(mktemp -d)
    
    # Copy files to temporary directory while preserving directory structure
    while IFS= read -r file; do
        # Calculate relative path
        local rel_path="${file#$SOURCE_DIR/}"
        local target_dir="$temp_dir/$(dirname "$rel_path")"
        
        # Create directory structure
        mkdir -p "$target_dir"
        
        # Copy file
        cp "$file" "$target_dir/"
    done < "$file_list"
    
    # Perform backup with appropriate compression
    case "$COMPRESSION" in
        gzip)
            tar -czf "${backup_file}.tar.gz" -C "$temp_dir" .
            compression_result=$?
            backup_file="${backup_file}.tar.gz"
            ;;
        bzip2)
            tar -cjf "${backup_file}.tar.bz2" -C "$temp_dir" .
            compression_result=$?
            backup_file="${backup_file}.tar.bz2"
            ;;
        xz)
            tar -cJf "${backup_file}.tar.xz" -C "$temp_dir" .
            compression_result=$?
            backup_file="${backup_file}.tar.xz"
            ;;
        none)
            tar -cf "${backup_file}.tar" -C "$temp_dir" .
            compression_result=$?
            backup_file="${backup_file}.tar"
            ;;
        *)
            log_message "Unknown compression type: $COMPRESSION" "ERROR"
            rm -rf "$temp_dir"
            exit 1
            ;;
    esac
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    if [ $compression_result -eq 0 ]; then
        log_message "Incremental backup completed successfully: $backup_file"
        
        # Update the timestamp for next incremental backup
        echo "$TIMESTAMP" > "$INCREMENTAL_MARKER"
        
        # Log number of files and backup size
        local file_count=$(wc -l < "$file_list")
        local backup_size=$(du -h "$backup_file" | cut -f1)
        log_message "Backed up $file_count files. Backup size: $backup_size"
    else
        log_message "Incremental backup failed with error code $compression_result" "ERROR"
        # Remove incomplete backup file
        rm -f "$backup_file"
        exit 1
    fi
}

# Function to schedule backups using cron
schedule_backup() {
    local cron_expression="$1"
    local script_path=$(readlink -f "$0")
    local temp_cron=$(mktemp)
    
    # Export current cron jobs
    crontab -l > "$temp_cron" 2>/dev/null || echo "" > "$temp_cron"
    
    # Check if the backup is already scheduled
    if grep -q "$script_path" "$temp_cron"; then
        log_message "Backup already scheduled. Updating schedule."
        sed -i "\|$script_path|d" "$temp_cron"
    fi
    
    # Add new cron job
    echo "$cron_expression $script_path" >> "$temp_cron"
    
    # Install new cron job
    if crontab "$temp_cron"; then
        log_message "Backup scheduled successfully with cron expression: $cron_expression"
    else
        log_message "Failed to schedule backup" "ERROR"
    fi
    
    # Clean up
    rm -f "$temp_cron"
}

# Function to list available backups
list_backups() {
    local backup_count=0
    
    echo "Available backups:"
    echo "------------------"
    
    # Find all backup files and sort by date
    find "$BACKUP_DIR" -name "*.tar*" | sort | while read -r backup_file; do
        local filename=$(basename "$backup_file")
        local backup_date=$(echo "$filename" | grep -oP '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}')
        local backup_type=$(echo "$filename" | grep -oP '^(full|incremental)')
        local backup_size=$(du -h "$backup_file" | cut -f1)
        
        echo "ID: $backup_date"
        echo "  Type: $backup_type"
        echo "  File: $filename"
        echo "  Size: $backup_size"
        
        # Check if we have a file list
        local file_list="$BACKUP_DIR/${backup_type}_backup_${backup_date}.filelist"
        if [ -f "$file_list" ]; then
            local file_count=$(wc -l < "$file_list")
            echo "  Files: $file_count"
        fi
        
        echo ""
        backup_count=$((backup_count + 1))
    done
    
    if [ $backup_count -eq 0 ]; then
        echo "No backups found in $BACKUP_DIR"
    fi
}

# Function to restore a backup
restore_backup() {
    local backup_id="$1"
    local restore_dir="$SOURCE_DIR.restored_$DATE"
    
    # Find the backup file
    local backup_file=$(find "$BACKUP_DIR" -name "*_${backup_id}.tar*" | head -1)
    
    if [ -z "$backup_file" ]; then
        log_message "No backup found with ID: $backup_id" "ERROR"
        exit 1
    fi
    
    log_message "Restoring backup ID $backup_id to $restore_dir"
    
    # Create restore directory
    mkdir -p "$restore_dir"
    
    # Extract the backup based on compression
    if [[ "$backup_file" == *.tar.gz ]]; then
        tar -xzf "$backup_file" -C "$restore_dir"
    elif [[ "$backup_file" == *.tar.bz2 ]]; then
        tar -xjf "$backup_file" -C "$restore_dir"
    elif [[ "$backup_file" == *.tar.xz ]]; then
        tar -xJf "$backup_file" -C "$restore_dir"
    elif [[ "$backup_file" == *.tar ]]; then
        tar -xf "$backup_file" -C "$restore_dir"
    else
        log_message "Unknown backup format: $backup_file" "ERROR"
        rmdir "$restore_dir"
        exit 1
    fi
    
    if [ $? -eq 0 ]; then
        log_message "Backup restored successfully to $restore_dir"
        echo "Backup has been restored to: $restore_dir"
        echo "Please review the restored files before replacing your originals."
    else
        log_message "Failed to restore backup" "ERROR"
        rmdir "$restore_dir"
        exit 1
    fi
}

# Function to clean up old backups based on retention policy
cleanup_old_backups() {
    if [ "$RETENTION_DAYS" -le 0 ]; then
        log_message "Retention policy disabled, skipping cleanup"
        return
    fi
    
    log_message "Cleaning up backups older than $RETENTION_DAYS days"
    
    local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%s)
    local removed=0
    
    # Find and remove old backup files
    find "$BACKUP_DIR" -name "*.tar*" | while read -r backup_file; do
        local filename=$(basename "$backup_file")
        local backup_date=$(echo "$filename" | grep -oP '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}')
        
        if [ -n "$backup_date" ]; then
            local file_date=$(date -d "${backup_date/_/ }" +%s)
            
            if [ "$file_date" -lt "$cutoff_date" ]; then
                log_message "Removing old backup: $filename"
                rm -f "$backup_file"
                
                # Also remove the file list if it exists
                local file_list="$BACKUP_DIR/$(echo "$filename" | sed 's/\.tar.*$/.filelist/')"
                if [ -f "$file_list" ]; then
                    rm -f "$file_list"
                fi
                
                removed=$((removed + 1))
            fi
        fi
    done
    
    log_message "Removed $removed old backup(s)"
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -d|--destination)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -t|--type)
            BACKUP_TYPE="$2"
            if [[ ! "$BACKUP_TYPE" =~ ^(full|incremental)$ ]]; then
                echo "Error: Backup type must be 'full' or 'incremental'"
                usage
            fi
            shift 2
            ;;
        -c|--compression)
            COMPRESSION="$2"
            if [[ ! "$COMPRESSION" =~ ^(gzip|bzip2|xz|none)$ ]]; then
                echo "Error: Compression must be 'gzip', 'bzip2', 'xz', or 'none'"
                usage
            fi
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        --schedule)
            check_dependencies
            prepare_directories
            schedule_backup "$2"
            exit 0
            ;;
        --list)
            prepare_directories
            list_backups
            exit 0
            ;;
        --restore)
            check_dependencies
            prepare_directories
            restore_backup "$2"
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Main execution
check_dependencies
prepare_directories

# Perform backup based on type
case "$BACKUP_TYPE" in
    full)
        perform_full_backup
        ;;
    incremental)
        perform_incremental_backup
        ;;
    *)
        log_message "Unknown backup type: $BACKUP_TYPE" "ERROR"
        exit 1
        ;;
esac

# Clean up old backups
cleanup_old_backups

exit 0

