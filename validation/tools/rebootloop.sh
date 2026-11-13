#!/usr/bin/env bash
# Host-side reboot loop over SSH (Wi-Fi), independent of adb.
#   rebootloop.sh <board-ip> <adb-serial> <out-dir> <boots> [collect-on-boot-1: yes|no]
# Per boot: reboot over SSH, wait for SSH, wait for systemd to leave "starting",
# run bootcheck.sh, and record whether the host sees the board on adb.
set -u
IP=$1; SER=$2; OUT=$3; N=$4; COLLECT=${5:-yes}
HERE=$(dirname "$(readlink -f "$0")")
S() { timeout "${T:-30}" "$HERE/bssh" "$IP" "$@" < /dev/null; }
LOG=$OUT/reboot-loop.txt
mkdir -p "$OUT"
echo "# reboot loop over SSH on $IP (adb serial $SER), $N boots, started $(date -u +%FT%TZ)" >> "$LOG"
for i in $(seq 1 "$N"); do
    old=$(T=15 S cat /proc/sys/kernel/random/boot_id | tr -d '\r')
    T=15 S 'systemctl reboot' >/dev/null 2>&1
    t0=$(date +%s); new=""
    while [ $(( $(date +%s) - t0 )) -lt 420 ]; do
        sleep 10
        new=$(T=12 S cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '\r')
        [ -n "$new" ] && [ "$new" != "$old" ] && break
    done
    if [ -z "$new" ] || [ "$new" = "$old" ]; then
        echo "=== boot $i: SSH DID NOT COME BACK with a new boot_id within 420 s ($(date -u +%FT%TZ))" >> "$LOG"
        exit 2
    fi
    ssh_s=$(( $(date +%s) - t0 ))
    for _ in $(seq 1 60); do
        st=$(T=12 S systemctl is-system-running 2>/dev/null | tr -d '\r')
        up=$(T=12 S cut -d. -f1 /proc/uptime 2>/dev/null | tr -d '\r')
        [ -n "$st" ] && [ "$st" != "starting" ] && [ "${up:-0}" -ge 45 ] && break
        sleep 5
    done
    sleep 5   # let adb enumerate on the host if it is going to
    hostadb=$(env -u LD_LIBRARY_PATH adb devices | awk -v s="$SER" '$1==s {print $2}')
    {
        echo "=== boot $i  host=$(date -u +%FT%TZ)  ssh_back_after=${ssh_s}s  host_adb=${hostadb:-absent}"
        T=60 S sh /root/validation/bootcheck.sh 2>&1 | tr -d '\r' | grep -v 'ignored null byte'
    } >> "$LOG"
    if [ "$i" = 1 ] && [ "$COLLECT" = yes ]; then
        T=600 S sh /root/validation/collect.sh 2>&1 | tr -d '\r' > "$OUT/collect-boot1.txt"
    fi
done
echo "# done $(date -u +%FT%TZ)" >> "$LOG"
