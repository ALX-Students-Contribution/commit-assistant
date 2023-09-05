#/bin/sh

# Since this is mostly for linux devices, just install in it
# Some distro's (Saw this on antiX) that don't have the required headers
# I (or most of the people) cannot really resolve this. Plese refer to
# your distro instructions on how to get them

# If you encounter any problem (apart from missing files and other niche errors)
# Please open a pull request on the repo that you found this file in

# This file and any related (specified by owners) are listed under the
# The MIT License

# This piece of code is released in the hope of being helpful.
# It is given "AS IS" and no warranty whatsoever for any loss
# that may be encountered when use of this piece of code

# Any further modification to this particular file will be done here:
# https://gist.github.com/gekkowrld/77211531ae252c6c5b2abe201c696050

# Set the git repo in Github
github_repo="https://github.com/git/git"

# Find the base distro e.g if you are using Linux Mint it will be
# Ubuntu and if Garuda Linux then arch
# This helps narrow down into "base" distro that are atleast well
# supported and documented

linux_distro=$(cat /etc/*-release 2>/dev/null | grep -oP '^ID_LIKE=\K.*' | tr '[[:upper:]]' '[[:lower:]]')

# Install git on the Linux system

make_git() {

  # List the comands to be installed for the script to run
  commands='curl, wget, tar, make, jq, sed'

  # Set the delimeter to be used in seperating the commands
  IFS=', '

  # Loop over the commands and install each of them if unavailable
  for install_command in "$commands"; do

    if ! command -v "$install_command" >/dev/null 2>&1; then
      sudo "$1" "$install_command"

      if [ $? -ne 0 ]; then
        echo "Could not install $install_command, please install it manually"
        exit 1
      fi

    fi

  done

  git_version=$(curl "https://api.github.com/repos/git/git/tags" -s | jq -r '.[0].name')

  # Download the latest "git tag"
  if ! test -f "$git_version.tar.gz"; then
    wget https://github.com/git/git/archive/refs/tags/"$git_version".tar.gz
  fi

  # Unarchive the file for use in the installation
  tar -xf "$git_version".tar.gz

  # Switch to the git folder
  git_folder=$(echo "$git_version" | sed -e s/v/git-/)
  cd "$git_folder" || exit

  # This is a "faster" method of building git, if you prefer you can do a profile build
  # Building profile takes a lot of time so I won't attempt to do it here
  # Make them to usr/local/ for convenience instead of /usr/ because of distro upgrades
  make prefix=/usr/local all doc info
  sudo make prefix=/usr/local install install-doc install-html install-info

}

# Try to install the required software on some distros.
# If you have the required software on any distro, then it should work

if [ "$linux_distro" = 'debian' ] || [ "$linux_distro" = 'ubuntu' ]; then
  make_git "apt-get install"
elif [ "$linux_distro" = "fedora" ]; then
  if command -v dnf >/dev/null 2>&1; then
    make_git dnf
  else
    make_git yum
  fi
elif [ "$linux_distro" = 'arch' ] || [ "$linux_distro" = 'arch linux' ]; then
  make_git "pacman -S"
elif [ "$linux_distro" = "gentoo" ]; then
  make_git "emerge -uD"
elif [ "$linux_distro" = "opensuse" ]; then
  make_git "zypper --non-interactive --auto-agree-with-licenses install"
elif [ "$linux_distro" = "alpine" ]; then
  make_git "apk add"
else
  make_git "" 2>&1
  if [ $? -ne 0 ]; then
    echo "Could not install git, head over to $github_repo for installation"
    exit 1
  fi
fi
