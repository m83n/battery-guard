# BatteryGuard

Menu bar app + root service that limits charge and pauses charging when hot, for Intel MacBooks with SMC key `BCLM`.

- `src/BatteryGuard.swift`: menu bar app; installs/removes the service via `install-helper.sh` with admin password (AppleScript).
- `src/battery-guard.sh`: service logic, runs as root every 60 s.
- `src/install-helper.sh`: root installer; also removes the old manual install (`com.local.battery-guard*`).
- `src/smcctl.c`: minimal SMC key read/write.
- Build: `./build.sh` (x86_64, macOS 11+, ad-hoc signed). Bump `VERSION` in build.sh on every release; `SERVICE_VERSION` is a hash of the service sources, so any change there makes the app ask to reinstall the service.

Rules:
- UI strings in Russian; no typographic symbols (dashes, arrows, ellipsis) except the degree sign.
- The thresholds file is user-writable and read by root: keep strict integer and range validation.
- SMC charge (StateOfCharge) reads 3-4% lower than macOS percent; see battery-guard.sh.
- Do not run downloaded third-party binaries; tools here are written from scratch.
