# Changelog

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
