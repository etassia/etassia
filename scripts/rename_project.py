#!/usr/bin/env python3
"""Migrate project names, including generated data, without remeasuring it.

Usage: python3 scripts/rename_project.py OLD NEW
Rebuild the native grammar after migration:
  ruby scripts/build_native_artifact.rb tmp/mermaid.parg lib/etassia/parser/native/mermaid.json
"""

import argparse
from pathlib import Path
import re
import subprocess


# These belong to the independently released native runtime.
NATIVE_NAMES = (
    "sirena-native", "Sirena::Native", "sirena/native", "sirena_ffi", "sirena-ffi",
    "sirena-rs", "SIRENA_NATIVE_LIB",
)
DEPLOYED_SITE_REMAP_URLS = (
    "https://claricle.github.io/sirena/",
    "https://www.claricle.org/sirena/",
)


def migrate(old, new, paths):
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z", "--", *paths]
    ).decode().split("\0")
    replacements = {old: new, old.capitalize(): new.capitalize(), old.upper(): new.upper()}
    pattern = re.compile("|".join(re.escape(s) for s in (*NATIVE_NAMES, *replacements)))

    for name in filter(None, tracked):
        path = Path(name)
        if not path.is_file():
            continue
        if name.startswith("scoreboard/") and path.suffix not in (".json", ".yml"):
            continue
        # The compiler owns the embedded source, checksums and validation record.
        if name.endswith("/parser/native/mermaid.json"):
            continue
        data = path.read_bytes()
        if b"\0" in data:
            continue
        source = data.decode("utf-8")
        file_pattern = pattern
        if name == ".github/workflows/links.yml":
            preserved_urls = "|".join(
                re.escape(url) for url in DEPLOYED_SITE_REMAP_URLS
            )
            file_pattern = re.compile(f"{preserved_urls}|{pattern.pattern}")
        renamed = file_pattern.sub(
            lambda m: replacements.get(m[0], m[0]),
            source,
        )
        renamed = re.sub(rf"claricle/{re.escape(new)}(?![\w-])", f"{new}/{new}", renamed)
        if renamed != source:
            path.write_bytes(renamed.encode("utf-8"))

    # Move the directory trees first, then any remaining named files/fixtures.
    for name in (f"lib/{old}", f"spec/{old}"):
        if Path(name).is_dir() and name.split("/")[0] in paths:
            subprocess.run(["git", "mv", name, name.replace(old, new)], check=True)
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z", "--", *paths]
    ).decode().split("\0")
    for name in filter(None, tracked):
        target = name.replace(old, new)
        if name != target and Path(name).exists():
            Path(target).parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["git", "mv", name, target], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("old")
    parser.add_argument("new")
    parser.add_argument("--paths", nargs="+")
    args = parser.parse_args()
    migrate(args.old, args.new, args.paths or [
        "lib", "spec", "exe", f"{args.old}.gemspec", f"{args.new}.gemspec",
        "tasks", "scripts", "Rakefile", ".simplecov", ".github/workflows",
        "package.json", "package-lock.json", "native_grammar", "scoreboard",
        "docs/claims-manifest.yml",
    ])
