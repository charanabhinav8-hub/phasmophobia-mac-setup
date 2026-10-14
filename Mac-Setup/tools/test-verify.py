"""Exercise the transfer verifier using tiny fixtures; never run or change the game.

Windows Git Bash does not ship shasum, so the tests provide a temporary adapter
for its exact "-a 256 --check" invocation. The adapter delegates to GNU
sha256sum. This tests the script's control flow, not Apple's shasum runtime.
Optional --real-game reads only the six core files in game-build.sha256.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


CORE = (
    "Phasmophobia.exe",
    "UnityPlayer.dll",
    "GameAssembly.dll",
    "baselib.dll",
    "Phasmophobia_Data/globalgamemanagers",
    "Phasmophobia_Data/il2cpp_data/Metadata/global-metadata.dat",
)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bash", default=shutil.which("bash"))
    parser.add_argument("--real-game", type=Path)
    args = parser.parse_args()
    if not args.bash:
        parser.error("Pass --bash with the path to Bash.")
    kit = Path(__file__).resolve().parents[1]
    verifier = kit / "Verify-Game.command"
    common = kit / "scripts/mac-setup-common.sh"
    generator = kit / "tools/create-game-manifest.py"
    checked: list[str] = []

    for script in (verifier, common):
        subprocess.run(
            [args.bash, "--noprofile", "--norc", "-n", script.as_posix()],
            check=True, capture_output=True, text=True, timeout=30,
        )
    checked.append("Bash parse: verifier and shared helpers")

    # Fixture cleanup stays inside this kit's tools directory. No game directory
    # is created, removed, or modified outside this temporary directory.
    parent = (kit / "tools").resolve()
    with tempfile.TemporaryDirectory(prefix=".verify-qa-", dir=parent) as temp:
        base = Path(temp).resolve()
        if base.parent != parent:
            raise RuntimeError("Temporary test directory escaped the scoped parent.")
        fake_kit = base / "Setup kit with spaces"
        fake_game = base / "Friend's game with spaces" / "Phasmophobia"
        (fake_kit / "scripts").mkdir(parents=True)
        fake_game.mkdir(parents=True)
        shutil.copy2(verifier, fake_kit / verifier.name)
        shutil.copy2(common, fake_kit / "scripts" / common.name)
        contents = {name: f"fixture content: {name}\n".encode() for name in CORE}
        contents["Phasmophobia_Data/asset file with spaces.bin"] = b"asset fixture\n"
        for name, data in contents.items():
            path = fake_game / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        excluded = {
            "OnlineFix.ini": b"mutable fixture\n",
            "OnlineFix.json": b"{}\n",
            "session.log": b"private log fixture\n",
            "SavedScreen0.png": b"generated image fixture\n",
            "_CommonRedist/package.exe": b"installer fixture\n",
        }
        for name, data in excluded.items():
            path = fake_game / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

        generated = subprocess.run(
            [sys.executable, str(generator), str(fake_game), str(fake_kit)],
            capture_output=True, text=True, timeout=30,
        )
        if generated.returncode:
            raise AssertionError(generated.stderr or generated.stdout)
        metadata = json.loads((fake_kit / "game-manifest.json").read_text("utf-8"))
        assert metadata["fileCount"] == len(contents), metadata
        assert {item["path"] for item in metadata["files"]} == set(contents)
        assert (fake_kit / "game-build.sha256").read_text("utf-8").count("\n") == len(CORE)
        assert b"\r" not in (fake_kit / "game-files.sha256").read_bytes()
        assert all(item["sha256"] == digest(fake_game / item["path"]) for item in metadata["files"])
        assert metadata["bytes"] == sum(len(data) for data in contents.values())
        assert metadata["buildIdentity"] == hashlib.sha256((fake_kit / "game-build.sha256").read_bytes()).hexdigest()
        checked.append("Manifest generator: six core files, totals, hashes, exclusions, LF output")

        shim_dir = base / "test bin"
        shim_dir.mkdir()
        shim = shim_dir / "shasum"
        shim.write_text(
            '#!/bin/bash\nset -euo pipefail\n'
            'if [ "$#" -ne 4 ] || [ "$1" != "-a" ] || [ "$2" != "256" ] || [ "$3" != "--check" ]; then\n'
            '  printf "%s\\n" "Unexpected test-adapter arguments" >&2; exit 97\n'
            'fi\n'
            'exec sha256sum --check "$4"\n',
            encoding="utf-8", newline="\n",
        )
        shim.chmod(0o755)
        environment = os.environ.copy()
        environment["PATH"] = str(shim_dir) + os.pathsep + environment.get("PATH", "")
        environment["BASH_COMPAT"] = "3.2"

        def verify(*options: str, expected: int = 0) -> str:
            completed = subprocess.run(
                [args.bash, "--noprofile", "--norc", (fake_kit / verifier.name).as_posix(), *options, "--no-pause"],
                capture_output=True, text=True, env=environment, timeout=60,
                cwd=base,
            )
            output = completed.stdout + completed.stderr
            assert completed.returncode == expected, (completed.returncode, expected, output)
            return output

        output = verify("--game", fake_game.as_posix())
        assert "Core game build matches" in output
        assert "multiplayer compatibility still need a test" in output
        checked.append("Core verification: path spaces and apostrophe, explicit testing caveat")
        verify("--game", (fake_game / "Phasmophobia.exe").as_posix())
        verify("--game", fake_game.parent.as_posix())
        checked.append("Path normalization: executable path and parent directory")
        verify("--game", fake_game.as_posix(), "--full")
        checked.append("Full verification: tiny fixture including asset filename with spaces")

        altered = fake_game / CORE[0]
        altered.write_bytes(b"changed fixture\n")
        output = verify("--game", fake_game.as_posix(), expected=1)
        assert "FAILED" in output and "matches the Windows copy" not in output
        altered.write_bytes(contents[CORE[0]])
        checked.append("Changed file: exit 1 without a success claim")

        missing = fake_game / CORE[-1]
        missing.unlink()
        output = verify("--game", fake_game.as_posix(), expected=1)
        assert "matches the Windows copy" not in output
        missing.write_bytes(contents[CORE[-1]])
        checked.append("Missing metadata: exit 1 without a success claim")

        build_manifest = fake_kit / "game-build.sha256"
        saved_manifest = build_manifest.read_bytes()
        build_manifest.unlink()
        output = verify("--game", fake_game.as_posix(), expected=2)
        assert "manifest is missing" in output
        build_manifest.write_bytes(saved_manifest)
        checked.append("Missing manifest: clear exit 2")

        output = verify("--unknown-option", expected=2)
        assert "Unknown option" in output
        # Do not use verify() here: its --no-pause flag would become --game's value.
        bad_argument = subprocess.run(
            [args.bash, "--noprofile", "--norc", (fake_kit / verifier.name).as_posix(), "--game"],
            capture_output=True, text=True, env=environment, timeout=30,
        )
        assert bad_argument.returncode == 2 and "needs a path" in bad_argument.stderr
        checked.append("CLI argument errors: explicit exit 2")
        assert all((fake_game / name).read_bytes() == data for name, data in (contents | excluded).items())
        checked.append("Verifier left all fixture files unchanged")

        if args.real_game:
            real_game = args.real_game.resolve(strict=True)
            lines = (kit / "game-build.sha256").read_text("utf-8").splitlines()
            parsed = []
            for line in lines:
                match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
                assert match, "Malformed real core manifest"
                expected_hash, relative = match.groups()
                assert relative in CORE, "Unexpected file in real core manifest"
                parsed.append(relative)
                assert digest(real_game / relative) == expected_hash, relative
            assert len(parsed) == len(CORE) and set(parsed) == set(CORE)
            checked.append("Real copy: six core SHA-256 fingerprints independently match")
            real_check = subprocess.run(
                [args.bash, "--noprofile", "--norc", verifier.as_posix(), "--game", real_game.as_posix(), "--no-pause"],
                capture_output=True, text=True, env=environment, timeout=90,
            )
            assert real_check.returncode == 0, real_check.stdout + real_check.stderr
            assert "Core game build matches" in real_check.stdout
            checked.append("Real copy: Bash verification passes with temporary SHA-256 adapter")
    print(json.dumps({
        "passed": len(checked),
        "checks": checked,
        "limits": [
            "Executed on Windows with Git Bash, using BASH_COMPAT=3.2.",
            "Actual macOS Bash 3.2 and native shasum still require the Mac test.",
            "No full 42 GiB rehash, game launch, or multiplayer test was performed.",
        ],
    }, indent=2))


if __name__ == "__main__":
    main()
