# -*- coding: utf-8 -*-
"""Generates custom 96x48 pixel-art illustrations for EVERY perk (100), synergy (12), seal (12), and char upgrade (30)."""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, mix, mul

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"

TREE_THEMES: dict[str, tuple[Color, Color, str]] = {
    "fast_arrows": (c("frost"), c("ice_blue"), "proj"),
    "damage": (c("crimson"), c("gold_glow"), "blade"),
    "fire_rate": (c("amber"), c("gold_lt"), "rapid"),
    "multishot": (c("gold"), c("lava"), "fan"),
    "reload": (c("brass"), c("cream"), "mag"),
    "proj_speed": (c("ice_lt"), c("snow"), "streak"),
    "pierce": (c("snow"), c("crimson"), "pierce"),
    "thunder": (c("ice_glow"), c("violet_lt"), "bolt"),
    "flame": (c("lava"), c("gold_glow"), "flame"),
    "frost": (c("frost_blue"), c("snow_lt"), "frost"),
    "dark": (c("violet"), c("ember_red"), "curse"),
    "light": (c("gold_glow"), c("white"), "smite"),
    "health": (c("scarlet"), c("crimson"), "heart"),
    "shield": (c("ice_blue"), c("gold"), "shield"),
    "dodge": (c("glow_green"), c("ice_lt"), "dash"),
    "soul": (c("violet_lt"), c("ghost_violet"), "soul"),
    "pickup": (c("gold"), c("amber"), "magnet"),
    "move": (c("sand_lt"), c("glow_green"), "boot"),
    "vision": (c("amber"), c("gold_glow"), "eye"),
    "wind": (c("snow"), c("ice_lt"), "wind"),
    "summon": (c("ghost_violet"), c("arcane"), "summon"),
    "dragon": (c("ember_red"), c("gold_glow"), "dragon"),
    "scythe": (c("crimson"), c("violet_lt"), "scythe"),
    "boomerang": (c("brass"), c("gold_lt"), "boomerang"),
    "beast": (c("life"), c("amber"), "beast"),
}


def _bg_scene(cv: Canvas, col1: Color, col2: Color, seed: int) -> None:
    rng = random.Random(seed)
    dark = mul(col1, 0.16)
    mid = mul(mix(col1, col2, 0.4), 0.30)
    for y in range(cv.h):
        t = y / float(cv.h - 1)
        row_col = mix(dark, mid, t)
        for x in range(cv.w):
            d = 1.04 if (x + y) % 2 == 0 else 0.96
            cv.px(x, y, mul(row_col, d))
    # Atmospheric radial glow at center
    cv.ellipse(48, 24, 34, 18, (col1[0], col1[1], col1[2], 42), True)
    cv.ellipse(48, 24, 20, 11, (col2[0], col2[1], col2[2], 45), True)
    # Subtle stars / embers
    for _ in range(18):
        cv.px(rng.randrange(4, 92), rng.randrange(4, 44), (col2[0], col2[1], col2[2], 140), True)


def _frame_illus(cv: Canvas, accent: Color) -> None:
    cv.box_outline(0, 0, cv.w, cv.h, c("black"))
    cv.box_outline(1, 1, cv.w - 2, cv.h - 2, mul(accent, 0.55))
    cv.line(1, 1, cv.w - 2, 1, mix(accent, c("gold_lt"), 0.35))
    for rx, ry in [(1, 1), (cv.w - 4, 1), (1, cv.h - 4), (cv.w - 4, cv.h - 4)]:
        cv.rect(rx, ry, 3, 3, mix(accent, c("gold"), 0.6))


