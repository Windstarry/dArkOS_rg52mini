#!/bin/bash
#
# ledctl -- analog-stick RGB LED control for AISLPC RK3562 handhelds
#           (RG52 Mini / RG43H Pro / RG43V Pro).
#
# The LEDs are driven by a small on-board MCU on uart1 (/dev/ttyS1). The
# protocol was reverse-engineered from the stock EmuELEC "mcu_led" binary:
#
#   * the port is opened ONCE, write-only, with CLOCAL set (the MCU link has
#     no modem-control lines), 9600 baud, 8N1, raw.
#   * wire format: write ONE byte = the value, repeated 3x, 10ms apart
#       chgmode N -> byte N   (1=G 2=B 3=R 4=G+B 5=R+G 6=B+R 7=rainbow
#                              8=scrolling 9=OFF ; 17-24 = breathing variants)
#       brightness B -> byte (50 - B)
#       init <4|8>   -> byte 0x20 / 0x21  (LED chain length; optional)
#
# Opening the port once (rather than per-byte) matters: re-opening /dev/ttyS1
# for every write glitches the line and the MCU ignores the command, leaving
# it in its power-on "flowing rainbow" default.
#
# The MCU is powered from the "vcc-led" rail (GPIO0_C7), gated through the
# regulator debugfs "enable" knob -- exactly as the stock script did. The
# rail is OFF at boot, so the LEDs stay dark until the user opts in.
#
# Persistence: /home/ark/.config/led.cfg (ENABLED/MODE/BRI/INIT).
#
# Must run as root (debugfs + tty). The UI calls it via sudo.

LED_DEV=/dev/ttyS1
LED_PWR=/sys/kernel/debug/regulator/vcc-led/enable
CFG=/home/ark/.config/led.cfg

# Defaults -- OFF, solid red, mid brightness, no chain-length handshake.
ENABLED=0
MODE=3
BRI=5
INIT=0          # 0 = skip; 4 or 8 = send the MCU "init <count>" first

# shellcheck source=/dev/null
[ -f "$CFG" ] && . "$CFG"

# No MCU UART on this unit (uart1 disabled / device not equipped) -> no-op.
[ -e "$LED_DEV" ] || exit 0

# Gate the vcc-led rail. Harmless if debugfs is absent/unwritable.
pwr() {
	[ -w "$LED_PWR" ] && printf '%s' "$1" > "$LED_PWR" 2>/dev/null
}

# Open the MCU UART once on fd 9, write-only, CLOCAL (no carrier wait), raw.
open_uart() {
	stty -F "$LED_DEV" 9600 cs8 -cstopb -parenb clocal -crtscts -ixon raw -echo 2>/dev/null
	exec 9>"$LED_DEV" 2>/dev/null
}
close_uart() { exec 9>&- 2>/dev/null; }

# Send one byte (decimal) on the held-open fd, 3x, 10ms apart (matches stock).
send() {
	local oct i
	oct=$(printf '%03o' "$1")
	for i in 1 2 3; do
		printf "\\$oct" >&9 2>/dev/null
		sleep 0.01
	done
}

save() {
	mkdir -p "$(dirname "$CFG")"
	printf 'ENABLED=%s\nMODE=%s\nBRI=%s\nINIT=%s\n' "$ENABLED" "$MODE" "$BRI" "$INIT" > "$CFG"
	chown ark:ark "$CFG" 2>/dev/null
}

light_on() {
	pwr 1
	open_uart || return
	if [ "$INIT" = "8" ]; then send 33; sleep 0.05      # 0x21 = 8-LED chain
	elif [ "$INIT" = "4" ]; then send 32; sleep 0.05    # 0x20 = 4-LED chain
	fi
	send "$MODE"
	sleep 0.05
	send $((50 - BRI))
	close_uart
}

light_off() {
	open_uart || { pwr 0; return; }
	send 9              # mode 9 = OFF
	close_uart
	pwr 0               # then drop the rail
}

case "$1" in
	apply)   [ "$ENABLED" = "1" ] && light_on || light_off ;;
	on)      ENABLED=1; save; light_on ;;
	off)     ENABLED=0; save; light_off ;;
	mode)    MODE=${2:-$MODE}; save; [ "$ENABLED" = "1" ] && light_on ;;
	bri)     BRI=${2:-$BRI};   save; [ "$ENABLED" = "1" ] && light_on ;;
	init)    INIT=${2:-0};     save; [ "$ENABLED" = "1" ] && light_on ;;
	suspend) light_off ;;
	# Debug: send arbitrary byte(s) on a freshly opened port. e.g. ledctl raw 3
	raw)     shift; pwr 1; open_uart || exit 1; for b in "$@"; do send "$b"; done; close_uart ;;
	status)  printf 'ENABLED=%s MODE=%s BRI=%s INIT=%s\n' "$ENABLED" "$MODE" "$BRI" "$INIT" ;;
	*)       echo "usage: ledctl {apply|on|off|mode N|bri B|init 4|8|suspend|raw B...|status}" >&2; exit 2 ;;
esac
