#!/bin/bash
# Checks transfer integrity against the local Windows copy used to prepare this kit.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/scripts/mac-setup-common.sh"
GAME_FOLDER=''
MANIFEST="$SCRIPT_DIR/game-build.sha256"
VERIFY_SCOPE='Core game build'
PAUSE=0
if [ "$#" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then PAUSE=1; fi

finish() {
    local result=$?
    trap - EXIT
    if [ "$PAUSE" -eq 1 ]; then
        printf '\nPress Return to close this window. '
        IFS= read -r _reply || true
    fi
    exit "$result"
}
trap finish EXIT

while [ "$#" -gt 0 ]; do
    case "$1" in
        --game)
            [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: --game needs a path.' >&2; exit 2; }
            GAME_FOLDER=$2; shift ;;
        --full) MANIFEST="$SCRIPT_DIR/game-files.sha256"; VERIFY_SCOPE='Full game transfer' ;;
        --no-pause) PAUSE=0 ;;
        --help|-h)
            printf '%s\n' 'Usage: bash Verify-Game.command [--game FOLDER] [--full] [--no-pause]' \
                'Default: compare the six core build files with the original Windows copy.' \
                '--full: read all recorded game files; the 42 GiB transfer can take several minutes.' \
                'This never changes the game. Matching hashes do not prove publisher authenticity or multiplayer compatibility.'
            exit 0 ;;
        *) printf 'ERROR: Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

if [ -z "$GAME_FOLDER" ] && [ -d "$SCRIPT_DIR/../Phasmophobia" ]; then
    GAME_FOLDER="$SCRIPT_DIR/../Phasmophobia"
fi
if [ -z "$GAME_FOLDER" ] && [ "$(uname -s)" = Darwin ] && [ -t 0 ]; then
    GAME_FOLDER=$(/usr/bin/osascript -e 'POSIX path of (choose folder with prompt "Choose the complete Phasmophobia game folder")') || {
        printf '%s\n' 'No folder selected. No files were changed.'; exit 2;
    }
fi
[ -n "$GAME_FOLDER" ] || { printf '%s\n' 'ERROR: Put Mac-Setup beside Phasmophobia, or pass --game followed by its folder path.' >&2; exit 2; }
GAME_FOLDER=$(normalize_game_path "$GAME_FOLDER")
validate_game_folder "$GAME_FOLDER"
[ -s "$MANIFEST" ] || { printf '%s\n' 'ERROR: The fingerprint manifest is missing. Extract the complete Mac setup ZIP again.' >&2; exit 2; }
command -v shasum >/dev/null 2>&1 || { printf '%s\n' 'ERROR: shasum is required; it is supplied with macOS.' >&2; exit 2; }

printf '\n%s check. Reading files; nothing will be changed.\n' "$VERIFY_SCOPE"
if [ "$VERIFY_SCOPE" = 'Full game transfer' ]; then
    printf '%s\n' 'Please leave this window open. Large asset files take time to read.'
fi
if (cd "$GAME_FOLDER" && shasum -a 256 --check "$MANIFEST"); then
    printf '\n%s matches the Windows copy recorded for this kit.\n' "$VERIFY_SCOPE"
    printf '%s\n' 'Next test: launch on the Mac, join the same private lobby, then load a contract.'
else
    printf '\nSome files are missing or differ from the recorded Windows copy.\n' >&2
    printf '%s\n' 'Check the FAILED filenames above. Finish copying or compare the game version on both computers.' \
        'A legitimate game update also changes hashes; do not replace newer files just to match this old manifest.' >&2
    exit 1
fi
