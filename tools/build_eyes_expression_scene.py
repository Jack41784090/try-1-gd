#!/usr/bin/env python3
"""Generate scenes/demos/eyes_expression_test.tscn -- a declarative, EDITABLE
prototype of the future Eyes.tscn part (deformable sclera mesh + pupil + morph
animation). No WarriorRig involved.

Offline asset tool (same pattern as build_parliament_cutscene.py): it WRITES the
.tscn text. The scene itself is fully declarative -- Godot loads the authored
nodes directly; nothing is created programmatically at runtime.

Run:  python3 tools/build_eyes_expression_scene.py
Then: open res://scenes/demos/eyes_expression_test.tscn and press F6.
"""
import math
import os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(__file__), "..", "scenes", "demos", "eyes_expression_test.tscn"))

BORDER_SCALE = 1.07
PUPIL_R = 13.0
PUPIL_SEGS = 24
LENGTH = 4.0       # neutral(0) -> wide(1) -> neutral(2) -> blink(3) -> neutral(4)

# Natural lid morph (inspired by assets/index.html): each rim vertex morphs toward a
# shared closed-curve for the blink, and asymmetrically for the widen -- the upper lid
# does most of the work, like a real eye. Godot's advantage: per-vertex bones carry the
# REAL artwork outline through these non-affine poses.
CLOSE_Y = 2.0        # where the lids meet on a blink (slightly below the centroid)
BLINK_UPPER = 0.94   # upper lid travels almost all the way to the closed curve
BLINK_LOWER = 0.85   # lower lid travels less (it barely moves in a real blink)
WIDEN_UPPER = 1.45   # wide opens the upper lid a lot...
WIDEN_LOWER = 1.18   # ...and drops the lower lid a little

CREAM = (0.945098, 0.882353, 0.796078)    # #f1e1cb eye-white body
OUTLINE = (0.13, 0.09, 0.07)
ACCENT = (0.764706, 0.807843, 0.921569)   # #c3ceeb blue accent
PUPIL_COL = (0.16, 0.11, 0.09)

# Sampled from eye_l_white_sclera_neutral.svg (texture space, 200x200 viewBox).
# PATH0 = eye-white body outline (the rim); PATH1 = blue accent feature.
PATH0_N = [
    (106.181, 143.557), (106.051, 137.495), (106.515, 131.527), (107.906, 125.837),
    (110.558, 120.606), (114.804, 116.020), (120.978, 112.259), (122.498, 112.038),
    (126.488, 111.562), (132.095, 111.116), (138.465, 110.984), (144.744, 111.450),
    (150.078, 112.798), (152.642, 114.806), (155.076, 116.970), (157.278, 119.349),
    (159.149, 121.998), (160.588, 124.976), (161.494, 128.338), (161.333, 131.664),
    (161.323, 134.433), (161.417, 136.826), (161.565, 139.019), (161.719, 141.190),
    (161.830, 143.519), (159.934, 152.106), (156.449, 158.981), (152.178, 164.258),
    (147.926, 168.051), (144.498, 170.474), (142.699, 171.641), (137.455, 170.280),
    (129.876, 166.422), (121.461, 160.943), (113.708, 154.721), (108.116, 148.633),
]
PATH1_N = [
    (80.547, 113.865), (82.456, 113.240), (84.390, 112.829), (86.571, 112.748),
    (88.705, 113.046), (90.494, 113.775), (90.965, 114.089), (91.398, 114.416),
    (91.781, 114.754), (92.100, 115.099), (92.986, 116.420), (93.542, 117.601),
    (93.829, 118.451), (93.911, 118.777), (89.870, 118.425), (86.547, 117.372),
    (83.564, 115.793),
]


def fnum(v):
    s = "%.6f" % v
    s = s.rstrip("0").rstrip(".")
    return s if s not in ("", "-") else "0"


def vec(p):
    return "Vector2(%s, %s)" % (fnum(p[0]), fnum(p[1]))


def color(c):
    return "Color(%s, %s, %s, 1)" % (fnum(c[0]), fnum(c[1]), fnum(c[2]))


