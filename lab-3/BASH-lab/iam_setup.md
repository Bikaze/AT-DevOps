# IAM Setup - Linux User Management Automation

## Overview

`iam_setup.sh` is a robust Bash script for automating Identity and Access Management (IAM) tasks on Linux systems. It streamlines the process of creating users and groups from CSV or TXT files, implements password policies, and can even send email notifications to newly created users.

This script is ideal for system administrators who need to efficiently manage user accounts, especially when onboarding multiple users simultaneously.

## Features

### Core Functionality

- **Batch User Creation**: Create multiple users at once from CSV or TXT files
- **Group Management**: Automatically create groups as needed
- **Home Directory Setup**: Configure proper home directories with appropriate permissions
- **Password Management**: Set temporary passwords and force password change on first login
- **Detailed Logging**: Track all actions with timestamps for audit purposes

### Advanced Features

## Email Notifications

To enable email notifications, you must set the following environment variables:

```bash
export MAILJET_API_KEY=your_api_key
export MAILJET_SECRET_KEY=your_secret_key
```

> ## [!CAUTION]
>
> The script is being run with **sudo**, which doesn't preserve your environment variables by default

## Solutions

Here are ways to fix this:

**Option 1: Export the variables before running the script**

```bash
export MAILJET_API_KEY="your-api-key"
export MAILJET_SECRET_KEY="your-secret-key"
sudo ./iam_setup.sh users.csv
```

**Option 2 (Recommended): Pass environment variables through sudo**

```bash
sudo MAILJET_API_KEY="your-api-key" MAILJET_SECRET_KEY="your-secret-key" ./iam_setup.sh users.csv
```

- **Password Complexity Checks**: Enforce strong password policies
- **Flexible Input**: Accept both CSV and TXT files with comma-separated values
- **Cleanup Capability**: Option to remove all created users and groups when needed
- **Secure Permissions**: Automatically set secure permissions on home directories

### Security Features

- **Safe Password Handling**: Sets temporary passwords that must be changed at first login
- **Home Directory Protection**: Sets permissions to 700 (user-only access)
- **Input Validation**: Checks input files for proper format and readability
- **Root Privilege Check**: Ensures the script is run with appropriate permissions
- **Tracking**: Keeps track of all created entities for proper cleanup

## Usage

### Basic Command Format

```bash
sudo ./iam_setup.sh <input_file> [options]
```

### Required Arguments

- `<input_file>`: Path to a CSV or TXT file containing user information

### Options

- `--cleanup`: Remove all users and groups created by this script

### Input File Format

The input file should be structured with comma-separated values:

```
username,fullname,group[,email]
```

Example:

```
jdoe,John Doe,engineering,john.doe@example.com
asmith,Alice Smith,engineering,alice.smith@example.com
mjones,Mike Jones,design,mike.jones@example.com
```

Fields:

- `username`: Login name for the user (required)
- `fullname`: Full name of the user (required)
- `group`: Group to which the user belongs (required)
- `email`: Email address for sending notifications (optional)

## Email Notifications

To enable email notifications, you must set the following environment variables:

```bash
export MAILJET_API_KEY=your_api_key
export MAILJET_SECRET_KEY=your_secret_key
```

The script uses the Mailjet API to send welcome emails to newly created users that include:

- Username
- Temporary password
- Instructions to change password on first login

## Examples

### Creating Users from a CSV File

```bash
sudo ./iam_setup.sh users.csv
```

### Cleaning Up Created Users and Groups

```bash
sudo ./iam_setup.sh users.csv --cleanup
```

Or use the dedicated cleanup script:

```bash
sudo ./iam_cleanup.sh
```

## Installation

1. Download the script:

```bash
wget https://example.com/iam_setup.sh
```

Or create it using your favorite text editor.

2. Make the script executable:

```bash
chmod +x iam_setup.sh
```

3. Run the script with sudo privileges:

```bash
sudo ./iam_setup.sh users.csv
```

## Companion Script: iam_cleanup.sh

The package includes a companion script `iam_cleanup.sh` that can remove all users and groups created by the main script. This is useful for testing or when you need to reset the system.

To use:

```bash
sudo ./iam_cleanup.sh
```

## Log Files

The script generates detailed logs to help track operations and troubleshoot issues:

- `iam_setup.log`: Records all actions performed by the main script
- `iam_cleanup.log`: Records all actions performed by the cleanup script

## Security Considerations

- **Run as Root**: This script must be run with sudo/root privileges
- **Password Storage**: Temporary passwords are set through the system and not stored by the script
- **Cleanup File**: A hidden file `.iam_setup_created` is created to track what was added

## Password Policies

The script enforces the following password complexity requirements:

- Minimum length: 8 characters
- Must include special characters
- Must include numbers
- Must include both uppercase and lowercase letters

These settings can be modified in the script's global variables section.

## Error Handling

The script includes comprehensive error handling to:

- Verify the input file exists and is readable
- Check for proper script permissions
- Validate password complexity
- Handle failures in user or group creation
- Log all errors with detailed information

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue to suggest improvements or report bugs.

## License

This script is released under the MIT License. See the LICENSE file for details.
