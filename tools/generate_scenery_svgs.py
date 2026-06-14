#!/usr/bin/env python3
"""Generate flat SD-style scenery SVGs (backdrops + props) into assets/scenery/.

Matches the clean-outline / solid-fill / no-gradient style of generate_sd_svgs.py.
Props are world-space set dressing for the stage (StageSet / SceneryInstruction).
Run: python3 tools/generate_scenery_svgs.py
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets/scenery")

OUTLINE = "#0a0a0a"
SW = 4  # outline stroke width


def svg(w, h, body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
        'viewBox="0 0 %d %d">\n%s\n</svg>\n' % (w, h, w, h, body)
    )


def tree():
    body = []
    # trunk
    body.append('<rect x="88" y="170" width="24" height="120" rx="6" fill="#6b4a2b" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    # foliage blobs
    for cx, cy, r, c in [(100, 90, 70, "#3f7d3a"), (60, 120, 48, "#356b31"),
                          (140, 120, 48, "#356b31"), (100, 140, 55, "#488a40")]:
        body.append('<circle cx="%d" cy="%d" r="%d" fill="%s" stroke="%s" stroke-width="%d"/>' % (cx, cy, r, c, OUTLINE, SW))
    return svg(200, 300, "\n".join(body))


def pillar():
    body = []
    stone = "#d8d2c0"
    # base
    body.append('<rect x="10" y="560" width="120" height="36" rx="4" fill="%s" stroke="%s" stroke-width="%d"/>' % (stone, OUTLINE, SW))
    # shaft
    body.append('<rect x="28" y="44" width="84" height="520" fill="%s" stroke="%s" stroke-width="%d"/>' % (stone, OUTLINE, SW))
    # flutes
    for x in (48, 70, 92):
        body.append('<line x1="%d" y1="56" x2="%d" y2="552" stroke="#b3ab94" stroke-width="3"/>' % (x, x))
    # capital
    body.append('<rect x="10" y="12" width="120" height="36" rx="4" fill="%s" stroke="%s" stroke-width="%d"/>' % (stone, OUTLINE, SW))
    return svg(140, 600, "\n".join(body))


def banner():
    body = []
    cloth = "#8c2b2b"
    # top rod
    body.append('<rect x="8" y="8" width="124" height="18" rx="4" fill="#5a4326" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    # cloth with notched bottom
    body.append('<path d="M18 26 H122 V270 L70 300 L18 270 Z" fill="%s" stroke="%s" stroke-width="%d"/>' % (cloth, OUTLINE, SW))
    # emblem
    body.append('<circle cx="70" cy="130" r="34" fill="#e6c558" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    body.append('<circle cx="70" cy="130" r="14" fill="#8c2b2b"/>')
    return svg(140, 320, "\n".join(body))


def podium():
    body = []
    wood = "#7a5230"
    body.append('<path d="M30 30 H150 L168 60 H12 Z" fill="%s" stroke="%s" stroke-width="%d"/>' % (wood, OUTLINE, SW))
    body.append('<rect x="74" y="60" width="32" height="60" fill="#5f3f25" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    body.append('<rect x="36" y="120" width="108" height="22" rx="4" fill="%s" stroke="%s" stroke-width="%d"/>' % (wood, OUTLINE, SW))
    # emblem panel
    body.append('<rect x="48" y="36" width="84" height="20" fill="#e6c558" stroke="%s" stroke-width="3"/>' % OUTLINE)
    return svg(180, 150, "\n".join(body))


def bench():
    body = []
    stone = "#cfc8b4"
    body.append('<rect x="10" y="20" width="200" height="30" rx="6" fill="%s" stroke="%s" stroke-width="%d"/>' % (stone, OUTLINE, SW))
    body.append('<rect x="26" y="50" width="20" height="34" fill="#b3ab94" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    body.append('<rect x="174" y="50" width="20" height="34" fill="#b3ab94" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    return svg(220, 90, "\n".join(body))


def great_map():
    body = []
    body.append('<rect x="6" y="6" width="248" height="168" rx="8" fill="#e8dcb5" stroke="%s" stroke-width="%d"/>' % (OUTLINE, SW))
    # river
    body.append('<path d="M40 20 C80 70, 100 90, 90 160" fill="none" stroke="#3a6ea5" stroke-width="8"/>')
    # land tint left bank (occupied)
    body.append('<path d="M6 6 H88 C96 80, 70 120, 70 174 H6 Z" fill="#9c5b5b" fill-opacity="0.45"/>')
    # city dots
    for cx, cy in [(60, 50), (120, 80), (170, 120), (200, 60)]:
        body.append('<circle cx="%d" cy="%d" r="7" fill="#caa84a" stroke="%s" stroke-width="3"/>' % (cx, cy, OUTLINE))
    return svg(260, 180, "\n".join(body))


def backdrop_chamber():
    body = []
    # wall
    body.append('<rect x="0" y="0" width="1920" height="1080" fill="#e7e1d2"/>')
    # upper frieze band
    body.append('<rect x="0" y="0" width="1920" height="120" fill="#d8d0bb"/>')
    body.append('<line x1="0" y1="120" x2="1920" y2="120" stroke="#b9b099" stroke-width="6"/>')
    # tall arched windows
    for cx in range(260, 1920, 360):
        body.append('<path d="M%d 180 a90 90 0 0 1 180 0 V520 H%d Z" fill="#cfe0ef" stroke="#b9b099" stroke-width="6"/>' % (cx, cx))
    # tiered seat silhouettes along the bottom
    tiers = [(700, "#cbc3ad"), (780, "#c2b9a1"), (860, "#b7ad93")]
    for y, c in tiers:
        body.append('<rect x="0" y="%d" width="1920" height="90" fill="%s"/>' % (y, c))
        body.append('<line x1="0" y1="%d" x2="1920" y2="%d" stroke="#9c937b" stroke-width="4"/>' % (y, y))
    # floor
    body.append('<rect x="0" y="950" width="1920" height="130" fill="#a8997d"/>')
    return svg(1920, 1080, "\n".join(body))


def backdrop_forest():
    body = []
    body.append('<rect x="0" y="0" width="1920" height="1080" fill="#bfe0ef"/>')
    body.append('<rect x="0" y="720" width="1920" height="360" fill="#5c8a44"/>')
    body.append('<line x1="0" y1="720" x2="1920" y2="720" stroke="#3f6b31" stroke-width="6"/>')
    # distant tree silhouettes
    for x in range(120, 1920, 240):
        body.append('<circle cx="%d" cy="660" r="120" fill="#4f7d3a" fill-opacity="0.8"/>' % x)
    return svg(1920, 1080, "\n".join(body))


FILES = {
    "tree.svg": tree,
    "pillar.svg": pillar,
    "banner.svg": banner,
    "podium.svg": podium,
    "bench.svg": bench,
    "great_map.svg": great_map,
    "backdrop_chamber.svg": backdrop_chamber,
    "backdrop_forest.svg": backdrop_forest,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in FILES.items():
        path = os.path.join(OUT, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(fn())
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