def packed_vec2(pts):
    return "PackedVector2Array(" + ", ".join(
        "%s, %s" % (fnum(p[0]), fnum(p[1])) for p in pts) + ")"


def one_hot(n, idx):
    return "PackedFloat32Array(" + ", ".join(
        "1" if i == idx else "0" for i in range(n)) + ")"


def bones_prop(names):
    n = len(names)
    parts = ['"%s", %s' % (name, one_hot(n, k)) for k, name in enumerate(names)]
    return "bones = [" + ", ".join(parts) + "]"


def avg(pts):
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def lid_morph(p, mode):
    """Non-affine vertical morph for one centered rim point. Upper-lid points
    (y<0) and lower-lid points (y>=0) are treated differently so the eye opens and
    closes like a real lid instead of a uniform scale."""
    x, y = p
    if mode == "wide":
        return (x, y * (WIDEN_UPPER if y < 0 else WIDEN_LOWER))
    # blink: travel toward the shared closed curve; upper lid goes most of the way
    t = BLINK_UPPER if y < 0 else BLINK_LOWER
    return (x, y + (CLOSE_Y - y) * t)


def main():
    cx, cy = avg(PATH0_N)
    white = [(p[0] - cx, p[1] - cy) for p in PATH0_N]
    accent = [(p[0] - cx, p[1] - cy) for p in PATH1_N]
    border = [(p[0] * BORDER_SCALE, p[1] * BORDER_SCALE) for p in white]
    pupil = [(math.cos(math.tau * i / PUPIL_SEGS) * PUPIL_R,
              math.sin(math.tau * i / PUPIL_SEGS) * PUPIL_R) for i in range(PUPIL_SEGS)]

    wnames = ["W%d" % k for k in range(len(white))]
    bnames = ["B%d" % k for k in range(len(accent))]

    L = []
    L.append("[gd_scene format=3]")
    L.append("")

    # --- Animation sub_resource ---
    L.append('[sub_resource type="Animation" id="Animation_morph"]')
    L.append("length = %s" % fnum(LENGTH))
    L.append("loop_mode = 1")
    ti = 0
    for name, neutral in [(n, p) for n, p in zip(wnames, white)] + \
                         [(n, p) for n, p in zip(bnames, accent)]:
        wide = lid_morph(neutral, "wide")
        blink = lid_morph(neutral, "blink")
        L.append('tracks/%d/type = "value"' % ti)
        L.append("tracks/%d/imported = false" % ti)
        L.append("tracks/%d/enabled = true" % ti)
        L.append('tracks/%d/path = NodePath("Eyes/Sclera/%s:position")' % (ti, name))
        L.append("tracks/%d/interp = 1" % ti)
        L.append("tracks/%d/loop_wrap = true" % ti)
        L.append("tracks/%d/keys = {" % ti)
        L.append('"times": PackedFloat32Array(0, 1, 2, 3, 4),')
        L.append('"transitions": PackedFloat32Array(1, 1, 1, 1, 1),')
        L.append('"update": 0,')
        L.append('"values": [%s, %s, %s, %s, %s]' % (
            vec(neutral), vec(wide), vec(neutral), vec(blink), vec(neutral)))
        L.append("}")
        ti += 1
    # pupil: shrink a little on widen, squish + drop to the closing line on blink
    L.append('tracks/%d/type = "value"' % ti)
    L.append("tracks/%d/imported = false" % ti)
    L.append("tracks/%d/enabled = true" % ti)
    L.append('tracks/%d/path = NodePath("Eyes/Pupil:scale")' % ti)
    L.append("tracks/%d/interp = 1" % ti)
    L.append("tracks/%d/loop_wrap = true" % ti)
    L.append("tracks/%d/keys = {" % ti)
    L.append('"times": PackedFloat32Array(0, 1, 2, 3, 4),')
    L.append('"transitions": PackedFloat32Array(1, 1, 1, 1, 1),')
    L.append('"update": 0,')
    L.append('"values": [Vector2(1, 1), Vector2(0.75, 0.75), Vector2(1, 1), '
             'Vector2(1, 0.08), Vector2(1, 1)]')
    L.append("}")
    ti += 1
    L.append('tracks/%d/type = "value"' % ti)
    L.append("tracks/%d/imported = false" % ti)
    L.append("tracks/%d/enabled = true" % ti)
    L.append('tracks/%d/path = NodePath("Eyes/Pupil:position")' % ti)
    L.append("tracks/%d/interp = 1" % ti)
    L.append("tracks/%d/loop_wrap = true" % ti)
    L.append("tracks/%d/keys = {" % ti)
    L.append('"times": PackedFloat32Array(0, 1, 2, 3, 4),')
    L.append('"transitions": PackedFloat32Array(1, 1, 1, 1, 1),')
    L.append('"update": 0,')
    L.append('"values": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0), '
             'Vector2(0, %s), Vector2(0, 0)]' % fnum(CLOSE_Y))
    L.append("}")
    L.append("")

    L.append('[sub_resource type="AnimationLibrary" id="AnimationLibrary_morph"]')
    L.append("_data = {")
    L.append('&"morph": SubResource("Animation_morph")')
    L.append("}")
    L.append("")

    # --- Nodes ---
    L.append('[node name="EyesExpressionTest" type="Node2D"]')
    L.append("")
    L.append('[node name="Camera2D" type="Camera2D" parent="."]')
    L.append("zoom = Vector2(4, 4)")
    L.append("")
    L.append('[node name="Eyes" type="Node2D" parent="."]')
    L.append("")
    L.append('[node name="Sclera" type="Skeleton2D" parent="Eyes"]')
    L.append("")

    for name, pos in list(zip(wnames, white)) + list(zip(bnames, accent)):
        L.append('[node name="%s" type="Bone2D" parent="Eyes/Sclera"]' % name)
        L.append("position = %s" % vec(pos))
        L.append("rest = Transform2D(1, 0, 0, 1, %s, %s)" % (fnum(pos[0]), fnum(pos[1])))
        L.append("auto_calculate_length_and_angle = false")
        L.append("length = 16.0")
        L.append("bone_angle = 0.0")
        L.append("")

    # dark rim behind the cream fill, skinned to the same bones so the outline
    # deforms with the eye
    L.append('[node name="EyeWhiteBorder" type="Polygon2D" parent="Eyes/Sclera"]')
    L.append("z_as_relative = false")
    L.append("color = %s" % color(OUTLINE))
    L.append("antialiased = true")
    L.append('skeleton = NodePath("..")')
    L.append("polygon = %s" % packed_vec2(border))
    L.append(bones_prop(wnames))
    L.append("")

    L.append('[node name="EyeWhite" type="Polygon2D" parent="Eyes/Sclera"]')
    L.append("z_index = 1")
    L.append("z_as_relative = false")
    L.append("color = %s" % color(CREAM))
    L.append("antialiased = true")
    L.append('skeleton = NodePath("..")')
    L.append("polygon = %s" % packed_vec2(white))
    L.append(bones_prop(wnames))
    L.append("")

    L.append('[node name="Accent" type="Polygon2D" parent="Eyes/Sclera"]')
    L.append("z_index = 2")
    L.append("z_as_relative = false")
    L.append("color = %s" % color(ACCENT))
    L.append("antialiased = true")
    L.append('skeleton = NodePath("..")')
    L.append("polygon = %s" % packed_vec2(accent))
    L.append(bones_prop(bnames))
    L.append("")

    L.append('[node name="Pupil" type="Polygon2D" parent="Eyes"]')
    L.append("z_index = 3")
    L.append("z_as_relative = false")
    L.append("color = %s" % color(PUPIL_COL))
    L.append("antialiased = true")
    L.append("polygon = %s" % packed_vec2(pupil))
    L.append("")

    L.append('[node name="MorphPlayer" type="AnimationPlayer" parent="."]')
    L.append('libraries/ = SubResource("AnimationLibrary_morph")')
    L.append('autoplay = &"morph"')
    L.append("")

    with open(OUT, "w") as fh:
        fh.write("\n".join(L))

    print("[EYES] wrote %s" % OUT)
    print("[EYES] eye-white rim bones=%d accent bones=%d center(texture)=(%s, %s)" % (
        len(white), len(accent), fnum(cx), fnum(cy)))


if __name__ == "__main__":
    main()
