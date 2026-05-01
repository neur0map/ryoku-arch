"""
Contrast calculation utilities (WCAG luminance and contrast).

This module provides functions for calculating relative luminance,
contrast ratios, and ensuring accessible color combinations.
"""

from .color import Color


def relative_luminance(r: int, g: int, b: int) -> float:
    """
    Calculate relative luminance per WCAG 2.1.

    The formula converts sRGB to linear RGB, then applies the luminance formula:
    L = 0.2126 * R + 0.7152 * G + 0.0722 * B

    Args:
        r, g, b: RGB components (0-255)

    Returns:
        Relative luminance (0-1)
    """
    def linearize(c: int) -> float:
        c_norm = c / 255.0
        if c_norm <= 0.03928:
            return c_norm / 12.92
        return ((c_norm + 0.055) / 1.055) ** 2.4

    r_lin = linearize(r)
    g_lin = linearize(g)
    b_lin = linearize(b)

    return 0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin


def contrast_ratio(color1: Color, color2: Color) -> float:
    """
    Calculate WCAG contrast ratio between two colors.

    Returns a value between 1:1 (identical) and 21:1 (black/white).
    """
    l1 = relative_luminance(color1.r, color1.g, color1.b)
    l2 = relative_luminance(color2.r, color2.g, color2.b)

    lighter = max(l1, l2)
    darker = min(l1, l2)

    return (lighter + 0.05) / (darker + 0.05)


def is_dark(color: Color) -> bool:
    """Determine if a color is perceptually dark."""
    return relative_luminance(color.r, color.g, color.b) < 0.179


def ensure_contrast(
    foreground: Color,
    background: Color,
    min_ratio: float = 4.5,
    prefer_light: bool | None = None
) -> Color:
    """
    Adjust foreground color to meet minimum contrast ratio against background.

    Args:
        foreground: The color to adjust
        background: The background color (not modified)
        min_ratio: Minimum contrast ratio (default 4.5 for WCAG AA)
        prefer_light: If True, prefer lightening; if False, prefer darkening;
                     if None, auto-detect based on background

    Returns:
        Adjusted foreground color meeting contrast requirements
    """
    current_ratio = contrast_ratio(foreground, background)
    if current_ratio >= min_ratio:
        return foreground

    h, s, l = foreground.to_hsl()
    bg_dark = is_dark(background)

    # Determine direction to adjust
    if prefer_light is None:
        prefer_light = bg_dark

    # Binary search for the right lightness
    if prefer_light:
        low, high = l, 1.0
    else:
        low, high = 0.0, l

    best_color = foreground
    for _ in range(20):  # Max iterations
        mid = (low + high) / 2
        test_color = Color.from_hsl(h, s, mid)
        ratio = contrast_ratio(test_color, background)

        if ratio >= min_ratio:
            best_color = test_color
            if prefer_light:
                high = mid
            else:
                low = mid
        else:
            if prefer_light:
                low = mid
            else:
                high = mid

    return best_color


def get_contrasting_color(background: Color, min_ratio: float = 4.5) -> Color:
    """Get a contrasting foreground color (black or white variant)."""
    if is_dark(background):
        # Light foreground for dark background
        fg = Color(243, 237, 247)  # Off-white
    else:
        # Dark foreground for light background
        fg = Color(14, 14, 67)  # Dark blue-black

    return ensure_contrast(fg, background, min_ratio)
