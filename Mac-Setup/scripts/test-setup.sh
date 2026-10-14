#!/bin/bash
# Offline regression checks. Run with macOS Bash or Git for Windows Bash.
# These mocks verify guardrails and path handling; they do not emulate macOS/Wine.
set -euo pipefail
TEST_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source "$TEST_SCRIPT_DIR/mac-setup-common.sh"
source "$TEST_SCRIPT_DIR/prepare-wrapper.sh"
# macOS ships shasum; Git for Windows ships the equivalent sha256sum instead.
if ! command -v shasum >/dev/null 2>&1; then
    shasum() { [ "$1" = -a ] && [ "$2" = 256 ] || return 2; shift 2; sha256sum "$@"; }
fi
TEST_BASE=$(cd "${TMPDIR:-/tmp}" && pwd -P)
TEST_ROOT=$(mktemp -d "$TEST_BASE/phasmo-mac-tests.XXXXXXXX")
TEST_COUNT=0
cleanup_tests() {
    case "$TEST_ROOT" in "$TEST_BASE"/phasmo-mac-tests.*) rm -rf -- "$TEST_ROOT" ;; esac
}
trap cleanup_tests EXIT

expect_success() {
    TEST_COUNT=$((TEST_COUNT + 1))
    if "$@" > "$TEST_ROOT/last-output.txt" 2>&1; then
        printf 'PASS %s: %s\n' "$TEST_COUNT" "$*"
    else
        cat "$TEST_ROOT/last-output.txt"
        printf 'FAIL: expected success: %s\n' "$*" >&2
        exit 1
    fi
}
expect_failure() {
    TEST_COUNT=$((TEST_COUNT + 1))
    if "$@" > "$TEST_ROOT/last-output.txt" 2>&1; then
        printf 'FAIL: expected rejection: %s\n' "$*" >&2
        exit 1
    else
        printf 'PASS %s: rejected %s\n' "$TEST_COUNT" "$*"
    fi
}

expect_success version_at_least 14.6 14.6
expect_success version_at_least 14.10 14.6
expect_success version_at_least 15.0 14.6
expect_success version_at_least 26.0.1 14.6
expect_failure version_at_least 14.5.9 14.6
expect_failure version_at_least 13.7 14.6
expect_failure version_at_least unknown 14.6

mock_mac() (
    local test_version="$1" test_arm="$2"
    uname() { printf 'Darwin\n'; }
    sw_vers() { printf '%s\n' "$test_version"; }
    sysctl() { printf '%s\n' "$test_arm"; }
    check_platform
)
mock_non_mac() (
    uname() { printf 'Linux\n'; }
    check_platform
)
expect_success mock_mac 14.6 1
expect_success mock_mac 26.0 1
expect_failure mock_mac 14.5 1
expect_failure mock_mac 15.0 0
expect_failure mock_non_mac

GAME_TEST_DIR="$TEST_ROOT/Friend's Games/Phasmophobia"
mkdir -p "$GAME_TEST_DIR/Phasmophobia_Data"
touch "$GAME_TEST_DIR/Phasmophobia.exe" "$GAME_TEST_DIR/UnityPlayer.dll" "$GAME_TEST_DIR/GameAssembly.dll"
expect_success validate_game_folder "$GAME_TEST_DIR"
expect_success normalize_game_path "$GAME_TEST_DIR/Phasmophobia.exe"
if [ "$(normalize_game_path "$GAME_TEST_DIR/Phasmophobia.exe")" != "$GAME_TEST_DIR" ]; then
    fail 'Game path did not preserve spaces and apostrophes.'; exit 1
fi
mv "$GAME_TEST_DIR/UnityPlayer.dll" "$GAME_TEST_DIR/UnityPlayer.saved"
expect_failure validate_game_folder "$GAME_TEST_DIR"
expect_failure normalize_game_path "$TEST_ROOT/missing game"

printf 'verified test fixture\n' > "$TEST_ROOT/download-source"
FIXTURE_SHA=$(sha256_file "$TEST_ROOT/download-source")
expect_success verify_sha256 "$TEST_ROOT/download-source" "$FIXTURE_SHA"
expect_failure verify_sha256 "$TEST_ROOT/download-source" '0000000000000000000000000000000000000000000000000000000000000000'
mkdir -p "$TEST_ROOT/stage"
mock_download() (
    curl() {
        local output=''
        while [ "$#" -gt 0 ]; do
            if [ "$1" = --output ]; then output="$2"; shift; fi
            shift
        done
        cp "$TEST_ROOT/download-source" "$output"
    }
    download_verified 'https://example.invalid/fixture' "$1" "$TEST_ROOT/cache.tar.xz" "$TEST_ROOT/stage"
)
expect_success mock_download "$FIXTURE_SHA"
expect_success verify_sha256 "$TEST_ROOT/cache.tar.xz" "$FIXTURE_SHA"
cache_reuse_without_network() (
    curl() { fail 'Network must not be used for a verified cache entry.'; return 99; }
    download_verified 'https://example.invalid/fixture' "$FIXTURE_SHA" "$TEST_ROOT/cache.tar.xz" "$TEST_ROOT/stage"
)
expect_success cache_reuse_without_network
expect_failure mock_download '0000000000000000000000000000000000000000000000000000000000000000'
expect_success verify_sha256 "$TEST_ROOT/cache.tar.xz" "$FIXTURE_SHA"

