#!/bin/bash

# Build and install flycast standalone emulator
# Cache key: hash of the flycastsa recipe AND its patches (which the recipe copies
# from the working tree). Keying on the recipe alone would miss patch-only changes
# (e.g. the rg52mini 270-degree rotation patch) and silently reuse a stale build.
FLYCASTSA_RECIPE_SHA=$(cat rk3562_core_builds/scripts/flycastsa.sh rk3562_core_builds/patches/flycastsa-patch* 2>/dev/null | sha1sum | awk '{print $1}')
if [ -f "Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz" ] && \
   [ "$(cat Arkbuild_package_cache/${CHIPSET}/flycastsa.commit 2>/dev/null)" == "${FLYCASTSA_RECIPE_SHA}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh flycastsa
	  "
	sudo mkdir -p Arkbuild/opt/flycastsa
	if [[ "$CHIPSET" = "rk3326" ]]; then
	  ext="-rk3326"
	else
	  ext=""
	fi
	sudo cp -R Arkbuild/home/ark/${CHIPSET}_core_builds/flycastsa-64/flycast${ext} Arkbuild/opt/flycastsa/flycast
	sudo rm -f Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz Arkbuild_package_cache/${CHIPSET}/flycastsa.commit
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz Arkbuild/opt/flycastsa/
	echo "${FLYCASTSA_RECIPE_SHA}" | sudo tee Arkbuild_package_cache/${CHIPSET}/flycastsa.commit > /dev/null
fi

sudo mkdir -p Arkbuild/home/ark/.config/flycast
sudo cp flycast/config/emu.cfg Arkbuild/home/ark/.config/flycast/

# RG52 Mini portrait panel: run flycast in Vulkan and rotate with flycast's own
# renderer (rend.Rotate90). SDL2's RGA rotation only covers the GL swap path and
# explicitly skips Vulkan windows, so Vulkan flycast would otherwise be unrotated.
# Landscape devices (rg43h) and other chipsets keep the GL default (pvr.rend=0,
# Rotate90=no) where SDL2 handles rotation.
if [ "$UNIT" == "rg52mini" ]; then
  sudo sed -i 's/^pvr.rend = .*/pvr.rend = 4/'            Arkbuild/home/ark/.config/flycast/emu.cfg
  sudo sed -i 's/^rend.Rotate90 = .*/rend.Rotate90 = yes/' Arkbuild/home/ark/.config/flycast/emu.cfg
fi

call_chroot "chown -R ark:ark /opt/"
call_chroot "chown -R ark:ark /home/ark/.config/flycast/"
sudo chmod 777 Arkbuild/opt/flycastsa/flycast
