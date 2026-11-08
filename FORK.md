# jrosa-digiwest/meta-arduino fork

This fork of [arduino/meta-arduino](https://github.com/arduino/meta-arduino)
is used to build, fix and test images for the Arduino UNO Q (`imola`) on the
`wrynose` branch. This file only exists on fork branches.

## Rules for upstream pull requests, issues and comments

**Never open a pull request, issue or comment in `arduino/meta-arduino`, or
in any other Arduino-owned repository, unless both of these are true:**

1. The person working with the agent has **explicitly asked** for it in the
   current session. A request to fix, commit or push is not a request to
   open a PR.
2. The change has been **validated by the AI agent** (built, and tested on a
   board where it affects runtime behaviour) **and by the person who asked**
   for it. They have seen what will be submitted, including the PR title and
   description, and approved it.

If either is missing, stop after committing and pushing to the fork, and ask.
This also applies to the other upstream projects this fork builds on
(Qualcomm `meta-qcom*`, OpenEmbedded, kas, etc.).

Issues and PRs inside this fork (`jrosa-digiwest/meta-arduino`) are fine to
use for tracking.

## Branches

| Branch | Base | Purpose |
|---|---|---|
| `fix/<topic>`, `feat/<topic>` | `origin/wrynose` | One topic each. An upstream PR, if one is ever approved, is opened from here. |
| `docs/<topic>` | `origin/master` or `origin/wrynose` | Documentation topics. Ones based on `master` are not merged into `unoq/wrynose`. |
| `docs/fork-workflow` | `origin/wrynose` | This file. Fork-only, never sent upstream. |
| `unoq/wrynose` | `origin/wrynose` | Integration: every `wrynose` topic merged together. Build, flash and test from here. |

Remotes: `origin` = arduino/meta-arduino, `fork` = jrosa-digiwest/meta-arduino.

### Workflow

1. Start new work on a topic branch from `origin/wrynose`. Never commit
   directly to `unoq/wrynose` or to the fork's `wrynose`.
2. Commit following [AGENTS.md](AGENTS.md): one topic per commit, and the
   `Assisted-by` / `Signed-off-by` trailers in that order.
3. Merge the topic into `unoq/wrynose` (`git merge --no-ff <topic>`), build,
   and test.
4. Push both branches to `fork`.
5. To pick up upstream changes, merge `origin/wrynose` into `unoq/wrynose`.
   Topics merged upstream then drop out of the diff on their own.
6. Prefer upstream fixes (Arduino, Qualcomm, OpenEmbedded) over local
   patches: check for existing commits, PRs and issues first.

## Build

kas-container, with the storage location and kas image set as in
[DEVELOPERS.md](DEVELOPERS.md):

```bash
export BASE_DIR=/path/to/storage            # sources, build, downloads, sstate-cache
export KAS_WORK_DIR="$BASE_DIR/sources" KAS_BUILD_DIR="$BASE_DIR/build"
export DL_DIR="$BASE_DIR/downloads" SSTATE_DIR="$BASE_DIR/sstate-cache"
# Same image as .github/workflows/compile.yml: the released kas 5.5 image
# lacks ccache, which meta-qcom's CI config requires.
export KAS_CONTAINER_IMAGE="ghcr.io/siemens/kas/kas@sha256:3f3d3257e8d4ca3adfcb2e0025e6da24339fb8d68a6999ca36c37381351582d5"

kas-container --runtime-args "--memory=28g" build meta-arduino-qcom/ci/imola.yml --target arduino-console-image
```

- `ci` must be a symlink to `meta-arduino-qcom/ci` (it is untracked, so new
  worktrees need it too).
- Set `--memory` a few GB below the host's RAM.
- To keep going after errors, pass bitbake's `-k` after `--`
  (`... build ... -- -k`). kas's own `-k` means something else.

Output: `$BASE_DIR/build/tmp/deploy/images/imola/arduino-console-image-imola.rootfs.qcomflash.tar.gz`.

## Flash and test on a board

- Flash: extract the `.qcomflash.tar.gz`, put the board in EDL (short the EDL
  pins, connect USB-C), then run
  `qdl --storage emmc prog_firehose_ddr.elf rawprogram0.xml patch0.xml`.
- Host tools: if `LD_LIBRARY_PATH` points at another libusb (some camera SDKs
  do this), `qdl` can segfault. Run host USB tools as
  `env -u LD_LIBRARY_PATH qdl ...` / `env -u LD_LIBRARY_PATH adb ...`.
- Console image login: `root` with no password, over serial or `adb shell`.
- Serial captures use bare CR line endings and terminal escape codes. Convert
  them before grepping:
  `tr '\r' '\n' < log.txt | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' > log.clean.txt`.
- Tests that restart `android-tools-adbd` drop the adb connection. Run them on
  the board as a transient unit (`systemd-run --unit=<name> <script>`), and put
  temporary unit overrides in `/run/systemd/system/` so that a reboot clears
  them.

## Known issues tracked in this fork

- [#1](https://github.com/jrosa-digiwest/meta-arduino/issues/1): restarting
  `android-tools-adbd` can hang forever in `rmdir functions/acm.GS0` while
  `arduino-router-serial` (`socat`) holds `/dev/ttyGS0`.
