#!/usr/bin/env python3
"""
SD/Chibi flat-vector SVG generator for CONDOR warrior rigs.
3/4 profile view — characters face RIGHT by default.

Generates 15 bone SVGs per class (7 classes = 105 files) in a clean
flat anime SD style: solid fills, 2px outlines, no gradients or hatching.

SVG viewBox sizes are 4x display size:
  Head=176x200, Torso=136x112, Hips=112x32, Arm=40x88, Forearm=32x72,
  Hand=56x56, Leg=48x104, Shin=40x88, Foot=80x40
"""
import os
import sys

OUTLINE = "#0a0a0a"
SW = 8        # stroke-width for outlines (÷4 at display = 2px)
SW_INNER = 4  # stroke-width for inner details (÷4 at display = 1px)
SKIN = "#f5d0a8"
SKIN_SHADOW = "#e0b890"

SIZES = {
    "head":         (176, 200),
    "torso":        (136, 112),
    "hips":         (112,  32),
    "leftarm":      ( 40,  88),
    "leftforearm":  ( 32,  72),
    "lefthand":     ( 56,  56),
    "rightarm":     ( 40,  88),
    "rightforearm": ( 32,  72),
    "righthand":    ( 56,  56),
    "leftleg":      ( 48, 104),
    "leftshin":     ( 40,  88),
    "leftfoot":     ( 80,  40),
    "rightleg":     ( 48, 104),
    "rightshin":    ( 40,  88),
    "rightfoot":    ( 80,  40),
}

# ─── Palettes ──────────────────────────────────────────────────────────
PALETTES = {
    "landsknecht": {
        "name": "Landsknecht",
        "hair": "#c49a6c",
        "hair_dark": "#a07848",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#5588bb",
        "cloth_main": "#cc3333",     # crimson doublet
        "cloth_dark": "#992222",
        "cloth_accent": "#ddcc88",   # gold trim
        "armor": "#aab0b8",          # steel
        "armor_dark": "#889098",
        "boots": "#7a5a40",
        "boots_dark": "#5a3a20",
        "belt": "#8b6433",
        "pants": "#7a6050",
        "gloves": "#8b6433",
    },
    "healer": {
        "name": "Healer",
        "hair": "#2a2a3a",
        "hair_dark": "#1a1a28",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#66bb77",
        "cloth_main": "#334488",     # dark blue robe
        "cloth_dark": "#223366",
        "cloth_accent": "#eeeedd",   # white sash
        "armor": "#334488",
        "armor_dark": "#223366",
        "boots": "#665544",
        "boots_dark": "#4a3a2a",
        "belt": "#8b6523",
        "pants": "#4466aa",
        "gloves": "#eeeedd",
    },
    "crossbowman": {
        "name": "Crossbowman",
        "hair": "#884422",
        "hair_dark": "#663311",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#887744",
        "cloth_main": "#447744",     # forest green
        "cloth_dark": "#335533",
        "cloth_accent": "#ccbb88",
        "armor": "#887755",          # padded leather
        "armor_dark": "#665533",
        "boots": "#7a5a40",
        "boots_dark": "#5a3a20",
        "belt": "#8b6433",
        "pants": "#887766",
        "gloves": "#887766",
    },
    "arquebusier": {
        "name": "Arquebusier",
        "hair": "#555555",
        "hair_dark": "#3a3a3a",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#778899",
        "cloth_main": "#444455",     # dark grey coat
        "cloth_dark": "#333344",
        "cloth_accent": "#aa8855",   # brass buttons
        "armor": "#555566",
        "armor_dark": "#444455",
        "boots": "#5a5a5a",
        "boots_dark": "#404040",
        "belt": "#8b6433",
        "pants": "#666666",
        "gloves": "#666666",
    },
    "pikeman": {
        "name": "Pikeman",
        "hair": "#aa8855",
        "hair_dark": "#886633",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#667788",
        "cloth_main": "#778899",     # grey-blue plate
        "cloth_dark": "#556677",
        "cloth_accent": "#ccbb88",
        "armor": "#99aabb",          # polished steel
        "armor_dark": "#778899",
        "boots": "#7a5a40",
        "boots_dark": "#5a3a20",
        "belt": "#8b6433",
        "pants": "#778899",
        "gloves": "#889999",
    },
    "feldprediger": {
        "name": "Feldprediger",
        "hair": "#665544",
        "hair_dark": "#443322",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#997755",
        "cloth_main": "#554466",     # dark purple vestment
        "cloth_dark": "#443355",
        "cloth_accent": "#eeeedd",   # white collar
        "armor": "#554466",
        "armor_dark": "#443355",
        "boots": "#665544",
        "boots_dark": "#4a3a2a",
        "belt": "#8b6433",
        "pants": "#665577",
        "gloves": "#665577",
    },
    "gelehrter": {
        "name": "Gelehrter",
        "hair": "#888899",
        "hair_dark": "#666677",
        "skin": "#f5d0a8",
        "skin_shadow": "#e0b890",
        "eye_iris": "#bb8833",
        "cloth_main": "#882233",     # deep crimson robe
        "cloth_dark": "#661122",
        "cloth_accent": "#ddbb55",   # gold trim
        "armor": "#882233",
        "armor_dark": "#661122",
        "boots": "#665544",
        "boots_dark": "#4a3a2a",
        "belt": "#ddbb55",
        "pants": "#882244",
        "gloves": "#993344",
    },
}

