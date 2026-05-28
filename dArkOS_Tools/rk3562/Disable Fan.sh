#!/bin/bash
# Stop the chassis fan by unbinding the pwm-fan driver. The driver's
# remove path drives PWM to 0 and drops the fan-vcc regulator, so the
# motor coasts to a stop cleanly. The thermal-trip notifier (BSP
# rockchip_system_monitor path) is torn down with the driver, so the
# kernel won't spin it back up. /home/ark/.config/.FAN_DISABLED is the
# persistence flag re-applied at boot by fan-state.service.
printf "\033c" >> /dev/tty1
DRV=/sys/bus/platform/drivers/pwm-fan
for d in "$DRV"/*; do
    [ -L "$d" ] || continue
    n=$(basename "$d")
    case "$n" in bind|unbind|uevent|module) continue;; esac
    echo "$n" | sudo tee "$DRV/unbind" > /dev/null
done
touch /home/ark/.config/.FAN_DISABLED
printf "\n\n\n\e[32mFan disabled.\n\nThe CPU/GPU are not thermally limited under normal load,\nbut sustained heavy use may warm the chassis.\n" > /dev/tty1
sudo cp "/usr/local/bin/Enable Fan.sh" "/opt/system/Advanced/"
sudo rm "/opt/system/Advanced/Disable Fan.sh"
sleep 3
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
