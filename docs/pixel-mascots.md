# Pixel Mascots

Ryoku has no canonical character mascot yet. The current brand anchor is the **力** mark: *chikara / ryoku*, meaning power or strength. Small decorative sprites should reinforce that mark instead of introducing a separate brand language.

## Existing references

- `assets/brand/logo.svg` and `assets/brand/logo-mark.svg`: the canonical **力** mark.
- `shell/assets/bongocat.gif`: an existing shell asset, useful as a reference but not Ryoku-specific.
- ActivSpot's `pet/Pet.qml`: a 14x14 pixel cat drawn from string arrays.
- ActivSpot's `pet/CatPill.qml`: an 8x8 compact cat drawn the same way.

The ActivSpot pets are not image files. They are QML canvas sprites:

1. Define a fixed sprite grid, usually 8x8, 14x14, or 16x16.
2. Store each frame as an array of strings.
3. Map each non-space character to a palette color.
4. Draw each character as one square pixel on a `Canvas`.
5. Use timers to switch frames and states.

## Sprite rules

Use these rules for any Ryoku-specific mascot or mark:

- Keep the sprite readable at 24-56 physical pixels.
- Use a dark outline on light fills, or a light outline on dark fills.
- Reserve `#F25623` for Ryoku brand accents.
- Keep neutral body colors close to the active shell surface palette.
- Animate with two to four frames per state.
- Keep motion small: blink, idle bob, one-pixel step, or a short sleep cycle.
- Avoid large horizontal movement inside compact shell surfaces.
- Do not add external image files unless the sprite needs detail that cannot survive a small canvas grid.

## Suggested Ryoku sprites

### Pixel 力 mark

Best for compact surfaces. Use an 8x8 or 12x12 grid with the brand orange fill. Keep the silhouette close to the real kanji, not a Latin logo.

### Ronin or samurai

Best for decorative spacer space in a larger island or launcher. Use a 16x16 grid:

- dark outline
- muted robe color from the current surface palette
- `#F25623` headband, sash, or sword glint
- two-frame blink
- two-frame idle bob

### Kitsune mask

Good when a mascot is needed without a full character body. Use white or muted foreground, orange ear/cheek accents, and a dark outline.

## QML frame pattern

```qml
readonly property var palette: ({
  "#": "#171717",
  "o": "#F25623",
  "w": "#CCD0CF",
  ".": "#4D4D4D"
})

readonly property var idleFrames: [
  [
    "   ##   ",
    "  #oo#  ",
    " #owwo# ",
    " #oooo# ",
    "  ####  ",
    "   ##   ",
    "  #..#  ",
    "        "
  ]
]
```

The drawing loop should skip spaces, look up each character in the palette, and fill one rectangle per sprite cell. Keep the cell size derived from the available item size so the sprite scales cleanly.
