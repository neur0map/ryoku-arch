# Ryoku Design Spec (`ryokudesign.md`)

**Goal:** Portable, implementation-precise visual spec extracted from `ryoku-site` and shell sources so Quickshell surfaces can be shaped to match Ryoku look/behavior.

**Last sync:** based on
- `ryoku-site` repo files under `app/`, `public/`, `tests/`
- shell config/runtime behavior in `shell/` and `shell/plugin/src/Ryoku/Config/`

---

## 1) Official site identity and invariants

- Product wording: **Ryoku Arch**
- Brand line: **Power and beauty, already composed.**
- Japanese line: **力と美のために**
- Marketing truth: Public preview signed alpha, Quickshell/Caelestia shell, Hyprland, premium Arch workstation.
- SEO/source identity (site): `https://ryoku.dev/`

---

## 2) Global visual token system (site)

From `app/assets/css/tokens.css`:

### Palette
- `--ryoku-bg: #0f0f0e`
- `--ryoku-bg-soft: #151412`
- `--ryoku-surface: #1c1917`
- `--ryoku-surface-2: #24211e`
- `--ryoku-card: rgba(28, 25, 23, 0.84)`
- `--ryoku-card-soft: rgba(36, 33, 30, 0.7)`
- `--ryoku-rule: rgba(220, 214, 198, 0.14)`
- `--ryoku-rule-strong: rgba(236, 229, 210, 0.26)`

### Text
- `--ryoku-text: #d8d6ca`
- `--ryoku-text-strong: #f6f1ea`
- `--ryoku-text-muted: #b3ad9b`
- `--ryoku-text-faint: #7a7365`

### Accent
- `--ryoku-accent: #f25623`
- `--ryoku-accent-bright: #f56e0f`
- `--ryoku-accent-soft: rgba(242, 86, 35, 0.16)`
- `--ryoku-accent-line: rgba(242, 86, 35, 0.38)`

### Pastels
- mint `#a7f3d0`
- sky `#bae6fd`
- lilac `#ddd6fe`
- rose `#fecdd3`
- amber `#fde68a`
- sage `#c9d7b8`

### Size / geometry
- `--ryoku-max: 1180px`
- `--ryoku-gutter: clamp(1rem, 3vw, 2rem)`
- `--ryoku-section-y: clamp(2rem, 4vw, 3.25rem)`
- `--ryoku-section-y-tight: clamp(1.2rem, 2.5vw, 2rem)`

### Radius
- `xs 6`, `sm 10`, `md 14`, `lg 18`, `xl 24`, `pill 999`

### Shadows
- `soft: 0 20px 70px rgba(0, 0, 0, 0.28)`
- `card: 0 14px 44px rgba(0, 0, 0, 0.22)`

### Type scale
- `--ryoku-font-display: "Fraunces Variable", "Fraunces", ...`
- `--ryoku-font-body: "Onest Variable", "Onest", ...`
- `--ryoku-font-mono: "JetBrains Mono Variable", "JetBrains Mono", ...`
- `--ryoku-font-jp: "Noto Sans JP Variable", "Noto Sans JP", ...`

### Motion
- `--ryoku-ease: cubic-bezier(0.22, 1, 0.36, 1)`
- `--ryoku-speed-fast: 140ms`
- `--ryoku-speed-base: 280ms`
- `--ryoku-speed-slow: 540ms`

### Base.css behavior
- import token CSS and all 4 variable fonts.
- Global background on `body` includes subtle diagonal/repeated grid + dark vertical gradient.
- `section[id] { scroll-margin-top: 6rem; }`
- `prefers-reduced-motion: reduce` disables transitions and reveal animation.

---

## 3) Shell-compatible runtime tokens (Quickshell bridge)

From `shell/plugin/src/Ryoku/Config/tokens.hpp` and `appearanceconfig.cpp`:

- Base token values:
  - rounding base: `extraSmall 4`, `small 12`, `normal 17`, `large 25`, `full 1000`
  - spacing base: `small 7`, `smaller 10`, `normal 12`, `larger 15`, `large 20`
  - padding base: `small 5`, `smaller 7`, `normal 10`, `larger 12`, `large 15`
  - font base size: `11/12/13/15/18/28`
