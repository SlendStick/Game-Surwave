# -*- coding: utf-8 -*-
"""Generates 128x128 gothic pixel-art portraits for ALL 10 playable heroes and ALL bestiary units + game icon."""

from __future__ import annotations

import json
import math
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, mix, mul, save_png

ROOT = Path(__file__).resolve().parent.parent
SPRITE_DIR = ROOT / "assets" / "sprites"

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def _dither(x: int, y: int, c1: Color, c2: Color, t: float) -> Color:
    b = (BAYER4[y & 3][x & 3] + 0.5) / 16.0
    return c2 if t > b else c1


def _upscale_2x(cv64: Canvas) -> Canvas:
    up = Canvas(128, 128)
    for y in range(64):
        for x in range(64):
            col = cv64.buf[y * 64 + x]
            i0 = (y * 2) * 128 + (x * 2)
            i1 = (y * 2 + 1) * 128 + (x * 2)
            up.buf[i0] = col
            up.buf[i0 + 1] = col
            up.buf[i1] = col
            up.buf[i1 + 1] = col
    return up


def _draw_backdrop_64(cv: Canvas, accent: Color, dark_bg: Color, rune_kind: str) -> None:
    cx, cy = 32.0, 28.0
    for y in range(64):
        for x in range(64):
            dist = math.hypot((x - cx) / 35.0, (y - cy) / 35.0)
            t = max(0.0, min(1.0, 1.0 - dist))
            col = _dither(x, y, c("void"), mix(dark_bg, accent, 0.30), t * 0.85)
            if abs(x - cx) > 19 and (x % 5 == 0):
                col = mul(col, 0.85)
            cv.px(x, y, col)
    cv.ring(cx, cy - 2, 20, 18.5, mix(dark_bg, accent, 0.55))
    cv.ring(cx, cy - 2, 16, 15.0, mix(dark_bg, accent, 0.32))
    if rune_kind == "points":
        for i in range(8):
            ang = i * math.tau / 8.0
            rx = int(round(cx + math.cos(ang) * 19.5))
            ry = int(round(cy - 2 + math.sin(ang) * 19.5))
            cv.rect(rx - 1, ry - 1, 2, 2, accent)
    elif rune_kind == "rays":
        for i in range(12):
            ang = i * math.tau / 12.0
            cv.line(
                int(cx + math.cos(ang) * 16),
                int(cy - 2 + math.sin(ang) * 16),
                int(cx + math.cos(ang) * 23),
                int(cy - 2 + math.sin(ang) * 23),
                mix(accent, c("gold_lt"), 0.35),
            )
    elif rune_kind == "sigil":
        for i in range(6):
            a1 = i * math.tau / 6.0
            a2 = ((i + 2) % 6) * math.tau / 6.0
            cv.line(
                int(cx + math.cos(a1) * 17),
                int(cy - 2 + math.sin(a1) * 17),
                int(cx + math.cos(a2) * 17),
                int(cy - 2 + math.sin(a2) * 17),
                mix(dark_bg, accent, 0.45),
            )


