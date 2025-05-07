#!/bin/bash

# IAM Setup Script
# This script automates the creation of users and groups from a CSV or TXT file
# It also includes email notifications and password complexity checks

# Global variables
LOG_FILE="iam_setup.log"
DEFAULT_PASSWORD="Ch@ngeMe123"
MIN_PASSWORD_LENGTH=8
REQUIRE_SPECIAL_CHARS=true
REQUIRE_NUMBERS=true
REQUIRE_MIXED_CASE=true

# Function to log messages
log_message() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR: This script must be run as root"
        exit 1
    fi
}

# Function to display usage
show_usage() {
    echo "Usage: $0 <input_file> [options]"
    echo ""
    echo "Options:"
    echo "  --cleanup   Remove all users and groups created by this script"
    echo ""
    echo "The input file should be a CSV or TXT file with the format:"
    echo "username,fullname,group[,email]"
    echo ""
    echo "Example:"
    echo "  $0 users.csv"
    echo "  $0 users.txt --cleanup"
    exit 1
}

# Function to validate input file
validate_input_file() {
    local input_file="$1"
    
    # Check if file exists
    if [ ! -f "$input_file" ]; then
        log_message "ERROR: Input file '$input_file' does not exist"
        show_usage
    fi
    
    # Check if file is readable
    if [ ! -r "$input_file" ]; then
        log_message "ERROR: Input file '$input_file' is not readable"
        exit 1
    fi
    
    # Check file extension
    local file_ext="${input_file##*.}"
    if [ "$file_ext" != "csv" ] && [ "$file_ext" != "txt" ]; then
        log_message "WARNING: Input file should have .csv or .txt extension"
    fi
    
    log_message "Input file '$input_file' validated successfully"
}

