#!/usr/bin/env bash
#
# Runs the integration suite with the credentials it needs to sign itself in.
#
#   tool/run_integration_tests.sh [device-id]
#
# With no device id, Flutter picks the connected device itself (and prompts if
# there is more than one).
#
# Two things this exists to get right, every time:
#
#   * `--dart-define-from-file=.env` hands the git-ignored credentials to the
#     test as compile-time constants. The file is passed by *path*, so the key
#     is never expanded into this shell, into `flutter`'s argv, or into any log
#     — unlike a `--dart-define=PLANE_API_KEY=$KEY`, which would be readable in
#     `ps` for the length of the run.
#   * `--no-uninstall` stops `flutter test` from uninstalling the app when the
#     run ends. It would take the app's stored session with it; the suite
#     re-seeds itself, so this is now only about not churning the install.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly ENV_FILE='.env'

if [[ ! -f "$ENV_FILE" ]]; then
  cat >&2 <<EOF
error: $ENV_FILE not found in $(pwd)

The integration suite signs itself in, and reads the credentials from there.
Create it with:

  PLANE_BASE_URL=https://your-plane-instance
  PLANE_API_KEY=<api key>

It is git-ignored on purpose — do not commit it, and do not paste the key into
a test file.
EOF
  exit 1
fi

# Checked here rather than left to Dart: a missing key would otherwise surface
# as seven identical test failures a full APK build later.
for required in PLANE_BASE_URL PLANE_API_KEY; do
  if ! grep -qE "^[[:space:]]*${required}=[^[:space:]]" "$ENV_FILE"; then
    echo "error: $ENV_FILE does not define $required" >&2
    exit 1
  fi
done

args=(
  test integration_test/app_test.dart
  --dart-define-from-file="$ENV_FILE"
  --no-uninstall
)

readonly DEVICE="${1-}"
if [[ -n "$DEVICE" ]]; then
  args+=(-d "$DEVICE")
fi

# The APK left installed at this point is the TEST binary: its entrypoint is the
# harness, not the app, so launching it by hand just sits on the splash screen
# looking like a hang. Put the real app back, so the device is usable after a
# run instead of quietly broken.
restore_app() {
  local apk='build/app/outputs/flutter-apk/app-debug.apk'
  if [[ ! -f "$apk" ]]; then
    echo >&2
    echo "note: the test binary is still installed on the device." >&2
    echo "      Restore the app with: flutter build apk --debug && adb install -r $apk" >&2
    return
  fi
  echo
  echo 'Restoring the app build over the test binary...'
  local adb_args=()
  [[ -n "$DEVICE" ]] && adb_args=(-s "$DEVICE")
  adb "${adb_args[@]}" install -r "$apk" >/dev/null 2>&1 \
    && echo 'Done — the app on the device is the app again.' \
    || echo 'warning: could not reinstall the app build.' >&2
}
trap restore_app EXIT

flutter "${args[@]}"
