#!/usr/bin/env python3
"""
Splits a layered head SVG into a tree of per-part, per-emotion SVGs.

Authoring model: the head is drawn in Inkscape inside a single "Face" layer.
Every labelled GROUP is a composable part, discovered recursively — there is no
hand-maintained list of expected feature names here. A part's own file holds
only the art that isn't claimed by a nested part, so the parts re-composite into
the original head when stacked (each keeps the master viewBox, so they overlay
with no manual placement).

Two SVG-authored conventions drive the split:

  * A label that is ``Clip`` or ends in ``-Clip``/``_Clip`` (case-insensitive) is
    internal clipping plumbing, never a part.
  * A label ending in ``+clip`` opts that part (and everything nested inside it)
    into keeping the container's face-silhouette clip, so shapes that would
    otherwise overflow the head outline at the temple/cheek stay inside it.

Directly under each top-level part sits one sub-group per EMOTION, labelled by
emotion name (e.g. ``eye_l`` -> {neutral, blink, wide}); those names are learnt
from the source and treated as variant selectors wherever they appear. A nested
part an emotion doesn't author is emitted EMPTY rather than skipped, so a
lookup never silently falls back to the neutral art (a blinking eye must not
show its neutral eye-white through the closed lashes).

Applied to rachelle/_head.svg this emits, into ``face/``:

  head_base_neutral.svg          head minus every part and standalone layer
  hair_back_neutral.svg          the HairBack layer, its own behind-body sprite
  eye_l_<emotion>.svg            eye_l minus white/lashes (the lower lid)
  eye_l_white_<emotion>.svg      the eye white, minus the pupil
  eye_l_white_pupil_<emotion>.svg
  eye_l_lashes_<emotion>.svg
  eye_r_… (mirrored)  brow_l_<emotion>.svg  brow_r_…  mouth_<emotion>.svg

Each output names itself so the Godot side never has to parse the filename back
into a tree: the root carries ``data-part-path`` (slash-joined part names) and
``data-pivot`` (the art's bounding-box centre as a 0..1 fraction of the canvas,
queried from Inkscape). ``tools/bake_rig_scene.gd`` reads both to build the
FaceComponent tree and to anchor each sprite's scale/rotation on its own art
instead of the canvas centre.

Outputs no longer produced by a run are pruned, so renaming a group in Inkscape
doesn't leave an orphan SVG behind.

Reuses bake_svg_clips.py for the ThorVG clipPath workarounds (resolve <use> in
clip paths, flatten clip groups) and the same 0.5s mtime watch loop style.

Usage:
  python3 tools/export_face_features.py                 # default: rachelle/_head.svg
  python3 tools/export_face_features.py path/_head.svg  # specific source(s)
  python3 tools/export_face_features.py --watch         # re-export on edit
"""

import copy
import subprocess
import sys
import time
from pathlib import Path
from lxml import etree

from bake_svg_clips import (
    Q,
    resolve_uses_in_clip_paths,
    resolve_all_uses,
    flatten_clip_paths,
)

SVG_NS = "http://www.w3.org/2000/svg"
INKSCAPE_NS = "http://www.inkscape.org/namespaces/inkscape"
LABEL = f"{{{INKSCAPE_NS}}}label"
GROUPMODE = f"{{{INKSCAPE_NS}}}groupmode"

# The Inkscape layer that holds the facial parts.
FACE_LAYER_LABEL = "Face"

# Emotion used as the suffix for emotion-independent outputs (base head, hair)
# and as the variant every part is expected to author.
DEFAULT_EMOTION = "neutral"

# Output name -> whole Inkscape layer (inkscape:label) exported on its own. These
# are full layers rather than parts inside the Face container, and are likewise
# removed from the base, so e.g. hair_back can render as its own sprite behind
# the body. Layers have no discovery convention to key off — unlike parts, being
# a layer says nothing about whether it wants to be a separate sprite.
FEATURE_LAYERS = {
    "hair_back": "HairBack",
}

# Elements kept when isolating a part: structural/metadata siblings that carry no
# art of their own but that the output still needs.
NON_ART_TAGS = {"defs", "metadata", "title", "desc", "style"}

# Elements that put ink on the canvas — used to tell an empty export apart from
# one that just happens to be small.
ART_TAGS = {
    "path", "ellipse", "circle", "rect", "polygon", "polyline", "line",
    "text", "image", "use",
}

