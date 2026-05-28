#!/bin/bash
# Re-bind the pwm-fan driver. The platform device name for the unnumbered
# DT node `pwm-fan { ... };` is just "pwm-fan". If the driver is already
# bound, the bind echo returns -EBUSY which we ignore.
printf "\033c" >> /dev/tty1
DRV=/sys/bus/platform/drivers/pwm-fan
echo "pwm-fan" | sudo tee "$DRV/bind" > /dev/null 2>&1 || true
rm -f /home/ark/.config/.FAN_DISABLED
printf "\n\n\n\e[32mFan re-enabled.\n\nAuto-ramps with CPU/GPU temperature.\n" > /dev/tty1
sudo cp "/usr/local/bin/Disable Fan.sh" "/opt/system/Advanced/"
sudo rm "/opt/system/Advanced/Enable Fan.sh"
sleep 3
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
