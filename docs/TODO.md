# Ryoku Todo

## Omarchy-Style Release Signing

Goal: match Omarchy's signing structure for stable readiness: signed ISO artifacts, one published signing key, and a keyring package that carries the public key for repository/package trust. Full Secure Boot support and strict package-chain enforcement are later hardening items, not the first stable blocker.

### Release Key

- [ ] Use one Ryoku release signing key for:
  - ISO `.sig` files.
  - Ryoku repository package signatures.
  - the `ryoku-keyring` package payload.
- [ ] Publish the release key fingerprint in:
  - root `README.md`.
  - `docs/release-pipeline.md`.
  - `SECURITY.md`.
  - `ryoku.dev` download/verification copy.
- [ ] Export the public key with every public ISO release as `ryoku-release-key.pub.asc`.
- [ ] Document verification with:
  - `gpg --import ryoku-release-key.pub.asc`
  - `gpg --verify ryoku-*.iso.sig ryoku-*.iso`
  - `sha256sum -c ryoku-*.iso.sha256`

### ISO Artifacts

- [x] Build public ISOs only through GitHub Actions.
- [x] Produce and upload:
  - `.iso`
  - `.iso.sig`
  - `.iso.sha256`
  - exported public key.
- [x] Verify the detached ISO signature in CI before upload.
- [ ] Keep `.sig` available beside every ISO URL, matching the Omarchy pattern of `ISO_URL.sig`.
- [ ] Keep the latest stable, rc, and edge ISO paths predictable.

### Keyring Package

- [ ] Create `ryoku-keyring`.
- [ ] Package the Ryoku public signing key in `ryoku-keyring`.
- [ ] Install `ryoku-keyring` in:
  - live ISO.
  - installed systems.
  - update path before package-repo signing is tightened.
- [ ] Use `ryoku-keyring` for seamless future key rotation.

### Ryoku Package Repository

- [ ] Keep a Ryoku package repository for custom packages, following Omarchy's shape:
  - stable channel.
  - rc channel.
  - edge channel.
  - `$arch` path component.
- [ ] Sign Ryoku-built packages with the Ryoku release/package key.
- [ ] Add a `[ryoku]` pacman repo block for installed systems.
- [ ] Start with Omarchy-parity pacman trust behavior if needed:
  - `SigLevel = Optional TrustAll`
  - keyring package installed and documented.
- [ ] Move to stricter package verification after the keyring and package signing path is proven.

### Stable Release Requirements

- [ ] Stable can ship when the Omarchy-style release signing path is complete:
  - signed ISO.
  - adjacent `.sig`.
  - published fingerprint.
  - public key export.
  - `ryoku-keyring`.
  - documented verification flow.
- [ ] Clearly document that Secure Boot is not supported yet and should be disabled, matching Omarchy's current install posture.

### Later Hardening

- [ ] Remove `TrustAll` once signed package and repo DB verification are ready.
- [ ] Sign offline repository databases with `repo-add --sign`.
- [ ] Add CI failure gates for unsigned custom packages and unsigned repo databases.
- [ ] Add Secure Boot support:
  - signed EFI boot path.
  - signed UKIs.
  - install/update hooks to regenerate and sign UKIs.
  - verification with `sbverify` or `sbctl`.
