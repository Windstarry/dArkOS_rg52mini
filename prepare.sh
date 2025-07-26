#!/bin/bash

echo -e "Making sure necessary tools and ccache are available for the build....\n\n"
# Ensure some build tools are installed and ready
sudo apt -y update
for NEEDED_TOOL in bc btrfs-progs build-essential bison flex ccache debootstrap device-tree-compiler eatmydata gcc gdisk lib32stdc++6 libc6-i386 libncurses5-dev libssl-dev lz4 lzop python-is-python3 qemu-user-static zlib1g:i386 xfsprogs
do
  dpkg -s "$NEEDED_TOOL" &>/dev/null
  if [[ $? != "0" ]]; then
    sudo apt -y install ${NEEDED_TOOL}
    verify_action
  fi
done

# Create ccache if it does not exist already
if [ ! -d "Arkbuild_ccache" ]; then
  mkdir Arkbuild_ccache
fi
export CCACHE_DIR=${PWD}/Arkbuild_ccache
sudo /usr/sbin/update-ccache-symlinks
[ -z $(echo $PATH | grep ccache) ] && export PATH=/usr/lib/ccache:$PATH
