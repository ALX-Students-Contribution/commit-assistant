#/bin/sh

github_repo="https://github.com/git/git"

# Find the OS type and store it in a variable
# Some of the installations are nearly the same in different OS'es
# If you spot any, please combine to reduce redundancy
findOsType () {

	if [ $OSTYPE == "linux-gnu" ]; then
		osType="Linux"
	elif [ $OSTYPE == "darwin"* ]; then
		osType="MacOS"
	elif [ $OSTYPE == "cygwin" ]; then
		osType="Cygwin"
	elif [ $OSTYPE == "msys" ]; then
		osType="MSYS"
	elif [ $OSTYPE == "win32" ]; then
		osType="Windows"
	elif [ $OSTYPE == "freebsd"* ]; then
		osType="FreeBSD"
	else
		echo "Your OS is not supported. Please install git manually."
		echo "Head over to $github_repo for installation"
		exit 1
	fi

}

findOsType

# Find the distribution of the Linux system

function FindDiff(){

	if [ $osType == "Linux" ]; then
		linux_distro=$(cat /etc/*-release 2> /dev/null | grep -oP '^ID_LIKE=\K.*' | tr '[[:upper:]]' '[[:lower:]]' )
	fi

}

# Install git on the Linux system

make_git() {

		# List the comands to be installed for the script to run
		commands='curl, wget, tar, make, jq, sed'

		# Set the delimeter to be used in seperating the commands
		IFS=', '

		# Loop over the commands and install each of them if unavailable
		for install_command in $commands; do

			if ! command -v $install_command > /dev/null 2>&1; then
				sudo $1 install $install_command

				if [ $? -ne 0 ]; then
					echo "Could not install $install_command, please install it manually"
					exit 1
				fi

			fi

		done

		git_version=$(curl "https://api.github.com/repos/git/git/tags" -s | jq -r '.[0].name')

		# Download the latest "git tag"
		if ! test -f "$git_version.tar.gz"; then
			wget https://github.com/git/git/archive/refs/tags/$git_version.tar.gz -O $git_version.tar.gz
		fi

		# Unarchive the file for use in the installation
		tar -xf $git_version.tar.gz

		# Switch to the git folder
		git_folder=$(echo $git_version | sed -e s/v/git-/)
		cd $git_folder

		# This is a "faster" method of building git, if you prefer you can do a progile build
		# Building profile takes a lot of time so I won't attempt to do it here

		make prefix=/usr all doc info
		sudo make prefix=/usr install install-doc install-html install-info

}

if [ $osType == "Linux" ]; then
	FindDiff
	if [[ $linux_distro == "debian" || $linux_distro == "ubuntu" ]]; then
		make_git apt-get
	elif [ $linux_distro == "fedora" ]; then
		if command -v dnf > /dev/null 2>&1; then
			make_git dnf
		else
			make_git yum
		fi
	elif [[ $linux_distro == "arch" || $linux_distro == "arch linux" ]]; then
		make_git pacman
	elif [ $linux_distro == "gentoo" ]; then
		make_git emerge
	elif [ $linux_distro == "opensuse" ]; then
		make_git zypper
	elif [ $linux_distro == "alpine" ]; then
		make_git apk
	elif [ $linux_distro == "openbsd" ]; then
		make_git pkg_add
	elif [ $linux_distro == "slitaz" ]; then
		make_git tazpkg
	else
		make_git "" 2>&1
		if [ $? -ne 0 ]; then
			echo "Could not install git, head over to $github_repo for installation"
			exit 1
		fi
	fi

fi