DEFAULT_SOURCE = (
    Path(__file__).parent.parent / "assets" / "rig_textures" / "rachelle" / "_head.svg"
)


#region Label conventions

def is_plumbing(label: str) -> bool:
    """True for clip-wiring labels (``Clip``, ``Base-Clip``, ``eye_Clip``, ...)."""
    low = label.lower()
    return low == "clip" or low.endswith("-clip") or low.endswith("_clip")


def parse_part_label(label: str) -> tuple[str, bool]:
    """(part name, keeps-the-container-clip) for a labelled group."""
    if label.lower().endswith("+clip"):
        return label[: -len("+clip")], True
    return label, False


def labelled_groups(elem) -> list:
    """Direct <g> children carrying an inkscape:label."""
    return [
        c for c in elem
        if etree.QName(c).localname == "g" and c.get(LABEL) is not None
    ]


def child_parts(scope, path: tuple, emotion_names: set) -> list:
    """(element, name, keeps-container-clip) for each part directly under ``scope``.

    Everything else the scope holds — plumbing, loose shapes, the variant groups
    — is that part's own art.
    """
    out = []
    for child in labelled_groups(scope):
        label = child.get(LABEL)
        if is_plumbing(label) or label in emotion_names:
            continue
        name, clip = parse_part_label(label)
        # Inlining a <use> brings the referenced part's label along with its art
        # (the far eye's fill is a transformed copy of the near eye's). A part
        # can't contain itself, so that copy is this part's own art, not a part.
        if name in path:
            continue
        out.append((child, name, clip))
    return out

#endregion


#region Structure discovery

def find_layer(root, label: str):
    for g in root.iter(Q("g")):
        if g.get(GROUPMODE) == "layer" and g.get(LABEL) == label:
            return g
    return None


def find_feature_container(root):
    """The group that directly holds the labelled part children.

    Inkscape nests the parts inside an (often unlabelled, transformed) <g>
    wrapper within the Face layer, so descend through those single-child
    wrappers rather than assuming a fixed depth.
    """
    node = find_layer(root, FACE_LAYER_LABEL)
    if node is None:
        return None
    while True:
        children = [c for c in node if isinstance(c.tag, str)]
        if len(children) != 1:
            return node
        only = children[0]
        if etree.QName(only).localname != "g" or only.get(LABEL) is not None:
            return node
        node = only


def discover_emotions(container) -> set:
    """Emotion names = the labels sitting directly under each top-level part."""
    emotions = set()
    for part in labelled_groups(container):
        if is_plumbing(part.get(LABEL)):
            continue
        for sub in labelled_groups(part):
            if not is_plumbing(sub.get(LABEL)):
                emotions.add(sub.get(LABEL))
    return emotions


def index_path(elem, root) -> tuple:
    """Child-index route from ``root`` down to ``elem``, valid on any deep copy."""
    route = []
    while elem is not root:
        parent = elem.getparent()
        route.append(list(parent).index(elem))
        elem = parent
    return tuple(reversed(route))


def follow(root, route: tuple):
    node = root
    for i in route:
        node = node[i]
    return node


def scan_parts(elem, path: tuple, clip_to_base: bool, emotions_ctx: set,
               emotion_names: set, root, out: dict) -> None:
    """Recursively register every part under ``elem`` into ``out``.

    ``out[path]`` collects, per emotion, the SCOPE element whose direct children
    make up that part's art for that emotion — the emotion sub-group for a part
    that authors variants, the part group itself otherwise.
    """
    variants = {
        c.get(LABEL): c for c in labelled_groups(elem)
        if c.get(LABEL) in emotion_names
    }
    entry = out.setdefault(path, {"clip": clip_to_base, "scopes": {}})
    entry["clip"] = entry["clip"] or clip_to_base
    scopes = variants.items() if variants else [(e, elem) for e in emotions_ctx]
    for emotion, scope in scopes:
        entry["scopes"][emotion] = index_path(scope, root)
        for child, name, child_clip in child_parts(scope, path, emotion_names):
            scan_parts(child, path + (name,), clip_to_base or child_clip,
                       {emotion}, emotion_names, root, out)


def default_scope(part, emotion_names: set):
    """The sub-group a part shows for the default emotion, or the part itself."""
    variants = [c for c in labelled_groups(part) if c.get(LABEL) in emotion_names]
    if not variants:
        return part
    for variant in variants:
        if variant.get(LABEL) == DEFAULT_EMOTION:
            return variant
    return variants[0]