# ─── SVG helpers ───────────────────────────────────────────────────────
def svg_start(w, h):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}">\n')

def svg_end():
    return '</svg>\n'

def ellipse(cx, cy, rx, ry, fill, stroke=None, sw=None):
    s = stroke or OUTLINE
    w = sw or SW
    return f'  <ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{s}" stroke-width="{w}"/>\n'

def circle(cx, cy, r, fill, stroke=None, sw=None):
    s = stroke or OUTLINE
    w = sw or SW
    return f'  <circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{s}" stroke-width="{w}"/>\n'

def rect(x, y, w, h, fill, stroke=None, sw=None, rx=0):
    s = stroke or OUTLINE
    sw_ = sw or SW
    r = f' rx="{rx}"' if rx else ''
    return f'  <rect x="{x}" y="{y}" width="{w}" height="{h}"{r} fill="{fill}" stroke="{s}" stroke-width="{sw_}"/>\n'

def path(d, fill, stroke=None, sw=None):
    s = stroke or OUTLINE
    w = sw or SW
    return f'  <path d="{d}" fill="{fill}" stroke="{s}" stroke-width="{w}"/>\n'

def line(x1, y1, x2, y2, stroke=None, sw=None):
    s = stroke or OUTLINE
    w = sw or SW_INNER
    return f'  <line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{s}" stroke-width="{w}"/>\n'

def group_start(name=""):
    attr = f' id="{name}"' if name else ''
    return f'  <g{attr}>\n'

def group_end():
    return '  </g>\n'


# ─── Anime profile eye (3/4 view, facing right) ─────────────────────
def anime_eye(cx, cy, iris_color, size=1.0):
    """Draw a large anime eye. size=1.0 for near eye, ~0.5 for far eye."""
    # Eye white (tall oval)
    ew = 18 * size
    eh = 22 * size
    s = ''
    s += ellipse(cx, cy, ew, eh, "#ffffff", sw=SW)
    # Iris
    ir = 14 * size
    s += circle(cx, cy + 2 * size, ir, iris_color, sw=SW_INNER)
    # Pupil
    pr = 7 * size
    s += circle(cx, cy + 2 * size, pr, "#1a1a2e", sw=0)
    # Highlight (top-right)
    hr = 5 * size
    s += circle(cx + 4 * size, cy - 4 * size, hr, "#ffffff", stroke="none", sw=0)
    # Upper eyelid line (thick)
    s += path(
        f"M {cx-ew},{cy-4*size} Q {cx},{cy-eh-6*size} {cx+ew},{cy-4*size}",
        "none", OUTLINE, SW + 2
    )
    return s


# ─── Generic bone generators ──────────────────────────────────────────

def gen_head(pal):
    """176×200 head — 3/4 anime profile facing right."""
    w, h = 176, 200
    cx, cy = 92, 110  # shifted right for profile
    s = svg_start(w, h)

    hair = pal["hair"]
    hair_dk = pal["hair_dark"]
    skin = pal["skin"]
    iris = pal["eye_iris"]

    # Back hair (behind head)
    s += path(
        f"M 30,80 Q 20,60 35,40 Q 60,10 100,8 Q 130,10 145,35 "
        f"Q 155,55 148,85 Q 142,110 120,130 "
        f"L 50,130 Q 30,115 30,80 Z",
        hair_dk, sw=SW
    )

    # Face shape — rounded 3/4 profile
    s += path(
        f"M 50,70 Q 48,50 65,38 Q 85,28 108,32 "  # forehead
        f"Q 132,38 142,58 "                          # temple
        f"Q 150,78 148,100 "                          # cheek
        f"Q 145,118 135,130 "                         # jaw
        f"Q 120,148 98,150 "                          # chin
        f"Q 75,148 60,130 "                           # other jaw
        f"Q 48,110 50,70 Z",
        skin, sw=SW
    )

    # Far eye (left, smaller, partially hidden)
    s += anime_eye(72, 90, iris, size=0.55)
    # Near eye (right, larger)
    s += anime_eye(118, 88, iris, size=0.85)

    # Nose — small triangle bump on right profile
    s += path(
        f"M 135,100 Q 142,108 138,116",
        "none", pal["skin_shadow"], SW_INNER
    )

    # Mouth — small line
    s += line(108, 128, 126, 128, pal["skin_shadow"], SW_INNER)

    # Eyebrows
    s += path(f"M 60,76 Q 72,70 84,74", "none", hair_dk, SW_INNER + 2)
    s += path(f"M 104,72 Q 118,66 132,72", "none", hair_dk, SW_INNER + 2)

    # Front hair — voluminous with strands
    s += path(
        f"M 35,75 Q 30,45 50,25 Q 70,8 100,5 Q 135,8 150,30 "
        f"Q 158,50 152,75 "  # right side
        f"L 140,60 Q 135,45 120,38 Q 108,48 115,65 "  # strand dip
        f"L 100,50 Q 90,42 80,50 Q 85,62 90,68 "      # center strands
        f"L 70,55 Q 55,48 50,65 Z",
        hair, sw=SW
    )

    # Hair highlight strand
    s += path(
        f"M 80,20 Q 95,15 110,22",
        "none", pal.get("cloth_accent", "#ddcc88"), SW_INNER
    )

    # Ear (right side, partially visible)
    s += path(
        f"M 148,80 Q 158,85 156,100 Q 154,110 148,108",
        "none", skin, SW_INNER
    )

    s += svg_end()
    return s


