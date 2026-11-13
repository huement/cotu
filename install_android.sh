#!/usr/bin/env bash
# Installs the Android build on a phone over USB (adb) and starts the game.
#
#   ./install_android.sh              # install build/android/Shards.apk and launch it
#   ./install_android.sh --no-launch  # install only
#   ./install_android.sh path/to.apk  # install a different APK
#
# Phone setup (once): Settings > About phone > tap "Build number" 7 times, then
# Settings > Developer options > turn on "USB debugging". Plug in the phone and accept
# the "Allow USB debugging?" prompt on its screen.
#
# Several phones / emulators plugged in: ANDROID_SERIAL=<id from `adb devices`> ./install_android.sh

set -euo pipefail

cd "$(dirname "$0")"

PACKAGE="com.shardsgame.shards"          # package/unique_name in export_presets.cfg
ACTIVITY="com.godot.game.GodotApp"       # Godot 4's Android launcher activity

APK="build/android/Shards.apk"
LAUNCH=1
for arg in "$@"; do
	case "$arg" in
		--no-launch) LAUNCH=0 ;;
		-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
		*) APK="$arg" ;;
	esac
done

# --- find adb (PATH, then the usual Android SDK spots on a Mac) -------------------
ADB="$(command -v adb || true)"
if [[ -z "$ADB" ]]; then
	for candidate in \
		"${ANDROID_HOME:-}/platform-tools/adb" \
		"${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
		"$HOME/Library/Android/sdk/platform-tools/adb"; do
		if [[ -x "$candidate" ]]; then ADB="$candidate"; break; fi
	done
fi
if [[ -z "$ADB" ]]; then
	echo "adb not found. Install it with:  brew install android-platform-tools" >&2
	echo "(or add your Android SDK's platform-tools folder to PATH)" >&2
	exit 1
fi

if [[ ! -f "$APK" ]]; then
	echo "No APK at $APK - build it first with ./build.sh android" >&2
	exit 1
fi

# --- check a phone is connected and authorised ------------------------------------
"$ADB" start-server >/dev/null
DEVICES="$("$ADB" devices | tail -n +2 | grep -v '^$' || true)"
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
	DEVICES="$(echo "$DEVICES" | grep "^$ANDROID_SERIAL" || true)"
fi
if [[ -z "$DEVICES" ]]; then
	echo "No phone found. Plug it in with USB debugging on (see the top of this script)." >&2
	exit 1
fi
if echo "$DEVICES" | grep -q "unauthorized"; then
	echo "The phone hasn't allowed this computer yet - unlock it and tap Allow on the USB debugging prompt." >&2
	exit 1
fi
COUNT="$(echo "$DEVICES" | grep -c "device$" || true)"
if [[ -z "${ANDROID_SERIAL:-}" && "$COUNT" -gt 1 ]]; then
	echo "More than one device connected:" >&2
	echo "$DEVICES" >&2
	echo "Pick one:  ANDROID_SERIAL=<id> ./install_android.sh" >&2
	exit 1
fi
SERIAL="$(echo "$DEVICES" | grep "device$" | head -1 | cut -f1)"
MODEL="$("$ADB" -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
echo "==> Installing $(basename "$APK") on ${MODEL:-$SERIAL}"

# --- install (replace the existing copy, keeping its saves) ------------------------
set +e
OUTPUT="$("$ADB" -s "$SERIAL" install -r "$APK" 2>&1)"
STATUS=$?
set -e
echo "$OUTPUT"

if [[ $STATUS -ne 0 ]] || ! echo "$OUTPUT" | grep -q "Success"; then
	if echo "$OUTPUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE\|signatures do not match"; then
		echo
		echo "The copy on the phone was signed with a different key, so it can't be updated."
		read -r -p "Uninstall it first? This DELETES its saves and characters on the phone. [y/N] " answer
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			"$ADB" -s "$SERIAL" uninstall "$PACKAGE"
			"$ADB" -s "$SERIAL" install "$APK"
		else
			echo "Not installed." >&2
			exit 1
		fi
	else
		echo "Install failed." >&2
		exit 1
	fi
fi

# --- launch -----------------------------------------------------------------------
if [[ $LAUNCH -eq 1 ]]; then
	echo "==> Starting the game"
	"$ADB" -s "$SERIAL" shell am start -n "$PACKAGE/$ACTIVITY" >/dev/null \
		|| "$ADB" -s "$SERIAL" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null
fi

echo "Done."
