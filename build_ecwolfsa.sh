#!/bin/bash

# Build and install ECWolf standalone emulator
sudo chroot Arkbuild/ bash -c "cd /home/ark &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh ecwolfsa
  "
sudo mkdir -p Arkbuild/opt/ecwolf
sudo mkdir -p Arkbuild/home/ark/.config/ecwolf
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/ecwolf-64/* Arkbuild/opt/ecwolf/
sudo cp -a ecwolf/config/ecwolf.cfg.rgb10 Arkbuild/home/ark/.config/ecwolf/ecwolf.cfg
sudo cp -a ecwolf/ecwolf* Arkbuild/usr/local/bin/

sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark/.config/"
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ecwolf/*
sudo chmod 777 Arkbuild/usr/local/bin/ecwolf*