def gen_torso(pal):
    """136×112 torso — compact body with clothing."""
    w, h = 136, 112
    cx = 70  # slightly right for 3/4
    s = svg_start(w, h)

    main = pal["cloth_main"]
    dark = pal["cloth_dark"]
    accent = pal["cloth_accent"]

    # Torso body shape — tapered
    s += path(
        f"M 28,8 Q 24,4 40,2 L 100,2 Q 116,4 112,8 "  # shoulders
        f"L 115,90 Q 112,105 100,108 L 40,108 Q 28,105 25,90 Z",  # waist
        main, sw=SW
    )

    # 3/4 depth shadow on far side
    s += path(
        f"M 28,8 L 25,90 Q 28,105 40,108 L 52,108 L 48,8 Z",
        dark, sw=0
    )

    # Collar / neckline
    s += path(
        f"M 48,2 Q 55,12 70,14 Q 85,12 92,2",
        "none", accent, SW_INNER
    )

    # Center seam
    s += line(72, 14, 72, 108, dark, SW_INNER)

    # Clothing fold lines
    s += line(45, 35, 50, 65, dark, SW_INNER)
    s += line(95, 35, 90, 65, dark, SW_INNER)

    s += svg_end()
    return s


def gen_hips(pal):
    """112×32 hips — belt area."""
    w, h = 112, 32
    s = svg_start(w, h)

    s += rect(8, 2, 96, 28, pal["pants"], rx=6)
    # Belt
    s += rect(8, 4, 96, 14, pal["belt"], rx=4)
    # Buckle
    s += rect(48, 5, 16, 12, pal.get("cloth_accent", "#ddcc88"), sw=SW_INNER, rx=2)

    s += svg_end()
    return s


def gen_arm(pal):
    """40×88 upper arm — tapered tube."""
    w, h = 40, 88
    cx = 20
    s = svg_start(w, h)

    cloth = pal["cloth_main"]
    dark = pal["cloth_dark"]

    # Arm shape — wider at shoulder, narrower at elbow
    s += path(
        f"M 6,6 Q 4,2 20,2 Q 36,2 34,6 "   # shoulder top
        f"L 30,80 Q 28,86 20,86 Q 12,86 10,80 Z",  # elbow
        cloth, sw=SW
    )

    # Shadow on far side
    s += path(
        f"M 6,6 L 10,80 Q 12,86 20,86 L 16,86 L 12,6 Z",
        dark, sw=0
    )

    # Sleeve fold
    s += line(16, 30, 18, 60, dark, SW_INNER)

    s += svg_end()
    return s


def gen_forearm(pal):
    """32×72 forearm."""
    w, h = 32, 72
    cx = 16
    s = svg_start(w, h)

    cloth = pal["cloth_main"]
    skin = pal["skin"]

    # Upper part — sleeve
    s += path(
        f"M 5,4 Q 3,2 16,2 Q 29,2 27,4 "
        f"L 24,42 Q 22,46 16,46 Q 10,46 8,42 Z",
        cloth, sw=SW
    )

    # Lower part — exposed skin/glove
    s += path(
        f"M 8,42 Q 10,38 16,38 Q 22,38 24,42 "
        f"L 22,66 Q 20,70 16,70 Q 12,70 10,66 Z",
        pal.get("gloves", skin), sw=SW
    )

    s += svg_end()
    return s


def gen_hand(pal):
    """56×56 hand — round mitten."""
    w, h = 56, 56
    cx, cy = 28, 30
    s = svg_start(w, h)

    glove = pal.get("gloves", pal["skin"])

    # Round mitten shape
    s += path(
        f"M 14,12 Q 8,8 10,20 Q 8,32 14,42 "    # left curve
        f"Q 20,50 28,50 "                          # bottom
        f"Q 36,50 42,42 "                          # right bottom
        f"Q 48,32 46,20 Q 48,8 42,12 "            # right curve
        f"Q 36,4 28,6 Q 20,4 14,12 Z",            # top
        glove, sw=SW
    )

    # Thumb bump (right side for profile)
    s += ellipse(42, 28, 8, 10, glove, sw=SW_INNER)

    # Finger line
    s += line(22, 32, 34, 32, OUTLINE, SW_INNER)

    s += svg_end()
    return s


def gen_leg(pal):
    """48×104 upper leg — tapered."""
    w, h = 48, 104
    s = svg_start(w, h)

    pants = pal["pants"]
    dark = pal.get("cloth_dark", "#333333")

    # Leg shape — wider at hip, narrower at knee
    s += path(
        f"M 6,4 Q 4,2 24,2 Q 44,2 42,4 "
        f"L 36,96 Q 34,102 24,102 Q 14,102 12,96 Z",
        pants, sw=SW
    )

    # Shadow on inner side
    s += path(
        f"M 6,4 L 12,96 Q 14,102 24,102 L 20,102 L 10,4 Z",
        dark, sw=0
    )

    s += svg_end()
    return s


