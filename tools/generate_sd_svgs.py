#!/usr/bin/env python3
"""
SD/Chibi flat-vector SVG generator for CONDOR warrior rigs.

Generates 15 bone SVGs per class (7 classes = 105 files) in a clean
flat anime SD style: solid fills, 2px outlines, no gradients or hatching.

SVG viewBox sizes are 4× display size:
  Head=120×136, Torso=168×144, Hips=144×40, Arm=48×112, Forearm=40×88,
  Hand=32×32, Leg=56×136, Shin=48×112, Foot=80×40
"""
import os
import sys

OUTLINE = "#0a0a0a"
SW = 2  # stroke-width for outlines
SW_INNER = 1  # stroke-width for inner details
SKIN = "#d9a880"
SKIN_SHADOW = "#c49268"

# ViewBox sizes (4× display pixels)
SIZES = {
    "head":         (120, 136),
    "torso":        (168, 144),
    "hips":         (144, 40),
    "leftarm":      (48, 112),
    "leftforearm":  (40, 88),
    "lefthand":     (32, 32),
    "rightarm":     (48, 112),
    "rightforearm": (40, 88),
    "righthand":    (32, 32),
    "leftleg":      (56, 136),
    "leftshin":     (48, 112),
    "leftfoot":     (80, 40),
    "rightleg":     (56, 136),
    "rightshin":    (48, 112),
    "rightfoot":    (80, 40),
}

# ─── Class color palettes ───────────────────────────────────────────
PALETTES = {
    "landsknecht": {
        "primary":    "#943030",  # crimson doublet
        "secondary":  "#6b1a1a",  # darker crimson
        "accent":     "#c0a040",  # gold trim
        "armor":      "#5a5a64",  # steel plate
        "armor_dark": "#3a3a42",
        "cloth":      "#482020",  # inner fabric
        "boots":      "#3d2818",
        "boots_sole": "#2a1a10",
        "belt":       "#4a3020",
        "hair":       "#1a0f08",
        "cuff":       "#8b2020",
    },
    "healer": {
        "primary":    "#2e4878",  # dark blue robe
        "secondary":  "#3a5a90",  # lighter blue
        "accent":     "#e8e0d0",  # white sash
        "armor":      "#2e4878",
        "armor_dark": "#1e3060",
        "cloth":      "#1e3060",
        "boots":      "#38261a",
        "boots_sole": "#2a1a10",
        "belt":       "#5c4030",
        "hair":       "#1a1a2e",
        "cuff":       "#e8e0d0",
    },
    "crossbowman": {
        "primary":    "#3a6030",  # forest green
        "secondary":  "#2a4820",  # darker green
        "accent":     "#c0a040",  # brass buckle
        "armor":      "#6a5030",  # padded leather
        "armor_dark": "#4a3820",
        "cloth":      "#5a4828",
        "boots":      "#42301e",
        "boots_sole": "#2a1a10",
        "belt":       "#5c4030",
        "hair":       "#2a1a08",
        "cuff":       "#4a3820",
    },
    "arquebusier": {
        "primary":    "#333028",  # dark charcoal coat
        "secondary":  "#282520",  # near-black
        "accent":     "#a08850",  # brass
        "armor":      "#333028",
        "armor_dark": "#222018",
        "cloth":      "#282520",
        "boots":      "#2e2218",
        "boots_sole": "#1a1210",
        "belt":       "#504028",
        "hair":       "#1a1208",
        "cuff":       "#4a4038",
    },
    "pikeman": {
        "primary":    "#585c68",  # grey plate
        "secondary":  "#6a6e78",  # lighter steel
        "accent":     "#c0a040",  # gold rivets
        "armor":      "#4a4e58",  # darker plate
        "armor_dark": "#3a3e48",
        "cloth":      "#484048",  # under-chain
        "boots":      "#38281a",
        "boots_sole": "#2a1a10",
        "belt":       "#4a3a28",
        "hair":       "#2a2018",
        "cuff":       "#585c68",
    },
    "feldprediger": {
        "primary":    "#3a2058",  # dark purple vestments
        "secondary":  "#4a2e6a",  # lighter purple
        "accent":     "#e8e0d0",  # white collar
        "armor":      "#3a2058",
        "armor_dark": "#2a1848",
        "cloth":      "#2a1848",
        "boots":      "#38261a",
        "boots_sole": "#2a1a10",
        "belt":       "#5c4838",
        "hair":       "#201828",
        "cuff":       "#e8e0d0",
    },
    "gelehrter": {
        "primary":    "#4c1420",  # deep crimson robe
        "secondary":  "#3a0e18",  # darker crimson
        "accent":     "#c0a040",  # gold trim
        "armor":      "#4c1420",
        "armor_dark": "#3a0e18",
        "cloth":      "#2a0a12",
        "boots":      "#2e1a14",
        "boots_sole": "#1a1010",
        "belt":       "#c0a040",
        "hair":       "#2a1018",
        "cuff":       "#c0a040",
    },
}


def svg_wrap(w, h, content):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
        f'width="{w}" height="{h}">\n{content}\n</svg>\n'
    )


