# ryoku-keyring

Ships the Ryoku release signing key into pacman's keyring so the `[ryoku]`
repository's signed packages verify on every machine.

## Contents
- `ryoku.gpg` -- the public key (binary export of `keys/ryoku-release-key.pub.asc`).
- `ryoku-trusted` -- `<fingerprint>:4:`, marks the key fully trusted.
- `ryoku-revoked` -- revoked fingerprints (empty until a key is retired).
- `ryoku-keyring.install` -- runs `pacman-key --populate ryoku` on install/upgrade.

The installer adds the `[ryoku]` repo to `/etc/pacman.conf` and installs this
package, then `pacman-key --populate ryoku` trusts the key.

## Rotating the key
1. Regenerate from the new public key:
   - `gpg --export <FPR> > ryoku.gpg`
   - `printf '%s:4:\n' <FPR> > ryoku-trusted`
   - add the old fingerprint to `ryoku-revoked`
2. Bump `pkgver` and rebuild/publish. Machines pick up the new trust on upgrade.

Current key: `Ryoku Releases <releases@ryoku.dev>`,
fingerprint `EB6D 3C0F 55A7 B3CA BA6B 2838 847B 274F 025D D6E3`.
