#!/bin/bash

# script installation location
SCRIPT_FILE="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"

# environment variable defaults
MTGA_INSTALL_DIR=${MTGA_INSTALL_DIR:-"$HOME/.local/share/mtga"}
MTGA_ARCH=${MTGA_ARCH:-}
MTGA_LOG_DEBUG=${MTGA_LOG_DEBUG:-1}
MTGA_FORCE_INSTALL=${MTGA_FORCE_INSTALL:-0}
MTGA_FORCE_ARCH=${MTGA_FORCE_ARCH:-0}
MTGA_WIN32_VERSION_URL=${MTGA_WIN32_VERSION_URL:-"https://mtgarena.downloads.wizards.com/Live/Windows32/version"}
MTGA_WIN64_VERSION_URL=${MTGA_WIN64_VERSION_URL:-"https://mtgarena.downloads.wizards.com/Live/Windows64/version"}
MTGA_VERSION_URL=${MTGA_VERSION_URL:-}
DXVK_RELEASE_URL=${DXVK_RELEASE_URL:-"https://api.github.com/repos/doitsujin/dxvk/releases/latest"}

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
        log-debug "removing '$1'"
        rm -rf "$1"
    fi
}

noisy-rm-empty-dir() {
    if [[ -d "$1" ]]; then
        log-debug "removing '$1'"
        rmdir "$1"
    fi
}

noisy-rm-file() {
    if [[ -f "$1" ]]; then
        log-debug "removing '$1'"
        rm -f "$1"
    fi
}

TEMP_DIR_LIST=()
create-temp-dir() {
    TEMP_DIR=$(mktemp -d -t 'mtga.tmp.XXXXXXXXXX')
    TEMP_DIR_LIST+=( "$TEMP_DIR" )
    trap cleanup-create-temp-dir EXIT

    log-debug "creating temporary directory '$TEMP_DIR'"
}

cleanup-create-temp-dir() {
    log-debug "removing temporary files"

    for TEMP_DIR in "${TEMP_DIR_LIST[@]}"; do
        noisy-rm-dir "$TEMP_DIR"
    done
}

make-workaround-reg() {
    cat > "$1" <<EOF
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"UseTakeFocus"="N"
EOF
}

check-wine-arch() {
    log-info "checking wine architecture"

    if [[ -f "$MTGA_INSTALL_DIR/winearch" ]]; then
        INSTALLED_ARCH="$(cat "$MTGA_INSTALL_DIR/winearch")"

        if [[ -z "$MTGA_ARCH" ]]; then
            MTGA_ARCH="$INSTALLED_ARCH"
            log-info "using installed architecture '$MTGA_ARCH'"
        elif [[ "$MTGA_ARCH" != "$INSTALLED_ARCH" ]]; then
            log-error "installed architecture '$INSTALLED_ARCH' doesn't match MTGA_ARCH '$MTGA_ARCH'"

            if [[ "$MTGA_FORCE_ARCH" -eq 1 ]]; then
                log-warn "forcing use of architecture '$MTGA_ARCH'"
            else
                exit 1
            fi
        fi
    else
        MTGA_ARCH=win32
        log-info "defaulting to architecture '$MTGA_ARCH'"
    fi
}

fetch-mtga-installer() {
    log-debug "getting latest installer URL"

    if [[ -z "$MTGA_VERSION_URL" ]]; then
        if [[ "$MTGA_ARCH" == win32 ]]; then
            MTGA_VERSION_URL="$MTGA_WIN32_VERSION_URL"
        elif [[ "$MTGA_ARCH" == win64 ]]; then
            MTGA_VERSION_URL="$MTGA_WIN64_VERSION_URL"
        else
            log-error "could not find version URL for architecture '$MTGA_ARCH'"
            exit 1
        fi
    fi

    INSTALLER_JSON="$(curl --silent "$MTGA_VERSION_URL")"
    INSTALLER_URL="$(jq -r '.CurrentInstallerURL' <<< "$INSTALLER_JSON")"
    INSTALLER_VERSION="$(jq -r '.Versions | keys[]' <<< "$INSTALLER_JSON" | head -n1)"

    if [[ "$INSTALLER_JSON" == "" ]]; then
        log-error "failed to get latest version information"
        exit 1
    fi

    if [[ "$INSTALLER_URL" == "" ]]; then
        log-error "failed to extract installer URL from latest version information"
        exit 1
    fi

    if [[ "$INSTALLER_VERSION" == "" ]]; then
        log-error "failed to extract version number from latest version information"
        exit 1
    fi

    log-info "latest version is $INSTALLER_VERSION"
    if [[ -f "$MTGA_INSTALL_DIR/version" ]]; then
        CURRENT_VERSION="$(cat "$MTGA_INSTALL_DIR/version")"

        log-info "current version is $CURRENT_VERSION"

        if [[ "$INSTALLER_VERSION" == "$CURRENT_VERSION" ]]; then
            log-info "mtga-wine is up to date"

            if [[ "$MTGA_FORCE_INSTALL" -eq 1 ]]; then
                log-warn "forcing reinstallation"
            else
                exit 0
            fi
        fi
    fi

    log-debug "downloading latest installer"
    curl -o "$1" "$INSTALLER_URL"

    if [[ $? -ne 0 ]]; then
        log-error "failed to download latest installer"
        exit 1
    fi
}

