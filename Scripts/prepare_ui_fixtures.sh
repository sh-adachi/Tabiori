#!/bin/bash
set -euo pipefail
# Usage: bash Scripts/prepare_ui_fixtures.sh <simulator UUID or booted>
# Adds only a named test folder to Files and one synthetic image to Photos.
script_directory="$(cd "$(dirname "$0")" && pwd)"
project_directory="$(dirname "$script_directory")"
simulator_id="${1:-booted}"
fixture_directory="$project_directory/.build/UITestFixtures"
swift -module-cache-path "$project_directory/.build/fixture-module-cache" \
  "$script_directory/render_ui_fixtures.swift" "$fixture_directory"
storage_container="$(xcrun simctl get_app_container "$simulator_id" com.apple.DocumentsApp groups | awk -F '\t' '$1 == "group.com.apple.FileProvider.LocalStorage" {print $2}')"
test -n "$storage_container"
fixture_destination="$storage_container/File Provider Storage/Tabiori-UITests"
mkdir -p "$fixture_destination"
cp "$fixture_directory/Tabiori-Test-Ticket.pdf" "$fixture_destination/Tabiori-Test-Ticket.pdf"
cp "$fixture_directory/Tabiori-Test-Photo.jpg" "$fixture_destination/Tabiori-Test-Photo.jpg"
xcrun simctl addmedia "$simulator_id" "$fixture_directory/Tabiori-Test-Photo.jpg"
printf 'Prepared Files folder Tabiori-UITests and a Photos image for %s\n' "$simulator_id"