def rect(x, y, w, h, fill, rx=0, stroke=True):
    s = f'  <rect x="{x}" y="{y}" width="{w}" height="{h}"'
    if rx:
        s += f' rx="{rx}"'
    s += f' fill="{fill}"'
    if stroke:
        s += f' stroke="{OUTLINE}" stroke-width="{SW}"'
    s += "/>"
    return s


def ellipse(cx, cy, rx, ry, fill, stroke=True):
    s = f'  <ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"'
    if stroke:
        s += f' stroke="{OUTLINE}" stroke-width="{SW}"'
    s += "/>"
    return s


def circle(cx, cy, r, fill, stroke=True):
    s = f'  <circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"'
    if stroke:
        s += f' stroke="{OUTLINE}" stroke-width="{SW}"'
    s += "/>"
    return s


def path(d, fill="none", stroke_color=None, sw=None, stroke=True):
    s = f'  <path d="{d}" fill="{fill}"'
    if stroke and stroke_color:
        s += f' stroke="{stroke_color}" stroke-width="{sw or SW}"'
    elif stroke:
        s += f' stroke="{OUTLINE}" stroke-width="{sw or SW}"'
    s += "/>"
    return s


def line(x1, y1, x2, y2, color=OUTLINE, sw=SW_INNER):
    return f'  <line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"/>'


# ─── Bone generators ────────────────────────────────────────────────

