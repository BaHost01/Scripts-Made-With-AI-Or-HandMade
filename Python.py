#!/usr/bin/env python3
"""Script Tooling Hub

Revamp features:
- repository script inventory
- dry-run remake planning
- optional quick rewrite to readable stubs
- obfuscator integration helper command
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
import argparse
import json
import shutil
import subprocess

SCRIPT_EXTENSIONS = {".lua", ".luau", ".py"}


@dataclass
class ScriptInfo:
    name: str
    ext: str
    bytes: int
    modified_utc: str


@dataclass
class RewriteResult:
    file: str
    backup: str
    status: str


def list_scripts(root: Path) -> list[ScriptInfo]:
    out: list[ScriptInfo] = []
    for path in sorted(root.iterdir()):
        if path.is_file() and path.suffix.lower() in SCRIPT_EXTENSIONS:
            stat = path.stat()
            out.append(
                ScriptInfo(
                    name=path.name,
                    ext=path.suffix.lower(),
                    bytes=stat.st_size,
                    modified_utc=datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat().replace("+00:00", "Z"),
                )
            )
    return out


def make_stub(path: Path) -> str:
    if path.suffix.lower() == ".py":
        return (
            "#!/usr/bin/env python3\n"
            "\"\"\"Readable remade placeholder.\"\"\"\n\n"
            "def main() -> None:\n"
            f"    print('Remade: {path.name}')\n\n"
            "if __name__ == '__main__':\n"
            "    main()\n"
        )

    return (
        f"-- Remade script placeholder: {path.name}\n"
        "return { redesigned = true, generatedBy = 'Python.py' }\n"
    )


def rewrite_scripts(root: Path, dry_run: bool) -> list[RewriteResult]:
    backup_root = root / ".remake_backups"
    backup_root.mkdir(parents=True, exist_ok=True)

    results: list[RewriteResult] = []
    for path in sorted(root.iterdir()):
        if not (path.is_file() and path.suffix.lower() in SCRIPT_EXTENSIONS):
            continue
        if path.name in {"Obsfucator.py"}:
            continue

        stamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        backup = backup_root / f"{path.stem}.{stamp}{path.suffix}.bak"
        shutil.copy2(path, backup)

        if not dry_run:
            path.write_text(make_stub(path), encoding="utf-8")

        results.append(RewriteResult(str(path), str(backup), "planned" if dry_run else "rewritten"))

    return results


def run_obfuscator(file_path: Path, output_path: str | None, dry_run: bool) -> int:
    cmd = ["python3", "Obsfucator.py", str(file_path)]
    if output_path:
        cmd.extend(["-o", output_path])
    if dry_run:
        cmd.append("--dry-run")

    completed = subprocess.run(cmd, check=False)
    return completed.returncode


def main() -> None:
    parser = argparse.ArgumentParser(description="Script Tooling Hub")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--inventory", action="store_true", help="Print inventory JSON")
    parser.add_argument("--rewrite", action="store_true", help="Rewrite scripts into clean placeholders")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--obfuscate", type=Path, help="Run Obsfucator.py against one Lua/Luau file")
    parser.add_argument("--output", help="Output path for --obfuscate")
    args = parser.parse_args()

    if args.inventory:
        print(json.dumps([asdict(x) for x in list_scripts(args.root)], indent=2))

    if args.rewrite:
        print(json.dumps([asdict(x) for x in rewrite_scripts(args.root, args.dry_run)], indent=2))

    if args.obfuscate:
        raise SystemExit(run_obfuscator(args.obfuscate, args.output, args.dry_run))


if __name__ == "__main__":
    main()
