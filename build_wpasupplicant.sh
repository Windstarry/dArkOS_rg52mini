#!/bin/bash

# Build and install modified wpa_supplicant with SAE fixes
call_chroot "cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh wpa_supplicant
  "

sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/wpa_supplicant/wpa_passphrase Arkbuild/usr/bin/wpa_passphrase
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/wpa_supplicant/wpa_cli Arkbuild/usr/sbin/wpa_cli
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/wpa_supplicant/wpa_supplicant Arkbuild/usr/sbin/wpa_supplicant
sudo chmod 777 Arkbuild/usr/bin/wpa_*
sudo chmod 777 Arkbuild/usr/sbin/wpa_*
