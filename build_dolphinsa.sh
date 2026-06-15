#!/bin/bash

# Build and install Dolphin standalone emulator
# Cache key: hash of the dolphinsa recipe AND its patches (the recipe copies the
# patches from the working tree, so a patch-only change must bust the cache too).
# Keyed per-UNIT because the RG52 Mini applies an extra Vulkan rotation patch
# (see below) that landscape devices don't, so the resulting binaries differ.
DOLPHINSA_RECIPE_SHA=$(cat rk3562_core_builds/scripts/dolphinsa.sh rk3562_core_builds/patches/dolphinsa-patch* 2>/dev/null | sha1sum | awk '{print $1}')
if [ -f "Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.tar.gz" ] && \
   [ "$(cat Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.commit 2>/dev/null)" == "${DOLPHINSA_RECIPE_SHA}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.tar.gz
    # Validate cache extraction produced the expected binary
    if [ ! -f "Arkbuild/opt/dolphin/dolphin-emu-nogui" ]; then
        echo "WARNING: Dolphin cache tarball is corrupt, rebuilding from source..."
        sudo rm -f Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.tar.gz
    fi
fi
if [ ! -f "Arkbuild/opt/dolphin/dolphin-emu-nogui" ]; then
	# The Vulkan 90-degree display rotation patch is only for portrait-panel
	# devices (RG52 Mini). Remove it for landscape-native devices (e.g. RG43H Pro)
	# so their dolphin binary matches upstream. (The patch self-disables on a
	# landscape swapchain at runtime too, but we drop it to keep the build clean.)
	if [ "$UNIT" != "rg52mini" ]; then
	  sudo rm -f Arkbuild/home/ark/${CHIPSET}_core_builds/patches/dolphinsa-patch-011-rk3562-vulkan-rotation.patch
	fi
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh dolphinsa
	  "
	sudo mkdir -p Arkbuild/opt/dolphin
	sudo mkdir -p Arkbuild/home/ark/.local/share/dolphin-emu
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/dolphinsa64/dolphin-emu-nogui Arkbuild/opt/dolphin/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/dolphin/Data/Sys/* Arkbuild/home/ark/.local/share/dolphin-emu/
	sudo rm -f Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.tar.gz Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.commit
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.tar.gz Arkbuild/opt/dolphin/ Arkbuild/home/ark/.local/share/dolphin-emu/
	echo "${DOLPHINSA_RECIPE_SHA}" | sudo tee Arkbuild_package_cache/${CHIPSET}/dolphinsa_${UNIT}.commit > /dev/null
fi
sudo cp -R dolphin/Config/ Arkbuild/home/ark/.local/share/dolphin-emu/
# rk3562 devices have a different built-in gamepad (evdev name "rk3562-joystick", not the
# rk3566 "retrogame_joypad"), so the shared GCPadNew.ini binds to nothing -> no input.
# Ship a chipset-specific GCPadNew.ini (correct Device name; GC Z on the R2 trigger axis
# since our R2 is an axis, not a button). Same pad on all rk3562 units, so keyed on CHIPSET.
if [ -f "dolphin/configs/${CHIPSET}/GCPadNew.ini" ]; then
  sudo cp dolphin/configs/${CHIPSET}/GCPadNew.ini Arkbuild/home/ark/.local/share/dolphin-emu/Config/GCPadNew.ini
fi
sudo cp dolphin/scripts/dolphin.sh Arkbuild/usr/local/bin/
call_chroot "chown -R ark:ark /opt/"
call_chroot "chown -R ark:ark /home/ark/"
sudo chmod 777 Arkbuild/opt/dolphin/dolphin-emu-nogui
sudo chmod 777 Arkbuild/usr/local/bin/dolphin.sh