def paint_order(scope, path: tuple, emotion_names: set, order: dict,
                counter: list) -> None:
    """Rank parts by where their OWN art sits in a depth-first document walk.

    Ranking a part by where its group starts would put it under everything it
    contains, but a part's art can legitimately sit on top of a nested one — the
    dark eye-line strokes are authored after the pupil inside the same group.
    Walking the art itself keeps the stack faithful to the source. Sprites use an
    absolute z_index, so this ordering is free to disagree with the scene tree's
    parenting, which exists to share transforms. The default emotion decides the
    ranking; a part keeps one z whichever variant it is currently showing.
    """
    # Hold the children in a list: lxml hands out element proxies, and an id()
    # can be reused once the last reference to one is dropped.
    kids = list(scope)
    nested = {id(c): name for c, name, _ in child_parts(scope, path, emotion_names)}
    for child in kids:
        if not isinstance(child.tag, str):
            continue
        if id(child) in nested:
            paint_order(default_scope(child, emotion_names),
                        path + (nested[id(child)],), emotion_names, order, counter)
        elif path not in order:
            order[path] = counter[0]
            counter[0] += 1
    order.setdefault(path, counter[0])

#endregion


#region Export

def force_visible(elem) -> None:
    """Clear Inkscape's editor 'hidden' state so a kept group always renders.

    Inkscape writes style="display:none" (or display="none") on groups toggled
    off in the layers panel — e.g. a 'neutral' eye sub-group hidden while 'wide'
    is shown. That editing state must not leak into the exported overlay."""
    if elem.get("display") == "none":
        del elem.attrib["display"]
    style = elem.get("style")
    if style and "display:none" in style:
        elem.set("style", style.replace("display:none", "display:inline"))


def is_drawable_layer(elem) -> bool:
    return etree.QName(elem).localname == "g" and elem.get(GROUPMODE) == "layer"


def _referenced_clip_ids(root) -> set:
    ids = set()
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        for source in (el.get("clip-path"), el.get("style") or ""):
            if source and "url(#" in source:
                start = source.index("url(#") + len("url(#")
                ids.add(source[start: source.index(")", start)])
    return ids


def prune_unused_clip_paths(root) -> None:
    """Drop <clipPath>s no kept element references (e.g. hair clips left behind
    when a part is isolated). Avoids dangling <use> refs into removed art."""
    referenced = _referenced_clip_ids(root)
    for cp in list(root.iter(Q("clipPath"))):
        if cp.get("id") not in referenced:
            cp.getparent().remove(cp)


def resolved_master(src_tree) -> etree._ElementTree:
    """A copy of the source with every <use> inlined, ready to slice up.

    Rendered <use>s go first so a part that reuses a sibling's geometry (the
    right eye borrowing the left eye's shapes) survives that sibling being
    stripped. Clip <use>s follow, while their referenced shapes still exist, so
    every clipPath ends up self-contained — isolating a part must not leave one
    of its clips pointing at art that isolation just removed.
    """
    tree = copy.deepcopy(src_tree)
    root = tree.getroot()
    resolve_all_uses(root)
    for _ in range(10):
        if resolve_uses_in_clip_paths(root) == 0:
            break
    return tree


def isolate(root, scope) -> None:
    """Strip everything that isn't on the route from ``root`` down to ``scope``.

    Sibling layers, sibling parts and the sibling emotion sub-groups all go, so
    what's left is this part's own branch — forced visible, since Inkscape marks
    the variants it isn't currently showing display:none.
    """
    node = scope
    while node is not root:
        parent = node.getparent()
        for sibling in list(parent):
            if sibling is node or not isinstance(sibling.tag, str):
                continue
            qname = etree.QName(sibling)
            if qname.namespace != SVG_NS or qname.localname in NON_ART_TAGS:
                continue
            parent.remove(sibling)
        force_visible(node)
        node = parent


def strip_ancestor_clips(root, container, clip_to_base: bool) -> None:
    """Drop the base-head silhouette clip the container and its ancestors carry.

    Its clip shape lives with the base head, which isolation just removed, so
    keeping it would clip the part down to nothing — unless the part opted in
    via ``+clip``, in which case the container's clip is retained (it is
    self-contained by then, see ``resolved_master``) and the part stays inside
    the face outline exactly as in the composite. Clips BELOW the container are
    the part's own (eye/pupil) clipping and are left alone.
    """
    node = container
    while node is not None and node is not root:
        if "clip-path" in node.attrib and not (clip_to_base and node is container):
            del node.attrib["clip-path"]
        node = node.getparent()


