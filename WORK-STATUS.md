# Work status — 14 October 2026

The previous chats were recovered. The intended outcome is four independent players: three Windows PCs plus a friend's M4 MacBook Pro at another home, with a zero-cost compatibility tool. The user accepted a local Mac route instead of a browser port and explicitly asked to use one tool and provide every step in a README. The friend is unavailable during this session and will test later.

Prepared `Mac-Setup/README.md`, an equivalent offline `README.html`, and `Phasmophobia-Mac-Setup.zip`. The single chosen tool is Sikarugir. `Setup-Mac.command` checks macOS/Rosetta, downloads pinned official components, creates a user-scoped Phasmophobia.app, initializes its Wine prefix, and links the existing game folder. `Steam-Mac.command` installs/opens Windows Steam in that same prefix. `Verify-Game.command` compares the transferred files to this Windows copy.

Verification: 61 offline setup checks and 12 verifier checks passed. Full game fingerprinting covered 602 files, with six core hashes independently rechecked. See `Mac-Setup/TEST-RESULTS.md` for the exact scope and limitations. Source components were inspected, but no Mac/Wine/game/multiplayer execution was possible from this Windows environment. Existing game binaries and Windows security settings were left unchanged.

The supplied folder is about 44.8 GB and contains a custom x86 Launcher.exe with an x64 Unity game and modified multiplayer components. Historical logs include an account-linking invalid-token/401 error. The compatibility layer cannot establish account ownership or repair an unverified multiplayer service. This is described candidly in the README.

The full goal is **not yet proven complete**. The next required evidence is the friend's M4 test: successful setup and Steam sign-in, game menu, private lobby with a Windows player, contract load, voice tests, return/reconnect, and four-player play. The README includes a ready-to-fill test report. The only remaining work that can establish the requested outcome requires the actual Mac and players; do not treat a ZIP, matching hashes, or offline tests as proof of playable multiplayer.
