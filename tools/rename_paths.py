#!/usr/bin/env python3
"""
rename_paths.py — CONDOR mass-rename utility.

Usage:
    python3 tools/rename_paths.py <manifest.py>            # dry-run
    python3 tools/rename_paths.py <manifest.py> --apply    # actually write

Manifest format (a Python file that defines RENAMES):
    RENAMES = [
        ("old/path.gd", "new/path.gd", "file"),
        ("old/folder", "new/folder", "folder"),
    ]

Behaviour:
  1. git mv each entry (folders moved as a single subtree).
  2. Build a substitution map:
       file  → exact old path string → new path string
       folder → "/old-segment/" → "/new-segment/"  (slash-bounded)
  3. Replace all occurrences in every .gd, .tscn, .tres, .md file
     (plus project.godot if a stage targets it).
     Skips .import, .uid, .git/, .godot/, addons/.
  4. Dry-run prints filename + replacement count; --apply writes.

After running: open the Godot editor or run
    godot --headless --path . --quit
once to rebuild the UID cache, then run the stage's demo scenes.
"""

import subprocess
import sys
import os
import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent

SKIP_DIRS = {".git", ".godot", "addons", "__pycache__", ".obsidian"}
SKIP_SUFFIXES = {".import", ".uid"}
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".md", ".godot", ".csproj"}


def load_manifest(path: str) -> list:
    spec = importlib.util.spec_from_file_location("manifest", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.RENAMES


def git_mv(old: str, new: str):
    old_abs = REPO_ROOT / old
    new_abs = REPO_ROOT / new
    new_abs.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["git", "mv", str(old_abs), str(new_abs)],
        cwd=REPO_ROOT, capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  ERROR git mv {old} -> {new}: {result.stderr.strip()}")
        return False
    print(f"  git mv {old} -> {new}")
    return True


def build_substitutions(renames: list) -> list:
    subs = []
    for old, new, kind in renames:
        if kind == "file":
            subs.append((old, new))
        elif kind == "folder":
            old_seg = f"/{old.rstrip('/')}/"
            new_seg = f"/{new.rstrip('/')}/"
            subs.append((old_seg, new_seg))
            old_res = f"res://{old.rstrip('/')}/"
            new_res = f"res://{new.rstrip('/')}/"
            subs.append((old_res, new_res))
    return subs


def iter_text_files(extra_files: set):
    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            fpath = Path(root) / fname
            rel = str(fpath.relative_to(REPO_ROOT))
            if fpath.suffix in SKIP_SUFFIXES:
                continue
            if fpath.suffix in TEXT_SUFFIXES or rel in extra_files:
                yield fpath


def apply_substitutions(subs: list, apply: bool, extra_files: set):
    total_files = 0
    total_repls = 0
    for fpath in iter_text_files(extra_files):
        try:
            content = fpath.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        new_content = content
        file_repls = 0
        for old, new in subs:
            count = new_content.count(old)
            if count:
                new_content = new_content.replace(old, new)
                file_repls += count
        if file_repls:
            total_files += 1
            total_repls += file_repls
            rel = fpath.relative_to(REPO_ROOT)
            if apply:
                fpath.write_text(new_content, encoding="utf-8")
                print(f"  WRITE {rel}  ({file_repls} replacements)")
            else:
                print(f"  [dry] {rel}  ({file_repls} replacements)")
    print(f"\n{'Applied' if apply else 'Would apply'} {total_repls} replacements across {total_files} files.")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    manifest_path = sys.argv[1]
    apply = "--apply" in sys.argv

    renames = load_manifest(manifest_path)
    extra_files = {r[0] for r in renames if r[2] == "file"} | \
                  {r[1] for r in renames if r[2] == "file"}

    print(f"\n=== {'APPLY' if apply else 'DRY-RUN'} — {len(renames)} rename(s) ===\n")

    print("Step 1: git mv")
    if apply:
        for old, new, kind in renames:
            git_mv(old, new)
    else:
        for old, new, kind in renames:
            print(f"  [dry] git mv {old} -> {new}")

    print("\nStep 2: text substitutions")
    subs = build_substitutions(renames)

    apply_substitutions(subs, apply, extra_files)

    print("\nReminder: run `godot --headless --path . --quit` to rebuild the UID cache,")
    print("then run this stage's demo scenes to verify.\n")


if __name__ == "__main__":
    main()
