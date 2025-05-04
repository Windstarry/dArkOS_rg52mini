#!/bin/bash

#set -e

# Load shared utilities (if any)
source ./utils.sh

# Step-by-step build process
source ./setup_partition.sh
source ./bootstrap_rootfs.sh
source ./image_setup.sh
source ./build_kernel.sh
source ./build_deps.sh
source ./build_sdl2.sh
source ./build_gptokeyb.sh
source ./build_emulationstation.sh
source ./build_retroarch.sh
source ./build_mednafen.sh
source ./build_ecwolfsa.sh
source ./build_scummvmsa.sh
source ./build_ppssppsa.sh
source ./build_ogage.sh
source ./build_351files.sh
source ./build_filebrowser.sh
source ./build_wpasupplicant.sh
source ./finishing_touches.sh
source ./cleanup_filesystem.sh
source ./write_rootfs.sh
source ./clean_mounts.sh
source ./create_image.sh

# You can insert additional build steps here (e.g., bootloader, splash setup)

echo "RGB10 build completed. Final image is ready."