- Appearance values are **token value × config scale**. `Config.appearance.rounding.scale`, `spacing.scale`, `padding.scale`, `font.size.scale`, and `anim.durations.scale` apply as multipliers.

Current practical mapping from active source:
- User override (from `~/.config/ryoku/shell.json`):
  - `appearance.rounding.scale: 0.6`
  - `border.rounding: 7`
  - `border.thickness: 9`

Config path precedence:
- User scope: `~/.config/ryoku/shell.json`
- default fallback: `~/.local/share/ryoku/default/ryoku-shell/shell.json`
- token fallback: `~/.config/ryoku/shell-tokens.json` (read by QStandardPaths::writableLocation + `/ryoku/`) if present.

Important formula for adapting section 2 visuals:
- Use `Tokens.rounding.normal`, `Tokens.rounding.large`, etc for quirk-free consistency.
- With scale 0.6: `Tokens.rounding.normal ≈ floor(17 * 0.6) = 10`, `large ≈ 15`.
- Border geometry uses separate hard value `Config.border.rounding` in a few places.

---

## 4) Reveal system / motion choreography

From `app/plugins/reveal.client.ts`:
- On mount, `document.documentElement.classList.add('js')`.
- If reduced-motion, all `[data-reveal]` become visible immediately.
- Else: `IntersectionObserver` with:
  - `threshold: 0.14`
  - `rootMargin: '0px 0px -6% 0px'`
- On first intersect: add `is-visible` and unobserve.
- MutationObserver re-scans DOM for late-inserted `[data-reveal]`.

From CSS:
- unrevealed: `opacity: 0`, `filter: blur(4px)`, `transform: translateY(16px)`
- transition each 0.62s with `--ryoku-ease`
- `data-reveal-stagger="1..5"` maps delays `0.05..0.25s`.

---

## 5) Site composition and section contract

Source order in `app/pages/index.vue`:
1. `HeroSection` (`#overview`)
2. `ProofStrip`
3. `DownloadSection` (`#download`)
4. `ReleaseTrailSection` (`#trail`)
5. `GalleryBand` (`#surfaces`)
6. `ExtrasSection` (`#extras`)
7. `SystemSection` (`#system`)

Global wrappers:
- `app/layouts/default.vue` gives `<SiteHeader/>`, `<main>`, `<SiteFooter/>`.
- `main shell` currently uses `<div class="shell">` with `min-height: 100vh`.

---

## 6) Component-level specification

### Header (`app/components/SiteHeader.vue`)
- Sticky top bar (`position: sticky; top: 0`) with `min-height: 66px`, backdrop blur 18px, border bottom.
- nav links: Overview / Download / Trail / Extras / Docs / GitHub.
- `AppLinkButton` for Discord (primary).
- Hide Docs/GitHub links below 820px; hide full nav below 620px.

### Hero (`HeroSection.vue`, `#overview`)
- Grid: `hero-shell` two columns: `minmax(0,0.98fr)` and `minmax(320px,0.52fr)`; stacked under 980px.
- Intro `h1` is two lines: title + `<em>` tagline.
- Big callout `h1` ranges `clamp(4rem,12vw,10.6rem)`; em tagline `clamp(2.05rem,5.4vw,5rem)`.
- Kanji signal block with huge `clamp(11rem,25vw,20rem)` plus animated stroke and breathe.
- Two-column mini data table in signal (label/value).
- Animations:
  - `hero-sweep` translate from `-14%` to `10%` over 13s alternate.
  - `signal-run` vertical rail sweep.
  - `mark-breathe` up/scale micro.

### Proof strip (`ProofStrip.vue`)
- Grid 5 columns desktop, 3 columns @ `<=940`, 1 column @ `<=560`.
- dt uppercase mono small; dd uses `--ryoku-font-display`.
- subtle `data-reveal` on each cell.