def gen_shin(pal):
    """40×88 lower leg / shin."""
    w, h = 40, 88
    s = svg_start(w, h)

    boots = pal["boots"]
    boots_dk = pal["boots_dark"]

    # Shin → boot shape
    s += path(
        f"M 6,4 Q 4,2 20,2 Q 36,2 34,4 "
        f"L 30,80 Q 28,86 20,86 Q 12,86 10,80 Z",
        boots, sw=SW
    )

    # Boot top line
    s += line(8, 20, 32, 20, boots_dk, SW_INNER)

    # Shadow
    s += path(
        f"M 6,4 L 10,80 Q 12,86 20,86 L 16,86 L 10,4 Z",
        boots_dk, sw=0
    )

    s += svg_end()
    return s


def gen_foot(pal):
    """80×40 foot — side-view boot."""
    w, h = 80, 40
    s = svg_start(w, h)

    boots = pal["boots"]
    boots_dk = pal["boots_dark"]

    # Boot shape — side view facing right
    s += path(
        f"M 12,6 Q 8,4 10,14 L 8,28 "        # ankle back
        f"Q 6,36 18,36 L 64,36 "               # sole
        f"Q 74,36 76,30 Q 78,24 72,20 "        # toe
        f"L 36,16 Q 28,8 22,6 Z",              # top
        boots, sw=SW
    )

    # Sole line
    s += line(12, 32, 70, 32, boots_dk, SW_INNER)

    # Toe cap
    s += line(58, 18, 58, 34, boots_dk, SW_INNER)

    s += svg_end()
    return s


# ─── Class-specific head overrides ────────────────────────────────────

def gen_head_landsknecht(pal):
    """Landsknecht: messy brown hair, strong jaw."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]

    # Back hair
    s += path(
        f"M 28,85 Q 18,55 40,30 Q 65,8 105,6 Q 140,10 155,40 "
        f"Q 162,60 155,90 Q 148,115 125,135 "
        f"L 45,135 Q 25,118 28,85 Z",
        hair_dk, sw=SW
    )

    # Face — angular jaw for warrior
    s += path(
        f"M 48,72 Q 45,48 62,36 Q 82,24 110,28 "
        f"Q 138,34 148,58 Q 155,80 152,102 "
        f"Q 148,122 138,134 Q 122,150 100,152 "
        f"Q 78,150 62,134 Q 46,114 48,72 Z",
        skin, sw=SW
    )

    # Eyes
    s += anime_eye(74, 92, iris, size=0.55)
    s += anime_eye(120, 90, iris, size=0.85)

    # Nose
    s += path(f"M 140,102 Q 148,110 144,120", "none", pal["skin_shadow"], SW_INNER)

    # Mouth — slight grin
    s += path(f"M 110,132 Q 122,138 132,132", "none", pal["skin_shadow"], SW_INNER)

    # Eyebrows — thick, determined
    s += path(f"M 58,78 Q 72,70 86,76", "none", hair_dk, SW + 2)
    s += path(f"M 106,74 Q 122,66 138,74", "none", hair_dk, SW + 2)

    # Front hair — messy spikes
    s += path(
        f"M 32,80 Q 22,40 55,18 Q 75,5 105,4 Q 140,6 158,35 "
        f"Q 165,52 158,78 "
        f"L 148,58 Q 142,40 128,32 L 135,55 "
        f"L 118,38 Q 108,30 100,40 L 108,58 "
        f"L 88,35 Q 78,28 68,40 L 78,60 "
        f"L 58,42 Q 45,38 42,55 Z",
        hair, sw=SW
    )

    # Ear
    s += path(f"M 152,82 Q 164,88 162,104 Q 160,114 152,112", "none", skin, SW_INNER)

    s += svg_end()
    return s


def gen_head_healer(pal):
    """Healer: dark hood, gentle face."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]
    hood = pal["cloth_main"]

    # Hood back
    s += path(
        f"M 20,90 Q 10,50 35,25 Q 62,2 105,0 Q 148,5 162,35 "
        f"Q 170,60 165,95 Q 158,130 130,150 "
        f"L 42,150 Q 18,130 20,90 Z",
        hood, sw=SW
    )

    # Face
    s += path(
        f"M 50,75 Q 48,52 65,40 Q 85,28 108,32 "
        f"Q 132,38 142,58 Q 150,78 148,100 "
        f"Q 145,120 135,132 Q 120,148 100,150 "
        f"Q 78,148 62,132 Q 48,112 50,75 Z",
        skin, sw=SW
    )

    # Gentle eyes
    s += anime_eye(72, 90, iris, size=0.5)
    s += anime_eye(118, 88, iris, size=0.8)

    # Soft nose and mouth
    s += path(f"M 136,102 Q 142,108 138,116", "none", pal["skin_shadow"], SW_INNER)
    s += line(110, 130, 125, 130, pal["skin_shadow"], SW_INNER)

    # Gentle eyebrows
    s += path(f"M 60,78 Q 72,74 84,78", "none", hair_dk, SW_INNER + 2)
    s += path(f"M 106,76 Q 118,72 130,76", "none", hair_dk, SW_INNER + 2)

    # Hood front — draping over forehead
    s += path(
        f"M 25,88 Q 15,45 42,20 Q 68,2 108,0 Q 150,4 166,32 "
        f"Q 172,55 168,85 "
        f"L 155,70 Q 150,50 135,38 Q 115,28 95,30 "
        f"Q 72,32 55,45 Q 40,58 38,78 Z",
        hood, sw=SW
    )

    # Hood shadow fold
    s += path(f"M 38,78 Q 50,72 70,70 Q 90,68 110,72", "none", pal["cloth_dark"], SW_INNER)

    # Small fringe of hair under hood
    s += path(
        f"M 52,68 Q 60,62 72,65 Q 80,60 88,65 L 85,72 L 70,70 L 55,72 Z",
        hair, sw=SW_INNER
    )

    s += svg_end()
    return s


