<h1 align="center">F2FS Guardian</h1>

<hr>

<h2 align="center">Transparent, safety-gated F2FS maintenance for rooted Android 13–16 devices</h2>

<p align="center">
  <a href="https://github.com/lolokeksu/F2FS-Guardian/releases/tag/v1"><img alt="Release v1" src="https://img.shields.io/badge/release-v1-0ea5e9"></a>
  <a href="https://github.com/lolokeksu/F2FS-Guardian/actions/workflows/ci.yml"><img alt="Validate and build" src="https://github.com/lolokeksu/F2FS-Guardian/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Android 13–16" src="https://img.shields.io/badge/Android-13--16-3ddc84?logo=android&logoColor=white">
</p>

<p align="center">
  <img alt="Tested device" src="https://img.shields.io/badge/tested-Realme%20GT%20Neo%205%20SE-64748b">
  <img alt="Root APatch tested" src="https://img.shields.io/badge/root-APatch%20tested-f97316">
  <img alt="Filesystem F2FS" src="https://img.shields.io/badge/filesystem-F2FS-334155">
</p>

<p align="center">
  <img alt="POSIX shell runtime" src="https://img.shields.io/badge/runtime-POSIX%20shell-a3a3a3?logo=gnu-bash&logoColor=111827">
  <a href="LICENSE"><img alt="GPL-3.0-only" src="https://img.shields.io/badge/license-GPL--3.0--only-0ea5e9"></a>
  <img alt="No telemetry" src="https://img.shields.io/badge/telemetry-none-22c55e">
</p>

<p align="center"><a href="README_RU.md">Russian</a> · <a href="https://github.com/lolokeksu/F2FS-Guardian/releases">Release</a> · <a href="SECURITY.md">Security</a></p>
---

## What it is

F2FS Guardian monitors the real F2FS instance backing `/data` and may request a short, standard kernel garbage-collection session only when the filesystem is heavily occupied and the phone is in a verified safety window.

It is not a CPU/GPU tweak, an FPS booster, a UFS benchmark hack, or a generic “optimizer.” It cannot raise the physical maximum speed of storage. Its narrow purpose is to move expensive F2FS maintenance away from active use and make behavior more predictable when free space becomes constrained.

## Release status

**v1 is the first stable release by Lolokeksu.**

Hardware integration has been verified on:

| Device | Android | Root | `/data` | Result |
|---|---:|---|---|---|
| Realme GT Neo 5 SE | 13 / API 33 | APatch | F2FS, `dm-51` | Installer, self-test, daemon, status, queue and cancellation verified |

A real GC session was deliberately not forced during validation because storage usage was only 19% and the safety policy correctly reported no trigger. This is expected behavior, not an incomplete install.

## Why this design

F2FS already contains its own garbage collector. F2FS Guardian does not replace it. The module adds a conservative policy layer around the standard `gc_urgent` sysfs interface:

1. identify the exact `/data` F2FS instance;
2. read filesystem occupancy and segment statistics;
3. verify screen, charging, battery, temperature and block-I/O conditions;
4. request only a documented F2FS GC mode;
5. enforce a strict time limit;
6. restore the module-owned mode to `gc_urgent=0`;
7. stop immediately if safety conditions change or another tool takes ownership.

## Compatibility

### Required

- Android 13, 14, 15 or 16 — API 33–36;
- Magisk 20.4+, KernelSU or APatch;
- `/data` formatted as F2FS;
- writable `/sys/fs/f2fs/<instance>/gc_urgent`;
- readable `free_segments` and `dirty_segments` for automatic mode;
- readable block-device statistics for the low-I/O gate.

### Not required

- Zygisk;
- LSPosed;
- Termux for background operation;
- an external BusyBox module;
- a custom kernel, provided the stock kernel exposes the required F2FS nodes.

Android version alone does not establish compatibility. Vendor kernels can omit, rename or restrict F2FS interfaces. Run `self-test` after every ROM or kernel change.

## Safety invariants

F2FS Guardian v1:

