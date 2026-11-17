# -*- coding: utf-8 -*-
"""Generates HD pixel-art character portraits (96x96) and the game icon (128x128)."""

from __future__ import annotations

import math
from pathlib import Path

from pixel_art_lib import Canvas, Color, PAL, c, mix, mul, save_png

ROOT = Path(__file__).resolve().parent.parent
SPRITE_DIR = ROOT / "assets" / "sprites"

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def _dither(cv: Canvas, x: int, y: int, c1: Color, c2: Color, t: float) -> Color:
    b = (BAYER4[y & 3][x & 3] + 0.5) / 16.0
    return c2 if t > b else c1


def _draw_backdrop(cv: Canvas, accent: Color, dark_bg: Color, rune_kind: str) -> None:
    w, h = cv.w, cv.h
    cx, cy = w * 0.5, h * 0.44
    for y in range(h):
        for x in range(w):
            dist = math.hypot((x - cx) / (w * 0.55), (y - cy) / (h * 0.55))
            t = max(0.0, min(1.0, 1.0 - dist))
            col = _dither(cv, x, y, c("void"), mix(dark_bg, accent, 0.28), t * 0.85)
            # Subtle gothic vertical stone rib texture in upper corners
            if abs(x - cx) > w * 0.30 and (x % 7 == 0):
                col = mul(col, 0.86)
            cv.px(x, y, col)
    # Halo / arcane circle behind head
    cv.ring(cx, cy - 4, 30, 28, mix(dark_bg, accent, 0.55))
    cv.ring(cx, cy - 4, 24, 23, mix(dark_bg, accent, 0.35))
    if rune_kind == "points":
        for i in range(8):
            ang = i * math.tau / 8.0
            rx = int(round(cx + math.cos(ang) * 29))
            ry = int(round(cy - 4 + math.sin(ang) * 29))
            cv.rect(rx - 1, ry - 1, 2, 2, accent)
    elif rune_kind == "rays":
        for i in range(12):
            ang = i * math.tau / 12.0
            cv.line(
                int(cx + math.cos(ang) * 24),
                int(cy - 4 + math.sin(ang) * 24),
                int(cx + math.cos(ang) * 33),
                int(cy - 4 + math.sin(ang) * 33),
                mix(accent, c("gold_lt"), 0.3),
            )
    elif rune_kind == "sigil":
        for i in range(6):
            a1 = i * math.tau / 6.0
            a2 = ((i + 2) % 6) * math.tau / 6.0
            cv.line(
                int(cx + math.cos(a1) * 26),
                int(cy - 4 + math.sin(a1) * 26),
                int(cx + math.cos(a2) * 26),
                int(cy - 4 + math.sin(a2) * 26),
                mix(dark_bg, accent, 0.45),
            )


