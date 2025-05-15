#!/bin/bash
# test_file_sorter.sh - Test suite for the file sorter script
# Author: John Doe (johndoe@example.com)
# 
# Run using: bash test_file_sorter.sh

# Path to the script being tested
SCRIPT_PATH="./file_sorter.sh"

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create temp test directory
TEST_DIR=$(mktemp -d)
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to create temporary test directory${NC}"
    exit 1
fi

# Function to report test results
function report_test {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TESTS_RUN++))
    
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo -e "       ${YELLOW}$message${NC}"
        ((TESTS_FAILED++))
    fi
}

# Ensure we clean up after ourselves
function cleanup {
    echo "Cleaning up test directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
}

# Register cleanup to run on exit
trap cleanup EXIT

# Make the script executable if it isn't
chmod +x "$SCRIPT_PATH"

# ===== Test 1: Script Existence =====
echo -e "\n${BLUE}[TEST]${NC} Checking if the script exists..."
if [ -f "$SCRIPT_PATH" ]; then
    report_test "Script exists" "pass"
else
    report_test "Script exists" "fail" "Script not found at: $SCRIPT_PATH"
    exit 1
fi

# ===== Test 2: Script Permissions =====
echo -e "\n${BLUE}[TEST]${NC} Checking if the script is executable..."
if [ -x "$SCRIPT_PATH" ]; then
    report_test "Script is executable" "pass"
else
    report_test "Script is executable" "fail" "Script is not executable"
    chmod +x "$SCRIPT_PATH"
    echo "  Fixed permissions."
fi

# ===== Test 3: Basic Script Execution =====
echo -e "\n${BLUE}[TEST]${NC} Running script with --help flag..."
output=$("$SCRIPT_PATH" --help 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ] && [[ "$output" == *"Usage"* ]]; then
    report_test "Script runs with --help flag" "pass"
else
    report_test "Script runs with --help flag" "fail" "Exit code: $exit_code, Output: $output"
fi

# ===== Test 4: File Categorization =====
echo -e "\n${BLUE}[TEST]${NC} Testing file categorization..."

# Source the script to get access to the get_category function
# Use a subshell to avoid polluting our environment
test_result=$(
    # Source the script file to get access to functions
    source "$SCRIPT_PATH" 2>/dev/null
    
    # Define test cases as extension:expected_category
    test_cases=(
        "pdf:Documents"
        "jpg:Images"
        "mp4:Videos"
        "mp3:Audio"
        "zip:Archives"
        "py:Code"
        "exe:Executables"
        "unknown:Others"
    )
    
    failures=0
    
    for test_case in "${test_cases[@]}"; do
        ext=$(echo "$test_case" | cut -d: -f1)
        expected=$(echo "$test_case" | cut -d: -f2)
        
        # Call the get_category function from the sourced script
        result=$(get_category "$ext")
        
        if [ "$result" != "$expected" ]; then
            echo "  Extension '$ext' categorized as '$result', expected '$expected'"
            ((failures++))
        fi
    done
    
    # Return the number of failures
    exit $failures
)

exit_code=$?
if [ $exit_code -eq 0 ]; then
    report_test "File categorization" "pass"
else
    report_test "File categorization" "fail" "Some extensions were not correctly categorized ($exit_code failures)"
fi

# ===== Test 5: Directory Organization =====
echo -e "\n${BLUE}[TEST]${NC} Testing directory organization..."

# Create test files
mkdir -p "$TEST_DIR/test_folder"
cd "$TEST_DIR/test_folder" || exit 1

# Create some test files with different extensions
echo "Test document" > document.txt
echo "Test image" > image.jpg
echo "Test video" > video.mp4
echo "Test audio" > audio.mp3
echo "Test archive" > archive.zip
echo "Test code" > code.py
echo "Test executable" > program.exe
echo "Test no extension" > no_extension
mkdir -p "test_dir" # A directory that should be ignored
touch ".hidden_file" # A hidden file that should be ignored

