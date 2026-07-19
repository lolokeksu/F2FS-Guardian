# F2FS Guardian v1

First stable release by **Lolokeksu**.

## Highlights

- Conservative F2FS maintenance policy for Android 13–16.
- Magisk, KernelSU and APatch manager installation.
- Exact `/data` F2FS instance discovery.
- Screen-off, charging, battery, thermal and block-I/O safety gates.
- Documented `gc_urgent=2` normal mode and short `gc_urgent=1` critical mode.
- Ownership-safe restoration to `gc_urgent=0`.
- Queue, cancellation, profiles, status, logs and self-test commands.
- No native binaries, network code, telemetry, SELinux changes or boot-partition writes.

## Hardware validation

Verified on Realme GT Neo 5 SE, Android 13 / API 33, APatch, F2FS `/data` instance `dm-51`. Installation, runtime self-test, daemon startup, status, queue and cancellation were confirmed. A real GC session was not forced at 19% storage usage.

## Installation

Install `F2FS-Guardian-v1.zip` in Magisk, KernelSU or APatch Manager, reboot, then run:

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh self-test
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status
```

Verify `SHA256SUMS` before installation.
