# Ryoku ISO Release Pipeline

How a Ryoku ISO gets built, signed, and published. The local equivalent
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
   an ISO SARIF report and blocks publishing on critical CVEs or
   misconfigurations before anything is signed or uploaded.
7. Sign the ISO with the GPG key from `GPG_PRIVATE_KEY` secret, then export
   the public key as `ryoku-release-key.pub.asc` so testers can verify
8. Generate `<iso>.sha256` containing the iso + sig hashes
9. Generate `<iso>.json`, `<iso>.js`, and `stable`-level `latest.json` /
   `latest.js` release manifests
10. Upload the ISO, signature, checksum, manifests, and public key to
   Cloudflare R2 via rclone
11. Attach the same files as a workflow-run artifact for 14 days as a fallback
12. Send the public Discord ISO announcement after every prior step succeeds

## Triggers

- `workflow_dispatch` (manual). Pick the public release stage (`alpha`, `beta`, `stable`). All builds publish under the `stable` download path.
- Pushing a `v*` tag (e.g. `v0.1.0`). Builds and publishes the same `stable` download path.

## GitHub Secrets the workflow needs

Configure under **Settings -> Secrets and variables -> Actions** in the repo.

| Secret | Required | Purpose |
|---|---|---|
| `R2_ACCESS_KEY_ID` | yes | Cloudflare R2 API token, access key ID |
| `R2_SECRET_ACCESS_KEY` | yes | Cloudflare R2 API token, secret access key |
| `R2_ENDPOINT` | yes | Account-scoped R2 endpoint, e.g. `https://<account>.r2.cloudflarestorage.com` |
| `R2_BUCKET` | optional | Bucket + prefix to upload into. Defaults to `ryoku/stable`. Set to e.g. `ryoku-iso/stable` if you use a different bucket name. |
| `GPG_PRIVATE_KEY` | yes | Armored private GPG signing key, full block including `-----BEGIN PGP PRIVATE KEY BLOCK-----` and `-----END PGP PRIVATE KEY BLOCK-----` |
| `GPG_PASSPHRASE` | optional | Passphrase for the GPG key, omit if the key has no passphrase |
| `DISCORD_ISO_WEBHOOK_URL` | optional | Discord webhook for public ISO release announcements. If unset, the ISO still builds and uploads, but no Discord message is sent. |

## Setting up Cloudflare R2

1. Cloudflare dashboard -> R2 -> Create bucket. Name it whatever (the workflow defaults to `ryoku/stable` as the upload path; if your bucket is also named `ryoku` you do not need to set `R2_BUCKET`).
2. R2 -> Manage R2 API Tokens -> Create token. Permission: "Object Read & Write" on this bucket only. Copy the access key ID + secret access key when shown (they are not shown again).
3. From the bucket detail page, copy the S3-compatible endpoint URL: `https://<account>.r2.cloudflarestorage.com`.
4. Bucket settings -> Public Access -> enable the `r2.dev` subdomain (development only, rate-limited) OR connect a custom domain (recommended for production). Ryoku uses the custom domain `iso.ryoku.dev` connected via Cloudflare DNS.
5. Add the three R2 values + the `GPG_PRIVATE_KEY` (and passphrase if any) to GitHub Secrets.

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
- The R2 bucket alongside each release ISO (uploaded automatically by
  the workflow as a fallback for users who only have the ISO URL)
- `https://ryoku.dev/release-key.asc` once the site is live

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
artifact upload. Discord release announcements are sent only after the ISO
build, live-root Trivy gate, signature, checksums, manifests, public key, and
workflow artifact have all finished successfully.

The release announcement sends users to `https://ryoku.dev` for the ISO,
signature, checksum, and public key. It reads the previous `latest.json`
before upload, compares that manifest's commit to the new build commit on
`main`, and posts up to five commit subjects plus a full compare link. If no
previous manifest exists, it falls back to the latest five commits on `main`.

## Where users download

After a successful run, the bucket has:

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

Public download URLs (served through Cloudflare CDN via the
`iso.ryoku.dev` custom domain):

```
https://iso.ryoku.dev/stable/latest.json
https://iso.ryoku.dev/stable/latest.js
https://iso.ryoku.dev/stable/ryoku-<date>-<tracking-id>-x86_64-main.iso
https://iso.ryoku.dev/stable/ryoku-<date>-<tracking-id>-x86_64-main.iso.sig
https://iso.ryoku.dev/stable/ryoku-<date>-<tracking-id>-x86_64-main.iso.sha256
https://iso.ryoku.dev/stable/ryoku-<date>-<tracking-id>-x86_64-main.iso.json
https://iso.ryoku.dev/stable/ryoku-<date>-<tracking-id>-x86_64-main.iso.js
https://iso.ryoku.dev/stable/ryoku-release-key.pub.asc
```

`latest.json` is the website source of truth. `latest.js` exposes the same
payload as `window.RYOKU_ISO_RELEASE` for static pages that cannot fetch JSON
directly. The manifest contains the current tracking ID, commit, workflow run
URL, filenames, public URLs, and SHA256 values for the ISO and detached
signature. Do not make the website guess the ISO name from the latest workflow
date.

## How users verify the ISO

```bash
# Download the iso, sig, sha256, and the public key. The pubkey is now
# published in two places (pick whichever is reachable):
#   * R2 bucket alongside the ISO         (no GitHub access needed)
#   * GitHub repo at keys/                (signed via tag history)
iso=ryoku-2026.05.11-r12-9019b9b-x86_64-main.iso
curl -LO https://iso.ryoku.dev/stable/$iso
curl -LO https://iso.ryoku.dev/stable/$iso.sig
curl -LO https://iso.ryoku.dev/stable/$iso.sha256
curl -LO https://iso.ryoku.dev/stable/$iso.json
curl -LO https://iso.ryoku.dev/stable/$iso.js
curl -LO https://iso.ryoku.dev/stable/ryoku-release-key.pub.asc
# OR, equivalently:
# curl -LO https://raw.githubusercontent.com/neur0map/ryoku-arch/main/keys/ryoku-release-key.pub.asc

# Import the public key, then check that its fingerprint matches the
# one published in the project README before trusting it.
gpg --import ryoku-release-key.pub.asc
gpg --with-colons --import-options show-only --import ryoku-release-key.pub.asc \
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