def _shade_bust_64(cv: Canvas, torso_col: Color, trim_col: Color, collar_col: Color, wide: int = 0) -> None:
    cx = 32
    sh_dark = mul(torso_col, 0.48)
    sh_mid = torso_col
    sh_hi = mix(torso_col, c("cream"), 0.24)
    pts = [
        (cx - 22 - wide, 63),
        (cx - 20 - wide, 45),
        (cx - 11, 37),
        (cx + 11, 37),
        (cx + 20 + wide, 45),
        (cx + 22 + wide, 63),
    ]
    cv.poly(pts, sh_dark)
    for y in range(38, 64):
        t_y = (y - 38) / 26.0
        half_w = int(11 + (11 + wide) * min(1.0, t_y * 1.45))
        for x in range(cx - half_w, cx + half_w + 1):
            if cv.get(x, y)[3] == 0:
                continue
            rel = (x - cx) / max(1, half_w)
            fold = math.sin((x - cx) * 0.45 + y * 0.12) * 0.12
            light = max(0.0, min(1.0, 0.58 - rel * 0.48 + fold))
            col = _dither(x, y, sh_dark, sh_mid, light * 1.3)
            if light > 0.68:
                col = _dither(x, y, sh_mid, sh_hi, (light - 0.68) * 2.8)
            cv.px(x, y, col)
    for side in (-1, 1):
        px = cx + side * (15 + wide // 2)
        cv.ellipse(px, 44, 7 + wide // 2, 4.5, mul(trim_col, 0.55))
        cv.ellipse(px - side, 43, 6 + wide // 2, 3.5, trim_col)
        cv.line(px - 4, 41, px + 4, 41, mix(trim_col, c("cream"), 0.45))
    cv.line(cx - 7, 38, cx, 52, trim_col, 2)
    cv.line(cx + 7, 38, cx, 52, mul(trim_col, 0.72), 2)
    cv.line(cx, 52, cx, 63, trim_col, 2)
    cv.ellipse(cx, 37, 9, 3.5, mul(collar_col, 0.6))
    cv.ellipse(cx, 36, 7.5, 2.8, collar_col)


def _draw_face_64(
    cv: Canvas,
    skin: Color,
    eye_col: Color,
    *,
    shadowed: bool = False,
    scar: bool = False,
    beard: Color | None = None,
    mask: Color | None = None,
    fangs: bool = False,
) -> None:
    cx, cy = 32, 26
    skin_dk = mul(skin, 0.62)
    skin_lt = mix(skin, c("cream"), 0.22)
    cv.rect(cx - 4, 32, 8, 7, skin_dk)
    cv.rect(cx - 3, 32, 4, 6, skin)
    cv.ellipse(cx, cy, 7.5, 9.0, skin_dk)
    cv.ellipse(cx - 1, cy - 1, 6.5, 8.0, skin)
    cv.ellipse(cx - 2, cy - 3, 3.5, 4.0, skin_lt)
    if shadowed:
        cv.poly([(cx - 8, 17), (cx + 8, 17), (cx + 7, 25), (cx, 27), (cx - 7, 25)], c("void"))
        cv.rect(cx - 6, 25, 12, 2, mix(c("void"), skin_dk, 0.5))
    cv.line(cx, 24, cx, 29, skin_dk)
    if mask is None:
        cv.line(cx - 2, 31, cx + 2, 31, mul(skin_dk, 0.72))
    if fangs:
        cv.px(cx - 2, 30, c("parchment"))
        cv.px(cx + 2, 30, c("parchment"))
    if scar:
        cv.line(cx + 1, 22, cx + 5, 30, c("crimson"))
    if beard is not None:
        cv.poly([(cx - 7, 29), (cx + 7, 29), (cx + 5, 37), (cx, 40), (cx - 5, 37)], mul(beard, 0.72))
        cv.poly([(cx - 5, 30), (cx + 5, 30), (cx + 3, 36), (cx, 38), (cx - 3, 36)], beard)
    if mask is not None:
        cv.poly([(cx - 7, 27), (cx + 7, 27), (cx + 6, 35), (cx, 37), (cx - 6, 35)], mul(mask, 0.65))
        cv.poly([(cx - 6, 28), (cx + 6, 28), (cx + 5, 34), (cx, 35), (cx - 5, 34)], mask)
    for sx in (-3, 3):
        cv.rect(cx + sx - 1, 24, 3, 2, c("black"))
        cv.rect(cx + sx - 1, 24, 2, 2, eye_col)
        cv.px(cx + sx - 1, 24, mix(eye_col, c("white"), 0.55))


def _draw_hood_64(cv: Canvas, hood_col: Color, trim_col: Color, tall: int = 0) -> None:
    cx = 32
    dk = mul(hood_col, 0.52)
    lt = mix(hood_col, c("cream"), 0.25)
    pts = [
        (cx - 12, 37), (cx - 13, 23), (cx - 7, 13 - tall), (cx, 10 - tall),
        (cx + 7, 13 - tall), (cx + 13, 23), (cx + 12, 37),
        (cx + 7, 34), (cx + 7, 22), (cx, 18), (cx - 7, 22), (cx - 7, 34),
    ]
    cv.poly(pts, dk)
    cv.poly([(cx - 10, 24), (cx - 6, 15 - tall), (cx, 11 - tall), (cx + 5, 15 - tall), (cx, 17), (cx - 7, 22)], hood_col)
    cv.line(cx - 8, 21, cx, 17, trim_col)
    cv.line(cx + 8, 21, cx, 17, mul(trim_col, 0.7))
    cv.line(cx - 7, 14 - tall, cx, 11 - tall, lt)


def _draw_orb_64(cv: Canvas, x: int, y: int, core: Color, glow: Color, r: int = 5) -> None:
    cv.ellipse(x, y, r + 3, r + 3, (glow[0], glow[1], glow[2], 70), True)
    cv.ellipse(x, y, r + 1.5, r + 1.5, (glow[0], glow[1], glow[2], 130), True)
    cv.ellipse(x, y, r, r, glow)
    cv.ellipse(x - 1, y - 1, max(1.5, r - 2), max(1.5, r - 2), core)
    cv.px(x - 1, y - 1, c("white"))


def _frame_portrait_128(cv: Canvas, accent: Color) -> None:
    w, h = 128, 128
    cv.box_outline(0, 0, w, h, c("black"))
    cv.box_outline(1, 1, w - 2, h - 2, c("black"))
    cv.box_outline(2, 2, w - 4, h - 4, mul(accent, 0.60))
    cv.line(2, 2, w - 3, 2, mix(accent, c("gold_lt"), 0.42))
    cv.line(2, 2, 2, h - 3, mix(accent, c("gold_lt"), 0.42))
    cv.box_outline(3, 3, w - 6, h - 6, c("void"))
    cv.box_outline(4, 4, w - 8, h - 8, mul(accent, 0.35))
    stud = mix(accent, c("gold"), 0.65)
    for sx, sy in [(3, 3), (w - 9, 3), (3, h - 9), (w - 9, h - 9)]:
        cv.rect(sx, sy, 6, 6, c("void"))
        cv.rect(sx + 1, sy + 1, 4, 4, mul(stud, 0.65))
        cv.rect(sx + 2, sy + 2, 2, 2, stud)
        cv.px(sx + 2, sy + 2, c("cream"))


def _build_hero_portrait(cls: str) -> Canvas:
    cv = Canvas(64, 64)
    if cls == "mage":  # Алдар
        accent = c("violet_lt")
        _draw_backdrop_64(cv, accent, c("arcane_vd"), "sigil")
        _shade_bust_64(cv, c("slate_dk"), c("violet_lt"), c("arcane"))
        _draw_face_64(cv, c("sand_lt"), c("cream"), shadowed=False, beard=c("bone"))
        # Pointed wizard hat
        cv.ellipse(32, 21, 16, 3.5, c("slate_vd"))
        cv.poly([(22, 20), (32, 5), (42, 20)], c("slate_dk"))
        cv.rect(24, 18, 16, 2, accent)
        _draw_orb_64(cv, 51, 42, c("white"), accent, 5)
    elif cls == "paladin":  # Сэр Гаван
        accent = c("gold_lt")
        _draw_backdrop_64(cv, accent, c("night"), "rays")
        _shade_bust_64(cv, c("stone"), c("gold"), c("crimson"), wide=2)
        cv.poly([(22, 36), (23, 17), (27, 12), (37, 12), (41, 17), (42, 36)], c("stone_dk"))
        cv.poly([(24, 35), (24, 18), (28, 13), (32, 13), (32, 35)], c("frost_dk"))
        cv.rect(31, 13, 2, 22, c("gold"))
        cv.rect(24, 23, 16, 2, c("gold_lt"))
        cv.rect(25, 24, 14, 2, c("black"))
        cv.rect(27, 24, 2, 2, c("gold_glow"))
        cv.rect(35, 24, 2, 2, c("gold_glow"))
        # Crimson plume
        cv.poly([(31, 12), (36, 4), (42, 8), (35, 13)], c("crimson"))
        cv.line(50, 34, 50, 61, c("snow_dk"), 2)
        cv.line(44, 50, 56, 50, c("gold"), 2)
    elif cls == "necromancer":  # Моркана
        accent = c("glow_green")
        _draw_backdrop_64(cv, accent, c("arcane_vd"), "points")
        _shade_bust_64(cv, c("arcane_dk"), c("frost_dk"), c("arcane"))
        _draw_face_64(cv, c("snow_dk"), c("glow_green"), shadowed=True)
        _draw_hood_64(cv, c("arcane_vd"), c("violet_lt"), tall=2)
        _draw_orb_64(cv, 14, 42, c("pale_green"), c("poison"), 5)
    elif cls == "orc":  # Коргаш
        accent = c("lava")
        _draw_backdrop_64(cv, accent, c("blood_vd"), "rays")
        _shade_bust_64(cv, c("leather"), c("iron"), c("sand_dk"), wide=3)
        _draw_face_64(cv, c("moss"), c("amber"), scar=True, fangs=True)
        cv.poly([(24, 23), (25, 15), (39, 15), (40, 23)], c("stone"))
        cv.poly([(24, 19), (15, 14), (14, 8), (19, 11), (25, 16)], c("bone"))
        cv.poly([(40, 19), (49, 14), (50, 8), (45, 11), (39, 16)], c("bone"))
    elif cls == "elf":  # Лиэль
        accent = c("ice_lt")
        _draw_backdrop_64(cv, accent, c("swamp_vd"), "points")
        _shade_bust_64(cv, c("moss_dk"), c("leather_lt"), c("moss"))
        _draw_face_64(cv, c("parchment"), c("ice_glow"), shadowed=False)
        # Pointed elven ears
        cv.poly([(24, 25), (17, 23), (24, 28)], c("parchment"))
        cv.poly([(40, 25), (47, 23), (40, 28)], c("parchment"))
        _draw_hood_64(cv, c("moss"), c("bronze"), tall=1)
        cv.line(48, 15, 53, 37, c("leather_lt"), 2)
        cv.line(53, 37, 50, 58, c("leather_lt"), 2)
        cv.line(48, 15, 50, 58, c("frost"))
    elif cls == "rogue":  # Тень
        accent = c("crimson")
        _draw_backdrop_64(cv, accent, c("night"), "sigil")
        _shade_bust_64(cv, c("slate_vd"), c("slate"), c("crimson_dk"))
        _draw_face_64(cv, c("sand_dk"), c("ember_red"), shadowed=True, mask=c("crimson_dk"))
        _draw_hood_64(cv, c("slate_vd"), c("crimson"))
        cv.line(12, 57, 20, 41, c("frost"), 2)
        cv.line(52, 57, 44, 41, c("frost"), 2)
    elif cls == "inventor":  # Вольтра
        accent = c("amber")
        _draw_backdrop_64(cv, accent, c("night"), "rays")
        _shade_bust_64(cv, c("bronze_dk"), c("brass"), c("amber"))
        _draw_face_64(cv, c("sand_lt"), c("white"))
        # Brass goggles & wild hair
        cv.rect(24, 17, 16, 5, c("leather"))
        cv.ellipse(28, 21, 3.5, 3, c("amber"))
        cv.ellipse(36, 21, 3.5, 3, c("amber"))
        cv.px(27, 20, c("white"))
        cv.px(35, 20, c("white"))
        _draw_orb_64(cv, 49, 44, c("white"), c("ice_glow"), 4)
    elif cls == "sniper":  # Рейн
        accent = c("brass")
        _draw_backdrop_64(cv, accent, c("swamp_vd"), "points")
        _shade_bust_64(cv, c("soil_dark"), c("brass"), c("soil"))
        _draw_face_64(cv, c("sand"), c("cream"), mask=c("crimson_dk"))
        # Wide witch-hunter hat
        cv.ellipse(32, 19, 17, 3, c("slate_vd"))
        cv.rect(25, 11, 14, 8, c("slate_dk"))
        cv.rect(25, 17, 14, 2, c("brass"))
        cv.line(48, 24, 56, 58, c("iron_dk"), 2)
    elif cls == "pyromancer":  # Игнис
        accent = c("flame")
        _draw_backdrop_64(cv, accent, c("blood_vd"), "rays")
        _shade_bust_64(cv, c("crimson_dk"), c("amber"), c("lava"))
        _draw_face_64(cv, c("sand_lt"), c("gold_glow"))
        cv.poly([(24, 23), (23, 12), (28, 16), (32, 7), (36, 16), (41, 11), (40, 23)], c("lava"))
        cv.poly([(27, 21), (32, 10), (37, 21)], c("gold_glow"))
        _draw_orb_64(cv, 15, 44, c("gold_glow"), c("lava"), 5)
    else:  # star — Нокс
        accent = c("ember_red")
        _draw_backdrop_64(cv, accent, c("void"), "sigil")
        _shade_bust_64(cv, c("arcane_vd"), c("ember_red"), c("crimson_dk"), wide=1)
        _draw_face_64(cv, c("slate_vd"), c("ember_red"), shadowed=True)
        cv.line(25, 19, 16, 7, c("frost_dk"), 2)
        cv.line(39, 19, 48, 7, c("frost_dk"), 2)
        cv.ring(32, 12, 12, 10.5, c("violet_lt"))
        _draw_orb_64(cv, 50, 42, c("white"), c("violet_lt"), 5)

    up = _upscale_2x(cv)
    _frame_portrait_128(up, accent)
    return up


def _build_bestiary_portrait(unit_id: str) -> Canvas:
    """Renders a 128x128 framed gothic portrait for any enemy, miniboss, or boss."""
    cv = Canvas(64, 64)
    accent = c("crimson")
    if unit_id in ("slime", "slime_small"):
        accent = c("poison")
        _draw_backdrop_64(cv, accent, c("swamp_vd"), "points")
        cv.ellipse(32, 38, 20, 16, c("swamp_dk"))
        cv.ellipse(32, 36, 17, 13, c("moss_dk"))
        cv.ellipse(30, 33, 12, 9, c("moss"))
        cv.ellipse(27, 30, 7, 5, c("poison"))
        if unit_id == "slime":
            cv.rect(27, 34, 10, 8, c("parchment"))
            cv.rect(29, 37, 2, 2, c("black"))
            cv.rect(33, 37, 2, 2, c("black"))
        cv.rect(26, 30, 3, 3, c("ember_red"))
        cv.rect(35, 30, 3, 3, c("ember_red"))
    elif unit_id == "goblin_archer":
        accent = c("moss")
        _draw_backdrop_64(cv, accent, c("swamp_vd"), "points")
        _shade_bust_64(cv, c("leather"), c("moss_dk"), c("soil"))
        _draw_face_64(cv, c("moss"), c("amber"), fangs=True)
        cv.poly([(24, 24), (13, 21), (24, 29)], c("moss_dk"))
        cv.poly([(40, 24), (51, 21), (40, 29)], c("moss_dk"))
        _draw_hood_64(cv, c("crimson_dk"), c("leather_lt"))
    elif unit_id == "frozen_zombie":
        accent = c("ice_glow")
        _draw_backdrop_64(cv, accent, c("night"), "sigil")
        _shade_bust_64(cv, c("slate"), c("ice_blue"), c("deep_water"))
        _draw_face_64(cv, c("frost_dk"), c("ice_glow"), scar=True)
        cv.poly([(22, 24), (17, 11), (27, 19)], c("ice_lt"))
        cv.poly([(38, 22), (46, 10), (42, 26)], c("frost_blue"))
    elif unit_id == "bat":
        accent = c("ember_red")
        _draw_backdrop_64(cv, accent, c("void"), "sigil")
        cv.poly([(28, 32), (8, 16), (11, 44), (24, 36)], c("umber"))
        cv.poly([(36, 32), (56, 16), (53, 44), (40, 36)], c("umber"))
        cv.ellipse(32, 34, 9, 11, c("soil_dark"))
        cv.poly([(25, 25), (21, 11), (30, 22)], c("umber"))
        cv.poly([(39, 25), (43, 11), (34, 22)], c("umber"))
        cv.rect(28, 29, 3, 3, c("ember_red"))
        cv.rect(34, 29, 3, 3, c("ember_red"))
        cv.px(29, 36, c("white"))
        cv.px(35, 36, c("white"))
    elif unit_id == "skeleton_warrior":
        accent = c("bone")
        _draw_backdrop_64(cv, accent, c("slate_vd"), "sigil")
        _shade_bust_64(cv, c("iron_dk"), c("bone"), c("iron"))
        cv.ellipse(32, 25, 8, 9, c("parchment"))
        cv.rect(27, 30, 10, 5, c("bone"))
        cv.rect(28, 24, 3, 3, c("black"))
        cv.rect(33, 24, 3, 3, c("black"))
        cv.px(29, 25, c("ember_red"))
        cv.px(34, 25, c("ember_red"))
        cv.line(50, 14, 50, 56, c("frost"), 2)
    elif unit_id == "dark_mage":
        accent = c("ghost_violet")
        _draw_backdrop_64(cv, accent, c("arcane_vd"), "sigil")
        _shade_bust_64(cv, c("arcane_vd"), c("violet_lt"), c("maroon"))
        _draw_face_64(cv, c("void"), c("ghost_violet"), shadowed=True)
        _draw_hood_64(cv, c("maroon"), c("bone"), tall=2)
        _draw_orb_64(cv, 50, 40, c("white"), accent, 5)
    elif unit_id == "werewolf":
        accent = c("amber")
        _draw_backdrop_64(cv, accent, c("blood_vd"), "rays")
        _shade_bust_64(cv, c("umber"), c("soil"), c("sand_dk"), wide=2)
        cv.ellipse(32, 26, 9, 9, c("soil"))
        cv.rect(28, 29, 8, 5, c("sand_dk"))
        cv.poly([(24, 22), (22, 10), (29, 19)], c("umber"))
        cv.poly([(40, 22), (42, 10), (35, 19)], c("umber"))
        cv.rect(28, 23, 2, 2, c("amber"))
        cv.rect(34, 23, 2, 2, c("amber"))
        cv.px(29, 33, c("white"))
        cv.px(35, 33, c("white"))
    elif unit_id == "demon":
        accent = c("ember_red")
        _draw_backdrop_64(cv, accent, c("blood_vd"), "rays")
        _shade_bust_64(cv, c("crimson_dk"), c("crimson"), c("blood"))
        _draw_face_64(cv, c("blood"), c("gold_glow"), fangs=True)
        cv.line(25, 19, 17, 8, c("bone"), 2)
        cv.line(39, 19, 47, 8, c("bone"), 2)
    elif unit_id == "fallen_angel":
        accent = c("gold_lt")
        _draw_backdrop_64(cv, accent, c("void"), "rays")
        cv.poly([(24, 34), (8, 12), (12, 46)], c("frost"))
        cv.poly([(40, 34), (56, 12), (52, 46)], c("frost"))
        _shade_bust_64(cv, c("parchment"), c("crimson_dk"), c("gold"))
        _draw_face_64(cv, c("bone"), c("ember_red"))
        cv.ring(32, 12, 9, 7.5, c("gold"))
        cv.px(32, 4, (0, 0, 0, 0))
    else:
        # Minibosses & Bosses: draw rich atmospheric bust with biome palette + crown/horns/aura
        biome_pal = {
            "sands": (c("sand_dk"), c("gold"), c("amber"), "rays"),
            "tundra": (c("frost_dk"), c("ice_blue"), c("ice_glow"), "points"),
            "peak": (c("stone_dk"), c("lava"), c("gold_glow"), "rays"),
            "abyss": (c("slate_vd"), c("violet_lt"), c("ghost_violet"), "sigil"),
            "forest": (c("soil_dark"), c("moss"), c("glow_green"), "points"),
            "rift": (c("arcane_vd"), c("violet_lt"), c("ember_red"), "sigil"),
            "graveyard": (c("bone"), c("arcane"), c("glow_green"), "sigil"),
            "hive": (c("swamp_dk"), c("poison"), c("pale_green"), "points"),
            "bloodmoon": (c("blood_dk"), c("crimson"), c("ember_red"), "rays"),
            "chaos": (c("arcane_dk"), c("scarlet"), c("ice_glow"), "sigil"),
            "temple": (c("bronze_dk"), c("gold"), c("ice_glow"), "rays"),
            "throne": (c("slate_vd"), c("gold"), c("ember_red"), "rays"),
            "shemhaz": (c("crimson_dk"), c("lava"), c("gold_glow"), "rays"),
            "satanail": (c("crimson_dk"), c("gold"), c("ember_red"), "rays"),
            "satan": (c("blood_vd"), c("crimson"), c("gold_glow"), "sigil"),
        }
        matched = biome_pal["shemhaz"]
        for k, pal in biome_pal.items():
            if k in unit_id:
                matched = pal
                break
        body_c, sec_c, eye_c, rune_k = matched
        accent = sec_c
        _draw_backdrop_64(cv, accent, mul(body_c, 0.45), rune_k)
        is_boss = unit_id.startswith("boss_") or unit_id.startswith("champ_")
        if is_boss:
            for s in (-1, 1):
                cv.poly([(32 + s * 10, 32), (32 + s * 28, 12), (32 + s * 24, 42), (32 + s * 10, 42)], mul(sec_c, 0.7))
        _shade_bust_64(cv, body_c, sec_c, eye_c, wide=3 if is_boss else 1)
        _draw_face_64(cv, mul(body_c, 1.15), eye_c, scar=True, fangs=is_boss)
        # Crown or Great Horns
        cv.line(25, 20, 15, 7, sec_c, 2)
        cv.line(39, 20, 49, 7, sec_c, 2)
        if is_boss:
            cv.poly([(24, 19), (26, 11), (32, 15), (38, 11), (40, 19)], sec_c)
        _draw_orb_64(cv, 51, 45, c("white"), eye_c, 4)

    up = _upscale_2x(cv)
    _frame_portrait_128(up, accent)
    return up


def generate_game_icon() -> Path:
    cv = Canvas(64, 64)
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 32, y - 32) / 36.0
            cv.px(x, y, _dither(x, y, c("void"), c("blood_vd"), max(0.0, 1.0 - d)))
    cv.box_outline(0, 0, 64, 64, c("black"))
    cv.box_outline(1, 1, 62, 62, c("bronze_dk"))
    cv.line(1, 1, 62, 1, c("gold_lt"))
    cv.line(1, 1, 1, 62, c("gold_lt"))
    cv.box_outline(2, 2, 60, 60, c("void"))
    cv.box_outline(3, 3, 58, 58, c("crimson_dk"))
    cv.ring(32, 32, 22, 19, c("crimson"))
    cv.ring(32, 32, 19, 17, c("gold"))
    pts = [(41, 16), (26, 16), (20, 22), (24, 30), (39, 32), (43, 39), (38, 46), (22, 46)]
    for i in range(len(pts) - 1):
        cv.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], c("ember_red"), 3)
        cv.line(pts[i][0], pts[i][1] - 1, pts[i + 1][0], pts[i + 1][1] - 1, c("gold_glow"), 1)
    cv.line(32, 9, 32, 46, c("snow"), 2)
    cv.poly([(32, 6), (29, 12), (35, 12)], c("snow_lt"))
    cv.line(23, 46, 41, 46, c("gold_lt"), 2)
    cv.rect(31, 48, 3, 6, c("crimson"))
    cv.rect(31, 54, 3, 2, c("gold_glow"))
    for rx, ry in [(2, 2), (58, 2), (2, 58), (58, 58)]:
        cv.rect(rx, ry, 4, 4, c("gold"))
        cv.px(rx + 1, ry + 1, c("cream"))
    up = _upscale_2x(cv)
    out_path = ROOT / "icon.png"
    save_png(out_path, 128, 128, up.buf)
    return out_path


