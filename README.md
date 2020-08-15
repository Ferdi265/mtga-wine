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
```

## Installation

Just put the script anywhere you would like to run it from. The
`MTGA_INSTALL_DIR` environment variable controls where the wine prefix will be
placed.

The default installation directory is `~/.local/share/mtga`.

Then, run `mtga install` to set up the prefix and install Magic: The Gathering
Arena. Newer versions of Magic: The Gathering Arena can be installed by running
`mtga update`.

## Dependencies

This script needs the following programs to work:

- `wine`
- `curl`
- `jq`
- `tar`
- `mktemp` (part of GNU coreutils)
