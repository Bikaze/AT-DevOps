#!/bin/bash
# duplicate_finder.sh - Finds and manages duplicate files in a directory
# Author: Clement MUGISHA
# Last modified: 15th May 2025
# Version: 1.0.0
#
# Usage: ./duplicate_finder.sh [directory]
# If no directory is specified, uses the current directory
#
# This script finds duplicate files by comparing file sizes and MD5 hashes,
# then offers options to delete or move them to another location.

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage information
function show_usage() {
    echo -e "${BLUE}Duplicate File Finder${NC}"
    echo "Usage: $0 [directory]"
    echo "If no directory is specified, the current directory will be used."
    echo
    echo "This script finds duplicate files in the specified directory"
    echo "and offers options to delete or move them."
    exit 1
}

# Check if md5sum is installed
if ! command -v md5sum &> /dev/null; then
    echo -e "${RED}Error: md5sum command is required but not found.${NC}"
    echo "Please install it first. On Debian/Ubuntu run: sudo apt-get install coreutils"
    exit 1
fi

# Process command line arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
fi

# Set directory
if [[ -n "$1" ]]; then
    if [[ ! -d "$1" ]]; then
        echo -e "${RED}Error: '$1' is not a valid directory.${NC}"
        exit 1
    fi
    directory="$1"
else
    directory="."
fi

# Resolve to absolute path
directory=$(cd "$directory" && pwd)

echo -e "${GREEN}Scanning for duplicate files in:${NC} $directory"
echo -e "${YELLOW}Please wait, this may take some time depending on the number of files...${NC}"

# Create temporary files
temp_dir=$(mktemp -d)
size_file="$temp_dir/sizes.txt"
duplicate_file="$temp_dir/duplicates.txt"

# Make sure temp files are deleted on exit
trap "rm -rf $temp_dir" EXIT

# Step 1: Get all files with their sizes
find "$directory" -type f -exec ls -la {} \; | awk '{print $5" "$9}' | sort -n > "$size_file"

# Step 2: Find files with the same size
echo -e "${BLUE}Finding potential duplicates by size...${NC}"
previous_size=""
previous_file=""
declare -A size_groups
group_count=0

while IFS=" " read -r size file; do
    if [[ "$size" == "$previous_size" ]]; then
        if [[ -z "${size_groups[$size]}" ]]; then
            group_count=$((group_count + 1))
            size_groups[$size]=$group_count
            echo "$previous_file" >> "$temp_dir/group_${group_count}.txt"
        fi
        echo "$file" >> "$temp_dir/group_${size_groups[$size]}.txt"
    fi
    previous_size="$size"
    previous_file="$file"
done < "$size_file"

# Step 3: For each size group, calculate md5 hashes
echo -e "${BLUE}Calculating file hashes to confirm duplicates...${NC}"
duplicate_count=0
declare -A hash_groups

for group_file in "$temp_dir"/group_*.txt; do
    while IFS= read -r file; do
        hash=$(md5sum "$file" | cut -d' ' -f1)
        
        # Append to hash group
        if [[ -z "${hash_groups[$hash]}" ]]; then
            hash_groups[$hash]="$file"
        else
            hash_groups[$hash]="${hash_groups[$hash]}|$file"
            duplicate_count=$((duplicate_count + 1))
        fi
    done < "$group_file"
done

# Check if any duplicates were found
if [[ $duplicate_count -eq 0 ]]; then
    echo -e "${GREEN}No duplicate files found.${NC}"
    exit 0
fi

# Step 4: Display duplicates and offer options
echo -e "${GREEN}Found potential duplicates! Grouping by hash...${NC}"

# Sort hash groups by original files first
for hash in "${!hash_groups[@]}"; do
    IFS='|' read -ra files <<< "${hash_groups[$hash]}"
    
    # Only process actual duplicates (more than one file with same hash)
    if [[ ${#files[@]} -gt 1 ]]; then
        echo -e "\n${YELLOW}Duplicate Group (MD5: ${hash:0:8}...)${NC}"
        
        # Display files with numbers
        for i in "${!files[@]}"; do
            file="${files[$i]}"
            file_size=$(du -h "$file" | cut -f1)
            echo -e "$((i+1)). ${BLUE}$file${NC} (${file_size})"
        done
        
        # Ask what to do with this group
        echo -e "\n${YELLOW}What would you like to do with these duplicates?${NC}"
        echo "1. Keep all files (skip)"
        echo "2. Delete specific duplicates"
        echo "3. Move specific duplicates to another location"
        echo "4. Automatically keep first file and delete the rest"
        echo "5. Skip all remaining duplicates"
        echo "q. Quit"
        
        read -p "Enter your choice: " choice
        
        case $choice in
            1)
                echo -e "${GREEN}Keeping all files in this group.${NC}"
                ;;
            2)
                read -p "Enter numbers of files to DELETE (space-separated): " delete_nums
                for num in $delete_nums; do
                    if [[ $num -le ${#files[@]} && $num -gt 0 ]]; then
                        idx=$((num-1))
                        rm -f "${files[$idx]}"
                        echo -e "${RED}Deleted:${NC} ${files[$idx]}"
                    fi
                done
                ;;
            3)
                read -p "Enter directory to move files to: " target_dir
                if [[ ! -d "$target_dir" ]]; then
                    read -p "Directory doesn't exist. Create it? (y/n): " create_dir
                    if [[ "$create_dir" == "y" ]]; then
                        mkdir -p "$target_dir"
                    else
                        echo "Skipping move operation."
                        continue
                    fi
                fi
                
                read -p "Enter numbers of files to MOVE (space-separated): " move_nums
                for num in $move_nums; do
                    if [[ $num -le ${#files[@]} && $num -gt 0 ]]; then
                        idx=$((num-1))
                        filename=$(basename "${files[$idx]}")
                        mv "${files[$idx]}" "$target_dir/$filename"
                        echo -e "${GREEN}Moved to $target_dir:${NC} ${files[$idx]}"
                    fi
                done
                ;;
            4)
                # Keep first file, delete the rest
                for i in $(seq 1 $((${#files[@]}-1))); do
                    rm -f "${files[$i]}"
                    echo -e "${RED}Deleted:${NC} ${files[$i]}"
                done
                echo -e "${GREEN}Kept:${NC} ${files[0]}"
                ;;
            5)
                echo -e "${YELLOW}Skipping all remaining duplicates.${NC}"
                exit 0
                ;;
            q|Q)
                echo -e "${YELLOW}Exiting duplicate file finder.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Skipping this group.${NC}"
                ;;
        esac
    fi
done

echo -e "\n${GREEN}Duplicate file processing complete.${NC}"
exit 0