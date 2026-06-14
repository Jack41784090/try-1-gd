#!/usr/bin/env python3
"""
Bakes _*.svg source files into Godot-compatible *.svg.

Godot's SVG renderer (ThorVG) has two limitations inside <clipPath>:
  1. It doesn't support <use> elements.
  2. It doesn't reliably honor nested <g> wrappers (a clip group whose
     shape is buried inside one or more <g> elements is silently dropped,
     so the clip never applies and the clipped fill spills out — e.g. the
     under-eye "shadow" gradient bleeding into the cheek as dark blobs).

This script resolves <use> references by inlining the referenced content,
then FLATTENS each <clipPath> so it contains only bare shape elements
(<path>/<ellipse>/<circle>/<rect>/<polygon>/<polyline>/<line>) with every
ancestor <g>/<use> transform composed down onto each shape. ThorVG clips
reliably against that shape.

Usage:
  python3 tools/bake_svg_clips.py                    # auto-discovers all _*.svg
  python3 tools/bake_svg_clips.py path/to/_head.svg  # specific file(s)
  python3 tools/bake_svg_clips.py --watch            # watch all _*.svg, re-bake on change
  python3 tools/bake_svg_clips.py --watch path/dir   # watch a specific folder (recursive)
"""

import sys
import copy
import re
import time
from pathlib import Path
from lxml import etree

SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
Q = lambda tag: f"{{{SVG_NS}}}{tag}"


def get_href(elem) -> str | None:
    href = elem.get("href") or elem.get(f"{{{XLINK_NS}}}href")
    if href and href.startswith("#"):
        return href[1:]
    return None


def find_by_id(root, elem_id: str):
    results = root.xpath(f'//*[@id="{elem_id}"]')
    return results[0] if results else None


def strip_ids(elem):
    """Remove id attributes from a copied element tree to avoid duplicates."""
    if "id" in elem.attrib:
        del elem.attrib["id"]
    for child in elem:
        strip_ids(child)


def apply_use_transform(elem, use_elem):
    """Merge x/y offset and transform from <use> onto the copied element."""
    x = float(use_elem.get("x", 0))
    y = float(use_elem.get("y", 0))
    use_transform = use_elem.get("transform", "")
    offset = f"translate({x},{y})" if (x or y) else ""
    combined = " ".join(filter(None, [offset, use_transform]))
    if combined:
        existing = elem.get("transform", "")
        elem.set("transform", f"{combined} {existing}".strip() if existing else combined)


def resolve_uses_in_clip_paths(root) -> int:
    """
    Inline <use> references inside <clipPath> elements.
    Returns the number of <use> elements resolved.
    """
    resolved = 0
    for clip_path in root.iter(Q("clipPath")):
        for use in list(clip_path.iter(Q("use"))):
            ref_id = get_href(use)
            if not ref_id:
                continue
            referenced = find_by_id(root, ref_id)
            if referenced is None:
                print(f"  WARNING: <use> references missing id='{ref_id}', skipping")
                continue

            inlined = copy.deepcopy(referenced)
            strip_ids(inlined)
            apply_use_transform(inlined, use)

            parent = use.getparent()
            idx = list(parent).index(use)
            parent.remove(use)
            parent.insert(idx, inlined)
            resolved += 1

    return resolved


SHAPE_TAGS = {"path", "ellipse", "circle", "rect", "polygon", "polyline", "line"}


def _compose(outer: str, inner: str) -> str:
    """Compose two SVG transform attribute strings (outer applied first)."""
    return " ".join(filter(None, [outer.strip(), inner.strip()]))


def collect_clip_shapes(elem, inherited_transform: str, out: list):
    """
    Walk a clipPath subtree, collecting bare shape elements with all ancestor
    <g>/<use> transforms composed onto each shape's own transform.
    """
    combined = _compose(inherited_transform, elem.get("transform", ""))
    tag = etree.QName(elem).localname

    if tag in SHAPE_TAGS:
        shape = copy.deepcopy(elem)
        strip_ids(shape)
        if combined:
            shape.set("transform", combined)
        elif "transform" in shape.attrib:
            del shape.attrib["transform"]
        out.append(shape)
        return

    for child in elem:
        if etree.QName(child).localname in ("g", "use") or etree.QName(child).localname in SHAPE_TAGS:
            collect_clip_shapes(child, combined, out)


