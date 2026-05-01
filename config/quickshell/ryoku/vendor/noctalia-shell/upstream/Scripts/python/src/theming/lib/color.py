"""
Color representation and conversion utilities.

This module provides the Color class and functions for converting between
RGB, HSL, and Lab color spaces.
"""

import math
from dataclasses import dataclass
from typing import TYPE_CHECKING

# Type aliases
RGB = tuple[int, int, int]
HSL = tuple[float, float, float]
LAB = tuple[float, float, float]

if TYPE_CHECKING:
    from .hct import Hct


@dataclass
class Color:
    """Represents a color with RGB values (0-255)."""
    r: int
    g: int
    b: int

    @classmethod
    def from_rgb(cls, rgb: RGB) -> 'Color':
        return cls(rgb[0], rgb[1], rgb[2])

    @classmethod
    def from_hex(cls, hex_str: str) -> 'Color':
        """Parse hex color string (#RRGGBB or RRGGBB)."""
        hex_str = hex_str.lstrip('#')
        return cls(
            int(hex_str[0:2], 16),
            int(hex_str[2:4], 16),
            int(hex_str[4:6], 16)
        )

    def to_rgb(self) -> RGB:
        return (self.r, self.g, self.b)

    def to_hex(self) -> str:
        """Convert to hex string (#RRGGBB)."""
        return f"#{self.r:02x}{self.g:02x}{self.b:02x}"

    def to_hsl(self) -> HSL:
        """Convert RGB to HSL."""
        return rgb_to_hsl(self.r, self.g, self.b)

    def to_hct(self) -> 'Hct':
        """Convert to HCT color space."""
        from .hct import Hct
        return Hct.from_rgb(self.r, self.g, self.b)

    @classmethod
    def from_hsl(cls, h: float, s: float, l: float) -> 'Color':
        """Create Color from HSL values."""
        r, g, b = hsl_to_rgb(h, s, l)
        return cls(r, g, b)

    @classmethod
    def from_hct(cls, hct: 'Hct') -> 'Color':
        """Create Color from HCT."""
        r, g, b = hct.to_rgb()
        return cls(r, g, b)


def rgb_to_hsl(r: int, g: int, b: int) -> HSL:
    """
    Convert RGB (0-255) to HSL (0-360, 0-1, 0-1).

    Args:
        r: Red component (0-255)
        g: Green component (0-255)
        b: Blue component (0-255)

    Returns:
        Tuple of (hue, saturation, lightness)
    """
    r_norm = r / 255.0
    g_norm = g / 255.0
    b_norm = b / 255.0

    max_c = max(r_norm, g_norm, b_norm)
    min_c = min(r_norm, g_norm, b_norm)
    delta = max_c - min_c

    # Lightness
    l = (max_c + min_c) / 2.0

    if delta == 0:
        h = 0.0
        s = 0.0
    else:
        # Saturation
        s = delta / (1 - abs(2 * l - 1)) if l != 0 and l != 1 else 0

        # Hue
        if max_c == r_norm:
            h = 60.0 * (((g_norm - b_norm) / delta) % 6)
        elif max_c == g_norm:
            h = 60.0 * (((b_norm - r_norm) / delta) + 2)
        else:
            h = 60.0 * (((r_norm - g_norm) / delta) + 4)

    return (h, s, l)


def hsl_to_rgb(h: float, s: float, l: float) -> RGB:
    """
    Convert HSL (0-360, 0-1, 0-1) to RGB (0-255).

    Args:
        h: Hue (0-360)
        s: Saturation (0-1)
        l: Lightness (0-1)

    Returns:
        Tuple of (r, g, b)
    """
    if s == 0:
        # Achromatic (gray)
        v = int(round(l * 255))
        return (v, v, v)

    def hue_to_rgb(p: float, q: float, t: float) -> float:
        if t < 0:
            t += 1
        if t > 1:
            t -= 1
        if t < 1/6:
            return p + (q - p) * 6 * t
        if t < 1/2:
            return q
        if t < 2/3:
            return p + (q - p) * (2/3 - t) * 6
        return p

    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q
    h_norm = h / 360.0

    r = hue_to_rgb(p, q, h_norm + 1/3)
    g = hue_to_rgb(p, q, h_norm)
    b = hue_to_rgb(p, q, h_norm - 1/3)

    return (
        int(round(r * 255)),
        int(round(g * 255)),
        int(round(b * 255))
    )


def adjust_lightness(color: Color, target_l: float) -> Color:
    """Adjust a color's lightness to a target value (0-1)."""
    h, s, _ = color.to_hsl()
    return Color.from_hsl(h, s, target_l)


def shift_hue(color: Color, degrees: float) -> Color:
    """Shift a color's hue by specified degrees."""
    h, s, l = color.to_hsl()
    new_h = (h + degrees) % 360
    return Color.from_hsl(new_h, s, l)


def hue_distance(h1: float, h2: float) -> float:
    """Calculate minimum angular distance between two hues (0-180)."""
    diff = abs(h1 - h2)
    return min(diff, 360 - diff)


def adjust_surface(color: Color, s_max: float, l_target: float) -> Color:
    """Derive a surface color from a base color with saturation limit and target lightness."""
    h, s, _ = color.to_hsl()
    return Color.from_hsl(h, min(s, s_max), l_target)


