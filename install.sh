#!/bin/bash

set -e

# Copy commit.sh to the bin directory
if ! sudo cp commit /usr/local/bin/; then
    echo "Error: Failed to copy commit script to /usr/local/bin/"
    exit 1
fi

# Check if git is installed in the system

if ! command -v git > /dev/null 2>&1; then
	echo -e "Git is not installed in your system \n Do you want to install it? (y/n): "

	read -r git_choice

	if [[ $git_choice == 'y' || $git_choice == 'Y' ]]; then
		chmod +x git_install.sh
	else
		echo "Script terminated. Please install git to continue."
		exit 1
	fi
fi

# Create a validation regex that will be used to validate if the email is correct or not
# This only checks for the syntax and not deliverability

regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

# Ask if the user will like to enter other details or will like to continue with the system configuration

read -rp "Do you want to enter your details(y/n): " detail_choice

if [[ $detail_choice == 'y' || $detail_choice == 'Y' ]]; then
	# Prompt for Git username
	read -rp "Enter Git username: " username

	# Validate that the username is not empty
	if [[ -z "$username" ]]; then
		echo "Error: Git username cannot be empty"
		exit 1
	fi

	# Prompt for Git email
	read -rp "Enter Git email: " email

	# Validate that the email is not empty
	if [[ -z "$email" ]]; then
		echo "Error: Your email is empty"
		exit 1
	fi

	# Validate the email is correct
	if [[ ! $email =~ $regex ]]; then
		echo "Error: Your email is invalid"
		exit 1
	fi
else
	username=$(git config --get user.name)
	email=$(git config --get user.email)
fi

# Add the credentials to a seperate file which will be used for future references

echo "user_username: $username" > ~/.commitconfig
echo "user_email: $email" >> ~/.commitconfig

sudo chmod +x /usr/local/bin/commit
echo "Installation completed successfully"

