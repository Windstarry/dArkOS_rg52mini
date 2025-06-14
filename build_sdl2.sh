#!/bin/bash

if [ "$1" == "32" ]; then
  ARCH="arm-linux-gnueabihf"
  CHROOT_DIR="Arkbuild32"
else
  ARCH="aarch64-linux-gnu"
  CHROOT_DIR="Arkbuild"
fi

# Build and install SDL2
if [ "$ARCH" == "arm-linux-gnueabihf" ]; then
  sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
    if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
    cd ${CHIPSET}_core_builds &&
    chmod 777 builds-alt.sh &&
    eatmydata ./builds-alt.sh sdl2 &&
    cd SDL &&
    make install
    "
else
  sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
    if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
    cd ${CHIPSET}_core_builds &&
    chmod 777 builds-alt.sh &&
    eatmydata ./builds-alt.sh sdl2 &&
    cd SDL/build &&
    make install
    "
fi

extension="3000.10"
#sudo mv -f -v ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/sdl2-64/libSDL2-2.0.so.0.${extension}.rotated ${CHROOT_DIR}/usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension}
#sudo mv -f -v ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/sdl2-32/libSDL2-2.0.so.0.${extension}.rotated ${CHROOT_DIR}/usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension}
#sudo rm -rfv ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/sdl2-64
#sudo rm -rfv ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/sdl2-32
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2.so /usr/lib/${ARCH}/libSDL2-2.0.so.0"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension} /usr/lib/${ARCH}/libSDL2.so"
#sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2.so /usr/lib/${ARCH}/libSDL2-2.0.so.0"
#sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension} /usr/lib/${ARCH}/libSDL2.so"
sudo cp -R ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL/include/* ${CHROOT_DIR}/usr/include/${ARCH}/SDL2/
sudo rm -rf ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL
