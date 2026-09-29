#!/usr/bin/env python3
"""Write share/colors.tsv: 20 hue families, five dark shades each.

The catalog is the source of truth. Regenerate it with this script, then
keep the checks at the bottom green: unique names, readable on a dark
window, and enough distance that neighboring hues still separate.
"""

import math
import os

NAMES = [
    "crimson", "rust", "copper", "amber", "olive", "moss", "fern", "forest",
    "pine", "jade", "teal", "lagoon", "cobalt", "navy", "indigo", "violet",
    "orchid", "plum", "wine", "rose",
]

# OKLCH hue 0 is red. The offset lands "crimson" on a red that still reads as crimson.
HUE_OFFSET = 25

# target relative luminance, chroma fraction of the gamut, brightest channel
SHADES = [
    ("ink", 0.028, 0.70, 110),
    ("deep", 0.050, 0.68, 130),
    ("", 0.078, 0.64, 150),
    ("soft", 0.108, 0.58, 170),
    ("glow", 0.145, 0.52, 190),
]


def lin_to_srgb(c):
    c = max(0.0, min(1.0, c))
    if c <= 0.0031308:
        return 12.92 * c
    return 1.055 * (c ** (1 / 2.4)) - 0.055


def oklab_to_linear(lightness, a, b):
    l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
    m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
    s_ = lightness - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bch = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return r, g, bch


def in_gamut(rgb):
    return all(-0.002 <= c <= 1.002 for c in rgb)


def rel_y(rgb):
    return 0.2126 * max(0.0, rgb[0]) + 0.7152 * max(0.0, rgb[1]) + 0.0722 * max(0.0, rgb[2])


def to_byte(rgb):
    out = []
    for c in rgb:
        c = max(0.0, min(1.0, c))
        out.append(max(0, min(255, int(round(lin_to_srgb(c) * 255)))))
    return tuple(out)


def cie_lab(rgb):
    def f(c):
        c = c / 255.0
        if c <= 0.04045:
            return c / 12.92
        return ((c + 0.055) / 1.055) ** 2.4

    r, g, b = f(rgb[0]), f(rgb[1]), f(rgb[2])
    x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

    def ff(t):
        if t > 0.008856:
            return t ** (1 / 3)
        return 7.787 * t + 16 / 116

    fx, fy, fz = ff(x / 0.95047), ff(y), ff(z / 1.08883)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def luminance(rgb):
    def f(c):
        c = c / 255.0
        if c <= 0.04045:
            return c / 12.92
        return ((c + 0.055) / 1.055) ** 2.4

    r, g, b = f(rgb[0]), f(rgb[1]), f(rgb[2])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def color_at(hue_deg, target_y, chroma_frac, channel_cap):
    hue = math.radians(hue_deg)
    lo, hi = 0.04, 0.8
    chosen = None
    for _ in range(24):
        lightness = (lo + hi) / 2
        clo, chi = 0.0, 0.32
        best_c = 0.0
        for _ in range(16):
            chroma = (clo + chi) / 2
            a = chroma * math.cos(hue)
            b = chroma * math.sin(hue)
            if in_gamut(oklab_to_linear(lightness, a, b)):
                best_c = chroma
                clo = chroma
            else:
                chi = chroma
        chroma = best_c * chroma_frac
        for _ in range(12):
            a = chroma * math.cos(hue)
            b = chroma * math.sin(hue)
            rgb = to_byte(oklab_to_linear(lightness, a, b))
            if max(rgb) <= channel_cap or chroma < 0.005:
                break
            chroma *= 0.92
        a = chroma * math.cos(hue)
        b = chroma * math.sin(hue)
        linear = oklab_to_linear(lightness, a, b)
        y = rel_y(linear)
        chosen = to_byte(linear)
        if y < target_y:
            lo = lightness
        else:
            hi = lightness
    return chosen


def build():
    rows = []
    for index, name in enumerate(NAMES):
        hue = index * (360.0 / len(NAMES)) + HUE_OFFSET
        for shade, target_y, frac, cap in SHADES:
            rgb = color_at(hue, target_y, frac, cap)
            if shade:
                cid = "%s-%s" % (name, shade)
                label = "%s %s" % (shade.title(), name.title())
            else:
                cid = name
                label = name.title()
            rows.append((cid, label, rgb))
    return rows


def delta(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def check(rows):
    if len(rows) != 100:
        raise SystemExit("expected 100 colors, got %d" % len(rows))
    ids = [row[0] for row in rows]
    labels = [row[1] for row in rows]
    hexes = ["#%02x%02x%02x" % row[2] for row in rows]
    if len(set(ids)) != 100 or len(set(labels)) != 100 or len(set(hexes)) != 100:
        raise SystemExit("ids, names, or hexes are not unique")
    labs = [cie_lab(row[2]) for row in rows]
    closest = 1e9
    for i in range(len(rows)):
        y = luminance(rows[i][2])
        if y >= 0.18 or y <= 0.02:
            raise SystemExit("%s luminance %.3f is outside the dark band" % (rows[i][0], y))
        for j in range(i + 1, len(rows)):
            closest = min(closest, delta(labs[i], labs[j]))
    if closest < 4:
        raise SystemExit("closest colors are only %.2f apart" % closest)


def main():
    rows = build()
    check(rows)
    dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), "colors.tsv")
    lines = [
        "# id\tname\thex",
        "# Dark backdrop colors. Light text stays readable. harness-tint list reads this file.",
    ]
    for cid, label, rgb in rows:
        lines.append("%s\t%s\t#%02x%02x%02x" % (cid, label, rgb[0], rgb[1], rgb[2]))
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("wrote %d colors to %s" % (len(rows), dest))


if __name__ == "__main__":
    main()
