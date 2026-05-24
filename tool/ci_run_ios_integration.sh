#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

device_id="$(
  xcrun simctl list devices available -j | python3 -c '
import json
import sys

data = json.load(sys.stdin)
candidates = []

for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        name = device.get("name", "")
        udid = device.get("udid") or device.get("UDID")
        if udid and "iPhone" in name and device.get("isAvailable", True):
            candidates.append((runtime, name, udid))

if not candidates:
    raise SystemExit("No available iPhone simulator found.")

runtime, name, udid = candidates[-1]
print(udid)
print(f"Selected {name} ({runtime})", file=sys.stderr)
'
)"

xcrun simctl boot "$device_id" || true
xcrun simctl bootstatus "$device_id" -b

cd "$repo_root/example"
flutter test integration_test/asset_workflow_test.dart -d "$device_id"
