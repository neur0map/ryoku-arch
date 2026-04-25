# Ryoku ISO

The Ryoku ISO streamlines [the installation of Ryoku](https://github.com/neur0map/ryoku-arch/2/the-ryoku-manual/50/getting-started). It includes the Ryoku Configurator as a front-end to archinstall and automatically launches the [Ryoku Installer](https://github.com/neur0map/ryoku-arch) after base arch has been setup.

## Downloading the latest ISO

See the ISO link on [github.com/neur0map/ryoku-arch](https://github.com/neur0map/ryoku-arch).

## Creating the ISO

Run `./bin/ryoku-iso-make` and the output goes into `./release`. You can build from your local $RYOKU_PATH for testing by using `--local-source` or from a checkout of the dev branch (instead of master) by using `--dev`.

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `RYOKU_INSTALLER_REPO` - GitHub repository for the installer (default: `neur0map/ryoku-arch`)
- `RYOKU_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)

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
