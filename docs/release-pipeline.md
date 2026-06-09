# Ryoku ISO Build Pipeline

How a Ryoku ISO gets built and signed. The local equivalent
of this flow is `iso/bin/ryoku-iso-release` (uses 1Password for
credentials); CI uses GitHub Secrets instead.

## What runs in CI

`.github/workflows/build-iso.yml` builds the ISO end to end on a
GitHub-hosted `ubuntu-latest` runner:

1. Checkout (full history so `.git` ships into the ISO via `--local-source`)
2. Prepare a support tracking ID (`r<run-number>-<short-sha>`) and pass it
   into the ISO build. The live image also gets `/etc/ryoku-iso-release`
   with the same ID, commit, run URL, installer channel `main`, and build
   timestamp.
3. Verify required secrets are present, fail with a clear message if not
4. Free disk space on the runner (strip preinstalled toolchains we do not use)
5. Build the ISO via `iso/bin/ryoku-iso-make --local-source --no-boot-offer`
6. Mount the built ISO live root and run Trivy against it. The workflow uploads
   an ISO SARIF report and blocks release artifact handling on critical CVEs or
   misconfigurations before anything is signed or uploaded.
7. Sign the ISO with the GPG key from `GPG_PRIVATE_KEY` secret, then export
   the public key as `ryoku-release-key.pub.asc` so testers can verify
8. Generate `<iso>.sha256` containing the iso + sig hashes
9. Generate `<iso>.json`, `<iso>.js`, and `stable`-level `latest.json` /
   `latest.js` release manifests
10. Upload the ISO, signature, checksum, manifests, and public key to the
   configured artifact store via rclone
11. Attach the same files as a workflow-run artifact for 14 days as a fallback
12. Send the Discord build-complete notice after every prior step succeeds

## Triggers

- `workflow_dispatch` (manual). Pick the public release stage (`alpha`, `beta`, `stable`). Builds use the stable artifact path internally while public ISO downloads are paused.
- Pushing a `v*` tag (e.g. `v0.1.0`). Builds the same stable artifact set.

## Version channels

Ryoku uses one tracked release version in the root `VERSION` file and derives
channel-specific display versions from it:

- `main` is the stable update channel. It receives tagged releases only.
- `unstable-dev` is the rolling preview channel. Every push can be consumed by
  users who selected the unstable channel in Settings.
- `PATCH` is for stable hotfixes, such as updater, boot, login, security, or
  data-loss fixes.
- `MINOR` is for feature batches after they have soaked in `unstable-dev`.
- `MAJOR` is reserved for breaking release eras or migration-heavy changes.

Unstable builds do not consume stable patch numbers. They display the next
tracked release target plus dev metadata:

```text
v0.2.0-alpha.0.dev.17+gb6c391a
```

Stable releases display the tracked version directly:

```text
v0.2.0-alpha.0
```

The helper scripts are:

- `bin/ryoku-release-version`: computes the channel display version.
- `bin/ryoku-release-bump`: computes the next `patch`, `minor`, or `major`
  tracked release version.

## Automated channel workflows

`.github/workflows/release-channel-versions.yml` validates the channel version
policy on pull requests and pushes to `main` or `unstable-dev`. On every
`unstable-dev` push, it moves the `unstable-dev-latest` tag to the pushed
commit. That tag is a marker for the newest rolling dev build, not a stable
release tag.

`.github/workflows/stable-release.yml` is the stable release button. Run it
from `main`, choose `patch`, `minor`, or `major`, choose the public stage
(`alpha`, `beta`, or `stable`), and leave `dispatch_iso` enabled when the ISO
should publish. The workflow updates `VERSION`, commits the release bump, tags
`v<version>`, pushes the tag, then dispatches `build-iso.yml` for that tag.

## GitHub Secrets the workflow needs

Configure under **Settings -> Secrets and variables -> Actions** in the repo.

