# ISO Tracking ID Design

## Goal

Every published Ryoku ISO needs a support-friendly tracking number that is visible in the filename, embedded in the live ISO, and published in machine-readable download metadata. When someone reports an installer failure, support can ask for the tracking ID and map it back to a GitHub Actions run and commit.

## Contract

CI builds use the tracking ID format `r<run-number>-<short-sha>`, for example `r12-9019b9b`. Local builds use `local-<utc-minute>-<short-sha>` unless `RYOKU_ISO_TRACKING_ID` is set explicitly.

Published ISO names use this shape:

```text
ryoku-YYYY.MM.DD-<tracking-id>-x86_64-<installer-ref>.iso
```

Example:

```text
ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso
```

## Build Pipeline

The workflow prepares release metadata before the ISO build, passes `SOURCE_DATE_EPOCH` and `RYOKU_ISO_TRACKING_ID` through `iso/bin/ryoku-iso-make`, and embeds `/etc/ryoku-iso-release` into the live image. The workflow then signs the ISO, regenerates checksums, creates a JSON manifest, and uploads all artifacts to R2.

## Download Metadata

Each ISO gets a per-file manifest named `<iso>.json`. The same content is copied to `latest.json` in the channel directory. The pipeline also writes `<iso>.js` and `latest.js`, assigning that same payload to `window.RYOKU_ISO_RELEASE`, so the static website can load release metadata without relying on R2 CORS headers. The manifest includes the tracking ID, channel, commit, run URL, filenames, public URLs, and SHA256 values for the ISO and detached signature.

## Website

The site should treat `latest.json` as the source of truth for downloads. It should display the tracking ID and use the manifest-provided filenames instead of guessing from the latest GitHub Actions date.
