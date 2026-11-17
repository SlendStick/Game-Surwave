# -*- coding: utf-8 -*-
"""Pixel-art generator for Seamless Map Tiles, Obstacles, VFX, and Gothic UI Art."""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, mix, mul

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"


def generate_map_tiles() -> int:
    maps = json.loads((ROOT / "data" / "maps.json").read_text(encoding="utf-8"))
    count = 0
    for idx, m in enumerate(maps):
        mid = m["id"]
        pal = m.get("palette", {})
        bg = c(pal.get("bg", "#141210"))
        bg2 = c(pal.get("bg2", "#201b16"))
        acc = c(pal.get("accent", "#5a5045"))
        obs = c(pal.get("obstacle", "#4a4035"))
        motif = pal.get("motif", "stones")

        rng = random.Random(1000 + idx * 77)
        cv = Canvas(64, 64, bg)

        # Base organic pixel grain (subtle dithered patches, seamless mod 64)
        for _ in range(42):
            px0 = rng.randrange(64)
            py0 = rng.randrange(64)
            rx = rng.randint(2, 6)
            ry = rng.randint(2, 5)
            col = mix(bg, bg2, rng.uniform(0.35, 0.85))
            for dy in range(-ry, ry + 1):
                for dx in range(-rx, rx + 1):
                    if (dx * dx) / (rx * rx + 0.1) + (dy * dy) / (ry * ry + 0.1) <= 1.0:
                        if rng.random() < 0.72:
                            cv.px((px0 + dx) % 64, (py0 + dy) % 64, col)

        if motif == "dunes":
            # Wind-swept sand ripples + small pebbles
            for row in (8, 24, 40, 56):
                for x in range(64):
                    y = (row + int(round(math.sin(x * math.tau / 32.0) * 2.0))) % 64
                    cv.px(x, y, mix(bg2, acc, 0.45))
                    cv.px(x, (y + 1) % 64, mul(bg, 0.82))
            for _ in range(18):
                x, y = rng.randrange(64), rng.randrange(64)
                cv.px(x, y, mix(acc, c("sand"), 0.35))
        elif motif == "ice":
            # Frozen tundra flagstones & frost fissures
            for ty in range(0, 64, 16):
                for tx in range(0, 64, 16):
                    off = 8 if (ty // 16) % 2 else 0
                    x0 = (tx + off) % 64
                    for k in range(16):
                        cv.px((x0 + k) % 64, ty, mul(bg, 0.72))
                        cv.px(x0, (ty + k) % 64, mul(bg, 0.72))
            for _ in range(14):
                x, y = rng.randrange(64), rng.randrange(64)
                for s in range(rng.randint(3, 6)):
                    cv.px((x + s) % 64, (y + s // 2) % 64, mix(acc, c("frost_blue"), 0.45))
        elif motif == "plots":
            # Graveyard cobblestone / mossy flagstones
            for ty in range(0, 64, 16):
                for tx in range(0, 64, 16):
                    off = 8 if (ty // 16) % 2 else 0
                    x0 = (tx + off) % 64
                    for k in range(16):
                        cv.px((x0 + k) % 64, ty, c("black", 180))
                        cv.px(x0, (ty + k) % 64, c("black", 180))
                    cv.px((x0 + 2) % 64, (ty + 2) % 64, mix(bg2, acc, 0.35))
            # Mossy tufts in mortar
            for _ in range(14):
                x, y = rng.randrange(64), rng.randrange(64)
                cv.px(x, y, c("moss_dk"))
                cv.px((x + 1) % 64, y, c("moss"))
        elif motif == "stones":
            # Temple / Chaos / Void gothic flagstones with subtle carved rune cracks
            for ty in range(0, 64, 32):
                for tx in range(0, 64, 32):
                    for k in range(32):
                        cv.px((tx + k) % 64, ty, mul(bg, 0.65))
                        cv.px(tx, (ty + k) % 64, mul(bg, 0.65))
                        cv.px((tx + k) % 64, (ty + 1) % 64, mix(bg2, acc, 0.25))
            for _ in range(18):
                x, y = rng.randrange(64), rng.randrange(64)
                cv.px(x, y, mix(bg2, obs, 0.5))
                cv.px((x + 1) % 64, y, mix(bg2, acc, 0.4))
        elif motif == "tufts":
            # Forest / Rift / Hive dark earth + grass/mycelium tufts
            for _ in range(28):
                x, y = rng.randrange(64), rng.randrange(64)
                col = mix(obs, acc, 0.5)
                cv.px(x, y, col)
                cv.px((x - 1) % 64, (y - 1) % 64, col)
                cv.px((x + 1) % 64, (y - 1) % 64, mul(col, 1.2))
        else:  # cracks
            # Volcanic / Bloodmoon / Throne / Abyss cracked earth
            for _ in range(10):
                x, y = rng.randrange(64), rng.randrange(64)
                for _step in range(rng.randint(5, 11)):
                    cv.px(x % 64, y % 64, mul(bg, 0.55))
                    cv.px((x + 1) % 64, y % 64, mix(bg2, acc, 0.35))
                    x += rng.choice((-1, 0, 1, 1))
                    y += rng.choice((-1, 0, 1))

        # Sparse micro-pebbles (never noisy!)
        for _ in range(16):
            x, y = rng.randrange(64), rng.randrange(64)
            cv.px(x, y, mix(bg2, acc, 0.5))

        cv.save(OUT / f"tile_{mid}.png")
        count += 1
    return count


def _draw_obstacle(shape: str) -> Canvas:
    if shape in ("water", "lava", "swamp", "ice", "ash", "cliff"):
        cv = Canvas(48, 48)
        cx, cy = 24, 24
        if shape == "water":
            cv.ellipse(cx, cy, 20, 14, c("deep_water"))
            cv.ellipse(cx, cy - 1, 17, 11, c("water"))
            cv.line(13, 21, 22, 21, c("water_lt"))
            cv.line(21, 26, 33, 26, c("ice_lt"))
            cv.outline(c("night"))
        elif shape == "lava":
            cv.ellipse(cx, cy, 20, 14, c("maroon"))
            cv.ellipse(cx, cy, 16, 11, c("crimson"))
            cv.ellipse(cx - 2, cy - 1, 10, 6, c("lava"))
            cv.ellipse(cx - 3, cy - 1, 5, 3, c("amber"))
            cv.outline(c("black"))
        elif shape == "swamp":
            cv.ellipse(cx, cy, 20, 13, c("swamp_vd"))
            cv.ellipse(cx, cy, 16, 10, c("swamp_dk"))
            cv.ellipse(cx - 5, cy - 2, 4, 3, c("moss"))
            cv.px(cx + 6, cy + 2, c("glow_green"))
            cv.px(cx - 8, cy + 1, c("poison"))
            cv.outline(c("black"))
        elif shape == "ice":
            cv.poly([(10, 32), (16, 12), (24, 6), (34, 15), (38, 34), (24, 40)], c("ice_blue"))
            cv.poly([(16, 12), (24, 6), (26, 26), (14, 28)], c("frost_blue"))
            cv.line(22, 9, 22, 24, c("snow_lt"))
            cv.outline(c("night"))
        elif shape == "ash":
            cv.ellipse(cx, cy + 3, 18, 10, c("slate_vd"))
            cv.ellipse(cx, cy + 1, 13, 7, c("slate"))
            cv.px(20, 22, c("lava"))
            cv.px(28, 25, c("ember_red"))
            cv.outline(c("black"))
        else:  # cliff
            cv.poly([(6, 38), (10, 14), (24, 8), (38, 16), (42, 38)], c("stone_dk"))
            cv.poly([(10, 14), (24, 8), (24, 34), (8, 36)], c("stone"))
            cv.line(12, 16, 24, 10, c("stone_lt"))
            cv.outline(c("black"))
        return cv

    cv = Canvas(32, 32)
    cx = 16
    cv.add_ground_shadow(cx, 28, 10, 3.0, 90)
    if shape == "tree":
        cv.rect(cx - 3, 18, 6, 10, c("soil_dark"))
        cv.line(cx - 1, 19, cx - 1, 27, c("leather"))
        # Twisted dead/gothic pine canopy
        cv.poly([(cx - 12, 20), (cx, 3), (cx + 12, 20)], c("swamp_dk"))
        cv.poly([(cx - 9, 15), (cx, 2), (cx + 9, 15)], c("moss_dk"))
        cv.poly([(cx - 6, 10), (cx, 2), (cx + 5, 10)], c("moss"))
    elif shape == "bush":
        cv.ellipse(cx, 19, 10, 7, c("swamp_dk"))
        cv.ellipse(cx - 4, 17, 6, 5, c("moss_dk"))
        cv.ellipse(cx + 4, 18, 5, 4, c("moss"))
        cv.px(cx - 2, 15, c("crimson"))
        cv.px(cx + 4, 17, c("crimson"))
    elif shape == "flower":
        cv.line(cx, 25, cx, 14, c("moss"), 2)
        cv.ellipse(cx - 3, 21, 3, 1.5, c("moss_dk"))
        cv.ellipse(cx, 12, 5, 5, c("crimson"))
        cv.ellipse(cx, 12, 2, 2, c("gold_glow"))
    elif shape == "mushroom":
        cv.rect(cx - 3, 17, 6, 10, c("parchment"))
        cv.ellipse(cx, 14, 10, 6, c("crimson_dk"))
        cv.ellipse(cx, 13, 8, 4, c("crimson"))
        cv.px(cx - 4, 12, c("cream"))
        cv.px(cx + 3, 11, c("cream"))
        cv.px(cx, 14, c("cream"))
    elif shape == "cactus":
        cv.rect(cx - 3, 7, 6, 20, c("moss_dk"))
        cv.rect(cx - 2, 8, 3, 18, c("moss"))
        cv.rect(cx - 9, 12, 6, 3, c("moss_dk"))
        cv.rect(cx - 9, 8, 3, 5, c("moss"))
        cv.rect(cx + 3, 15, 6, 3, c("moss_dk"))
        cv.rect(cx + 6, 11, 3, 5, c("moss"))
        cv.px(cx - 3, 10, c("parchment"))
        cv.px(cx + 3, 13, c("parchment"))
    elif shape == "rock":
        cv.poly([(6, 25), (9, 14), (17, 10), (25, 15), (27, 25)], c("stone_dk"))
        cv.poly([(9, 14), (17, 10), (19, 22), (8, 24)], c("stone"))
        cv.line(10, 14, 17, 11, c("stone_lt"))
    elif shape == "bone":
        cv.ellipse(cx, 18, 6, 5, c("bone"))
        cv.rect(cx - 4, 21, 8, 4, c("parchment"))
        cv.px(cx - 2, 18, c("black"))
        cv.px(cx + 2, 18, c("black"))
        cv.line(5, 25, 26, 22, c("bone"), 2)
    elif shape == "crystal":
        cv.poly([(11, 26), (9, 14), (15, 5), (21, 14), (20, 26)], c("arcane"))
        cv.poly([(12, 25), (11, 14), (15, 6), (17, 25)], c("violet_lt"))
        cv.line(14, 8, 14, 18, c("ghost_violet"))
    elif shape == "pillar":
        cv.rect(9, 22, 14, 5, c("stone_dk"))
        cv.rect(11, 8, 10, 15, c("stone"))
        cv.line(13, 9, 13, 22, c("stone_lt"))
        cv.rect(9, 5, 14, 4, c("stone_lt"))
        cv.px(16, 14, c("gold"))
    elif shape == "grave":
        cv.rect(8, 23, 16, 4, c("soil_dark"))
        cv.rect(10, 10, 12, 14, c("stone_dk"))
        cv.ellipse(16, 10, 6, 4, c("stone"))
        cv.line(16, 11, 16, 18, c("black"))
        cv.line(13, 13, 19, 13, c("black"))
    elif shape == "cross":
        cv.rect(14, 6, 4, 21, c("soil"))
        cv.rect(8, 11, 16, 4, c("leather"))
        cv.line(15, 7, 15, 25, c("leather_lt"))
    elif shape == "pumpkin":
        cv.ellipse(cx, 20, 9, 7, c("lava"))
        cv.ellipse(cx, 20, 5, 7, c("flame"))
        cv.rect(cx - 1, 11, 2, 3, c("moss"))
        cv.px(cx - 3, 18, c("gold_glow"))
        cv.px(cx + 3, 18, c("gold_glow"))
        cv.line(cx - 3, 22, cx + 3, 22, c("gold_glow"))
    elif shape == "reeds":
        for rx, h in [(10, 10), (15, 7), (20, 11), (24, 13)]:
            cv.line(rx, 26, rx, h, c("moss"))
            cv.rect(rx - 1, h, 3, 4, c("leather"))
    elif shape == "stalagmite":
        cv.poly([(8, 26), (13, 9), (16, 4), (20, 11), (24, 26)], c("slate_dk"))
        cv.poly([(10, 26), (14, 10), (16, 5), (17, 26)], c("stone"))
    elif shape == "scrap":
        cv.rect(7, 17, 16, 9, c("iron_dk"))
        cv.line(6, 24, 25, 14, c("bronze"), 2)
        cv.ring(19, 19, 4.5, 2.5, c("iron"))
    else:  # obelisk
        cv.rect(9, 23, 14, 4, c("slate_dk"))
        cv.poly([(11, 23), (13, 6), (16, 3), (19, 6), (21, 23)], c("slate"))
        cv.line(16, 8, 16, 19, c("violet_lt"))
        cv.px(16, 12, c("ghost_violet"))
    cv.outline(c("black"))
    return cv


def generate_obstacles() -> int:
    shapes = [
        "tree", "bush", "flower", "mushroom", "cactus", "rock", "bone", "water",
        "crystal", "pillar", "grave", "cross", "pumpkin", "reeds", "lava", "swamp",
        "ice", "ash", "stalagmite", "scrap", "cliff", "obelisk",
    ]
    for sh in shapes:
        _draw_obstacle(sh).save(OUT / f"obs_{sh}.png")
    return len(shapes)


def generate_ui_and_fx() -> int:
    count = 0

    # ring.png (player foot ring)
    cv = Canvas(32, 32)
    cv.ring(16, 16, 14, 12.2, c("gold_lt", 210))
    cv.save(OUT / "ring.png")
    count += 1

    # elite.png (ornate gothic rune aura for elites)
    cv = Canvas(32, 32)
    cv.ring(16, 16, 14.5, 12.5, c("amber", 210))
    for ang in (0, 90, 180, 270):
        rad = math.radians(ang)
        x, y = int(16 + math.cos(rad) * 13.5), int(16 + math.sin(rad) * 13.5)
        cv.rect(x - 1, y - 1, 3, 3, c("gold_glow"))
    cv.save(OUT / "elite.png")
    count += 1

    # fx_burst.png & fx_ring.png
    cv = Canvas(16, 16)
    cv.ellipse(8, 8, 6, 6, c("white", 180))
    cv.ellipse(8, 8, 3, 3, c("white", 255))
    cv.save(OUT / "fx_burst.png")
    count += 1

    cv = Canvas(32, 32)
    cv.ring(16, 16, 14, 11.5, c("white", 220))
    cv.save(OUT / "fx_ring.png")
    count += 1

    # ui_heart_full.png & ui_heart_empty.png (16x16)
    for full in (True, False):
        cv = Canvas(16, 16)
        col = c("crimson") if full else c("slate_vd")
        hi = c("scarlet") if full else c("slate_dk")
        cv.ellipse(5.5, 6, 3.3, 3.0, col)
        cv.ellipse(10.5, 6, 3.3, 3.0, col)
        cv.poly([(3, 7), (13, 7), (8, 13)], col)
        cv.px(5, 5, hi)
        if full:
            cv.px(4, 5, c("cream"))
        cv.outline(c("black"))
        cv.save(OUT / ("ui_heart_full.png" if full else "ui_heart_empty.png"))
        count += 1

    # ui_ammo.png (12x16 gothic silver/gold cartridge)
    cv = Canvas(12, 16)
    cv.rect(4, 5, 4, 8, c("gold"))
    cv.line(5, 6, 5, 12, c("gold_lt"))
    cv.poly([(4, 5), (6, 1), (8, 5)], c("frost"))
    cv.rect(3, 13, 6, 2, c("bronze"))
    cv.outline(c("black"))
    cv.save(OUT / "ui_ammo.png")
    count += 1

    # ui_skill_ready.png (20x20 gothic rune crest)
    cv = Canvas(20, 20)
    cv.ring(10, 10, 8.5, 6.5, c("bronze"))
    cv.poly([(10, 4), (15, 10), (10, 16), (5, 10)], c("ice_blue"))
    cv.poly([(10, 6), (13, 10), (10, 14), (7, 10)], c("ice_glow"))
    cv.px(10, 10, c("white"))
    cv.outline(c("black"))
    cv.save(OUT / "ui_skill_ready.png")
    count += 1

    # ui_crest.png (64x64 gothic crossed swords + winged skull emblem)
    cv = Canvas(64, 64)
    # Crossed swords
    cv.line(10, 52, 52, 10, c("frost"), 3)
    cv.line(54, 52, 12, 10, c("frost"), 3)
    cv.line(10, 44, 18, 52, c("gold"), 2)
    cv.line(54, 44, 46, 52, c("gold"), 2)
    # Winged shield & skull
    cv.poly([(18, 18), (46, 18), (44, 42), (32, 54), (20, 42)], c("maroon"))
    cv.box_outline(19, 19, 26, 24, c("gold"))
    cv.rect(25, 22, 14, 12, c("parchment"))
    cv.rect(27, 34, 10, 5, c("bone"))
    cv.rect(27, 26, 3, 3, c("black"))
    cv.rect(34, 26, 3, 3, c("black"))
    cv.px(28, 27, c("ember_red"))
    cv.px(35, 27, c("ember_red"))
    cv.outline(c("black"))
    cv.save(OUT / "ui_crest.png")
    count += 1

    # ui_title_bg.png (320x180 gothic ruined citadel & blood moon pixel art)
    w, h = 320, 180
    bg = Canvas(w, h)
    # Night sky gradient (banded pixel dithering!)
    sky_top = c("void")
    sky_mid = c("night")
    sky_hor = c("blood_vd")
    for y in range(h):
        t = y / float(h)
        if t < 0.55:
            col = mix(sky_top, sky_mid, t / 0.55)
        else:
            col = mix(sky_mid, sky_hor, (t - 0.55) / 0.45)
        for x in range(w):
            # Subtle Bayer-like dither
            d = 1.03 if ((x + y) % 2 == 0) else 0.97
            bg.px(x, y, mul(col, d))

    # Stars
    rng = random.Random(4242)
    for _ in range(70):
        sx, sy = rng.randrange(w), rng.randrange(105)
        bg.px(sx, sy, c("frost_dk") if rng.random() < 0.7 else c("parchment"))

    # Giant Blood Moon (top right) + moonlit cloud wisps
    mx, my = 242, 46
    bg.ellipse(mx, my, 27, 27, c("maroon", 110), True)
    bg.ellipse(mx, my, 23, 23, c("blood_dk"))
    bg.ellipse(mx, my, 20, 20, c("crimson"))
    bg.ellipse(mx - 2, my - 2, 16, 16, c("blood"))
    for cx0, cy0, r0 in [(mx - 6, my - 4, 4), (mx + 5, my + 3, 5), (mx + 2, my - 8, 3)]:
        bg.ellipse(cx0, cy0, r0, r0, c("crimson_dk"))
    for cloud_x, cloud_y, cw in [(180, 34, 34), (255, 62, 40), (110, 48, 30)]:
        bg.ellipse(cloud_x, cloud_y, cw, 5, c("slate_vd", 140), True)
        bg.ellipse(cloud_x + 8, cloud_y + 2, cw - 8, 3, c("night", 150), True)

    # Distant jagged mountains
    pts = [(0, 136)]
    for x in range(0, w + 16, 12):
        pts.append((x, 108 + int(math.sin(x * 0.045) * 14) + rng.randint(-5, 6)))
    pts.append((w, 136))
    bg.poly(pts, c("slate_vd"))

    # Ruined Gothic Cathedral / Citadel Silhouette on hill (left-center)
    bg.rect(34, 66, 48, 72, c("black"))
    bg.poly([(32, 66), (58, 34), (84, 66)], c("black"))  # main spire
    bg.rect(57, 22, 2, 14, c("black"))
    bg.rect(53, 26, 10, 2, c("black"))  # gothic cross
    # Flying buttresses & battlements
    bg.poly([(14, 136), (22, 96), (34, 96), (34, 136)], c("black"))
    bg.poly([(102, 136), (94, 96), (82, 96), (82, 136)], c("black"))
    for bx in range(36, 80, 6):
        bg.rect(bx, 63, 3, 4, c("black"))
    # Flanking towers
    bg.rect(20, 82, 16, 56, c("black"))
    bg.poly([(18, 82), (28, 62), (38, 82)], c("black"))
    bg.rect(80, 76, 18, 62, c("black"))
    bg.poly([(78, 76), (89, 54), (100, 76)], c("black"))
    # Rose window & glowing amber cathedral lancet windows
    bg.ring(58, 69, 6.0, 4.0, c("crimson"))
    bg.ellipse(58, 69, 3.0, 3.0, c("amber"))
    for wx in (44, 56, 68):
        bg.rect(wx, 84, 4, 13, c("lava"))
        bg.rect(wx + 1, 86, 2, 9, c("gold_glow"))
    bg.rect(26, 94, 4, 9, c("amber"))
    bg.rect(87, 90, 4, 9, c("amber"))
    # Arched cathedral gate + torch braziers
    bg.rect(52, 114, 12, 22, c("void"))
    bg.ellipse(58, 114, 6, 5, c("void"))
    for tx in (47, 68):
        bg.rect(tx, 126, 2, 8, c("iron_dk"))
        bg.ellipse(tx + 1, 124, 2.5, 2.5, c("flame"))
        bg.px(tx + 1, 123, c("gold_glow"))

    # Foreground dead pines, crypt graves & mist ground
    bg.rect(0, 134, w, 46, c("void"))
    for tx in range(6, w, 22):
        th = rng.randint(18, 34)
        bg.poly([(tx - 7, 136), (tx, 136 - th), (tx + 7, 136)], c("black"))
    for gx in (135, 165, 215, 275):
        bg.rect(gx, 132, 3, 9, c("slate_vd"))
        bg.rect(gx - 2, 134, 7, 2, c("slate_vd"))
    # Subtle stone road + ground fog line
    for y in range(138, 180, 10):
        for x in range(0, w, 18):
            bg.rect(x + (y % 4), y, 15, 7, c("dark_brown"))
    for y in range(129, 143):
        alpha = 68 - abs(y - 135) * 8
        if alpha > 0:
            bg.rect(0, y, w, 1, c("crimson_dk", alpha), True)

    bg.save(OUT / "ui_title_bg.png")
    count += 1

    count += _generate_event_and_vfx_sprites()
    return count


def _generate_event_and_vfx_sprites() -> int:
    count = 0

    # 1. Mover: Tumbleweed (32x32 woven thorny desert bush)
    tw = Canvas(32, 32)
    tw.ellipse(16, 16, 12.5, 12.0, c("soil_dark"))
    tw.ellipse(16, 16, 10.5, 10.0, c("leather"))
    rng = random.Random(31415)
    for _ in range(26):
        a1 = rng.uniform(0, math.tau)
        a2 = a1 + rng.uniform(0.9, 2.3)
        r1 = rng.uniform(4.0, 11.0)
        r2 = rng.uniform(4.0, 11.0)
        col = c("sand_dk") if rng.random() < 0.45 else (c("leather_lt") if rng.random() < 0.6 else c("soil_dark"))
        tw.line(int(16 + math.cos(a1) * r1), int(16 + math.sin(a1) * r1),
                int(16 + math.cos(a2) * r2), int(16 + math.sin(a2) * r2), col)
    # Outer thorny twigs poking out
    for i in range(10):
        ang = i * math.tau / 10.0 + 0.2
        tw.line(int(16 + math.cos(ang) * 9), int(16 + math.sin(ang) * 9),
                int(16 + math.cos(ang) * 14), int(16 + math.sin(ang) * 14), c("sand_dk"))
    tw.ellipse(13, 12, 4, 3, (c("sand_lt")[0], c("sand_lt")[1], c("sand_lt")[2], 95), True)
    tw.outline(c("black"))
    tw.save(OUT / "mover_tumbleweed.png")
    count += 1

    # Mover: Wisp, Insects, Shard
    wp = Canvas(24, 24)
    wp.ellipse(12, 12, 9, 9, (c("glow_green")[0], c("glow_green")[1], c("glow_green")[2], 70), True)
    wp.ellipse(12, 12, 5, 5, c("pale_green"))
    wp.ellipse(12, 11, 2.5, 2.5, c("white"))
    wp.save(OUT / "mover_wisp.png")
    count += 1

    ins = Canvas(32, 32)
    irng = random.Random(7711)
    for _ in range(18):
        ix = irng.randint(5, 26)
        iy = irng.randint(5, 26)
        ins.rect(ix, iy, 2, 2, c("black"))
        ins.px(ix + 1, iy - 1, c("parchment"))
    ins.save(OUT / "mover_insects.png")
    count += 1

    sh = Canvas(24, 24)
    sh.poly([(12, 2), (20, 14), (12, 22), (4, 14)], c("ice_blue"))
    sh.poly([(12, 4), (16, 13), (12, 20)], c("snow_lt"))
    sh.outline(c("night"))
    sh.save(OUT / "mover_shard.png")
    count += 1

    # 2. WorldBox-style Falling Meteor (4 frames 32x32) + Scorched Crater (48x48)
    for f in range(4):
        mt = Canvas(32, 32)
        # Flaming diagonal tail up-left -> boulder at bottom-right (20, 21)
        mt.poly([(2, 2 + f), (14, 10), (24, 18), (16, 26), (8, 16)], c("crimson"))
        mt.poly([(5, 4 + (f % 2)), (18, 14), (20, 22), (12, 18)], c("lava"))
        mt.poly([(9, 8), (18, 17), (15, 20)], c("gold_glow"))
        mt.ellipse(21, 22, 6, 6, c("stone_dk"))
        mt.ellipse(20, 21, 4.5, 4.5, c("maroon"))
        mt.px(19, 20, c("gold_glow"))
        mt.px(22, 23, c("ember_red"))
        mt.outline(c("black"))
        mt.save(OUT / f"event_meteor_{f}.png")
        count += 1

    cr = Canvas(48, 48)
    cr.ellipse(24, 24, 18, 13, (c("black")[0], c("black")[1], c("black")[2], 140), True)
    cr.ellipse(24, 24, 13, 9, c("slate_vd"))
    cr.ellipse(24, 24, 7, 5, c("maroon"))
    cr.ellipse(24, 24, 3, 2, c("lava"))
    cr.save(OUT / "event_crater.png")
    count += 1

    # 3. Rockfall Boulders & Stalactites
    for f in range(2):
        bl = Canvas(32, 32)
        bl.poly([(7 + f, 24), (6, 12), (15, 5), (25, 11), (26 - f, 24), (16, 27)], c("stone_dk"))
        bl.poly([(8, 12), (15, 6), (20, 16), (10, 21)], c("stone"))
        bl.line(10, 11, 15, 7, c("stone_lt"))
        bl.outline(c("black"))
        bl.save(OUT / f"event_boulder_{f}.png")
        count += 1

    st = Canvas(24, 32)
    st.poly([(6, 2), (18, 2), (14, 20), (12, 30), (10, 20)], c("stone_dk"))
    st.poly([(8, 3), (12, 3), (12, 28), (10, 19)], c("stone"))
    st.line(9, 4, 11, 24, c("stone_lt"))
    st.outline(c("black"))
    st.save(OUT / "event_stalactite.png")
    count += 1

    # 4. Ice Spikes (3 eruption frames) & Avalanche Wave
    for f in range(3):
        sp = Canvas(32, 32)
        h_s = 8 + f * 9
        sp.poly([(9, 29), (16, 29 - h_s), (23, 29)], c("ice_blue"))
        sp.poly([(11, 29), (16, 30 - h_s), (17, 29)], c("snow_lt"))
        if f >= 1:
            sp.poly([(4, 29), (9, 29 - h_s // 2), (13, 29)], c("frost_blue"))
            sp.poly([(19, 29), (24, 29 - h_s // 2), (28, 29)], c("frost_blue"))
        sp.outline(c("night"))
        sp.save(OUT / f"event_ice_spike_{f}.png")
        count += 1

    av = Canvas(64, 32)
    av.ellipse(32, 20, 29, 10, c("frost_dk"))
    av.ellipse(32, 16, 27, 9, c("snow_dk"))
    for bx in range(8, 57, 8):
        av.ellipse(bx, 13 + (bx % 3), 6, 5, c("snow_lt"))
    av.outline(c("slate"))
    av.save(OUT / "event_avalanche_wave.png")
    count += 1

    # 5. Poison Geyser & Ghost Hands (3 frames each)
    for f in range(3):
        gy = Canvas(32, 32)
        h_g = 7 + f * 9
        gy.ellipse(16, 27, 10, 4, c("swamp_dk"))
        gy.rect(12, 27 - h_g, 8, h_g, c("moss"))
        gy.rect(14, 27 - h_g, 4, h_g, c("glow_green"))
        gy.ellipse(16, 27 - h_g, 6 + f * 2, 3, c("pale_green"))
        gy.outline(c("black"))
        gy.save(OUT / f"event_geyser_{f}.png")
        count += 1

        gh = Canvas(32, 32)
        rise = 6 + f * 7
        gh.ellipse(16, 28, 9, 3, c("arcane_vd"))
        gh.rect(13, 28 - rise, 6, rise, c("bone"))
        for fx_off in (-4, -1, 2, 5):
            gh.line(16 + fx_off // 2, 28 - rise, 16 + fx_off, max(2, 22 - rise), c("parchment"))
        gh.outline(c("black"))
        gh.save(OUT / f"event_ghost_hand_{f}.png")
        count += 1

    # 6. Perk VFX: Lightning Strike (32x64, 4 frames), Fireball Blast (40x40, 4 frames), Heavenly Smite (32x64, 4 frames), Frost Burst (32x32, 3 frames)
    for f in range(4):
        lt = Canvas(32, 64)
        thick = 3 if f in (0, 1) else (2 if f == 2 else 1)
        col = c("white") if f == 1 else c("ice_glow")
        pts = [(16, 0), (11 + (f % 2) * 2, 16), (20 - (f % 2) * 2, 32), (13, 46), (16, 60)]
        for i in range(len(pts) - 1):
            lt.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], c("ice_blue"), thick + 2)
            lt.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], col, thick)
        if f in (1, 2):
            lt.line(11, 16, 4, 28, c("ice_glow"), 1)
            lt.line(20, 32, 28, 44, c("ice_glow"), 1)
        lt.ellipse(16, 59, 6 + f * 3, 3, (c("ice_glow")[0], c("ice_glow")[1], c("ice_glow")[2], 180 - f * 35), True)
        lt.save(OUT / f"vfx_lightning_{f}.png")
        count += 1

        fb = Canvas(40, 40)
        rad = 6 + f * 4
        fb.ellipse(20, 20, rad + 2, rad + 2, (c("crimson")[0], c("crimson")[1], c("crimson")[2], 210 - f * 35), True)
        fb.ellipse(20, 20, rad, rad, (c("lava")[0], c("lava")[1], c("lava")[2], 220 - f * 35), True)
        if f < 3:
            fb.ellipse(20, 20, max(2, rad - 4), max(2, rad - 4), c("gold_glow"))
        if f == 0:
            fb.ellipse(20, 20, 3, 3, c("white"))
        for k in range(8):
            a = k * math.tau / 8.0 + f * 0.4
            fb.rect(int(20 + math.cos(a) * (rad + 2)), int(20 + math.sin(a) * (rad + 2)), 2, 2, c("gold_glow"))
        fb.save(OUT / f"vfx_fireball_{f}.png")
        count += 1

        sm = Canvas(32, 64)
        bw = 10 - f * 2
        sm.rect(16 - bw, 0, bw * 2, 60, (c("gold")[0], c("gold")[1], c("gold")[2], 170 - f * 35), True)
        sm.rect(16 - max(1, bw // 2), 0, max(2, bw), 60, (c("white")[0], c("white")[1], c("white")[2], 220 - f * 45), True)
        if f in (0, 1):
            sm.line(16, 40, 16, 62, c("white"), 2)
            sm.line(6, 50, 26, 50, c("white"), 2)
        sm.ellipse(16, 58, 7 + f * 3, 4, (c("gold_glow")[0], c("gold_glow")[1], c("gold_glow")[2], 190 - f * 40), True)
        sm.save(OUT / f"vfx_smite_{f}.png")
        count += 1

    for f in range(3):
        fr = Canvas(32, 32)
        r = 5 + f * 5
        for ang in range(0, 360, 45):
            rad_a = math.radians(ang)
            fr.line(16, 16, int(16 + math.cos(rad_a) * r), int(16 + math.sin(rad_a) * r), c("ice_glow"), 2 if f == 0 else 1)
        fr.ring(16, 16, r, max(1, r - 2), c("snow_lt"))
        fr.save(OUT / f"vfx_frost_{f}.png")
        count += 1

    return count



def run() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    return generate_map_tiles() + generate_obstacles() + generate_ui_and_fx()
