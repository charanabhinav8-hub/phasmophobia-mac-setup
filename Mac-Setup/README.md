# Run Phasmophobia on the M4 MacBook Pro

Use **Sikarugir**. This is the single compatibility route used by this kit. It creates a Mac app that runs the existing Windows game on the Mac itself. Your three Windows PCs can keep playing independently.

**Status: setup prepared; the Mac game and multiplayer test are still pending.** The installer and file checks have been checked on Windows. Nobody has run this package on your friend's M4 during this session. Follow the final test checklist before calling it working.

The compatibility software costs ₹0. This ZIP contains setup scripts and instructions, **not the game**. It does not supply a Steam account or game ownership. Official Steam multiplayer requires the required game entitlement and successful sign-in. The supplied Windows folder includes a custom `Launcher.exe` and additional multiplayer components; their Mac compatibility is unverified.

## What you will do

1. Put the complete game folder and this setup folder on the Mac.
2. Run `Setup-Mac.command` to prepare Sikarugir and create `Phasmophobia.app`.
3. Run `Steam-Mac.command` to install/open **Windows Steam inside that same app**, then sign in.
4. Open `Phasmophobia.app` and test the game with the Windows players.

You do not need a browser host, a spare Windows PC, Homebrew, a virtual machine, router port forwarding, or a paid compatibility app. This runs locally on macOS; it is not a browser port or a native Mac rebuild.

## 1. Check the Mac before copying anything

1. On the Mac, choose **Apple menu → About This Mac**.
2. Confirm it says **Apple M4**. This kit targets Apple Silicon; your M4 MacBook Pro is the intended hardware.
3. Confirm **macOS 14.6 or later**. If it is older, use Apple's normal Software Update before continuing.
4. Keep the Mac plugged into power and connected to the Internet during setup.
5. Allow approximately **60 GB of free space before copying the game** onto the internal disk. The current game folder is about **44.8 GB (41.7 GiB)**. Sikarugir, its downloads, the Windows environment, and Steam need additional space. Setup checks for at least 4 GiB free for the initial wrapper; Steam updates and saves need space too.
6. If the game will stay on an external SSD, keep that SSD connected whenever you play. An existing APFS or exFAT drive can hold the large files. FAT32 cannot hold the largest game file, which exceeds 4 GB. Do not erase a drive just to follow this guide.

## 2. Put both folders on the Mac

### On the Windows PC

1. Locate the **entire** `Phasmophobia` folder inside this project.
2. It must contain `Phasmophobia.exe`, `UnityPlayer.dll`, `GameAssembly.dll`, and the complete `Phasmophobia_Data` folder. Keep the other supplied files together too.
3. Transfer that complete folder to the Mac using your existing storage or file-transfer method. Transferring only an `.exe` will not work.
4. Transfer `Phasmophobia-Mac-Setup.zip` to the Mac as well. The small setup ZIP does not replace the roughly 45 GB game folder.

### On the Mac

1. Open **Finder**.
2. Choose **Go → Home**.
3. Create a folder named **Games** if you do not already have one.
4. Put the complete `Phasmophobia` game folder in `Games`.
5. Double-click `Phasmophobia-Mac-Setup.zip` to extract it.
6. Put the extracted **Mac-Setup** folder in `Games`, beside `Phasmophobia`.

The result should look like this:

```text
Your home folder/
  Games/
    Phasmophobia/
      Launcher.exe                 (present in the supplied copy)
      Phasmophobia.exe
      UnityPlayer.dll
      GameAssembly.dll
      Phasmophobia_Data/
      ...all the other game files...
    Mac-Setup/
      README.md
      Setup-Mac.command
      Steam-Mac.command
      Verify-Game.command
      scripts/
      ...the other setup files...
```

You can use another location. If the folders are not beside each other, setup asks you to choose the game folder. Keep the full `Mac-Setup` folder together; its commands need the `scripts` folder.

## 3. Check that the game transferred correctly

1. Open the **Mac-Setup** folder.
2. Double-click **Verify-Game.command**.
3. If prompted, choose the folder containing `Phasmophobia.exe`.
4. Wait for the six core files to report `OK` and for the message that the core build matches the recorded Windows copy.
5. If a file says `FAILED` or is missing, finish or repeat the transfer before continuing.

