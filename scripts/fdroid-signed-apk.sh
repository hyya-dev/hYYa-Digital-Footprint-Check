#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Builds the F-Droid edition exactly as F-Droid does (a clean clone of the tag, unsigned, `-Pfdroid=true
# assembleRelease` in Android/), signs it with the upload key using apksigner from build-tools 34, and checks
# it before it is attached to the GitHub Release. F-Droid publishes our signed APK only when its own build
# from source matches it: F-Droid's docs say apksigner 35 or later makes APKs its tooling can't verify.
#
#   scripts/fdroid-signed-apk.sh v1.0.8-android28 [out dir]
#
# Prints the APK path, its SHA-256 and the signing certificate. Then attach it to the SAME tag's release:
#   gh release upload <tag> <apk>
# F-Droid downloads it from .../releases/download/v%v-android%c/hYYa-Digital-Footprint-Check-fdroid-%v-%c.apk
set -euo pipefail
trap 'echo "stopped at line $LINENO" >&2' ERR
TAG="${1:?pass the release tag, e.g. v1.0.8-android28}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${2:-$ROOT/build/fdroid}"
REPO="https://github.com/hyya-dev/hYYa-Digital-Footprint-Check.git"
CERT="b02c93bd33825a0c9609a51130cc662ef427b7051e019bbaac5d4e74fa99dce7"
SDK="$(grep '^sdk.dir=' "$ROOT/Android/local.properties" | cut -d= -f2-)"
BT34="$SDK/build-tools/34.0.0"
[ -x "$BT34/apksigner" ] || { echo "Install build-tools 34.0.0 first (sdkmanager \"build-tools;34.0.0\")"; exit 1; }
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# Two clean builds in different folders: the second stands in for F-Droid's own build.
build() {
  git clone -q "$REPO" "$WORK/$1"
  git -C "$WORK/$1" -c advice.detachedHead=false checkout -q "$TAG"
  echo "sdk.dir=$SDK" > "$WORK/$1/Android/local.properties"   # no signing key: unsigned, as F-Droid builds it
  (cd "$WORK/$1/Android" && ./gradlew -q --no-daemon --no-build-cache -Pfdroid=true assembleRelease)
  cp "$WORK/$1/Android/app/build/outputs/apk/release/app-release-unsigned.apk" "$WORK/$1.apk"
}
echo "• building twice from a clean clone of $TAG"; build ours; build fdroid
cmp -s "$WORK/ours.apk" "$WORK/fdroid.apk" || { echo "NOT reproducible: the two unsigned builds differ"; exit 1; }
"$BT34/zipalign" -c -p 4 "$WORK/ours.apk" >/dev/null || { echo "unsigned APK is not aligned"; exit 1; }

BADGING="$("$SDK/build-tools/36.0.0/aapt2" dump badging "$WORK/ours.apk" | grep -m1 "^package:" || true)"
VNAME="$(sed -E "s/.*versionName='([^']+)'.*/\1/" <<<"$BADGING")"; VCODE="$(sed -E "s/.*versionCode='([^']+)'.*/\1/" <<<"$BADGING")"
[ "$TAG" = "v$VNAME-android$VCODE" ] || { echo "tag $TAG doesn't match the build ($VNAME, $VCODE)"; exit 1; }
APK="$OUT/hYYa-Digital-Footprint-Check-fdroid-$VNAME-$VCODE.apk"

echo "• reproducible; signing with apksigner 34"
# The upload key, read from the folder named in local.properties; passwords go through the environment only.
DIR="$(grep '^hyya.signingDir=' "$ROOT/Android/local.properties" | cut -d= -f2-)"
prop() { grep "^$1=" "$DIR/keystore.properties" | cut -d= -f2-; }
KS="$DIR/$(basename "$(prop storeFile)")"
KS_PASS="$(prop storePassword)" KEY_PASS="$(prop keyPassword)" \
  "$BT34/apksigner" sign --ks "$KS" --ks-key-alias "$(prop keyAlias)" --ks-pass env:KS_PASS --key-pass env:KEY_PASS \
  --out "$APK" "$WORK/ours.apk"
rm -f "$APK.idsig"

"$BT34/apksigner" verify --print-certs "$APK" 2>/dev/null | grep -c "SHA-256 digest: $CERT" >/dev/null || { echo "wrong signing certificate"; exit 1; }
# F-Droid's own check: copy our signature onto its unsigned build and verify it.
python3 -m venv "$WORK/venv"; "$WORK/venv/bin/pip" -q --disable-pip-version-check install apksigcopier
# apksigcopier calls apksigner itself: give it the same version 34.
PATH="$BT34:$PATH" "$WORK/venv/bin/apksigcopier" compare "$APK" --unsigned "$WORK/fdroid.apk"
echo "apksigcopier compare: match (our signature verifies on F-Droid's unsigned build)"
echo "APK: $APK"
echo "SHA-256: $(shasum -a 256 "$APK" | cut -d' ' -f1)"
echo "Certificate: $CERT"
echo "apksigner: $("$BT34/apksigner" --version) (build-tools 34.0.0)"
