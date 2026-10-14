# Validation record

Checked on 14 October 2026 from the Windows project folder. No Mac was connected. The friend will test later.

## Passed locally

- **61 offline setup checks**: Bash parsing, version/platform checks, missing prerequisites, downloaded-file checksum rejection, safe cache reuse, archive-root rejection, paths with spaces/apostrophes, executable selection, batch-file working directory and escaping, preserving an unrelated wrapper, resuming a kit wrapper, rejecting incomplete prefixes, Windows Steam detection, and read-only readiness checks.
- **12 file-verifier checks**: fixture-manifest generation, correct size/hash counts, core/full comparison on small fixtures, missing/changed files, argument errors, no misleading success, unchanged fixture files, and an independent rehash of the six real core files.
- Official Creator, Template, and Wine engine archive SHA-256 values matched their published release metadata after downloading. The Windows Steam installer used for pinning had a valid Valve Corp. Authenticode signature when inspected on Windows.
- A full local-copy fingerprint manifest was generated for **602 files / 44,739,590,487 bytes**. The game build fingerprint is `fee9f935240561e275bae62bcea6585646e0893fea469b6eb5fcd5ba645264e0`.
- Windows diagnostic script parsed and ran, including missing-path and report-location failures. Its report excludes raw logs, account IDs, usernames, machine names, installation paths, and network addresses.
- Mac shell scripts use UTF-8 with LF line endings. The ZIP builder verifies archive integrity, file contents, and Unix executable permission bits on `.command` and `.sh` files. The ZIP excludes the game, downloaded executables, and this PC's diagnostic JSON.

## What those checks do not prove

The offline setup tests use mocks for macOS signing, plist operations, native symlinks, and some installation state. Git Bash was used on Windows. The verifier tests use a temporary `sha256sum` adapter because this Git Bash installation does not provide macOS `shasum`. None of this emulates an M4 Mac or executes the Wine engine.

The HTML guide is generated from the same Markdown README. Actual browser visual preview was unavailable in this session; the Markdown remains the canonical instructions.

Still unverified: Apple's Bash 3.2 and native commands, Rosetta installation, Finder launch, macOS app signing/permission behavior, Wine prefix creation, Windows Steam installation/update/sign-in on this Mac, game rendering, microphone, authentication, private lobby, map load, reconnection, and four-player play.

Historical Windows logs show graphics initialization but also account-linking and other errors. They may describe a different game folder. The actual current copy was not launched during this preparation session.

## Reproduce local checks

These are maintainer commands, not extra steps your Mac friend needs to perform:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' 'Mac-Setup/scripts/test-setup.sh'
python 'Mac-Setup/tools/test-verify.py' --bash 'C:\Program Files\Git\bin\bash.exe' --real-game 'Phasmophobia'
```

The full multiplayer acceptance steps are in [README.md](README.md). Preparation is finished; game compatibility is not certified until that actual Mac test succeeds.
