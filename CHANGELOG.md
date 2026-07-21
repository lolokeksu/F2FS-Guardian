# Changelog

## v1.1 — 2026-07-21

Stable compatibility and interface update by **Lolokeksu**.

### Compatibility

- Added multi-source `/data` filesystem detection for KernelSU Next and isolated installer environments.
- Unknown installer results no longer falsely abort installation; strict runtime verification remains mandatory.
- Added exact `/data` `major:minor` to block-device and F2FS-instance resolution.
- Removed the fallback that selected the first available F2FS instance.
- Added a boot-completion and `/data` mount wait before daemon startup.

### Interface

- Added persistent Russian and English terminal menus with in-menu language switching.
- Added short commands: `f2g`, `f2status`, `f2check`, `f2request`, `f2cancel`, `f2logs`, `f2doctor`, `f2start`, `f2stop`, `f2profile` and `f2lang`.
- Added localized status, condition checks and compatibility diagnostics.
- Added the `doctor` command for filesystem, device, sysfs, battery, screen and root-manager diagnostics.
- Clarified that `f2start` enables automatic maintenance and does not force an immediate GC session.

### Manager Action fix

- Fixed the endless `Invalid selection` loop when SukiSU or KernelSU Manager Action provides no interactive stdin.
- Manager Action now opens the menu only with a real TTY.
- Non-interactive Action windows show a localized status dashboard and exit cleanly.

### Safety and testing

- Kept the v1 GC modes, thresholds, ownership rules and bounded-session policy unchanged.
- Added EOF regression, language persistence and short-command tests.
- Added synchronized English/Russian documentation checks.
- Updated deterministic build and generic release automation for v1.1.

## v1 — 2026-07-19

First stable release by **Lolokeksu**.

### Core

- Added Android 13–16 and F2FS-only installation gates.
- Added exact `/data` F2FS instance discovery.
- Added conservative automatic policy based on usage, dirty segments and free segments.
- Added documented `gc_urgent=2` normal mode and short `gc_urgent=1` critical mode.
- Added strict session limits and ownership-safe restoration to `gc_urgent=0`.
- Added detection of pre-existing and mid-session conflicts.

### Safety

- Added screen-off, charging, battery, thermal and block-I/O gates.
- Added minimum interval between successful sessions.
- Added active-session condition rechecks and cancellation.
- Added whitelist-based, non-executable configuration parsing.
- Added bounded local logging.
- Added a shell-only package with no network client, native binary, telemetry or boot partition changes.

### User interface

- Added status, readiness check, queue, cancellation, profiles, logs, enable/disable, self-test and interactive menu commands.
- Added clear `Last run: never` output before the first session.
- Fixed stale `Last decision: manual maintenance queued` after cancellation.
- Added distinct status for queued cancellation and active-session cancellation.

### Packaging and documentation

- Set author to Lolokeksu.
- Added deterministic ZIP builds and SHA-256 checksums.
- Added GitHub Actions release automation.
- Added static checks and four mocked lifecycle/regression tests.
- Rebuilt the main README around compatibility, safety, usage, troubleshooting, recovery and reproducibility.
- Added Russian GitHub and 4PDA documentation.
