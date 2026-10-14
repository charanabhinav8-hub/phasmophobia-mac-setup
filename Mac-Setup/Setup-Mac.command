#!/bin/bash
# Free, user-scoped Sikarugir preparation for an Apple Silicon Mac.
# Tested for Bash 3.2-compatible syntax; a real Mac is required for installation.
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=scripts/mac-setup-common.sh
source "$SCRIPT_DIR/scripts/mac-setup-common.sh"
source "$SCRIPT_DIR/scripts/prepare-wrapper.sh"

MODE='install'
GAME_FOLDER=''
GAME_EXE=''
OPEN_APPS=1
PAUSE=0
STAGE_DIR=''
LOG_FILE=''
if [ "$#" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then PAUSE=1; fi

usage() {
    cat <<'EOF'
Usage: bash Setup-Mac.command [--check | --dry-run] [--game PATH] [--exe FILE] [--no-open] [--no-pause]

  --check     Check this Mac, Rosetta, and game files. Make no changes or downloads.
  --dry-run   Show the exact installation plan. Works on Windows Git Bash too.
  --game PATH Location of the complete game folder, or its Phasmophobia.exe.
  --exe FILE  Relative executable inside the game folder; defaults to Launcher.exe
              when present, otherwise Phasmophobia.exe.
  --no-open   Prepare the wrapper without opening Finder or the guide.
  --no-pause  Return immediately at the end (useful when run from Terminal).
  --help      Show these options.

This prepares the free Mac compatibility tools. It does not prove the game or
multiplayer works on the Mac, and does not include a game, engine, or Steam account.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check) MODE=check ;;
        --dry-run) MODE=dry-run ;;
        --game)
            [ "$#" -ge 2 ] || { fail '--game requires a path.'; exit 2; }
            GAME_FOLDER=$2; shift ;;
        --exe)
            [ "$#" -ge 2 ] || { fail '--exe requires a relative executable path.'; exit 2; }
            GAME_EXE=$2; shift ;;
        --no-open) OPEN_APPS=0 ;;
        --no-pause) PAUSE=0 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

cleanup_and_pause() {
    local result=$?
    trap - EXIT
    if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
        # mktemp created this exact private staging directory for this invocation.
        case "$STAGE_DIR" in
            "$CACHE_DIR"/stage.*) rm -rf -- "$STAGE_DIR" ;;
        esac
    fi
    if [ "$result" -ne 0 ]; then
        printf '\nSetup stopped (exit %s). Resolve the error above and rerun.\n' "$result" >&2
    fi
    if [ -n "$LOG_FILE" ]; then printf '\nSetup log: %s\n' "$LOG_FILE"; fi
    if [ "$PAUSE" -eq 1 ]; then
        printf '\nPress Return to close this window. '
        IFS= read -r _reply || true
    fi
    exit "$result"
}
trap cleanup_and_pause EXIT

if [ -z "$GAME_FOLDER" ] && [ -d "$SCRIPT_DIR/../Phasmophobia" ]; then
    GAME_FOLDER="$SCRIPT_DIR/../Phasmophobia"
fi
if [ -n "$GAME_FOLDER" ]; then
    GAME_FOLDER=$(normalize_game_path "$GAME_FOLDER")
    validate_game_folder "$GAME_FOLDER"
    if [ -z "$GAME_EXE" ]; then
        if [ -f "$GAME_FOLDER/Launcher.exe" ]; then GAME_EXE=Launcher.exe; else GAME_EXE=Phasmophobia.exe; fi
    fi
    validate_executable "$GAME_FOLDER" "$GAME_EXE"
fi

if [ "$MODE" = dry-run ]; then
    cat <<EOF
DRY RUN - no installation, network access, or writes.

Target: Apple Silicon Mac with macOS $MINIMUM_MACOS or later.
1. Check Rosetta 2. If absent, run Apple's interactive Rosetta installer.
2. Download $CREATOR_URL
3. Require SHA-256 $CREATOR_SHA256
4. Extract only the verified Creator archive into a private staging folder.
5. Apply the official cask's app-local quarantine/signature repair to that new copy.
6. Install to ~/Applications/$CREATOR_BUNDLE_NAME, preserving any existing app.
7. Download and verify Template $TEMPLATE_VERSION and $ENGINE_NAME.
8. Build ~/Applications/Sikarugir/Phasmophobia.app, preserving unrelated wrappers.
9. Use the official launcher's WSS-wineprefixcreate command to create its prefix.
10. Link the complete game folder, configure a launcher with the correct working
    directory, and leave DXMT as the default Direct3D 11 backend.
