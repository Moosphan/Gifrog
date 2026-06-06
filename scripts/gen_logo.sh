#!/usr/bin/env bash
# gen_logo.sh — Generate PNG assets from SVG sources
#
# Usage:
#   ./scripts/gen_logo.sh [options]
#
# Options:
#   --bg-color COLOR      Background color for app icon (CSS hex, e.g. #F2FFF7). Default: SVG original
#   --size SIZE           Output size in pixels for logo.png (default: 1024)
#   --no-logo             Skip generating assets/logo.png
#   --no-icon             Skip generating Sources/Gifrog/Resources/GifrogIcon.png
#   --no-template         Skip generating Sources/Gifrog/Resources/GifrogIconTemplate.png
#   --out-dir DIR         Override output directory for all files (optional)
#   --help                Show this help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/assets"
RES_DIR="$ROOT_DIR/Sources/Gifrog/Resources"

# ── defaults ──────────────────────────────────────────────────────────────────
OPT_BG_COLOR=""
OPT_SIZE=1024
OPT_LOGO=true
OPT_ICON=true
OPT_TEMPLATE=true
OPT_OUT_DIR=""

# ── argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bg-color)   OPT_BG_COLOR="$2";  shift 2 ;;
    --size)       OPT_SIZE="$2";      shift 2 ;;
    --no-logo)    OPT_LOGO=false;     shift   ;;
    --no-icon)    OPT_ICON=false;     shift   ;;
    --no-template) OPT_TEMPLATE=false; shift  ;;
    --out-dir)    OPT_OUT_DIR="$2";   shift 2 ;;
    --help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── output dirs ───────────────────────────────────────────────────────────────
if [[ -n "$OPT_OUT_DIR" ]]; then
  mkdir -p "$OPT_OUT_DIR"
  LOGO_OUT="$OPT_OUT_DIR/logo.png"
  ICON_OUT="$OPT_OUT_DIR/GifrogIcon.png"
  TMPL_OUT="$OPT_OUT_DIR/GifrogIconTemplate.png"
else
  LOGO_OUT="$ASSETS_DIR/logo.png"
  ICON_OUT="$RES_DIR/GifrogIcon.png"
  TMPL_OUT="$RES_DIR/GifrogIconTemplate.png"
fi

# ── helpers ───────────────────────────────────────────────────────────────────

# svg_to_png <svg_file> <size> <out_file>
#   Uses qlmanage (macOS built-in, vector-accurate) to render SVG → PNG.
svg_to_png() {
  local svg="$1" size="$2" out="$3"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local svg_base
  svg_base="$(basename "$svg")"

  qlmanage -t -s "$size" -o "$tmp_dir" "$svg" >/dev/null 2>&1
  local rendered="$tmp_dir/${svg_base}.png"
  if [[ ! -f "$rendered" ]]; then
    echo "  ✗ qlmanage failed to render $svg" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  mv "$rendered" "$out"
  rm -rf "$tmp_dir"
}

# patch_bg_color <svg_file> <color> → prints path of a temp SVG with background set to color.
# Handles two SVG shapes:
#   1. Has a linearGradient id="gifrog-icon-bg" + rect using it → replaces gradient stops
#   2. No background rect → inserts a plain rect as first child of <svg>
patch_bg_color() {
  local svg="$1" color="$2"
  local tmp
  tmp="$(mktemp /tmp/gen_logo_XXXXXX.svg)"
  python3 - "$svg" "$color" "$tmp" <<'PY'
import sys, re

src, color, dst = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src).read()

if 'gifrog-icon-bg' in text:
    # Replace stop-color values inside the gifrog-icon-bg gradient block
    def patch_gradient(m):
        return re.sub(r'stop-color="[^"]*"', f'stop-color="{color}"', m.group(0))
    text = re.sub(
        r'<linearGradient[^>]*id="gifrog-icon-bg"[^>]*>.*?</linearGradient>',
        patch_gradient, text, flags=re.DOTALL
    )
else:
    # No existing background — extract viewBox dimensions and prepend a rect
    vb = re.search(r'viewBox="0 0 (\d+) (\d+)"', text)
    w, h = (vb.group(1), vb.group(2)) if vb else ('512', '512')
    rx = str(int(int(w) * 112 / 512))   # same corner-radius ratio as logo.svg
    rect = f'  <rect width="{w}" height="{h}" rx="{rx}" fill="{color}"/>\n'
    text = re.sub(r'(<svg[^>]*>)', r'\1\n' + rect, text, count=1)

open(dst, 'w').write(text)
print(dst)
PY
}

# ── logo.png (assets/logo.png) ────────────────────────────────────────────────
if $OPT_LOGO; then
  echo "→ Generating logo.png (${OPT_SIZE}px)…"
  SVG_SRC="$ASSETS_DIR/logo.svg"

  if [[ -n "$OPT_BG_COLOR" ]]; then
    PATCHED_SVG="$(patch_bg_color "$SVG_SRC" "$OPT_BG_COLOR")"
    svg_to_png "$PATCHED_SVG" "$OPT_SIZE" "$LOGO_OUT"
    rm -f "$PATCHED_SVG"
  else
    svg_to_png "$SVG_SRC" "$OPT_SIZE" "$LOGO_OUT"
  fi
  echo "  ✓ $LOGO_OUT"
fi

# ── GifrogIcon.png (app icon, with background) ────────────────────────────────
if $OPT_ICON; then
  echo "→ Generating GifrogIcon.png (1024px)…"
  SVG_SRC="$RES_DIR/GifrogIcon.svg"

  if [[ -n "$OPT_BG_COLOR" ]]; then
    PATCHED_SVG="$(patch_bg_color "$SVG_SRC" "$OPT_BG_COLOR")"
    svg_to_png "$PATCHED_SVG" 1024 "$ICON_OUT"
    rm -f "$PATCHED_SVG"
  else
    svg_to_png "$SVG_SRC" 1024 "$ICON_OUT"
  fi
  echo "  ✓ $ICON_OUT"
fi

# ── GifrogIconTemplate.png (menu bar, monochrome template) ────────────────────
if $OPT_TEMPLATE; then
  echo "→ Generating GifrogIconTemplate.png (88px @2x = 44pt)…"
  SVG_SRC="$RES_DIR/GifrogIconTemplate.svg"
  # Template icons render as-is (black strokes, transparent bg) — bg color N/A
  svg_to_png "$SVG_SRC" 88 "$TMPL_OUT"
  echo "  ✓ $TMPL_OUT"
fi

echo "Done."
