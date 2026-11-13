#!/bin/sh
# Validation checklist collector (INSTRUCTIONS.md + ISSUES.md items).
# Usage on the board: sh /root/validation/collect.sh > collect-<tag>.txt 2>&1
# Read-only, except for short functional probes (BT power/scan, Wi-Fi scan).

T=20   # default per-command time limit (s); BusyBox has no `timeout`
run() {  # run [-t secs] "label" "cmd"
    t=$T; [ "$1" = "-t" ] && { t=$2; shift 2; }
    echo; echo "### $1"; echo "\$ $2"
    ( eval "$2" ) 2>&1 &
    p=$!; ( sleep "$t"; kill -9 "$p" 2>/dev/null && echo "!!! killed after ${t}s" ) &
    w=$!; wait "$p" 2>/dev/null; kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
}
dedup() {  # first occurrence of each message (timestamps/pids/hex/numbers masked) + repeat count
    awk '{k=$0; sub(/^\[[ 0-9.]+\] /,"",k); gsub(/\[[0-9]+\]/,"",k); gsub(/0x[0-9a-fA-F]+/,"",k); gsub(/[0-9]+/,"N",k);
          c[k]++; if (c[k]==1) {o[++n]=$0; ok[n]=k}}
         END {for (i=1;i<=n;i++) printf "%5dx %s\n", c[ok[i]], o[i]}'
}
have() { command -v "$1" >/dev/null 2>&1; }
sec() { echo; echo "=================== $1"; }

sec "IDENTITY"
run "date/uptime" "date -u; uptime; cat /proc/uptime"
run "os-release" "cat /usr/lib/os-release"
run "kernel" "uname -a; cat /proc/cmdline"
run "soc" "cat /sys/devices/soc0/machine /sys/devices/soc0/soc_id /sys/devices/soc0/serial_number 2>/dev/null"
run "image markers" "ls /usr/bin/docker /usr/bin/weston /usr/bin/sscrpcd 2>&1; grep -c ep1 /usr/bin/arduino-gadget-setup; ls -l /lib/systemd/system/systemd-networkd.service 2>&1"

sec "BOOT HEALTH"
run "startup" "journalctl -b -o short-monotonic --no-pager | grep -E 'Startup finished|Reached target.*Multi-User'"
run "failed units" "systemctl --failed --no-pager --all"
run "jobs" "systemctl list-jobs --no-pager"
run "is-system-running" "systemctl is-system-running"
run -t 40 "journal warnings" "journalctl -b -p warning -o short-monotonic --no-pager | dedup"
run "dmesg err/warn (keyword filter; BusyBox dmesg has no --level)" "dmesg | grep -iE 'error|fail|warn|timeout|deferred|call trace|bug|oops|crash|fatal' | grep -v 'Adding APR' | dedup"
run "unit start times (top 25 by activation, no systemd-analyze)" "for u in \$(systemctl list-units --type=service --state=active --no-legend --plain | awk '{print \$1}'); do a=\$(systemctl show -p ExecMainStartTimestampMonotonic --value \$u); i=\$(systemctl show -p InactiveExitTimestampMonotonic -p ActiveEnterTimestampMonotonic --value \$u | tr '\n' ' '); echo \"\$i \$u\"; done | awk '{d=(\$2-\$1)/1000000; if (\$1>0) printf \"%8.3fs  start@%8.3fs  %s\n\", d, \$1/1000000, \$3}' | sort -rn | head -n 25"

sec "KERNEL AND HARDWARE"
run "modules" "lsmod"
run "remoteprocs" "for r in /sys/class/remoteproc/*; do echo \"\$r \$(cat \$r/name) \$(cat \$r/state) fw=\$(cat \$r/firmware 2>/dev/null)\"; done; echo crashes=\$(dmesg | grep -c 'handling crash')"
run "firmware load errors" "dmesg | grep -iE 'firmware|\.mbn|\.jsn' | grep -iE 'fail|error|-2'"
run "deferred devices" "cat /sys/kernel/debug/devices_deferred"
run "thermal" "for z in /sys/class/thermal/thermal_zone*; do echo \"\$(cat \$z/type) \$(cat \$z/temp)\"; done"
run "cpufreq" "for c in /sys/devices/system/cpu/cpufreq/policy*; do echo \"\$c gov=\$(cat \$c/scaling_governor) cur=\$(cat \$c/scaling_cur_freq) min=\$(cat \$c/scaling_min_freq) max=\$(cat \$c/scaling_max_freq)\"; done"
run "cpuidle" "cat /sys/devices/system/cpu/cpuidle/current_driver; for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do echo \"\$(cat \$s/name) usage=\$(cat \$s/usage)\"; done"
run "watchdog" "if command -v wdctl >/dev/null; then wdctl; else ls -l /dev/watchdog*; cat /sys/class/watchdog/watchdog0/identity /sys/class/watchdog/watchdog0/timeout 2>/dev/null; fi"
run "gpu/drm" "ls /sys/class/drm; for c in /sys/class/drm/card*-*; do echo \"\$c \$(cat \$c/status)\"; done; ls -l /dev/dri /dev/kgsl* 2>&1; dmesg | grep -iE 'adreno|a702|kgsl|msm_dpu' | head -n 20"
run "video" "ls -l /dev/video*; for v in /sys/class/video4linux/*; do echo \"\$v \$(cat \$v/name)\"; done; dmesg | grep -iE 'iris|venus|vpu' | head -n 20"