11. Cache the verified official Windows Steam installer for Steam-Mac.command.

Cache: ~/Library/Caches/Phasmo-Mac-Setup
Logs: ~/Library/Logs/Phasmo-Mac-Setup
No Homebrew, paid compatibility software, or system Gatekeeper changes are used.
The guide covers first launch, Steam, graphics fallbacks, and multiplayer checks.
EOF
    exit 0
fi

check_platform
case "$HOME" in /*) ;; *) fail 'HOME must be an absolute Mac user directory.'; exit 1 ;; esac
[ "$HOME" != / ] && [ -d "$HOME" ] || { fail 'No valid Mac user home directory was found.'; exit 1; }
[ "$(id -u)" -ne 0 ] || { fail 'Run setup as your normal Mac user, without sudo.'; exit 1; }

APP_DIR="$HOME/Applications"
CREATOR_APP="$APP_DIR/$CREATOR_BUNDLE_NAME"
WRAPPER_APP="$APP_DIR/Sikarugir/Phasmophobia.app"
CACHE_DIR="$HOME/Library/Caches/Phasmo-Mac-Setup"
LOG_DIR="$HOME/Library/Logs/Phasmo-Mac-Setup"

if [ "$MODE" = check ]; then
    CHECK_RESULT=0
    if rosetta_installed; then say 'Rosetta 2: installed.'; else warn 'Rosetta 2: not found. Run setup normally to open Apple’s installer.'; CHECK_RESULT=1; fi
    if check_creator_bundle "$CREATOR_APP"; then
        say "Creator: installed at $CREATOR_APP"
    elif [ -e "$CREATOR_APP" ]; then
        warn "Creator: an unexpected item exists at $CREATOR_APP. Setup will preserve it and stop."
        CHECK_RESULT=1
    else
        say 'Creator: not yet installed in your Applications folder.'
        CHECK_RESULT=1
    fi
    if [ -z "$GAME_FOLDER" ]; then
        warn 'Game folder not found beside the kit. Rerun with --game followed by the complete folder path.'
        CHECK_RESULT=1
    fi
    if wrapper_is_prepared "$WRAPPER_APP"; then
        say "Wrapper: configured with its game link and initialized prefix at $WRAPPER_APP"
    else
        say 'Wrapper: missing or incomplete. Run Setup-Mac.command normally to prepare it.'
        CHECK_RESULT=1
    fi
    if find_windows_steam "$WRAPPER_APP/Contents/SharedSupport/prefix" >/dev/null; then
        say 'Windows Steam: installed in the game wrapper; sign-in must be checked in its window.'
    else
        say 'Windows Steam: not found in this wrapper. Run Steam-Mac.command after setup.'
        CHECK_RESULT=1
    fi
    say 'Check finished; no downloads or files were changed.'
    exit "$CHECK_RESULT"
fi

if [ -z "$GAME_FOLDER" ]; then
    say 'Select the complete game folder in the Finder dialog.'
    if ! GAME_FOLDER=$(/usr/bin/osascript -e 'POSIX path of (choose folder with prompt "Select the complete Phasmophobia folder")'); then
        say 'Folder selection was cancelled. Nothing was installed. Run setup again when the game folder is on this Mac.'
        exit 0
    fi
    GAME_FOLDER=$(normalize_game_path "$GAME_FOLDER")
    validate_game_folder "$GAME_FOLDER"
    if [ -z "$GAME_EXE" ]; then
        if [ -f "$GAME_FOLDER/Launcher.exe" ]; then GAME_EXE=Launcher.exe; else GAME_EXE=Phasmophobia.exe; fi
    fi
    validate_executable "$GAME_FOLDER" "$GAME_EXE"
fi

mkdir -p "$LOG_DIR" "$CACHE_DIR"
LOG_FILE="$LOG_DIR/setup-$(date '+%Y%m%d-%H%M%S')-$$.log"
exec > >(tee -a "$LOG_FILE") 2>&1
say 'Preparing Sikarugir for an Apple Silicon Mac.'
say "Pinned release: Creator $CREATOR_VERSION (official GitHub archive)."

if ! rosetta_installed; then
    say 'Rosetta 2 is required. Apple’s installer will ask you to read and accept its license.'
    if [ ! -t 0 ]; then
        fail 'Open Terminal, run: /usr/sbin/softwareupdate --install-rosetta ; then rerun setup.'
        exit 1
    fi
    /usr/sbin/softwareupdate --install-rosetta || {
        fail 'Rosetta was not installed. Complete Apple’s installer, then rerun setup.'; exit 1;
    }
    rosetta_installed || { fail 'The Rosetta installation receipt is still missing. Restart the Mac if Apple requested it, then rerun setup.'; exit 1; }
fi

say 'Rosetta 2: installed.'

if [ -e "$CREATOR_APP" ] || [ -L "$CREATOR_APP" ]; then
    check_creator_bundle "$CREATOR_APP" || {
        fail "An unexpected or incomplete app already exists at $CREATOR_APP. Move that item aside in Finder and rerun. Setup has left it untouched."
        exit 1
    }
    say "Keeping your existing Creator app: $CREATOR_APP"
else
    mkdir -p "$APP_DIR" "$APP_DIR/Sikarugir"
    STAGE_DIR=$(mktemp -d "$CACHE_DIR/stage.XXXXXXXX")
    ARCHIVE="$CACHE_DIR/$CREATOR_ARCHIVE_NAME"
    download_verified "$CREATOR_URL" "$CREATOR_SHA256" "$ARCHIVE" "$STAGE_DIR"
    check_creator_archive "$ARCHIVE" "$STAGE_DIR/archive-list.txt"
    tar -xf "$ARCHIVE" -C "$STAGE_DIR"
    STAGED_APP="$STAGE_DIR/$CREATOR_BUNDLE_NAME"
    check_creator_bundle "$STAGED_APP" || { fail 'The verified release did not contain the expected Creator app.'; exit 1; }
    say 'Applying the official cask’s app-local signature repair to the verified new Creator copy.'
    /usr/bin/xattr -drs com.apple.quarantine "$STAGED_APP"
    /usr/bin/codesign --force --deep --sign - "$STAGED_APP"
    /usr/bin/codesign --verify --deep "$STAGED_APP"
    # Never replace a user app if another setup process created it while downloading.
    [ ! -e "$CREATOR_APP" ] && [ ! -L "$CREATOR_APP" ] || { fail 'Creator appeared during setup. Rerun to reuse that app.'; exit 1; }
    mv "$STAGED_APP" "$CREATOR_APP"
    say "Installed Creator: $CREATOR_APP"
fi

mkdir -p "$APP_DIR/Sikarugir"
if [ -z "$STAGE_DIR" ]; then STAGE_DIR=$(mktemp -d "$CACHE_DIR/stage.XXXXXXXX"); fi
prepare_wrapper "$WRAPPER_APP" "$GAME_FOLDER" "$GAME_EXE" "$CACHE_DIR" "$STAGE_DIR"
if find_windows_steam "$WRAPPER_APP/Contents/SharedSupport/prefix" >/dev/null; then
    say 'Windows Steam is already installed in this game wrapper. Use Steam-Mac.command to open it.'
else
    if ! download_verified "$STEAM_INSTALLER_URL" "$STEAM_INSTALLER_SHA256" "$CACHE_DIR/SteamSetup.exe" "$STAGE_DIR"; then
        warn 'The game wrapper is prepared, but the Steam installer could not be cached. Steam-Mac.command will retry; the README includes the official download path.'
    fi
    say 'Windows Steam still needs installation and sign-in. Run Steam-Mac.command next.'
fi

if [ -n "$GAME_FOLDER" ]; then
    printf '%s\n' "$GAME_FOLDER" > "$CACHE_DIR/game-folder.txt"
fi

if [ "$OPEN_APPS" -eq 1 ]; then
    /usr/bin/open -R "$WRAPPER_APP" || true
    if [ -n "$GAME_FOLDER" ]; then /usr/bin/open -R "$GAME_FOLDER/Phasmophobia.exe" || true; fi
    if [ -f "$SCRIPT_DIR/README.html" ]; then /usr/bin/open "$SCRIPT_DIR/README.html" || true; fi
fi

cat <<EOF

Your Mac wrapper is prepared. Run Steam-Mac.command to install/open Windows Steam
in this same wrapper and sign in. Then open Phasmophobia.app for the first launch.
The game has not been tested on this Mac yet.

Creator: $CREATOR_APP
Wrapper: $WRAPPER_APP
Executable: $GAME_EXE
Game folder: ${GAME_FOLDER:-not selected; use --game when the files are on this Mac}
EOF
