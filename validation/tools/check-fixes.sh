#!/bin/sh
# Checks for the fixes on unoq/wrynose that collect.sh/bootcheck.sh do not cover.
# Read-only. Usage on the board: sh /root/validation/check-fixes.sh
echo "### BLD-1 buildinfo + os-release"
head -n 12 /etc/buildinfo; grep -E 'BUILD_ID|VERSION_ID' /etc/os-release
echo "### LOG-1 persistent journal"
cat /etc/systemd/journald.conf.d/50-arduino-persistent.conf
ls -ld /var/log /var/log/journal; readlink /var/log || echo "/var/log is not a symlink"
journalctl --list-boots --no-pager | tail -n 15
journalctl --disk-usage
mount | grep -E ' /var/log| /var/volatile' || echo "no volatile mount for /var/log"
ls /var/log
echo "### TIME-1 / TIME-3"
zcat /proc/config.gz 2>/dev/null | grep -E 'RTC_HCTOSYS|RTC_SYSTOHC' || echo "no /proc/config.gz"
journalctl -k -b --no-pager | grep -iE 'hctosys|setting system clock' || echo "no hctosys message"
timedatectl | head -n 7; cat /sys/class/rtc/rtc0/since_epoch
ls -l --full-time /var/lib/systemd/timesync/clock
systemctl list-timers --all --no-pager | grep -iE 'logrotate|NEXT'
journalctl -b --no-pager | grep -iE 'in the future|Time jumped' | head -n 5
echo "### DSP-3 ACL on dma_heap"
ls -l /dev/dma_heap/; for f in /dev/dma_heap/*; do getfacl -p $f 2>&1 | grep -v '^$'; done
journalctl -b --no-pager | grep -i setfacl | head -n 3; echo "setfacl journal lines: $(journalctl -b --no-pager | grep -ci setfacl)"
echo "### NET-3/4/5"
nmcli -f NAME,TYPE,DEVICE,FILENAME connection show
ls -l /usr/lib/NetworkManager/system-connections/
systemctl is-enabled dnsmasq; systemctl is-active dnsmasq
cat /sys/kernel/config/usb_gadget/arduino/functions/ncm.usb0/dev_addr /sys/kernel/config/usb_gadget/arduino/functions/ncm.usb0/host_addr | tr -d '\000'
cat /sys/kernel/config/usb_gadget/arduino/strings/0x409/serialnumber
cat /var/lib/NetworkManager/dnsmasq-usb0.leases 2>/dev/null
echo "### NET-7: no router/DNS offered on usb0"
cat /etc/NetworkManager/dnsmasq-shared.d/90-arduino-usb0.conf 2>&1 | grep -v '^#'
echo "### SNS-1"
systemctl is-enabled sscrpcd 2>&1; systemctl is-active sscrpcd 2>&1
echo "adsp crashes this boot: $(journalctl -k -b --no-pager | grep -ciE 'adsp.*(crash|fatal error)|remoteproc.*crash detected')"
cat /proc/loadavg
echo "### BLD-2 adb group"
grep -E '^adb:' /etc/group || echo "no adb group"; id arduino
ls -ld /home/arduino
echo "### USB-1 drop-in"
systemctl cat arduino-router-serial.service --no-pager | tail -n 6
echo "=== done"
