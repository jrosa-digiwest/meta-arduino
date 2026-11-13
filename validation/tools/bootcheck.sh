#!/bin/sh
# Per-boot snapshot for reboot loops. Prints key=value lines.
km() { journalctl -k -b -o short-monotonic --no-pager; }  # dmesg ring overflows in crash loops
lim() {  # lim secs cmd...  (BusyBox has no `timeout`)
    t=$1; shift; ( "$@" ) 2>/dev/null & p=$!
    ( sleep "$t"; kill -9 "$p" 2>/dev/null ) & w=$!
    wait "$p" 2>/dev/null; kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
}
echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
echo "date=$(date -u +%FT%TZ)"
echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"
echo "startup=$(journalctl -b --no-pager | grep -o 'Startup finished.*(kernel).*' | head -n 1)"
echo "system_state=$(systemctl is-system-running)"
echo "failed=$(systemctl --failed --no-legend --plain | awk '{print $1}' | tr '\n' ' ')"
echo "jobs=$(systemctl list-jobs --no-legend | wc -l)"
# AUD-2
echo "apr_added=$(km | grep -c 'Adding APR/GPR dev')"
echo "apr_first=$(km | grep -m1 'Adding APR/GPR dev' | cut -d']' -f1 | tr -d '[ ')"
echo "adsp_up=$(km | grep -m1 'adsp is now up' | cut -d']' -f1 | tr -d '[ ')"
echo "lpi_pinctrl_deferred=$(grep -c a7c0000 /sys/kernel/debug/devices_deferred)"
q=$(lim 10 qrtr-lookup)
echo "qrtr_total=$(echo "$q" | grep -cE '^ *[0-9]')"
echo "qrtr_node5=$(echo "$q" | awk '$1 ~ /^[0-9]+$/ && $4 == 5' | wc -l)"
echo "qrtr_node0=$(echo "$q" | awk '$1 ~ /^[0-9]+$/ && $4 == 0' | wc -l)"
echo "sound_cards=$(grep -c ']:' /proc/asound/cards 2>/dev/null)"
# SNS-1 / DSP
echo "adsp_crashes=$(km | grep -c 'handling crash')"
echo "adsp_crash_last=$(km | grep -o 'handling crash #[0-9]*' | tail -n 1)"
echo "adsp_state=$(cat /sys/class/remoteproc/*/state | tr '\n' ' ')"
echo "adsprpcd=$(systemctl is-active adsprpcd) audiopd=$(systemctl is-active adsprpcd_audiopd) sscrpcd=$(systemctl is-active sscrpcd 2>/dev/null)"
# adb / gadget
echo "read_descriptors=$(km | grep -c 'read descriptors')"
echo "bcdversion_warn=$(km | grep -c bcdVersion)"
echo "udc=$(cat /sys/kernel/config/usb_gadget/*/UDC 2>/dev/null | tr '\n' ' ') udc_state=$(cat /sys/class/udc/*/state 2>/dev/null)"
echo "adbd=$(systemctl is-active android-tools-adbd)"
# TIME-1
echo "rtc_since_epoch=$(cat /sys/class/rtc/rtc0/since_epoch 2>/dev/null)"
echo "rtc_hctosys=$(km | grep -o 'setting system clock to.*' | head -n 1)"
echo "time_jumped=$(journalctl -b --no-pager | grep -c 'Time jumped backwards')"
# NET
echo "wait_online=$(systemctl is-active systemd-networkd-wait-online 2>/dev/null)/$(systemctl is-active NetworkManager-wait-online 2>/dev/null)"
echo "wlan0=$(cat /sys/class/net/wlan0/operstate 2>/dev/null) usb0=$(cat /sys/class/net/usb0/operstate 2>/dev/null)"
echo "ncm_dev_addr=$(cat /sys/kernel/config/usb_gadget/*/functions/ncm.*/dev_addr 2>/dev/null | tr -d '\000')"
echo "router_serial_fail=$(journalctl -b -u arduino-router-serial --no-pager | grep -c 'Failed with result')"
echo "kernel_warn=$(km | grep -cE 'WARNING: CPU|Call trace')"
