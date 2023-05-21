#!/bin/bash

set -e

# Copy commit.sh to the bin directory
if ! sudo cp commit /usr/local/bin/; then
    echo "Error: Failed to copy commit script to /usr/local/bin/"
    exit 1
fi

# Ask if the user will like to enter other details or will like to continue with the system configuration

read -p "Do you want to enter your details(y/n): " detail_choice

if [[ $detail_choice == 'y' || $detail_choice == 'Y' ]]; then
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
else
	username=$(git config --get user.name)
	email=$(git config --get user.email)
fi

# Add the credentials to a seperate file which will be used for future references

echo "user_username: $username" > ~/.commitconfig
echo "user_email: $email" >> ~/.commitconfig

sudo chmod 755 /usr/local/bin/commit
echo "Installation completed successfully"