def gen_head(p):
    """120×136 — oversized SD head."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Hair back (behind face)
    parts.append(path(
        f"M{cx-48} {cy-20} Q{cx-50} {cy-54} {cx-20} {cy-60} "
        f"Q{cx} {cy-66} {cx+20} {cy-60} Q{cx+50} {cy-54} {cx+48} {cy-20} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Face oval
    parts.append(ellipse(cx, cy, 46, 52, SKIN))
    # Cheek shadow (simple flat shape)
    parts.append(ellipse(cx - 26, cy + 14, 12, 8, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 26, cy + 14, 12, 8, SKIN_SHADOW, stroke=False))
    # Hair front (bangs)
    parts.append(path(
        f"M{cx-46} {cy-22} Q{cx-48} {cy-52} {cx-18} {cy-58} "
        f"Q{cx} {cy-64} {cx+18} {cy-58} Q{cx+48} {cy-52} {cx+46} {cy-22} "
        f"Q{cx+30} {cy-12} {cx} {cy-14} Q{cx-30} {cy-12} {cx-46} {cy-22} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Eyes — large anime style
    parts.append(ellipse(cx - 16, cy - 6, 10, 12, "#f0ece8"))
    parts.append(ellipse(cx + 16, cy - 6, 10, 12, "#f0ece8"))
    # Iris
    parts.append(ellipse(cx - 16, cy - 4, 7, 9, "#4a6090"))
    parts.append(ellipse(cx + 16, cy - 4, 7, 9, "#4a6090"))
    # Pupil
    parts.append(circle(cx - 16, cy - 3, 4, "#1a1a20"))
    parts.append(circle(cx + 16, cy - 3, 4, "#1a1a20"))
    # Eye highlights
    parts.append(circle(cx - 13, cy - 8, 2.5, "#ffffff", stroke=False))
    parts.append(circle(cx + 19, cy - 8, 2.5, "#ffffff", stroke=False))
    # Eyebrows
    parts.append(path(
        f"M{cx-28} {cy-20} Q{cx-16} {cy-26} {cx-6} {cy-20}",
        stroke_color=OUTLINE, sw=2.5
    ))
    parts.append(path(
        f"M{cx+6} {cy-20} Q{cx+16} {cy-26} {cx+28} {cy-20}",
        stroke_color=OUTLINE, sw=2.5
    ))
    # Mouth — small simple line
    parts.append(path(
        f"M{cx-6} {cy+20} Q{cx} {cy+24} {cx+6} {cy+20}",
        stroke_color="#c06050", sw=1.5
    ))
    return svg_wrap(w, h, "\n".join(parts))


def gen_torso(p):
    """168×144 — compact SD torso."""
    w, h = 168, 144
    cx = 84
    parts = []
    # Main body
    parts.append(rect(6, 6, 156, 132, p["primary"], rx=14))
    # Shoulder area accent
    parts.append(rect(6, 6, 156, 36, p["secondary"], rx=14))
    # Collar/neckline
    parts.append(path(
        f"M{cx-24} 6 Q{cx} 20 {cx+24} 6",
        fill=SKIN, stroke_color=OUTLINE, sw=SW
    ))
    # Center seam
    parts.append(line(cx, 42, cx, 138, p["cloth"], SW_INNER))
    # Belt across waist
    parts.append(rect(6, 100, 156, 14, p["belt"], rx=4))
    # Belt buckle
    parts.append(rect(cx - 8, 100, 16, 14, p["accent"], rx=2))
    # Accent trim at bottom
    parts.append(rect(6, 124, 156, 14, p["cuff"], rx=6))
    return svg_wrap(w, h, "\n".join(parts))


def gen_hips(p):
    """144×40 — belt/waist area."""
    w, h = 144, 40
    parts = []
    parts.append(rect(4, 4, 136, 32, p["primary"], rx=8))
    parts.append(rect(4, 4, 136, 12, p["belt"], rx=6))
    return svg_wrap(w, h, "\n".join(parts))


def gen_arm(p, side="left"):
    """48×112 — upper arm with sleeve."""
    w, h = 48, 112
    cx = 24
    parts = []
    # Sleeve
    parts.append(rect(4, 4, 40, 104, p["primary"], rx=10))
    # Shoulder cap
    parts.append(path(
        f"M4 4 Q{cx} -4 44 4 L44 28 Q{cx} 34 4 28 Z",
        fill=p["armor"], stroke_color=OUTLINE, sw=SW
    ))
    # Sleeve fold line
    parts.append(line(14, 50, 14, 80, p["cloth"], SW_INNER))
    # Cuff
    parts.append(rect(4, 94, 40, 14, p["cuff"], rx=6))
    return svg_wrap(w, h, "\n".join(parts))


def gen_forearm(p, side="left"):
    """40×88 — lower arm."""
    w, h = 40, 88
    parts = []
    parts.append(rect(4, 4, 32, 80, p["primary"], rx=8))
    # Cuff/bracer
    parts.append(rect(4, 66, 32, 18, p["armor"], rx=4))
    return svg_wrap(w, h, "\n".join(parts))


def gen_hand(p, side="left"):
    """32×32 — simplified round hand."""
    w, h = 32, 32
    parts = []
    parts.append(circle(16, 16, 13, SKIN))
    # Finger line detail
    parts.append(path(
        f"M10 20 Q12 24 10 28",
        stroke_color=SKIN_SHADOW, sw=SW_INNER
    ))
    parts.append(path(
        f"M22 20 Q24 24 22 28",
        stroke_color=SKIN_SHADOW, sw=SW_INNER
    ))
    return svg_wrap(w, h, "\n".join(parts))


def gen_leg(p, side="left"):
    """56×136 — upper leg / thigh."""
    w, h = 56, 136
    parts = []
    parts.append(rect(6, 4, 44, 128, p["primary"], rx=10))
    # Fold line
    parts.append(line(18, 40, 16, 90, p["cloth"], SW_INNER))
    return svg_wrap(w, h, "\n".join(parts))


def gen_shin(p, side="left"):
    """48×112 — lower leg / boot top."""
    w, h = 48, 112
    parts = []
    # Boot shaft
    parts.append(rect(4, 4, 40, 104, p["boots"], rx=8))
    # Boot top fold
    parts.append(rect(2, 4, 44, 16, p["boots"], rx=6))
    # Boot lace/strap
    parts.append(line(14, 40, 34, 40, p["boots_sole"], SW_INNER))
    parts.append(line(14, 60, 34, 60, p["boots_sole"], SW_INNER))
    return svg_wrap(w, h, "\n".join(parts))


def gen_foot(p, side="left"):
    """80×40 — simplified SD foot."""
    w, h = 80, 40
    parts = []
    parts.append(rect(4, 4, 72, 32, p["boots"], rx=10))
    # Sole line
    parts.append(rect(4, 28, 72, 8, p["boots_sole"], rx=4))
    return svg_wrap(w, h, "\n".join(parts))


# ─── Class-specific head overrides ──────────────────────────────────

def gen_head_landsknecht(p):
    """Landsknecht: short military hair, strong jaw."""
    return gen_head(p)


def gen_head_healer(p):
    """Healer: hooded head with blue hood framing face."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Hood back
    parts.append(path(
        f"M{cx-50} {cy+10} Q{cx-54} {cy-50} {cx} {cy-62} "
        f"Q{cx+54} {cy-50} {cx+50} {cy+10} Z",
        fill=p["primary"], stroke_color=OUTLINE, sw=SW
    ))
    # Face
    parts.append(ellipse(cx, cy, 42, 48, SKIN))
    parts.append(ellipse(cx - 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    # Hood front frame
    parts.append(path(
        f"M{cx-50} {cy+10} Q{cx-50} {cy-40} {cx-20} {cy-50} "
        f"Q{cx} {cy-56} {cx+20} {cy-50} Q{cx+50} {cy-40} {cx+50} {cy+10} "
        f"Q{cx+36} {cy-10} {cx} {cy-14} Q{cx-36} {cy-10} {cx-50} {cy+10} Z",
        fill=p["primary"], stroke_color=OUTLINE, sw=SW
    ))
    # Hair wisps peeking out
    parts.append(path(
        f"M{cx-30} {cy-18} Q{cx-20} {cy-30} {cx-10} {cy-22}",
        stroke_color=p["hair"], sw=2
    ))
    parts.append(path(
        f"M{cx+10} {cy-22} Q{cx+20} {cy-30} {cx+30} {cy-18}",
        stroke_color=p["hair"], sw=2
    ))
    # Eyes
    parts.append(ellipse(cx - 14, cy - 4, 9, 11, "#f0ece8"))
    parts.append(ellipse(cx + 14, cy - 4, 9, 11, "#f0ece8"))
    parts.append(ellipse(cx - 14, cy - 2, 6, 8, "#3050a0"))
    parts.append(ellipse(cx + 14, cy - 2, 6, 8, "#3050a0"))
    parts.append(circle(cx - 14, cy - 1, 3.5, "#1a1a28"))
    parts.append(circle(cx + 14, cy - 1, 3.5, "#1a1a28"))
    parts.append(circle(cx - 11, cy - 6, 2.5, "#ffffff", stroke=False))
    parts.append(circle(cx + 17, cy - 6, 2.5, "#ffffff", stroke=False))
    # Soft brows
    parts.append(path(
        f"M{cx-24} {cy-18} Q{cx-14} {cy-22} {cx-4} {cy-18}",
        stroke_color=OUTLINE, sw=2
    ))
    parts.append(path(
        f"M{cx+4} {cy-18} Q{cx+14} {cy-22} {cx+24} {cy-18}",
        stroke_color=OUTLINE, sw=2
    ))
    # Gentle mouth
    parts.append(path(
        f"M{cx-5} {cy+20} Q{cx} {cy+23} {cx+5} {cy+20}",
        stroke_color="#c06050", sw=1.5
    ))
    return svg_wrap(w, h, "\n".join(parts))


def gen_head_pikeman(p):
    """Pikeman: helmet with visor."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Helmet dome
    parts.append(path(
        f"M{cx-48} {cy-8} Q{cx-50} {cy-56} {cx} {cy-64} "
        f"Q{cx+50} {cy-56} {cx+48} {cy-8} Z",
        fill=p["armor"], stroke_color=OUTLINE, sw=SW
    ))
    # Face opening
    parts.append(ellipse(cx, cy + 4, 36, 42, SKIN))
    # Helmet sides / cheek guards
    parts.append(path(
        f"M{cx-48} {cy-8} Q{cx-44} {cy+20} {cx-36} {cy+36} L{cx-30} {cy+10} Z",
        fill=p["armor"], stroke_color=OUTLINE, sw=SW
    ))
    parts.append(path(
        f"M{cx+48} {cy-8} Q{cx+44} {cy+20} {cx+36} {cy+36} L{cx+30} {cy+10} Z",
        fill=p["armor"], stroke_color=OUTLINE, sw=SW
    ))
    # Visor ridge
    parts.append(path(
        f"M{cx-40} {cy-10} Q{cx} {cy-18} {cx+40} {cy-10}",
        stroke_color=p["armor_dark"], sw=3
    ))
    # Cheek shadow
    parts.append(ellipse(cx - 18, cy + 16, 8, 6, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 18, cy + 16, 8, 6, SKIN_SHADOW, stroke=False))
    # Eyes — stern
    parts.append(ellipse(cx - 14, cy - 2, 9, 10, "#f0ece8"))
    parts.append(ellipse(cx + 14, cy - 2, 9, 10, "#f0ece8"))
    parts.append(ellipse(cx - 14, cy, 6, 7, "#607050"))
    parts.append(ellipse(cx + 14, cy, 6, 7, "#607050"))
    parts.append(circle(cx - 14, cy + 1, 3.5, "#1a1a18"))
    parts.append(circle(cx + 14, cy + 1, 3.5, "#1a1a18"))
    parts.append(circle(cx - 11, cy - 4, 2, "#ffffff", stroke=False))
    parts.append(circle(cx + 17, cy - 4, 2, "#ffffff", stroke=False))
    # Heavy brows
    parts.append(path(
        f"M{cx-26} {cy-14} Q{cx-14} {cy-20} {cx-4} {cy-14}",
        stroke_color=OUTLINE, sw=3
    ))
    parts.append(path(
        f"M{cx+4} {cy-14} Q{cx+14} {cy-20} {cx+26} {cy-14}",
        stroke_color=OUTLINE, sw=3
    ))
    # Mouth
    parts.append(line(cx - 6, cy + 22, cx + 6, cy + 22, "#a05040", 1.5))
    # Helmet crest/ridge on top
    parts.append(path(
        f"M{cx} {cy-64} Q{cx+4} {cy-68} {cx} {cy-72} Q{cx-4} {cy-68} {cx} {cy-64}",
        fill=p["accent"], stroke_color=OUTLINE, sw=SW
    ))
    return svg_wrap(w, h, "\n".join(parts))


def gen_head_arquebusier(p):
    """Arquebusier: leather cap, narrow eyes."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Hair back
    parts.append(path(
        f"M{cx-44} {cy-16} Q{cx-46} {cy-50} {cx-16} {cy-56} "
        f"Q{cx} {cy-60} {cx+16} {cy-56} Q{cx+46} {cy-50} {cx+44} {cy-16} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Face
    parts.append(ellipse(cx, cy, 44, 50, SKIN))
    parts.append(ellipse(cx - 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    # Leather cap
    parts.append(path(
        f"M{cx-48} {cy-16} Q{cx-50} {cy-48} {cx-16} {cy-54} "
        f"Q{cx} {cy-58} {cx+16} {cy-54} Q{cx+50} {cy-48} {cx+48} {cy-16} "
        f"Q{cx+34} {cy-20} {cx} {cy-22} Q{cx-34} {cy-20} {cx-48} {cy-16} Z",
        fill=p["boots"], stroke_color=OUTLINE, sw=SW
    ))
    # Cap brim
    parts.append(path(
        f"M{cx-50} {cy-16} Q{cx} {cy-8} {cx+50} {cy-16}",
        stroke_color=OUTLINE, sw=2.5
    ))
    # Eyes — narrow, focused
    parts.append(ellipse(cx - 16, cy - 4, 9, 8, "#f0ece8"))
    parts.append(ellipse(cx + 16, cy - 4, 9, 8, "#f0ece8"))
    parts.append(ellipse(cx - 16, cy - 3, 6, 6, "#605040"))
    parts.append(ellipse(cx + 16, cy - 3, 6, 6, "#605040"))
    parts.append(circle(cx - 16, cy - 2, 3, "#1a1a18"))
    parts.append(circle(cx + 16, cy - 2, 3, "#1a1a18"))
    parts.append(circle(cx - 13, cy - 6, 2, "#ffffff", stroke=False))
    parts.append(circle(cx + 19, cy - 6, 2, "#ffffff", stroke=False))
    # Brows
    parts.append(path(
        f"M{cx-28} {cy-16} Q{cx-16} {cy-20} {cx-6} {cy-16}",
        stroke_color=OUTLINE, sw=2
    ))
    parts.append(path(
        f"M{cx+6} {cy-16} Q{cx+16} {cy-20} {cx+28} {cy-16}",
        stroke_color=OUTLINE, sw=2
    ))
    # Mouth
    parts.append(line(cx - 5, cy + 20, cx + 5, cy + 20, "#a05040", 1.5))
    return svg_wrap(w, h, "\n".join(parts))


def gen_head_crossbowman(p):
    """Crossbowman: messy hair, alert eyes."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Hair back — wild
    parts.append(path(
        f"M{cx-50} {cy-14} Q{cx-52} {cy-52} {cx-22} {cy-62} "
        f"Q{cx} {cy-68} {cx+22} {cy-62} Q{cx+52} {cy-52} {cx+50} {cy-14} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Face
    parts.append(ellipse(cx, cy, 44, 50, SKIN))
    parts.append(ellipse(cx - 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    # Hair front — spiky tufts
    parts.append(path(
        f"M{cx-48} {cy-16} Q{cx-40} {cy-50} {cx-24} {cy-58} L{cx-18} {cy-30} "
        f"L{cx-12} {cy-62} Q{cx} {cy-66} {cx+12} {cy-62} L{cx+18} {cy-30} "
        f"L{cx+24} {cy-58} Q{cx+40} {cy-50} {cx+48} {cy-16} "
        f"Q{cx+30} {cy-10} {cx} {cy-12} Q{cx-30} {cy-10} {cx-48} {cy-16} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Eyes — wide, alert
    parts.append(ellipse(cx - 16, cy - 4, 10, 12, "#f0ece8"))
    parts.append(ellipse(cx + 16, cy - 4, 10, 12, "#f0ece8"))
    parts.append(ellipse(cx - 16, cy - 2, 7, 9, "#408040"))
    parts.append(ellipse(cx + 16, cy - 2, 7, 9, "#408040"))
    parts.append(circle(cx - 16, cy - 1, 4, "#1a1a18"))
    parts.append(circle(cx + 16, cy - 1, 4, "#1a1a18"))
    parts.append(circle(cx - 13, cy - 6, 2.5, "#ffffff", stroke=False))
    parts.append(circle(cx + 19, cy - 6, 2.5, "#ffffff", stroke=False))
    # Brows
    parts.append(path(
        f"M{cx-28} {cy-18} Q{cx-16} {cy-24} {cx-6} {cy-18}",
        stroke_color=OUTLINE, sw=2
    ))
    parts.append(path(
        f"M{cx+6} {cy-18} Q{cx+16} {cy-24} {cx+28} {cy-18}",
        stroke_color=OUTLINE, sw=2
    ))
    # Mouth — small grin
    parts.append(path(
        f"M{cx-6} {cy+20} Q{cx} {cy+24} {cx+6} {cy+20}",
        stroke_color="#c06050", sw=1.5
    ))
    return svg_wrap(w, h, "\n".join(parts))


def gen_head_feldprediger(p):
    """Feldprediger: white collar, close-cropped hair, solemn."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Hair
    parts.append(path(
        f"M{cx-46} {cy-18} Q{cx-48} {cy-52} {cx-18} {cy-58} "
        f"Q{cx} {cy-62} {cx+18} {cy-58} Q{cx+48} {cy-52} {cx+46} {cy-18} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Face
    parts.append(ellipse(cx, cy, 44, 50, SKIN))
    parts.append(ellipse(cx - 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    # Hair front (tonsure-style, receding)
    parts.append(path(
        f"M{cx-46} {cy-18} Q{cx-46} {cy-48} {cx-14} {cy-54} "
        f"Q{cx} {cy-58} {cx+14} {cy-54} Q{cx+46} {cy-48} {cx+46} {cy-18} "
        f"Q{cx+20} {cy-6} {cx} {cy-4} Q{cx-20} {cy-6} {cx-46} {cy-18} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # White collar at chin
    parts.append(path(
        f"M{cx-30} {cy+40} Q{cx} {cy+52} {cx+30} {cy+40} "
        f"Q{cx+20} {cy+34} {cx} {cy+32} Q{cx-20} {cy+34} {cx-30} {cy+40} Z",
        fill=p["accent"], stroke_color=OUTLINE, sw=SW
    ))
    # Eyes — calm, wise
    parts.append(ellipse(cx - 14, cy - 4, 9, 10, "#f0ece8"))
    parts.append(ellipse(cx + 14, cy - 4, 9, 10, "#f0ece8"))
    parts.append(ellipse(cx - 14, cy - 2, 6, 7, "#6050a0"))
    parts.append(ellipse(cx + 14, cy - 2, 6, 7, "#6050a0"))
    parts.append(circle(cx - 14, cy - 1, 3.5, "#1a1a28"))
    parts.append(circle(cx + 14, cy - 1, 3.5, "#1a1a28"))
    parts.append(circle(cx - 11, cy - 6, 2, "#ffffff", stroke=False))
    parts.append(circle(cx + 17, cy - 6, 2, "#ffffff", stroke=False))
    # Gentle brows
    parts.append(path(
        f"M{cx-24} {cy-18} Q{cx-14} {cy-22} {cx-4} {cy-18}",
        stroke_color=OUTLINE, sw=2
    ))
    parts.append(path(
        f"M{cx+4} {cy-18} Q{cx+14} {cy-22} {cx+24} {cy-18}",
        stroke_color=OUTLINE, sw=2
    ))
    # Small closed mouth
    parts.append(line(cx - 5, cy + 20, cx + 5, cy + 20, "#a06050", 1.5))
    return svg_wrap(w, h, "\n".join(parts))


def gen_head_gelehrter(p):
    """Gelehrter: hooded/circlet, mystical eyes."""
    w, h = 120, 136
    cx, cy = 60, 72
    parts = []
    # Hair back
    parts.append(path(
        f"M{cx-48} {cy-10} Q{cx-50} {cy-54} {cx-18} {cy-60} "
        f"Q{cx} {cy-66} {cx+18} {cy-60} Q{cx+50} {cy-54} {cx+48} {cy-10} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Face
    parts.append(ellipse(cx, cy, 44, 50, SKIN))
    parts.append(ellipse(cx - 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    parts.append(ellipse(cx + 24, cy + 14, 10, 7, SKIN_SHADOW, stroke=False))
    # Hair front — long, framing
    parts.append(path(
        f"M{cx-48} {cy-10} Q{cx-48} {cy-50} {cx-16} {cy-58} "
        f"Q{cx} {cy-64} {cx+16} {cy-58} Q{cx+48} {cy-50} {cx+48} {cy-10} "
        f"Q{cx+34} {cy-4} {cx} {cy-8} Q{cx-34} {cy-4} {cx-48} {cy-10} Z",
        fill=p["hair"], stroke_color=OUTLINE, sw=SW
    ))
    # Long side locks
    parts.append(path(
        f"M{cx-46} {cy-6} Q{cx-50} {cy+20} {cx-44} {cy+44}",
        stroke_color=p["hair"], sw=8
    ))
    parts.append(path(
        f"M{cx-46} {cy-6} Q{cx-50} {cy+20} {cx-44} {cy+44}",
        stroke_color=OUTLINE, sw=2
    ))
    parts.append(path(
        f"M{cx+46} {cy-6} Q{cx+50} {cy+20} {cx+44} {cy+44}",
        stroke_color=p["hair"], sw=8
    ))
    parts.append(path(
        f"M{cx+46} {cy-6} Q{cx+50} {cy+20} {cx+44} {cy+44}",
        stroke_color=OUTLINE, sw=2
    ))
    # Gold circlet
    parts.append(path(
        f"M{cx-40} {cy-18} Q{cx} {cy-30} {cx+40} {cy-18}",
        stroke_color=p["accent"], sw=3
    ))
    # Circlet gem
    parts.append(circle(cx, cy - 24, 4, "#a03030"))
    # Eyes — large, mystical
    parts.append(ellipse(cx - 16, cy - 4, 10, 12, "#f0ece8"))
    parts.append(ellipse(cx + 16, cy - 4, 10, 12, "#f0ece8"))
    parts.append(ellipse(cx - 16, cy - 2, 7, 9, "#a04050"))
    parts.append(ellipse(cx + 16, cy - 2, 7, 9, "#a04050"))
    parts.append(circle(cx - 16, cy - 1, 4, "#1a1a20"))
    parts.append(circle(cx + 16, cy - 1, 4, "#1a1a20"))
    parts.append(circle(cx - 13, cy - 6, 2.5, "#ffffff", stroke=False))
    parts.append(circle(cx + 19, cy - 6, 2.5, "#ffffff", stroke=False))
    # Thin elegant brows
    parts.append(path(
        f"M{cx-26} {cy-20} Q{cx-16} {cy-24} {cx-6} {cy-20}",
        stroke_color=OUTLINE, sw=1.5
    ))
    parts.append(path(
        f"M{cx+6} {cy-20} Q{cx+16} {cy-24} {cx+26} {cy-20}",
        stroke_color=OUTLINE, sw=1.5
    ))
    # Small mouth
    parts.append(path(
        f"M{cx-5} {cy+20} Q{cx} {cy+23} {cx+5} {cy+20}",
        stroke_color="#c06050", sw=1.5
    ))
    return svg_wrap(w, h, "\n".join(parts))


# ─── Class-specific torso overrides ─────────────────────────────────

def gen_torso_landsknecht(p):
    """Slashed doublet with steel chest plate."""
    w, h = 168, 144
    cx = 84
    parts = []
    # Base doublet
    parts.append(rect(6, 6, 156, 132, p["primary"], rx=14))
    # Collar neckline
    parts.append(path(
        f"M{cx-24} 6 Q{cx} 20 {cx+24} 6",
        fill=SKIN, stroke_color=OUTLINE, sw=SW
    ))
    # Slash marks (flat colored lines — simplified)
    for yy in range(36, 120, 22):
        parts.append(line(16, yy, 60, yy + 12, p["cloth"], 4))
        parts.append(line(108, yy, 152, yy + 12, p["cloth"], 4))
    # Steel chest plate
    parts.append(path(
        f"M{cx-32} 18 Q{cx} 12 {cx+32} 18 L{cx+34} 72 Q{cx} 80 {cx-34} 72 Z",
        fill=p["armor"], stroke_color=OUTLINE, sw=SW
    ))
    # Plate highlight
    parts.append(path(
        f"M{cx-26} 22 Q{cx} 18 {cx+26} 22 L{cx+28} 48 Q{cx} 52 {cx-28} 48 Z",
        fill=p["armor_dark"], stroke_color="none", sw=0, stroke=False
    ))
    # Gold collar trim
    parts.append(path(
        f"M{cx-40} 8 Q{cx} 0 {cx+40} 8",
        stroke_color=p["accent"], sw=3
    ))
    # Belt
    parts.append(rect(6, 100, 156, 12, p["belt"], rx=4))
    parts.append(rect(cx - 7, 98, 14, 16, p["accent"], rx=2))
    return svg_wrap(w, h, "\n".join(parts))


def gen_torso_healer(p):
    """Dark blue robe with white sash."""
    w, h = 168, 144
    cx = 84
    parts = []
    parts.append(rect(6, 6, 156, 132, p["primary"], rx=14))
    # V-neckline
    parts.append(path(
        f"M{cx-26} 6 L{cx} 40 L{cx+26} 6",
        fill=p["secondary"], stroke_color=OUTLINE, sw=SW
    ))
    # Inner robe visible through V
    parts.append(path(
        f"M{cx-20} 10 L{cx} 34 L{cx+20} 10",
        fill=p["accent"], stroke_color="none", sw=0, stroke=False
    ))
    # White sash diagonal
    parts.append(path(
        f"M{cx+40} 20 L{cx-40} 100 L{cx-34} 110 L{cx+46} 30 Z",
        fill=p["accent"], stroke_color=OUTLINE, sw=SW
    ))
    # Robe hem
    parts.append(rect(6, 124, 156, 14, p["secondary"], rx=6))
    return svg_wrap(w, h, "\n".join(parts))


def gen_torso_pikeman(p):
    """Steel plate over chain."""
    w, h = 168, 144
    cx = 84
    parts = []
    # Chainmail base
    parts.append(rect(6, 6, 156, 132, p["cloth"], rx=14))
    # Full chest plate
    parts.append(rect(14, 10, 140, 90, p["armor"], rx=10))
    # Plate lighter center
    parts.append(rect(30, 16, 108, 50, p["secondary"], rx=6))
    # Gorget (neck guard)
    parts.append(path(
        f"M{cx-28} 6 Q{cx} 16 {cx+28} 6 Q{cx+26} 0 {cx} -2 Q{cx-26} 0 {cx-28} 6 Z",
        fill=p["armor"], stroke_color=OUTLINE, sw=SW
    ))
    # Belt
    parts.append(rect(6, 104, 156, 12, p["belt"], rx=4))
    parts.append(rect(cx - 7, 102, 14, 16, p["accent"], rx=2))
    # Chain skirt
    parts.append(rect(6, 120, 156, 18, p["cloth"], rx=6))
    return svg_wrap(w, h, "\n".join(parts))


def gen_torso_feldprediger(p):
    """Purple vestments with white collar."""
    w, h = 168, 144
    cx = 84
    parts = []
    parts.append(rect(6, 6, 156, 132, p["primary"], rx=14))
    # White collar
    parts.append(path(
        f"M{cx-30} 6 Q{cx-20} 20 {cx} 26 Q{cx+20} 20 {cx+30} 6",
        fill=p["accent"], stroke_color=OUTLINE, sw=SW
    ))
    # Center front panel
    parts.append(rect(cx - 16, 26, 32, 112, p["secondary"], rx=4))
    # Cross emblem
    parts.append(rect(cx - 4, 44, 8, 28, p["accent"], rx=1))
    parts.append(rect(cx - 12, 52, 24, 8, p["accent"], rx=1))
    # Rope belt
    parts.append(path(
        f"M20 100 Q{cx} 108 148 100",
        stroke_color=p["belt"], sw=4
    ))
    # Robe hem
    parts.append(rect(6, 124, 156, 14, p["secondary"], rx=6))
    return svg_wrap(w, h, "\n".join(parts))


def gen_torso_gelehrter(p):
    """Deep crimson scholar robe with gold trim."""
    w, h = 168, 144
    cx = 84
    parts = []
    parts.append(rect(6, 6, 156, 132, p["primary"], rx=14))
    # Open robe revealing inner
    parts.append(path(
        f"M{cx-12} 6 L{cx-18} 138 L{cx+18} 138 L{cx+12} 6 Z",
        fill=p["secondary"], stroke_color=OUTLINE, sw=SW
    ))
    # Gold trim on edges
    parts.append(line(cx - 12, 6, cx - 18, 138, p["accent"], 2))
    parts.append(line(cx + 12, 6, cx + 18, 138, p["accent"], 2))
    # Collar
    parts.append(path(
        f"M{cx-26} 6 Q{cx} 18 {cx+26} 6",
        fill=SKIN, stroke_color=OUTLINE, sw=SW
    ))
    # Gold collar edge
    parts.append(path(
        f"M{cx-34} 8 Q{cx} 0 {cx+34} 8",
        stroke_color=p["accent"], sw=3
    ))
    # Hood gathered at back (visible at shoulders)
    parts.append(path(
        f"M{cx-50} 10 Q{cx-46} 0 {cx-34} 8",
        stroke_color=p["primary"], sw=6
    ))
    parts.append(path(
        f"M{cx+50} 10 Q{cx+46} 0 {cx+34} 8",
        stroke_color=p["primary"], sw=6
    ))
    # Robe hem with gold
    parts.append(rect(6, 126, 156, 12, p["secondary"], rx=6))
    parts.append(line(6, 128, 162, 128, p["accent"], 1.5))
    return svg_wrap(w, h, "\n".join(parts))


# ─── Class-specific arm/leg overrides ────────────────────────────────

def gen_arm_pikeman(p, side="left"):
    """Pikeman arm with plate vambrace."""
    w, h = 48, 112
    cx = 24
    parts = []
    parts.append(rect(4, 4, 40, 104, p["armor"], rx=10))
    # Pauldron
    parts.append(path(
        f"M2 2 Q{cx} -6 46 2 L46 30 Q{cx} 36 2 30 Z",
        fill=p["armor_dark"], stroke_color=OUTLINE, sw=SW
    ))
    # Rivet
    parts.append(circle(cx, 16, 3, p["accent"]))
    # Articulation line
    parts.append(line(8, 50, 40, 50, p["armor_dark"], SW_INNER))
    return svg_wrap(w, h, "\n".join(parts))


# ─── Main generation logic ──────────────────────────────────────────

HEAD_OVERRIDES = {
    "landsknecht": gen_head_landsknecht,
    "healer": gen_head_healer,
    "crossbowman": gen_head_crossbowman,
    "arquebusier": gen_head_arquebusier,
    "pikeman": gen_head_pikeman,
    "feldprediger": gen_head_feldprediger,
    "gelehrter": gen_head_gelehrter,
}

TORSO_OVERRIDES = {
    "landsknecht": gen_torso_landsknecht,
    "healer": gen_torso_healer,
    "pikeman": gen_torso_pikeman,
    "feldprediger": gen_torso_feldprediger,
    "gelehrter": gen_torso_gelehrter,
}

ARM_OVERRIDES = {
    "pikeman": gen_arm_pikeman,
}


def generate_class(cls_name, output_dir):
    """Generate all 15 bone SVGs for a class."""
    p = PALETTES[cls_name]
    os.makedirs(output_dir, exist_ok=True)

    bones = {
        "head":         HEAD_OVERRIDES.get(cls_name, gen_head),
        "torso":        TORSO_OVERRIDES.get(cls_name, gen_torso),
        "hips":         gen_hips,
        "leftarm":      ARM_OVERRIDES.get(cls_name, gen_arm),
        "leftforearm":  gen_forearm,
        "lefthand":     gen_hand,
        "rightarm":     lambda p, s="right": ARM_OVERRIDES.get(cls_name, gen_arm)(p, "right"),
        "rightforearm": lambda p, s="right": gen_forearm(p, "right"),
        "righthand":    lambda p, s="right": gen_hand(p, "right"),
        "leftleg":      gen_leg,
        "leftshin":     gen_shin,
        "leftfoot":     gen_foot,
        "rightleg":     lambda p, s="right": gen_leg(p, "right"),
        "rightshin":    lambda p, s="right": gen_shin(p, "right"),
        "rightfoot":    lambda p, s="right": gen_foot(p, "right"),
    }

    for bone_name, gen_func in bones.items():
        svg_content = gen_func(p)
        filepath = os.path.join(output_dir, f"{bone_name}.svg")
        with open(filepath, "w") as f:
            f.write(svg_content)
        print(f"  ✓ {bone_name}.svg")


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(base_dir)
    assets_dir = os.path.join(project_root, "assets", "rig_textures")
    canvas_dir = os.path.join(project_root, "scenes", "demos", "canvas", "svgs", "rig")

    for cls_name in PALETTES:
        print(f"\n[{cls_name}]")
        generate_class(cls_name, os.path.join(assets_dir, cls_name))
        # Also generate canvas demo copies
        canvas_cls_dir = os.path.join(canvas_dir, cls_name)
        if os.path.isdir(canvas_dir):
            generate_class(cls_name, canvas_cls_dir)
            print(f"  (canvas copy done)")

    print(f"\nDone! Generated {len(PALETTES) * 15} SVGs.")


if __name__ == "__main__":
    main()
