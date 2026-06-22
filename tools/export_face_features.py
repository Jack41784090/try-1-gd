#!/usr/bin/env python3
"""
Splits a layered head SVG into per-feature, per-variant SVGs for sprite-swapping.

Authoring model: the head is drawn in Inkscape inside a single "Face" layer.
The features are labelled GROUPS (eye_l, eye_r, brow_l, brow_r, lips), and each
of those groups holds one sub-group per EMOTION, labelled by emotion name
(e.g. eye_l -> {neutral, wide}). All emotions therefore live in one file. This
tool discovers the emotion names from those sub-groups and emits, per emotion:

  face/head_base_neutral.svg   head minus the feature groups (Head bone texture)
  face/eye_l_<emotion>.svg     left (near) eye, that emotion's sub-group only
  face/eye_r_<emotion>.svg     right (far) eye, that emotion's sub-group only
  face/mouth_<emotion>.svg     lips, that emotion's sub-group only
  face/brows_<emotion>.svg     brow_l + brow_r, that emotion's sub-group only

The left and right eyes are emitted as separate overlays so each can be swapped
independently (winks, asymmetric expressions).

A feature only emits the emotions it actually authors; a group missing the
requested emotion falls back to its "neutral" sub-group. The base head and hair
don't vary by emotion, so they're emitted once with the "neutral" suffix.

Every output keeps the source viewBox/size, so the feature sprites overlay the
head base in the same coordinate space with no manual placement.

Reuses bake_svg_clips.py for the ThorVG clipPath workarounds (resolve <use> in
clip paths, flatten clip groups) and the same 0.5s mtime watch loop style.

Usage:
  python3 tools/export_face_features.py                 # default: rachelle/_head.svg
  python3 tools/export_face_features.py path/_head.svg  # specific source(s)
  python3 tools/export_face_features.py --watch         # re-export on edit
"""

import sys
import copy
import time
from pathlib import Path
from lxml import etree

from bake_svg_clips import (
    Q,
    resolve_uses_in_clip_paths,
    resolve_all_uses,
    flatten_clip_paths,
)

INKSCAPE_NS = "http://www.inkscape.org/namespaces/inkscape"
LABEL = f"{{{INKSCAPE_NS}}}label"
GROUPMODE = f"{{{INKSCAPE_NS}}}groupmode"

# The Inkscape layer that holds the facial features.
FACE_LAYER_LABEL = "Face"

# Output feature -> set of inkscape:labels of the feature-GROUP containers that
# sit as direct children of the Face container. Each such group holds one
# sub-group per emotion, labelled by emotion name (e.g. eye_l -> {neutral, wide}).
# Anything not listed here (shadow, nose, blush, Base-Clip, ...) stays with the
# base head.
FEATURE_GROUPS = {
    "eye_l": {"eye_l"},
    "eye_r": {"eye_r"},
    "mouth": {"lips"},
    "brows": {"brow_l", "brow_r"},
}

# Union of all feature-group labels — these groups are stripped from the base.
ALL_FEATURE_LABELS = set().union(*FEATURE_GROUPS.values())

# Emotion used both as the fallback when a feature group lacks a sub-group for
# the requested emotion (e.g. brows/mouth only author "neutral" while the eyes
# add "wide"), and as the suffix for the emotion-independent base/hair outputs.
DEFAULT_EMOTION = "neutral"

# Features whose shapes should stay clipped to the base-face silhouette (the
# container's clip-path) instead of having that clip stripped. Eyes and brows can
# otherwise overflow the face outline at the temple/cheek edges; clipping them to
# the base keeps them inside the head exactly as in the composited source.
CLIP_TO_BASE_FEATURES = {"eye_l", "eye_r", "brows"}

# Output name -> whole Inkscape layer (inkscape:label) exported on its own. These
# are full layers (not children of the Face container) and are likewise removed
# from the base, so e.g. hair_back can render as its own behind-the-body sprite.
FEATURE_LAYERS = {
    "hair_back": "HairBack",
}

DEFAULT_SOURCE = (
    Path(__file__).parent.parent / "assets" / "rig_textures" / "rachelle" / "_head.svg"
)