mock_archive() (
    local fixture_kind="$1"
    tar() {
        case "$fixture_kind" in
            good) printf 'Sikarugir Creator.app/\nSikarugir Creator.app/Contents/Info.plist\n' ;;
            escape) printf 'Sikarugir Creator.app/../outside\n' ;;
            absolute) printf '/tmp/outside\n' ;;
            wrong) printf 'Unexpected.app/Contents/Info.plist\n' ;;
            empty) return 0 ;;
        esac
    }
    check_creator_archive 'unused-fixture.tar.xz' "$TEST_ROOT/listing.txt"
)
expect_success mock_archive good
expect_failure mock_archive escape
expect_failure mock_archive absolute
expect_failure mock_archive wrong
expect_failure mock_archive empty

expect_success bash -n "$TEST_SCRIPT_DIR/../Setup-Mac.command"
expect_success bash -n "$TEST_SCRIPT_DIR/mac-setup-common.sh"
expect_success bash "$TEST_SCRIPT_DIR/../Setup-Mac.command" --dry-run --no-pause
expect_success bash "$TEST_SCRIPT_DIR/../Setup-Mac.command" --help
expect_failure bash "$TEST_SCRIPT_DIR/../Setup-Mac.command" --game
expect_failure bash "$TEST_SCRIPT_DIR/../Setup-Mac.command" --unknown-option

mv "$GAME_TEST_DIR/UnityPlayer.saved" "$GAME_TEST_DIR/UnityPlayer.dll"
printf 'original launcher fixture\n' > "$GAME_TEST_DIR/Launcher.exe"
ORIGINAL_GAME_HASH=$(sha256_file "$GAME_TEST_DIR/Launcher.exe")
expect_success normalize_game_path "$(dirname "$GAME_TEST_DIR")"
expect_success normalize_game_path "$GAME_TEST_DIR/Launcher.exe"
expect_success validate_executable "$GAME_TEST_DIR" Launcher.exe
expect_failure validate_executable "$GAME_TEST_DIR" ../outside.exe
expect_failure validate_executable "$GAME_TEST_DIR" /absolute.exe
expect_failure validate_executable "$GAME_TEST_DIR" Launcher.bat
expect_failure validate_executable "$GAME_TEST_DIR" missing.exe
expect_success write_game_launcher "$TEST_ROOT/batch-prefix" 'Tools/Launch %ready%.exe'
batch_quotes_correct() {
    local text
    text=$(cat "$TEST_ROOT/batch-prefix/drive_c/phasmo-kit/launch-game.bat")
    case "$text" in *'cd /d "C:\Phasmophobia"'*) ;; *) return 1 ;; esac
    case "$text" in *'"C:\Phasmophobia\Tools\Launch %%ready%%.exe" %*'*) ;; *) return 1 ;; esac
    case "$text" in *'setlocal DisableDelayedExpansion'*) ;; *) return 1 ;; esac
}
expect_success batch_quotes_correct