This quick check compares six important files. To check **all 602 recorded files**, open Terminal and run:

```bash
bash "$HOME/Games/Mac-Setup/Verify-Game.command" --full
```

The full check reads approximately 42 GiB and may take several minutes. It leaves the game unchanged. It excludes Windows redistributable installers, screenshots, logs, and mutable launcher settings. These fingerprints compare against the local Windows copy used to prepare this kit; they do not certify publisher authenticity or prove that multiplayer works. A later legitimate game update will change the fingerprints.

## 4. Run the Mac setup

1. Double-click **Setup-Mac.command**.
2. A Terminal window opens. Leave it open while setup is running.
3. If asked to choose a folder, select the complete **Phasmophobia** folder, not just the data folder or an archive.
4. If Rosetta 2 is missing, setup starts Apple's Rosetta installer. Read and answer Apple's license prompt. If Apple asks for an administrator password, your friend enters it themselves. Do not add `sudo` to this setup command.
5. Let setup download and verify the Sikarugir components. A checksum mismatch stops installation; it is not a successful install.
6. Wait for creation of the Windows environment. Complete any Wine installation dialog that appears. Initial setup can take several minutes; do not close the window while files are being created.
7. Continue only once setup explicitly reports that the wrapper has been prepared. Finder will show **Phasmophobia.app**.

Setup uses these pinned components from the official Sikarugir GitHub organization:

- Sikarugir Creator **1.0.2**.
- Sikarugir Template **1.0.21**.
- Wine engine **WS12WineSikarugir11.0_1**.
- The template's default **DXMT** renderer for DirectX 11.

Setup creates the app here:

```text
~/Applications/Sikarugir/Phasmophobia.app
```

It links to your existing game folder instead of making a second 45 GB copy. **Keep the game folder in its chosen location.** Moving the app alone to another computer does not transfer the game.

For this supplied folder, setup selects `Launcher.exe` because that is its Windows entry point. For a folder without that launcher, it selects `Phasmophobia.exe`. It sets the game's working directory and does not modify the game binaries or add DLL overrides.

### If double-clicking a `.command` does not work

Open **Applications → Utilities → Terminal**. Type `bash` followed by one space, drag the desired `.command` file from Finder into Terminal, then press **Return**. This also handles a path containing spaces and does not require changing executable permissions.

For the exact folder arrangement above, you can instead paste:

```bash
bash "$HOME/Games/Mac-Setup/Setup-Mac.command"
```

Use the generated setup command from this kit. If macOS displays a security or approval dialog, review what it names and follow the normal app-specific approval process for the software you intended to open. Do not disable Gatekeeper or antivirus globally.

## 5. Install and sign in to Windows Steam in this wrapper

**The Steam application for macOS is not enough for this step.** The Windows game needs the Windows Steam client in the same Sikarugir Windows environment.

1. In **Mac-Setup**, double-click **Steam-Mac.command**.
2. On the first run, it opens Valve's official Windows Steam installer inside the prepared `Phasmophobia.app` environment.
3. Follow the Steam installer. Keep its default installation folder:

   ```text
   C:\Program Files (x86)\Steam
   ```

4. On the installer's final screen, **uncheck “Run Steam” before clicking Finish**. This lets the installer close completely; the helper will start Steam separately. Leaving that box checked can make the helper wait while Steam remains open.
5. Let the helper open Steam and let Steam update. If it does not open after installation, run **Steam-Mac.command** again. Keep its Terminal window open while Steam is in use.
6. Your friend signs in to **their own Steam account**, including Steam Guard if requested. The kit cannot perform or bypass sign-in.
7. Keep Windows Steam running while starting the game.
8. If an official Steam installation reports the game is not owned or is missing from the library, resolve that through Steam. Installing this free compatibility tool does not unlock the game.

For an official Steam copy, launch the game from that Windows Steam library. If Steam needs to install or update the game, allow the required download and disk space. Do not mix an official Steam installation with unrelated modified multiplayer files.

For the supplied standalone folder, keep Windows Steam running and use the prepared **Phasmophobia.app** in the next step. Its custom launcher and online services may still fail under Wine. The kit does not claim to repair those services.

