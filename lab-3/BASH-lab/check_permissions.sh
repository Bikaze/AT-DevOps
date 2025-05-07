#!/bin/bash

# Permission Checker Script
# This script provides a comprehensive overview of users, groups, and permissions on the system
# Requires sudo/root privileges to run

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Global variables
OUTPUT_FILE="permissions_report.txt"
DETAILED=false
SPECIFIC_USER=""
SPECIFIC_GROUP=""

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${BOLD}ERROR: This script must be run as root${RESET}"
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
}

# Function to display usage
show_usage() {
    echo -e "${BOLD}Usage:${RESET} $0 [options]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  -h, --help         Show this help message"
    echo "  -d, --detailed     Show detailed information"
    echo "  -u, --user USER    Show information for specific user"
    echo "  -g, --group GROUP  Show information for specific group"
    echo "  -o, --output FILE  Save output to specified file (default: permissions_report.txt)"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $0"
    echo "  $0 --detailed"
    echo "  $0 --user jdoe"
    echo "  $0 --group engineering"
    echo "  $0 --output my_report.txt"
    exit 1
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                ;;
            -d|--detailed)
                DETAILED=true
                shift
                ;;
            -u|--user)
                SPECIFIC_USER="$2"
                shift 2
                ;;
            -g|--group)
                SPECIFIC_GROUP="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}${BOLD}ERROR: Unknown option: $1${RESET}"
                show_usage
                ;;
        esac
    done
}

