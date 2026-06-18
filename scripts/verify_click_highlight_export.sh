#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_JSON="${GIFROG_CLICK_PROJECT:-$HOME/Library/Application Support/Gifrog/projects/00DB1AE0-FC23-4133-BBC3-5D47EC9524D2/project.json}"
WORK_DIR="${TMPDIR:-/tmp}/gifrog-click-highlight-export-verify"
RUNNER="$WORK_DIR/export_click_fixture"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

swiftc -parse-as-library \
  "$ROOT_DIR/Sources/Gifrog/AppPaths.swift" \
  "$ROOT_DIR/Sources/Gifrog/Models.swift" \
  "$ROOT_DIR/Sources/Gifrog/Export/ExportManager.swift" \
  "$ROOT_DIR/scripts/export_click_fixture.swift" \
  -o "$RUNNER"

"$RUNNER" "$PROJECT_JSON" "$WORK_DIR" > "$WORK_DIR/exports.txt"

plain="$(sed -n 's/^plain=//p' "$WORK_DIR/exports.txt")"
highlighted="$(sed -n 's/^highlighted=//p' "$WORK_DIR/exports.txt")"

python3 - "$plain" "$highlighted" "$WORK_DIR" <<'PY'
import sys
import subprocess
from PIL import Image, ImageChops, ImageStat

plain_gif, highlighted_gif, work_dir = sys.argv[1:4]

clicks = [
    (1.084, 155, 180),
    (1.584, 203, 187),
    (2.702, 275, 168),
    (3.422, 112, 201),
    (5.222, 485, 190),
]

measurements = []
for index, (time, center_x, center_y) in enumerate(clicks):
    plain_png = f"{work_dir}/plain-{index}.png"
    highlighted_png = f"{work_dir}/highlighted-{index}.png"
    subprocess.run(
        ["ffmpeg", "-y", "-ss", f"{time:.3f}", "-i", plain_gif, "-frames:v", "1", "-update", "1", plain_png],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )
    subprocess.run(
        ["ffmpeg", "-y", "-ss", f"{time:.3f}", "-i", highlighted_gif, "-frames:v", "1", "-update", "1", highlighted_png],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )

    plain = Image.open(plain_png).convert("RGB")
    highlighted = Image.open(highlighted_png).convert("RGB")
    box = (center_x - 18, center_y - 18, center_x + 18, center_y + 18)
    diff = ImageChops.difference(plain.crop(box), highlighted.crop(box))
    stat = ImageStat.Stat(diff)
    peak = max(channel[1] for channel in diff.getextrema())
    total = sum(stat.sum)
    center_red, center_green, center_blue = highlighted.getpixel((center_x, center_y))
    purple_bias = center_blue - min(center_red, center_green)
    measurements.append((index + 1, peak, total, purple_bias))

failures = [(index, peak, total) for index, peak, total, _ in measurements if peak < 90 or total < 14000]
if failures:
    details = ", ".join(f"click {index}: peak={peak:.1f} total={total:.1f}" for index, peak, total in failures)
    print(f"FAIL: click highlight is too weak in exported GIF. {details}", file=sys.stderr)
    sys.exit(1)

purple_failures = [(index, purple_bias) for index, _, _, purple_bias in measurements if purple_bias > 45]
if purple_failures:
    details = ", ".join(f"click {index}: purple_bias={purple_bias}" for index, purple_bias in purple_failures)
    print(f"FAIL: exported click highlight should match the white preview style, not purple. {details}", file=sys.stderr)
    sys.exit(1)

details = ", ".join(f"click {index}: peak={peak:.1f} total={total:.1f}" for index, peak, total, _ in measurements)
print(f"click highlight export verification passed {details}")
PY