def feature_group_emotions(container, group_labels: set) -> set:
    """Emotion names a feature offers = union of its groups' sub-group labels."""
    emotions = set()
    for grp in container:
        if grp.get(LABEL) in group_labels:
            for sub in grp:
                label = sub.get(LABEL)
                if label is not None:
                    emotions.add(label)
    return emotions


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


def select_emotion_subgroup(group, emotion: str) -> None:
    """Keep only the sub-group for ``emotion`` in ``group`` (fall back to the
    DEFAULT_EMOTION sub-group when the requested one is absent); drop the rest.
    The kept sub-group is forced visible. Unlabelled children are left alone."""
    labelled = [c for c in group if c.get(LABEL) is not None]
    chosen = next((c for c in labelled if c.get(LABEL) == emotion), None)
    if chosen is None:
        chosen = next((c for c in labelled if c.get(LABEL) == DEFAULT_EMOTION), None)
    for child in labelled:
        if child is not chosen:
            group.remove(child)
    if chosen is not None:
        force_visible(chosen)


def find_layer(root, label: str):
    for g in root.iter(Q("g")):
        if g.get(GROUPMODE) == "layer" and g.get(LABEL) == label:
            return g
    return None


def find_face_layer(root):
    return find_layer(root, FACE_LAYER_LABEL)


def find_feature_container(root):
    """The group that directly holds the labelled feature children.

    Inkscape nests the features inside an (often unlabelled, transformed) <g>
    wrapper within the Face layer, so we locate that wrapper by finding the
    parent of a known feature label rather than assuming a fixed depth.
    """
    for label in ALL_FEATURE_LABELS:
        els = root.xpath(
            f'//*[@inkscape:label="{label}"]', namespaces={"inkscape": INKSCAPE_NS}
        )
        if els:
            return els[0].getparent()
    return None


def is_drawable_layer(elem) -> bool:
    return etree.QName(elem).localname == "g" and elem.get(GROUPMODE) == "layer"


def _referenced_clip_ids(root) -> set:
    ids = set()
    for el in root.iter():
        for source in (el.get("clip-path"), el.get("style") or ""):
            if source and "url(#" in source:
                start = source.index("url(#") + len("url(#")
                ids.add(source[start: source.index(")", start)])
    return ids


def prune_unused_clip_paths(root) -> None:
    """Drop <clipPath>s no kept element references (e.g. hair clips left behind
    when a feature is isolated). Avoids dangling <use> refs into removed art."""
    referenced = _referenced_clip_ids(root)
    for cp in list(root.iter(Q("clipPath"))):
        if cp.get("id") not in referenced:
            cp.getparent().remove(cp)


def _bake_clips(root) -> None:
    """Apply the ThorVG clipPath workarounds in place (same as bake_svg_clips)."""
    prune_unused_clip_paths(root)
    for _ in range(10):
        if resolve_uses_in_clip_paths(root) == 0:
            break
    flatten_clip_paths(root)


