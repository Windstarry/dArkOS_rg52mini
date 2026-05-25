#!/bin/bash
#
# Bluetooth connection manager for RK3562 (RG52 Mini, RG43H Pro)
#
# bluez is enabled on all RK3562 devices to support hotplugged USB BT
# dongles, but the built-in radio is WiFi-only (RK915/AIC8800), so on a
# fresh boot there's typically no HCI controller registered. In that
# state `bluetoothctl` blocks waiting for one, which would hang the
# pre-suspend hook and prevent the device from ever actually sleeping.
# Bail out early when no controller is present, and put a hard timeout
# on every bluetoothctl call as a safety net.

# No HCI device -> nothing to do.
if ! compgen -G "/sys/class/bluetooth/hci*" > /dev/null; then
    exit 0
fi

case $1 in
    check)
        if timeout 2 bluetoothctl info 2>/dev/null | grep -q "Connected: yes"; then
            touch /var/local/btautoreconnect.state
        fi
        ;;
    reconnect)
        LAST_DEVICE=$(timeout 2 bluetoothctl paired-devices 2>/dev/null | head -1 | awk '{print $2}')
        if [ ! -z "$LAST_DEVICE" ]; then
            timeout 5 bluetoothctl connect "$LAST_DEVICE" 2>/dev/null
        fi
        ;;
    *)
        echo "Usage: $0 {check|reconnect}"
        ;;
esac
