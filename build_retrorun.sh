#!/bin/bash

# Build and install Retrorun and Retrorun32
call_chroot "cd /home/ark &&
  if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh retrorun
  "
call_chroot32 "cd /home/ark &&
  if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh retrorun
  "
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retrorun-64/retrorun-${CHIPSET} Arkbuild/usr/local/bin/retrorun
sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retrorun-32/retrorun32-${CHIPSET} Arkbuild/usr/local/bin/retrorun32
sudo cp -a retrorun/scripts/*.sh Arkbuild/usr/local/bin/
sudo cp -a retrorun/configs/retrorun.cfg.${CHIPSET} Arkbuild/home/ark/.config/retrorun.cfg

sudo chmod 777 Arkbuild/usr/local/bin/retrorun*
sudo chmod 777 Arkbuild/usr/local/bin/atomiswave.sh
sudo chmod 777 Arkbuild/usr/local/bin/dreamcast.sh
sudo chmod 777 Arkbuild/usr/local/bin/naomi.sh
sudo chmod 777 Arkbuild/usr/local/bin/saturn.sh
