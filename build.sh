#!/usr/bin/env bash
# Exports the playable builds of Shards Of Arcanum.
#
#   ./build.sh            # Mac + Android
#   ./build.sh mac        # just the Mac build   -> build/macos/Shards.zip
#   ./build.sh android    # just the Android APK -> build/android/Shards.apk
#   ./build.sh web        # itch.io HTML5 build  -> build/Shards_web.zip (index.html at zip root)
#
# Uses the presets in export_presets.cfg. Needs Godot's export templates installed
# (Editor > Manage Export Templates); Android also needs the Android SDK + Java set in
# Editor Settings > Export > Android. Save the project in the editor before running.
#
# Other Godot location:  GODOT=/path/to/Godot ./build.sh

set -euo pipefail

cd "$(dirname "$0")"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT" ]]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT="$(command -v godot)"
	else
		echo "Godot not found at $GODOT - run with GODOT=/path/to/Godot ./build.sh" >&2
		exit 1
	fi
fi

# Android playtest signing key (keep the same key so new APKs install over old ones).
KEYSTORE="$PWD/build/android/shards-playtest.keystore"
KEYSTORE_USER="shards"
KEYSTORE_PASSWORD="shardsplaytest"

build_mac() {
	echo "==> Mac build"
	mkdir -p build/macos
	"$GODOT" --headless --path . --export-release "macOS" build/macos/Shards.zip
	echo "    build/macos/Shards.zip"
}

build_android() {
	echo "==> Android build"
	if [[ ! -f "$KEYSTORE" ]]; then
		echo "    Missing signing key: $KEYSTORE" >&2
		exit 1
	fi
	mkdir -p build/android
	GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEYSTORE_USER" \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASSWORD" \
		"$GODOT" --headless --path . --export-release "Android" build/android/Shards.apk
	echo "    build/android/Shards.apk"
}

build_web() {
	echo "==> Web build (itch.io)"
	rm -rf build/web 2>/dev/null || true
	mkdir -p build/web
	"$GODOT" --headless --path . --export-release "Web" build/web/index.html
	rm -f build/Shards_web.zip
	# Zip the folder's CONTENTS so index.html sits at the root of the archive.
	(cd build/web && zip -qr ../Shards_web.zip . -x "*.DS_Store")
	echo "    build/Shards_web.zip  (upload to itch.io, tick 'This file will be played in the browser')"
}

case "${1:-all}" in
	mac|macos) build_mac ;;
	android) build_android ;;
	web) build_web ;;
	all) build_mac; build_android ;;
	*) echo "Usage: ./build.sh [mac|android|web|all]" >&2; exit 1 ;;
esac

echo "Done."
