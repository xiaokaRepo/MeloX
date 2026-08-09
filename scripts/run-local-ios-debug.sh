#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data_path="${project_root}/build/LocalDebugDerivedData"
debug_project_path="${project_root}/MeloXLocalDebug.xcodeproj"
simulator_id="${MELOX_SIMULATOR_ID:-}"

if [[ -z "${simulator_id}" ]]; then
    simulator_id="$(xcrun simctl list devices | awk -F '[()]' '
        /^-- iOS / { in_ios_section = 1; next }
        /^--/ { in_ios_section = 0 }
        in_ios_section && /Booted/ { print $2; exit }
    ')"
fi

if [[ -z "${simulator_id}" ]]; then
    printf '%s\n' "No booted iOS Simulator found. Boot an iOS 26.x simulator in Xcode, then run this script again." >&2
    exit 2
fi

device_name="$(xcrun simctl list devices | awk -v id="${simulator_id}" -F '[()]' '$2 == id { print $1; exit }' | sed 's/[[:space:]]*$//')"
printf 'Building MeloX for %s with serialized target builds...\n' "${device_name:-${simulator_id}}"

rm -rf "${debug_project_path}"
cp -R "${project_root}/MeloX.xcodeproj" "${debug_project_path}"

# Xcode 26.3 can link the iOS and watchOS builds of this local package together.
# The generated project retains the iOS app and Widget but omits the Watch target.
perl -0pi -e 's/^\t\t\t\tB1000000000000000000000C \/\* Embed Watch Content \*\/,\n//m' "${debug_project_path}/project.pbxproj"
perl -0pi -e 's/^\t\t\t\tB1000000000000000000000E \/\* PBXTargetDependency \*\/,\n//m' "${debug_project_path}/project.pbxproj"

xcodebuild \
    -project "${debug_project_path}" \
    -scheme MeloX \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=${simulator_id}" \
    -derivedDataPath "${derived_data_path}" \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM= \
    build

app_path="${derived_data_path}/Build/Products/Debug-iphonesimulator/MeloX.app"
xcrun simctl install "${simulator_id}" "${app_path}"
xcrun simctl launch --terminate-running-process "${simulator_id}" azki.moye.MeloX
printf 'MeloX launched on %s.\n' "${device_name:-${simulator_id}}"