### If Valve has updated the Steam installer

The helper pins the installer checked when this kit was prepared. If Valve replaces that download, its checksum will differ and the helper will stop. Keep using the same Sikarugir wrapper:

1. Open [Valve's official Windows Steam installer link](https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe) and save `SteamSetup.exe` on the Mac. This is the Windows installer; the normal [Steam download page](https://store.steampowered.com/about/) may offer the Mac app instead.
2. Right-click **Phasmophobia.app → Show Package Contents → Contents → Configure.app**.
3. Choose **Install Software → Choose Setup Executable** and select the downloaded `SteamSetup.exe`.
4. Keep the default Steam installation folder. Uncheck **Run Steam** on the final screen and finish.
5. Run **Steam-Mac.command** again; it opens the already installed Windows Steam.

This manual path obtains the current installer directly from Valve. It is not covered by this kit's old pinned checksum. Do not edit the script to accept an unexplained hash or download a replacement from an unrelated site.

## 6. Launch the game on the Mac

1. Open Finder and choose **Go → Home → Applications → Sikarugir**.
2. Double-click **Phasmophobia.app**.
3. Wait for the initial launch. First-run graphics initialization can take longer than later launches.
4. If macOS asks for microphone access, allow it if your friend wants in-game voice. If it asks for access to the folder containing the game, allow the access needed to read that chosen folder.
5. Reach the game menu before trying multiplayer.
6. Start with **1280 × 720**, low graphics, and a **60 FPS limit** if those settings are offered. After a stable test, increase settings as desired.
7. Record the **game version shown in the menu**. Every intended player should use the same game version and compatible multiplayer service.

For each later session, run **Steam-Mac.command**, leave Steam signed in, then open **Phasmophobia.app**. You do not need to rerun the full setup each time.

## 7. Test multiplayer in this order

Do this with at least one Windows player before inviting everyone. Getting to the menu alone is not a multiplayer pass.

1. On Windows, start the usual game and confirm it reaches its menu.
2. Compare the game version shown on Windows and Mac. Match the branch and multiplayer service too.
3. Choose the same server region if the game offers region selection.
4. One player creates a **private lobby** and shares the lobby code directly with the other player.
5. The Mac player joins that lobby using the same normal join flow used on Windows.
6. Confirm both players appear separately and can move independently.
7. Test hearing each other, push-to-talk, proximity voice, and radio voice. Choose the correct input device in the game.
8. Start a short contract. Both players must load into the map and remain connected.
9. Check movement, mouse look, equipment interaction, game audio, and voice during the contract.
10. Finish or leave the contract normally, return to the lobby, then have the Mac player reconnect once.
11. Add the remaining Windows players and repeat a short contract with all four players.

You do not need port forwarding just to perform this ordinary client multiplayer test. If the supplied build uses a different service from the other players, a compatibility wrapper will not make those services compatible.

## 8. If something fails

Stay with the same Sikarugir setup. Identify the failed step before changing settings.

| What happened | Next step |
| --- | --- |
| Setup says to run on a Mac | Run the `.command` on the M4 Mac, not on Windows. |
| macOS version is too old | Update through Apple's Software Update, then rerun setup. |
| Rosetta installation was cancelled | Rerun setup and complete Apple's Rosetta prompt. |
| A game file is missing | Select the folder containing `Phasmophobia.exe`; finish transferring the complete folder. |
| Download or checksum check fails | Check the connection and rerun. If the checksum still differs, stop and report the exact filename; do not skip the check. An upstream installer may have changed. |
| There is not enough disk space | Make enough space using your normal file-management process, or keep the game on a suitable connected SSD. Setup does not erase files for you. |
| An unrelated `Phasmophobia.app` already exists | The kit preserves it. Rename that existing app in Finder if you want to keep it, then rerun setup. |
| Setup stopped partway through creating its wrapper | Keep the error text. Rerun the same setup; it can resume a wrapper created by this kit. Do not delete the game folder. |
| You moved the game folder after setup | Rerun `Setup-Mac.command` with the new folder selected. It updates its game-folder link without copying the game. |
| Steam is not running / Steam API fails | Open **Steam-Mac.command**, sign in to Windows Steam in this same wrapper, leave it open, and retry. Native macOS Steam alone does not satisfy this. |
| Steam will not sign in or the game reports no entitlement | Resolve the account or ownership issue in Steam. This is separate from graphics compatibility. |
| Game opens but a lobby join returns an authentication error | Record the exact error, game version, and service used. Check the same account/service works on Windows. Reinstalling graphics tools does not establish a fix for authentication. |
| A lobby opens but contracts fail to load | Run the full game-file check, compare versions, then retry one short two-player contract. |
| No microphone / other players cannot hear you | Check the selected in-game microphone and push-to-talk key. In macOS **System Settings → Privacy & Security → Microphone**, check permission for the app that requested it. Restart the game after changing permission. |
| Voice still fails | Use a separate voice call for talking. If your game version offers **Text** voice recognition, try it for supported equipment interactions. This does not restore proximity/radio voice or every audio-driven mechanic. Mark voice as a failed part of the test. |
| Black window, crash, or frozen launch | Stop the test and collect the exact error/log below. Use the same Sikarugir configuration for the first report; do not change several settings at once. Mac execution has not yet been validated for this build. |

### Open Sikarugir's configuration window

Only if troubleshooting requires it: right-click **Phasmophobia.app → Show Package Contents → Contents**, then open **Configure.app**. This is part of the same Sikarugir tool. Its **Test Run** function can produce the Wine log. Keep DXMT for the first test so the result is reproducible.

### Read-only setup check

```bash
bash "$HOME/Games/Mac-Setup/Setup-Mac.command" --check
```

This checks the Mac requirements and known setup files. It makes no downloads or repairs and does not prove the game launches.

## 9. What to send back after the test

Copy this checklist into your reply and fill it in:

```text
Mac: M4 MacBook Pro
macOS version:
Memory:
Setup-Mac result / exact error:
Steam-Mac result / sign-in completed:
Game version on Mac:
Game version on Windows:
Game menu reached: yes / no
Private lobby joined: yes / no
Contract loaded on both computers: yes / no
Stayed connected through a contract: yes / no
Returned to lobby and reconnected: yes / no
Audio heard: yes / no
Microphone / proximity / radio worked: yes / no
Four-player test completed: yes / no
Exact remaining error:
```

Logs stay on your Mac. Nothing is automatically uploaded:

- Setup logs: `~/Library/Logs/Phasmo-Mac-Setup/`.
- Wine test-run log: `~/Applications/Sikarugir/Phasmophobia.app/Contents/SharedSupport/Logs/LastRunWine.log`.
- The Unity game log, when created, is inside the wrapper's Windows environment under its user profile's `AppData/LocalLow/Kinetic Games/Phasmophobia/Player.log`. The exact Wine user folder can vary.

Read logs before sharing. Send the relevant error section, and remove account identifiers, access tokens, lobby codes, and personal paths. Do not send passwords or Steam Guard codes.

## What has been checked so far

- Official download URLs and published Sikarugir archive SHA-256 values were checked; the three Sikarugir archives were downloaded and verified on Windows.
- The current wrapper's layout, launch interface, and prefix-creation command were checked against the official source and downloaded components.
- Shell syntax, prerequisite handling, download verification, and game-file verification were exercised locally. These checks do not emulate a Mac or Wine.
- A full fingerprint manifest was produced for 602 files in the supplied game copy; the six core fingerprints were independently rechecked.
- Windows diagnostics found the graphics hardware and both Visual C++ runtimes. Historical Windows logs show DirectX 11 initialization and some authentication/voice-related errors. They do not prove this copied folder or the Mac works.
- **Still required:** actual Mac application startup, Windows Steam sign-in, game rendering, microphone behavior, lobby join, contract load, reconnection, and four-player play.

For exact component versions, hashes, and supporting sources, see [compatibility-notes.md](compatibility-notes.md). Windows-only diagnostics are available through `Check-Windows.ps1`; they are not part of the Mac installation.

Official tool: [Sikarugir on GitHub](https://github.com/Sikarugir-App/Sikarugir). Use the GitHub organization linked here; the similarly named `sikarugir.com` site is not the official project.
