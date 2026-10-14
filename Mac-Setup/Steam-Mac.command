#!/bin/bash
# Install/open Windows Steam in the SAME Sikarugir prefix as Phasmophobia.
set -euo pipefail
umask 077
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/scripts/mac-setup-common.sh"
MODE='run'
PAUSE=0
STAGE_DIR=''
LOG_FILE=''
if [ "$#" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then PAUSE=1; fi
while [ "$#" -gt 0 ]; do
    case "$1" in
        --check) MODE=check ;;
        --dry-run) MODE=dry-run ;;
        --no-pause) PAUSE=0 ;;
        --help|-h)
            say 'Usage: bash Steam-Mac.command [--check | --dry-run] [--no-pause]'
            say 'Normally installs Windows Steam if missing, or opens it in the game wrapper.'
            exit 0 ;;
        *) fail "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

WRAPPER_APP="$HOME/Applications/Sikarugir/Phasmophobia.app"
PREFIX="$WRAPPER_APP/Contents/SharedSupport/prefix"
CACHE_DIR="$HOME/Library/Caches/Phasmo-Mac-Setup"
cleanup_steam() {
    local result=$?
    trap - EXIT
    if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
        case "$STAGE_DIR" in "$CACHE_DIR"/stage.*) rm -rf -- "$STAGE_DIR" ;; esac
    fi
    if [ "$result" -ne 0 ]; then say "Steam setup stopped (exit $result). Read the error above; your game files were not modified."; fi
    if [ -n "$LOG_FILE" ]; then say "Log: $LOG_FILE"; fi
    if [ "$PAUSE" -eq 1 ]; then printf '\nPress Return to close this window. '; IFS= read -r _reply || true; fi
    exit "$result"
}
trap cleanup_steam EXIT

if [ "$MODE" = dry-run ]; then
    say 'DRY RUN - no downloads, installation, or writes.'
    say 'Use the Phasmophobia.app Wine prefix created by Setup-Mac.command.'
    say "If Steam is missing, download $STEAM_INSTALLER_URL"
    say "Require SHA-256: $STEAM_INSTALLER_SHA256"
    say 'Run: Contents/MacOS/wineskinlauncher WSS-installer <absolute SteamSetup.exe>'
    say 'If installed, run: Contents/MacOS/Sikarugir run <absolute steam.exe>'
    say 'Steam sign-in remains an interactive step. This does not use macOS Steam.'
    exit 0
fi

check_platform
[ "$(id -u)" -ne 0 ] || { fail 'Run as your normal Mac user, without sudo.'; exit 1; }
wrapper_is_prepared "$WRAPPER_APP" || {
    fail 'The game wrapper is not prepared. Run Setup-Mac.command successfully first.'; exit 1;
}

STEAM_EXE=$(find_windows_steam "$PREFIX" || true)
if [ "$MODE" = check ]; then
    if [ -n "$STEAM_EXE" ]; then say "Windows Steam found in the game wrapper: $STEAM_EXE"; exit 0; fi
    warn 'Windows Steam is not installed at its default location in this wrapper.'
    exit 1
fi

LOG_DIR="$HOME/Library/Logs/Phasmo-Mac-Setup"
mkdir -p "$CACHE_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/steam-$(date '+%Y%m%d-%H%M%S')-$$.log"
exec > >(tee -a "$LOG_FILE") 2>&1

if [ -z "$STEAM_EXE" ]; then
    STAGE_DIR=$(mktemp -d "$CACHE_DIR/stage.XXXXXXXX")
    INSTALLER="$CACHE_DIR/SteamSetup.exe"
    if ! download_verified "$STEAM_INSTALLER_URL" "$STEAM_INSTALLER_SHA256" "$INSTALLER" "$STAGE_DIR"; then
        say 'If Valve has published a newer installer, use the official Steam website link in the README.'
        say 'Open the game wrapper’s Contents/Configure.app, select Install Software, then Choose Setup Executable.'
        say 'Select that official SteamSetup.exe to keep Steam in this same wrapper.'
        exit 1
    fi
    say 'Installing Windows Steam into the game wrapper.'
    say 'In Steam Setup, keep its default installation folder.'
    say 'On the Finish page, uncheck Run Steam and finish; this command will open it afterward.'
    say 'If Steam already opened and this window is waiting, close Steam once to let the installer finish.'
    "$WRAPPER_APP/Contents/MacOS/wineskinlauncher" WSS-installer "$INSTALLER" || {
        fail 'The Steam installer did not finish successfully. Run this command again to retry.'; exit 1;
    }
    STEAM_EXE=$(find_windows_steam "$PREFIX" || true)
    [ -n "$STEAM_EXE" ] || {
        fail 'Steam was not found in the default folder. If you chose a custom folder, use Contents/Configure.app to run its steam.exe; otherwise rerun this installer.'
        exit 1
    }
fi

say 'Opening Windows Steam in the Phasmophobia wrapper.'
say 'Let Steam update, then sign in. Keep Steam running while opening Phasmophobia.app.'
say 'If this Terminal window stays busy while Steam is open, that is normal.'
say 'Game launch and multiplayer still require your test on this Mac.'
/usr/bin/open -R "$WRAPPER_APP" || true
"$WRAPPER_APP/Contents/MacOS/Sikarugir" run "$STEAM_EXE"