| Secret | Required | Purpose |
|---|---|---|
| `R2_ACCESS_KEY_ID` | yes | Cloudflare R2 API token, access key ID |
| `R2_SECRET_ACCESS_KEY` | yes | Cloudflare R2 API token, secret access key |
| `R2_ENDPOINT` | yes | Account-scoped R2 endpoint, e.g. `https://<account>.r2.cloudflarestorage.com` |
| `R2_BUCKET` | optional | Bucket + prefix to upload into. Defaults to `ryoku/stable`. Set to e.g. `ryoku-iso/stable` if you use a different bucket name. |
| `R2_SHELL_BUCKET` | optional | Bucket served at `shell.ryoku.dev`, where the shell installer's `install.sh` is published. Can be the ISO bucket (`ryoku-iso`) with `shell.ryoku.dev` added as a second custom domain, or a separate bucket. |
| `R2_SHELL_ACCESS_KEY_ID` | optional | Access key ID for a dedicated shell-bucket token. If unset, the publish falls back to `R2_ACCESS_KEY_ID` (works when the shell shares the ISO bucket). |
| `R2_SHELL_SECRET_ACCESS_KEY` | optional | Secret for that dedicated token; falls back to `R2_SECRET_ACCESS_KEY`. |
| `GPG_PRIVATE_KEY` | yes | Armored private GPG signing key, full block including `-----BEGIN PGP PRIVATE KEY BLOCK-----` and `-----END PGP PRIVATE KEY BLOCK-----` |
| `GPG_PASSPHRASE` | optional | Passphrase for the GPG key, omit if the key has no passphrase |
| `DISCORD_ISO_WEBHOOK_URL` | optional | Discord webhook for ISO build-complete notices. If unset, the ISO still builds and uploads, but no Discord message is sent. |

## Setting up Cloudflare R2

1. Cloudflare dashboard -> R2 -> Create bucket. Name it whatever (the workflow defaults to `ryoku/stable` as the upload path; if your bucket is also named `ryoku` you do not need to set `R2_BUCKET`).
2. R2 -> Manage R2 API Tokens -> Create token. Permission: "Object Read & Write" on this bucket only. Copy the access key ID + secret access key when shown (they are not shown again).
3. From the bucket detail page, copy the S3-compatible endpoint URL: `https://<account>.r2.cloudflarestorage.com`.
4. Bucket settings -> Public Access stays private while public ISO downloads are paused. Do not document or expose a public ISO download domain until beta opens.
5. Add the three R2 values + the `GPG_PRIVATE_KEY` (and passphrase if any) to GitHub Secrets.

## Hosting the shell installer (shell.ryoku.dev)

`shell.ryoku.dev/install.sh` is the one-command entry for the standalone shell
installer. It is just `shell-install/boot.sh`: the bootstrap clones the repo and
runs the live installer, so the hosted file rarely changes and the URL is
permanent (the installer always pulls the current repo, nothing is hardcoded).

`.github/workflows/publish-shell-installer.yml` re-uploads `boot.sh` as
`install.sh` whenever it changes on `main` (or on manual dispatch). It uploads to
`R2_SHELL_BUCKET` using `R2_SHELL_ACCESS_KEY_ID` / `R2_SHELL_SECRET_ACCESS_KEY` if
set, otherwise the ISO token (`R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`). With
no credentials or bucket it logs a warning and skips, so it is safe to merge
before the bucket exists.

One-time setup (Cloudflare side, not scriptable from CI):

1. Pick the bucket. Simplest is to reuse the ISO bucket (`ryoku-iso`): its token
   already has write access, so no new credentials are needed. Or create a
   separate bucket and dedicated token (then set the `R2_SHELL_*` secrets).
2. Bucket -> Settings -> Public access -> Connect a custom domain -> `shell.ryoku.dev`.
   Cloudflare adds the DNS record; the bucket root then serves at
   `https://shell.ryoku.dev/`, so `shell.ryoku.dev/install.sh` maps to
   `<bucket>/install.sh`.
3. Set the `R2_SHELL_BUCKET` secret to the bucket name.
4. Push a `boot.sh` change (or run the workflow manually) to publish `install.sh`.

Unlike the ISO, this object is meant to be public: it is a one-line bootstrap,
so the custom domain's public access is expected.

## Setting up the GPG signing key

If you do not already have a Ryoku release key:

```bash
gpg --quick-generate-key 'Ryoku Releases <releases@ryoku.dev>' rsa4096 sign 5y
```

Pick a passphrase or skip it (passphrase-protected is more secure; CI handles both).

Export the private key as an ASCII-armored block:

```bash
gpg --armor --export-secret-keys 'releases@ryoku.dev' > ryoku-release-key.asc
```

Paste the entire contents (including the `-----BEGIN`/`-----END` lines) into the
GitHub Secret `GPG_PRIVATE_KEY`. **Delete `ryoku-release-key.asc` from disk after pasting.**

Export the public key for users to verify against:

```bash
gpg --armor --export 'releases@ryoku.dev' > ryoku-release-key.pub.asc
```