# Function to print section header
print_header() {
    local title="$1"
    local length=${#title}
    local line=$(printf '%*s' "$length" | tr ' ' '=')
    
    echo -e "\n${BOLD}${BLUE}$title${RESET}"
    echo -e "${BLUE}$line${RESET}\n"
}

# Function to check and print system information
check_system_info() {
    print_header "SYSTEM INFORMATION"
    
    echo -e "${BOLD}Hostname:${RESET}        $(hostname)"
    echo -e "${BOLD}Kernel:${RESET}          $(uname -r)"
    echo -e "${BOLD}OS:${RESET}              $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo -e "${BOLD}Last Boot:${RESET}       $(who -b | awk '{print $3" "$4}')"
}

# Function to check and print user information
check_users() {
    if [ -n "$SPECIFIC_USER" ]; then
        if ! id "$SPECIFIC_USER" &>/dev/null; then
            echo -e "${RED}${BOLD}ERROR: User '$SPECIFIC_USER' does not exist${RESET}"
            exit 1
        fi
        print_header "USER INFORMATION: $SPECIFIC_USER"
        check_specific_user "$SPECIFIC_USER"
    else
        print_header "USER INFORMATION"
        echo -e "${BOLD}Total users:${RESET} $(getent passwd | wc -l)"
        
        echo -e "\n${BOLD}${CYAN}Users with UID 0 (root access):${RESET}"
        getent passwd | awk -F: '$3 == 0 {print $1}' | while read -r user; do
            echo -e "  - ${YELLOW}$user${RESET}"
        done
        
        echo -e "\n${BOLD}${CYAN}Users with login shell:${RESET}"
        getent passwd | grep -v '/nologin$\|/false$' | awk -F: '{print "  - " $1 " (Shell: " $7 ")"}' | sort
        
        echo -e "\n${BOLD}${CYAN}Recently created users (last 30 days):${RESET}"
        cut -d: -f1,3 /etc/passwd | while IFS=: read -r user uid; do
            if [ "$uid" -ge 1000 ] && [ "$uid" -ne 65534 ]; then
                creation=$(stat -c %y /home/$user 2>/dev/null | cut -d' ' -f1)
                if [ -n "$creation" ]; then
                    days_since=$(( ( $(date +%s) - $(date -d "$creation" +%s) ) / 86400 ))
                    if [ "$days_since" -le 30 ]; then
                        echo -e "  - $user (Created: $creation)"
                    fi
                fi
            fi
        done
        
        if [ "$DETAILED" = true ]; then
            echo -e "\n${BOLD}${CYAN}Sudo users:${RESET}"
            grep -v '^#' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -E '^[^#%]' | while read -r line; do
                echo -e "  - $line"
            done
            
            getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' | while read -r user; do
                if id -nG "$user" | grep -qw "sudo\|wheel\|admin"; then
                    echo -e "  - $user (via group membership)"
                fi
            done
        fi
    fi  
}

# Function to check and print specific user information
check_specific_user() {
    local user="$1"
    local uid=$(id -u "$user")
    local gid=$(id -g "$user")
    local primary_group=$(getent group "$gid" | cut -d: -f1)
    local shell=$(getent passwd "$user" | cut -d: -f7)
    local homedir=$(eval echo ~$user)
    local last_login=$(last -1 "$user" 2>/dev/null | head -1 | awk '{print $4, $5, $6, $7}')
    local password_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
    local password_expires=$(chage -l "$user" | grep 'Password expires' | cut -d: -f2- | xargs)
    
    echo -e "${BOLD}Username:${RESET}        $user"
    echo -e "${BOLD}UID:${RESET}             $uid"
    echo -e "${BOLD}Primary Group:${RESET}   $primary_group ($gid)"
    echo -e "${BOLD}Secondary Groups:${RESET}"
    
    id -Gn "$user" | tr ' ' '\n' | while read -r group; do
        if [ "$group" != "$primary_group" ]; then
            echo -e "  - $group"
        fi
    done
    
    echo -e "${BOLD}Home Directory:${RESET}  $homedir"
    echo -e "${BOLD}Shell:${RESET}           $shell"
    
    if [ -n "$last_login" ]; then
        echo -e "${BOLD}Last Login:${RESET}      $last_login"
    else
        echo -e "${BOLD}Last Login:${RESET}      Never"
    fi
    
    echo -e "${BOLD}Password Status:${RESET} $password_status"
    echo -e "${BOLD}Password Expires:${RESET} $password_expires"
    
    echo -e "\n${BOLD}${CYAN}Home Directory Permissions:${RESET}"
    if [ -d "$homedir" ]; then
        ls -ld "$homedir" | awk '{print "  " $1 " (Owner: " $3 ", Group: " $4 ")"}'
        
        local home_perms=$(stat -c '%a' "$homedir")
        if [ "$home_perms" != "700" ] && [ "$home_perms" != "750" ]; then
            echo -e "  ${RED}WARNING: Home directory has potentially insecure permissions ($home_perms)${RESET}"
        fi
    else
        echo -e "  ${RED}WARNING: Home directory does not exist${RESET}"
    fi
    
    echo -e "\n${BOLD}${CYAN}Sudo Access:${RESET}"
    if sudo -l -U "$user" 2>/dev/null | grep -q 'not allowed'; then
        echo -e "  No sudo access"
    else
        sudo -l -U "$user" 2>/dev/null | grep -v 'not allowed' | sed 's/^/  /'
    fi
    
    if [ "$DETAILED" = true ]; then
        echo -e "\n${BOLD}${CYAN}Files Owned by $user:${RESET}"
        echo -e "  ${YELLOW}NOTE: This may take some time for users with many files${RESET}"
        find "$homedir" -user "$user" -type f -perm /o+rwx -ls 2>/dev/null | \
            awk '{print "  " $3 " " $5 " " $6 " " $11}' | head -10
        
        local file_count=$(find "$homedir" -user "$user" -type f 2>/dev/null | wc -l)
        echo -e "  Total files: $file_count"
        
        echo -e "\n${BOLD}${CYAN}Crontabs:${RESET}"
        if [ -f "/var/spool/cron/crontabs/$user" ]; then
            cat "/var/spool/cron/crontabs/$user" | grep -v '^#' | sed '/^$/d' | sed 's/^/  /'
        else
            echo -e "  No crontab for $user"
        fi
    fi
}

# Function to check and print group information
check_groups() {
    if [ -n "$SPECIFIC_GROUP" ]; then
        if ! getent group "$SPECIFIC_GROUP" &>/dev/null; then
            echo -e "${RED}${BOLD}ERROR: Group '$SPECIFIC_GROUP' does not exist${RESET}"
            exit 1
        fi
        print_header "GROUP INFORMATION: $SPECIFIC_GROUP"
        check_specific_group "$SPECIFIC_GROUP"
    else
        print_header "GROUP INFORMATION"
        echo -e "${BOLD}Total groups:${RESET} $(getent group | wc -l)"
        
        echo -e "\n${BOLD}${CYAN}System groups (GID < 1000):${RESET}"
        getent group | awk -F: '$3 < 1000 {print "  - " $1 " (GID: " $3 ")"}' | head -10
        echo -e "  ${YELLOW}(showing first 10 of $(getent group | awk -F: '$3 < 1000' | wc -l))${RESET}"
        
        echo -e "\n${BOLD}${CYAN}User groups (GID >= 1000):${RESET}"
        getent group | awk -F: '$3 >= 1000 && $3 != 65534 {print "  - " $1 " (GID: " $3 ")"}' | sort
        
        if [ "$DETAILED" = true ]; then
            echo -e "\n${BOLD}${CYAN}Groups with sudo privileges:${RESET}"
            grep -E '^%' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | sed 's/^%/  - %/'
        fi
    fi
}

# Function to check and print specific group information
check_specific_group() {
    local group="$1"
    local gid=$(getent group "$group" | cut -d: -f3)
    
    echo -e "${BOLD}Group name:${RESET}       $group"
    echo -e "${BOLD}GID:${RESET}              $gid"
    
    echo -e "\n${BOLD}${CYAN}Group members:${RESET}"
    local members=$(getent group "$group" | cut -d: -f4)
    if [ -z "$members" ]; then
        echo -e "  No direct members"
    else
        echo "$members" | tr ',' '\n' | sed 's/^/  - /'
    fi
    
    # Find users with this as primary group
    echo -e "\n${BOLD}${CYAN}Users with $group as primary group:${RESET}"
    getent passwd | awk -F: -v gid="$gid" '$4 == gid {print "  - " $1}' | sort
    
    if [ "$DETAILED" = true ]; then
        echo -e "\n${BOLD}${CYAN}Files owned by group $group:${RESET}"
        echo -e "  ${YELLOW}NOTE: This may take some time for groups with many files${RESET}"
        find / -group "$group" -type f -ls 2>/dev/null | \
            awk '{print "  " $3 " " $5 " " $6 " " $11}' | head -10
    fi
    
    # Check sudo privileges
    echo -e "\n${BOLD}${CYAN}Sudo privileges:${RESET}"
    if grep -q "^%$group" /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
        grep "^%$group" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | sed 's/^/  /'
    else
        echo -e "  No sudo privileges for group $group"
    fi
}

# Function to check directory permissions
check_directory_permissions() {
    print_header "IMPORTANT DIRECTORY PERMISSIONS"
    
    # List of important directories to check
    local dirs=(
        "/home"
        "/etc"
        "/etc/sudoers.d"
        "/var/log"
        "/usr/bin"
        "/usr/sbin"
        "/bin"
        "/sbin"
        "/boot"
    )
    
    # Check each directory
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local perms=$(stat -c '%a' "$dir")
            local owner=$(stat -c '%U' "$dir")
            local group=$(stat -c '%G' "$dir")
            
            echo -e "${BOLD}$dir:${RESET}"
            echo -e "  Permissions: $perms"
            echo -e "  Owner: $owner"
            echo -e "  Group: $group"
            
            # Check for potentially insecure permissions
            case "$dir" in
                "/home")
                    if [ "$perms" != "755" ] && [ "$perms" != "750" ] && [ "$perms" != "700" ]; then
                        echo -e "  ${RED}WARNING: Unusual permissions for /home${RESET}"
                    fi
                    ;;
                "/etc")
                    if [ "$perms" != "755" ]; then
                        echo -e "  ${RED}WARNING: Unusual permissions for /etc${RESET}"
                    fi
                    ;;
                "/etc/sudoers.d")
                    if [ "$perms" != "750" ] && [ "$perms" != "755" ]; then
                        echo -e "  ${RED}WARNING: Unusual permissions for /etc/sudoers.d${RESET}"
                    fi
                    ;;
            esac
            
            echo ""
        fi
    done
    
    # Check home directories
    echo -e "${BOLD}${CYAN}User home directories:${RESET}"
    getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1 ":" $6}' | while IFS=: read -r user homedir; do
        if [ -d "$homedir" ]; then
            local perms=$(stat -c '%a' "$homedir")
            echo -e "  $homedir ($user): $perms"
            
            # Check for potentially insecure permissions
            if [ "$perms" != "700" ] && [ "$perms" != "750" ] && [ "$perms" != "755" ]; then
                echo -e "    ${RED}WARNING: Potentially insecure home directory permissions${RESET}"
            fi
        fi
    done
}