create_wrapper_fixture() {
    local target="$1" state="$2" prefix="$1/Contents/SharedSupport/prefix"
    mkdir -p "$target/Contents/Resources" "$target/Contents/MacOS" "$target/Contents/SharedSupport/wine/bin"
    printf 'phasmo-mac-setup v1\n' > "$target/Contents/Resources/phasmo-mac-setup.txt"
    printf '#!/bin/bash\nexit 0\n' > "$target/Contents/MacOS/wineskinlauncher"
    printf '#!/bin/bash\nexit 0\n' > "$target/Contents/SharedSupport/wine/bin/wine"
    chmod +x "$target/Contents/MacOS/wineskinlauncher" "$target/Contents/SharedSupport/wine/bin/wine"
    if [ "$state" = ready ]; then
        mkdir -p "$prefix/drive_c/windows/system32"
        printf 'WINE REGISTRY Version 2\n' > "$prefix/system.reg"
        printf 'WINE REGISTRY Version 2\n' > "$prefix/user.reg"
        touch "$prefix/drive_c/windows/system32/kernel32.dll"
    fi
}
mkdir -p "$TEST_ROOT/wrapper-cache" "$TEST_ROOT/wrapper-stage"
WRAPPER_FIXTURE="$TEST_ROOT/Phasmophobia Test.app"
create_wrapper_fixture "$WRAPPER_FIXTURE" ready
mock_wrapper_resume() (
    # Windows lacks macOS signing/plist tools and may disallow native symlinks.
    # Record those external operations while exercising real state/guard logic.
    repair_app_signature() { printf 'sign\n' >> "$TEST_ROOT/wrapper-operations"; }
    verify_app_signature() { printf 'verify\n' >> "$TEST_ROOT/wrapper-operations"; }
    set_plist_string() { printf '%s=%s\n' "$2" "$3" >> "$TEST_ROOT/plist-operations"; }
    download_verified() { fail 'A ready wrapper must not download again.'; return 99; }
    ln() { [ "$1" = -s ] || return 99; printf '%s\n' "$2" > "$3"; }
    prepare_wrapper "$WRAPPER_FIXTURE" "$GAME_TEST_DIR" Launcher.exe "$TEST_ROOT/wrapper-cache" "$TEST_ROOT/wrapper-stage"
)
expect_success mock_wrapper_resume
wrapper_resume_results() {
    [ "$(cat "$WRAPPER_FIXTURE/Contents/SharedSupport/prefix/drive_c/Phasmophobia")" = "$GAME_TEST_DIR" ] || return 1
    [ "$(head -n 1 "$TEST_ROOT/wrapper-cache/wrapper-status.txt")" = wrapper-prepared ] || return 1
    case "$(cat "$TEST_ROOT/plist-operations")" in *'Program Name and Path=/phasmo-kit/launch-game.bat'*) ;; *) return 1 ;; esac
    case "$(cat "$WRAPPER_FIXTURE/Contents/SharedSupport/prefix/drive_c/phasmo-kit/launch-game.bat")" in *'"C:\Phasmophobia\Launcher.exe" %*'*) ;; *) return 1 ;; esac
    verify_sha256 "$GAME_TEST_DIR/Launcher.exe" "$ORIGINAL_GAME_HASH"
}
expect_success wrapper_resume_results

INCOMPLETE_FIXTURE="$TEST_ROOT/Incomplete.app"
create_wrapper_fixture "$INCOMPLETE_FIXTURE" incomplete
expect_failure prepare_wrapper "$INCOMPLETE_FIXTURE" "$GAME_TEST_DIR" Launcher.exe "$TEST_ROOT/wrapper-cache" "$TEST_ROOT/wrapper-stage"
incomplete_did_not_succeed() {
    [ ! -e "$INCOMPLETE_FIXTURE/Contents/SharedSupport/prefix/drive_c/Phasmophobia" ] &&
        [ "$(head -n 1 "$TEST_ROOT/wrapper-cache/wrapper-status.txt")" = in-progress ]
}
expect_success incomplete_did_not_succeed

UNOWNED_FIXTURE="$TEST_ROOT/User Existing.app"
mkdir -p "$UNOWNED_FIXTURE"
printf 'preserve me\n' > "$UNOWNED_FIXTURE/user-file"
expect_failure prepare_wrapper "$UNOWNED_FIXTURE" "$GAME_TEST_DIR" Launcher.exe "$TEST_ROOT/wrapper-cache" "$TEST_ROOT/wrapper-stage"
existing_user_data_unchanged() { [ "$(cat "$UNOWNED_FIXTURE/user-file")" = 'preserve me' ]; }
expect_success existing_user_data_unchanged
expect_failure prepare_wrapper "$WRAPPER_FIXTURE" "$GAME_TEST_DIR" Launcher.exe "$TEST_ROOT/wrapper-cache" "$TEST_ROOT/wrapper-stage"

expect_failure find_windows_steam "$TEST_ROOT/steam-prefix"
mkdir -p "$TEST_ROOT/steam-prefix/drive_c/Program Files (x86)/Steam"
touch "$TEST_ROOT/steam-prefix/drive_c/Program Files (x86)/Steam/steam.exe"
expect_success find_windows_steam "$TEST_ROOT/steam-prefix"
expect_success bash -n "$TEST_SCRIPT_DIR/prepare-wrapper.sh"
expect_success bash -n "$TEST_SCRIPT_DIR/../Steam-Mac.command"
expect_success bash "$TEST_SCRIPT_DIR/../Steam-Mac.command" --dry-run --no-pause
expect_success bash "$TEST_SCRIPT_DIR/../Steam-Mac.command" --help
expect_failure bash "$TEST_SCRIPT_DIR/../Steam-Mac.command" --unknown-option
expect_success wine_prefix_ready "$WRAPPER_FIXTURE/Contents/SharedSupport/prefix"
mkdir -p "$TEST_ROOT/placeholder-prefix/drive_c/windows/system32"
touch "$TEST_ROOT/placeholder-prefix/system.reg" "$TEST_ROOT/placeholder-prefix/user.reg" "$TEST_ROOT/placeholder-prefix/drive_c/windows/system32/kernel32.dll"
expect_failure wine_prefix_ready "$TEST_ROOT/placeholder-prefix"
expect_failure wrapper_is_prepared "$INCOMPLETE_FIXTURE"
expect_failure wrapper_is_prepared "$UNOWNED_FIXTURE"

printf '\n%s offline checks passed. No Mac/Wine execution was tested.\n' "$TEST_COUNT"
