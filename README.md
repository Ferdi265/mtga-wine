# `mtga-wine`

A simple script that manages a wine prefix for Magic: The Gathering Arena with
support for both 32 bit and 64 bit wine prefixes.

## Usage

```
usage: mtga-wine.sh [command]

commands:
 - run ............. run MTG Arena
 - install ......... download MTG Arena and prepare wine prefix
 - update .......... update MTG Arena to the latest version
 - uninstall ....... remove MTG arena wine prefix
 - install-dxvk .... install DXVK into the wine prefix
 - update-dxvk ..... update DXVK in the wine prefix
 - uninstall-dxvk .. uninstall DXVK from the wine prefix
```

## Installation

Just put the script anywhere you would like to run it from. The default
installation directory is `~/.local/share/mtga`.

Then, run `mtga-wine.sh install` to set up the prefix and install Magic: The
Gathering Arena. To install the 64 bit version of Magic: The Gathering Arena,
run `MTGA_ARCH=win64 mtga-wine.sh install` instead (later commands will
automatically detect 32 bit or 64 bit). Updated versions of Magic:
The Gathering Arena can be installed by running `mtga-wine.sh update`.

## Updating

You can update Magic: The Gathering Arena with `mtga-wine.sh update`. This will
update the game if a newer version exists.

DXVK can be updated by running `mtga-wine.sh update-dxvk`.

## Uninstalling

Magic: The Gathering Arena can be uninstalled by running
`mtga-wine.sh uninstall`. This removes the whole wine prefix.

DXVK can be uninstalled separately with `mtga-wine.sh uninstall-dxvk`, though
this can be done more cleanly by just uninstalling and reinstalling (and not
running `mtga-wine.sh install-dxvk` afterwards).

## Environment Variables

`mtga-wine` can be configured via several environment variables:

- `MTGA_INSTALL_DIR` controls where the game's files will be stored (defaults to
  `~/.local/share/mtga`)
- `MTGA_ARCH` controls whether the 32 bit or 64 bit version of the game will be
  installed (defaults to `win32`, but this will change to `win64` soon, since
  the 32 bit client is no longer officially supported)
- `MTGA_LOG_DEBUG` controls whether `debug` log messages are displayed (defaults
  to `1`)

There are also several advanced configuration variables that shouldn't normally
be needed:

- `MTGA_FORCE_INSTALL` disables checking whether a new version is available when
  set to `1` and always reinstalls the latest version (defaults to `0`)
- `MTGA_FORCE_ARCH` disables checking the architecture that was saved when
  installing when set to `1` and always uses the architecture specified in
  `MTGA_ARCH` (defaults to `0`)
- `MTGA_VERSION_URL` controls the URL where the version information JSON for new
  versions of the game is retrieved from (defaults to the value of
  `MTGA_WIN32_VERSION_URL` or `MTGA_WIN64_VERSION_URL` depending on the
  architecture)
- `MTGA_WIN32_VERSION_URL` defaults to
  https://mtgarena.downloads.wizards.com/Live/Windows32/version
- `MTGA_WIN64_VERSION_URL` defaults to
  https://mtgarena.downloads.wizards.com/Live/Windows64/version
- `DXVK_RELEASE_URL` controls the URL where the version information JSON for new
  releases of DXVK is retrieved from (defaults to
  https://api.github.com/repos/doitsujin/dxvk/releases/latest)

## Dependencies

This script needs the following programs to work:

- `wine`
- `curl`
- `jq`
- `tar`
- `mktemp` (part of GNU coreutils)
