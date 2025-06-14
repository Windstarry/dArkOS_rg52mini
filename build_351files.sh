#!/bin/bash

# Build and install 351Files
if [ "$CHIPSET" == "rk3326" ]; then
  UNIT="RGB10"
else
  UNIT="RG353V"
fi
call_chroot "cd /home/ark &&
  git clone --recursive https://github.com/christianhaitian/351Files.git &&
  cd 351Files &&
  ./build_RG351.sh ${UNIT} ArkOS /roms ./res &&
  strip 351Files &&
  mkdir -p /opt/351Files &&
  cp 351Files /opt/351Files/ &&
  chmod 777 /opt/351Files/351Files &&
  cp -R res/ /opt/351Files/
  "
sudo rm -rf Arkbuild/home/ark/351Files

