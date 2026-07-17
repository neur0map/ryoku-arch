#!/usr/bin/env python3
"""Map a recraft line_art SVG onto the Ryoku ramp.

Each generation picks its own greys, so matching fills by string silently
misses some: one file's linework came back rgb(57,58,58) and stayed invisible
on black. Bucket by luminance instead, which holds for any generation.

Light fills are not only the ground: they are painted inside every outlined
shape. They map to paper, never to none, or the outlines fill in solid.
"""
import re, sys

PAPER, INK, DIM = "#000000", "#cdc4ba", "#7a756e"

def lum(r, g, b):
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255

def regrade(src, dst):
    s = open(src).read()
    def sub(m):
        r, g, b = (int(x) for x in m.group(1, 2, 3))
        L = lum(r, g, b)
        return 'fill="%s"' % (PAPER if L > 0.75 else INK if L < 0.35 else DIM)
    s = re.sub(r'fill="rgb\((\d+),\s*(\d+),\s*(\d+)\)"', sub, s)
    open(dst, "w").write(s)
    return len(re.findall(r'fill="', s))

if __name__ == "__main__":
    for a in sys.argv[1:]:
        n = regrade(a, a.replace("p_", "q_"))
        print("regraded %s (%d fills)" % (a, n))