# Function to check SSH configuration
check_ssh_config() {
    print_header "SSH CONFIGURATION"
    
    if [ ! -f "/etc/ssh/sshd_config" ]; then
        echo -e "${YELLOW}SSH server not installed or configured${RESET}"
        return
    fi
    
    # Check key settings
    echo -e "${BOLD}${CYAN}Key SSH settings:${RESET}"
    
    local settings=(
        "PermitRootLogin"
        "PasswordAuthentication"
        "PubkeyAuthentication"
        "PermitEmptyPasswords"
        "X11Forwarding"
        "AllowUsers"
        "AllowGroups"
        "DenyUsers"
        "DenyGroups"
    )
    
    for setting in "${settings[@]}"; do
        local value=$(grep -i "^$setting" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        if [ -n "$value" ]; then
            echo -e "  $setting: $value"
            
            # Check for potentially insecure settings
            if [ "$setting" = "PermitRootLogin" ] && [ "$value" = "yes" ]; then
                echo -e "    ${RED}WARNING: Root login is enabled${RESET}"
            fi
            
            if [ "$setting" = "PasswordAuthentication" ] && [ "$value" = "yes" ]; then
                echo -e "    ${YELLOW}NOTE: Password authentication is enabled${RESET}"
            fi
            
            if [ "$setting" = "PermitEmptyPasswords" ] && [ "$value" = "yes" ]; then
                echo -e "    ${RED}WARNING: Empty passwords are allowed${RESET}"
            fi
        fi
    done
    
    # Check authorized keys
    echo -e "\n${BOLD}${CYAN}Authorized keys:${RESET}"
    getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1 ":" $6}' | while IFS=: read -r user homedir; do
        if [ -f "$homedir/.ssh/authorized_keys" ]; then
            local key_count=$(wc -l < "$homedir/.ssh/authorized_keys")
            echo -e "  $user: $key_count keys"
            
            if [ "$DETAILED" = true ]; then
                cat "$homedir/.ssh/authorized_keys" | cut -d' ' -f1-2 | sed "s/^/    /"
            fi
        fi
    done
    
    # Check for unusual SSH configuration files
    echo -e "\n${BOLD}${CYAN}Non-standard SSH configuration files:${RESET}"
    find /etc/ssh -type f -name "*.conf" | grep -v "sshd_config\|ssh_config" | while read -r file; do
        echo -e "  $file"
    done
}

