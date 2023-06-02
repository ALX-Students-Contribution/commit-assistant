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

# Find the distribution of the Linux system

function linux_FindDistro(){
	linux_distro=$(cat /etc/*-release 2> /dev/null | grep -oP '^ID_LIKE=\K.*' | tr '[[:upper:]]' '[[:lower:]]' )

}

# Install git on the Linux system

if [ $osType == "Linux" ]; then
	linux_FindDistro
	if [ $linux_distro == 'debian' ]; then
		apt-get install git
	if [ $linux_distro == 'ubuntu' ]; then
		add-apt-repository ppa:git-core/ppa
		apt update; apt install git
	if [ $linux_distro == 'fedora' ]; then
		if command -v dnf > /dev/null 2>&1; then
			dnf install git
		else
			yum install git
		fi
	if [ $linux_distro == 'arch' || $linux_distro == 'arch linux' ]; then
		pacman -S git
	if [ $linux_distro == 'gentoo' ]; then
		emerge --ask --verbose dev-vcs/git
	if [ $linux_distro == 'opensuse' ]; then
		zypper install git
	if [ $linux_distro == 'alpine' ]; then
		apk add git
	if [ $linux_distro == 'openbsd' ]; then
		pkg_add git
	if [ $linux_distro == 'slitaz' ]; then
		tazpkg get-install git

fi