def saturate(color: Color, amount: float) -> Color:
    """Adjust saturation by amount (-1 to 1)."""
    h, s, l = color.to_hsl()
    new_s = max(0.0, min(1.0, s + amount))
    return Color.from_hsl(h, new_s, l)


# =============================================================================
# Lab Color Space (CIE L*a*b*)
# =============================================================================

# D65 white point
_WHITE_X = 95.047
_WHITE_Y = 100.0
_WHITE_Z = 108.883


def _linearize(channel: int) -> float:
    """Convert sRGB channel (0-255) to linear RGB (0-1)."""
    normalized = channel / 255.0
    if normalized <= 0.04045:
        return normalized / 12.92
    return math.pow((normalized + 0.055) / 1.055, 2.4)


def _delinearize(linear: float) -> int:
    """Convert linear RGB (0-1) to sRGB channel (0-255)."""
    if linear <= 0.0031308:
        normalized = linear * 12.92
    else:
        normalized = 1.055 * math.pow(linear, 1.0 / 2.4) - 0.055
    return max(0, min(255, round(normalized * 255)))


def _lab_f(t: float) -> float:
    """Lab forward transform function."""
    if t > 0.008856:
        return math.pow(t, 1.0 / 3.0)
    return (903.3 * t + 16.0) / 116.0


def _lab_f_inv(t: float) -> float:
    """Lab inverse transform function."""
    if t > 0.206893:
        return t * t * t
    return (116.0 * t - 16.0) / 903.3


def rgb_to_lab(r: int, g: int, b: int) -> LAB:
    """
    Convert sRGB (0-255) to CIE L*a*b*.

    Returns:
        Tuple of (L*, a*, b*) where L* is 0-100
    """
    # sRGB to linear RGB
    linear_r = _linearize(r)
    linear_g = _linearize(g)
    linear_b = _linearize(b)

    # Linear RGB to XYZ (D65)
    x = 0.4124564 * linear_r + 0.3575761 * linear_g + 0.1804375 * linear_b
    y = 0.2126729 * linear_r + 0.7151522 * linear_g + 0.0721750 * linear_b
    z = 0.0193339 * linear_r + 0.1191920 * linear_g + 0.9503041 * linear_b

    # Scale to 0-100 range
    x *= 100.0
    y *= 100.0
    z *= 100.0

    # XYZ to Lab
    fx = _lab_f(x / _WHITE_X)
    fy = _lab_f(y / _WHITE_Y)
    fz = _lab_f(z / _WHITE_Z)

    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b = 200.0 * (fy - fz)

    return (L, a, b)


def lab_to_rgb(L: float, a: float, b: float) -> RGB:
    """
    Convert CIE L*a*b* to sRGB (0-255).

    Args:
        L: Lightness (0-100)
        a: Green-red component
        b: Blue-yellow component

    Returns:
        Tuple of (r, g, b)
    """
    # Lab to XYZ
    fy = (L + 16.0) / 116.0
    fx = a / 500.0 + fy
    fz = fy - b / 200.0

    x = _WHITE_X * _lab_f_inv(fx)
    y = _WHITE_Y * _lab_f_inv(fy)
    z = _WHITE_Z * _lab_f_inv(fz)

    # Scale back to 0-1 range
    x /= 100.0
    y /= 100.0
    z /= 100.0

    # XYZ to linear RGB
    linear_r = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
    linear_g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
    linear_b = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z

    # Clamp and delinearize
    return (
        _delinearize(max(0.0, min(1.0, linear_r))),
        _delinearize(max(0.0, min(1.0, linear_g))),
        _delinearize(max(0.0, min(1.0, linear_b)))
    )


def lab_distance(lab1: LAB, lab2: LAB) -> float:
    """
    Calculate Euclidean distance between two Lab colors.

    This is a simple perceptual distance metric.
    """
    dL = lab1[0] - lab2[0]
    da = lab1[1] - lab2[1]
    db = lab1[2] - lab2[2]
    return math.sqrt(dL * dL + da * da + db * db)


def find_closest_color(
    compare_to: str,
    colors: list[dict[str, str]]
) -> str:
    """
    Find the closest named color from a list (matugen-compatible).

    Uses Lab color space Euclidean distance for perceptual color matching.

    Args:
        compare_to: Hex color to compare (e.g., "#ff5500")
        colors: List of {"name": "...", "color": "#..."} dicts

    Returns:
        Name of the closest color, or empty string if no colors provided
    """
    if not colors:
        return ""

    # Parse target color
    target = Color.from_hex(compare_to)
    target_lab = rgb_to_lab(target.r, target.g, target.b)

    closest_name = ""
    closest_dist = float('inf')

    for entry in colors:
        try:
            entry_color = Color.from_hex(entry["color"])
            entry_lab = rgb_to_lab(entry_color.r, entry_color.g, entry_color.b)
            dist = lab_distance(target_lab, entry_lab)
            if dist < closest_dist:
                closest_dist = dist
                closest_name = entry["name"]
        except (KeyError, ValueError):
            # Skip invalid entries
            continue

    return closest_name