def run() -> int:
    SPRITE_DIR.mkdir(parents=True, exist_ok=True)
    count = 0

    # 1. All 10 playable heroes (exact `cls` IDs from data/characters.json)
    hero_classes = [
        "mage", "paladin", "necromancer", "orc", "elf",
        "rogue", "inventor", "sniper", "pyromancer", "star",
    ]
    for cls in hero_classes:
        _build_hero_portrait(cls).save(SPRITE_DIR / f"portrait_{cls}.png")
        count += 1

    # 2. All enemies & minibosses from data/enemies.json
    enemies = json.loads((ROOT / "data" / "enemies.json").read_text(encoding="utf-8"))
    for e in enemies:
        eid = str(e["id"])
        _build_bestiary_portrait(eid).save(SPRITE_DIR / f"portrait_{eid}.png")
        count += 1

    # 3. All bosses from data/bosses.json + boss_<map> aliases
    bosses_data = json.loads((ROOT / "data" / "bosses.json").read_text(encoding="utf-8"))
    boss_ids = {"boss_satan", "boss_champion", "boss_shemhaz", "boss_satanail"}
    for map_k, bd in bosses_data.get("bosses", {}).items():
        boss_ids.add(str(bd["id"]))
        boss_ids.add(f"boss_{map_k}")
    for bid in sorted(boss_ids):
        _build_bestiary_portrait(bid).save(SPRITE_DIR / f"portrait_{bid}.png")
        count += 1

    generate_game_icon()
    count += 1
    return count