sec "STORAGE"
run "partitions" "if command -v lsblk >/dev/null; then lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,PARTLABEL; else cat /proc/partitions; fi"
run "partlabels" "ls -l /dev/disk/by-partlabel/ | grep -iE 'rootfs|boot|efi|dtb|userdata|persist'"
run "mounts/df" "df -h; mount | grep -E ' / | /var| /home| /run '"
run "expand-rootfs" "systemctl status --no-pager expand-rootfs 2>&1 | head -n 12; journalctl -b -u expand-rootfs --no-pager | tail -n 5"
run "emmc health" "for f in life_time pre_eol_info name manfid date fwrev; do echo \"\$f=\$(cat /sys/block/mmcblk0/device/\$f 2>/dev/null)\"; done"
run "A/B slots" "qbootctl 2>&1 | head -n 30"

sec "NETWORKING"
run "links/addrs" "ip -br link; ip -br addr; ip route; ip -6 route"
run "network managers" "for u in systemd-networkd systemd-networkd-wait-online NetworkManager NetworkManager-wait-online dnsmasq systemd-resolved avahi-daemon dropbear.socket rpcbind.socket docker containerd; do printf '%-34s enabled=%-10s active=%s\n' \$u \$(systemctl is-enabled \$u 2>/dev/null) \$(systemctl is-active \$u 2>/dev/null); done"
run "networkctl" "networkctl list --no-pager 2>&1"
run "nmcli" "nmcli general; nmcli dev; nmcli -f NAME,TYPE,DEVICE,AUTOCONNECT con"
run "usb0 udev" "udevadm info /sys/class/net/usb0 2>&1 | grep -E 'DEVTYPE|NM_UNMANAGED|INTERFACE|ID_NET'"
run "ncm mac" "cat /sys/kernel/config/usb_gadget/*/functions/ncm.*/dev_addr /sys/kernel/config/usb_gadget/*/functions/ncm.*/host_addr 2>&1"
run -t 25 "wifi scan" "nmcli -f SSID,CHAN,SIGNAL,SECURITY dev wifi list --rescan yes | head -n 15"
run "listening sockets" "netstat -tulpn"
run "resolv/time" "cat /etc/resolv.conf; timedatectl; timedatectl timesync-status 2>&1 | head -n 12"
run "iptables" "iptables -S 2>&1 | head -n 40; iptables -t nat -S 2>&1 | head -n 30"

sec "USB GADGET / ADB"
run "gadget" "for g in /sys/kernel/config/usb_gadget/*; do echo \"\$g UDC=\$(cat \$g/UDC)\"; ls \$g/functions \$g/configs/*/; done; cat /sys/class/udc/*/state"
run "adbd" "systemctl status --no-pager android-tools-adbd 2>&1 | head -n 12; systemctl status --no-pager usbgx 2>&1 | head -n 8"
run "gadget kernel msgs" "dmesg | grep -cE 'read descriptors'; dmesg | grep -iE 'bcdVersion|functionfs|ffs|dwc3|gadget|UDC' | head -n 30"
run "gadget unit logs" "journalctl -b --no-pager -o short-monotonic | grep -iE 'gadget|adbd|usbgx|ffs' | head -n 40"

sec "BLUETOOTH"
run "hci" "hciconfig -a"
run -t 25 "bluetoothctl" "bluetoothctl show; bluetoothctl power on; bluetoothctl --timeout 8 scan on | tail -n 5; bluetoothctl devices | wc -l"
run "bluetoothd log" "journalctl -b -u bluetooth --no-pager | tail -n 10"

