#!/bin/bash
# file_sorter.sh - Organizes files in a directory based on their types
# Author: John Doe (johndoe@example.com)
# Last modified: 05/12/2025
# Version: 1.2.3
#
# Usage: ./file_sorter.sh [directory]
# If no directory is specified, uses the current directory

# Some vars we'll need
SORTED_COUNT=0
SKIPPED_COUNT=0
ERRORS=0

# Colors for output - makes it easier to read
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print usage info
function show_usage {
    echo "Usage: $0 [directory]"
    echo "If no directory is specified, the current directory will be used."
}

# Print a fancy header
function print_header {
    echo "======================================================"
    echo "                   FILE SORTER 1.2.3                  "
    echo "======================================================"
    echo "Organizing files in: $TARGET_DIR"
    echo "------------------------------------------------------"
}

# For logging messages with colors
function log_info {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function log_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function log_error {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

# Determine category based on file extension
function get_category {
    local file_ext=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    
    # Remove leading dot if present
    file_ext="${file_ext#.}"
    
    case "$file_ext" in
        # Documents
        pdf|doc|docx|txt|rtf|odt|xls|xlsx|ppt|pptx|csv)
            echo "Documents"
            ;;
        # Images
        jpg|jpeg|png|gif|bmp|svg|tiff|ico|raw)
            echo "Images"
            ;;
        # Videos
        mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg)
            echo "Videos"
            ;;
        # Audio
        mp3|wav|flac|aac|ogg|m4a|wma)
            echo "Audio"
            ;;
        # Archives
        zip|rar|tar|gz|7z|bz2|xz|iso)
            echo "Archives"
            ;;
        # Code
        py|java|js|html|css|c|cpp|h|sh|php|rb|json|xml|yaml|sql)
            echo "Code"
            ;;
        # Executables
        exe|msi|apk|app|deb|rpm)
            echo "Executables"
            ;;
        # Default
        *)
            echo "Others"
            ;;
    esac
}

# Main function to organize files
function organize_files {
    local dir="$1"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi
    
    # Get all files in the directory (non-recursive)
    # Using find with -print0 and read -d to handle files with spaces
    find "$dir" -maxdepth 1 -type f -not -path "*/\.*" -print0 | while IFS= read -r -d '' file; do
        # Get just the filename
        filename=$(basename "$file")
        
        # Skip this script itself
        if [ "$filename" = "$(basename "$0")" ]; then
            continue
        fi
        
        # Get file extension
        extension="${filename##*.}"
        if [ "$extension" = "$filename" ]; then
            extension=""
        fi
        
        # Determine category
        if [ -z "$extension" ]; then
            category="Others"
        else
            category=$(get_category "$extension")
        fi
        
        # Create category folder if it doesn't exist
        category_path="$dir/$category"
        if [ ! -d "$category_path" ]; then
            mkdir -p "$category_path"
            if [ $? -ne 0 ]; then
                log_error "Failed to create directory: $category_path"
                continue
            fi
            log_info "Created directory: $category"
        fi
        
        # Handle duplicate filenames
        dest_file="$category_path/$filename"
        if [ -f "$dest_file" ]; then
            # Add timestamp to filename
            timestamp=$(date +"%Y%m%d_%H%M%S")
            name_part="${filename%.*}"
            ext_part="${filename##*.}"
            
            if [ "$ext_part" = "$filename" ]; then
                # No extension
                new_filename="${name_part}_${timestamp}"
            else
                new_filename="${name_part}_${timestamp}.${ext_part}"
            fi
            
            dest_file="$category_path/$new_filename"
            log_warning "File already exists, renaming to: $new_filename"
        fi
        
        # Move the file
        mv "$file" "$dest_file"
        if [ $? -eq 0 ]; then
            log_success "Moved: $filename → $category/"
            SORTED_COUNT=$((SORTED_COUNT+1))
        else
            log_error "Failed to move: $filename"
        fi
    done
    
    return 0
}

# Main script execution starts here

# Check if being sourced (for testing)
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Determine target directory
if [ -z "$1" ]; then
    TARGET_DIR="."
    echo -n "No directory specified. Organize files in current directory? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
else
    TARGET_DIR="$1"
fi

# Convert to absolute path
TARGET_DIR=$(realpath "$TARGET_DIR")

# Show what we're doing
print_header

# Do the organizing
organize_files "$TARGET_DIR"
exit_code=$?

# Print summary
echo ""
echo "======================================================"
echo " SUMMARY"
echo "======================================================"
echo " Files organized: $SORTED_COUNT"
echo " Files skipped: $SKIPPED_COUNT"
echo " Errors encountered: $ERRORS"
echo "======================================================"

if [ $exit_code -eq 0 ] && [ $ERRORS -eq 0 ]; then
    log_success "All files organized successfully!"
    exit 0
else
    log_error "Completed with errors. Check the output above."
    exit 1
fi

# TODO: Add an undo feature
# TODO: Add an option to simulate without moving files
# TODO: Add logging to file