def _draw_motif_scene(cv: Canvas, motif: str, accent: Color, hi: Color, variant: int, seed: int) -> None:
    rng = random.Random(seed)
    cx, cy = 48, 24

    if motif in ("proj", "streak"):
        # Speeding projectile(s) + shockcone + target reticle
        count = 1 + (variant % 3)
        for i in range(count):
            yy = cy + (i - (count - 1) * 0.5) * 9
            cv.line(10, int(yy), 58, int(yy), mul(accent, 0.6), 1)
            cv.line(24, int(yy), 62, int(yy), accent, 2)
            cv.poly([(60, int(yy) - 4), (72, int(yy)), (60, int(yy) + 4)], hi)
        if variant >= 2:
            cv.ring(74, cy, 10, 8.5, c("crimson"))
            cv.px(74, cy, c("gold_glow"))
    elif motif in ("blade", "pierce"):
        # Heavy caliber / reaper blade / shattered armor
        if variant == 3:
            # Reaper crescent scythe & skull
            cv.line(26, 40, 56, 8, c("leather_lt"), 2)
            cv.poly([(54, 7), (22, 12), (34, 22), (56, 12)], hi)
            cv.ellipse(66, 26, 8, 9, c("parchment"))
            cv.rect(62, 24, 3, 3, c("black"))
            cv.rect(68, 24, 3, 3, c("black"))
        else:
            cv.line(18, 38, 70, 10, c("stone_lt"), 3)
            cv.line(20, 38, 70, 11, hi, 1)
            cv.line(26, 24, 38, 36, c("gold"), 2)
            for k in range(variant * 2 + 2):
                a = rng.uniform(0, math.tau)
                r = rng.uniform(6, 16)
                cv.rect(int(58 + math.cos(a) * r), int(18 + math.sin(a) * r), 2, 2, hi)
    elif motif in ("rapid", "fan", "mag"):
        # Fan volley or glowing brass drum magazine
        if motif == "mag":
            cv.ring(cx, cy, 14, 7, c("bronze"))
            for i in range(6):
                a = i * math.tau / 6.0 + variant * 0.3
                bx = int(cx + math.cos(a) * 10)
                by = int(cy + math.sin(a) * 10)
                cv.ellipse(bx, by, 2.5, 2.5, hi)
        else:
            n = 3 + variant * 2
            for i in range(n):
                ang = -0.55 + (1.10 * i / max(1, n - 1))
                x1, y1 = 16, cy
                x2 = int(x1 + math.cos(ang) * 58)
                y2 = int(y1 + math.sin(ang) * 32)
                cv.line(x1, y1, x2, y2, accent, 2)
                cv.ellipse(x2, y2, 2.5, 2.5, hi)
            cv.ellipse(16, cy, 5, 5, c("white"))
    elif motif == "bolt":
        # Sky-to-earth branching thunderbolt + storm cloud
        cv.ellipse(48, 8, 22, 6, c("slate_dk"))
        cv.ellipse(36, 10, 12, 5, c("slate"))
        cv.ellipse(60, 10, 12, 5, c("slate"))
        pts = [(48, 10), (41, 20), (50, 22), (43, 33), (52, 41)]
        for i in range(len(pts) - 1):
            cv.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], accent, 3)
            cv.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], c("white"), 1)
        if variant >= 1:
            cv.line(41, 20, 27, 34, hi, 1)
            cv.line(50, 22, 68, 35, hi, 1)
        cv.ellipse(52, 41, 14, 4, (accent[0], accent[1], accent[2], 140), True)
    elif motif == "flame":
        # Roaring fireball / inferno pillar
        cx0 = cx + (0 if variant != 1 else -8)
        cv.ellipse(cx0, 28, 16, 14, c("crimson_dk"))
        cv.poly([(cx0 - 14, 30), (cx0 - 6, 8), (cx0 + 2, 20), (cx0 + 8, 6), (cx0 + 15, 30)], c("lava"))
        cv.poly([(cx0 - 8, 32), (cx0, 12), (cx0 + 8, 32)], c("gold_glow"))
        cv.ellipse(cx0, 31, 4, 4, c("white"))
        for i in range(4 + variant * 2):
            cv.rect(rng.randint(18, 78), rng.randint(6, 38), 2, 2, c("gold_glow"))
    elif motif == "frost":
        # Crystal snowflake / frozen ice prison
        for ang_deg in range(0, 180, 30):
            r = 16
            rad = math.radians(ang_deg)
            cv.line(int(cx - math.cos(rad) * r), int(cy - math.sin(rad) * r),
                    int(cx + math.cos(rad) * r), int(cy + math.sin(rad) * r), accent, 2)
        cv.ellipse(cx, cy, 6, 6, c("white"))
        if variant >= 2:
            for sx in (22, 74):
                cv.poly([(sx - 5, 38), (sx, 10), (sx + 5, 38)], hi)
    elif motif in ("curse", "soul", "scythe"):
        # Necrotic skull, spectral wisps, or reaper scythe
        cv.ellipse(cx, cy - 2, 11, 12, c("parchment"))
        cv.rect(cx - 6, cy + 7, 12, 5, c("bone"))
        cv.rect(cx - 5, cy - 3, 3, 3, c("black"))
        cv.rect(cx + 2, cy - 3, 3, 3, c("black"))
        cv.px(cx - 4, cy - 2, hi)
        cv.px(cx + 3, cy - 2, hi)
        for i in range(4):
            ang = i * math.tau / 4.0 + variant * 0.5
            wx = int(cx + math.cos(ang) * 24)
            wy = int(cy + math.sin(ang) * 14)
            cv.ellipse(wx, wy, 4, 4, accent)
            cv.px(wx, wy, c("white"))
        if motif == "scythe":
            cv.line(18, 42, 76, 6, c("frost"), 2)
    elif motif == "smite":
        # Golden heavenly beam from above + halo cross
        cv.rect(cx - 8, 2, 16, 42, (accent[0], accent[1], accent[2], 95), True)
        cv.rect(cx - 4, 2, 8, 42, (hi[0], hi[1], hi[2], 190), True)
        cv.line(cx, 6, cx, 38, c("white"), 2)
        cv.line(cx - 12, 18, cx + 12, 18, c("white"), 2)
        cv.ellipse(cx, 40, 18, 5, (accent[0], accent[1], accent[2], 150), True)
    elif motif == "heart":
        # Glowing ruby heart + regeneration rays
        cv.ellipse(cx - 6, cy - 3, 7, 6.5, accent)
        cv.ellipse(cx + 6, cy - 3, 7, 6.5, accent)
        cv.poly([(cx - 13, cy - 1), (cx + 13, cy - 1), (cx, cy + 14)], accent)
        cv.ellipse(cx - 6, cy - 5, 2.5, 2, c("white"))
        if variant >= 1:
            cv.line(cx - 22, cy, cx - 16, cy, c("gold_glow"), 2)
            cv.line(cx + 16, cy, cx + 22, cy, c("gold_glow"), 2)
    elif motif == "shield":
        # Ornate tower shield + rune crest
        cv.poly([(34, 8), (62, 8), (60, 28), (48, 40), (36, 28)], mul(accent, 0.6))
        cv.poly([(36, 10), (60, 10), (58, 27), (48, 37), (38, 27)], accent)
        cv.line(48, 11, 48, 36, hi, 2)
        cv.line(39, 20, 57, 20, hi, 2)
    elif motif in ("dash", "boot", "wind"):
        # Swirling gale / speed afterimages
        for k in range(3):
            ox = 26 + k * 14
            cv.ellipse(ox, cy + (k % 2) * 3, 6, 11, (accent[0], accent[1], accent[2], 80 + k * 60), True)
        cv.line(14, 16, 78, 16, hi, 2)
        cv.line(20, 26, 84, 26, accent, 2)
        cv.line(12, 34, 70, 34, hi, 1)
    elif motif == "magnet":
        # Horseshoe magnet pulling XP gems & gold coins
        cv.ring(36, cy, 12, 7, c("crimson"))
        cv.rect(36, 12, 14, 24, (0, 0, 0, 0))
        cv.rect(36, 12, 8, 5, c("frost"))
        cv.rect(36, 31, 8, 5, c("frost"))
        for gx, gy in [(62, 16), (72, 24), (64, 34)]:
            cv.poly([(gx, gy - 4), (gx + 4, gy), (gx, gy + 4), (gx - 4, gy)], c("ice_glow"))
    elif motif == "eye":
        # All-seeing glowing rune eye
        cv.ellipse(cx, cy, 22, 11, c("parchment"))
        cv.ellipse(cx, cy, 10, 10, accent)
        cv.ellipse(cx, cy, 4, 6, c("black"))
        cv.px(cx - 2, cy - 3, c("white"))
    elif motif == "dragon":
        # Fire-breathing drake head & breath cone
        cv.poly([(18, 28), (28, 12), (44, 16), (40, 30), (24, 34)], c("crimson"))
        cv.poly([(28, 12), (22, 6), (32, 11)], c("gold"))
        cv.px(35, 19, c("gold_glow"))
        cv.poly([(44, 22), (82, 10), (82, 36)], c("lava"))
        cv.poly([(46, 23), (76, 17), (76, 30)], c("gold_glow"))
    elif motif in ("summon", "beast"):
        # Summoning circle + spectral companion / armored wolf beast
        cv.ellipse(cx, 35, 24, 6, (accent[0], accent[1], accent[2], 140), True)
        cv.ellipse(cx, 22, 10, 11, accent)
        cv.poly([(cx - 8, 16), (cx - 10, 6), (cx - 2, 14)], hi)
        cv.poly([(cx + 8, 16), (cx + 10, 6), (cx + 2, 14)], hi)
        cv.px(cx - 3, 20, c("white"))
        cv.px(cx + 3, 20, c("white"))
    elif motif == "boomerang":
        # Дуга полёта и возврата + вращающийся бумеранг в центре
        cv.ellipse(cx, cy + 6, 34, 12, (accent[0], accent[1], accent[2], 60), True)
        cv.line(14, cy + 12, cx - 10, cy - 8, mul(accent, 0.7))
        cv.line(cx + 10, cy - 8, 82, cy + 12, mul(accent, 0.7))
        cv.line(cx - 10, cy - 8, cx + 10, cy - 8, hi, 2)
        for k in range(3):
            r = 8 + k * 5
            cv.line(cx - r, cy - 2 - k * 2, cx - 2, cy - 6 - k, mul(hi, 0.8 - k * 0.2))
            cv.line(cx + 2, cy - 6 - k, cx + r, cy - 2 - k * 2, mul(hi, 0.8 - k * 0.2))
        cv.poly([(cx - 16, cy + 10), (cx, cy + 2), (cx + 16, cy + 10)], accent)
        cv.poly([(cx - 12, cy + 10), (cx, cy + 5), (cx + 12, cy + 10)], hi)
    else:  # spear
        for s in (-1, 0, 1):
            yy = cy + s * 9
            cv.line(12, yy + 4, 68, yy - 4, c("gold"), 2)
            cv.poly([(64, yy - 8), (78, yy - 5), (66, yy + 1)], c("white"))


