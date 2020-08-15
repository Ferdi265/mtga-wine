#!/bin/bash

# script installation location
SCRIPT_FILE="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"

# environment variable defaults
DESTDIR="${DESTDIR:-"$HOME/.local/share"}"
MTGA_VERSION_URL="${MTGA_VERSION_URL:-"https://mtgarena.downloads.wizards.com/Live/Windows32/version"}"

# output color variables
# (see 'man console_codes', section 'ECMA-48 Set Graphics Rendition')
R=$'\e[1;31m'
G=$'\e[1;32m'
Y=$'\e[1;33m'
B=$'\e[1;34m'
W=$'\e[1;37m'
N=$'\e[0m'

# check for needed programs
MISSING_PROGRAMS=0

check-installed() {
    type -p "$1" >/dev/null
    if [[ $? -ne 0 ]]; then
        echo "${R}error:${N} the '$1' command is missing!"
        MISSING_PROGRAMS=1
    fi
}

check-installed curl
check-installed jq
check-installed mktemp
check-installed wine
check-installed winetricks

if [[ $MISSING_PROGRAMS -ne 0 ]]; then
    echo "${R}error:${N} aborting due to missing required commands"
    exit 1
fi

# utility functions
noisy-rm-dir() {
    if [[ -d "$1" ]]; then
        echo "${W}info:${N} removing '$1'"
        rm -rf "$1"
    fi
}

temp-dir() {
    mktemp -d -t 'mtga.tmp.XXXXXXXXXX'
}

make-workaround-reg() {
    cat > "$1" <<EOF
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"UseTakeFocus"="N"
EOF
}

mtga-wine() {
    mkdir -p "$DESTDIR/mtga/prefix"
    WINEPREFIX="$DESTDIR/mtga/prefix" wine "$@"
}

mtga-winetricks() {
    mkdir -p "$DESTDIR/mtga/prefix"
    WINEPREFIX="$DESTDIR/mtga/prefix" winetricks "$@"
}

# commands
mtga-install() {
    if [[ -e "$DESTDIR/mtga/prefix" ]]; then
        echo "${R}error:${N} mtga-wine is already installed"
        exit 1
    fi

    echo "${W}info:${N} installing mtga-wine"

    echo "${B}debug:${N} creating wine prefix"
    mtga-wine wineboot

    echo "${B}debug:${N} setting windows version to win7"
    mtga-wine winecfg /v win7

    echo "${B}debug:${N} setting workaround registry keys"
    TEMP_DIR="$(temp-dir)"
    make-workaround-reg "$TEMP_DIR/workaround.reg"
    mtga-wine regedit /C "$TEMP_DIR/workaround.reg"

    echo "${B}debug:${N} removing temporary files"
    rm -rf "$TEMP_DIR"

    echo "${B}debug:${N} running initial update"
    mtga-update
}

mtga-update() {
    if [[ ! -d "$DESTDIR/mtga/prefix" ]]; then
        echo "${R}error:${N} mtga-wine is not installed, please install first"
        exit 1
    fi

    echo "${W}info:${N} updating mtga-wine"

    echo "${B}debug:${N} getting latest installer URL"
    INSTALLER_URL="$(curl --silent "$MTGA_VERSION_URL" | jq -r ".CurrentInstallerURL")"

    echo "${B}debug:${N} downloading installer"
    TEMP_DIR="$(temp-dir)"
    curl -o "$TEMP_DIR/mtga-installer.msi" "$INSTALLER_URL"

    echo "${B}debug:${N} running latest installer"
    mtga-wine msiexec /i "$TEMP_DIR/mtga-installer.msi" /qn

    echo "${B}debug:${N} removing temporary files"
    rm -rf "$TEMP_DIR"
}

mtga-run() {
    if [[ ! -d "$DESTDIR/mtga/prefix" ]]; then
        echo "${R}error:${N} mtga-wine is not installed, please install first"
        exit 1
    fi

    mtga-wine "C:/Program Files/Wizards of the Coast/MTGA/MTGA.exe"
}

mtga-run-nogc() {
    GC_DONT_GC=1 mtga-run
}

mtga-uninstall() {
    echo "${W}info:${N} uninstalling mtga-wine"
    noisy-rm-dir "$DESTDIR/mtga/prefix"
    noisy-rm-dir "$DESTDIR/mtga"
}

mtga-help() {
    echo "${W}usage:${N} $0 [command]"
    echo
    echo "${W}commands:${N}"
    echo " - install${N} .... download MTG Arena and prepare wine prefix"
    echo " - update${N} ..... patch MTG Arena to the latest version"
    echo " - run${N} ........ run MTG Arena"
    echo " - run-nogc${N} ... run MTG Arena (without garbage collector)"
    echo " - uninstall${N} .. remove MTG arena wine prefix"
}

mtga-invalid-usage() {
    echo "${R}error:${N} invalid usage"
    mtga-help
    exit 1
}

# invocation
if [[ $# -ne 1 ]]; then
    mtga-invalid-usage
fi

case "$1" in
    install) mtga-install;;
    update) mtga-update;;
    run) mtga-run;;
    run-nogc) mtga-run-nogc;;
    uninstall) mtga-uninstall;;
    help) mtga-help;;
    *) mtga-invalid-usage;;
esac

exit 0
