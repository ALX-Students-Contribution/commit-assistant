#!/bin/bash

set -e

# Copy commit.sh to the bin directory
if ! sudo cp commit /usr/local/bin/; then
    echo "Error: Failed to copy commit script to /usr/local/bin/"
    exit 1
fi

# Prompt for Git username
read -p "Enter Git username: " username

# Validate that the username is not empty
if [[ -z "$username" ]]; then
    echo "Error: Git username cannot be empty"
    exit 1
fi

# Prompt for Git email
read -p "Enter Git email: " email

# Validate that the email is not empty
if [[ -z "$email" ]]; then
    echo "Error: Git email cannot be empty"
    exit 1
fi

echo

# Replace <user.name> and <user.email> in commit.sh with the provided values
if ! sudo sed -i "s/<user.name>/$username/g" /usr/local/bin/commit; then
    echo "Error: Failed to replace username in commit script"
    exit 1
fi

if ! sudo sed -i "s/<user.email>/$email/g" /usr/local/bin/commit; then
    echo "Error: Failed to replace email in commit script"
    exit 1
fi

sudo chmod 755 /usr/local/bin/commit
echo "Installation completed successfully"

