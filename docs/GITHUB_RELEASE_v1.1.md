# F2FS Guardian v1.1

Stable compatibility and interface update by **Lolokeksu**.

## Main changes

- Multi-source `/data` filesystem detection for KernelSU Next and isolated installer environments.
- Unknown installer results no longer produce a false `/data must use F2FS` abort.
- Strict post-boot verification still prevents kernel writes unless F2FS and all required sysfs nodes are confirmed.
- Exact `/data` block-device and F2FS-instance resolution.
- Bilingual Russian/English terminal menu with persistent language selection.
- Short commands including `f2g`, `f2status`, `f2doctor`, `f2start`, `f2stop`, `f2profile` and `f2lang`.
- New detailed `doctor` diagnostics.
- Boot-completion wait before daemon startup.
- Fixed the endless `Invalid selection` loop in non-interactive SukiSU and KernelSU Manager Action windows.

## Manager Action

A Manager Action window without a real TTY now shows a localized status dashboard and exits cleanly. Use a real terminal for the interactive menu:

```sh
f2g
```

## Safety

The F2FS maintenance policy is unchanged from v1:

- documented `gc_urgent=2` normal mode;
- short `gc_urgent=1` critical mode;
- screen-off, charging, battery, temperature and I/O gates;
- strict session limits;
- ownership-safe restoration to `gc_urgent=0`;
- no network code, telemetry, native binaries, SELinux changes or boot-partition writes.

## Installation

Install `F2FS-Guardian-v1.1.zip` through Magisk, KernelSU, KernelSU Next, SukiSU-compatible environments or APatch Manager. Reboot and run:

```sh
f2doctor
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh self-test
```

KernelSU Next, SukiSU and device-specific environments still require runtime verification after installation.

Verify `SHA256SUMS` before installation.
