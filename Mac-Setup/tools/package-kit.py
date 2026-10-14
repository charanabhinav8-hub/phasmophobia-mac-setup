"""Build the shareable setup ZIP; never package the game or machine reports."""
from __future__ import annotations

import hashlib
import json
import stat
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

import markdown


def main() -> None:
    kit = Path(__file__).resolve().parents[1]
    project = kit.parent
    renderer = markdown.Markdown(extensions=["fenced_code", "tables", "toc"])
    body = renderer.convert((kit / "README.md").read_text(encoding="utf-8"))
    html = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Phasmophobia on the M4 MacBook Pro — setup guide</title>
<style>
* { box-sizing: border-box; }
body { margin: 0; color: #243349; background: #f4f6f9; font: 17px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
main { max-width: 900px; margin: 0 auto; padding: 44px 48px 80px; background: white; min-height: 100vh; }
h1,h2,h3 { color: #153c63; line-height: 1.2; }
h1 { font-size: clamp(1.8rem, 5vw, 2.65rem); letter-spacing: -.035em; margin-top: 0; }
h2 { font-size: 1.5rem; margin: 2.6em 0 .9em; padding-top: .4em; }
h3 { font-size: 1.15rem; margin: 1.8em 0 .7em; }
p,li { max-width: 76ch; }
li { margin: .45em 0; }
a { color: #145cab; text-underline-offset: .18em; }
a:hover { color: #063670; }
a:focus-visible,summary:focus-visible { outline: 3px solid #bb750b; outline-offset: 4px; }
pre { padding: 18px; overflow-x: auto; border: 1px solid #d9e1eb; border-radius: 6px; background: #f2f5f9; font-size: .87em; line-height: 1.55; }
code { font-family: ui-monospace, "SFMono-Regular", Consolas, monospace; overflow-wrap: anywhere; }
p code,li code,td code { background: #f1f4f8; padding: .06em .2em; border-radius: 3px; font-size: .91em; }
table { width: 100%; border-collapse: collapse; font-size: .94em; }
th,td { border: 1px solid #d7dfeb; padding: 12px; text-align: left; vertical-align: top; }
th { background: #edf2f8; }
td:first-child { width: 31%; }
details { margin: 1.5em 0 2em; padding: 14px 20px; background: #edf2f8; border-radius: 6px; }
summary { cursor: pointer; color: #153c63; font-weight: 600; }
.toc { font-size: .92em; }
.toc li { margin: .25em 0; }
footer { margin-top: 4em; font-size: .84em; color: #526379; }
@media (max-width: 600px) { main { padding: 28px 20px 50px; } body { font-size: 16px; } th,td { padding: 8px; } }
@media print { body,main { background: white; } main { max-width: none; padding: 0; } details { display: none; } h2,h3 { break-after: avoid; } pre,table { break-inside: avoid; } a { color: inherit; } }
</style></head><body><main>
""" + "<details><summary>Jump to a step</summary>" + renderer.toc + "</details>" + body + """
<footer>This is an offline copy of README.md. Setup uses Sikarugir; the actual Mac and multiplayer test is still required.</footer>
</main></body></html>
"""
    (kit / "README.html").write_text(html, encoding="utf-8", newline="\n")
    allowed_suffixes = {".md", ".html", ".command", ".sh", ".py", ".ps1", ".sha256", ".json"}
    excluded_names = {"windows-check.json"}
    entries = sorted(
        p for p in kit.rglob("*")
        if p.is_file() and not p.is_symlink()
        and p.suffix in allowed_suffixes
        and p.name not in excluded_names
        and "__pycache__" not in p.parts
    )
    archive = project / "Phasmophobia-Mac-Setup.zip"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=9) as package:
        for path in entries:
            rel = path.relative_to(kit)
            arcname = "Mac-Setup/" + rel.as_posix()
            info = ZipInfo(arcname)
            info.create_system = 3
            mode = 0o755 if path.suffix in {".command", ".sh"} else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = ZIP_DEFLATED
            package.writestr(info, path.read_bytes())
    with ZipFile(archive) as package:
        if package.testzip() is not None:
            raise SystemExit("ZIP integrity check failed.")
        for entry in package.infolist():
            if not entry.filename.startswith("Mac-Setup/") or ".." in Path(entry.filename).parts:
                raise SystemExit("Unexpected archive path.")
            source = kit / entry.filename.removeprefix("Mac-Setup/")
            if package.read(entry.filename) != source.read_bytes():
                raise SystemExit(f"ZIP content mismatch: {entry.filename}")
            if source.suffix in {".command", ".sh"}:
                if b"\r\n" in source.read_bytes():
                    raise SystemExit(f"Mac script must use LF line endings: {source.name}")
                if (entry.external_attr >> 16) & 0o111 != 0o111:
                    raise SystemExit(f"Missing executable bits: {source.name}")
    sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    (project / "Phasmophobia-Mac-Setup.zip.sha256").write_text(
        f"{sha}  {archive.name}\n", encoding="ascii", newline="\n"
    )
    print(json.dumps({"archive": str(archive), "fileCount": len(entries), "bytes": archive.stat().st_size, "sha256": sha}))


if __name__ == "__main__":
    main()
