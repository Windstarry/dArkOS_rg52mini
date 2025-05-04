#!/bin/bash

# Build and install SCUMMVM standalone emulator
sudo chroot Arkbuild/ bash -c "cd /home/ark &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh scummvm
  "
sudo mkdir -p Arkbuild/opt/scummvm
sudo cp -Ra Arkbuild/home/ark/rk3326_core_builds/scummvm/extra/ Arkbuild/opt/scummvm/
sudo cp -Ra Arkbuild/home/ark/rk3326_core_builds/scummvm/themes/ Arkbuild/opt/scummvm/
sudo cp -Ra Arkbuild/home/ark/rk3326_core_builds/scummvm/LICENSES/ Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/scummvm/scummvm Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/scummvm/AUTHORS Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/scummvm/COPYING Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/scummvm/COPYRIGHT Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/scummvm/NEWS.md Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/scummvm/README.md Arkbuild/opt/scummvm/
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/scummvm/scummvm
