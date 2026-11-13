# UNO Q (`imola`) image validation

Fork-only. Status of the `arduino-console-image` and `arduino-container-image` validation on two boards, the fixes
on `unoq/wrynose`, and the scripts used. The detailed issue list, with evidence and reasoning, is
`ISSUES.md` in the console baseline folder of the local image store (see [Evidence](#evidence)).

## Images

| Column | Image | Built from | Board |
|---|---|---|---|
| CB | console `20261112163151` | `origin/wrynose` `6cc3e50` | A |
| KB | container `20261107184228` | `origin/wrynose` `6cc3e50` | B |
| CP | console `20261113121944` | `unoq/wrynose` `34f89c5` | A |
| KP | container `20261113125103` | `unoq/wrynose` `34f89c5` | B |

Each image got the checklist (`collect.sh`) on its first boot and a 12-boot loop (`rebootloop.sh`).
Two follow-up fixes were committed after CP/KP (marked v2) and are **trialled live only, not built yet**:
USB-1 `34b2b77` and NET-7 `805c105` (`unoq/wrynose` `5d4be70`).

## Fixes

Every fix is a topic branch from `origin/wrynose` merged into `unoq/wrynose`. A fix in a package recipe reaches
every image that installs the package; `arduino-image.inc` reaches every image built on it.

| ID | Problem | Branch | Commits | CP | KP |
|---|---|---|---|---|---|
| USB-2 | gadget bind race, no USB after reboot (5/12 boots) | `fix/arduino-usb-gadget-wait-adbd` | `ed5c1de` | fixed 12/12 | fixed 12/12 |
| NET-1/2 | networkd next to NetworkManager, 2 min 20 s boot | `fix/arduino-image-drop-systemd-networkd` | `9f30513` | fixed (21 s) | fixed (26 s) |
| TIME-1 | RTC hctosys rolls the clock back to 1970 | `fix/linux-qcom-imola-no-rtc-hctosys` | `fb917e6` | fixed | fixed |
| SNS-1 | `sscrpcd` crashes the ADSP ≈190×/boot (container) | `fix/qcom-sensors-binaries-qcm2290-no-sscrpcd` | `c609012` | n/a | fixed (0 crashes) |
| USB-1 | adbd restart hangs in `rmdir acm.GS0` (fork #1) | `fix/arduino-usb-gadget-router-serial-lifetime` | `07465cf`, v2 `34b2b77` | v1 regressed, v2 trial 3/3 | same |
| NET-5 | random NCM MACs | `fix/arduino-usb-gadget-stable-ncm-mac` | `d8a52ef` | fixed | fixed |
| NET-4 | system dnsmasq blocks NM shared mode | `fix/dnsmasq-disable-system-service` | `1b72261` | fixed | fixed |
| NET-3 | USB networking not configured | `fix/arduino-usb-gadget-ncm-networkmanager` | `5437fe7` | fixed | fixed |
| NET-7 | host gets default route + DNS via the board | same branch | v2 `805c105` | new, v2 trial OK | same |
| VID-1 | VPU firmware missing | `fix/packagegroup-uno-q-vpu-firmware` | `f9d96ee` | fixed | fixed |
| VID-2 | `iris-video-dlkm` blacklists `qcom_iris` (container) | `fix/iris-video-dlkm-qcm2290-qcom-iris` | `2f62d26` | n/a | fixed (HW round trip 120/120) |
| DSP-3 | `/bin/setfacl` missing for the fastrpc ACL rule | `fix/fastrpc-rdepends-acl` | `23d42fe` | fixed | fixed |
| BLD-2 | `usermod` of a missing `adb` user | `fix/arduino-image-drop-adb-usermod` | `58d4f94` | fixed | fixed |
| BLD-1 | no reliable build identification | `fix/arduino-image-buildinfo` | `0aad45b` | fixed (`/etc/buildinfo`) | fixed |
| LOG-1 | volatile journal, logs lost on reboot | `fix/persistent-journal` | `a3d9a68` | fixed | fixed |
| – | `require` for mandatory includes (upstream PR #11) | `fix/images-require-mandatory-includes-wrynose` | `8f56728` | built | built |

Notes:
- **USB-1 v1** listed both gadget units in `PartOf=`. adbd has `Conflicts=usb-gadget.service`, so every
  `systemctl restart android-tools-adbd` was rejected ("conflicting jobs"). v2 keeps `PartOf=` on adbd only.
- **NET-7** comes from NetworkManager shared mode (also used by upstream LmP `ncm-network.service`). The fix is a
  `dnsmasq-shared.d` drop-in that omits DHCP options 3 and 6 for `usb0` only. Drop it to keep the upstream behaviour.
- **LOG-1** is partly build configuration: `FILESYSTEM_PERMS_TABLES:remove` is in `meta-arduino-qcom/ci/base.yml`.
  Builds without that kas file keep the volatile `/var/log` and skip the journald drop-in.

## Open issues

| ID | Issue | Pri | Status |
|---|---|---|---|
| AUD-2 | ADSP publishes no QRTR services, APR never registers (no sound card, AUD-1) | P2+ | CP 1/12, KP 4/12 boots. Lead: stable GLINK `rmb()` fix missing from 6.18.52; not applied (decision) |
| DSP-1/2 | `adsprpcd_audiopd` fails every boot (ENOMEM); root PD mmap error | P2+/P3 | open |
| NET-6 | every board serves `10.11.99.0/29`; two boards on one host collide | P3 | design decision |
| VID-3 | `v4l2h264dec` rejects H.264 tagged BT.601 (`colorimetry=2:4:5:4`) | P3 | GStreamer v4l2 colorimetry; not root-caused |
| KGSL-1 | kgsl `WARN_ONCE` "I/O coherency is not supported" at probe | P3 | noise, no fix |
| ROUTER-1 | `arduino-router-serial` fails once per boot (router not ready) | P3 | upstream `arduino-router` (no sd_notify) |
| BLD-5 | `7zip:do_compile` link errors in 2 of 3 console builds | P3 | likely parallel-make race; not investigated |
| BOOT-2 | board B absent for 30 min after one `adb reboot` (baseline) | ? | not seen in 24 patched reboots |
| BOOT-1, PWR-1, KRN-1/2, BT-1, BLD-3, TOOL-1, SEC-1, SVC-1 | see `ISSUES.md` | P3/P4 | open, accepted or deferred |

USB-3 (board B not enumerated) was the host port: gone after moving the cable (12/12).

Not tested: audio playback, camera, DP display, MCU flashing, power-cut boots, A/B slot switching, video on the
console image (no GStreamer).

## Tools

Host side (`tools/`, run from the host):
- `bssh <ip> <cmd>`: root SSH to a board (empty password, host keys change per flash).
- `rebootloop.sh <ip> <adb-serial> <out-dir> <boots> [yes|no]`: reboots over SSH (Wi-Fi, independent of USB),
  waits for a new boot ID and for systemd to settle, records whether the host sees adb, and appends a
  `bootcheck.sh` snapshot per boot to `<out-dir>/reboot-loop.txt`; runs `collect.sh` after the first reboot.
- `clean_serial.py <in> <out>`: serial capture to plain text (CR/CRLF, escape codes, boot ROM bytes).
- `rpm_payload.py <rpm> <out.zst>`: extract an RPM payload (`zstd -dc out.zst | cpio -t`).

Board side (copy to `/root/validation/`):
- `collect.sh`: full read-only checklist with labelled sections and de-duplicated warnings.
- `bootcheck.sh`: one `key=value` snapshot per boot (startup time, failed units, APR/QRTR, ADSP crashes, UDC
  state, NCM MAC, time jumps, kernel warnings).
- `check-fixes.sh`: checks for the fixes above that `collect.sh` does not cover.
- `test-usb1-adbd-restart.sh`: USB-1 regression test, prints `RESULT: PASS|FAIL`. Run via `systemd-run`.
- `repro-usb1-hang.sh`: USB-1 reproducer for images without the fix.
- `test-video-roundtrip.sh`: HW H.264 encode → file → decode, frame count and a PNG frame (container image).

Typical run, with the board on Wi-Fi:

```bash
T=validation/tools; IP=192.168.x.y
$T/bssh $IP mkdir -p /root/validation
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $T/*.sh root@$IP:/root/validation/
$T/bssh $IP sh /root/validation/collect.sh > collect-firstboot.txt
$T/rebootloop.sh $IP <adb-serial> <out-dir> 12 yes
$T/bssh $IP sh /root/validation/check-fixes.sh > check-fixes.txt
$T/bssh $IP systemd-run --unit=usb1-test sh /root/validation/test-usb1-adbd-restart.sh
```

Board quirks: BusyBox has no `timeout` (the scripts poll instead) and needs `head -n N`; the dmesg ring overflows
during crash loops (use `journalctl -k`); run host tools as `env -u LD_LIBRARY_PATH adb|qdl …`.

## Evidence

Local image store `/mnt/Storage/arduino-uno-q-images/` (not in git), one folder per image with the flashed
artifacts, manifest, serial first boot and a `validation/` folder of logs and trial outputs:
- `validation-6cc3e50-arduino-console-image-imola-20261112163151/validation/ISSUES.md`: the living issue list.
- `validation-6cc3e50-arduino-container-image-imola-20261107184228/`
- `validation-34f89c5-arduino-console-image-imola-20261113121944-patched/`
- `validation-34f89c5-arduino-container-image-imola-20261113125103-patched/`