sec "AUDIO / DSP"
run "sound cards" "cat /proc/asound/cards; command -v aplay >/dev/null && aplay -l; command -v arecord >/dev/null && arecord -l"
run "apr/rpmsg" "ls /sys/bus/rpmsg/devices; ls /sys/bus/apr/devices 2>/dev/null; dmesg | grep -c 'Adding APR'; lsmod | grep -E '^(apr|q6|snd_soc_qcom|qcom_q6v5)' "
run -t 15 "qrtr services" "qrtr-lookup"
run "fastrpc units" "for u in adsprpcd adsprpcd_audiopd sscrpcd rmtfs tqftpserv pd-mapper; do printf '%-20s enabled=%-10s active=%s\n' \$u \$(systemctl is-enabled \$u 2>/dev/null) \$(systemctl is-active \$u 2>/dev/null); done; journalctl -b -u adsprpcd_audiopd --no-pager | tail -n 6"
run "setfacl/udev" "ls -l /bin/setfacl /usr/bin/setfacl 2>&1; ls -l /dev/dma_heap/; journalctl -b --no-pager | grep -i setfacl | head -n 3"

sec "TIME / LOGS"
run "rtc" "cat /sys/class/rtc/rtc0/name /sys/class/rtc/rtc0/since_epoch /sys/class/rtc/rtc0/hctosys 2>&1; hwclock -r -u 2>&1; dmesg | grep -iE 'rtc|clock' | grep -iE 'setting|pm8xxx'; journalctl -b --no-pager -o short-monotonic | grep -iE 'Time jumped|timestamp on|clock synchroni|advanced'"
run "persistent timers" "journalctl -b --no-pager | grep -i 'persistent file timestamp'"
run "logging" "ls -ld /var/log /var/volatile/log 2>&1; journalctl --list-boots --no-pager 2>&1 | tail -n 5; journalctl --disk-usage; systemctl is-active rsyslog syslog 2>&1"
run "build id" "grep -E 'BUILD_ID|VERSION' /usr/lib/os-release; ls /etc/build /etc/version 2>&1; cat /etc/version 2>/dev/null"

sec "ARDUINO INTEGRATION"
run "router" "systemctl status --no-pager arduino-router arduino-router-serial 2>&1 | head -n 30; ls -l /var/run/arduino-router.sock; journalctl -b -u arduino-router-serial --no-pager -o short-monotonic | head -n 15"
run "mcu/openocd" "openocd --version 2>&1 | head -n 1; ls /usr/share/arduino* /lib/firmware/arduino* 2>&1 | head; systemctl list-units --all --no-pager | grep -iE 'arduino|stm32|mcu|flash'"
run "acm tty" "ls -l /dev/ttyGS* /dev/ttyHS* /dev/ttyMSM* 2>&1"

sec "USERS AND SECURITY"
run "users" "id root; id arduino; id adb 2>&1; ls -ld /home/arduino; grep -E '^(root|arduino):' /etc/shadow | cut -d: -f1,2; cat /etc/sudoers.d/* 2>&1"

sec "PERFORMANCE"
run "memory/load" "free -m; uptime; cat /proc/loadavg"
run "top" "top -b -n 1 | head -n 25"
run "running services" "systemctl list-units --type=service --state=running --no-legend --plain | awk '{print \$1}' | tr '\n' ' '; echo; systemctl list-units --type=service --state=running --no-legend | wc -l"

if have docker; then
sec "CONTAINER STACK"
run -t 30 "docker info" "docker info 2>&1 | head -n 40"
run -t 20 "docker networks" "docker network ls; ip -br addr | grep -E 'docker|veth|br-'; nmcli dev | grep -E 'docker|veth|br-'"
run "docker units" "systemctl status --no-pager docker containerd 2>&1 | head -n 25; journalctl -b -u docker --no-pager -p warning | tail -n 15"
run "weston" "systemctl list-units --all --no-pager | grep -iE 'weston|wayland'; systemctl status --no-pager weston 2>&1 | head -n 15; journalctl -b -u weston --no-pager | tail -n 15"
run "kgsl/iris dlkm" "lsmod | grep -iE 'kgsl|iris|msm|video|camx|cam'; dmesg | grep -iE 'kgsl|iris' | head -n 20"
run "thermald" "systemctl status --no-pager thermald 2>&1 | head -n 12; journalctl -b -u thermald --no-pager | tail -n 10"
run "userspace resource manager" "systemctl list-units --all --no-pager | grep -iE 'urm|resource'; for u in \$(systemctl list-units --all --no-legend --plain | awk '{print \$1}' | grep -iE 'urm|resource-manager'); do systemctl status --no-pager \$u | head -n 10; journalctl -b -u \$u --no-pager | tail -n 10; done"
run "camx/camera-service" "systemctl list-units --all --no-pager | grep -iE 'cam'; for u in \$(systemctl list-units --all --no-legend --plain | awk '{print \$1}' | grep -iE 'cam'); do systemctl status --no-pager \$u | head -n 10; journalctl -b -u \$u --no-pager | tail -n 10; done"
run "sensors" "systemctl status --no-pager sscrpcd 2>&1 | head -n 8"
fi
echo; echo "=================== END $(cat /proc/uptime)"
