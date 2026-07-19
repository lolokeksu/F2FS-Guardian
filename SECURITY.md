# Security policy

## Supported version

Security fixes are provided for the latest tagged release of F2FS Guardian maintained by Lolokeksu.

## Security properties

The release module contains shell scripts and text files only. It contains no ELF/native binary, network client, telemetry component, certificate, hosts file, SELinux policy, system overlay, or boot-image payload.

The persistent configuration is parsed as data and is never sourced or evaluated as shell code.

## Reporting

Open a private GitHub security advisory in the repository when available. Include the module version, root manager, Android API, kernel version, relevant log lines, and exact reproduction steps. Do not include personal files or application data.

## Verification

Run:

```sh
./tests/static_checks.sh
./tests/mock_runtime_test.sh
./tests/mock_cancel_test.sh
./tests/mock_conflict_test.sh
./tests/mock_cli_state_test.sh
./scripts/build.sh
sha256sum -c dist/SHA256SUMS
```
