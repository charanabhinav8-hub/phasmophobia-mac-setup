# Compatibility evidence

Checked on 14 October 2026. These notes document the sources and downloaded components used to prepare the Mac setup. The game has not been run on the M4 Mac during this session.

## What is established

- Phasmophobia's [Steam listing](https://store.steampowered.com/app/739630/Phasmophobia/) lists Windows, a 64-bit operating system, and DirectX 11. There is no official macOS build listed. The setup runs the existing Windows files through Wine.
- The [official Sikarugir project](https://github.com/Sikarugir-App/Sikarugir) supports macOS 14.6 or later. Apple Silicon requires Rosetta 2. Both the downloaded Creator and template declare macOS 14.6 as their minimum version.
- Sikarugir's current [engine list](https://raw.githubusercontent.com/Sikarugir-App/Engines/main/EngineList.txt) starts with `WS12WineSikarugir11.0_1`. Its [template manifest](https://raw.githubusercontent.com/Sikarugir-App/Template/main/NewestVersion.txt) identifies `Template-1.0.21`.
- The official project warns that `sikarugir.com` is unrelated. The setup uses the project's GitHub organization and published checksums.

## Pinned downloads

Each archive below was downloaded on Windows and its SHA-256 checked against the official release asset metadata. Creator's checksum also matches the [official Homebrew cask](https://github.com/Sikarugir-App/homebrew-sikarugir/blob/main/Casks/sikarugir.rb).

| Component | Official download | SHA-256 |
| --- | --- | --- |
| Creator 1.0.2 | [Creator-v1.0.2.tar.xz](https://github.com/Sikarugir-App/Creator/releases/download/v1.0.2/Creator-v1.0.2.tar.xz) | `e7852e78a02b6958708563e87aedf55986cbf6a7e6d6bcb3d661d8fccb15b7bd` |
| Template 1.0.21 | [Template-1.0.21.tar.xz](https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.21.tar.xz) | `bbe996e4e4375318485953d0c7818b7b4b0a4dc1f13303bcc584f99f7602f78d` |
| Wine Sikarugir 11.0 revision 1 | [WS12WineSikarugir11.0_1.tar.xz](https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir11.0_1.tar.xz) | `67e29fb3d74f363af39c69ba11f9b13a79812c5db07cf4748672658e4a200a0e` |

The download versions are pinned so a later upstream release cannot silently change this setup. The separate component releases contain the authoritative metadata: [Creator](https://github.com/Sikarugir-App/Creator/releases/tag/v1.0.2), [Template](https://github.com/Sikarugir-App/Template/releases/tag/v1.0), [Engines](https://github.com/Sikarugir-App/Engines/releases/tag/v1.0).

## Graphics and sound

The [official renderer description](https://github.com/Sikarugir-App/Sikarugir#readme) lists DXMT as the default DirectX 10/11 renderer, D3DMetal as a selectable renderer for 64-bit Direct3D 11/12 on Apple Silicon, and DXVK as a selectable DirectX 10/11 renderer. Start with DXMT for this DirectX 11 game; D3DMetal and DXVK are separate fallback trials if graphics fail. Select one renderer at a time.

The [Configure source](https://github.com/Sikarugir-App/Sikarugir-foss-sources/blob/main/Configure/Classes/Controller/WineskinAppDelegate.m) makes the three renderer options mutually exclusive. D3DMetal is Apple's separately licensed component; its license is linked from the official project.

Whisky is [no longer maintained](https://github.com/Whisky-App/Whisky#maintenance-notice). Its [Phasmophobia compatibility page](https://docs.getwhisky.app/game-support/phasmophobia.html), last changed on 1 January 2025, reports Silver compatibility and successful opening, with broken proximity chat and outbound voice. This is historical evidence for Whisky. Voice and graphics on this Sikarugir setup still require a Mac test.

The template includes `NSMicrophoneUsageDescription`, so a microphone description is present in the app bundle. Its presence alone does not establish that Wine will request permission correctly or that the game's voice service will work. If available in the supplied game version, Text voice recognition can be used for equipment interaction; a separate voice call can cover player communication. Text mode does not replace every audio-driven mechanic.

## Multiplayer limits

The runtime does not supply game ownership, Steam authentication, compatible lobby services, or an online session. A successful menu launch is only the first test. This exact build must still create or join the same lobby as the Windows players, load a contract, and remain connected.

Anti-cheat and service authentication behavior for this exact build on this Mac remain unverified. No inspected primary source establishes a universal anti-cheat block for this setup. Kinetic's [official Steam news feed](https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=739630&count=100&maxlength=0) includes a 16 December 2025 Steam Deck voice-chat fix and 2026 Text voice-recognition updates; those are not Mac compatibility certifications.

## Wrapper contract checked from source and archives

- Template archive root: `Template-1.0.21.app`.
- Engine archive root: `wswine.bundle`; installed engine directory: `<wrapper>/Contents/SharedSupport/wine`.
- Prefix: `<wrapper>/Contents/SharedSupport/prefix`. The template's `Contents/drive_c` symlink points to `SharedSupport/prefix/drive_c`. A new template contains no initialized prefix.
- The archive contains `Contents/MacOS/launcher -> Sikarugir` and `Contents/MacOS/wineskinlauncher -> launcher`. The latter is lowercase.
- The actual launcher binary's help supports `WSS-wineprefixcreate`, `WSS-wineboot`, `WSS-winetricks`, `config`, and `debug`. Creator 1.0.2 contains the same engine directory and prefix-creation command. Older source still mentions `WSS-InstallICE`; that command is absent from the current launcher's help and is not needed for this engine layout.
- `Info.plist` uses `Program Name and Path` for a path relative to Wine's C: drive, and `Program Flags` for its arguments. These keys are defined in [Configure_Prefix.pch](https://github.com/Sikarugir-App/Sikarugir-foss-sources/blob/main/Configure/OtherSources/Configure_Prefix.pch); [NSPortDataLoader.m](https://github.com/Sikarugir-App/Sikarugir-foss-sources/blob/main/Configure/Classes/Utilities/NSPortDataLoader.m) prepends C: when reading the main program path.
- The launcher's help explicitly supports `.bat`, `.msi`, and `.exe` files. A small batch launcher can explicitly set the game's working directory before starting it.
- Configure's [UI source](https://github.com/Sikarugir-App/Sikarugir-foss-sources/blob/main/Configure/Base.lproj/MainMenu.xib) contains `Install Software`, `Copy a Folder Inside`, `Windows app:`, `Browse`, and `Test Run`. These provide a manual recovery route.
- Test-run Wine logs use `<wrapper>/Contents/SharedSupport/Logs/LastRunWine.log`.

These checks establish the download integrity and setup structure. macOS application startup, Wine initialization, game rendering, microphone access, and multiplayer must be verified on the friend's Mac.
