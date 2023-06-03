#/bin/sh

# Find the OS type and store it in a variable

function findOsType () {
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
		osType="Unknown"
	fi
}

findOsType
echo "af: findos"
# Find the distribution of the Linux system

function linux_FindDistro(){
	linux_distro=$(cat /etc/*-release 2> /dev/null | grep -oP '^ID_LIKE=\K.*' | tr '[[:upper:]]' '[[:lower:]]' )
}

# Install git on the Linux system

if [ $osType == "Linux" ]; then
	linux_FindDistro
	if [ $linux_distro == "debian" ]; then
		apt-get install git
	elif [ $linux_distro == "ubuntu" ]; then
		add-apt-repository ppa:git-core/ppa
		apt update; apt install git
	elif [ $linux_distro == "fedora" ]; then
		if command -v dnf > /dev/null 2>&1; then
			dnf install git
		else
			yum install git
		fi
	elif [ $linux_distro == "arch" || $linux_distro == "arch linux" ]; then
		pacman -S git
	elif [ $linux_distro == "gentoo" ]; then
		emerge --ask --verbose dev-vcs/git
	elif [ $linux_distro == "opensuse" ]; then
		zypper install git
	elif [ $linux_distro == "alpine" ]; then
		apk add git
	elif [ $linux_distro == "openbsd" ]; then
		pkg_add git
	elif [ $linux_distro == "slitaz" ]; then
		tazpkg get-install git
	fi

fi


if [ $osType == "Unkown" ]; then
	echo "Your OS is not supported. Please install git manually."
	echo "Head over to https://github.com/git/git or https://git-scm.com/downloads"
	exit 1
fi