def export_feature(
    src_tree, feature: str, group_labels: set, emotion: str, clip_to_base: bool = False
) -> etree._ElementTree:
    """Build a tree containing only <defs> + the feature's groups for one emotion.

    Keeps the feature's group containers (e.g. eye_l/eye_r), and within each
    keeps only the sub-group for ``emotion`` (or the neutral fallback).

    When ``clip_to_base`` is set, the container's face-silhouette clip-path is
    retained so the kept feature is clipped to the base face outline (used for
    the eyes). The silhouette clip pulls its shape in via a <use> of the Base
    group, which lives among the non-feature children we strip — so we resolve
    that <use> into <defs> *first*, while the Base shape still exists, making the
    clip self-contained before the strip.
    """
    tree = copy.deepcopy(src_tree)
    root = tree.getroot()

    # The right eye/brow reuse geometry authored in the left eye/brow via <use>.
    # Inline those references before any sibling groups/layers are stripped so
    # the exported feature stays self-contained and doesn't lose components.
    resolve_all_uses(root)

    face = find_face_layer(root)
    container = find_feature_container(root)
    if face is None or container is None:
        raise ValueError(f"no '{FACE_LAYER_LABEL}' layer / feature container found")

    # Drop every layer except the Face layer (hair, guides, etc.).
    for layer in list(root):
        if is_drawable_layer(layer) and layer is not face:
            root.remove(layer)

    if clip_to_base:
        # Inline the silhouette clip's <use> of the Base group now, before the
        # Base shape is stripped below, so the clip survives self-contained.
        for _ in range(10):
            if resolve_uses_in_clip_paths(root) == 0:
                break

    # Keep only this feature's group containers inside the Face container, then
    # collapse each to the requested emotion's sub-group.
    for child in list(container):
        if child.get(LABEL) not in group_labels:
            container.remove(child)
    for group in list(container):
        select_emotion_subgroup(group, emotion)

    # The container/Face layer carry the face-silhouette clip-path, whose clip
    # source (the Base shape) lives with the head base and is removed here. Drop
    # those ancestor clips so the kept features aren't clipped to nothing; the
    # features' own (eye/pupil) clip-paths are descendants and stay intact.
    # Exception: when clip_to_base, retain the silhouette clip on the container
    # so the feature is clipped to the base face (the clip is now self-contained
    # via the pre-resolved <use> above).
    node = container
    while node is not None and node is not root:
        if "clip-path" in node.attrib and not (clip_to_base and node is container):
            del node.attrib["clip-path"]
        node = node.getparent()

    _bake_clips(root)
    return tree


def export_layer(src_tree, layer_label: str) -> etree._ElementTree:
    """Build a tree containing only <defs> + the named Inkscape layer."""
    tree = copy.deepcopy(src_tree)
    root = tree.getroot()

    # Inline any cross-layer <use> references before dropping other layers.
    resolve_all_uses(root)

    target = find_layer(root, layer_label)
    if target is None:
        raise ValueError(f"no '{layer_label}' layer found")

    for layer in list(root):
        if is_drawable_layer(layer) and layer is not target:
            root.remove(layer)

    _bake_clips(root)
    return tree


def export_base(src_tree) -> etree._ElementTree:
    """Build the head minus the separately-exported features and layers."""
    tree = copy.deepcopy(src_tree)
    root = tree.getroot()

    # Inline <use> references before stripping feature groups/layers so any
    # base-head geometry that reuses feature shapes survives on its own.
    resolve_all_uses(root)

    container = find_feature_container(root)
    if container is None:
        raise ValueError("no feature container found")

    for child in list(container):
        if child.get(LABEL) in ALL_FEATURE_LABELS:
            container.remove(child)

    # Layers exported on their own (e.g. HairBack) are removed from the base too.
    for layer_label in FEATURE_LAYERS.values():
        layer = find_layer(root, layer_label)
        if layer is not None:
            layer.getparent().remove(layer)

    _bake_clips(root)
    return tree


def write_tree(tree, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    tree.write(str(out), xml_declaration=True, encoding="UTF-8", pretty_print=True)


def export(src: Path) -> None:
    parser = etree.XMLParser(remove_blank_text=True)
    src_tree = etree.parse(str(src), parser)
    container = find_feature_container(src_tree.getroot())
    if container is None:
        raise ValueError("no feature container found")
    out_dir = src.parent / "face"

    written: list = []
    # The base head and standalone layers (hair) don't vary by emotion.
    write_tree(export_base(src_tree), out_dir / f"head_base_{DEFAULT_EMOTION}.svg")
    written.append(f"head_base_{DEFAULT_EMOTION}")

    for feature, group_labels in FEATURE_GROUPS.items():
        emotions = feature_group_emotions(container, group_labels) or {DEFAULT_EMOTION}
        clip_to_base = feature in CLIP_TO_BASE_FEATURES
        for emotion in sorted(emotions):
            write_tree(
                export_feature(src_tree, feature, group_labels, emotion, clip_to_base),
                out_dir / f"{feature}_{emotion}.svg",
            )
            written.append(f"{feature}_{emotion}")

    for name, layer_label in FEATURE_LAYERS.items():
        write_tree(export_layer(src_tree, layer_label), out_dir / f"{name}_{DEFAULT_EMOTION}.svg")
        written.append(f"{name}_{DEFAULT_EMOTION}")

    print(f"{src.name} → face/{{{', '.join(written)}}}.svg")


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
