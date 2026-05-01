# Ryoku ISO

The Ryoku ISO provides a guided Arch install path for Ryoku. It includes the Ryoku Configurator as a front end to archinstall and automatically launches the Ryoku installer after the base system is set up.

## Downloading the latest ISO

Signed public ISO links will be added to the root README when the first release is published.

## Creating the ISO

From the repository root, run `./iso/bin/ryoku-iso-make`. Output goes into `iso/release`. You can build from the local checkout for testing with `--local-source`.

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `RYOKU_INSTALLER_REPO` - GitHub repository for the installer (default: `neur0map/ryoku-arch`)
- `RYOKU_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `main`)

Example usage:
```bash
RYOKU_INSTALLER_REPO="myuser/ryoku-fork" RYOKU_INSTALLER_REF="some-feature" ./bin/ryoku-iso-make
```

## Testing the ISO

Run `./bin/ryoku-iso-boot [release/ryoku.iso]`.

## Signing the ISO

Run `./bin/ryoku-iso-sign [gpg-user] [release/ryoku.iso]`.

## Uploading the ISO

Run `./bin/ryoku-iso-upload [release/ryoku.iso]`. This requires you've configured rclone (use `rclone config`).

## Full release of the ISO

Run `./bin/ryoku-iso-release VERSION` to create, test, sign, and upload the ISO in one flow. Add `--rc` to release an RC build instead.
