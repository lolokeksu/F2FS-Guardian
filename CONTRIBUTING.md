# Contributing

Contributions must preserve the module's conservative safety model.

Before opening a pull request:

```sh
./scripts/test.sh
./scripts/build.sh
sha256sum -c dist/SHA256SUMS
```

Requirements:

- POSIX/BusyBox-compatible shell only in the installable module;
- no network access, telemetry or downloaded code;
- no undocumented F2FS mode values;
- no permanent sysfs permission changes;
- no modification of boot, init_boot, vendor_boot, vbmeta or dtbo;
- every behavior change must include a mocked regression test;
- compatibility claims require exact device, Android API, root manager and kernel evidence.
