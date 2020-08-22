# `mtga-wine`

A simple script that manages a wine prefix for Magic: The Gathering Arena.

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

Just put the script anywhere you would like to run it from. The
`MTGA_INSTALL_DIR` environment variable controls where the wine prefix will be
placed.

The default installation directory is `~/.local/share/mtga`.

Then, run `mtga-wine.sh install` to set up the prefix and install Magic: The
Gathering Arena. Newer versions of Magic: The Gathering Arena can be installed
by running `mtga-wine.sh update`.

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

## Dependencies

This script needs the following programs to work:

- `wine`
- `curl`
- `jq`
- `tar`
- `mktemp` (part of GNU coreutils)