def gen_head_crossbowman(pal):
    """Crossbowman: russet hair, leather cap."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]

    # Back hair
    s += path(
        f"M 30,82 Q 20,55 42,32 Q 68,10 105,8 Q 138,12 152,38 "
        f"Q 160,58 155,88 Q 148,112 128,132 "
        f"L 48,132 Q 28,115 30,82 Z",
        hair_dk, sw=SW
    )

    # Face
    s += path(
        f"M 50,72 Q 48,50 65,38 Q 85,26 108,30 "
        f"Q 132,36 142,56 Q 150,76 148,98 "
        f"Q 145,118 135,130 Q 120,146 100,148 "
        f"Q 78,146 62,130 Q 48,110 50,72 Z",
        skin, sw=SW
    )

    # Eyes — focused, slightly narrowed
    s += anime_eye(72, 88, iris, size=0.5)
    s += anime_eye(118, 86, iris, size=0.78)

    s += path(f"M 138,100 Q 144,106 140,114", "none", pal["skin_shadow"], SW_INNER)
    s += line(108, 128, 124, 128, pal["skin_shadow"], SW_INNER)

    # Eyebrows — focused
    s += path(f"M 58,76 Q 72,68 86,74", "none", hair_dk, SW + 2)
    s += path(f"M 106,72 Q 122,64 136,72", "none", hair_dk, SW + 2)

    # Front hair — short and practical
    s += path(
        f"M 35,78 Q 25,42 52,20 Q 78,5 108,6 Q 142,10 158,38 "
        f"Q 164,52 158,72 "
        f"L 145,55 Q 138,40 120,34 L 128,52 "
        f"L 105,36 Q 92,30 82,38 L 90,54 "
        f"L 68,40 Q 52,36 45,52 Z",
        hair, sw=SW
    )

    # Leather cap band
    s += path(
        f"M 38,52 Q 55,42 90,38 Q 125,38 148,48",
        "none", pal["armor"], SW + 2
    )

    # Ear
    s += path(f"M 152,80 Q 162,86 160,100 Q 158,110 152,108", "none", skin, SW_INNER)

    s += svg_end()
    return s


def gen_head_arquebusier(pal):
    """Arquebusier: grey hair, leather cap, stern."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]

    # Back hair — cropped short
    s += path(
        f"M 35,78 Q 28,52 48,32 Q 72,12 108,10 Q 140,14 155,38 "
        f"Q 162,55 158,82 Q 152,105 135,120 "
        f"L 52,120 Q 32,108 35,78 Z",
        hair_dk, sw=SW
    )

    # Face — harder angles
    s += path(
        f"M 50,70 Q 48,48 65,36 Q 85,24 110,28 "
        f"Q 135,34 145,55 Q 152,75 150,98 "
        f"Q 146,118 136,130 Q 122,148 100,150 "
        f"Q 78,148 62,130 Q 48,110 50,70 Z",
        skin, sw=SW
    )

    # Eyes — narrow, stern
    s += anime_eye(72, 88, iris, size=0.48)
    s += anime_eye(118, 86, iris, size=0.75)

    s += path(f"M 138,100 Q 144,106 140,114", "none", pal["skin_shadow"], SW_INNER)
    s += line(112, 130, 128, 126, pal["skin_shadow"], SW_INNER)

    # Thick stern eyebrows
    s += path(f"M 56,74 Q 72,66 88,72", "none", hair_dk, SW + 4)
    s += path(f"M 104,70 Q 122,62 140,70", "none", hair_dk, SW + 4)

    # Front hair — very short crop
    s += path(
        f"M 38,74 Q 30,45 55,24 Q 80,8 110,8 Q 142,12 158,35 "
        f"Q 164,50 160,72 "
        f"L 150,58 Q 142,42 125,34 L 130,50 "
        f"L 108,36 Q 95,30 85,38 L 92,50 "
        f"L 70,38 Q 55,34 48,50 Z",
        hair, sw=SW
    )

    # Leather cap
    s += path(
        f"M 35,42 Q 50,28 90,22 Q 130,22 158,35 "
        f"Q 162,38 158,42 Q 130,35 90,32 Q 50,35 38,42 Z",
        pal["armor_dark"], sw=SW
    )

    # Ear
    s += path(f"M 154,78 Q 164,84 162,98 Q 160,108 154,106", "none", skin, SW_INNER)

    s += svg_end()
    return s