### Download section (`DownloadSection.vue`, `#download`)
- `PUBLIC_CHANNEL = stable`
- `ISO_BASE = https://iso.ryoku.dev/stable`
- manifest URLs:
  - preferred: `latest.js` loaded as script with cache-buster `?ts=${Date.now()}`
  - fallback fetch: `latest.json`
  - if script fails, fallback manifest path used
  - `normalizeManifest()` maps `manifest.files` fields to names/urls and defaults:
    - `signature: ${iso}.sig`
    - `sha256: ${iso}.sha256`
    - `manifest: ${iso}.json`
    - `public_key: ryoku-release-key.pub.asc`
- cache: `localStorage key=ryoku.iso.latest-release.stable`, TTL 1 hour.
- fallback hardcoded release block is present if all fails.
- grid areas:
  - `download-slab` card
  - `release-ledger` build metadata
  - `files-table`
  - `key-panel`
  - `WaitlistForm`
- Artifact links are always normalized to `ISO_BASE` names; `main` manifest names are rewritten to `stable` path in tests (asserted).

### Trail (`ReleaseTrailSection.vue`, `#trail`)
- 3 phases (alpha/beta/stable), each with progress and milestones.
- `overall readiness` computed score: done `1`, wip = `progress` default `0.5`, todo `0`.
- Uses `WaveBar` for progress display.

### Gallery (`GalleryBand.vue`, `#surfaces`)
- Horizontally scrollable rail with `grid-auto-columns` 38vw desktop, 78vw under 980px, 88vw on very small.
- `img[loading="lazy" decoding="auto"]` on all shots.
- Lead image ratio wider `16/8.6`; others `16/9.5`.

### Extras (`ExtrasSection.vue`, `#extras`)
- Horizontally scrollable rail of 10 kits.
- One row, each card has top border accent line with hover scaling transform and image rotate.
- Every card has `wide` style when `index % 4 === 1` (offset translateY).

### System (`SystemSection.vue`, `#system`)
- Intro + lanes list + requirements grid + docs links.
- Lane list uses 2 columns with index label in accent color.
- Docs links rendered in 2-col grid desktop; single column mobile.

### Footer (`SiteFooter.vue`)
- Brand + year + JP slogan.
- Links: Docs / GitHub / Discord / Reddit / X.

### Shared button pattern (`AppLinkButton.vue`)
- `primary | secondary | ghost` variants.
- base: `border-radius: var(--ryoku-radius-sm)`, `min-height:38px`, uppercase mono.
- hover arrow slides right + shimmer `::before` diagonal sweep.

### Waitlist form (`WaitlistForm.vue`)
- POSTs to `https://n.prowl.sh/webhook/ryoku` by default, overridable with `NUXT_PUBLIC_N8N_WEBHOOK_URL`.
- localStorage dedupe key `ryoku.waitlist.submitted`.
- simple honeypot and email regex.

### Wave renderer (`WaveBar.vue`)
- Procedurally creates sine-path data URI in JS for mask.
- props: `value`, `color`, `height`, `wavelength`, `amplitude`, `stroke-width`, `speed`, `samples`.
- uses CSS masks to repeat sine wave in filled region.

---

## 7) Runtime config + metadata

`app.config.ts` + `nuxt.config.ts` + `shared/ryoku-site.ts`:
- defaults:
  - site: `https://ryoku.dev`
  - docs: `https://docs.ryoku.dev`
  - repo: `https://github.com/neur0map/ryoku-arch`
  - discord: `https://discord.gg/8KjBmUEyKA`
  - reddit: `https://www.reddit.com/r/RyokuArch/`
  - x: `https://x.com/neur0map`
  - n8n webhook default `https://n.prowl.sh/webhook/ryoku`
  - version raw URL: `https://raw.githubusercontent.com/neur0map/ryoku-arch/main/VERSION`
- `index.vue` sets title/description/canonical/og/twitter + `jsonLd`
- `social-card.svg` is explicitly `1280x640`, background gradients + watermark kanji, copy in Fraunces/Onest/JetBrains Mono.

---

## 8) Deterministic validation (automated)

From `tests/marketing.spec.ts`:
- asserts hero/title, links, text, no accidental references to alternate shells.
- verifies canonical + OG/Twitter metadata (`og:url`, `twitter:image`, jsonLD schema).
- verifies robots/sitemap endpoints.
- verifies `#download` manifest normalization behavior.
- verifies no `<link rel="preload" as="image">` (intentional: no upfront hero image preload).

