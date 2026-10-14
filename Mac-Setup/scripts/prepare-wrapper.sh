#!/bin/bash
# Assembly mirrors the published Creator layout and its prefix-create command.
# Loaded by Setup-Mac.command. No work occurs merely by sourcing this file.

write_game_launcher() {
    local prefix="$1" executable="$2" escaped
    # In a batch file %% produces a literal %. Delayed expansion stays disabled.
    escaped=${executable//\//\\}
    escaped=${escaped//%/%%}
    mkdir -p "$prefix/drive_c/phasmo-kit"
    {
        printf '@echo off\r\nsetlocal DisableDelayedExpansion\r\n'
        printf 'cd /d "C:\\Phasmophobia"\r\n'
        printf 'if errorlevel 1 exit /b 2\r\n'
        printf '"C:\\Phasmophobia\\%s" %%*\r\n' "$escaped"
        printf 'exit /b %%ERRORLEVEL%%\r\n'
    } > "$prefix/drive_c/phasmo-kit/launch-game.bat"
}

prepare_wrapper() {
    local target="$1" game="$2" executable="$3" cache="$4" stage="$5"
    local marker="$target/Contents/Resources/phasmo-mac-setup.txt"
    local prefix="$target/Contents/SharedSupport/prefix"
    local template_archive="$cache/Template-$TEMPLATE_VERSION.tar.xz"
    local engine_archive="$cache/$ENGINE_NAME.tar.xz"
    local staged_app="$stage/$TEMPLATE_ROOT" free_kb current_link plist

    validate_executable "$game" "$executable" || return 1
    printf 'in-progress\n' > "$cache/wrapper-status.txt"
    if [ -e "$target" ] || [ -L "$target" ]; then
        [ -f "$marker" ] && [ "$(head -n 1 "$marker")" = 'phasmo-mac-setup v1' ] || {
            fail "A wrapper already exists at $target and was not created by this kit. It has been preserved. Rename it in Finder before running automatic setup."
            return 1
        }
        say "Resuming the wrapper created by this kit: $target"
    else
        free_kb=$(df -Pk "$(dirname "$target")" | awk 'NR == 2 { print $4 }')
        case "$free_kb" in ''|*[!0-9]*) warn 'Could not measure free disk space. Allow at least 4 GB for the tools and prefix.' ;;
            *) [ "$free_kb" -ge 4194304 ] || { fail 'At least 4 GiB free disk space is required for downloads, extraction, and the Wine prefix.'; return 1; } ;;
        esac
        download_verified "$TEMPLATE_URL" "$TEMPLATE_SHA256" "$template_archive" "$stage" || return 1
        download_verified "$ENGINE_URL" "$ENGINE_SHA256" "$engine_archive" "$stage" || return 1
        check_archive_root "$template_archive" "$stage/template-list.txt" "$TEMPLATE_ROOT" || return 1
        check_archive_root "$engine_archive" "$stage/engine-list.txt" 'wswine.bundle' || return 1
        say 'Extracting the verified wrapper template and Wine engine...'
        tar -xf "$template_archive" -C "$stage" || return 1
        tar -xf "$engine_archive" -C "$stage" || return 1
        [ -x "$staged_app/Contents/MacOS/wineskinlauncher" ] || { fail 'The expected wrapper launcher is missing.'; return 1; }
        [ -x "$stage/wswine.bundle/bin/wine" ] || { fail 'The expected Wine engine is missing.'; return 1; }
        mkdir -p "$staged_app/Contents/SharedSupport" "$staged_app/Contents/Resources"
        [ ! -e "$staged_app/Contents/SharedSupport/wine" ] && [ ! -L "$staged_app/Contents/SharedSupport/wine" ] || {
            fail 'The template contains an unexpected existing Wine engine; setup stopped.'; return 1;
        }
        mv "$stage/wswine.bundle" "$staged_app/Contents/SharedSupport/wine" || return 1
        printf 'phasmo-mac-setup v1\ntemplate=%s\nengine=%s\n' "$TEMPLATE_VERSION" "$ENGINE_NAME" > "$staged_app/Contents/Resources/phasmo-mac-setup.txt"
        clear_app_quarantine "$staged_app" || return 1
        repair_app_signature "$staged_app" || return 1
        [ ! -e "$target" ] && [ ! -L "$target" ] || { fail 'A wrapper appeared while downloading. Rerun setup.'; return 1; }
        mv "$staged_app" "$target" || return 1
    fi

    [ -x "$target/Contents/MacOS/wineskinlauncher" ] && [ -x "$target/Contents/SharedSupport/wine/bin/wine" ] || {
        fail 'The saved wrapper is incomplete. Inspect it with Creator before trying again.'; return 1;
    }
    if ! wine_prefix_ready "$prefix"; then
        say 'Creating the Windows environment in the wrapper. This can take several minutes.'
        say 'If Wine shows an installation dialog, complete it; keep this Terminal window open.'
        "$target/Contents/MacOS/wineskinlauncher" WSS-wineprefixcreate || {
            fail "Wine could not create its prefix. The partial wrapper is preserved at $target. Rerun setup to retry; see the log for the error."
            return 1
        }
    fi
    wine_prefix_ready "$prefix" || {
        fail "Prefix creation did not produce the required Windows files. Setup is incomplete. Open $target/Contents/Configure.app for troubleshooting."
        return 1
    }

    if [ -L "$prefix/drive_c/Phasmophobia" ]; then
        current_link=$(readlink "$prefix/drive_c/Phasmophobia")
        if [ "$current_link" != "$game" ]; then
            say 'Updating this kit’s game-folder link to the selected location.'
            # Remove only this known symlink; never remove or move the game data.
            rm "$prefix/drive_c/Phasmophobia" || return 1
            ln -s "$game" "$prefix/drive_c/Phasmophobia" || return 1
        fi
    elif [ -e "$prefix/drive_c/Phasmophobia" ]; then
        fail 'The wrapper already has a real Phasmophobia folder. It was preserved; move it aside in Finder before linking the selected game folder.'
        return 1
    else
        ln -s "$game" "$prefix/drive_c/Phasmophobia" || return 1
    fi
    write_game_launcher "$prefix" "$executable" || return 1
    plist="$target/Contents/Info.plist"
    set_plist_string "$plist" CFBundleName 'Phasmophobia' || return 1
    set_plist_string "$plist" CFBundleIdentifier 'local.phasmo-mac-setup.game' || return 1
    set_plist_string "$plist" 'Program Name and Path' '/phasmo-kit/launch-game.bat' || return 1
    # Keep the template's empty flags and DXMT default. On a rerun, retain the
    # user's later flags/renderer choices made through Configure.app.
    repair_app_signature "$target" || return 1
    verify_app_signature "$target" || return 1
    printf 'wrapper-prepared\nexecutable=%s\ngame=%s\n' "$executable" "$game" > "$cache/wrapper-status.txt"
    say "Wrapper prepared: $target"
    say "Selected executable: $executable"
    say 'The full game folder is linked in place; keep it at this location. No game files were copied or changed.'
}
