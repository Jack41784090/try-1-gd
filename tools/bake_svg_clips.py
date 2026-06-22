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
INKSCAPE_NS = "http://www.inkscape.org/namespaces/inkscape"
Q = lambda tag: f"{{{SVG_NS}}}{tag}"


def has_face_layer(root) -> bool:
    """True if the SVG contains an Inkscape 'Face' layer (a layered head)."""
    label = f"{{{INKSCAPE_NS}}}label"
    groupmode = f"{{{INKSCAPE_NS}}}groupmode"
    for g in root.iter(Q("g")):
        if g.get(groupmode) == "layer" and g.get(label) == "Face":
            return True
    return False


def export_faces(src: Path) -> None:
    """Also split a layered head SVG into per-feature/emotion overlay SVGs.

    Lazily imports export_face_features to avoid a circular import (that module
    imports helpers from this one)."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        import export_face_features as eff
    except ImportError as e:
        print(f"  (face export skipped: {e})")
        return
    eff.export_safe(src)


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


def _resolve_use(use, root) -> bool:
    """Inline a single <use> element; return True if resolved."""
    ref_id = get_href(use)
    if not ref_id:
        return False
    referenced = find_by_id(root, ref_id)
    if referenced is None:
        return False

    inlined = copy.deepcopy(referenced)
    strip_ids(inlined)
    apply_use_transform(inlined, use)

    parent = use.getparent()
    idx = list(parent).index(use)
    parent.remove(use)
    parent.insert(idx, inlined)
    return True


def resolve_uses_in_clip_paths(root) -> int:
    """
    Inline <use> references inside <clipPath> elements.
    Returns the number of <use> elements resolved.

    Dangling references (target id missing) are removed silently: a clipPath
    that references nothing contributes no clip region, so the empty <use>
    is just discarded. This keeps the export clean when the source artwork
    contains stale clipPath definitions.
    """
    resolved = 0
    for clip_path in root.iter(Q("clipPath")):
        for use in list(clip_path.iter(Q("use"))):
            if _resolve_use(use, root):
                resolved += 1
            else:
                # Remove dangling <use> so it doesn't pollute the clipPath.
                use.getparent().remove(use)
    return resolved


def _inside_defs(elem) -> bool:
    """True if ``elem`` is nested inside a <defs> element."""
    while elem is not None:
        if etree.QName(elem).localname == "defs":
            return True
        elem = elem.getparent()
    return False


def resolve_all_uses(root, max_passes: int = 20) -> int:
    """
    Inline every rendered <use> element (i.e. outside <defs>), not just those
    inside clipPaths.

    Needed before splitting a layered SVG into per-feature exports: one feature
    (e.g. the right eye) may reference shapes authored in its sibling feature
    (the left eye). Resolving those references first makes each export self-
    contained, so stripping the sibling feature doesn't clip out components.

    Uses inside <defs> are skipped here; the dedicated clipPath resolver handles
    those later and avoids noisy warnings about pre-existing dangling clipPath
    references in the source artwork.
    """
    total = 0
    for _ in range(max_passes):
        # Process in reverse document order so a <use> that acts as a shared
        # symbol (e.g. eye_r's lowlid referencing the eye_l geometry) is copied
        # before the symbol itself is inlined and loses its id.
        uses = [u for u in root.iter(Q("use")) if not _inside_defs(u)]
        if not uses:
            break
        resolved = 0
        for use in reversed(uses):
            if _resolve_use(use, root):
                resolved += 1
        total += resolved
        if resolved == 0:
            break
    return total


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

    # A layered head (Face layer) also feeds the texture-swap expression system —
    # split it into per-feature/emotion overlays right after baking.
    if has_face_layer(root):
        export_faces(src)


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
