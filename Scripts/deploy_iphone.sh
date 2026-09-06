#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
    echo "Usage: bash Scripts/deploy_iphone.sh <iPhone UDID>" >&2
    echo "Find the connected iPhone UDID with: xcrun xctrace list devices" >&2
    exit 2
fi

tabiori_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tabiori_device="$1"
tabiori_build="$tabiori_root/.build/device"

xcodebuild \
    -project "$tabiori_root/Tabiori.xcodeproj" \
    -scheme Tabiori \
    -configuration Debug \
    -destination "id=$tabiori_device" \
    -derivedDataPath "$tabiori_build" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build

xcrun devicectl device install app \
    --device "$tabiori_device" \
    "$tabiori_build/Build/Products/Debug-iphoneos/Tabiori.app"

xcrun devicectl device process launch \
    --device "$tabiori_device" \
    dev.adachi.tabiori
