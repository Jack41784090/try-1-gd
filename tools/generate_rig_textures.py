#!/usr/bin/env python3
"""Generate geometric placeholder textures for all 7 warrior classes.

Each class gets a unique color palette and visual pattern on armor pieces.
Textures are sized to match the polygon placeholders in WarriorRig._build_placeholder_body().

Output: assets/rig_textures/<class_name>/<bone_name>.png
"""

import os
import math
from PIL import Image, ImageDraw

BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "rig_textures")

SCALE = 4

SKIN_COLOR = (237, 194, 153)
SKIN_SHADOW = (210, 168, 130)

CLASS_PALETTES = {
    "landsknecht": {
        "primary":      (184, 46, 46),
        "secondary":    (148, 36, 36),
        "accent":       (220, 180, 50),
        "metal":        (170, 170, 175),
        "metal_dark":   (130, 130, 138),
        "leather":      (110, 72, 42),
        "leather_dark": (80, 52, 30),
        "boots":        (72, 51, 36),
        "cloth":        (150, 42, 42),
    },
    "healer": {
        "primary":      (56, 97, 184),
        "secondary":    (72, 115, 200),
        "accent":       (220, 220, 240),
        "metal":        (160, 165, 180),
        "metal_dark":   (120, 125, 140),
        "leather":      (90, 75, 65),
        "leather_dark": (65, 55, 45),
        "boots":        (72, 51, 40),
        "cloth":        (80, 110, 170),
    },
    "crossbowman": {
        "primary":      (60, 100, 55),
        "secondary":    (45, 78, 42),
        "accent":       (180, 160, 100),
        "metal":        (155, 155, 150),
        "metal_dark":   (115, 115, 110),
        "leather":      (120, 85, 50),
        "leather_dark": (90, 65, 38),
        "boots":        (80, 58, 38),
        "cloth":        (70, 95, 65),
    },
    "arquebusier": {
        "primary":      (80, 65, 55),
        "secondary":    (60, 48, 40),
        "accent":       (200, 160, 80),
        "metal":        (140, 140, 145),
        "metal_dark":   (100, 100, 108),
        "leather":      (100, 70, 45),
        "leather_dark": (75, 52, 32),
        "boots":        (55, 40, 30),
        "cloth":        (90, 75, 60),
    },
    "pikeman": {
        "primary":      (160, 160, 170),
        "secondary":    (130, 130, 142),
        "accent":       (60, 60, 180),
        "metal":        (185, 185, 195),
        "metal_dark":   (140, 140, 152),
        "leather":      (100, 80, 60),
        "leather_dark": (75, 60, 42),
        "boots":        (70, 55, 38),
        "cloth":        (50, 50, 140),
    },
    "feldprediger": {
        "primary":      (50, 42, 65),
        "secondary":    (70, 58, 90),
        "accent":       (210, 190, 100),
        "metal":        (150, 148, 155),
        "metal_dark":   (110, 108, 118),
        "leather":      (85, 65, 50),
        "leather_dark": (62, 48, 35),
        "boots":        (60, 45, 32),
        "cloth":        (90, 75, 120),
    },
    "gelehrter": {
        "primary":      (120, 30, 80),
        "secondary":    (90, 22, 60),
        "accent":       (80, 220, 200),
        "metal":        (145, 140, 148),
        "metal_dark":   (105, 100, 112),
        "leather":      (70, 55, 55),
        "leather_dark": (50, 40, 40),
        "boots":        (55, 38, 38),
        "cloth":        (140, 50, 100),
    },
}

