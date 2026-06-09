#!/bin/bash
#
# Build and install EmulationStation-fcamod for RK3562 (RG52 Mini)
#

if [ -f exports.sh ];
then
  source exports.sh
fi
echo "export devid=$(printenv DEV_ID)" | sudo tee Arkbuild/home/ark/ES_VARIABLES.txt
echo "export devpass=$(printenv DEV_PASS)" | sudo tee -a Arkbuild/home/ark/ES_VARIABLES.txt
echo "export apikey=$(printenv TGDB_APIKEY)" | sudo tee -a Arkbuild/home/ark/ES_VARIABLES.txt
echo "export softname=\"dArkOS-${UNIT}\"" | sudo tee -a Arkbuild/home/ark/ES_VARIABLES.txt

if [ -f "Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/emulationstation.commit)" == "$(curl -s https://api.github.com/repos/christianhaitian/EmulationStation-fcamod/commits/503noTTS | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz
    sudo rm Arkbuild/home/ark/ES_VARIABLES.txt
else
    call_chroot "apt-get -y update && eatmydata apt-get -y install libfreeimage3 fonts-droid-fallback libfreetype6 curl vlc-bin libsdl2-mixer-2.0-0"
    call_chroot "cd /home/ark &&
      source ES_VARIABLES.txt &&
      rm ES_VARIABLES.txt &&
      git clone --recursive --depth=1 https://github.com/christianhaitian/EmulationStation-fcamod -b 503noTTS &&
      cd EmulationStation-fcamod &&
      git submodule update --init &&
      cmake -DSCREENSCRAPER_DEV_LOGIN=\"devid=\$devid&devpassword=\$devpass\" -DGAMESDB_APIKEY=\"\$apikey\" -DSCREENSCRAPER_SOFTNAME=\"\$softname\" . &&
      make -j\$(nproc) &&
      mkdir -pv /usr/bin/emulationstation &&
      cp -a emulationstation /usr/bin/emulationstation &&
      chmod 777 /usr/bin/emulationstation &&
      cp -a resources /usr/bin/emulationstation/
      "
    if [ -f "Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz" ]; then
      sudo rm -f Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz
    fi
    if [ -f "Arkbuild_package_cache/${CHIPSET}/emulationstation.commit" ]; then
      sudo rm -f Arkbuild_package_cache/${CHIPSET}/emulationstation.commit
    fi
    sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz Arkbuild/usr/bin/emulationstation/
    sudo git --git-dir=Arkbuild/home/ark/EmulationStation-fcamod/.git --work-tree=Arkbuild/home/ark/EmulationStation-fcamod rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/emulationstation.commit
fi

# RK3562: bake the g13p0 Mali path into the ES binary's RPATH instead of setting
# LD_LIBRARY_PATH=/opt/emulationstation/lib in the launcher. The launcher prefix
# leaks into every emulator ES spawns (children inherit ES's environment), shadowing
# the system g24p0 Mali with g13p0 for GLES/EGL/GBM (RetroArch, standalone emulators).
# An ELF rpath is NOT inherited by child processes, so it fixes the leak.
#
# It MUST be DT_RPATH (--force-rpath), NOT DT_RUNPATH (plain --set-rpath). DT_RUNPATH
# is non-transitive: it would resolve only ES's own NEEDED libmali.so.1 to g13p0, while
# SDL2's NEEDED libgbm.so.1 / libwayland-egl.so.1 and the SDL_VIDEO_EGL_DRIVER dlopen
# of libEGL.so would still resolve to the system g24p0. That loads TWO Mali DDKs in one
# process (g13p0 + g24p0) and ES crashes on startup. DT_RPATH is transitive and is also
# searched for dlopen from libraries in the chain, so the whole ES process stays on g13p0
# (verified empirically) — matching the old LD_LIBRARY_PATH behavior without the leak.
# Idempotent, so safe on cache hits too.
if [ "$CHIPSET" == "rk3562" ]; then
  sudo patchelf --force-rpath --set-rpath '/opt/emulationstation/lib' Arkbuild/usr/bin/emulationstation/emulationstation
  verify_action
fi

sudo rm -rf Arkbuild/home/ark/EmulationStation-fcamod
sudo mkdir -p Arkbuild/etc/emulationstation/themes

# Use rk3566 configs as base (similar hardware capabilities)
if [[ "${BUILD_ARMHF}" == "y" ]]; then
  if [ -f "Emulationstation/es_systems.cfg.${CHIPSET}" ]; then
    sudo cp Emulationstation/es_systems.cfg.${CHIPSET} Arkbuild/etc/emulationstation/es_systems.cfg
  else
    sudo cp Emulationstation/es_systems.cfg.rk3566 Arkbuild/etc/emulationstation/es_systems.cfg
  fi
else
  if [ -f "Emulationstation/es_systems.cfg.${CHIPSET}-64bit_Only" ]; then
    sudo cp Emulationstation/es_systems.cfg.${CHIPSET}-64bit_Only Arkbuild/etc/emulationstation/es_systems.cfg
  else
    sudo cp Emulationstation/es_systems.cfg.rk3566-64bit_Only Arkbuild/etc/emulationstation/es_systems.cfg
  fi
fi

# Use existing config or fall back to rk3566/353m configs
if [ -f "Emulationstation/es_input.cfg.${UNIT}" ]; then
  sudo cp Emulationstation/es_input.cfg.${UNIT} Arkbuild/etc/emulationstation/es_input.cfg
else
  sudo cp Emulationstation/es_input.cfg.353m Arkbuild/etc/emulationstation/es_input.cfg
fi

if [ -f "Emulationstation/es_settings.cfg.${UNIT}" ]; then
  sudo cp Emulationstation/es_settings.cfg.${UNIT} Arkbuild/home/ark/.emulationstation/es_settings.cfg
else
  sudo cp Emulationstation/es_settings.cfg.353m Arkbuild/home/ark/.emulationstation/es_settings.cfg
fi

if [ -f "Emulationstation/emulationstation.sh.${UNIT}" ]; then
  sudo cp Emulationstation/emulationstation.sh.${UNIT} Arkbuild/usr/bin/emulationstation/emulationstation.sh
else
  sudo cp Emulationstation/emulationstation.sh.353m Arkbuild/usr/bin/emulationstation/emulationstation.sh
fi

sudo cp Emulationstation/fonts/* Arkbuild/usr/bin/emulationstation/resources/
sudo mkdir -p Arkbuild/usr/share/fonts/truetype/droid/
sudo wget -t 5 -T 30 --no-check-certificate https://github.com/aosp-mirror/platform_frameworks_base/raw/refs/heads/main/data/fonts/DroidSansFallbackFull.ttf -O Arkbuild/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf
sudo cp -R Emulationstation/scripts/ Arkbuild/home/ark/.emulationstation/
sudo chmod -R 777 Arkbuild/home/ark/.emulationstation/scripts/*
call_chroot "chown -R ark:ark /etc/emulationstation/"
call_chroot "chown -R ark:ark /home/ark/"
sudo chmod 777 Arkbuild/usr/bin/emulationstation/emulationstation.sh
sudo cp Emulationstation/emulationstation.service Arkbuild/etc/systemd/system/emulationstation.service
call_chroot "systemctl enable emulationstation"
