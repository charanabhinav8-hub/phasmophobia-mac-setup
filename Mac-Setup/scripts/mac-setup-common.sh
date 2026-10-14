#!/bin/bash
# Shared by the Mac setup commands. Compatible with macOS /bin/bash 3.2.
# Sourcing this file performs no installation, network access, or filesystem writes.

CREATOR_VERSION='1.0.2'
CREATOR_ARCHIVE_NAME='Creator-v1.0.2.tar.xz'
CREATOR_URL='https://github.com/Sikarugir-App/Creator/releases/download/v1.0.2/Creator-v1.0.2.tar.xz'
CREATOR_SHA256='e7852e78a02b6958708563e87aedf55986cbf6a7e6d6bcb3d661d8fccb15b7bd'
CREATOR_BUNDLE_NAME='Sikarugir Creator.app'
TEMPLATE_VERSION='1.0.21'
TEMPLATE_ROOT='Template-1.0.21.app'
TEMPLATE_URL='https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.21.tar.xz'
TEMPLATE_SHA256='bbe996e4e4375318485953d0c7818b7b4b0a4dc1f13303bcc584f99f7602f78d'
ENGINE_NAME='WS12WineSikarugir11.0_1'
ENGINE_URL='https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir11.0_1.tar.xz'
ENGINE_SHA256='67e29fb3d74f363af39c69ba11f9b13a79812c5db07cf4748672658e4a200a0e'
STEAM_INSTALLER_URL='https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'
STEAM_INSTALLER_SHA256='7d3654531c32d941b8cae81c4137fc542172bfa9635f169cb392f245a0a12bcb'
MINIMUM_MACOS='14.6'

say() { printf '%s\n' "$*"; }
warn() { printf 'NOTICE: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; return 1; }

version_at_least() {
    # Numeric comparison; 14.10 must sort after 14.6.
    local actual_major actual_minor actual_patch required_major required_minor required_patch
    local actual="$1" required="$2"
    case "$actual" in ''|*[!0-9.]*) return 1 ;; esac
    case "$required" in ''|*[!0-9.]*) return 1 ;; esac
    IFS=. read -r actual_major actual_minor actual_patch <<EOF
$actual
EOF
    IFS=. read -r required_major required_minor required_patch <<EOF
$required
EOF
    actual_minor=${actual_minor:-0}; actual_patch=${actual_patch:-0}
    required_minor=${required_minor:-0}; required_patch=${required_patch:-0}
    case "$actual_patch$required_patch" in *.*) return 1 ;; esac
    [ "$actual_major" -gt "$required_major" ] && return 0
    [ "$actual_major" -lt "$required_major" ] && return 1
    [ "$actual_minor" -gt "$required_minor" ] && return 0
    [ "$actual_minor" -lt "$required_minor" ] && return 1
    [ "$actual_patch" -ge "$required_patch" ]
}

check_platform() {
    local platform hardware_arm
    platform=$(uname -s)
    [ "$platform" = Darwin ] || { fail 'Run this command on the Mac. Windows and Linux cannot run the Mac Wine engine.'; return 1; }
    MACOS_VERSION=$(sw_vers -productVersion) || return 1
    version_at_least "$MACOS_VERSION" "$MINIMUM_MACOS" || {
        fail "Sikarugir requires macOS $MINIMUM_MACOS or later; this Mac has $MACOS_VERSION. Update macOS before continuing."
        return 1
    }
    hardware_arm=$(sysctl -n hw.optional.arm64 2>/dev/null || true)
    [ "$hardware_arm" = 1 ] || {
        fail 'This kit targets an Apple Silicon Mac (M1/M2/M3/M4 or later). It is not configured for Intel Macs.'
        return 1
    }
    say "Mac check: macOS $MACOS_VERSION, Apple Silicon."
}

rosetta_installed() {
    pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1
}

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

verify_sha256() {
    local observed
    [ -f "$1" ] || return 1
    observed=$(sha256_file "$1") || return 1
    [ "$observed" = "$2" ]
}

download_verified() {
    # destination is our cache; a mismatch is never extracted or executed.
    local url="$1" expected="$2" destination="$3" stage="$4"
    if verify_sha256 "$destination" "$expected"; then
        say "Using verified cached download: $(basename "$destination")"
        return 0
    fi
    say "Downloading $(basename "$destination") from the official GitHub release..."
    curl --proto '=https' --proto-redir '=https' --fail --location --show-error \
        --retry 3 --connect-timeout 20 --max-time 600 --output "$stage/download.part" "$url" || {
        fail 'Download failed. Check the Internet connection, then run setup again.'; return 1;
    }
    verify_sha256 "$stage/download.part" "$expected" || {
        fail 'The download did not match the pinned SHA-256. Installation stopped; the file was not extracted or run.'
        return 1
    }
    mv "$stage/download.part" "$destination" || return 1
    say "SHA-256 verified: $expected"
}

