#!/usr/bin/env python3
"""Obsfucator.py
Lua/Luau obfuscator with safe, practical transforms.

Features
- Identifier renaming (locals + function params)
- Optional string literal encoding
- Optional comment stripping
- Optional whitespace minification
- Backup support
- Dry-run preview + JSON stats
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
import argparse
import base64
import json
import random
import re
import shutil
import string
import time

LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while",
}

BUILTIN_GUARD = {
    "game", "workspace", "script", "Enum", "Color3", "CFrame", "Vector3", "UDim2",
    "Instance", "pairs", "ipairs", "next", "pcall", "xpcall", "print", "warn", "error",
    "string", "table", "math", "os", "coroutine", "task", "type", "typeof", "tonumber",
    "tostring", "getgenv", "loadstring", "require",
}

IDENT = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
LOCAL_DECL = re.compile(r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*)")
FUNC_PARAM = re.compile(r"function\s*[A-Za-z_\.\:]*\s*\((.*?)\)", re.S)
STRING_LIT = re.compile(r"('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")", re.S)
LINE_COMMENT = re.compile(r"--[^\[].*$", re.M)
BLOCK_COMMENT = re.compile(r"--\[\[(.*?)\]\]", re.S)


@dataclass
class ObfuscationStats:
    file: str
    output: str
    bytes_in: int
    bytes_out: int
    renamed_identifiers: int
    encoded_strings: int
    removed_comments: int


class LuaObfuscator:
    def __init__(self, *, seed: int = 1337, rename_prefix: str = "_x") -> None:
        self.rng = random.Random(seed)
        self.rename_prefix = rename_prefix
        self._counter = 0

    def _new_name(self) -> str:
        self._counter += 1
        suffix = ''.join(self.rng.choice(string.ascii_letters) for _ in range(5))
        return f"{self.rename_prefix}{self._counter}_{suffix}"

    def collect_rename_candidates(self, text: str) -> dict[str, str]:
        mapping: dict[str, str] = {}

        for match in LOCAL_DECL.finditer(text):
            name = match.group(1)
            if name in LUA_KEYWORDS or name in BUILTIN_GUARD or len(name) <= 1:
                continue
            mapping.setdefault(name, self._new_name())

        for match in FUNC_PARAM.finditer(text):
            params = [p.strip() for p in match.group(1).split(',') if p.strip()]
            for param in params:
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", param):
                    if param in LUA_KEYWORDS or param in BUILTIN_GUARD or len(param) <= 1:
                        continue
                    mapping.setdefault(param, self._new_name())

        return mapping

    def apply_renames(self, text: str, mapping: dict[str, str]) -> str:
        if not mapping:
            return text

        def repl(m: re.Match[str]) -> str:
            token = m.group(0)
            return mapping.get(token, token)

        return IDENT.sub(repl, text)

    def strip_comments(self, text: str) -> tuple[str, int]:
        removed = 0

        def block_repl(_: re.Match[str]) -> str:
            nonlocal removed
            removed += 1
            return ""

        text = BLOCK_COMMENT.sub(block_repl, text)

        def line_repl(m: re.Match[str]) -> str:
            nonlocal removed
            removed += 1
            return ""

        text = LINE_COMMENT.sub(line_repl, text)
        return text, removed

    def encode_strings(self, text: str) -> tuple[str, int]:
        encoded = 0

        def repl(m: re.Match[str]) -> str:
            nonlocal encoded
            raw = m.group(0)
            quote = raw[0]
            value = raw[1:-1]
            b64 = base64.b64encode(value.encode("utf-8", errors="ignore")).decode("ascii")
            encoded += 1
            return f"(decode64('{b64}'))"

        return STRING_LIT.sub(repl, text), encoded

    @staticmethod
    def minify_whitespace(text: str) -> str:
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        return '\n'.join(line.rstrip() for line in text.splitlines()) + "\n"

    def obfuscate(
        self,
        text: str,
        *,
        rename: bool = True,
        remove_comments: bool = True,
        encode_strings: bool = False,
        minify: bool = False,
        add_watermark: str | None = None,
    ) -> tuple[str, int, int, int]:
        renamed_count = 0
        encoded_count = 0
        removed_comments = 0

        header = ""
        if add_watermark:
            header = f"-- obfuscated: {add_watermark}\n"

        if remove_comments:
            text, removed_comments = self.strip_comments(text)

        mapping = self.collect_rename_candidates(text) if rename else {}
        if mapping:
            text = self.apply_renames(text, mapping)
            renamed_count = len(mapping)

        bootstrap = ""
        if encode_strings:
            text, encoded_count = self.encode_strings(text)
            bootstrap = (
                "local function decode64(v) "
                "return game:GetService('HttpService'):Base64Decode(v) end\n"
            )

        if minify:
            text = self.minify_whitespace(text)

        return header + bootstrap + text, renamed_count, encoded_count, removed_comments


def backup(src: Path) -> Path:
    stamp = time.strftime("%Y%m%d_%H%M%S", time.gmtime())
    dst = src.with_suffix(src.suffix + f".{stamp}.bak")
    shutil.copy2(src, dst)
    return dst


def run_file(args: argparse.Namespace, path: Path) -> ObfuscationStats:
    source = path.read_text(encoding="utf-8")
    obf = LuaObfuscator(seed=args.seed, rename_prefix=args.rename_prefix)

    output, renamed, encoded, removed = obf.obfuscate(
        source,
        rename=not args.no_rename,
        remove_comments=not args.keep_comments,
        encode_strings=args.encode_strings,
        minify=args.minify,
        add_watermark=args.watermark,
    )

    if args.backup and not args.dry_run:
        backup(path)

    out_path = Path(args.output) if args.output else path.with_name(path.stem + ".obf" + path.suffix)
    if not args.dry_run:
        out_path.write_text(output, encoding="utf-8")

    return ObfuscationStats(
        file=str(path),
        output=str(out_path),
        bytes_in=len(source.encode("utf-8")),
        bytes_out=len(output.encode("utf-8")),
        renamed_identifiers=renamed,
        encoded_strings=encoded,
        removed_comments=removed,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Lua/Luau obfuscator")
    parser.add_argument("input", type=Path, help="Input .lua/.luau file")
    parser.add_argument("-o", "--output", help="Output file path")
    parser.add_argument("--seed", type=int, default=1337, help="Random seed")
    parser.add_argument("--rename-prefix", default="_x", help="Prefix for renamed identifiers")
    parser.add_argument("--no-rename", action="store_true", help="Disable identifier renaming")
    parser.add_argument("--keep-comments", action="store_true", help="Do not remove comments")
    parser.add_argument("--encode-strings", action="store_true", help="Encode string literals via base64 decoder")
    parser.add_argument("--minify", action="store_true", help="Minify whitespace")
    parser.add_argument("--watermark", default="Obsfucator.py", help="Watermark text")
    parser.add_argument("--backup", action="store_true", help="Create .bak before writing")
    parser.add_argument("--dry-run", action="store_true", help="Compute and print stats without writing output")
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.input.suffix.lower() not in {".lua", ".luau"}:
        raise SystemExit("Input must be .lua or .luau")

    stats = run_file(args, args.input)
    print(json.dumps(asdict(stats), indent=2))


if __name__ == "__main__":
    main()
