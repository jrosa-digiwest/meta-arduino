#!/bin/sh
# USB-1 regression test (fork issue #1): restart android-tools-adbd three times,
# each time after unbinding the gadget so that arduino-router-serial (socat)
# reopens /dev/ttyGS0 on the unbound gadget, which is the condition that used to
# hang `rmdir functions/acm.GS0`.
# Pass: every restart returns 0 within a few seconds, the UDC is bound again,
# and no task is left in state D.
# The restarts drop adb and USB networking, so run it as a transient unit:
#   systemd-run --unit=usb1-test sh /root/validation/test-usb1-adbd-restart.sh
# Result: /root/usb1-test/restart.txt
O=/root/usb1-test; mkdir -p $O; L=$O/restart.txt; : > $L
G=/sys/kernel/config/usb_gadget/arduino
log() { echo "$1 @$(cut -d' ' -f1 /proc/uptime) socat=$(pidof socat) held=$(ls -l /proc/$(pidof socat 2>/dev/null)/fd 2>/dev/null | grep -c ttyGS0) UDC=[$(cat $G/UDC)] adbd=$(systemctl is-active android-tools-adbd)" >> $L; }
echo "PartOf=$(systemctl show -p PartOf --value arduino-router-serial)" >> $L
for r in 1 2 3; do
    log "round $r start"
    if [ -n "$(cat $G/UDC)" ]; then
        echo "" > $G/UDC
        for w in $(seq 1 20); do sleep 1; p=$(pidof socat) && ls -l /proc/$p/fd 2>/dev/null | grep -q ttyGS0 && break; done
        sleep 1; log "round $r unbound, socat reopened ttyGS0"
    fi
    # BusyBox has no `timeout`: run the restart in the background and poll it.
    systemctl restart android-tools-adbd >> $L 2>&1 & rp=$!
    for w in $(seq 1 60); do kill -0 $rp 2>/dev/null || break; sleep 1; done
    if kill -0 $rp 2>/dev/null; then echo "FAIL: restart still running after 60 s" >> $L
    else wait $rp; rc=$?; echo "restart rc=$rc after ${w}s" >> $L; [ $rc = 0 ] || echo "FAIL: restart rc=$rc" >> $L; fi
    sleep 6; log "round $r after restart"
    [ -n "$(cat $G/UDC)" ] || echo "FAIL: UDC not bound after round $r" >> $L
    ps -o pid,stat,args | awk '$2 ~ /D/' >> $L
done
grep -q FAIL $L && echo "=== RESULT: FAIL" >> $L || echo "=== RESULT: PASS" >> $L