def _make_illus(name: str, motif: str, accent: Color, hi: Color, variant: int, seed: int) -> Canvas:
    cv = Canvas(96, 48)
    _bg_scene(cv, accent, hi, seed)
    _draw_motif_scene(cv, motif, accent, hi, variant, seed)
    _frame_illus(cv, accent)
    return cv


def run() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    count = 0

    # 1. All 100 perks from data/perks.json
    perks_data = json.loads((ROOT / "data" / "perks.json").read_text(encoding="utf-8"))
    for idx, p in enumerate(perks_data.get("perks", [])):
        pid = str(p["id"])
        tree = str(p.get("tree", "damage"))
        tier = int(p.get("tier", 1))
        branch = str(p.get("branch", ""))
        variant = (tier - 1) + (1 if branch == "b" else 0)
        accent, hi, motif = TREE_THEMES.get(tree, (c("gold"), c("cream"), "blade"))
        _make_illus(pid, motif, accent, hi, variant, 5000 + idx * 31).save(OUT / f"illus_{pid}.png")
        count += 1

    # 2. All 12 synergies
    syn_styles = {
        "syn_reaper": ("scythe", c("crimson"), c("gold_glow")),
        "syn_iceflame": ("frost", c("ice_glow"), c("lava")),
        "syn_weaponmaster": ("blade", c("gold_lt"), c("white")),
        "syn_smallmag": ("mag", c("amber"), c("gold_glow")),
        "syn_overload": ("bolt", c("ice_glow"), c("lava")),
        "syn_unbreakable": ("shield", c("frost"), c("gold")),
        "syn_summonpower": ("summon", c("ghost_violet"), c("gold_glow")),
        "syn_plague": ("curse", c("glow_green"), c("violet_lt")),
        "syn_resonance": ("smite", c("violet_lt"), c("ice_glow")),
        "syn_windshadow": ("dash", c("moon_stone"), c("violet_lt")),
        "syn_swordshield": ("shield", c("gold"), c("crimson")),
        "syn_giant": ("heart", c("lava"), c("gold_glow")),
    }
    for idx, (sid, (mot, ac, hi)) in enumerate(syn_styles.items()):
        _make_illus(sid, mot, ac, hi, 3, 7000 + idx * 17).save(OUT / f"illus_{sid}.png")
        count += 1

    # 3. All 12 seals
    seals = json.loads((ROOT / "data" / "seals.json").read_text(encoding="utf-8"))
    for idx, s in enumerate(seals):
        sid = str(s["id"])
        mot = ["proj", "bolt", "flame", "curse", "blade", "smite", "fan", "boot", "shield", "summon", "heart", "wind"][idx % 12]
        _make_illus(sid, mot, c("gold"), c("ice_glow"), 2, 8000 + idx * 19).save(OUT / f"illus_{sid}.png")
        count += 1

    # 4. All 30 character unique upgrades
    chars = json.loads((ROOT / "data" / "characters.json").read_text(encoding="utf-8"))
    for c_idx, ch in enumerate(chars):
        cls = str(ch.get("cls", "mage"))
        mot = {
            "mage": "bolt", "paladin": "smite", "necromancer": "curse", "orc": "blade",
            "elf": "proj", "rogue": "dash", "inventor": "magnet", "sniper": "streak",
            "pyromancer": "flame", "star": "summon",
        }.get(cls, "blade")
        for u_idx, up in enumerate(ch.get("upgrades", [])):
            uid = str(up["id"])
            _make_illus(uid, mot, c("gold_lt"), c("violet_lt"), u_idx + 1, 9000 + c_idx * 10 + u_idx).save(OUT / f"illus_{uid}.png")
            count += 1

    # 5. Evolution & Specialization banners
    _make_illus("evolution", "blade", c("gold_glow"), c("crimson"), 3, 9901).save(OUT / "illus_evolution.png")
    _make_illus("specialization", "smite", c("ice_glow"), c("gold_lt"), 2, 9902).save(OUT / "illus_specialization.png")
    count += 2
    return count