def flatten_clip_paths(root) -> int:
    """
    Replace each <clipPath>'s children with the bare shapes it ultimately
    contains, transforms composed down. Returns the number of clipPaths
    that contained <g> wrappers (i.e. needed flattening).
    """
    flattened = 0
    for clip_path in root.iter(Q("clipPath")):
        has_wrapper = any(
            etree.QName(c).localname in ("g", "use") for c in clip_path.iter()
        )
        if not has_wrapper:
            continue  # already bare shapes — leave untouched to avoid churn
        shapes: list = []
        for child in list(clip_path):
            collect_clip_shapes(child, "", shapes)
        if not shapes:
            continue
        for child in list(clip_path):
            clip_path.remove(child)
        for shape in shapes:
            clip_path.append(shape)
        flattened += 1
    return flattened


def bake(src: Path, out: Path):
    parser = etree.XMLParser(remove_blank_text=True)
    tree = etree.parse(str(src), parser)
    root = tree.getroot()

    total = 0
    for _ in range(10):  # max passes to handle nested references
        n = resolve_uses_in_clip_paths(root)
        total += n
        if n == 0:
            break

    flattened = flatten_clip_paths(root)

    tree.write(
        str(out),
        xml_declaration=True,
        encoding="UTF-8",
        pretty_print=True,
    )
    parts = []
    parts.append(f"resolved {total} clip <use>(s)" if total else "no clip <use>")
    parts.append(f"flattened {flattened} clipPath group(s)" if flattened else "no <g> to flatten")
    print(f"{src.name} → {out.name}  ({', '.join(parts)})")


def out_path_for(src: Path) -> Path:
    """The baked output path for a given _*.svg source."""
    return src.parent / (src.stem[1:] + ".svg")  # strip leading _


def discover_sources(args: list) -> tuple[list, list]:
    """
    Resolve CLI args into (source files, watch roots).
    A directory arg becomes a watch root scanned recursively for _*.svg.
    With no args, the default rig_textures tree is used.
    """
    default_root = Path(__file__).parent.parent / "assets" / "rig_textures"
    if not args:
        return sorted(default_root.rglob("_*.svg")), [default_root]

    sources: list = []
    roots: list = []
    for a in args:
        p = Path(a)
        if p.is_dir():
            roots.append(p)
            sources.extend(sorted(p.rglob("_*.svg")))
        else:
            sources.append(p)
            roots.append(p.parent)
    return sources, roots


def bake_safe(src: Path) -> bool:
    """Bake one source, swallowing parse errors (file may be mid-save)."""
    try:
        bake(src, out_path_for(src))
        return True
    except (etree.XMLSyntaxError, OSError) as e:
        print(f"  skip {src.name}: {e}")
        return False


def watch(roots: list, interval: float = 0.5):
    """Poll _*.svg files under the given roots and re-bake on mtime change."""
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass
    roots = sorted({r for r in roots})
    print(f"Watching for _*.svg changes in: {', '.join(str(r) for r in roots)}")
    print("Press Ctrl+C to stop.\n")
    mtimes: dict = {}

    def scan() -> list:
        found: list = []
        for root in roots:
            if root.is_dir():
                found.extend(root.rglob("_*.svg"))
            elif root.exists():
                found.extend(root.parent.glob("_*.svg"))
        return sorted(set(found))

    # Seed without baking so we only react to edits made after startup.
    for src in scan():
        try:
            mtimes[src] = src.stat().st_mtime
        except OSError:
            pass

    try:
        while True:
            for src in scan():
                try:
                    mt = src.stat().st_mtime
                except OSError:
                    continue
                if mtimes.get(src) != mt:
                    mtimes[src] = mt
                    bake_safe(src)
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nStopped watching.")


def main():
    args = sys.argv[1:]
    watch_mode = False
    if args and args[0] in ("--watch", "-w"):
        watch_mode = True
        args = args[1:]

    sources, roots = discover_sources(args)

    if watch_mode:
        watch(roots)
        return

    if not sources:
        print("No _*.svg files found.")
        return

    for src in sources:
        if not src.exists():
            print(f"ERROR: {src} not found")
            continue
        bake(src, out_path_for(src))


if __name__ == "__main__":
    main()
