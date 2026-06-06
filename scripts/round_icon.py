#!/usr/bin/env python3
"""
round_icon.py — Apply smooth rounded corners to a PNG image.

Default mode produces a macOS-style app icon (continuous superellipse / squircle).
Supports custom corner radius and superellipse exponent for other use cases.

Usage:
    round_icon.py <input.png> [output.png] [options]

Examples:
    # macOS app icon (default)
    round_icon.py logo.png

    # Custom corner radius (pixels)
    round_icon.py logo.png rounded.png --radius 120

    # Custom radius as percentage of image size
    round_icon.py logo.png rounded.png --radius 22%

    # Traditional rounded rectangle (not superellipse)
    round_icon.py logo.png rounded.png --radius 120 --rect

    # Adjust superellipse exponent (default 5, higher = sharper corners)
    round_icon.py logo.png --exponent 4
"""

import argparse
import sys
import numpy as np
from PIL import Image

# ─── macOS icon defaults ──────────────────────────────────────────────────────
# Apple HIG: continuous superellipse with ~22.37% corner radius
MACOS_EXPONENT = 5
MACOS_CORNER_RATIO = 0.2237  # corner radius as fraction of icon size


def make_superellipse_mask(width: int, height: int, radius: float, exponent: float) -> np.ndarray:
    """Generate a smooth superellipse (squircle) alpha mask.

    Args:
        width:  Image width in pixels.
        height: Image height in pixels.
        radius: Corner radius in pixels (measured from edge to curve start).
        exponent: Superellipse exponent (2=circle, 4=classic squircle, 5=macOS).

    Returns:
        2D float64 array [height, width] with values in [0, 1].
    """
    # Semi-axes: distance from center to the flat edge
    a = width / 2.0 - radius + radius * (2 ** (1.0 / exponent))
    b = height / 2.0 - radius + radius * (2 ** (1.0 / exponent))

    # For a square image: a = b = size/2 when radius follows the standard formula.
    # Simplify: use the inscribed superellipse that touches canvas edges at midpoints.
    a = width / 2.0
    b = height / 2.0

    y = np.arange(height, dtype=np.float64).reshape(-1, 1) - (height - 1) / 2.0
    x = np.arange(width, dtype=np.float64).reshape(1, -1) - (width - 1) / 2.0

    norm = (np.abs(x) / a) ** exponent + (np.abs(y) / b) ** exponent

    # Cosine smoothstep transition at the boundary (~6px effective width)
    # transition_width controls the softness: larger = softer edge
    max_dim = max(width, height)
    transition_width = 6.0 / max_dim  # ~6px in normalized space
    t = np.clip((1.0 - norm) / transition_width + 0.5, 0.0, 1.0)
    mask = 0.5 - 0.5 * np.cos(t * np.pi)

    return mask


def make_rounded_rect_mask(width: int, height: int, radius: float) -> np.ndarray:
    """Generate a smooth rounded-rectangle alpha mask.

    Args:
        width:  Image width in pixels.
        height: Image height in pixels.
        radius: Corner radius in pixels.

    Returns:
        2D float64 array [height, width] with values in [0, 1].
    """
    y = np.arange(height, dtype=np.float64).reshape(-1, 1)
    x = np.arange(width, dtype=np.float64).reshape(1, -1)

    # Distance to nearest corner center
    cx = np.clip(x, radius, width - radius)
    cy = np.clip(y, radius, height - radius)
    dx = np.abs(x - cx)
    dy = np.abs(y - cy)
    dist = np.sqrt(dx ** 2 + dy ** 2)

    # Smooth transition at the radius boundary
    t = np.clip((radius - dist) + 0.5, 0.0, 1.0)
    # Apply smoothstep for anti-aliasing
    mask = t * t * (3.0 - 2.0 * t)

    return mask


def resolve_radius(size: int, radius_str: str) -> float:
    """Parse a radius value (pixels or percentage)."""
    if radius_str.endswith('%'):
        return size * float(radius_str[:-1]) / 100.0
    return float(radius_str)


def apply_mask(img: Image.Image, mask: np.ndarray) -> Image.Image:
    """Apply an alpha mask to an RGBA image."""
    pixels = np.array(img.convert("RGBA"))
    pixels[:, :, 3] = (pixels[:, :, 3] * mask).astype(np.uint8)
    return Image.fromarray(pixels)


def main():
    parser = argparse.ArgumentParser(
        description="Apply smooth rounded corners to a PNG image.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("input", help="Input PNG file")
    parser.add_argument("output", nargs="?", default=None, help="Output PNG file (default: overwrite input)")
    parser.add_argument(
        "--radius", default=None,
        help="Corner radius in pixels or %% (default: macOS style 22.37%% of image size)",
    )
    parser.add_argument(
        "--exponent", type=float, default=MACOS_EXPONENT,
        help=f"Superellipse exponent (default: {MACOS_EXPONENT}, higher=sharper corners)",
    )
    parser.add_argument(
        "--rect", action="store_true",
        help="Use traditional rounded rectangle instead of superellipse",
    )
    args = parser.parse_args()

    img = Image.open(args.input)
    w, h = img.size
    size = max(w, h)

    if args.rect:
        radius = resolve_radius(size, args.radius) if args.radius else size * MACOS_CORNER_RATIO
        mask = make_rounded_rect_mask(w, h, radius)
    else:
        radius = resolve_radius(size, args.radius) if args.radius else size * MACOS_CORNER_RATIO
        mask = make_superellipse_mask(w, h, radius, args.exponent)

    result = apply_mask(img, mask)
    output = args.output or args.input
    result.save(output)
    print(f"Saved: {output} ({w}×{h}, radius={radius:.0f}px, {'rect' if args.rect else f'squircle n={args.exponent}'})")


if __name__ == "__main__":
    main()