# Make sure we're in the right directory
cd "$TEST_DIR/test_folder" || exit 1

# Run the script without confirmation prompt
"$SCRIPT_PATH" "$TEST_DIR/test_folder" <<< "y" > /dev/null 2>&1
exit_code=$?

# Check results
if [ $exit_code -ne 0 ]; then
    report_test "Directory organization" "fail" "Script exited with non-zero status: $exit_code"
else
    # Check if category folders were created
    expected_folders=("Documents" "Images" "Videos" "Audio" "Archives" "Code" "Executables" "Others")
    
    folder_errors=""
    for folder in "${expected_folders[@]}"; do
        if [ ! -d "$TEST_DIR/test_folder/$folder" ]; then
            folder_errors="$folder_errors $folder"
        fi
    done
    
    if [ -z "$folder_errors" ]; then
        # Check if files were moved to correct folders
        file_errors=""
        
        test_cases=(
            "Documents/document.txt"
            "Images/image.jpg"
            "Videos/video.mp4"
            "Audio/audio.mp3"
            "Archives/archive.zip"
            "Code/code.py"
            "Executables/program.exe"
            "Others/no_extension"
        )
        
        for test_case in "${test_cases[@]}"; do
            if [ ! -f "$TEST_DIR/test_folder/$test_case" ]; then
                file_errors="$file_errors $test_case"
            fi
        done
        
        # Check special cases
        # Hidden file should remain in place
        if [ ! -f "$TEST_DIR/test_folder/.hidden_file" ]; then
            file_errors="$file_errors .hidden_file"
        fi
        
        # Directory should remain in place
        if [ ! -d "$TEST_DIR/test_folder/test_dir" ]; then
            file_errors="$file_errors test_dir"
        fi
        
        if [ -z "$file_errors" ]; then
            report_test "Directory organization" "pass"
        else
            report_test "Directory organization" "fail" "Files not found: $file_errors"
        fi
    else
        report_test "Directory organization" "fail" "Folders not created: $folder_errors"
    fi
fi

# ===== Test 6: Duplicate Handling =====
echo -e "\n${BLUE}[TEST]${NC} Testing duplicate file handling..."

# Create a duplicate scenario in a new directory
mkdir -p "$TEST_DIR/dupe_test/Documents"
echo "Original document" > "$TEST_DIR/dupe_test/Documents/duplicate.txt"
echo "Duplicate document" > "$TEST_DIR/dupe_test/duplicate.txt"

# Run the script (redirect stdin to provide 'y' to the prompt)
"$SCRIPT_PATH" "$TEST_DIR/dupe_test" <<< "y" > /dev/null 2>&1

# Check if the duplicate was handled - look for timestamp in filename
dupe_files=$(find "$TEST_DIR/dupe_test/Documents" -name "duplicate*.txt" | wc -l)
if [ "$dupe_files" -gt 1 ]; then
    report_test "Duplicate file handling" "pass"
else
    report_test "Duplicate file handling" "fail" "Duplicate file was not properly renamed"
    echo "Files in Documents directory:"
    find "$TEST_DIR/dupe_test/Documents" -type f -ls
fi

# ===== Test 7: Error Handling - Invalid Directory =====
echo -e "\n${BLUE}[TEST]${NC} Testing error handling with invalid directory..."

# Run the script with a non-existent directory
"$SCRIPT_PATH" "/this/directory/does/not/exist" > /dev/null 2>&1
exit_code=$?

if [ $exit_code -ne 0 ]; then
    report_test "Error handling - Invalid directory" "pass" 
else
    report_test "Error handling - Invalid directory" "fail" "Script should have returned non-zero exit code for invalid directory"
fi

# Print summary
echo ""
echo "======================================================"
echo " TEST SUMMARY"
echo "======================================================"
echo " Total tests: $TESTS_RUN"
echo " Passed: $TESTS_PASSED"
echo " Failed: $TESTS_FAILED"
echo "======================================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. See above for details.${NC}"
    exit 1
fi
