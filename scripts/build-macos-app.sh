#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Claude Code}"
BUNDLE_ID="${BUNDLE_ID:-com.claudecode.app}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BINARY_NAME="${BINARY_NAME:-claude-code}"
ENTRYPOINT="${ENTRYPOINT:-$ROOT_DIR/src/entrypoints/cli.tsx}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/dist/macos}"
APP_BUNDLE_PATH="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE_PATH/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE_PATH/Contents/Resources"
INFO_PLIST_TEMPLATE="${INFO_PLIST_TEMPLATE:-$ROOT_DIR/packaging/macos/Info.plist.template}"
INFO_PLIST_PATH="$APP_BUNDLE_PATH/Contents/Info.plist"
OUTPUT_BINARY_PATH="$MACOS_DIR/$BINARY_NAME"
ZIP_PATH="$BUILD_DIR/$APP_NAME-macos-arm64.zip"

if ! command -v bun >/dev/null 2>&1; then
  echo "bun is required but was not found in PATH."
  exit 1
fi

if [[ ! -f "$ENTRYPOINT" ]]; then
  echo "Entrypoint not found: $ENTRYPOINT"
  exit 1
fi

if [[ ! -f "$INFO_PLIST_TEMPLATE" ]]; then
  echo "Info.plist template not found: $INFO_PLIST_TEMPLATE"
  exit 1
fi

rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [[ -f "$ROOT_DIR/package.json" ]]; then
  if [[ -f "$ROOT_DIR/bun.lock" || -f "$ROOT_DIR/bun.lockb" ]]; then
    bun install --cwd "$ROOT_DIR" --frozen-lockfile
  else
    bun install --cwd "$ROOT_DIR"
  fi
fi

bun build "$ENTRYPOINT" \
  --compile \
  --target=bun-darwin-arm64 \
  --outfile "$OUTPUT_BINARY_PATH"

chmod +x "$OUTPUT_BINARY_PATH"

export APP_NAME BUNDLE_ID APP_VERSION BINARY_NAME
python3 - "$INFO_PLIST_TEMPLATE" "$INFO_PLIST_PATH" <<'PY'
from pathlib import Path
import os
import sys

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
content = template_path.read_text(encoding="utf-8")

replacements = {
    "__APP_NAME__": os.environ["APP_NAME"],
    "__BUNDLE_ID__": os.environ["BUNDLE_ID"],
    "__APP_VERSION__": os.environ["APP_VERSION"],
    "__BINARY_NAME__": os.environ["BINARY_NAME"],
}

for token, value in replacements.items():
    content = content.replace(token, value)

output_path.write_text(content, encoding="utf-8")
PY

if [[ -f "$ROOT_DIR/assets/macos/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/assets/macos/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE_PATH" "$ZIP_PATH"

echo "Built app bundle: $APP_BUNDLE_PATH"
echo "Built zip artifact: $ZIP_PATH"