fetch-dxvk-installer() {
    log-debug "getting latest release URL"
    RELEASE_JSON="$(curl --silent "$DXVK_RELEASE_URL")"
    RELEASE_URL="$(jq -r '.assets[].browser_download_url' <<< "$RELEASE_JSON" | head -n1)"
    RELEASE_VERSION="$(jq -r '.tag_name' <<< "$RELEASE_JSON")"

    if [[ "$RELEASE_JSON" == "" ]]; then
        log-error "failed to get latest release information"
        exit 1
    fi

    if [[ "$RELEASE_URL" == "" ]]; then
        log-error "failed to extract release URL from latest release information"
        exit 1
    fi

    if [[ "$RELEASE_VERSION" == "" ]]; then
        log-error "failed to extract version number from latest release information"
        exit 1
    fi

    log-info "latest DXVK version is $RELEASE_VERSION"
    if [[ -f "$MTGA_INSTALL_DIR/dxvk-version" ]]; then
        CURRENT_VERSION="$(cat "$MTGA_INSTALL_DIR/dxvk-version")"

        log-info "current DXVK version is $CURRENT_VERSION"

        if [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
            log-info "DXVK is up to date"

            if [[ "$MTGA_FORCE_INSTALL" -eq 1 ]]; then
                log-warn "forcing reinstallation"
            else
                exit 0
            fi
        fi
    fi

    log-debug "downloading latest release"
    curl -L -o "$1" "$RELEASE_URL"

    if [[ $? -ne 0 ]]; then
        log-error "failed to download latest release"
        exit 1
    fi
}

mtga-run-in-prefix() {
    mkdir -p "$MTGA_INSTALL_DIR/prefix"
    WINEARCH="$MTGA_ARCH" WINEPREFIX="$MTGA_INSTALL_DIR/prefix" "$@"
}

mtga-wine() {
    mtga-run-in-prefix wine "$@"
}

# check for needed programs

MISSING_PROGRAMS=0
check-installed wine
check-installed curl
check-installed jq
check-installed tar
check-installed mktemp

if [[ $MISSING_PROGRAMS -ne 0 ]]; then
    log-error "aborting due to missing required commands"
    exit 1
fi

# check variables for validity

if [[ -n "$MTGA_ARCH" && "$MTGA_ARCH" != "win32" && "$MTGA_ARCH" != "win64" ]]; then
    log-error "invalid wine architecture '$MTGA_ARCH'"
    exit 1
fi

# commands

mtga-run() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed, please install first"
        exit 1
    fi

    log-info "running mtga-wine"

    check-wine-arch

    mkdir -p "$MTGA_INSTALL_DIR/cache"

    (
        cd "$MTGA_INSTALL_DIR/cache"
        mtga-wine "C:/Program Files/Wizards of the Coast/MTGA/MTGA.exe"
    )
}