- uses only `gc_urgent=2` for normal work and `gc_urgent=1` for a short critical session;
- never writes undocumented mode `4`;
- never changes `gc_urgent_sleep_time`;
- never changes permissions under `/sys`;
- refuses to overwrite a non-zero `gc_urgent` value owned by another tool;
- rechecks runtime safety while a session is active;
- restores only the mode it can prove it owns;
- stores configuration as validated integer data and never sources or evaluates it;
- includes no native executable, downloader, socket client, telemetry or remote code;
- makes no changes to SELinux, AVB, dm-verity, `boot`, `init_boot`, `vendor_boot`, `dtbo`, `vbmeta` or dynamic partitions;
- uses no volume-button installer menu.

## Default balanced policy

All safety conditions must be satisfied before either automatic or queued work can start.

| Condition | Default |
|---|---:|
| Check interval | 60 minutes |
| Minimum interval between successful sessions | 24 hours |
| Screen off time | at least 20 minutes |
| Charging required | yes |
| Minimum battery | 50% |
| Maximum battery temperature | 39.0 °C |
| Maximum observed block-I/O activity | 25 operations/second |

Normal maintenance requires both:

| Normal trigger | Default |
|---|---:|
| `/data` usage | at least 84% |
| Dirty segments | at least 256 |
| Kernel mode | `gc_urgent=2` |
| Maximum duration | 480 seconds |

Critical maintenance requires all three:

| Critical trigger | Default |
|---|---:|
| `/data` usage | at least 95% |
| Dirty segments | at least 128 |
| Free segments | no more than 96 |
| Kernel mode | `gc_urgent=1` |
| Maximum duration | 90 seconds |

These are conservative policy defaults, not universal F2FS constants. They are configurable.

## Installation

1. Back up important user data.
2. Download `F2FS-Guardian-v1.zip` from the GitHub Releases page.
3. Install it in Magisk, KernelSU or APatch Manager.
4. Reboot.
5. Run the self-test:

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh self-test
```

Expected success output:

```text
PASS: runtime prerequisites are available
```

6. Review status:

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status
```

A low storage-usage result such as `no trigger` is correct. Do not force a GC session merely to prove that the module can write to the kernel.

## Commands

```sh
# Full status
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status

# Evaluate trigger and safety conditions without starting work
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh check

# Queue safe maintenance; it still waits for every safety condition
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh request

# Cancel a queued request or stop a module-owned active session
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh cancel

# Show recent logs
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh logs

# Show persistent configuration
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh config

# Open the interactive shell menu
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh menu

# Apply a profile
su -c '/data/adb/modules/f2fs_guardian/f2fs-guardian.sh profile balanced'
su -c '/data/adb/modules/f2fs_guardian/f2fs-guardian.sh profile conservative'
su -c '/data/adb/modules/f2fs_guardian/f2fs-guardian.sh profile manual'

# Enable or disable the daemon through persistent config
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh enable
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh disable
```

Termux is optional. The daemon starts through the root manager and does not depend on Termux.

## Profiles

### Balanced

Default policy. Checks every 60 minutes, waits 24 hours between successful sessions, requires 20 minutes of screen-off time and uses the normal trigger at 84% usage with 256 dirty segments.

### Conservative

Checks every 120 minutes, waits 48 hours between successful sessions, requires 30 minutes of screen-off time, raises the normal trigger to 88% usage and 512 dirty segments, and shortens session limits.

### Manual

Disables automatic maintenance. Monitoring and queued manual requests remain available; queued work still obeys every safety condition.

## Configuration

Persistent user configuration:

```text
/data/adb/f2fs_guardian/config.conf
```

Factory defaults:

```text
/data/adb/modules/f2fs_guardian/config/default.conf
```

The parser accepts only a fixed whitelist of integer keys. Unknown keys and invalid values are ignored. The file is not executed as shell code. Persistent configuration survives module updates and is removed during a normal uninstall.

## Status interpretation

Common results:

