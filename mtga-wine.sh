#!/bin/bash

# script installation location
SCRIPT_FILE="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"

# environment variable defaults
MTGA_INSTALL_DIR="${MTGA_INSTALL_DIR:-"$HOME/.local/share/mtga"}"
MTGA_LOG_DEBUG=${MTGA_LOG_DEBUG:-1}
MTGA_VERSION_URL="${MTGA_VERSION_URL:-"https://mtgarena.downloads.wizards.com/Live/Windows32/version"}"

# output color variables
# (see 'man console_codes', section 'ECMA-48 Set Graphics Rendition')
R=$'\e[1;31m'
G=$'\e[1;32m'
Y=$'\e[1;33m'
B=$'\e[1;34m'
W=$'\e[1;37m'
N=$'\e[0m'

# utility functions

log-error() {
    echo "${R}error:${N} $1"
}

log-warn() {
    echo "${Y}warn:${N} $1"
}

log-info() {
    echo "${W}info:${N} $1"
}

log-debug() {
    if [[ $MTGA_LOG_DEBUG -eq 1 ]]; then
        echo "${B}debug:${N} $1"
    fi
}

check-installed() {
    type -p "$1" >/dev/null
    if [[ $? -ne 0 ]]; then
        log-error "the '$1' command is missing!"
        MISSING_PROGRAMS=1
    fi
}

noisy-rm-dir() {
    if [[ -d "$1" ]]; then
        log-info "removing '$1'"
        rm -rf "$1"
    fi
}

noisy-rm-file() {
    if [[ -f "$1" ]]; then
        log-info "removing '$1'"
        rm -f "$1"
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
    mkdir -p "$MTGA_INSTALL_DIR/prefix"
    WINEPREFIX="$MTGA_INSTALL_DIR/prefix" wine "$@"
}

# check for needed programs

MISSING_PROGRAMS=0
check-installed wine
check-installed curl
check-installed jq
check-installed mktemp

if [[ $MISSING_PROGRAMS -ne 0 ]]; then
    log-error "aborting due to missing required commands"
    exit 1
fi

# commands

mtga-install() {
    if [[ -e "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is already installed"
        exit 1
    fi

    log-info "installing mtga-wine"

    log-debug "creating wine prefix"
    mtga-wine wineboot

    log-debug "setting windows version to win7"
    mtga-wine winecfg /v win7

    log-debug "setting workaround registry keys"
    TEMP_DIR="$(temp-dir)"
    make-workaround-reg "$TEMP_DIR/workaround.reg"
    mtga-wine regedit /C "$TEMP_DIR/workaround.reg"

    log-debug "removing temporary files"
    rm -rf "$TEMP_DIR"

    log-info "running initial update"
    mtga-update

}

mtga-update() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed, please install first"
        exit 1
    fi

    log-info "updating mtga-wine"

    log-debug "getting latest installer URL"
    INSTALLER_JSON="$(curl --silent "$MTGA_VERSION_URL")"
    INSTALLER_URL="$(jq -r '.CurrentInstallerURL' <<< "$INSTALLER_JSON")"
    INSTALLER_VERSION="$(jq -r '.Versions | keys[]' <<< "$INSTALLER_JSON" | head -n1)"

    log-info "latest version is $INSTALLER_VERSION"
    if [[ -f "$MTGA_INSTALL_DIR/version" ]]; then
        CURRENT_VERSION="$(cat "$MTGA_INSTALL_DIR/version")"

        log-info "current version is $CURRENT_VERSION"

        if [[ "$INSTALLER_VERSION" == "$CURRENT_VERSION" ]]; then
            log-info "mtga-wine is up to date"
            return
        fi
    fi

    log-debug "downloading installer"
    TEMP_DIR="$(temp-dir)"
    curl -o "$TEMP_DIR/mtga-installer.msi" "$INSTALLER_URL"

    log-info "running latest installer"
    mtga-wine msiexec /i "$TEMP_DIR/mtga-installer.msi" /qn

    log-debug "removing temporary files"
    rm -rf "$TEMP_DIR"

    log-debug "saving current version"
    echo "$INSTALLER_VERSION" > "$MTGA_INSTALL_DIR/version"

    log-info "update infinished"
}

mtga-run() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed, please install first"
        exit 1
    fi

    (
        cd "$MTGA_INSTALL_DIR"
        mtga-wine "C:/Program Files/Wizards of the Coast/MTGA/MTGA.exe"
    )
}

mtga-run-nogc() {
    GC_DONT_GC=1 mtga-run
}

mtga-uninstall() {
    log-info "uninstalling mtga-wine"
    noisy-rm-dir "$MTGA_INSTALL_DIR/prefix"
    noisy-rm-file "$MTGA_INSTALL_DIR/version"
}

mtga-help() {
    echo "${W}usage:${N} $(basename "$0") [command]"
    echo
    echo "${W}commands:${N}"
    echo " - install${N} .... download MTG Arena and prepare wine prefix"
    echo " - update${N} ..... patch MTG Arena to the latest version"
    echo " - run${N} ........ run MTG Arena"
    echo " - run-nogc${N} ... run MTG Arena (without garbage collector)"
    echo " - uninstall${N} .. remove MTG arena wine prefix"
}

mtga-invalid-usage() {
    log-error "invalid usage"
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