mtga-install() {
    if [[ -e "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is already installed"

        if [[ "$MTGA_FORCE_INSTALL" -eq 1 ]]; then
            log-warn "forcing reinstallation"
        else
            exit 1
        fi
    fi

    log-info "installing mtga-wine"

    check-wine-arch

    log-debug "creating wine prefix"
    mtga-wine wineboot

    log-debug "saving wine architecture"
    echo "$MTGA_ARCH" > "$MTGA_INSTALL_DIR/winearch"

    log-debug "setting windows version to win7"
    mtga-wine winecfg /v win7

    create-temp-dir

    log-debug "setting workaround registry keys"
    make-workaround-reg "$TEMP_DIR/workaround.reg"
    mtga-wine regedit /C "$TEMP_DIR/workaround.reg"

    fetch-mtga-installer "$TEMP_DIR/mtga-installer.msi"

    log-info "running latest installer"
    mtga-wine msiexec /i "$TEMP_DIR/mtga-installer.msi" /qn

    log-debug "saving current version"
    echo "$INSTALLER_VERSION" > "$MTGA_INSTALL_DIR/version"

    log-info "finished installing mtga-wine"
}

mtga-update() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed, please install first"
        exit 1
    fi

    log-info "updating mtga-wine"

    check-wine-arch

    create-temp-dir

    fetch-mtga-installer "$TEMP_DIR/mtga-installer.msi"

    log-info "running latest installer"
    mtga-wine msiexec /i "$TEMP_DIR/mtga-installer.msi" /qn

    log-debug "saving current version"
    echo "$INSTALLER_VERSION" > "$MTGA_INSTALL_DIR/version"

    log-info "update infinished"
}

mtga-uninstall() {
    log-info "uninstalling mtga-wine"
    noisy-rm-dir "$MTGA_INSTALL_DIR/prefix"
    noisy-rm-dir "$MTGA_INSTALL_DIR/cache"
    noisy-rm-file "$MTGA_INSTALL_DIR/version"
    noisy-rm-file "$MTGA_INSTALL_DIR/dxvk-version"
    noisy-rm-file "$MTGA_INSTALL_DIR/winearch"
    noisy-rm-empty-dir "$MTGA_INSTALL_DIR"
}

mtga-install-dxvk() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed, please install first"
        exit 1
    fi

    if [[ -f "$MTGA_INSTALL_DIR/dxvk-version" ]]; then
        log-error "DXVK is already installed"

        if [[ "$MTGA_FORCE_INSTALL" -eq 1 ]]; then
            log-warn "forcing reinstallation"
        else
            exit 1
        fi
    fi

    log-info "installing DXVK into mtga-wine"

    check-wine-arch

    create-temp-dir

    fetch-dxvk-installer "$TEMP_DIR/dxvk.tar.gz"

    log-debug "extracting latest release"
    tar -C "$TEMP_DIR" --strip-components=1 -xf "$TEMP_DIR/dxvk.tar.gz"

    if [[ $? -ne 0 ]]; then
        log-error "failed to extract latest release"
        exit 1
    fi

    log-info "running DXVK setup script"
    mtga-run-in-prefix "$TEMP_DIR/setup_dxvk.sh" install

    log-debug "saving current version"
    echo "$RELEASE_VERSION" > "$MTGA_INSTALL_DIR/dxvk-version"

    log-info "finished installing DXVK"
}

mtga-update-dxvk() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed, please install first"
        exit 1
    fi

    if [[ ! -f "$MTGA_INSTALL_DIR/dxvk-version" ]]; then
        log-error "DXVK is not installed, please install first"
        exit 1
    fi

    log-info "updating DXVK in mtga-wine"

    check-wine-arch

    create-temp-dir

    fetch-dxvk-installer "$TEMP_DIR/dxvk.tar.gz"

    log-debug "extracting latest release"
    tar -C "$TEMP_DIR" --strip-components=1 -xf "$TEMP_DIR/dxvk.tar.gz"

    if [[ $? -ne 0 ]]; then
        log-error "failed to extract latest release"
        exit 1
    fi

    log-info "running DXVK setup script"
    mtga-run-in-prefix "$TEMP_DIR/setup_dxvk.sh" install

    log-debug "saving current version"
    echo "$RELEASE_VERSION" > "$MTGA_INSTALL_DIR/dxvk-version"

    log-info "finished installing DXVK"
}

mtga-uninstall-dxvk() {
    if [[ ! -d "$MTGA_INSTALL_DIR/prefix" ]]; then
        log-error "mtga-wine is not installed"
        exit 1
    fi

    if [[ ! -f "$MTGA_INSTALL_DIR/dxvk-version" ]]; then
        log-info "DXVK is not installed"
        exit 1
    fi

    log-info "uninstalling DXVK from mtga-wine"

    check-wine-arch

    create-temp-dir

    noisy-rm-file "$MTGA_INSTALL_DIR/dxvk-version"

    fetch-dxvk-installer "$TEMP_DIR/dxvk.tar.gz"

    log-debug "extracting latest release"
    tar -C "$TEMP_DIR" --strip-components=1 -xf "$TEMP_DIR/dxvk.tar.gz"

    if [[ $? -ne 0 ]]; then
        log-error "failed to extract latest release"
        exit 1
    fi

    log-info "running DXVK uninstall script"
    mtga-run-in-prefix "$TEMP_DIR/setup_dxvk.sh" uninstall

    log-info "finished uninstalling DXVK"
}

mtga-help() {
    echo "${W}usage:${N} $(basename "$0") [command]"
    echo
    echo "${W}commands:${N}"
    echo " - run ............. run MTG Arena"
    echo " - install ......... download MTG Arena and prepare wine prefix"
    echo " - update .......... update MTG Arena to the latest version"
    echo " - uninstall ....... remove MTG arena wine prefix"
    echo " - install-dxvk .... install DXVK into the wine prefix"
    echo " - update-dxvk ..... update DXVK in the wine prefix"
    echo " - uninstall-dxvk .. uninstall DXVK from the wine prefix"
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
    run) mtga-run;;
    install) mtga-install;;
    update) mtga-update;;
    uninstall) mtga-uninstall;;
    install-dxvk) mtga-install-dxvk;;
    update-dxvk) mtga-update-dxvk;;
    uninstall-dxvk) mtga-uninstall-dxvk;;
    help) mtga-help;;
    *) mtga-invalid-usage;;
esac

exit 0
