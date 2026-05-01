# Roadmap

Ryoku is public while the first signed ISO and showcase materials are still being finished. This list is intentionally high-level: implementation notes live in code review and commit history, not in the public front door.

## Release Readiness

- [ ] Publish the first signed ISO and verification instructions.
- [ ] Add a stable download URL and an always-latest ISO pointer.
- [ ] Add public screenshots and a short navigation video to the README.
- [ ] Complete at least one fresh bare-metal install pass before calling the ISO stable.
- [ ] Smoke-test the online install fallback in addition to the offline ISO path.

## Security Workstation Baseline

- [ ] Define the default security-tooling set by category: recon, web, wireless, forensics, reverse engineering, wordlists, and reporting.
- [ ] Keep heavy, niche, or legally sensitive tools optional instead of default.
- [ ] Add a short "what ships by default" section once the first baseline lands.
- [ ] Document how to install optional tool packs without turning Ryoku into a kitchen-sink distribution.

## Shell And Visual Polish

- [ ] Finish the native Quickshell settings/control surfaces.
- [ ] Finish screenshot, recording, notifications, network, and audio popup polish.
- [ ] Keep desktop scale and dashboard sizing comfortable on compact high-DPI laptops.
- [ ] Add an in-system About/Credits surface for upstream acknowledgements.

## Infrastructure

- [ ] Move expensive AUR rebuilds toward a hosted Ryoku package repo after the release pipeline is stable.
- [ ] Continue expanding hardware coverage for Apple T2, Panther Lake, and other uncommon platforms.
- [ ] Keep legacy compatibility wrappers until existing installs have had a clear migration window.
