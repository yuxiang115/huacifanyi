#!/usr/bin/env bash
# Sync this repo to a Mac over SSH, then test / build / run it there.
#
#   HUACI_MAC=user@host scripts/mac-build.sh [test|build|run]
#
# The Mac copy (default ~/workspace/huaci) is overwritten on every sync: edit here, not there.
#
# Signing over SSH: the login keychain is locked inside SSH sessions, so certificate signing from
# Configs/Local.xcconfig fails with errSecInternalComponent. Either unlock it on the Mac first
# (`security unlock-keychain ~/Library/Keychains/login.keychain-db`, you type the password), or set
# HUACI_ADHOC=1 to sign ad-hoc for this build (Accessibility must then be re-granted after each build).
set -euo pipefail

: "${HUACI_MAC:?set HUACI_MAC=user@host}"
REMOTE_DIR="${HUACI_REMOTE_DIR:-workspace/huaci}"
ACTION="${1:-test}"
APP="build/DerivedData/Build/Products/Debug/Huaci.app"

cd "$(dirname "$0")/.."

echo "==> Syncing to $HUACI_MAC:~/$REMOTE_DIR"
tar -czf - --exclude=.git --exclude=Huaci.xcodeproj --exclude=build . |
  ssh "$HUACI_MAC" "mkdir -p '$REMOTE_DIR' && cd '$REMOTE_DIR' && rm -rf Huaci HuaciTests && tar -xzf - 2>/dev/null"

remote() {
  ssh "$HUACI_MAC" "export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH; set -o pipefail; cd '$REMOTE_DIR' && $1"
}

# xcodebuild -quiet still prints an AppIntents notice on every build; drop it (sed keeps the exit status).
QUIET_FILTER="2>&1 | sed '/appintentsmetadataprocessor/d'"
# Evaluated on the Mac (escaped \$), so it picks the Mac's own architecture.
DESTINATION="\"platform=macOS,arch=\$(uname -m)\""
# Command-line build settings override the xcconfig values.
SIGNING=""
if [ "${HUACI_ADHOC:-0}" = 1 ]; then
  SIGNING="HUACI_CODE_SIGN_IDENTITY=- HUACI_DEVELOPMENT_TEAM="
fi

remote "xcodegen generate --quiet"

case "$ACTION" in
  test)
    echo "==> Testing"
    remote "xcodebuild test -quiet -project Huaci.xcodeproj -scheme Huaci -destination $DESTINATION \
      -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO $QUIET_FILTER"
    echo "==> Tests passed"
    ;;
  build | run)
    echo "==> Building (Debug)"
    remote "xcodebuild build -quiet -project Huaci.xcodeproj -scheme Huaci -configuration Debug \
      -destination $DESTINATION -derivedDataPath build/DerivedData $SIGNING $QUIET_FILTER"
    echo "==> Built ~/$REMOTE_DIR/$APP"
    if [ "$ACTION" = run ]; then
      # Wait for the old instance to exit, otherwise `open` fails with -600.
      remote "pkill -x Huaci; while pgrep -qx Huaci; do sleep 0.2; done; open '$APP'"
      echo "==> Launched"
    fi
    ;;
  *)
    echo "unknown action: $ACTION (use test, build or run)" >&2
    exit 2
    ;;
esac