Commit `ryoku-release-key.pub.asc` to the repo (or publish to a key
server) so users have something to verify against. Standard locations:

- `keys/ryoku-release-key.pub.asc` in the repo (canonical, bound to the
  source tree under tag history)
- The configured artifact store alongside each release ISO, if public ISO
  downloads are reopened later
- The Ryoku website once stable downloads reopen

For the in-repo copy, also document the key fingerprint in `README.md`
so a substituted pubkey would be obvious. Get it with:

```bash
gpg --with-colons --import-options show-only --import ryoku-release-key.pub.asc \
  | awk -F: '/^fpr/ { print $10; exit }'
```

## Triggering a build

Manual:

1. GitHub repo -> Actions -> Build ISO
2. Run workflow -> select public release stage -> Run

For the current alpha, use release stage `alpha`.

Tag a release:

```bash
git tag -a v0.1.0 -m "Ryoku v0.1.0"
git push origin v0.1.0
```

Either kicks off the workflow. ~30-60 min on cold cache (DKMS overlay
compiles dominate). The workflow page shows live logs and the final
artifact upload. Discord build notices are sent only after the ISO build,
live-root Trivy gate, signature, checksums, manifests, public key, and workflow
artifact have all finished successfully.

Public ISO download links are intentionally not included while alpha downloads
are paused. The build-complete notice points to the project site for status
updates, records the tracking ID, and posts up to five commit subjects plus a
full compare link when previous release metadata is available.

## Artifact Layout

After a successful run, the configured artifact store has:

```
ryoku/stable/
├── latest.json
├── latest.js
├── ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso
├── ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso.sig
├── ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso.sha256
├── ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso.json
├── ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso.js
└── ryoku-release-key.pub.asc
```

The tracking ID is the `r12-9019b9b` segment in the example above. Ask
users for this value when triaging ISO or installer reports. In a booted
live ISO it is also available at `/etc/ryoku-iso-release`.

`latest.json` and `latest.js` are release metadata for maintainers. Public ISO
download links stay out of the website and docs until beta opens. The manifest
contains the current tracking ID, commit, workflow run URL, filenames, optional
artifact URLs, and SHA256 values for the ISO and detached signature.

## Verify A Local Or Private ISO Build

```bash
# Run these from the directory containing a local or private ISO build,
# its detached signature, and its sha256 file.
iso=ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso

# Import the public key, then check that its fingerprint matches the
# one published in the project README before trusting it.
gpg --import keys/ryoku-release-key.pub.asc
gpg --with-colons --import-options show-only --import keys/ryoku-release-key.pub.asc \
  | awk -F: '/^fpr/ { print $10; exit }'

# Check the signature on the ISO
gpg --verify $iso.sig $iso
# Expected output: "Good signature from Ryoku Releases <releases@ryoku.dev>"

# Cross-check the sha256
sha256sum -c $iso.sha256
# Expected output: "ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso: OK"
```

## Failure modes worth knowing

- **Disk space exhausted on runner**. Visible as `mkarchiso` failing to write the squashfs. The `Free disk space` step strips ~25 GB of preinstalled toolchains; if a future bump pushes the build past that, switch to a self-hosted runner or use a `larger` GitHub-hosted runner.
- **Build timeout**. Workflow `timeout-minutes: 120`. Cold builds rarely exceed 60 min; if Apple T2 or `linux-ptl` get added to the boot overlay later, this may need to grow.
- **Trivy blocks publish**. The built live root has a critical CVE or
  misconfiguration. Open the `trivy-iso` code-scanning result or the workflow
  table output, update or remove the affected package/config, and rerun the ISO
  build.
- **GPG sign fails**. Usually a malformed `GPG_PRIVATE_KEY` (missing the BEGIN/END lines, or a stray newline broke the armored block). Re-export and re-paste.
- **rclone upload fails**. Typically an `R2_ENDPOINT` mismatch (must be the account-scoped one, not the bucket URL).

## Local equivalent (no CI required)

`iso/bin/ryoku-iso-release v0.1.0` does the same chain locally if you have:

- 1Password CLI (`op`) logged into the Ryoku account, OR
- Manually configured `~/.config/rclone/rclone.conf` with the `[Ryoku]` remote
- A GPG signing key in your default keyring

This is the path used pre-CI. Once CI is set up, prefer CI for shareable
releases (reproducible runner) and use the local script for one-off
builds you only intend to give to one person.
