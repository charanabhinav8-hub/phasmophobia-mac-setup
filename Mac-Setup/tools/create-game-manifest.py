"""Record this local game copy without including any game content in the kit."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    game = args.game.resolve(strict=True)
    out = args.output.resolve()
    if not (game / "Phasmophobia.exe").is_file():
        raise SystemExit("Choose the complete Phasmophobia game folder.")
    out.mkdir(parents=True, exist_ok=True)
    # Generated screenshots and Windows installers are unnecessary for launch.
    # Mutable launcher/account configuration is not used as a build identity.
    core_names = {
        "Phasmophobia.exe", "UnityPlayer.dll", "GameAssembly.dll", "baselib.dll",
        "Phasmophobia_Data/globalgamemanagers",
        "Phasmophobia_Data/il2cpp_data/Metadata/global-metadata.dat",
    }
    files = sorted(
        (p for p in game.rglob("*") if p.is_file()
         and "_CommonRedist" not in p.relative_to(game).parts
         and not p.name.startswith(("SavedScreen", "SavedVideo"))
         and p.suffix.lower() not in {".log", ".ini"}
         and p.name != "OnlineFix.json"),
        key=lambda p: p.relative_to(game).as_posix(),
    )
    entries = []
    lines = []
    build_lines = []
    for index, path in enumerate(files, 1):
        rel = path.relative_to(game).as_posix()
        if any(character in rel for character in "\n\r\\"):
            raise SystemExit(f"Unsupported manifest path: {rel!r}")
        before = path.stat()
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(8 * 1024 * 1024), b""):
                digest.update(chunk)
        after = path.stat()
        if before.st_size != after.st_size or before.st_mtime_ns != after.st_mtime_ns:
            raise SystemExit(f"File changed while it was being read: {rel}")
        sha = digest.hexdigest()
        entries.append({"path": rel, "bytes": after.st_size, "sha256": sha})
        line = f"{sha}  {rel}\n"
        lines.append(line)
        if rel in core_names:
            build_lines.append(line)
        if index % 100 == 0:
            print(f"Fingerprinted {index}/{len(files)} files", flush=True)
    if len(build_lines) != len(core_names):
        present = {e["path"] for e in entries}
        raise SystemExit(f"Missing core game files: {sorted(core_names - present)}")
    full_manifest = "".join(lines)
    build_manifest = "".join(build_lines)
    identity = hashlib.sha256(build_manifest.encode("utf-8")).hexdigest()
    (out / "game-files.sha256").write_text(full_manifest, encoding="utf-8", newline="\n")
    (out / "game-build.sha256").write_text(build_manifest, encoding="utf-8", newline="\n")
    metadata = {
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "scope": "Local-copy transfer integrity only; not an official publisher authenticity check or multiplayer proof.",
        "buildIdentity": identity,
        "fileCount": len(entries),
        "bytes": sum(e["bytes"] for e in entries),
        "excluded": ["_CommonRedist/", "SavedScreen*", "SavedVideo*", "*.log", "*.ini", "OnlineFix.json"],
        "files": entries,
    }
    (out / "game-manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({k: metadata[k] for k in ("buildIdentity", "fileCount", "bytes")}), flush=True)


if __name__ == "__main__":
    main()
