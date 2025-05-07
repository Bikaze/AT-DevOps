# Linux Permissions Checker

## Overview

`check_permissions.sh` is a comprehensive script that provides detailed information about users, groups, and permissions on your Linux system. It's designed to help system administrators audit their systems, identify potential security issues, and understand the overall permissions structure.

This script requires sudo/root privileges to access all the necessary information.

## Features

### Comprehensive System Checks

* **System Information Overview**: Details about your system, including hostname, kernel version, and OS details
* **User Information and Permissions**: Complete user profiles with permissions, sudo access, and security settings
* **Group Information and Memberships**: Details about groups, their members, and associated permissions
* **Important Directory Permissions**: Analysis of critical system directories and their permission settings
* **SSH Configuration Security**: Assessment of SSH configuration files and security settings
* **Sudo Configuration Analysis**: Detailed inspection of sudo settings and privileges across the system

### Flexible Options

```
Usage: ./check_permissions.sh [options]

Options:
  -h, --help         Show this help message
  -d, --detailed     Show detailed information
  -u, --user USER    Show information for specific user
  -g, --group GROUP  Show information for specific group
  -o, --output FILE  Save output to specified file (default: permissions_report.txt)
```

### Color-coded Output

* Uses color formatting for better readability
* Highlights warnings and potential security issues in red
* Makes important section headers stand out with bold blue formatting
* Differentiates between different types of information with consistent color schemes

### Security Focused

* Identifies users with root access (UID 0)
* Checks for insecure home directory permissions
* Analyzes sudo privileges for users and groups
* Inspects SSH configuration for security issues (e.g., PermitRootLogin, PasswordAuthentication)
* Reviews critical system directories for incorrect permissions
* Alerts on potential security vulnerabilities with clear warnings

### Detailed Reporting

* Generates a comprehensive report file
* Includes timestamps and system information
* Option to focus on specific users or groups
* Saves all output to a configurable file for later analysis

## How to Use

### Basic Usage (requires sudo)

```bash
sudo ./check_permissions.sh
```

### Get Detailed Information

For more in-depth analysis:

```bash
sudo ./check_permissions.sh --detailed
```

### Check a Specific User

To focus on a single user's permissions and settings:

```bash
sudo ./check_permissions.sh --user jdoe
```

### Check a Specific Group

To examine a particular group's settings and members:

```bash
sudo ./check_permissions.sh --group engineering
```

### Save Report to a Custom File

To specify a different output file:

```bash
sudo ./check_permissions.sh --output security_audit.txt
```

## Example Output

When executed, the script produces organized, easy-to-read output like this:

```
SYSTEM INFORMATION
=================

Hostname:        server-01
Kernel:          5.15.0-72-generic
OS:              Ubuntu 22.04.2 LTS
Last Boot:       2023-05-07 09:32

USER INFORMATION
===============

Total users: 27

Users with UID 0 (root access):
  - root

Users with login shell:
  - jdoe (Shell: /bin/bash)
  - asmith (Shell: /bin/bash)
  - mjones (Shell: /bin/bash)
  ...
```

## Installation

1. Download the script:

```bash
wget https://example.com/check_permissions.sh
```

Or create it using your favorite text editor.

2. Make the script executable:

```bash
chmod +x check_permissions.sh
```

3. Run the script with sudo privileges:

```bash
sudo ./check_permissions.sh
```

## Security Note

This script requires root privileges to access system information. Always review scripts before running them with elevated privileges.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue to suggest improvements or report bugs.

