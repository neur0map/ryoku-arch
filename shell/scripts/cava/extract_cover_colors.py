#!/usr/bin/env python3
"""Extract dominant colors from album art for cava gradients."""

import json
import os
import sys
from collections import Counter
from pathlib import Path


def quantize_colors(image_path: str, count: int = 8) -> list[str]:
    from PIL import Image

    image = Image.open(image_path).convert("RGB")
    image = image.resize((150, 150), Image.LANCZOS)
    quantized = image.quantize(colors=count * 2, method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette()
    if not palette:
        return []

    ranked = []
    for idx, _freq in Counter(quantized.getdata()).most_common():
        r, g, b = palette[idx * 3], palette[idx * 3 + 1], palette[idx * 3 + 2]
        brightness = (r * 299 + g * 587 + b * 114) / 1000
        if brightness < 20 or brightness > 240:
            continue
        ranked.append(f"#{r:02x}{g:02x}{b:02x}")
        if len(ranked) >= count:
            break

    return ranked


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: extract_cover_colors.py <image_path> [count] [output_path]", file=sys.stderr)
        return 1

    image_path = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    state_dir = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
    default_output = Path(state_dir) / "quickshell" / "user" / "generated" / "cover-colors.json"
    output_path = Path(sys.argv[3]) if len(sys.argv) > 3 else default_output

    if not os.path.isfile(image_path):
        print(f"Image not found: {image_path}", file=sys.stderr)
        return 1

    try:
        colors = quantize_colors(image_path, count)
    except ImportError:
        print("PIL not available, cannot extract colors", file=sys.stderr)
        return 1
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    if len(colors) < 2:
        print("Not enough distinct colors found", file=sys.stderr)
        return 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(colors), encoding="utf-8")
    print(json.dumps(colors))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