# Function to check password complexity
check_password_complexity() {
    local password="$1"
    local is_complex=true
    local error_msg=""
    
    # Check minimum length
    if [ ${#password} -lt $MIN_PASSWORD_LENGTH ]; then
        is_complex=false
        error_msg="Password must be at least $MIN_PASSWORD_LENGTH characters long"
    fi
    
    # Check for special characters
    if [ "$REQUIRE_SPECIAL_CHARS" = true ] && ! echo "$password" | grep -q '[!@#$%^&*()_+{}|:"<>?~`-]'; then
        is_complex=false
        error_msg="$error_msg, must contain special characters"
    fi
    
    # Check for numbers
    if [ "$REQUIRE_NUMBERS" = true ] && ! echo "$password" | grep -q '[0-9]'; then
        is_complex=false
        error_msg="$error_msg, must contain numbers"
    fi
    
    # Check for mixed case
    if [ "$REQUIRE_MIXED_CASE" = true ] && ! echo "$password" | grep -q '[a-z]' && ! echo "$password" | grep -q '[A-Z]'; then
        is_complex=false
        error_msg="$error_msg, must contain both uppercase and lowercase letters"
    fi
    
    if [ "$is_complex" = false ]; then
        log_message "ERROR: Password complexity check failed - $error_msg"
        return 1
    fi
    
    return 0
}

# Function to create groups
create_group() {
    local group_name="$1"
    
    # Check if group already exists
    if getent group "$group_name" >/dev/null; then
        log_message "Group '$group_name' already exists"
        return 0
    fi
    
    # Create group
    if groupadd "$group_name"; then
        log_message "Created group '$group_name'"
        return 0
    else
        log_message "ERROR: Failed to create group '$group_name'"
        return 1
    fi
}

# Function to create users
create_user() {
    local username="$1"
    local fullname="$2"
    local group="$3"
    local email="$4"
    
    # Check if user already exists
    if id "$username" >/dev/null 2>&1; then
        log_message "User '$username' already exists"
        return 0
    fi
    
    # Create the user
    if useradd -m -c "$fullname" -g "$group" "$username"; then
        log_message "Created user '$username' ($fullname) in group '$group'"
        
        # Set password
        echo "$username:$DEFAULT_PASSWORD" | chpasswd
        log_message "Set temporary password for '$username'"
        
        # Force password change on first login
        chage -d 0 "$username"
        log_message "Set password expiry for '$username' (will be forced to change on first login)"
        
        # Set permissions on home directory
        chmod 700 "/home/$username"
        log_message "Set permissions on '/home/$username' to 700"
        
        # Send email notification if email is provided
        if [ -n "$email" ]; then
            send_email_notification "$username" "$fullname" "$email"
        fi
        
        return 0
    else
        log_message "ERROR: Failed to create user '$username'"
        return 1
    fi
}

# Function to send email notification
send_email_notification() {
    local username="$1"
    local fullname="$2"
    local email="$3"

    # Check if Mailjet environment variables are set
    if [ -z "$MAILJET_API_KEY" ] || [ -z "$MAILJET_SECRET_KEY" ]; then
        log_message "WARNING: Mailjet API keys not set, skipping email notification for '$username'"
        return 1
    fi
    
    log_message "Sending email notification to '$email' for user '$username'"
    
    # Prepare email content
    local subject="Your new account has been created"
    local body="Dear $fullname,\n\nYour account has been created with the following details:\n\nUsername: $username\nTemporary Password: $DEFAULT_PASSWORD\n\nPlease log in and change your password immediately.\n\nThank you,\nSystem Administrator"
    
    # Send email using Mailjet API
    curl -s \
      -X POST \
      --user "$MAILJET_API_KEY:$MAILJET_SECRET_KEY" \
      https://api.mailjet.com/v3.1/send \
      -H 'Content-Type: application/json' \
      -d '{
        "Messages":[
          {
            "From": {
              "Email": "clement.mugisha@amalitechtraining.org",
              "Name": "System Administrator"
            },
            "To": [
              {
                "Email": "'"$email"'",
                "Name": "'"$fullname"'"
              }
            ],
            "Subject": "'"$subject"'",
            "TextPart": "'"$body"'"
          }
        ]
      }' > /dev/null
    
    if [ $? -eq 0 ]; then
        log_message "Email notification sent to '$email' for user '$username'"
        return 0
    else
        log_message "ERROR: Failed to send email notification to '$email' for user '$username'"
        return 1
    fi
}

# Function to process input file
process_input_file() {
    local input_file="$1"
    local created_users=()
    local created_groups=()
    
    # Read the file line by line
    while IFS=',' read -r username fullname group email || [[ -n "$username" ]]; do
        # Skip empty lines and comments
        if [ -z "$username" ] || [[ "$username" =~ ^# ]]; then
            continue
        fi
        
        # Create group if it doesn't exist
        if create_group "$group"; then
            if ! echo "${created_groups[@]}" | grep -qw "$group"; then
                created_groups+=("$group")
            fi
        fi
        
        # Create user
        if create_user "$username" "$fullname" "$group" "$email"; then
            created_users+=("$username")
        fi
    done < "$input_file"
    
    # Save created users and groups to file for cleanup
    echo "# Created by iam_setup.sh on $(date)" > .iam_setup_created
    echo "# Users" >> .iam_setup_created
    for user in "${created_users[@]}"; do
        echo "USER:$user" >> .iam_setup_created
    done
    echo "# Groups" >> .iam_setup_created
    for group in "${created_groups[@]}"; do
        echo "GROUP:$group" >> .iam_setup_created
    done
    
    log_message "Created $(echo ${#created_users[@]}) users and $(echo ${#created_groups[@]}) groups"
}

# Function to clean up created users and groups
cleanup() {
    if [ ! -f ".iam_setup_created" ]; then
        log_message "ERROR: Cleanup file '.iam_setup_created' not found"
        exit 1
    fi
    
    log_message "Starting cleanup..."
    local removed_users=0
    local removed_groups=0
    
    # Read the cleanup file line by line
    while read -r line; do
        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        # Parse line
        local type="${line%%:*}"
        local name="${line#*:}"
        
        # Remove users
        if [ "$type" = "USER" ]; then
            if id "$name" >/dev/null 2>&1; then
                userdel -r "$name" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "Removed user '$name'"
                    removed_users=$((removed_users + 1))
                else
                    log_message "ERROR: Failed to remove user '$name'"
                fi
            else
                log_message "User '$name' does not exist"
            fi
        fi
        
        # Remove groups
        if [ "$type" = "GROUP" ]; then
            if getent group "$name" >/dev/null; then
                groupdel "$name" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "Removed group '$name'"
                    removed_groups=$((removed_groups + 1))
                else
                    log_message "ERROR: Failed to remove group '$name'"
                fi
            else
                log_message "Group '$name' does not exist"
            fi
        fi
    done < ".iam_setup_created"
    
    log_message "Cleanup complete: removed $removed_users users and $removed_groups groups"
    
    # Remove cleanup file
    rm -f ".iam_setup_created"
}

# Main function
main() {
    # Initialize log file
    echo "# IAM Setup Log - $(date)" > "$LOG_FILE"
    log_message "Starting IAM setup script"
    
    # Check if running as root
    check_root
    
    # Check password complexity
    check_password_complexity "$DEFAULT_PASSWORD"
    if [ $? -ne 0 ]; then
        log_message "ERROR: Default password does not meet complexity requirements"
        exit 1
    fi
    
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        log_message "ERROR: No input file specified"
        show_usage
    fi
    
    local input_file="$1"
    local do_cleanup=false
    
    # Check for cleanup option
    if [ "$2" = "--cleanup" ]; then
        do_cleanup=true
    fi
    
    if [ "$do_cleanup" = true ]; then
        cleanup
        exit 0
    fi
    
    # Validate input file
    validate_input_file "$input_file"
    
    # Process input file
    process_input_file "$input_file"
    
    log_message "IAM setup script completed successfully"
}

# Run the main function
main "$@"