| Output | Meaning |
|---|---|
| `gc_urgent: 0` | No module-owned forced GC is active |
| `Last run: never` | No maintenance session has completed yet |
| `no trigger` | Filesystem state does not justify maintenance |
| `waiting: not charging` | Trigger/request exists, but charging is required |
| `waiting: battery temperature...` | Safety window is blocked by temperature |
| `Manual request: queued` | Request persists until conditions are safe or it is cancelled |
| `manual maintenance cancelled` | Queued request was removed successfully |

Android `ps -A` may show the daemon only as `sh`. The authoritative PID is stored in:

```text
/data/adb/f2fs_guardian/state/daemon.lock/pid
```

## Logs and privacy

```text
/data/adb/f2fs_guardian/logs/guardian.log
/data/adb/f2fs_guardian/state/
```

The log is size-limited and rotated. The module does not transmit logs, device identifiers or telemetry. Review [SECURITY.md](SECURITY.md) for the security model and reporting process.

## Conflicts

Do not combine F2FS Guardian with another module, kernel manager or boot script that writes the same F2FS nodes. The module detects a non-zero pre-existing mode and refuses to start. If another tool changes `gc_urgent` during a session, F2FS Guardian records ownership loss and does not overwrite the external value.

Potentially conflicting categories:

- F2FS GC “optimizers”;
- kernel-manager profiles that write `/sys/fs/f2fs/*`;
- storage-tuning modules with their own background daemon;
- vendor or custom-kernel scripts that force GC modes.

## Uninstall and boot recovery

Normal removal through the root manager runs `uninstall.sh`, requests any active module-owned session to stop, restores the owned mode to `0`, and removes persistent configuration, state and logs.

If Android does not boot far enough to open the root manager, disable the module from an available root ADB shell:

```sh
adb shell su -c 'touch /data/adb/modules/f2fs_guardian/disable'
adb reboot
```

A recovery can use the same marker only if it can decrypt and mount `/data`.

## Known limitations

- No benefit is expected on `ext4`.
- A healthy, lightly occupied F2FS volume may never need a session.
- F2FS GC creates additional internal writes; repeated manual requests are not useful.
- The module does not repair filesystem corruption.
- Storage latency caused by thermal throttling, RAM pressure, app behavior, shader compilation or CPU/GPU scheduling is outside the module’s scope.
- Compatibility must be retested after a ROM or kernel update.

## Build and verification

```sh
./tests/static_checks.sh
./tests/mock_runtime_test.sh
./tests/mock_cancel_test.sh
./tests/mock_conflict_test.sh
./tests/mock_cli_state_test.sh
./scripts/build.sh
sha256sum -c dist/SHA256SUMS
```

The release workflow runs the same checks on GitHub Actions. Release archives are deterministic: file order and timestamps are normalized before ZIP creation.

## Repository layout

```text
module/                         Installable module source
module/lib/common.sh           Validated config and hardware checks
module/f2fs-guardian.sh        Daemon, policy engine and CLI
module/customize.sh            Installer validation
module/service.sh              Late-start entry point
module/uninstall.sh            Ownership-safe cleanup
scripts/build.sh               Deterministic release builder
tests/                          Static and mocked lifecycle tests
```

## Credits

- **Lolokeksu** — author and maintainer.
- Magisk, KernelSU and APatch projects — systemless module environments.
- Linux F2FS maintainers — filesystem and sysfs interfaces.
- Realme GT Neo 5 SE hardware validation was performed on Android 13 with APatch.

F2FS Guardian is an independent implementation. It does not contain code, binaries, telemetry or promotional actions from F2FS-SuperGC.

## License

Copyright © 2026 Lolokeksu.

Licensed under [GPL-3.0-only](LICENSE).

## Technical references

- Magisk module developer guide: <https://topjohnwu.github.io/Magisk/guides.html>
- KernelSU module guide: <https://kernelsu.org/guide/module.html>
- APatch module guide: <https://apatch.dev/apm-guide.html>
- Linux F2FS sysfs ABI: <https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-fs-f2fs>
- Android API levels: <https://developer.android.com/tools/releases/platforms>
