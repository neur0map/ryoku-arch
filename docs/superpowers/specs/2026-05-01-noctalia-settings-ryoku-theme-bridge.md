# Noctalia Settings Ryoku Theme Bridge

## Goal

Make the centered Noctalia-derived settings panel look like Ryoku without changing Noctalia's layout, spacing, controls, or page structure.

## Visual Rules

- Noctalia's yellow primary accent is replaced with Ryoku brand orange `#F25623`.
- Panel surfaces, text colors, outlines, secondary accents, and hover tones come from the active Ryoku theme.
- Greek Noir is the fallback palette when the active theme render is missing.
- Noctalia widgets continue to consume their existing `Color.m*` roles; the bridge changes the color source, not the UI code.
- Noctalia's default and fixed fonts use Ryoku's configured monospace family, currently `JetBrainsMono Nerd Font`, instead of upstream blank/default font values.

## Architecture

Add a `default/themed/noctalia-colors.json.tpl` template rendered by `ryoku-theme-set-templates` beside the existing shell color templates. It maps Ryoku theme tokens into Noctalia's Material-style roles. `mPrimary`, `mOnPrimary`, and hover-on-primary stay brand-controlled; theme-derived tokens feed surfaces and non-primary roles.

Update `Noctalia/Commons/Color.qml` to read the rendered active-theme `noctalia-colors.json` from `~/.config/ryoku/current/theme/`. If that file is missing, the singleton falls back to Greek Noir values embedded in the QML defaults.

Update `Noctalia/Commons/Settings.qml` and `Assets/settings-default.json` so Noctalia's font settings default to Ryoku's monospace font. User changes through the settings UI still persist through Noctalia's existing settings adapter.

## Verification

Static shell tests must prove:

- the theme renderer produces `noctalia-colors.json`;
- rendered Noctalia primary is `#F25623`;
- rendered surface/text colors come from the active Ryoku theme;
- unresolved template placeholders are not left behind;
- Noctalia `Color.qml` reads the Ryoku current-theme color file;
- Noctalia defaults use the Ryoku font family.