def _shade_bust(cv: Canvas, torso_col: Color, trim_col: Color, collar_col: Color, wide: int = 0) -> None:
    """Draws detailed gothic shoulders, cloak/armor folds, and collar."""
    cx = 48
    sh_dark = mul(torso_col, 0.48)
    sh_mid = torso_col
    sh_hi = mix(torso_col, c("cream"), 0.24)
    # Main torso & shoulders silhouette
    pts = [
        (cx - 32 - wide, 95),
        (cx - 29 - wide, 68),
        (cx - 17, 56),
        (cx + 17, 56),
        (cx + 29 + wide, 68),
        (cx + 32 + wide, 95),
    ]
    cv.poly(pts, sh_dark)
    # Shaded inner cloak/chest planes with directional lighting (left lit, right shadowed)
    for y in range(57, 96):
        t_y = (y - 57) / 39.0
        half_w = int(17 + (15 + wide) * min(1.0, t_y * 1.45))
        for x in range(cx - half_w, cx + half_w + 1):
            if cv.get(x, y)[3] == 0:
                continue
            rel = (x - cx) / max(1, half_w)
            fold = math.sin((x - cx) * 0.35 + y * 0.08) * 0.12
            light = max(0.0, min(1.0, 0.58 - rel * 0.48 + fold))
            col = _dither(cv, x, y, sh_dark, sh_mid, light * 1.3)
            if light > 0.68:
                col = _dither(cv, x, y, sh_mid, sh_hi, (light - 0.68) * 2.8)
            cv.px(x, y, col)
    # Pauldrons / shoulder plates
    for side in (-1, 1):
        px = cx + side * (22 + wide // 2)
        cv.ellipse(px, 67, 11 + wide // 2, 7, mul(trim_col, 0.55))
        cv.ellipse(px - side * 1, 66, 9 + wide // 2, 5, trim_col)
        cv.line(px - 7, 63, px + 7, 63, mix(trim_col, c("cream"), 0.45))
    # Chest trim V-placket
    cv.line(cx - 11, 57, cx, 78, trim_col, 2)
    cv.line(cx + 11, 57, cx, 78, mul(trim_col, 0.72), 2)
    cv.line(cx, 78, cx, 95, trim_col, 2)
    # Collar
    cv.ellipse(cx, 56, 13, 5, mul(collar_col, 0.6))
    cv.ellipse(cx, 55, 11, 4, collar_col)


def _draw_face(
    cv: Canvas,
    skin: Color,
    eye_col: Color,
    *,
    shadowed: bool = False,
    scar: bool = False,
    beard: Color | None = None,
    mask: Color | None = None,
    visor: bool = False,
) -> None:
    cx, cy = 48, 39
    skin_dk = mul(skin, 0.62)
    skin_lt = mix(skin, c("cream"), 0.22)
    # Neck
    cv.rect(cx - 6, 48, 12, 10, skin_dk)
    cv.rect(cx - 4, 48, 6, 9, skin)
    if visor:
        return
    # Head base
    cv.ellipse(cx, cy, 11, 13, skin_dk)
    cv.ellipse(cx - 1, cy - 1, 9.5, 11.5, skin)
    cv.ellipse(cx - 3, cy - 4, 5, 6, skin_lt)
    if shadowed:
        # Upper brow cast shadow from hood
        cv.poly([(cx - 12, 26), (cx + 12, 26), (cx + 11, 38), (cx, 41), (cx - 11, 38)], c("void"))
        cv.rect(cx - 9, 38, 18, 3, mix(c("void"), skin_dk, 0.5))
    # Nose bridge & brow
    if not shadowed:
        cv.line(cx - 6, 35, cx - 2, 36, skin_dk)
        cv.line(cx + 2, 36, cx + 6, 35, skin_dk)
    cv.line(cx, 36, cx, 43, skin_dk)
    cv.px(cx - 1, 42, skin_lt)
    # Mouth
    if mask is None:
        cv.line(cx - 3, 46, cx + 3, 46, mul(skin_dk, 0.72))
    # Scar
    if scar:
        cv.line(cx + 2, 33, cx + 7, 45, c("crimson"))
        cv.line(cx + 3, 33, cx + 8, 45, c("sand_lt"))
    # Beard
    if beard is not None:
        cv.poly([(cx - 10, 44), (cx + 10, 44), (cx + 7, 56), (cx, 59), (cx - 7, 56)], mul(beard, 0.7))
        cv.poly([(cx - 8, 45), (cx + 8, 45), (cx + 5, 54), (cx, 56), (cx - 5, 54)], beard)
    # Face mask
    if mask is not None:
        cv.poly([(cx - 11, 40), (cx + 11, 40), (cx + 10, 52), (cx, 55), (cx - 10, 52)], mul(mask, 0.65))
        cv.poly([(cx - 10, 41), (cx + 9, 41), (cx + 8, 50), (cx, 52), (cx - 9, 50)], mask)
        cv.line(cx - 9, 41, cx + 9, 41, mix(mask, c("frost"), 0.3))
    # Eyes (glowing & crisp)
    for sx in (-4, 4):
        cv.rect(cx + sx - 2, 37, 4, 2, c("black"))
        cv.rect(cx + sx - 1, 37, 2, 2, eye_col)
        cv.px(cx + sx - 1, 37, mix(eye_col, c("white"), 0.55))


def _draw_hood(cv: Canvas, hood_col: Color, trim_col: Color, tall: int = 0) -> None:
    cx = 48
    dk = mul(hood_col, 0.52)
    lt = mix(hood_col, c("cream"), 0.25)
    pts = [
        (cx - 18, 56),
        (cx - 19, 34),
        (cx - 11, 20 - tall),
        (cx, 15 - tall),
        (cx + 11, 20 - tall),
        (cx + 19, 34),
        (cx + 18, 56),
        (cx + 11, 52),
        (cx + 11, 33),
        (cx, 27),
        (cx - 11, 33),
        (cx - 11, 52),
    ]
    cv.poly(pts, dk)
    cv.poly([(cx - 15, 36), (cx - 9, 22 - tall), (cx, 17 - tall), (cx + 7, 22 - tall), (cx, 26), (cx - 11, 33)], hood_col)
    cv.line(cx - 12, 32, cx, 26, trim_col)
    cv.line(cx + 12, 32, cx, 26, mul(trim_col, 0.7))
    cv.line(cx - 10, 21 - tall, cx, 16 - tall, lt)


def _draw_magic_orb(cv: Canvas, x: int, y: int, core: Color, glow: Color, r: int = 7) -> None:
    cv.ellipse(x, y, r + 4, r + 4, (glow[0], glow[1], glow[2], 70), blend=True)
    cv.ellipse(x, y, r + 2, r + 2, (glow[0], glow[1], glow[2], 130), blend=True)
    cv.ellipse(x, y, r, r, glow)
    cv.ellipse(x - 1, y - 1, max(2, r - 2), max(2, r - 2), core)
    cv.px(x - 2, y - 2, c("white"))


def _frame_portrait(cv: Canvas, accent: Color) -> None:
    w, h = cv.w, cv.h
    cv.box_outline(0, 0, w, h, c("black"))
    cv.box_outline(1, 1, w - 2, h - 2, mul(accent, 0.55))
    cv.line(1, 1, w - 2, 1, mix(accent, c("gold_lt"), 0.35))
    cv.line(1, 1, 1, h - 2, mix(accent, c("gold_lt"), 0.35))
    cv.box_outline(2, 2, w - 4, h - 4, c("void"))
    # Corner ornamental studs
    stud = mix(accent, c("gold"), 0.6)
    for sx, sy in [(2, 2), (w - 6, 2), (2, h - 6), (w - 6, h - 6)]:
        cv.rect(sx, sy, 4, 4, c("void"))
        cv.rect(sx + 1, sy + 1, 2, 2, stud)
        cv.px(sx + 1, sy + 1, c("cream"))


def _build_portrait(cls: str) -> Canvas:
    cv = Canvas(96, 96)
    match cls:
        case "mage":  # Алдар — Боевой маг
            accent = c("ember_red")
            _draw_backdrop(cv, accent, c("blood_vd"), "sigil")
            _shade_bust(cv, c("crimson_dk"), c("gold"), c("arcane_dk"))
            _draw_face(cv, c("sand"), c("gold_glow"), shadowed=True, scar=True)
            _draw_hood(cv, c("crimson"), c("gold"), tall=2)
            cv.ellipse(75, 76, 5, 4, c("crimson_dk"))
            _draw_magic_orb(cv, 75, 63, c("gold_glow"), c("flame"), 7)
            for ex, ey in [(70, 50), (79, 54), (66, 59), (81, 71)]:
                cv.rect(ex, ey, 2, 2, c("amber"))
        case "knight":  # Сэр Гаван — Паладин
            accent = c("gold_lt")
            _draw_backdrop(cv, accent, c("night"), "rays")
            _shade_bust(cv, c("stone"), c("gold"), c("crimson"), wide=2)
            # Greathelm
            cv.poly([(34, 54), (35, 25), (41, 18), (55, 18), (61, 25), (62, 54)], c("stone_dk"))
            cv.poly([(36, 52), (37, 26), (42, 20), (49, 20), (49, 52)], c("frost_dk"))
            cv.rect(47, 19, 3, 33, c("gold"))
            cv.rect(36, 35, 24, 3, c("gold_lt"))
            # Visor slit + holy glowing eyes
            cv.rect(38, 36, 20, 2, c("black"))
            cv.rect(42, 36, 3, 2, c("gold_glow"))
            cv.rect(51, 36, 3, 2, c("gold_glow"))
            # Breathing holes
            for bx in (40, 43, 53, 56):
                for by in (42, 46):
                    cv.px(bx, by, c("black"))
            # Sword hilt on right
            cv.line(74, 52, 74, 92, c("snow_dk"), 2)
            cv.line(66, 76, 82, 76, c("gold"), 2)
            cv.rect(73, 84, 3, 4, c("crimson"))
        case "witch":  # Моркана — Ведьма
            accent = c("violet_lt")
            _draw_backdrop(cv, accent, c("arcane_vd"), "points")
            _shade_bust(cv, c("arcane_dk"), c("frost_dk"), c("arcane"))
            _draw_face(cv, c("snow_dk"), c("glow_green"), shadowed=False)
            # Dark locks
            cv.poly([(36, 31), (32, 54), (39, 54), (39, 36)], c("void"))
            cv.poly([(60, 31), (64, 54), (57, 54), (57, 36)], c("void"))
            # Wide pointed witch hat
            cv.ellipse(48, 31, 27, 5, c("void"))
            cv.ellipse(48, 30, 25, 4, c("arcane_vd"))
            cv.poly([(35, 29), (44, 9), (56, 7), (53, 18), (61, 29)], c("arcane_dk"))
            cv.rect(38, 26, 20, 3, c("violet"))
            cv.box_outline(46, 25, 4, 5, c("gold"))
            cv.ellipse(21, 76, 5, 4, c("arcane_vd"))
            _draw_magic_orb(cv, 21, 63, c("pale_green"), c("poison"), 6)
        case "barbarian":  # Коргаш — Варвар
            accent = c("lava")
            _draw_backdrop(cv, accent, c("blood_vd"), "rays")
            _shade_bust(cv, c("leather"), c("iron"), c("sand_dk"), wide=4)
            # Fur pelt collar
            for fx in range(26, 71, 3):
                cv.ellipse(fx, 57, 4, 4, c("sand_dk") if fx % 2 == 0 else c("umbra"))
            _draw_face(cv, c("sand"), c("amber"), scar=True, beard=c("leather"))
            cv.line(44, 48, 44, 55, c("leather_lt"))
            cv.line(52, 48, 52, 55, c("leather_lt"))
            # Iron horned helm
            cv.poly([(36, 34), (38, 22), (58, 22), (60, 34)], c("stone"))
            cv.rect(47, 22, 2, 13, c("iron"))
            # Curved horns
            cv.poly([(36, 29), (24, 21), (22, 12), (28, 17), (37, 24)], c("bone"))
            cv.poly([(60, 29), (72, 21), (74, 12), (68, 17), (59, 24)], c("bone"))
            cv.line(23, 13, 27, 18, c("cream"))
            cv.line(73, 13, 69, 18, c("cream"))
        case "archer":  # Лиэль — Охотник
            accent = c("glow_green")
            _draw_backdrop(cv, accent, c("swamp_vd"), "points")
            _shade_bust(cv, c("moss_dk"), c("leather_lt"), c("moss"))
            _draw_face(cv, c("parchment"), c("life"), shadowed=True)
            _draw_hood(cv, c("moss"), c("bronze"), tall=1)
            # Bow stave & arrow fletching behind shoulder
            cv.line(70, 22, 78, 56, c("leather_lt"), 2)
            cv.line(78, 56, 74, 88, c("leather_lt"), 2)
            cv.line(70, 22, 74, 88, c("parchment"), 1)
            cv.line(22, 42, 34, 62, c("bone"), 2)
            cv.poly([(19, 38), (24, 41), (22, 46)], c("frost"))
        case "ninja":  # Тень — Тень
            accent = c("ice_lt")
            _draw_backdrop(cv, accent, c("night"), "sigil")
            _shade_bust(cv, c("slate_vd"), c("slate"), c("deep_water"))
            _draw_face(cv, c("sand_dk"), c("ember_red"), shadowed=True, mask=c("slate_dk"))
            _draw_hood(cv, c("slate_vd"), c("water_lt"))
            # Forehead iron plate
            cv.rect(41, 29, 14, 4, c("stone_lt"))
            cv.px(44, 30, c("black"))
            cv.px(51, 30, c("black"))
            # Twin shadow daggers
            cv.line(18, 86, 30, 62, c("snow_dk"), 2)
            cv.line(78, 86, 66, 62, c("snow_dk"), 2)
        case "lightning_mage":  # Вольтра — Громовой маг
            accent = c("ice_glow")
            _draw_backdrop(cv, accent, c("night"), "rays")
            _shade_bust(cv, c("water"), c("brass"), c("ice_blue"))
            _draw_face(cv, c("snow_dk"), c("ice_glow"))
            # Archmage lightning crown / collar
            cv.poly([(36, 31), (39, 17), (44, 24), (48, 13), (52, 24), (57, 17), (60, 31)], c("brass"))
            cv.rect(47, 16, 2, 12, c("ice_glow"))
            # Crackling arcs
            cv.line(20, 34, 28, 44, c("ice_glow"), 1)
            cv.line(28, 44, 22, 54, c("white"), 1)
            cv.line(22, 54, 30, 66, c("ice_glow"), 1)
            cv.line(74, 30, 67, 44, c("ice_glow"), 1)
            cv.line(67, 44, 75, 56, c("white"), 1)
            _draw_magic_orb(cv, 72, 68, c("white"), c("ice_glow"), 6)
        case "wind_archer":  # Рейн — Лучник ветра
            accent = c("frost_blue")
            _draw_backdrop(cv, accent, c("deep_water"), "points")
            _shade_bust(cv, c("water_lt"), c("frost"), c("ice_blue"))
            _draw_face(cv, c("cream"), c("frost_blue"))
            # Wind-swept pale hair
            cv.poly([(35, 36), (34, 22), (46, 17), (59, 20), (64, 30), (58, 36), (52, 28), (41, 29)], c("snow"))
            cv.poly([(58, 22), (71, 18), (64, 28)], c("snow_dk"))
            # Gale rings
            cv.ring(24, 62, 11, 9, c("frost_blue"))
            cv.ring(24, 62, 6, 4, c("ice_glow"))
        case "fire_mage":  # Игнис — Маг огня
            accent = c("flame")
            _draw_backdrop(cv, accent, c("blood_vd"), "rays")
            _shade_bust(cv, c("maroon"), c("amber"), c("lava"))
            _draw_face(cv, c("sand"), c("gold_glow"))
            # Flame hair / ember crown
            cv.poly([(36, 34), (35, 19), (42, 24), (48, 11), (54, 23), (61, 17), (60, 34)], c("lava"))
            cv.poly([(40, 31), (44, 18), (48, 15), (52, 20), (56, 30)], c("amber"))
            cv.poly([(45, 29), (48, 20), (51, 28)], c("gold_glow"))
            _draw_magic_orb(cv, 24, 68, c("gold_glow"), c("lava"), 7)
        case _:  # void_mage — Нокс, Некромант Бездны
            accent = c("ghost_violet")
            _draw_backdrop(cv, accent, c("void"), "sigil")
            _shade_bust(cv, c("arcane_vd"), c("ghost_violet"), c("bone"))
            _draw_face(cv, c("moon_stone"), c("ghost_violet"), shadowed=True)
            # Jagged bone & obsidian crown
            cv.poly([(35, 34), (34, 15), (41, 24), (48, 11), (55, 24), (62, 15), (61, 34)], c("arcane_dk"))
            cv.line(34, 15, 37, 29, c("bone"))
            cv.line(48, 11, 48, 26, c("ghost_violet"))
            cv.line(62, 15, 59, 29, c("bone"))
            cv.ellipse(75, 76, 5, 4, c("arcane_vd"))
            _draw_magic_orb(cv, 75, 63, c("white"), c("violet_lt"), 7)

    _frame_portrait(cv, accent)
    return cv


def generate_game_icon() -> Path:
    """Generates a 128x128 crisp gothic pixel-art Surwave icon at repo root (upscaled 2x from 64x64)."""
    cv = Canvas(64, 64)
    # Dark gothic radial background
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 32, y - 32) / 36.0
            bg = _dither(cv, x, y, c("void"), c("blood_vd"), max(0.0, 1.0 - d))
            cv.px(x, y, bg)
    # Outer beveled stone & bronze frame
    cv.box_outline(0, 0, 64, 64, c("black"))
    cv.box_outline(1, 1, 62, 62, c("bronze_dk"))
    cv.line(1, 1, 62, 1, c("gold_lt"))
    cv.line(1, 1, 1, 62, c("gold_lt"))
    cv.box_outline(2, 2, 60, 60, c("void"))
    cv.box_outline(3, 3, 58, 58, c("crimson_dk"))
    # Glowing arcane/crimson circle
    cv.ring(32, 32, 22, 19, c("crimson"))
    cv.ring(32, 32, 19, 17, c("gold"))
    # Fiery crimson-gold 'S' wave ribbons around the blade
    pts_top = [(41, 16), (26, 16), (20, 22), (24, 30), (39, 32), (43, 39), (38, 46), (22, 46)]
    for i in range(len(pts_top) - 1):
        cv.line(pts_top[i][0], pts_top[i][1], pts_top[i + 1][0], pts_top[i + 1][1], c("ember_red"), 3)
        cv.line(pts_top[i][0], pts_top[i][1] - 1, pts_top[i + 1][0], pts_top[i + 1][1] - 1, c("gold_glow"), 1)
    # Stylized sword blade bisecting the 'S' crest
    cv.line(32, 9, 32, 46, c("snow"), 2)
    cv.line(33, 11, 33, 45, c("frost_dk"), 1)
    cv.poly([(32, 6), (29, 12), (35, 12)], c("snow_lt"))
    cv.line(23, 46, 41, 46, c("gold_lt"), 2)
    cv.rect(31, 48, 3, 6, c("crimson"))
    cv.rect(31, 54, 3, 2, c("gold_glow"))
    # Corner rivets
    for rx, ry in [(2, 2), (58, 2), (2, 58), (58, 58)]:
        cv.rect(rx, ry, 4, 4, c("gold"))
        cv.px(rx + 1, ry + 1, c("cream"))
    # Nearest-neighbor 2x upscale to 128x128
    up = [(0, 0, 0, 255)] * (128 * 128)
    for y in range(64):
        for x in range(64):
            col = cv.buf[y * 64 + x]
            for dy in (0, 1):
                for dx in (0, 1):
                    up[(y * 2 + dy) * 128 + (x * 2 + dx)] = col
    out_path = ROOT / "icon.png"
    save_png(out_path, 128, 128, up)
    return out_path


def run() -> int:
    classes = [
        "mage",
        "knight",
        "witch",
        "barbarian",
        "archer",
        "ninja",
        "lightning_mage",
        "wind_archer",
        "fire_mage",
        "void_mage",
    ]
    for cls in classes:
        cv = _build_portrait(cls)
        cv.save(SPRITE_DIR / f"portrait_{cls}.png")
    generate_game_icon()
    return len(classes) + 1