def gen_head_pikeman(pal):
    """Pikeman: steel helmet with nose guard."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]
    steel = pal["armor"]
    steel_dk = pal["armor_dark"]

    # Back hair under helmet
    s += path(
        f"M 35,88 Q 30,65 48,45 Q 70,28 105,25 Q 140,28 155,48 "
        f"Q 162,65 158,90 Q 152,110 135,125 "
        f"L 50,125 Q 32,110 35,88 Z",
        hair_dk, sw=SW
    )

    # Face
    s += path(
        f"M 50,72 Q 48,50 65,38 Q 85,26 108,30 "
        f"Q 132,36 142,56 Q 150,76 148,98 "
        f"Q 145,118 135,130 Q 120,146 100,148 "
        f"Q 78,146 62,130 Q 48,110 50,72 Z",
        skin, sw=SW
    )

    # Eyes — steady
    s += anime_eye(72, 88, iris, size=0.5)
    s += anime_eye(118, 86, iris, size=0.8)

    s += path(f"M 138,100 Q 144,106 140,114", "none", pal["skin_shadow"], SW_INNER)
    s += line(108, 128, 124, 128, pal["skin_shadow"], SW_INNER)

    # Eyebrows
    s += path(f"M 58,76 Q 72,70 86,76", "none", hair_dk, SW + 2)
    s += path(f"M 106,74 Q 122,68 136,74", "none", hair_dk, SW + 2)

    # Helmet — dome shape over head
    s += path(
        f"M 25,78 Q 18,40 50,18 Q 80,2 110,4 Q 145,8 162,32 "
        f"Q 172,52 168,78 "
        f"L 158,82 Q 162,55 148,38 Q 130,20 105,18 "
        f"Q 78,18 55,35 Q 38,52 35,78 Z",
        steel, sw=SW
    )

    # Helmet brim
    s += path(
        f"M 22,78 Q 20,72 28,68 L 165,68 Q 172,72 170,78 "
        f"Q 168,84 160,82 L 32,82 Q 24,84 22,78 Z",
        steel_dk, sw=SW
    )

    # Nose guard
    s += path(
        f"M 135,68 L 138,80 Q 140,90 136,95 L 130,95 Q 128,90 130,80 L 128,68",
        steel_dk, sw=SW_INNER
    )

    # Hair peeking below helmet
    s += path(
        f"M 38,82 Q 45,78 60,80 Q 75,82 80,85",
        "none", hair, SW_INNER + 2
    )

    # Ear area
    s += path(f"M 155,82 Q 162,88 160,100 Q 158,108 155,106", "none", skin, SW_INNER)

    s += svg_end()
    return s


def gen_head_feldprediger(pal):
    """Feldprediger: tonsure/clerical cut, scholarly."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]

    # Back hair
    s += path(
        f"M 32,82 Q 25,55 45,34 Q 68,14 105,12 Q 140,16 155,40 "
        f"Q 162,58 158,85 Q 152,108 132,125 "
        f"L 48,125 Q 30,110 32,82 Z",
        hair_dk, sw=SW
    )

    # Face — gentle, rounded
    s += path(
        f"M 50,72 Q 48,50 65,38 Q 85,28 108,32 "
        f"Q 132,38 142,58 Q 150,78 148,100 "
        f"Q 145,118 135,130 Q 120,148 100,150 "
        f"Q 78,148 62,130 Q 48,110 50,72 Z",
        skin, sw=SW
    )

    # Eyes — wise, gentle
    s += anime_eye(72, 90, iris, size=0.5)
    s += anime_eye(118, 88, iris, size=0.78)

    s += path(f"M 136,102 Q 142,108 138,116", "none", pal["skin_shadow"], SW_INNER)
    s += line(108, 130, 122, 130, pal["skin_shadow"], SW_INNER)

    # Gentle eyebrows
    s += path(f"M 60,78 Q 72,74 84,78", "none", hair_dk, SW_INNER + 2)
    s += path(f"M 106,76 Q 118,72 130,76", "none", hair_dk, SW_INNER + 2)

    # Front hair — receding/tonsure, neat sides
    s += path(
        f"M 35,78 Q 28,48 52,28 Q 78,12 108,12 Q 142,16 158,38 "
        f"Q 164,52 160,78 "
        f"L 148,62 Q 142,48 128,42 Q 118,52 125,65 "
        f"L 100,55 Q 88,62 95,72 "
        f"L 68,62 Q 55,58 48,68 Z",
        hair, sw=SW
    )

    # White collar
    s += path(
        f"M 60,148 Q 75,155 100,155 Q 125,155 140,148 "
        f"Q 145,152 135,158 Q 115,168 100,168 "
        f"Q 85,168 65,158 Q 55,152 60,148 Z",
        pal["cloth_accent"], sw=SW_INNER
    )

    # Ear
    s += path(f"M 152,82 Q 162,88 160,100 Q 158,110 152,108", "none", skin, SW_INNER)

    s += svg_end()
    return s