def export_part(master, scope_route: tuple, container_route: tuple, path: tuple,
                emotion_names: set, clip_to_base: bool) -> etree._ElementTree:
    """One part's own art for one emotion: its scope minus every nested part."""
    tree = copy.deepcopy(master)
    root = tree.getroot()
    scope = follow(root, scope_route)
    container = follow(root, container_route)

    isolate(root, scope)
    strip_ancestor_clips(root, container, clip_to_base)

    # Whatever a nested part claims is exported in that part's own file.
    for child, _, _ in child_parts(scope, path, emotion_names):
        scope.remove(child)

    prune_unused_clip_paths(root)
    flatten_clip_paths(root)
    return tree


def export_empty(master, container_route: tuple) -> etree._ElementTree:
    """A blank canvas for a part an emotion doesn't author.

    Emitted rather than skipped so the Godot side finds a texture for every
    (part, emotion) pair and never falls back to the neutral art — a blink has
    no eye white, and must not borrow the open eye's.
    """
    tree = copy.deepcopy(master)
    root = tree.getroot()
    container = follow(root, container_route)
    isolate(root, container)
    for child in list(container):
        if isinstance(child.tag, str):
            container.remove(child)
    prune_unused_clip_paths(root)
    return tree


def export_base(master, container_route: tuple) -> etree._ElementTree:
    """The head minus the parts and the separately-exported layers.

    Unlike a part export this keeps the other layers (hair, line work): the base
    is the Head bone's own texture, not an overlay.
    """
    tree = copy.deepcopy(master)
    root = tree.getroot()
    container = follow(root, container_route)
    for child, _, _ in child_parts(container, (), set()):
        container.remove(child)
    for layer_label in FEATURE_LAYERS.values():
        layer = find_layer(root, layer_label)
        if layer is not None:
            layer.getparent().remove(layer)
    prune_unused_clip_paths(root)
    flatten_clip_paths(root)
    return tree


def export_layer(master, layer_label: str) -> etree._ElementTree:
    """Build a tree containing only <defs> + the named Inkscape layer."""
    tree = copy.deepcopy(master)
    root = tree.getroot()
    target = find_layer(root, layer_label)
    if target is None:
        raise ValueError(f"no '{layer_label}' layer found")
    for layer in list(root):
        if is_drawable_layer(layer) and layer is not target:
            root.remove(layer)
    prune_unused_clip_paths(root)
    flatten_clip_paths(root)
    return tree


def has_art(tree) -> bool:
    root = tree.getroot()
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        qname = etree.QName(el)
        if qname.namespace == SVG_NS and qname.localname in ART_TAGS:
            node = el.getparent()
            while node is not None and etree.QName(node).localname != "defs":
                node = node.getparent()
            if node is None:
                return True
    return False

#endregion


#region Pivot

def canvas_size(root) -> tuple[float, float]:
    box = (root.get("viewBox") or "").split()
    if len(box) == 4:
        return float(box[2]), float(box[3])
    return float(root.get("width", 1)), float(root.get("height", 1))


def query_pivot(path: Path, width: float, height: float) -> tuple[float, float]:
    """Bounding-box centre of a written SVG, as a 0..1 fraction of the canvas.

    A Sprite2D scales and rotates around its texture centre, which for a
    full-canvas overlay is the middle of the whole face — a pupil shrink would
    creep toward the nose. Inkscape gives the exact visual bounds of the art, so
    the sprite can be anchored on itself instead. Falls back to the canvas
    centre (i.e. today's behaviour) when Inkscape isn't available.
    """
    try:
        result = subprocess.run(
            ["inkscape", "--query-x", "--query-y", "--query-width",
             "--query-height", str(path)],
            capture_output=True, text=True, timeout=60, check=True,
        )
        x, y, w, h = (float(v) for v in result.stdout.split())
    except (OSError, subprocess.SubprocessError, ValueError) as e:
        print(f"  ! pivot fallback for {path.name} (Inkscape query failed: {e})")
        return 0.5, 0.5
    return (x + w / 2.0) / width, (y + h / 2.0) / height

#endregion


