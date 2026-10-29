#!/usr/bin/env bash
#
# Builds BetterCapture from source and installs it to /Applications. See README.md.

set -euo pipefail

cd "$(dirname "$0")/.."

installed_app=/Applications/BetterCapture.app
built_app=DerivedData/Build/Products/Release/BetterCapture.app

signing_teams() {
  security find-identity -v -p codesigning |
    sed -nE 's/.*"(Apple Development: [^"]*)".*/\1/p' |
    while read -r identity; do
      security find-certificate -c "$identity" -p | openssl x509 -noout -subject
    done |
    sed -nE 's/.*OU ?= ?([A-Z0-9]{10}).*/\1/p' |
    sort -u
}

designated_requirement() {
  codesign -d -r- "$1" 2>/dev/null || true
}

team=${DEVELOPMENT_TEAM:-$(signing_teams || true)}

case $team in
  *$'\n'*)
    printf 'You can sign with more than one team, so set DEVELOPMENT_TEAM to one of:\n%s\n' "$team" >&2
    exit 1
    ;;
esac

if [ -n "$team" ]; then
  echo "Signing with team $team"
  signing=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$team")
else
  echo "No Apple Development signing identity found, so signing ad hoc: macOS will ask for permissions again after every install" >&2
  signing=(CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO)
fi

xcodebuild build -quiet \
  -project BetterCapture.xcodeproj -scheme BetterCapture -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath DerivedData \
  ARCHS="$(uname -m)" "${signing[@]}"

pkill -x -U "$UID" BetterCapture || true
while pgrep -xq -U "$UID" BetterCapture; do sleep 1; done

# macOS keeps showing a permission as granted after the app's signature changes, though it no longer applies.
if [ "$(designated_requirement "$installed_app")" != "$(designated_requirement "$built_app")" ]; then
  bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$built_app/Contents/Info.plist")
  tccutil reset All "$bundle_id"
fi

rm -rf "$installed_app"
ditto "$built_app" "$installed_app"
open "$installed_app"