def gen_head_gelehrter(pal):
    """Gelehrter: silver-grey hair, circlet, scholarly."""
    w, h = 176, 200
    s = svg_start(w, h)
    hair, hair_dk = pal["hair"], pal["hair_dark"]
    skin, iris = pal["skin"], pal["eye_iris"]
    gold = pal["cloth_accent"]

    # Back hair — longer, flowing
    s += path(
        f"M 25,88 Q 15,50 40,25 Q 68,4 105,2 Q 145,8 160,35 "
        f"Q 170,58 165,95 Q 158,130 135,155 "
        f"L 40,155 Q 18,135 25,88 Z",
        hair_dk, sw=SW
    )

    # Face
    s += path(
        f"M 50,72 Q 48,50 65,38 Q 85,28 108,32 "
        f"Q 132,38 142,58 Q 150,78 148,100 "
        f"Q 145,118 135,130 Q 120,148 100,150 "
        f"Q 78,148 62,130 Q 48,110 50,72 Z",
        skin, sw=SW
    )

    # Eyes — sharp, intelligent
    s += anime_eye(72, 90, iris, size=0.52)
    s += anime_eye(118, 88, iris, size=0.82)

    s += path(f"M 138,102 Q 144,108 140,116", "none", pal["skin_shadow"], SW_INNER)
    s += path(f"M 108,130 Q 118,134 128,130", "none", pal["skin_shadow"], SW_INNER)

    # Sharp eyebrows
    s += path(f"M 58,76 Q 72,68 86,74", "none", hair_dk, SW + 2)
    s += path(f"M 106,72 Q 122,64 138,72", "none", hair_dk, SW + 2)

    # Front hair — longer, swept back with strands
    s += path(
        f"M 28,85 Q 18,42 48,18 Q 75,2 108,2 Q 148,6 165,35 "
        f"Q 172,55 168,82 "
        f"L 155,65 Q 148,45 130,35 L 140,58 "
        f"L 115,35 Q 102,25 90,35 L 100,55 "
        f"L 75,32 Q 60,25 50,42 L 58,62 "
        f"L 40,48 Q 32,45 30,58 Z",
        hair, sw=SW
    )

    # Gold circlet
    s += path(
        f"M 35,55 Q 50,42 90,36 Q 130,36 160,48",
        "none", gold, SW + 2
    )
    # Circlet gem
    s += circle(98, 38, 6, "#cc3333", sw=SW_INNER)

    # Ear
    s += path(f"M 155,82 Q 165,88 163,102 Q 161,112 155,110", "none", skin, SW_INNER)

    s += svg_end()
    return s


# ─── Class-specific torso overrides ──────────────────────────────────

def gen_torso_landsknecht(pal):
    """Crimson slashed doublet with steel chest plate accent."""
    w, h = 136, 112
    s = svg_start(w, h)
    main, dark, accent = pal["cloth_main"], pal["cloth_dark"], pal["cloth_accent"]
    steel = pal["armor"]

    # Main torso
    s += path(
        f"M 28,6 Q 22,2 42,0 L 98,0 Q 118,2 112,6 "
        f"L 115,92 Q 112,106 98,110 L 42,110 Q 28,106 25,92 Z",
        main, sw=SW
    )
    # Shadow side
    s += path(f"M 28,6 L 25,92 Q 28,106 42,110 L 52,110 L 48,6 Z", dark, sw=0)

    # Slashed detail — diagonal cuts showing accent color
    for y in range(22, 82, 18):
        s += path(f"M 55,{y} L 75,{y+8} L 72,{y+12} L 52,{y+4} Z", accent, sw=0)

    # Steel gorget (neck guard)
    s += path(
        f"M 45,0 Q 52,8 70,10 Q 88,8 95,0 L 98,4 Q 88,14 70,16 Q 52,14 42,4 Z",
        steel, sw=SW_INNER
    )

    # Center lacing
    s += line(70, 16, 70, 108, dark, SW_INNER)

    s += svg_end()
    return s


def gen_torso_healer(pal):
    """Dark blue robe with white sash."""
    w, h = 136, 112
    s = svg_start(w, h)
    main, dark, accent = pal["cloth_main"], pal["cloth_dark"], pal["cloth_accent"]

    # Robe body
    s += path(
        f"M 26,6 Q 20,2 40,0 L 100,0 Q 120,2 114,6 "
        f"L 118,92 Q 115,106 100,110 L 40,110 Q 25,106 22,92 Z",
        main, sw=SW
    )
    s += path(f"M 26,6 L 22,92 Q 25,106 40,110 L 52,110 L 48,6 Z", dark, sw=0)

    # White sash diagonal
    s += path(
        f"M 48,0 L 62,0 L 100,110 L 86,110 Z",
        accent, sw=SW_INNER
    )

    # Cross emblem on sash
    s += rect(68, 42, 4, 20, main, sw=0)
    s += rect(60, 48, 20, 4, main, sw=0)

    # Collar line
    s += path(f"M 48,0 Q 58,10 70,12 Q 82,10 92,0", "none", dark, SW_INNER)

    s += svg_end()
    return s


def gen_torso_pikeman(pal):
    """Steel plate over chain mail."""
    w, h = 136, 112
    s = svg_start(w, h)
    steel, steel_dk = pal["armor"], pal["armor_dark"]
    chain = pal["cloth_dark"]

    # Chain mail base
    s += path(
        f"M 28,6 Q 22,2 42,0 L 98,0 Q 118,2 112,6 "
        f"L 115,92 Q 112,106 98,110 L 42,110 Q 28,106 25,92 Z",
        chain, sw=SW
    )

    # Steel breastplate over chain
    s += path(
        f"M 32,8 Q 28,4 48,2 L 92,2 Q 112,4 108,8 "
        f"L 110,72 Q 108,82 92,84 L 48,84 Q 32,82 30,72 Z",
        steel, sw=SW
    )
    # Plate shadow
    s += path(f"M 32,8 L 30,72 Q 32,82 48,84 L 56,84 L 52,8 Z", steel_dk, sw=0)

    # Plate center ridge
    s += line(70, 4, 70, 82, steel_dk, SW_INNER)

    # Rivets
    for y in [20, 45, 70]:
        s += circle(42, y, 3, steel_dk, sw=0)
        s += circle(98, y, 3, steel_dk, sw=0)

    s += svg_end()
    return s


