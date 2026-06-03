#!/bin/bash

# Build and install oga_controls for various dArkOS menus from christianhaitian/oga_controls

call_chroot "cd /home/ark &&
  git clone --recursive --depth=1 https://github.com/christianhaitian/oga_controls.git -b quitter
  "

# The RK3562 devices use our custom 'play_joystick' input driver (rk3562-joystick),
# not the rk3566 'singleadc-joypad'. The upstream 'rg503' profile — passed by
# Kodi.sh, saturn.sh and pico8.sh — hardcodes the singleadc-joypad evdev path
# (/dev/input/by-path/platform-singleadc-joypad-event-joystick), which does not
# exist here, so oga_controls opens nothing and no input reaches the app (e.g.
# Kodi modal dialogs become undismissable). Our driver's button/axis codes already
# match the rg503 profile: BTN_DPAD_* dpad (544-547), ABS 0/1 + 3/4 analog sticks,
# BTN_SOUTH/EAST/NORTH/WEST faces (304/305/307/308), 314/315 select/start, 310/311
# L1/R1, 317/318 L3/R3 — so only the device path needs repointing. Our gamepad
# enumerates as platform-play_joystick-event-joystick (DT node 'play_joystick').
if [ "$CHIPSET" == "rk3562" ]; then
  call_chroot "cd /home/ark/oga_controls &&
    sed -i 's#platform-singleadc-joypad-event-joystick#platform-play_joystick-event-joystick#' main.c"
fi

call_chroot "cd /home/ark/oga_controls &&
  make all &&
  mkdir -p /opt/quitter &&
  strip oga_controls &&
  cp oga_controls /opt/quitter/ &&
  chmod 777 /opt/quitter/oga_controls &&
  chown -R ark:ark /opt/quitter
  "
sudo rm -rf Arkbuild/home/ark/oga_controls
