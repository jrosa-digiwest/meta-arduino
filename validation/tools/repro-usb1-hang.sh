#!/bin/sh
# USB-1 reproducer (fork issue #1), baseline images: socat reopens /dev/ttyGS0
# while the gadget is unbound, then the adbd restart tears the gadget down and
# `rmdir functions/acm.GS0` hangs in state D until socat is stopped.
# With the fix use test-usb1-adbd-restart.sh instead (pass/fail result).
#   systemd-run --unit=usb1-repro sh /root/validation/repro-usb1-hang.sh
# Release a hang with: systemctl stop arduino-router-serial
O=/root/usb1-test; mkdir -p $O; L=$O/unbound.txt; : > $L
G=/sys/kernel/config/usb_gadget/arduino
log() { echo "$1 @$(cut -d' ' -f1 /proc/uptime) socat=$(pidof socat) held=$(ls -l /proc/$(pidof socat 2>/dev/null)/fd 2>/dev/null | grep -c ttyGS0) UDC=[$(cat $G/UDC)] adbd=$(systemctl is-active android-tools-adbd)" >> $L; }
log "start"
echo "" > $G/UDC; log "unbound"
for w in $(seq 1 20); do sleep 1; p=$(pidof socat) && ls -l /proc/$p/fd 2>/dev/null | grep -q ttyGS0 && break; done
sleep 1; log "socat reopened ttyGS0 on the unbound gadget"
systemctl restart android-tools-adbd > $O/restart.out 2>&1 &
for t in 5 10 20; do sleep $t; log "restart +${t}s step"; done
ps -o pid,stat,args | awk '$2 ~ /D/' >> $L
for p in $(ps -o pid,stat | awk '$2 ~ /D/ {print $1}'); do echo "=== stack $p ($(cat /proc/$p/comm))" >> $L; cat /proc/$p/stack >> $L 2>&1; done
systemctl status --no-pager android-tools-adbd 2>&1 | head -n 15 >> $L
echo "=== done" >> $L