def gen_torso_feldprediger(pal):
    """Dark purple vestments with white collar."""
    w, h = 136, 112
    s = svg_start(w, h)
    main, dark, accent = pal["cloth_main"], pal["cloth_dark"], pal["cloth_accent"]

    # Vestment body
    s += path(
        f"M 26,6 Q 20,2 40,0 L 100,0 Q 120,2 114,6 "
        f"L 118,92 Q 115,106 100,110 L 40,110 Q 25,106 22,92 Z",
        main, sw=SW
    )
    s += path(f"M 26,6 L 22,92 Q 25,106 40,110 L 50,110 L 46,6 Z", dark, sw=0)

    # White collar band
    s += path(
        f"M 44,0 Q 52,10 70,14 Q 88,10 96,0 "
        f"L 100,4 Q 88,16 70,20 Q 52,16 40,4 Z",
        accent, sw=SW_INNER
    )

    # Cross/religious symbol
    s += rect(65, 36, 10, 28, accent, sw=0)
    s += rect(58, 44, 24, 8, accent, sw=0)

    # Hem detail
    s += line(30, 95, 110, 95, dark, SW_INNER)

    s += svg_end()
    return s


def gen_torso_gelehrter(pal):
    """Deep crimson scholar robe with gold trim."""
    w, h = 136, 112
    s = svg_start(w, h)
    main, dark, gold = pal["cloth_main"], pal["cloth_dark"], pal["cloth_accent"]

    # Robe body
    s += path(
        f"M 24,6 Q 18,2 38,0 L 102,0 Q 122,2 116,6 "
        f"L 120,92 Q 117,106 102,110 L 38,110 Q 23,106 20,92 Z",
        main, sw=SW
    )
    s += path(f"M 24,6 L 20,92 Q 23,106 38,110 L 50,110 L 46,6 Z", dark, sw=0)

    # Gold trim along edges
    s += path(f"M 46,0 L 48,110", "none", gold, SW_INNER + 2)
    s += path(f"M 92,0 L 90,110", "none", gold, SW_INNER + 2)

    # Mystical symbol
    s += circle(70, 52, 14, "none", gold, SW_INNER + 2)
    s += path(f"M 70,38 L 70,66 M 56,52 L 84,52", "none", gold, SW_INNER)

    # Collar
    s += path(f"M 46,0 Q 56,10 70,12 Q 84,10 94,0", "none", dark, SW_INNER)

    s += svg_end()
    return s


# ─── Map bones to generators ──────────────────────────────────────────

GENERIC_GENERATORS = {
    "head": gen_head,
    "torso": gen_torso,
    "hips": gen_hips,
    "leftarm": gen_arm,
    "rightarm": gen_arm,
    "leftforearm": gen_forearm,
    "rightforearm": gen_forearm,
    "lefthand": gen_hand,
    "righthand": gen_hand,
    "leftleg": gen_leg,
    "rightleg": gen_leg,
    "leftshin": gen_shin,
    "rightshin": gen_shin,
    "leftfoot": gen_foot,
    "rightfoot": gen_foot,
}

CLASS_OVERRIDES = {
    "landsknecht": {
        "head": gen_head_landsknecht,
        "torso": gen_torso_landsknecht,
    },
    "healer": {
        "head": gen_head_healer,
        "torso": gen_torso_healer,
    },
    "crossbowman": {
        "head": gen_head_crossbowman,
    },
    "arquebusier": {
        "head": gen_head_arquebusier,
    },
    "pikeman": {
        "head": gen_head_pikeman,
        "torso": gen_torso_pikeman,
    },
    "feldprediger": {
        "head": gen_head_feldprediger,
        "torso": gen_torso_feldprediger,
    },
    "gelehrter": {
        "head": gen_head_gelehrter,
        "torso": gen_torso_gelehrter,
    },
}


# ─── Generation entry point ──────────────────────────────────────────

def generate_class(class_name, pal, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    overrides = CLASS_OVERRIDES.get(class_name, {})
    for bone, gen_fn in GENERIC_GENERATORS.items():
        fn = overrides.get(bone, gen_fn)
        svg_content = fn(pal)
        filepath = os.path.join(output_dir, f"{bone}.svg")
        with open(filepath, "w") as f:
            f.write(svg_content)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    rig_dir = os.path.join(project_root, "assets", "rig_textures")
    canvas_dir = os.path.join(project_root, "scenes", "demos", "canvas", "svgs", "rig")

    total = 0
    for class_name, pal in PALETTES.items():
        out = os.path.join(rig_dir, class_name)
        generate_class(class_name, pal, out)

        canvas_out = os.path.join(canvas_dir, class_name)
        generate_class(class_name, pal, canvas_out)

        total += 15
        print(f"  ✓ {class_name}: 15 SVGs → {out}")

    print(f"\nGenerated {total * 2} SVGs ({total} rig + {total} canvas)")


if __name__ == "__main__":
    main()