def write_tree(tree, out: Path, part_path: str, order: int, pivot: tuple | None) -> None:
    root = tree.getroot()
    root.set("data-part-path", part_path)
    root.set("data-order", str(order))
    if pivot is not None:
        root.set("data-pivot", f"{pivot[0]:.6f},{pivot[1]:.6f}")
    out.parent.mkdir(parents=True, exist_ok=True)
    tree.write(str(out), xml_declaration=True, encoding="UTF-8", pretty_print=True)


def emit(tree, out_dir: Path, stem: str, part_path: str, order: int,
         written: list) -> None:
    """Write one output, then stamp it with the pivot Inkscape measures on it."""
    out = out_dir / f"{stem}.svg"
    width, height = canvas_size(tree.getroot())
    write_tree(tree, out, part_path, order, None)
    pivot = query_pivot(out, width, height) if has_art(tree) else (0.5, 0.5)
    write_tree(tree, out, part_path, order, pivot)
    written.append(out.name)


def prune_stale(out_dir: Path, written: list) -> None:
    """Delete outputs a previous run produced that this one no longer does."""
    keep = set(written)
    for existing in sorted(out_dir.glob("*.svg")):
        if existing.name in keep:
            continue
        existing.unlink()
        sidecar = existing.with_suffix(".svg.import")
        if sidecar.exists():
            sidecar.unlink()
        print(f"  - pruned {existing.name}")


def export(src: Path) -> None:
    parser = etree.XMLParser(remove_blank_text=True)
    src_tree = etree.parse(str(src), parser)
    master = resolved_master(src_tree)
    container = find_feature_container(master.getroot())
    if container is None:
        raise ValueError(f"no '{FACE_LAYER_LABEL}' layer / part container found")

    emotion_names = discover_emotions(container)
    parts: dict = {}
    scan_parts(container, (), False, {DEFAULT_EMOTION}, emotion_names,
               master.getroot(), parts)
    order: dict = {}
    paint_order(container, (), emotion_names, order, [0])
    container_route = index_path(container, master.getroot())

    out_dir = src.parent / "face"
    written: list = []

    # The container's own remainder is the head base: everything no part claims.
    emit(export_base(master, container_route), out_dir,
         f"head_base_{DEFAULT_EMOTION}", "", 0, written)

    # A nested part inherits the emotions its top-level ancestor authors, and is
    # emitted empty for the ones it doesn't itself define, so nothing falls back.
    for path, entry in parts.items():
        if not path:
            continue
        for emotion in sorted(parts[path[:1]]["scopes"]):
            scope_route = entry["scopes"].get(emotion)
            tree = (export_empty(master, container_route) if scope_route is None
                    else export_part(master, scope_route, container_route, path,
                                     emotion_names, entry["clip"]))
            emit(tree, out_dir, "_".join(path) + f"_{emotion}",
                 "/".join(path), order[path], written)

    # Standalone layers sit behind the whole body, so they paint before anything.
    for name, layer_label in FEATURE_LAYERS.items():
        emit(export_layer(master, layer_label), out_dir,
             f"{name}_{DEFAULT_EMOTION}", name, -1, written)

    prune_stale(out_dir, written)
    print(f"{src.name} → face/ ({len(written)} files)")


def export_safe(src: Path) -> bool:
    try:
        export(src)
        return True
    except (etree.XMLSyntaxError, OSError, ValueError) as e:
        print(f"  skip {src.name}: {e}")
        return False


def watch(sources: list, interval: float = 0.5) -> None:
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass
    print("Watching for changes in: " + ", ".join(str(s) for s in sources))
    print("Press Ctrl+C to stop.\n")
    mtimes = {s: s.stat().st_mtime for s in sources if s.exists()}
    try:
        while True:
            for src in sources:
                if not src.exists():
                    continue
                mt = src.stat().st_mtime
                if mtimes.get(src) != mt:
                    mtimes[src] = mt
                    export_safe(src)
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nStopped watching.")


def main() -> None:
    args = sys.argv[1:]
    watch_mode = False
    if args and args[0] in ("--watch", "-w"):
        watch_mode = True
        args = args[1:]

    sources = [Path(a) for a in args] if args else [DEFAULT_SOURCE]

    if watch_mode:
        watch(sources)
        return

    for src in sources:
        if not src.exists():
            print(f"ERROR: {src} not found")
            continue
        export(src)


if __name__ == "__main__":
    main()
