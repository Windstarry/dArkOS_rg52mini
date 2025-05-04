#!/bin/bash

# Build and install Mednafen
sudo chroot Arkbuild/ bash -c "cd /home/ark &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh mednafen
  "
sudo mkdir -p Arkbuild/opt/mednafen
sudo mkdir -p Arkbuild/home/ark/.mednafen
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/mednafen64/mednafen Arkbuild/opt/mednafen/
sudo cp -a mednafen/configs/mednafen.cfg.rgb10 Arkbuild/home/ark/.mednafen/mednafen.cfg
sudo cp -a mednafen/mednafen Arkbuild/usr/local/bin/

sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark/.mednafen/"
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/mednafen/mednafen
sudo chmod 777 Arkbuild/usr/local/bin/mednafen