# Function to check sudo configuration
check_sudo_config() {
    print_header "SUDO CONFIGURATION"
    
    # Check sudoers file
    echo -e "${BOLD}${CYAN}/etc/sudoers file:${RESET}"
    if [ -f "/etc/sudoers" ]; then
        local perms=$(stat -c '%a' "/etc/sudoers")
        local owner=$(stat -c '%U' "/etc/sudoers")
        
        echo -e "  Permissions: $perms"
        echo -e "  Owner: $owner"
        
        if [ "$perms" != "440" ] && [ "$perms" != "400" ]; then
            echo -e "  ${RED}WARNING: Unusual permissions for /etc/sudoers${RESET}"
        fi
        
        if [ "$owner" != "root" ]; then
            echo -e "  ${RED}WARNING: /etc/sudoers is not owned by root${RESET}"
        fi
        
        echo -e "\n${BOLD}${CYAN}Users with sudo access:${RESET}"
        grep -v '^#' /etc/sudoers | grep -E '^[^#%]' | grep -v "^Defaults" | sed 's/^/  /'
        
        echo -e "\n${BOLD}${CYAN}Groups with sudo access:${RESET}"
        grep -v '^#' /etc/sudoers | grep -E '^%' | sed 's/^/  /'
    else
        echo -e "  ${RED}WARNING: /etc/sudoers file not found${RESET}"
    fi
    
    # Check sudoers.d directory
    echo -e "\n${BOLD}${CYAN}/etc/sudoers.d directory:${RESET}"
    if [ -d "/etc/sudoers.d" ]; then
        local perms=$(stat -c '%a' "/etc/sudoers.d")
        local owner=$(stat -c '%U' "/etc/sudoers.d")
        
        echo -e "  Permissions: $perms"
        echo -e "  Owner: $owner"
        
        if [ "$perms" != "750" ] && [ "$perms" != "755" ]; then
            echo -e "  ${RED}WARNING: Unusual permissions for /etc/sudoers.d${RESET}"
        fi
        
        if [ "$owner" != "root" ]; then
            echo -e "  ${RED}WARNING: /etc/sudoers.d is not owned by root${RESET}"
        fi
        
        echo -e "\n${BOLD}${CYAN}Files in /etc/sudoers.d:${RESET}"
        find /etc/sudoers.d -type f -not -name "*~" | while read -r file; do
            echo -e "  $file:"
            local file_perms=$(stat -c '%a' "$file")
            local file_owner=$(stat -c '%U' "$file")
            
            echo -e "    Permissions: $file_perms"
            echo -e "    Owner: $file_owner"
            
            if [ "$file_perms" != "440" ] && [ "$file_perms" != "400" ]; then
                echo -e "    ${RED}WARNING: Unusual permissions for $file${RESET}"
            fi
            
            if [ "$file_owner" != "root" ]; then
                echo -e "    ${RED}WARNING: $file is not owned by root${RESET}"
            fi
            
            if [ "$DETAILED" = true ]; then
                echo -e "    Content:"
                cat "$file" | grep -v "^#" | sed -e '/^$/d' | sed 's/^/      /'
            fi
        done
    else
        echo -e "  /etc/sudoers.d directory not found"
    fi
}

# Main function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize output file
    echo "Permission Checker Report - $(date)" > "$OUTPUT_FILE"
    echo "=====================================" >> "$OUTPUT_FILE"
    
    # Redirect all output to both console and file
    exec > >(tee -a "$OUTPUT_FILE")
    
    # Check if running as root
    check_root
    
    # Print welcome message
    echo -e "${BOLD}${GREEN}Permission Checker Script${RESET}"
    echo -e "${GREEN}=============================${RESET}"
    echo -e "Generating report... This may take a few moments.\n"
    
    # Run all checks
    check_system_info
    check_users
    check_groups
    check_directory_permissions
    check_ssh_config
    check_sudo_config
    
    # Print completion message
    echo -e "\n${BOLD}${GREEN}Report completed!${RESET}"
    echo -e "Full report saved to: ${BOLD}$OUTPUT_FILE${RESET}"
}

# Run the main function
main "$@"