Snapshot scripts:
- `tests/snap-layout.mjs` captures full/fold shots for [1440,1920,768,390] with reduced-motion.
- Before capture it removes intro (`.intro`) and sets `intro-done`, then primes lazy images by scrolling through document.
- `snap-section.mjs`, `snap-gallery.mjs`, `snap-element.mjs` capture scoped screenshots with same intro removal.

Use these as visual baselines for Quickshell parity if building a renderer-equivalent desktop shell.

---

## 9) Practical Quickshell adaptation mapping

Use for shell rebuild:
- **Colors:** use Ryoku website tokens as surface/base palette.
  - prefer `--ryoku-bg`, `--ryoku-surface`, `--ryoku-surface-2`, `--ryoku-rule(-strong)`, `--ryoku-text*`, `--ryoku-accent`.
- **Geometry:** map website radius ladder to Quickshell tokens where possible (`Tokens.rounding.*`), then `Config.border.rounding` for hard corners.
- **Spacing:** map rhythm with `Tokens.padding.*` and `Tokens.spacing.*`.
- **Typography:** display/body/mono/jp families from tokens and preserve uppercase/micro-lettering treatment where possible.
- **Motion:** animate using `--ryoku-ease` and ~0.62/0.28/0.54s durations.
- **Reveal:** implement threshold+staggered reveal semantics before complex panel transitions.
- **Curvature fix (current session context):** shell corners come from:
  - `Config.border.rounding` for hard frame corner radius.
  - `Tokens.rounding.*` for card surfaces (`StyledRect.radius = Tokens.rounding.normal` in several shell modules).
  - Active user override path is `~/.config/ryoku/shell.json`, so set `appearance.rounding.scale` and `border.rounding` there first.

Suggested next baseline values for “slightly curved” (already applied):
- `appearance.rounding.scale: 0.6`
- `border.rounding: 7`
- `border.thickness: 9`

---

## 10) Source references for quick lookup

### Files used
- `app/components/HeroSection.vue`
- `app/components/ProofStrip.vue`
- `app/components/DownloadSection.vue`
- `app/components/ReleaseTrailSection.vue`
- `app/components/GalleryBand.vue`
- `app/components/ExtrasSection.vue`
- `app/components/SystemSection.vue`
- `app/components/WaitlistForm.vue`
- `app/components/WaveBar.vue`
- `app/components/shared/AppLinkButton.vue`
- `app/components/shared/SiteLogo.vue`
- `app/components/SiteHeader.vue`
- `app/components/SiteFooter.vue`
- `app/plugins/reveal.client.ts`
- `app/layouts/default.vue`
- `app/pages/index.vue`
- `app/assets/css/base.css`
- `app/assets/css/tokens.css`
- `app/composables/useRyokuVersion.ts`
- `app/composables/useRyokuSite.ts`
- `shared/ryoku-site.ts`
- `nuxt.config.ts`
- `tests/marketing.spec.ts`
- `tests/snap-layout.mjs`
- `tests/snap-section.mjs`
- `tests/snap-gallery.mjs`
- `tests/snap-element.mjs`
- `public/social-card.svg`
- `public/logos/logo-mark.svg`
- `public/favicon.svg`

### Shell code that controls radius behavior
- `shell/plugin/src/Ryoku/Config/appearanceconfig.hpp`
- `shell/plugin/src/Ryoku/Config/appearanceconfig.cpp`
- `shell/plugin/src/Ryoku/Config/tokens.hpp`
- `shell/plugin/src/Ryoku/Config/tokens.cpp`
- `shell/plugin/src/Ryoku/Config/config.cpp`
- `shell/plugin/src/Ryoku/Config/borderconfig.hpp`
- `shell/modules/drawers/ContentWindow.qml`
- `shell/modules/bar/BarWrapper.qml`
- `shell/modules/sidebar/Content.qml`
- `shell/modules/sidebar/Wrapper.qml`
- `shell/modules/utilities/Wrapper.qml`
