#!/bin/bash
# bulk_renamer.sh - A tool to rename multiple files using patterns, prefixes, suffixes, counters, and dates
# Author: Clement MUGISHA
# Last modified: 15th May 2025
# Version: 1.0.0
#
# Usage: ./bulk_renamer.sh [options] [files...]
# If no files are specified, shows the help message.

# Bulk File Renamer
# A tool to rename multiple files using patterns, prefixes, suffixes, counters, and dates.

# Display help message
show_help() {
    echo "Bulk File Renamer - Rename multiple files using patterns"
    echo ""
    echo "Usage: $0 [options] [files...]"
    echo ""
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -p, --prefix STRING        Add prefix to filename"
    echo "  -s, --suffix STRING        Add suffix to filename (before extension)"
    echo "  -e, --extension EXT        Change file extension"
    echo "  -r, --replace OLD NEW      Replace OLD with NEW in filename"
    echo "  -l, --lowercase            Convert filename to lowercase"
    echo "  -u, --uppercase            Convert filename to uppercase"
    echo "  -c, --counter START        Add counter starting from START"
    echo "  -w, --width WIDTH          Width of counter (zero padded)"
    echo "  -d, --date FORMAT          Add date with specified format (uses 'date' syntax)"
    echo "  -n, --dry-run              Show what would be done without making changes"
    echo "  -f, --force                Force rename even if target files exist"
    echo ""
    echo "Examples:"
    echo "  $0 -p \"holiday_\" -c 1 -w 3 *.jpg"
    echo "  $0 -r \"DSC\" \"photo\" -d \"%Y%m%d\" *.jpg"
    echo "  $0 -l -s \"_edited\" *.JPG"
    echo ""
}

# Parse command line arguments
PREFIX=""
SUFFIX=""
EXTENSION=""
REPLACE_OLD=""
REPLACE_NEW=""
LOWERCASE=false
UPPERCASE=false
USE_COUNTER=false
COUNTER_START=0
COUNTER_WIDTH=1
DATE_FORMAT=""
DRY_RUN=false
FORCE=false

# No parameters provided
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -s|--suffix)
            SUFFIX="$2"
            shift 2
            ;;
        -e|--extension)
            EXTENSION="$2"
            shift 2
            ;;
        -r|--replace)
            REPLACE_OLD="$2"
            REPLACE_NEW="$3"
            shift 3
            ;;
        -l|--lowercase)
            LOWERCASE=true
            shift
            ;;
        -u|--uppercase)
            UPPERCASE=true
            shift
            ;;
        -c|--counter)
            USE_COUNTER=true  # Set the flag when counter is requested
            COUNTER_START=$2
            shift 2
            ;;
        -w|--width)
            COUNTER_WIDTH=$2
            shift 2
            ;;
        -d|--date)
            DATE_FORMAT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            # Break from the loop when we reach the first non-option argument
            break
            ;;
    esac
done

# Check if at least one file is provided
if [ $# -eq 0 ]; then
    echo "Error: No files specified."
    show_help
    exit 1
fi

# Counter for renamed files and errors
renamed=0
errors=0
counter=$COUNTER_START

# Process each file
for file in "$@"; do
    # Skip if file doesn't exist
    if [ ! -f "$file" ]; then
        echo "Warning: $file does not exist, skipping."
        continue
    fi
    
    # Get filename and extension
    filename=$(basename -- "$file")
    dir=$(dirname -- "$file")
    extension="${filename##*.}"
    filename_noext="${filename%.*}"
    
    # Apply transformations
    new_filename="$filename_noext"
    
    # Replace pattern if specified
    if [ -n "$REPLACE_OLD" ]; then
        new_filename="${new_filename//$REPLACE_OLD/$REPLACE_NEW}"
    fi
    
    # Convert to lowercase if requested
    if [ "$LOWERCASE" = true ]; then
        new_filename=$(echo "$new_filename" | tr '[:upper:]' '[:lower:]')
    fi
    
    # Convert to uppercase if requested
    if [ "$UPPERCASE" = true ]; then
        new_filename=$(echo "$new_filename" | tr '[:lower:]' '[:upper:]')
    fi
    
    # Add counter if requested
    if [ "$USE_COUNTER" = true ]; then
        counter_formatted=$(printf "%0${COUNTER_WIDTH}d" $counter)
        new_filename="${new_filename}${counter_formatted}"
        ((counter++))
    fi
    
    # Add date if requested
    if [ -n "$DATE_FORMAT" ]; then
        date_str=$(date +"$DATE_FORMAT")
        new_filename="${new_filename}${date_str}"
    fi
    
    # Add prefix and suffix
    new_filename="${PREFIX}${new_filename}${SUFFIX}"
    
    if [ -n "$EXTENSION" ]; then
        new_ext="$EXTENSION"
    else
        # Only use the extension if the original file had one
        if [ "$extension" != "$filename" ]; then
            new_ext="$extension"
        else
            new_ext=""
        fi
    fi
    
    # Construct the final new filename with path
    new_file="${dir}/${new_filename}"
    
    # Only add the extension if it's not empty
    if [ -n "$new_ext" ]; then
        new_file="${new_file}.${new_ext}"
    fi
    
    # Check if target file already exists
    if [ -f "$new_file" ] && [ "$new_file" != "$file" ] && [ "$FORCE" = false ]; then
        echo "Error: Target file $new_file already exists. Use -f to force overwrite."
        ((errors++))
        continue
    fi
    
    # Perform the rename or show what would be done
    if [ "$DRY_RUN" = true ]; then
        echo "Would rename: $file -> $new_file"
    else
        if [ "$file" != "$new_file" ]; then
            mv "$file" "$new_file"
            if [ $? -eq 0 ]; then
                echo "Renamed: $file -> $new_file"
                ((renamed++))
            else
                echo "Error renaming $file"
                ((errors++))
            fi
        else
            echo "Skipped: $file (new name is the same)"
        fi
    fi
done

# Show summary
if [ "$DRY_RUN" = true ]; then
    echo "Dry run completed. Would rename $renamed file(s)."
else
    echo "Completed. Renamed $renamed file(s). Errors: $errors."
fi