BONE_SIZES = {
    "Head":          (22, 26),
    "Torso":         (48, 44),
    "Hips":          (40, 12),
    "LeftArm":       (14, 36),
    "LeftForearm":   (12, 26),
    "LeftHand":      (10, 10),
    "RightArm":      (14, 36),
    "RightForearm":  (12, 26),
    "RightHand":     (10, 10),
    "LeftLeg":       (16, 48),
    "LeftShin":      (14, 36),
    "LeftFoot":      (24, 12),
    "RightLeg":      (16, 48),
    "RightShin":     (14, 36),
    "RightFoot":     (24, 12),
}


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_stripe_pattern(draw, w, h, color1, color2, stripe_width=4, horizontal=False):
    for y in range(h):
        for x in range(w):
            if horizontal:
                band = (y // stripe_width) % 2
            else:
                band = ((x + y) // stripe_width) % 2
            draw.point((x, y), fill=color1 if band == 0 else color2)


def draw_diamond_pattern(draw, w, h, bg, fg, size=6):
    draw.rectangle([0, 0, w - 1, h - 1], fill=bg)
    for cy in range(0, h + size, size):
        for cx in range(0, w + size, size):
            half = size // 2
            pts = [(cx, cy - half), (cx + half, cy), (cx, cy + half), (cx - half, cy)]
            draw.polygon(pts, fill=fg)


def draw_dot_pattern(draw, w, h, bg, fg, spacing=6, radius=1):
    draw.rectangle([0, 0, w - 1, h - 1], fill=bg)
    for cy in range(spacing // 2, h, spacing):
        for cx in range(spacing // 2, w, spacing):
            draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=fg)


def draw_cross_hatching(draw, w, h, bg, fg, spacing=5):
    draw.rectangle([0, 0, w - 1, h - 1], fill=bg)
    for i in range(-h, w + h, spacing):
        draw.line([(i, 0), (i + h, h)], fill=fg, width=1)
        draw.line([(i, h), (i + h, 0)], fill=fg, width=1)


def draw_chevron_pattern(draw, w, h, bg, fg, size=8):
    draw.rectangle([0, 0, w - 1, h - 1], fill=bg)
    for row in range(0, h + size, size):
        for col in range(-size, w + size, size * 2):
            pts = [
                (col, row),
                (col + size, row - size // 2),
                (col + size * 2, row),
                (col + size, row + size // 2),
            ]
            draw.line([pts[0], pts[1]], fill=fg, width=1)
            draw.line([pts[1], pts[2]], fill=fg, width=1)


def draw_arcane_circles(draw, w, h, bg, fg, count=3):
    draw.rectangle([0, 0, w - 1, h - 1], fill=bg)
    for i in range(count):
        cx = w // 2 + int(math.cos(i * 2.1) * w * 0.2)
        cy = h // 2 + int(math.sin(i * 2.1) * h * 0.2)
        r = min(w, h) // (3 + i)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fg, width=1)


def draw_scale_mail(draw, w, h, color1, color2, scale_size=6):
    draw.rectangle([0, 0, w - 1, h - 1], fill=color1)
    for row in range(0, h + scale_size, scale_size):
        offset = (row // scale_size % 2) * (scale_size // 2)
        for col in range(-scale_size + offset, w + scale_size, scale_size):
            draw.arc([col, row - scale_size // 2, col + scale_size, row + scale_size // 2],
                     0, 180, fill=color2, width=1)


def generate_head(draw, w, h, pal, class_name):
    draw.ellipse([1, 2, w - 2, h - 1], fill=SKIN_COLOR)
    draw.arc([1, 2, w - 2, h - 1], 200, 340, fill=SKIN_SHADOW, width=1)
    hair_h = h // 3
    if class_name == "landsknecht":
        draw.ellipse([0, 0, w - 1, hair_h + 4], fill=(60, 40, 25))
        draw.rectangle([w // 4, 0, w * 3 // 4, hair_h // 2], fill=(80, 55, 35))
    elif class_name == "healer":
        draw.ellipse([0, 0, w - 1, hair_h + 6], fill=(50, 35, 22))
    elif class_name == "crossbowman":
        draw.ellipse([1, 0, w - 2, hair_h + 3], fill=(45, 32, 20))
        draw.rectangle([0, hair_h // 2, w - 1, hair_h + 2], fill=pal["leather"])
    elif class_name == "arquebusier":
        draw.ellipse([0, 0, w - 1, hair_h + 5], fill=(35, 28, 22))
        draw.rectangle([w // 3, 0, w * 2 // 3, 3], fill=pal["metal"])
    elif class_name == "pikeman":
        draw.rectangle([0, 0, w - 1, hair_h + 4], fill=pal["metal"])
        draw.rectangle([1, 1, w - 2, hair_h + 3], fill=pal["metal_dark"])
        draw.line([(0, hair_h + 4), (w - 1, hair_h + 4)], fill=pal["accent"], width=1)
    elif class_name == "feldprediger":
        draw.ellipse([0, 0, w - 1, hair_h + 5], fill=(38, 30, 24))
        cx, cy = w // 2, hair_h // 2 + 1
        draw.line([(cx - 2, cy), (cx + 2, cy)], fill=pal["accent"], width=1)
        draw.line([(cx, cy - 2), (cx, cy + 2)], fill=pal["accent"], width=1)
    elif class_name == "gelehrter":
        draw.ellipse([0, 0, w - 1, hair_h + 5], fill=(55, 25, 40))
        draw.arc([2, 0, w - 3, hair_h + 2], 0, 180, fill=pal["accent"], width=1)


def generate_torso(draw, w, h, pal, class_name):
    draw.rectangle([0, 0, w - 1, h - 1], fill=pal["primary"])
    stripe_h = h // 6
    draw.rectangle([0, 0, w - 1, stripe_h], fill=pal["secondary"])
    draw.rectangle([0, h - stripe_h, w - 1, h - 1], fill=pal["secondary"])

    if class_name == "landsknecht":
        draw_stripe_pattern(draw, w, h, pal["primary"], pal["secondary"], stripe_width=6)
        draw.rectangle([w // 3, 2, w * 2 // 3, h // 3], fill=pal["accent"])
    elif class_name == "healer":
        cx, cy = w // 2, h // 2
        draw.line([(cx, cy - 8), (cx, cy + 8)], fill=pal["accent"], width=3)
        draw.line([(cx - 6, cy), (cx + 6, cy)], fill=pal["accent"], width=3)
    elif class_name == "crossbowman":
        draw_diamond_pattern(draw, w, h, pal["primary"], pal["secondary"], size=8)
        draw.rectangle([0, h // 2 - 2, w - 1, h // 2 + 2], fill=pal["leather"])
    elif class_name == "arquebusier":
        draw_cross_hatching(draw, w, h, pal["primary"], pal["secondary"], spacing=6)
        for y_off in [h // 4, h // 2, h * 3 // 4]:
            draw.rectangle([2, y_off - 1, w - 3, y_off + 1], fill=pal["metal"])
    elif class_name == "pikeman":
        draw_scale_mail(draw, w, h, pal["primary"], pal["metal_dark"], scale_size=6)
        draw.rectangle([0, 0, w - 1, 3], fill=pal["accent"])
        draw.rectangle([0, h - 4, w - 1, h - 1], fill=pal["accent"])
    elif class_name == "feldprediger":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["primary"])
        draw_chevron_pattern(draw, w, h, pal["primary"], pal["cloth"], size=10)
        cx = w // 2
        draw.line([(cx - 4, h // 3), (cx + 4, h // 3)], fill=pal["accent"], width=2)
        draw.line([(cx, h // 3 - 4), (cx, h // 3 + 6)], fill=pal["accent"], width=2)
    elif class_name == "gelehrter":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["primary"])
        draw_arcane_circles(draw, w, h, pal["primary"], pal["accent"], count=4)
        draw_dot_pattern(draw, w, h // 4, pal["primary"], pal["accent"], spacing=5, radius=1)


def generate_hips(draw, w, h, pal, class_name):
    draw.rectangle([0, 0, w - 1, h - 1], fill=pal["leather"])
    draw.line([(0, h // 2), (w - 1, h // 2)], fill=pal["metal"], width=1)
    if class_name in ("pikeman",):
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["metal_dark"])
        draw.line([(0, h // 2), (w - 1, h // 2)], fill=pal["accent"], width=1)
    elif class_name in ("feldprediger", "gelehrter"):
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["cloth"])
        draw.line([(w // 4, 0), (w // 4, h - 1)], fill=pal["accent"], width=1)
        draw.line([(w * 3 // 4, 0), (w * 3 // 4, h - 1)], fill=pal["accent"], width=1)


def generate_arm(draw, w, h, pal, class_name):
    if class_name == "pikeman":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["metal"])
        draw.rectangle([1, 1, w - 2, h - 2], fill=pal["metal_dark"])
        draw.line([(w // 2, 0), (w // 2, h - 1)], fill=pal["primary"], width=1)
    else:
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["cloth"])
        draw.rectangle([0, 0, w - 1, 3], fill=pal["primary"])
        draw.rectangle([0, h - 4, w - 1, h - 1], fill=pal["primary"])


def generate_forearm(draw, w, h, pal, class_name):
    if class_name == "pikeman":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["metal"])
        draw.line([(0, h // 2), (w - 1, h // 2)], fill=pal["metal_dark"], width=1)
    elif class_name in ("landsknecht", "crossbowman"):
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["leather"])
        draw.rectangle([0, h - 4, w - 1, h - 1], fill=pal["metal"])
    else:
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["cloth"])
        draw.rectangle([0, h - 3, w - 1, h - 1], fill=pal["primary"])


def generate_hand(draw, w, h, pal, class_name):
    r = min(w, h) // 2
    cx, cy = w // 2, h // 2
    if class_name in ("pikeman", "landsknecht"):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=pal["metal"])
        draw.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], fill=pal["leather"])
    else:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SKIN_COLOR)
        draw.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=SKIN_SHADOW, width=1)


def generate_leg(draw, w, h, pal, class_name):
    if class_name == "pikeman":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["metal_dark"])
        draw.line([(w // 2, 0), (w // 2, h - 1)], fill=pal["metal"], width=1)
    elif class_name in ("gelehrter", "feldprediger"):
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["cloth"])
    else:
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["leather"])
        draw.rectangle([0, 0, 2, h - 1], fill=pal["leather_dark"])


def generate_shin(draw, w, h, pal, class_name):
    if class_name == "pikeman":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["metal"])
        draw.line([(0, h // 3), (w - 1, h // 3)], fill=pal["metal_dark"], width=1)
        draw.line([(0, h * 2 // 3), (w - 1, h * 2 // 3)], fill=pal["metal_dark"], width=1)
    else:
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["boots"])
        draw.rectangle([0, 0, w - 1, 2], fill=pal["leather"])


def generate_foot(draw, w, h, pal, class_name):
    draw.rectangle([0, 0, w - 1, h - 1], fill=pal["boots"])
    draw.rectangle([0, 0, w - 1, 2], fill=pal["leather"])
    if class_name == "pikeman":
        draw.rectangle([0, 0, w - 1, h - 1], fill=pal["metal_dark"])
        draw.rectangle([0, h // 2, w - 1, h // 2 + 1], fill=pal["metal"], width=1)


BONE_GENERATORS = {
    "Head":         generate_head,
    "Torso":        generate_torso,
    "Hips":         generate_hips,
    "LeftArm":      generate_arm,
    "RightArm":     generate_arm,
    "LeftForearm":  generate_forearm,
    "RightForearm": generate_forearm,
    "LeftHand":     generate_hand,
    "RightHand":    generate_hand,
    "LeftLeg":      generate_leg,
    "RightLeg":     generate_leg,
    "LeftShin":     generate_shin,
    "RightShin":    generate_shin,
    "LeftFoot":     generate_foot,
    "RightFoot":    generate_foot,
}


def generate_textures_for_class(class_name, palette):
    class_dir = os.path.join(BASE_DIR, class_name)
    os.makedirs(class_dir, exist_ok=True)

    for bone_name, (base_w, base_h) in BONE_SIZES.items():
        w = base_w * SCALE
        h = base_h * SCALE
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        generator = BONE_GENERATORS[bone_name]
        generator(draw, w, h, palette, class_name)

        filename = bone_name.lower() + ".png"
        filepath = os.path.join(class_dir, filename)
        img.save(filepath, "PNG")

    print(f"  Generated {len(BONE_SIZES)} textures for {class_name}")


def main():
    print("Generating placeholder rig textures...")
    os.makedirs(BASE_DIR, exist_ok=True)

    for class_name, palette in CLASS_PALETTES.items():
        generate_textures_for_class(class_name, palette)

    total = len(CLASS_PALETTES) * len(BONE_SIZES)
    print(f"\nDone! Generated {total} textures in {BASE_DIR}")
    print("Classes:", ", ".join(CLASS_PALETTES.keys()))
    print("Bones per class:", len(BONE_SIZES))


if __name__ == "__main__":
    main()