check_archive_root() {
    local archive="$1" listing="$2" root="$3" entry
    tar -tf "$archive" > "$listing" || return 1
    [ -s "$listing" ] || { fail 'The archive is empty.'; return 1; }
    while IFS= read -r entry; do
        case "$entry" in
            "$root"|"$root/"|"$root/"*) ;;
            *) fail "Unexpected archive entry: $entry"; return 1 ;;
        esac
        case "/$entry/" in
            */../*|*/./*) fail 'Unsafe archive path; installation stopped.'; return 1 ;;
        esac
    done < "$listing"
}

check_creator_archive() { check_archive_root "$1" "$2" "$CREATOR_BUNDLE_NAME"; }

normalize_game_path() {
    # Accept a game directory or Phasmophobia.exe; retain spaces literally.
    local candidate="$1"
    candidate=${candidate%/}
    case "$candidate" in
        *.exe|*.EXE) candidate=$(dirname "$candidate") ;;
    esac
    if [ -d "$candidate/Phasmophobia" ] && [ ! -f "$candidate/Phasmophobia.exe" ]; then
        candidate="$candidate/Phasmophobia"
    fi
    [ -d "$candidate" ] || { fail "Game folder not found: $candidate"; return 1; }
    (cd "$candidate" && pwd -P)
}

validate_executable() {
    local folder="$1" executable="$2"
    case "$executable" in
        ''|/*|*\\*|*:*|*\"*|*$'\n'*|*$'\r'*) fail 'The executable must be a relative Windows .exe path inside the game folder.'; return 1 ;;
    esac
    case "/$executable/" in */../*|*/./*) fail 'The executable path must stay inside the game folder.'; return 1 ;; esac
    case "$executable" in *.exe|*.EXE) ;; *) fail 'Choose a Windows .exe file.'; return 1 ;; esac
    [ -f "$folder/$executable" ] || { fail "Selected executable not found: $folder/$executable"; return 1; }
}

validate_game_folder() {
    local folder="$1" missing='' file
    for file in Phasmophobia.exe UnityPlayer.dll GameAssembly.dll; do
        if [ ! -f "$folder/$file" ]; then missing="$missing $file"; fi
    done
    [ -d "$folder/Phasmophobia_Data" ] || missing="$missing Phasmophobia_Data/"
    [ -z "$missing" ] || { fail "Incomplete game folder; missing:$missing"; return 1; }
    say "Game files found: $folder"
    say 'File presence is confirmed. Launch and multiplayer compatibility still need a test on the Mac.'
}

read_plist() {
    /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null
}

clear_app_quarantine() { /usr/bin/xattr -drs com.apple.quarantine "$1"; }
repair_app_signature() { /usr/bin/codesign --force --deep --sign - "$1"; }
verify_app_signature() { /usr/bin/codesign --verify --deep "$1"; }
set_plist_string() { /usr/bin/plutil -replace "$2" -string "$3" "$1"; }

wine_prefix_ready() {
    local prefix="$1" first_line
    [ -s "$prefix/system.reg" ] && [ -s "$prefix/user.reg" ] &&
        [ -f "$prefix/drive_c/windows/system32/kernel32.dll" ] || return 1
    IFS= read -r first_line < "$prefix/system.reg" || return 1
    first_line=${first_line%$'\r'}
    [ "$first_line" = 'WINE REGISTRY Version 2' ] || return 1
    IFS= read -r first_line < "$prefix/user.reg" || return 1
    first_line=${first_line%$'\r'}
    [ "$first_line" = 'WINE REGISTRY Version 2' ]
}

wrapper_is_prepared() {
    local wrapper="$1" prefix="$1/Contents/SharedSupport/prefix"
    local marker="$1/Contents/Resources/phasmo-mac-setup.txt" program
    [ -f "$marker" ] && [ "$(head -n 1 "$marker")" = 'phasmo-mac-setup v1' ] || return 1
    [ -x "$wrapper/Contents/MacOS/wineskinlauncher" ] &&
        [ -x "$wrapper/Contents/SharedSupport/wine/bin/wine" ] || return 1
    wine_prefix_ready "$prefix" || return 1
    [ -L "$prefix/drive_c/Phasmophobia" ] && [ -d "$prefix/drive_c/Phasmophobia" ] &&
        [ -s "$prefix/drive_c/phasmo-kit/launch-game.bat" ] || return 1
    program=$(read_plist "$wrapper/Contents/Info.plist" 'Program Name and Path') || return 1
    [ "$program" = '/phasmo-kit/launch-game.bat' ]
}

check_creator_bundle() {
    local bundle="$1" identifier
    [ -f "$bundle/Contents/Info.plist" ] || return 1
    [ -x "$bundle/Contents/MacOS/Sikarugir Creator" ] || return 1
    identifier=$(read_plist "$bundle/Contents/Info.plist" CFBundleIdentifier) || return 1
    [ "$identifier" = 'com.sikarugir.Sikarugir-Creator' ]
}

find_windows_steam() {
    local prefix="$1" candidate
    for candidate in \
        "$prefix/drive_c/Program Files (x86)/Steam/steam.exe" \
        "$prefix/drive_c/Program Files (x86)/Steam/Steam.exe" \
        "$prefix/drive_c/Program Files/Steam/steam.exe" \
        "$prefix/drive_c/Program Files/Steam/Steam.exe"; do
        if [ -f "$candidate" ]; then printf '%s\n' "$candidate"; return 0; fi
    done
    return 1
}
