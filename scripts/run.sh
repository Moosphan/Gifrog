#!/usr/bin/env bash
# run.sh - Build Gifrog.app and launch it
#
# Usage:
#   ./scripts/run.sh [options]
#
# Options:
#   --debug          Build in debug mode (default: release)
#   --no-kill        Don't kill a running Gifrog instance before launching
#   --env KEY=VALUE  Set an environment variable for the launched app (repeatable)
#   --help           Show this help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Gifrog"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

# defaults
BUILD_CONFIG="debug"
OPT_KILL=true
LAUNCH_ENV=()

# argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   BUILD_CONFIG="debug"; shift ;;
    --no-kill) OPT_KILL=false;       shift ;;
    --env)     LAUNCH_ENV+=("$2");   shift 2 ;;
    --help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# kill existing instance
if $OPT_KILL && pgrep -xq "$APP_NAME" 2>/dev/null; then
  echo "-> Stopping running $APP_NAME..."
  pkill -x "$APP_NAME" || true
  sleep 0.5
fi

# build
echo "-> Building ($BUILD_CONFIG)..."
bash "$ROOT_DIR/scripts/build_app.sh" "$BUILD_CONFIG"

# launch
BINARY="$APP_DIR/Contents/MacOS/$APP_NAME"
echo "-> Launching $APP_DIR..."

if [[ ${#LAUNCH_ENV[@]} -gt 0 ]]; then
  # env vars require direct execution; open(1) cannot forward them
  env "${LAUNCH_ENV[@]}" "$BINARY" &
  disown
else
  open "$APP_DIR"
fi

echo "   $APP_NAME launched"
