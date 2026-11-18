# -*- coding: utf-8 -*-
"""Pixel-art generator for Heroes (32x32), Enemies (32x32), Minibosses (48x48), and Bosses (64x64 + full animations)."""

from __future__ import annotations

import json
import math
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, mix, mul

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"


def _save_anim(
    base_name: str,
    base_cv: Canvas,
    idle_frames: list[Canvas],
    walk_frames: list[Canvas],
    attack_frames: list[Canvas] | None = None,
    hurt_frames: list[Canvas] | None = None,
    death_frames: list[Canvas] | None = None,
) -> int:
    base_cv.save(OUT / f"{base_name}.png")
    count = 1
    for i, fr in enumerate(idle_frames):
        fr.save(OUT / f"{base_name}_idle_{i}.png")
        count += 1
    for i, fr in enumerate(walk_frames):
        fr.save(OUT / f"{base_name}_walk_{i}.png")
        count += 1
    if attack_frames:
        for i, fr in enumerate(attack_frames):
            fr.save(OUT / f"{base_name}_attack_{i}.png")
            count += 1
    if hurt_frames:
        for i, fr in enumerate(hurt_frames):
            fr.save(OUT / f"{base_name}_hurt_{i}.png")
            count += 1
    if death_frames:
        for i, fr in enumerate(death_frames):
            fr.save(OUT / f"{base_name}_death_{i}.png")
            count += 1
    return count


def _hero_base(
    skin: Color,
    robe_dk: Color,
    robe_md: Color,
    robe_lt: Color,
    accent: Color,
    eye_col: Color,
    head_style: str,
    gear_style: str,
    bob_y: int = 0,
    leg_phase: int = 0,
    broad: bool = False,
) -> Canvas:
    """Renders a crisp 32x32 gothic RPG hero with 4-tone shading, rim highlights, and animation."""
    cv = Canvas(32, 32)
    cx = 15
    cv.add_ground_shadow(15.5, 29.0, 8.5 if broad else 6.8, 2.5, 100)

    l_dy = -1 if leg_phase == 1 else (1 if leg_phase == 3 else 0)
    r_dy = -1 if leg_phase == 3 else (1 if leg_phase == 1 else 0)
    boot_dk = c("dark_brown")
    boot_lt = c("leather_lt")
    cv.rect(cx - 4, 24 + l_dy, 3, 4, boot_dk)
    cv.rect(cx - 4, 24 + l_dy, 2, 2, boot_lt)
    cv.rect(cx + 2, 24 + r_dy, 3, 4, boot_dk)
    cv.rect(cx + 2, 24 + r_dy, 2, 2, boot_lt)

    y0 = bob_y
    # Cape / mantle with wind sway
    if head_style in ("mage_hat", "hood", "paladin_helm", "ranger_hood", "void_horns", "witch_hat", "ember_crown"):
        cape_w = 14 if broad else 12
        sway = 1 if leg_phase in (1, 3) else 0
        cv.poly([
            (cx - 5, 13 + y0),
            (cx + 6, 13 + y0),
            (cx + cape_w // 2 + 1 + sway, 26 + y0),
            (cx - cape_w // 2 - sway, 26 + y0),
        ], mul(robe_dk, 0.80))
        cv.line(cx - 5, 14 + y0, cx - cape_w // 2 - sway, 25 + y0, robe_md)

    # Torso & armor layers
    tw = 12 if broad else 10
    tx = cx - tw // 2 + (0 if broad else 1)
    cv.rect(tx, 13 + y0, tw, 12, robe_dk)
    cv.rect(tx + 1, 13 + y0, tw - 2, 10, robe_md)
    cv.rect(tx + 2, 14 + y0, max(2, tw - 5), 5, robe_lt)
    cv.rect(tx, 20 + y0, tw, 2, c("iron_dk"))
    cv.rect(cx - 1, 20 + y0, 3, 2, accent)
    cv.rect(cx - 1, 15 + y0, 2, 4, accent)
    if broad:
        cv.rect(tx - 2, 12 + y0, 4, 4, robe_lt)
        cv.rect(tx + tw - 2, 12 + y0, 4, 4, robe_md)
        cv.px(tx - 1, 13 + y0, accent)
        cv.px(tx + tw - 1, 13 + y0, accent)

    # Arms
    arm_sway = 1 if leg_phase == 1 else (-1 if leg_phase == 3 else 0)
    cv.rect(tx - 2, 14 + y0 + arm_sway, 2, 7, robe_md)
    cv.rect(tx - 2, 20 + y0 + arm_sway, 2, 2, skin)
    cv.rect(tx + tw, 14 + y0 - arm_sway, 2, 7, robe_dk)
    cv.rect(tx + tw, 20 + y0 - arm_sway, 2, 2, skin)

    # Head & Face
    cv.rect(cx - 3, 7 + y0, 7, 7, skin)
    cv.rect(cx - 3, 12 + y0, 7, 2, mul(skin, 0.76))
    cv.px(cx - 1, 10 + y0, eye_col)
    cv.px(cx + 2, 10 + y0, eye_col)

    if head_style == "mage_hat":
        cv.rect(cx - 6, 7 + y0, 13, 2, robe_md)
        cv.poly([(cx - 4, 7 + y0), (cx + 5, 7 + y0), (cx + 2, 1 + y0)], robe_dk)
        cv.line(cx - 3, 6 + y0, cx + 1, 2 + y0, robe_lt)
        cv.rect(cx - 3, 6 + y0, 7, 1, accent)
        cv.poly([(cx - 2, 12 + y0), (cx + 3, 12 + y0), (cx + 1, 17 + y0)], c("bone"))
        cv.px(cx, 13 + y0, c("parchment"))
    elif head_style == "paladin_helm":
        cv.rect(cx - 4, 5 + y0, 9, 8, c("stone_lt"))
        cv.rect(cx - 3, 6 + y0, 7, 3, c("frost"))
        cv.rect(cx - 2, 9 + y0, 5, 1, c("black"))
        cv.px(cx - 1, 9 + y0, eye_col)
        cv.px(cx + 1, 9 + y0, eye_col)
        cv.poly([(cx - 1, 5 + y0), (cx + 2, 5 + y0), (cx + 4, 1 + y0), (cx - 1, 2 + y0)], c("crimson"))
        cv.px(cx + 1, 3 + y0, c("scarlet"))
    elif head_style == "hood":
        cv.poly([(cx - 5, 12 + y0), (cx - 4, 5 + y0), (cx + 4, 5 + y0), (cx + 5, 12 + y0)], robe_dk)
        cv.rect(cx - 3, 7 + y0, 7, 5, c("void"))
        cv.px(cx - 1, 10 + y0, eye_col)
        cv.px(cx + 2, 10 + y0, eye_col)
        cv.rect(cx - 4, 5 + y0, 9, 1, accent)
    elif head_style == "orc_tusks":
        cv.rect(cx - 4, 6 + y0, 9, 2, c("soil_dark"))
        cv.rect(cx + 3, 7 + y0, 2, 5, c("soil"))
        cv.px(cx - 2, 12 + y0, c("parchment"))
        cv.px(cx + 2, 12 + y0, c("parchment"))
        cv.line(cx - 2, 8 + y0, cx, 10 + y0, c("maroon"))
    elif head_style == "ranger_hood":
        cv.poly([(cx - 4, 11 + y0), (cx - 3, 5 + y0), (cx + 4, 5 + y0), (cx + 5, 11 + y0)], robe_dk)
        cv.rect(cx - 2, 7 + y0, 5, 5, skin)
        cv.rect(cx - 5, 8 + y0, 2, 2, skin)
        cv.rect(cx + 4, 8 + y0, 2, 2, skin)
        cv.px(cx - 1, 9 + y0, eye_col)
        cv.px(cx + 2, 9 + y0, eye_col)
        cv.px(cx + 3, 4 + y0, accent)
        cv.px(cx + 4, 3 + y0, accent)
    elif head_style == "cowl_scarf":
        cv.rect(cx - 4, 6 + y0, 9, 7, robe_dk)
        cv.rect(cx - 3, 8 + y0, 7, 3, c("void"))
        cv.px(cx - 1, 9 + y0, eye_col)
        cv.px(cx + 2, 9 + y0, eye_col)
        cv.rect(cx - 3, 11 + y0, 7, 3, accent)
    elif head_style == "goggles":
        cv.rect(cx - 4, 6 + y0, 9, 3, c("leather"))
        cv.rect(cx - 3, 8 + y0, 3, 2, c("amber"))
        cv.rect(cx + 1, 8 + y0, 3, 2, c("amber"))
        cv.px(cx - 2, 8 + y0, c("white"))
        cv.px(cx + 2, 8 + y0, c("white"))
    elif head_style == "witch_hat":
        cv.rect(cx - 6, 7 + y0, 13, 1, c("slate_vd"))
        cv.rect(cx - 3, 3 + y0, 7, 4, c("slate_dk"))
        cv.rect(cx - 3, 6 + y0, 7, 1, c("brass"))
        cv.rect(cx - 3, 11 + y0, 7, 3, c("crimson_dk"))
    elif head_style == "ember_crown":
        cv.rect(cx - 4, 5 + y0, 9, 3, c("iron_dk"))
        for hx in (-3, 0, 3):
            cv.px(cx + hx, 4 + y0, c("flame"))
            cv.px(cx + hx, 3 + y0, c("gold_glow"))
    elif head_style == "void_horns":
        cv.rect(cx - 4, 6 + y0, 9, 7, c("void"))
        cv.line(cx - 3, 6 + y0, cx - 6, 2 + y0, c("frost_dk"))
        cv.line(cx + 4, 6 + y0, cx + 7, 2 + y0, c("frost_dk"))
        cv.px(cx - 1, 9 + y0, c("ember_red"))
        cv.px(cx + 2, 9 + y0, c("ember_red"))

    if gear_style == "staff":
        cv.line(cx + 7, 4 + y0, cx + 7, 27 + y0, c("leather"))
        cv.rect(cx + 6, 3 + y0, 3, 3, accent)
        cv.px(cx + 7, 4 + y0, c("white"))
    elif gear_style == "sword_shield":
        cv.line(cx + 8, 6 + y0, cx + 8, 22 + y0, c("frost"))
        cv.rect(cx + 6, 19 + y0, 5, 1, c("gold"))
        cv.rect(cx - 9, 13 + y0, 4, 9, c("crimson_dk"))
        cv.box_outline(cx - 9, 13 + y0, 4, 9, c("gold"))
    elif gear_style == "grimoire":
        cv.rect(cx - 10, 10 + y0, 5, 6, c("arcane_dk"))
        cv.box_outline(cx - 10, 10 + y0, 5, 6, c("parchment"))
        cv.px(cx - 8, 12 + y0, c("glow_green"))
    elif gear_style == "axe":
        cv.line(cx + 8, 7 + y0, cx + 8, 26 + y0, c("soil"))
        cv.poly([(cx + 7, 7 + y0), (cx + 12, 5 + y0), (cx + 12, 13 + y0), (cx + 7, 11 + y0)], c("frost"))
        cv.line(cx + 12, 6 + y0, cx + 12, 12 + y0, c("white"))
    elif gear_style == "bow_quiver":
        cv.line(cx - 7, 12 + y0, cx - 4, 21 + y0, c("leather"))
        cv.px(cx - 7, 11 + y0, c("parchment"))
        cv.line(cx + 7, 10 + y0, cx + 9, 16 + y0, c("leather_lt"))
        cv.line(cx + 9, 16 + y0, cx + 7, 22 + y0, c("leather_lt"))
        cv.line(cx + 7, 10 + y0, cx + 7, 22 + y0, c("frost"))
    elif gear_style == "daggers":
        cv.line(cx - 8, 19 + y0, cx - 11, 14 + y0, c("frost"))
        cv.line(cx + 8, 19 + y0, cx + 11, 14 + y0, c("frost"))
        cv.px(cx - 11, 14 + y0, accent)
        cv.px(cx + 11, 14 + y0, accent)
    elif gear_style == "tesla":
        cv.rect(cx - 9, 11 + y0, 3, 9, c("bronze"))
        cv.px(cx - 8, 9 + y0, c("ice_glow"))
        cv.px(cx - 7, 8 + y0, c("white"))
    elif gear_style == "rifle":
        cv.line(cx + 5, 18 + y0, cx + 13, 12 + y0, c("iron_dk"))
        cv.px(cx + 13, 12 + y0, c("frost"))
    elif gear_style == "braziers":
        cv.rect(cx - 9, 17 + y0, 3, 4, c("flame"))
        cv.px(cx - 8, 16 + y0, c("gold_glow"))
        cv.rect(cx + 7, 17 + y0, 3, 4, c("flame"))
        cv.px(cx + 8, 16 + y0, c("gold_glow"))
    elif gear_style == "void_halo":
        cv.ring(cx, 6 + y0, 9.5, 8.0, c("violet_lt"), True)

    cv.directional_shade(0.12)
    cv.outline(c("black"))
    return cv


def generate_heroes() -> int:
    specs = [
        ("mage", c("sand_lt"), c("slate_vd"), c("slate_dk"), c("slate"), c("violet_lt"), c("cream"), "mage_hat", "staff", False),
        ("paladin", c("bone"), c("maroon"), c("stone"), c("frost_dk"), c("gold"), c("gold_glow"), "paladin_helm", "sword_shield", True),
        ("necromancer", c("parchment"), c("void"), c("arcane_vd"), c("arcane_dk"), c("violet_lt"), c("glow_green"), "hood", "grimoire", False),
        ("orc", c("moss"), c("soil_dark"), c("leather"), c("bronze"), c("bone"), c("amber"), "orc_tusks", "axe", True),
        ("elf", c("parchment"), c("swamp_dk"), c("moss_dk"), c("moss"), c("ice_lt"), c("ice_glow"), "ranger_hood", "bow_quiver", False),
        ("rogue", c("sand"), c("void"), c("slate_vd"), c("slate_dk"), c("crimson"), c("ember_red"), "cowl_scarf", "daggers", False),
        ("inventor", c("sand_lt"), c("soil_dark"), c("bronze_dk"), c("bronze"), c("amber"), c("white"), "goggles", "tesla", False),
        ("sniper", c("sand"), c("swamp_dk"), c("soil_dark"), c("soil"), c("brass"), c("cream"), "witch_hat", "rifle", False),
        ("pyromancer", c("sand_lt"), c("blood_dk"), c("crimson_dk"), c("lava"), c("amber"), c("gold_glow"), "ember_crown", "braziers", False),
        ("star", c("slate_vd"), c("void"), c("arcane_vd"), c("crimson_dk"), c("ember_red"), c("ember_red"), "void_horns", "void_halo", True),
    ]
    total = 0
    for cls, skin, r_dk, r_md, r_lt, acc, eye, hst, gst, broad in specs:
        idle = [
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=0, leg_phase=0, broad=broad),
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=1, leg_phase=0, broad=broad),
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=0, leg_phase=0, broad=broad),
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=0, leg_phase=0, broad=broad),
        ]
        walk = [
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=0, leg_phase=1, broad=broad),
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=-1, leg_phase=2, broad=broad),
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=0, leg_phase=3, broad=broad),
            _hero_base(skin, r_dk, r_md, r_lt, acc, eye, hst, gst, bob_y=-1, leg_phase=0, broad=broad),
        ]
        total += _save_anim(cls, idle[0], idle, walk)
    return total


def _draw_enemy(kind: str, phase: int = 0) -> Canvas:
    """Every enemy is a crisp, expressive 32x32 gothic pixel-art sprite."""
    cv = Canvas(32, 32)
    cx = 16
    bob = -1 if phase in (1, 3) else 0
    step = 1 if phase == 1 else (-1 if phase == 3 else 0)

    if kind in ("slime", "slime_small"):
        small = kind == "slime_small"
        rx = (7.5 if small else 11.5) * (1.08 if phase in (1, 3) else 0.96)
        ry = (6.0 if small else 9.0) * (0.90 if phase in (1, 3) else 1.08)
        cy = 21 if small else 19
        cv.add_ground_shadow(cx, 28, rx, 2.5, 90)
        cv.ellipse(cx, cy + 1, rx, ry, c("swamp_dk"))
        cv.ellipse(cx, cy, rx * 0.88, ry * 0.86, c("moss_dk"))
        cv.ellipse(cx - 1, cy - 1, rx * 0.68, ry * 0.64, c("moss"))
        cv.ellipse(cx - 2, cy - 2, rx * 0.42, ry * 0.36, c("poison"))
        cv.px(int(cx - rx * 0.35), int(cy - ry * 0.45), c("pale_green"))
        cv.px(int(cx - rx * 0.28), int(cy - ry * 0.35), c("white"))
        if not small:
            # Suspended gothic skull inside gelatinous ooze
            cv.rect(cx - 3, cy, 6, 4, c("parchment"))
            cv.px(cx - 1, cy + 1, c("black"))
            cv.px(cx + 1, cy + 1, c("black"))
            # Dripping tendrils
            cv.rect(cx - 7, cy + 4, 2, 3, c("moss"))
            cv.rect(cx + 5, cy + 5, 2, 2, c("moss"))
        cv.rect(cx - 3, cy - 2, 2, 2, c("ember_red"))
        cv.rect(cx + 2, cy - 2, 2, 2, c("ember_red"))
        cv.outline(c("black"))
        return cv

    if kind == "bat":
        cy = 15 + bob
        cv.add_ground_shadow(cx, 28, 7.5, 2.0, 75)
        wing_y = -6 if phase in (0, 2) else (4 if phase == 1 else -1)
        # Detailed serrated leathery bat wings
        for s in (-1, 1):
            cv.poly([
                (cx + s * 3, cy),
                (cx + s * 13, cy + wing_y - 4),
                (cx + s * 14, cy + wing_y + 3),
                (cx + s * 10, cy + 5),
                (cx + s * 6, cy + 2),
                (cx + s * 3, cy + 4),
            ], c("umber"))
            cv.line(cx + s * 3, cy, cx + s * 13, cy + wing_y - 4, c("leather_lt"))
            cv.line(cx + s * 8, cy + wing_y // 2, cx + s * 10, cy + 5, c("leather"))
        # Furry torso & head
        cv.ellipse(cx, cy + 1, 4.2, 5.5, c("soil_dark"))
        cv.ellipse(cx, cy, 3.0, 4.0, c("soil"))
        cv.poly([(cx - 4, cy - 3), (cx - 5, cy - 8), (cx - 1, cy - 4)], c("umber"))
        cv.poly([(cx + 4, cy - 3), (cx + 5, cy - 8), (cx + 1, cy - 4)], c("umber"))
        cv.rect(cx - 2, cy - 2, 2, 2, c("ember_red"))
        cv.rect(cx + 1, cy - 2, 2, 2, c("ember_red"))
        cv.px(cx - 1, cy + 1, c("parchment"))
        cv.px(cx + 1, cy + 1, c("parchment"))
        cv.outline(c("black"))
        return cv

    if kind == "goblin_archer":
        cv.add_ground_shadow(cx, 29, 7.0, 2.2, 90)
        cv.rect(cx - 4, 23 + step, 3, 5, c("moss_dk"))
        cv.rect(cx + 1, 23 - step, 3, 5, c("moss_dk"))
        # Leather tunic & belt
        cv.rect(cx - 5, 13 + bob, 10, 10, c("soil_dark"))
        cv.rect(cx - 4, 14 + bob, 8, 7, c("leather"))
        cv.rect(cx - 5, 19 + bob, 10, 2, c("iron_dk"))
        cv.px(cx, 19 + bob, c("bronze"))
        # Pointed ears, grin & crimson hood
        cv.rect(cx - 4, 7 + bob, 8, 6, c("moss"))
        cv.poly([(cx - 4, 8 + bob), (cx - 9, 7 + bob), (cx - 4, 11 + bob)], c("moss_dk"))
        cv.poly([(cx + 4, 8 + bob), (cx + 9, 7 + bob), (cx + 4, 11 + bob)], c("moss_dk"))
        cv.poly([(cx - 5, 8 + bob), (cx, 2 + bob), (cx + 5, 8 + bob)], c("crimson_dk"))
        cv.px(cx - 2, 9 + bob, c("amber"))
        cv.px(cx + 2, 9 + bob, c("amber"))
        cv.line(cx - 2, 11 + bob, cx + 2, 11 + bob, c("parchment"))
        # Quiver + curved bow
        cv.line(cx - 7, 11 + bob, cx - 4, 20 + bob, c("sand_dk"), 2)
        cv.line(cx + 6, 8 + bob, cx + 10, 15 + bob, c("leather_lt"), 2)
        cv.line(cx + 10, 15 + bob, cx + 6, 22 + bob, c("leather_lt"), 2)
        cv.line(cx + 6, 8 + bob, cx + 6, 22 + bob, c("bone"))
        cv.line(cx + 4, 15 + bob, cx + 11, 15 + bob, c("frost"))
        cv.outline(c("black"))
        return cv

    if kind == "frozen_zombie":
        cv.add_ground_shadow(cx, 29, 7.5, 2.5, 95)
        cv.rect(cx - 5, 22 + step, 4, 6, c("slate_dk"))
        cv.rect(cx + 1, 22 - step, 4, 6, c("slate_dk"))
        cv.rect(cx - 6, 11 + bob, 12, 12, c("slate"))
        cv.rect(cx - 5, 12 + bob, 10, 9, c("deep_water"))
        cv.poly([(cx - 7, 13 + bob), (cx - 2, 7 + bob), (cx - 1, 15 + bob)], c("ice_lt"))
        cv.poly([(cx + 3, 15 + bob), (cx + 8, 8 + bob), (cx + 7, 18 + bob)], c("frost_blue"))
        cv.rect(cx - 4, 4 + bob, 8, 8, c("frost_dk"))
        cv.rect(cx - 2, 9 + bob, 4, 2, c("void"))
        cv.rect(cx - 3, 6 + bob, 2, 2, c("ice_glow"))
        cv.rect(cx + 1, 6 + bob, 2, 2, c("ice_glow"))
        cv.rect(cx - 10, 13 + bob, 4, 3, c("frost_dk"))
        cv.rect(cx + 6, 13 + bob, 4, 3, c("frost_dk"))
        cv.outline(c("black"))
        return cv

    if kind == "skeleton_warrior":
        cv.add_ground_shadow(cx, 29, 7.0, 2.4, 90)
        cv.rect(cx - 4, 21 + step, 3, 7, c("bone"))
        cv.rect(cx + 1, 21 - step, 3, 7, c("bone"))
        cv.rect(cx - 5, 12 + bob, 10, 9, c("iron_dk"))
        for ry in (13, 15, 17):
            cv.rect(cx - 4, ry + bob, 8, 1, c("parchment"))
        cv.line(cx, 12 + bob, cx, 19 + bob, c("bone"))
        cv.rect(cx - 4, 4 + bob, 8, 8, c("parchment"))
        cv.rect(cx - 2, 10 + bob, 5, 2, c("sand_lt"))
        cv.rect(cx - 3, 7 + bob, 2, 2, c("ember_red"))
        cv.rect(cx + 1, 7 + bob, 2, 2, c("ember_red"))
        # Tower shield + notched broadsword
        cv.rect(cx - 10, 11 + bob, 5, 10, c("iron"))
        cv.box_outline(cx - 10, 11 + bob, 5, 10, c("bronze"))
        cv.line(cx + 7, 5 + bob, cx + 7, 20 + bob, c("snow_dk"), 2)
        cv.rect(cx + 5, 17 + bob, 5, 2, c("bronze"))
        cv.outline(c("black"))
        return cv

    if kind == "dark_mage":
        cv.add_ground_shadow(cx, 29, 7.5, 2.4, 95)
        cv.poly([(cx - 6, 11 + bob), (cx + 6, 11 + bob), (cx + 9, 27 + bob), (cx - 9, 27 + bob)], c("arcane_vd"))
        cv.poly([(cx - 4, 12 + bob), (cx + 4, 12 + bob), (cx + 5, 26 + bob), (cx - 5, 26 + bob)], c("arcane_dk"))
        cv.rect(cx - 1, 14 + bob, 2, 10, c("violet_lt"))
        cv.poly([(cx - 6, 11 + bob), (cx, 3 + bob), (cx + 6, 11 + bob)], c("maroon"))
        cv.line(cx - 4, 6 + bob, cx - 7, 1 + bob, c("bone"))
        cv.line(cx + 4, 6 + bob, cx + 7, 1 + bob, c("bone"))
        cv.rect(cx - 2, 8 + bob, 2, 2, c("ghost_violet"))
        cv.rect(cx + 1, 8 + bob, 2, 2, c("ghost_violet"))
        cv.line(cx + 9, 4 + bob, cx + 9, 26 + bob, c("soil_dark"), 2)
        cv.ellipse(cx + 9, 4 + bob, 2.5, 2.5, c("ghost_violet"))
        cv.outline(c("black"))
        return cv

    if kind == "werewolf":
        cv.add_ground_shadow(cx, 29, 9.0, 2.8, 95)
        cv.rect(cx - 5, 22 + step, 3, 6, c("soil_dark"))
        cv.rect(cx + 2, 22 - step, 3, 6, c("soil_dark"))
        cv.ellipse(cx, 15 + bob, 8.0, 7.5, c("umber"))
        cv.ellipse(cx, 13 + bob, 6.2, 5.2, c("soil"))
        cv.rect(cx - 4, 5 + bob, 8, 7, c("soil"))
        cv.rect(cx - 2, 9 + bob, 6, 3, c("sand_dk"))
        cv.poly([(cx - 5, 7 + bob), (cx - 4, 1 + bob), (cx - 2, 6 + bob)], c("umber"))
        cv.poly([(cx + 2, 6 + bob), (cx + 4, 1 + bob), (cx + 5, 7 + bob)], c("umber"))
        cv.px(cx - 2, 7 + bob, c("amber"))
        cv.px(cx + 1, 7 + bob, c("amber"))
        cv.rect(cx - 11, 14 + bob, 3, 5, c("soil_dark"))
        cv.line(cx - 11, 19 + bob, cx - 12, 23 + bob, c("parchment"))
        cv.line(cx - 9, 19 + bob, cx - 10, 23 + bob, c("parchment"))
        cv.rect(cx + 8, 14 + bob, 3, 5, c("soil_dark"))
        cv.line(cx + 10, 19 + bob, cx + 11, 23 + bob, c("parchment"))
        cv.outline(c("black"))
        return cv

    if kind == "demon":
        cv.add_ground_shadow(cx, 29, 8.0, 2.5, 95)
        for s in (-1, 1):
            cv.poly([(cx + s * 3, 12 + bob), (cx + s * 13, 5 + bob), (cx + s * 11, 18 + bob)], c("blood_dk"))
            cv.line(cx + s * 3, 12 + bob, cx + s * 13, 5 + bob, c("crimson"))
        cv.line(cx + 5, 22 + bob, cx + 11, 25 + bob, c("crimson"), 2)
        cv.px(cx + 12, 23 + bob, c("scarlet"))
        cv.rect(cx - 5, 11 + bob, 10, 11, c("crimson_dk"))
        cv.rect(cx - 4, 12 + bob, 8, 7, c("crimson"))
        cv.rect(cx - 4, 5 + bob, 8, 7, c("blood"))
        cv.line(cx - 3, 5 + bob, cx - 7, 1 + bob, c("bone"), 2)
        cv.line(cx + 3, 5 + bob, cx + 7, 1 + bob, c("bone"), 2)
        cv.rect(cx - 2, 7 + bob, 2, 2, c("gold_glow"))
        cv.rect(cx + 1, 7 + bob, 2, 2, c("gold_glow"))
        cv.rect(cx - 4, 22 + step, 3, 5, c("blood_dk"))
        cv.rect(cx + 1, 22 - step, 3, 5, c("blood_dk"))
        cv.outline(c("black"))
        return cv

    # fallen_angel
    cv.add_ground_shadow(cx, 29, 8.0, 2.5, 95)
    wing_dy = -1 if phase in (1, 3) else 0
    cv.poly([(cx - 3, 12 + bob), (cx - 14, 5 + wing_dy), (cx - 12, 18 + wing_dy), (cx - 4, 18 + bob)], c("frost"))
    cv.poly([(cx + 3, 12 + bob), (cx + 14, 5 + wing_dy), (cx + 12, 18 + wing_dy), (cx + 4, 18 + bob)], c("frost"))
    cv.line(cx - 13, 10 + wing_dy, cx - 10, 17 + wing_dy, c("crimson"))
    cv.line(cx + 13, 10 + wing_dy, cx + 10, 17 + wing_dy, c("crimson"))
    cv.poly([(cx - 4, 11 + bob), (cx + 4, 11 + bob), (cx + 6, 26 + bob), (cx - 6, 26 + bob)], c("parchment"))
    cv.rect(cx - 2, 13 + bob, 4, 10, c("crimson_dk"))
    cv.rect(cx - 3, 6 + bob, 6, 5, c("bone"))
    cv.px(cx - 1, 8 + bob, c("ember_red"))
    cv.px(cx + 1, 8 + bob, c("ember_red"))
    cv.line(cx - 4, 3 + bob, cx + 3, 3 + bob, c("gold"))
    cv.px(cx, 3 + bob, (0, 0, 0, 0))
    cv.outline(c("black"))
    return cv


def _biome_themes() -> dict:
    return {
        "sands":     (c("sand"), c("bronze"), c("amber"), "desert"),
        "tundra":    (c("ice_blue"), c("frost_blue"), c("ice_glow"), "frost"),
        "peak":      (c("stone_dk"), c("lava"), c("gold_glow"), "magma"),
        "abyss":     (c("slate_dk"), c("violet_lt"), c("ghost_violet"), "crystal"),
        "forest":    (c("moss_dk"), c("moss"), c("amber"), "forest"),
        "rift":      (c("arcane_dk"), c("violet_lt"), c("ember_red"), "rift"),
        "graveyard": (c("stone"), c("moss"), c("glow_green"), "grave"),
        "hive":      (c("swamp_dk"), c("poison"), c("pale_green"), "hive"),
        "bloodmoon": (c("crimson_dk"), c("crimson"), c("ember_red"), "blood"),
        "chaos":     (c("arcane"), c("gold"), c("ice_glow"), "chaos"),
        "temple":    (c("sand_dk"), c("gold"), c("ice_glow"), "temple"),
        "throne":    (c("slate_vd"), c("crimson"), c("gold_glow"), "infernal"),
        "void":      (c("#1b1326"), c("violet_lt"), c("ember_red"), "void"),
    }



def _biome_rim(cv: Canvas, acc_c) -> None:
    """Подсветка силуэта со стороны света — читаемость на тёмном фоне любой карты."""
    edge = []
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.get(x, y)[3] < 180:
                continue
            if cv.get(x - 1, y)[3] < 60 or cv.get(x, y - 1)[3] < 60:
                edge.append((x, y))
    for x, y in edge:
        cv.px(x, y, (acc_c[0], acc_c[1], acc_c[2], 96), True)


def _solid(cv: Canvas, x: int, y: int) -> bool:
    return cv.get(x, y)[3] >= 150


def _kind_details(cv: Canvas, kind: str, prop: str, tint_c, acc_c, eye_c, bob: int) -> None:
    """Детали поверх силуэта: у каждого врага свои признаки, плюс приметы биома."""
    cx = 16
    cy = 20 + bob
    if kind in ("slime", "slime_small"):
        small = kind == "slime_small"
        # блики желе и пузырьки
        for bx, by in ((cx - 5, cy - 5), (cx + 4, cy - 3), (cx + 1, cy + 4)):
            if 0 <= bx < cv.w and 0 <= by < cv.h and _solid(cv, bx, by):
                cv.px(bx, by, (255, 255, 255, 110), True)
        if _solid(cv, cx - 2, cy + 2):
            cv.px(cx - 2, cy + 2, eye_c)
        if prop == "frost":
            cv.px(cx, cy - 8, c("snow_lt"))
            cv.px(cx - 1, cy - 7, acc_c)
    elif kind == "goblin_archer":
        # колчан за спиной
        for i in range(3):
            cv.line(cx - 9 + i, cy - 10, cx - 6 + i, cy - 16, c("leather_lt"))
            cv.px(cx - 6 + i, cy - 16, acc_c)
        cv.px(cx + 2, cy - 5, eye_c)
        if _solid(cv, cx, cy + 1):
            cv.px(cx, cy + 1, c("gold"))
        cv.px(cx - 4, cy - 2, eye_c)
    elif kind == "frozen_zombie":
        for i, (sx, sy) in enumerate(((cx - 7, cy - 8), (cx + 6, cy - 7), (cx + 2, cy - 12))):
            cv.line(sx, sy, sx, sy - 3, c("snow_lt"))
            cv.px(sx, sy - 4, c("ice_glow"))
        cv.px(cx - 3, cy - 4, c("ice_glow"))
        cv.px(cx + 3, cy - 4, c("ice_glow"))
        if prop == "magma":
            cv.px(cx, cy + 4, c("lava"))
    elif kind == "bat":
        for sgn in (-1, 1):
            cv.line(cx + sgn * 4, cy - 2, cx + sgn * 9, cy - 5, mul(acc_c, 0.7))
            cv.line(cx + sgn * 5, cy, cx + sgn * 10, cy - 2, mul(acc_c, 0.55))
        cv.px(cx - 1, cy + 5, c("white"))
        cv.px(cx + 1, cy + 5, c("white"))
        cv.px(cx - 4, cy - 4, eye_c)
        cv.px(cx + 4, cy - 4, eye_c)
    elif kind == "skeleton_warrior":
        for i in range(3):
            cv.px(cx - 3 + i * 3, cy + 1, c("bone"))
        cv.px(cx - 6, cy - 2, acc_c)
        cv.px(cx + 6, cy - 2, acc_c)
        cv.line(cx + 8, cy - 6, cx + 10, cy - 12, c("iron"))
        cv.px(cx + 10, cy - 13, eye_c)
        cv.px(cx - 2, cy - 5, eye_c)
    elif kind == "dark_mage":
        for i in range(3):
            cv.px(cx - 5 + i * 4, cy + 5, acc_c)
        cv.px(cx - 1, cy - 7, eye_c)
        cv.px(cx + 1, cy - 7, eye_c)
        cv.px(cx + 8, cy - 10, eye_c)
        cv.px(cx + 8, cy - 11, c("white"))
    elif kind == "werewolf":
        for i in range(4):
            cv.px(cx - 6 + i * 4, cy - 9 - (i % 2), mul(acc_c, 0.9))
        cv.px(cx - 3, cy + 6, c("bone"))
        cv.px(cx, cy + 6, c("bone"))
        cv.px(cx + 3, cy + 6, c("bone"))
        cv.px(cx - 3, cy - 4, eye_c)
        cv.px(cx + 3, cy - 4, eye_c)
    elif kind == "demon":
        cv.px(cx - 5, cy - 11, eye_c)
        cv.px(cx + 5, cy - 11, eye_c)
        cv.px(cx - 2, cy + 1, c("lava"))
        cv.px(cx + 2, cy + 2, c("gold_glow"))
        cv.line(cx + 7, cy + 4, cx + 9, cy + 9, mul(acc_c, 0.9))
    elif kind == "fallen_angel":
        # обломок нимба
        cv.line(cx - 6, cy - 13, cx + 6, cy - 13, acc_c)
        cv.px(cx - 7, cy - 12, acc_c)
        cv.px(cx + 7, cy - 12, acc_c)
        for sgn in (-1, 1):
            cv.line(cx + sgn * 7, cy - 4, cx + sgn * 11, cy + 3, mul(acc_c, 0.8))
        cv.px(cx - 2, cy - 5, eye_c)
        cv.px(cx + 2, cy - 5, eye_c)
    # общие приметы биома
    if prop == "void":
        cv.px(cx - 8, cy + 8, (0, 0, 0, 180), True)
        cv.px(cx + 8, cy + 6, (0, 0, 0, 160), True)
    elif prop == "infernal":
        cv.px(cx - 9, cy + 7, c("ember_red"))
        cv.px(cx + 9, cy + 5, c("lava"))


def _draw_themed_enemy(kind: str, map_id: str, phase: int = 0) -> Canvas:
    cv = _draw_enemy(kind, phase)
    themes = _biome_themes()
    if map_id not in themes:
        return cv
    tint_c, acc_c, eye_c, prop = themes[map_id]
    # Shift non-black interior pixels toward the biome palette while preserving contrast & shading
    for y in range(cv.h):
        for x in range(cv.w):
            r, g, b, a = cv.get(x, y)
            if a < 180:
                continue
            if r + g + b <= 45:
                continue  # preserve black outline
            nr = int(r * 0.56 + tint_c[0] * 0.44)
            ng = int(g * 0.56 + tint_c[1] * 0.44)
            nb = int(b * 0.56 + tint_c[2] * 0.44)
            cv.buf[y * cv.w + x] = (min(255, nr), min(255, ng), min(255, nb), a)

    cx = 16
    bob = -1 if phase in (1, 3) else 0
    if prop == "desert":
        cv.rect(cx - 4, 5 + bob, 8, 2, c("sand_lt"))
        cv.px(cx, 5 + bob, c("gold"))
        cv.px(cx - 6, 15 + bob, acc_c)
        cv.px(cx + 6, 15 + bob, acc_c)
    elif prop == "frost":
        cv.line(cx - 5, 6 + bob, cx - 7, 2 + bob, acc_c)
        cv.line(cx + 5, 6 + bob, cx + 7, 2 + bob, acc_c)
        cv.px(cx, 3 + bob, c("snow_lt"))
        cv.px(cx - 2, 9 + bob, eye_c)
        cv.px(cx + 2, 9 + bob, eye_c)
    elif prop == "magma":
        cv.px(cx - 2, 14 + bob, acc_c)
        cv.px(cx + 1, 16 + bob, acc_c)
        cv.px(cx, 18 + bob, eye_c)
        cv.px(cx - 3, 4 + bob, acc_c)
        cv.px(cx + 3, 4 + bob, eye_c)
    elif prop == "crystal":
        cv.poly([(cx - 5, 7 + bob), (cx - 7, 2 + bob), (cx - 3, 5 + bob)], acc_c)
        cv.poly([(cx + 5, 7 + bob), (cx + 7, 2 + bob), (cx + 3, 5 + bob)], acc_c)
        cv.px(cx, 15 + bob, eye_c)
    elif prop == "forest":
        cv.rect(cx - 3, 4 + bob, 6, 2, acc_c)
        cv.px(cx - 5, 13 + bob, c("moss"))
        cv.px(cx + 5, 14 + bob, c("crimson"))
    elif prop == "rift":
        cv.px(cx, 3 + bob, eye_c)
        cv.px(cx - 7, 11 + bob, acc_c)
        cv.px(cx + 7, 11 + bob, acc_c)
        cv.px(cx, 16 + bob, acc_c)
    elif prop == "grave":
        cv.px(cx - 7, 9 + bob, eye_c)
        cv.px(cx + 7, 12 + bob, eye_c)
        cv.rect(cx - 3, 15 + bob, 6, 1, c("moss"))
    elif prop == "hive":
        cv.px(cx - 4, 13 + bob, acc_c)
        cv.px(cx + 4, 16 + bob, acc_c)
        cv.px(cx - 2, 4 + bob, acc_c)
        cv.px(cx + 2, 4 + bob, acc_c)
        cv.px(cx - 1, 9 + bob, eye_c)
        cv.px(cx + 2, 9 + bob, eye_c)
    elif prop == "blood":
        cv.line(cx - 4, 5 + bob, cx - 6, 2 + bob, acc_c)
        cv.line(cx + 4, 5 + bob, cx + 6, 2 + bob, acc_c)
        cv.px(cx - 2, 12 + bob, acc_c)
        cv.px(cx + 2, 12 + bob, acc_c)
    elif prop == "chaos":
        cv.px(cx - 6, 5 + bob, eye_c)
        cv.px(cx + 6, 6 + bob, acc_c)
        cv.px(cx - 7, 18 + bob, acc_c)
        cv.px(cx + 7, 15 + bob, eye_c)
    elif prop == "temple":
        cv.rect(cx - 4, 4 + bob, 8, 2, acc_c)
        cv.px(cx, 3 + bob, eye_c)
        cv.rect(cx - 5, 14 + bob, 2, 3, acc_c)
        cv.rect(cx + 3, 14 + bob, 2, 3, acc_c)
    elif prop == "infernal":
        cv.rect(cx - 7, 12 + bob, 3, 3, acc_c)
        cv.rect(cx + 4, 12 + bob, 3, 3, acc_c)
        cv.px(cx - 3, 4 + bob, eye_c)
        cv.px(cx + 3, 4 + bob, eye_c)
    elif prop == "void":
        cv.line(cx - 5, 3 + bob, cx + 5, 3 + bob, acc_c)
        cv.px(cx, 3 + bob, (0, 0, 0, 0))
        cv.px(cx - 2, 9 + bob, eye_c)
        cv.px(cx + 2, 9 + bob, eye_c)
    _kind_details(cv, kind, prop, tint_c, acc_c, eye_c, bob)
    _biome_rim(cv, acc_c)
    cv.outline(c("black"))
    return cv


def generate_enemies() -> int:
    total = 0
    enemies = [
        "slime", "slime_small", "goblin_archer", "frozen_zombie",
        "bat", "skeleton_warrior", "dark_mage", "werewolf",
        "demon", "fallen_angel",
    ]
    for kind in enemies:
        idle = [_draw_enemy(kind, 0), _draw_enemy(kind, 2)]
        walk = [_draw_enemy(kind, p) for p in range(4)]
        total += _save_anim(kind, idle[0], idle, walk)

    # Облик для каждой карты: у всех врагов свой облик на каждом биоме
    # (даже если карта пока не спавнит этого врага — ростеры меняются).
    maps = json.loads((ROOT / "data" / "maps.json").read_text(encoding="utf-8"))
    for m in maps:
        mid = m["id"]
        for eid in sorted(enemies):
            idle = [_draw_themed_enemy(eid, mid, 0), _draw_themed_enemy(eid, mid, 2)]
            walk = [_draw_themed_enemy(eid, mid, p) for p in range(4)]
            total += _save_anim(f"{eid}__{mid}", idle[0], idle, walk)
    return total


def _draw_miniboss(mb_id: str) -> Canvas:
    cv = Canvas(48, 48)
    cx, cy = 24, 24
    cv.add_ground_shadow(cx, 44, 15.0, 4.0, 105)

    themes = {
        "mb_sands": ("scorpion", c("sand_dk"), c("bronze"), c("amber")),
        "mb_tundra": ("yeti", c("snow_dk"), c("ice_blue"), c("ice_glow")),
        "mb_peak": ("magma", c("stone_dk"), c("lava"), c("gold_glow")),
        "mb_abyss": ("watcher", c("slate_dk"), c("violet"), c("ghost_violet")),
        "mb_forest": ("treant", c("soil_dark"), c("moss"), c("amber")),
        "mb_rift": ("aberration", c("arcane_vd"), c("violet_lt"), c("ember_red")),
        "mb_graveyard": ("bone_golem", c("bone"), c("parchment"), c("glow_green")),
        "mb_hive": ("brood", c("swamp_dk"), c("poison"), c("pale_green")),
        "mb_bloodmoon": ("nosferatu", c("blood_dk"), c("crimson"), c("ember_red")),
        "mb_chaos": ("hydra", c("arcane_dk"), c("scarlet"), c("gold_glow")),
        "mb_temple": ("idol", c("bronze_dk"), c("gold"), c("ice_glow")),
        "mb_throne": ("blackguard", c("slate_vd"), c("iron"), c("crimson")),
        "mb": ("blackguard", c("stone_dk"), c("iron"), c("ember_red")),
    }
    arch, body_c, sec_c, eye_c = themes.get(mb_id, themes["mb"])

    if arch == "scorpion":
        cv.ellipse(cx, cy + 4, 11, 9, body_c)
        cv.ellipse(cx, cy + 2, 8, 6, sec_c)
        for i, (tx, ty) in enumerate([(24, 14), (27, 9), (24, 5), (19, 6)]):
            cv.ellipse(tx, ty, 3 - i * 0.2, 3 - i * 0.2, sec_c)
        cv.px(17, 7, c("crimson"))
        cv.ellipse(cx - 14, cy + 2, 5, 4, sec_c)
        cv.ellipse(cx + 14, cy + 2, 5, 4, sec_c)
        cv.px(cx - 3, cy + 1, eye_c)
        cv.px(cx + 3, cy + 1, eye_c)
    elif arch == "treant":
        cv.rect(cx - 7, 18, 14, 23, body_c)
        cv.ellipse(cx, 13, 15, 9, sec_c)
        cv.ellipse(cx - 7, 16, 7, 6, c("moss_dk"))
        cv.ellipse(cx + 7, 16, 7, 6, c("moss_dk"))
        cv.line(cx - 8, 39, cx - 13, 43, body_c, 2)
        cv.line(cx + 8, 39, cx + 13, 43, body_c, 2)
        cv.rect(cx - 4, 21, 2, 2, eye_c)
        cv.rect(cx + 2, 21, 2, 2, eye_c)
    elif arch == "watcher":
        cv.ellipse(cx, cy, 12, 12, body_c)
        cv.ellipse(cx, cy, 7, 7, sec_c)
        cv.ellipse(cx, cy, 4, 4, c("black"))
        cv.px(cx, cy, eye_c)
        for ang in range(0, 360, 45):
            rad = math.radians(ang)
            ex = int(cx + math.cos(rad) * 18)
            ey = int(cy + math.sin(rad) * 18)
            cv.line(int(cx + math.cos(rad) * 10), int(cy + math.sin(rad) * 10), ex, ey, sec_c, 2)
            cv.px(ex, ey, eye_c)
    elif arch in ("hydra", "aberration"):
        cv.ellipse(cx, cy + 6, 12, 10, body_c)
        for hx, hy in [(cx - 10, 10), (cx, 6), (cx + 10, 10)]:
            cv.line(cx, cy, hx, hy + 4, body_c, 3)
            cv.ellipse(hx, hy, 4, 4, sec_c)
            cv.px(hx - 1, hy, eye_c)
            cv.px(hx + 1, hy, eye_c)
    elif arch == "nosferatu":
        cv.poly([(cx - 4, 15), (cx - 18, 8), (cx - 15, 32), (cx - 5, 28)], c("maroon"))
        cv.poly([(cx + 4, 15), (cx + 18, 8), (cx + 15, 32), (cx + 5, 28)], c("maroon"))
        cv.rect(cx - 6, 14, 12, 24, body_c)
        cv.rect(cx - 4, 7, 8, 7, c("bone"))
        cv.px(cx - 2, 10, eye_c)
        cv.px(cx + 2, 10, eye_c)
        cv.px(cx - 2, 12, c("white"))
        cv.px(cx + 2, 12, c("white"))
    else:
        cv.rect(cx - 10, 14, 20, 20, body_c)
        cv.rect(cx - 8, 16, 16, 14, sec_c)
        cv.rect(cx - 14, 15, 5, 13, body_c)
        cv.rect(cx + 9, 15, 5, 13, body_c)
        cv.rect(cx - 7, 34, 5, 8, body_c)
        cv.rect(cx + 2, 34, 5, 8, body_c)
        cv.rect(cx - 5, 6, 10, 9, sec_c)
        cv.line(cx - 4, 6, cx - 8, 2, eye_c, 2)
        cv.line(cx + 4, 6, cx + 8, 2, eye_c, 2)
        cv.rect(cx - 3, 9, 2, 2, eye_c)
        cv.rect(cx + 1, 9, 2, 2, eye_c)
        cv.rect(cx - 2, 20, 4, 5, eye_c)

    cv.outline(c("black"))
    return cv


def generate_minibosses() -> int:
    ids = [
        "mb", "mb_sands", "mb_tundra", "mb_peak", "mb_abyss", "mb_forest",
        "mb_rift", "mb_graveyard", "mb_hive", "mb_bloodmoon", "mb_chaos",
        "mb_temple", "mb_throne",
    ]
    for mb_id in ids:
        _draw_miniboss(mb_id).save(OUT / f"{mb_id}.png")
    return len(ids)


# ------------------------------------------------------------------ 128x128 / 160x160 DETAILED BOSSES + FULL SPEC ANIMATIONS
def _draw_feathered_wing(
    cv: Canvas,
    ox: int,
    oy: int,
    side: int,
    span_x: int,
    top_y: int,
    bot_y: int,
    base_c: Color,
    edge_c: Color,
    trim_c: Color,
    feathers: int = 6,
) -> None:
    """Draws a curved, organic feathered wing with angled primary feathers and golden/crimson rim."""
    mid_x = ox + side * int(span_x * 0.52)
    mid_y = int((oy + top_y) * 0.5) - 6
    tip_x = ox + side * span_x
    # Arching wing bone
    cv.line(ox, oy, mid_x, mid_y, edge_c, 3)
    cv.line(mid_x, mid_y, tip_x, top_y, edge_c, 3)
    cv.line(ox, oy - 1, mid_x, mid_y - 1, trim_c, 1)
    cv.line(mid_x, mid_y - 1, tip_x, top_y - 1, trim_c, 1)
    # Angled overlapping feathers fanning outward
    for fi in range(feathers):
        t = (fi + 0.5) / float(feathers)
        if t < 0.5:
            u = t * 2.0
            rx = int(ox + (mid_x - ox) * u)
            ry = int(oy + (mid_y - oy) * u)
        else:
            u = (t - 0.5) * 2.0
            rx = int(mid_x + (tip_x - mid_x) * u)
            ry = int(mid_y + (top_y - mid_y) * u)
        flen = int((bot_y - oy) * (0.65 + 0.55 * t) + 12)
        fx_tip = int(rx + side * (6 + int(8 * t)))
        fy_tip = ry + flen
        fc = base_c if fi % 2 == 0 else mul(base_c, 1.22)
        cv.poly([
            (rx - side * 3, ry + 1),
            (rx + side * 4, ry + 2),
            (fx_tip + side * 2, fy_tip),
            (fx_tip - side * 5, fy_tip - 5),
        ], fc)
        cv.line(rx + side * 3, ry + 2, fx_tip + side * 1, fy_tip - 1, trim_c, 1)


def _draw_armored_torso(
    cv: Canvas,
    bx: int,
    y_top: int,
    w: int,
    h: int,
    armor_dk: Color,
    armor_md: Color,
    armor_lt: Color,
    trim_c: Color,
    core_c: Color,
) -> None:
    """Draws a tapered, beveled dark-fantasy cuirass with waist, belt, and glowing core."""
    hw = w // 2
    ww = max(6, int(hw * 0.68))
    # Tapered breastplate silhouette
    cv.poly([
        (bx - hw, y_top),
        (bx + hw, y_top),
        (bx + ww, y_top + h),
        (bx - ww, y_top + h),
    ], armor_dk)
    cv.poly([
        (bx - hw + 3, y_top + 2),
        (bx + hw - 3, y_top + 2),
        (bx + ww - 2, y_top + h - 3),
        (bx - ww + 2, y_top + h - 3),
    ], armor_md)
    # Lit chest plates (left/right pectoral bevels)
    cv.poly([
        (bx - hw + 5, y_top + 4),
        (bx - 2, y_top + 4),
        (bx - 3, y_top + h // 2),
        (bx - hw + 6, y_top + h // 2 - 2),
    ], armor_lt)
    cv.poly([
        (bx + 2, y_top + 4),
        (bx + hw - 5, y_top + 4),
        (bx + hw - 6, y_top + h // 2 - 2),
        (bx + 3, y_top + h // 2),
    ], mix(armor_md, armor_lt, 0.55))
    # Central trim & waist belt
    cv.line(bx, y_top + 2, bx, y_top + h - 2, trim_c, 2)
    cv.rect(bx - ww - 1, y_top + h - 6, ww * 2 + 2, 5, trim_c)
    cv.rect(bx - 4, y_top + h - 7, 8, 7, mul(trim_c, 1.25))
    # Glowing core sigil
    cv.ellipse(bx, y_top + int(h * 0.36), 6, 6, mul(trim_c, 0.85))
    cv.ellipse(bx, y_top + int(h * 0.36), 4, 4, core_c)
    cv.px(bx - 1, y_top + int(h * 0.36) - 1, c("white"))


def _boss_frame(
    boss_id: str,
    state: str,
    frame_idx: int,
) -> Canvas:
    """Renders a detailed 128x128 (or 160x160 for Satanail/Satan) boss frame."""
    is_mega_boss = boss_id in ("boss_satanail", "boss_satan")
    S = 160 if is_mega_boss else 128
    sc = S / 128.0
    cv = Canvas(S, S)
    cx = S // 2
    bob = 0
    wing_spread = 0
    arm_raise = 0
    lean_x = 0
    step_l = 0
    step_r = 0

    if state == "idle":
        bob = int((0, -4, 0, 3)[frame_idx % 4] * sc)
        wing_spread = int((0, 6, 2, 11)[frame_idx % 4] * sc)
    elif state == "walk":
        bob = int((-3, 0, -4, 0)[frame_idx % 4] * sc)
        wing_spread = int((8, 2, 10, 4)[frame_idx % 4] * sc)
        step_l = int((-5, 2, -2, 0)[frame_idx % 4] * sc)
        step_r = int((5, -4, 2, 0)[frame_idx % 4] * sc)
    elif state == "attack":
        arm_raise = int((-16, 6, -4, 0)[frame_idx % 4] * sc)
        wing_spread = int((4, 15, 8, 0)[frame_idx % 4] * sc)
        lean_x = int((-4, 8, 4, 0)[frame_idx % 4] * sc)
    elif state == "hurt":
        lean_x = int((-6, -12, -3)[frame_idx % 3] * sc)
        bob = int((3, 5, 1)[frame_idx % 3] * sc)
    elif state == "death":
        if frame_idx == 4:
            for k in range(22):
                px = int(cx + math.cos(k * 0.7) * (18 + k * 2) * sc)
                py = int(S * 0.58 + math.sin(k * 1.3) * 24 * sc)
                col = c("gold_glow") if boss_id == "boss_satanail" else (c("#ff1493") if boss_id == "boss_satan" else c("flame"))
                cv.rect(px, py, 3, 3, col)
            return cv

    collapse_y = 0
    if state == "death":
        collapse_y = int((12, 26, 36, 42)[min(3, frame_idx)] * sc)

    bx = cx + lean_x
    by = bob + collapse_y

    # Palette & archetype
    if boss_id == "boss_satanail":
        body_c, sec_c, lt_c, eye_c, wing_c, aura_c, form = (
            c("crimson_dk"), c("gold"), c("crimson"), c("#ff1493"), c("slate_vd"), c("gold_glow"), "seraph"
        )
    elif boss_id == "boss_satan":
        body_c, sec_c, lt_c, eye_c, wing_c, aura_c, form = (
            c("blood_vd"), c("crimson"), c("ember_red"), c("white"), c("void"), c("#ff1493"), "satan"
        )
    elif boss_id == "boss_shemhaz":
        body_c, sec_c, lt_c, eye_c, wing_c, aura_c, form = (
            c("crimson_dk"), c("slate_vd"), c("crimson"), c("ember_red"), c("slate_vd"), c("flame"), "shemhaz"
        )
    else:
        styles = {
            "boss_sands": (c("sand_dk"), c("gold"), c("sand_lt"), c("amber"), c("bronze"), c("gold_glow"), "pharaoh"),
            "boss_tundra": (c("frost_dk"), c("ice_blue"), c("frost"), c("ice_glow"), c("snow_dk"), c("ice_glow"), "frost_titan"),
            "boss_peak": (c("stone_dk"), c("lava"), c("stone"), c("gold_glow"), c("maroon"), c("flame"), "magma_titan"),
            "boss_abyss": (c("slate_vd"), c("violet"), c("violet_lt"), c("ghost_violet"), c("arcane_vd"), c("violet_lt"), "abyss_lord"),
            "boss_forest": (c("soil_dark"), c("moss"), c("life"), c("amber"), c("moss_dk"), c("glow_green"), "treant_king"),
            "boss_rift": (c("arcane_vd"), c("violet_lt"), c("frost"), c("ember_red"), c("arcane_dk"), c("ghost_violet"), "rift_knight"),
            "boss_graveyard": (c("slate_vd"), c("arcane"), c("bone"), c("glow_green"), c("slate_dk"), c("glow_green"), "lich_king"),
            "boss_hive": (c("swamp_dk"), c("poison"), c("life"), c("pale_green"), c("moss_dk"), c("glow_green"), "brood_queen"),
            "boss_bloodmoon": (c("blood_dk"), c("crimson"), c("frost"), c("ember_red"), c("maroon"), c("ember_red"), "vampire_lord"),
            "boss_chaos": (c("arcane_dk"), c("scarlet"), c("violet_lt"), c("ice_glow"), c("crimson_dk"), c("violet_lt"), "chaos_titan"),
            "boss_temple": (c("bronze_dk"), c("gold"), c("parchment"), c("ice_glow"), c("stone"), c("gold_glow"), "hierophant"),
            "boss_throne": (c("slate_vd"), c("gold"), c("iron"), c("ember_red"), c("crimson_dk"), c("gold"), "usurper"),
            "boss_champion": (c("stone_dk"), c("crimson"), c("iron"), c("gold_glow"), c("maroon"), c("flame"), "usurper"),
        }
        body_c, sec_c, lt_c, eye_c, wing_c, aura_c, form = styles.get(boss_id, styles["boss_champion"])

    def sx(v: float) -> int:
        return int(round(v * sc))

    # Ground shadow
    if not (state == "death" and frame_idx >= 3):
        cv.add_ground_shadow(bx, S - sx(9), sx(42) + wing_spread // 2, sx(9), 115)

    # Aura ring on idle 1/3, walk, or attack
    if (state == "idle" and frame_idx in (1, 3)) or state == "walk":
        ar = sx(48) + (sx(6) if frame_idx == 3 else 0)
        cv.ring(bx, S // 2 + by, ar, ar - sx(3), (aura_c[0], aura_c[1], aura_c[2], 75), True)

    # Flowing royal / vampire cape behind body
    if form in ("seraph", "satan", "vampire_lord", "usurper", "lich_king", "hierophant") and not (state == "death" and frame_idx >= 2):
        cape_c = c("maroon") if form in ("seraph", "vampire_lord") else (c("void") if form == "satan" else mul(body_c, 0.72))
        sway = sx(4) if (state == "walk" and frame_idx in (1, 3)) else 0
        cv.poly([
            (bx - sx(18), sx(40) + by),
            (bx + sx(18), sx(40) + by),
            (bx + sx(32) + sway, sx(112) + by),
            (bx + sx(12), sx(104) + by),
            (bx, sx(114) + by),
            (bx - sx(12), sx(104) + by),
            (bx - sx(32) - sway, sx(112) + by),
        ], cape_c)
        cv.line(bx - sx(18), sx(42) + by, bx - sx(31) - sway, sx(110) + by, sec_c, 2)
        cv.line(bx + sx(18), sx(42) + by, bx + sx(31) + sway, sx(110) + by, sec_c, 2)

    # Wings (6-winged Seraph for Satanail/Satan, Demon Wings for Shemhaz, Vampire/Chitin/Rift wings)
    if not (state == "death" and frame_idx >= 2):
        if form in ("seraph", "satan"):
            # 3 pairs of massive fallen-seraph wings!
            w_trim = c("gold_lt") if form == "seraph" else c("ember_red")
            w_edge = c("gold") if form == "seraph" else c("crimson")
            for s in (-1, 1):
                # Upper grand wing
                _draw_feathered_wing(cv, bx + s * sx(14), sx(44) + by, s, sx(52) + wing_spread,
                                     sx(10) - wing_spread // 2 + by, sx(56) + by, wing_c, w_edge, w_trim, 7)
                # Middle wing
                _draw_feathered_wing(cv, bx + s * sx(13), sx(54) + by, s, sx(44) + wing_spread // 2,
                                     sx(34) + by, sx(78) + by, mix(wing_c, body_c, 0.35), w_edge, w_trim, 5)
                # Lower shadow wing
                _draw_feathered_wing(cv, bx + s * sx(10), sx(66) + by, s, sx(32),
                                     sx(62) + by, sx(96) + by, mul(wing_c, 0.78), c("crimson_dk"), w_trim, 4)
        elif form == "shemhaz":
            ws = sx(48) + wing_spread
            wy_top = sx(14) - wing_spread // 2 + by
            for s in (-1, 1):
                cv.poly([
                    (bx + s * sx(14), sx(46) + by),
                    (bx + s * ws, wy_top),
                    (bx + s * (ws - sx(6)), sx(48) + by),
                    (bx + s * (ws - sx(14)), sx(72) + by),
                    (bx + s * sx(14), sx(68) + by),
                ], wing_c)
                cv.line(bx + s * sx(14), sx(46) + by, bx + s * ws, wy_top, c("slate_vd"), 3)
                cv.line(bx + s * ws, wy_top, bx + s * (ws - sx(14)), sx(72) + by, c("crimson"), 2)
                cv.line(bx + s * sx(28), sx(42) + by, bx + s * (ws - sx(6)), sx(50) + by, c("crimson_dk"), 2)
        elif form in ("vampire_lord", "usurper", "chaos_titan"):
            ws = sx(42) + wing_spread
            for s in (-1, 1):
                _draw_feathered_wing(cv, bx + s * sx(12), sx(46) + by, s, ws,
                                     sx(22) - wing_spread // 2 + by, sx(76) + by, wing_c, sec_c, lt_c, 5)
        elif form == "brood_queen":
            for s in (-1, 1):
                cv.ellipse(bx + s * sx(28), sx(44) + by, sx(22) + wing_spread // 2, sx(10), (140, 210, 150, 140), True)
                cv.ellipse(bx + s * sx(24), sx(56) + by, sx(18), sx(8), (110, 185, 130, 120), True)

    # Legs / greaves / lower robe
    if not (state == "death" and frame_idx >= 2):
        if form in ("lich_king", "pharaoh", "abyss_lord", "hierophant"):
            cv.poly([
                (bx - sx(18), sx(58) + by), (bx + sx(18), sx(58) + by),
                (bx + sx(25) + step_r // 2, sx(114) + by),
                (bx + sx(10), sx(106) + by), (bx, sx(116) + by), (bx - sx(10), sx(106) + by),
                (bx - sx(25) + step_l // 2, sx(114) + by),
            ], mul(body_c, 0.86))
            cv.line(bx, sx(66) + by, bx, sx(112) + by, sec_c, 2)
        elif form == "brood_queen":
            cv.ellipse(bx, sx(92) + by, sx(22), sx(18), body_c)
            for ry in (84, 92, 100):
                cv.line(bx - sx(16), sx(ry) + by, bx + sx(16), sx(ry) + by, sec_c, 2)
            for s in (-1, 1):
                for ly in (72, 84, 96):
                    cv.line(bx + s * sx(14), sx(ly) + by, bx + s * sx(32), sx(ly + 10) + by, sec_c, 3)
        elif form == "treant_king":
            for s, st in ((-1, step_l), (1, step_r)):
                cv.poly([
                    (bx + s * sx(8), sx(84) + by),
                    (bx + s * sx(18), sx(84) + by),
                    (bx + s * sx(24), sx(114) + by + st),
                    (bx + s * sx(6), sx(114) + by + st),
                ], body_c)
        else:
            # Armored greaves & sabatons
            for s, st in ((-1, step_l), (1, step_r)):
                lx = bx + (sx(-16) if s < 0 else sx(5))
                cv.rect(lx, sx(84) + by + st, sx(11), sx(28), mul(body_c, 0.78))
                cv.rect(lx + 2, sx(86) + by + st, sx(6), sx(16), body_c)
                cv.rect(lx - 1, sx(95) + by + st, sx(13), sx(4), sec_c)
                cv.rect(lx - 2, sx(108) + by + st, sx(14), sx(7), sec_c)

    # Torso, armor, pauldrons, arms & weapons
    if not (state == "death" and frame_idx >= 3):
        tw = sx(44) if form in ("shemhaz", "magma_titan", "frost_titan", "treant_king", "chaos_titan") else sx(38)
        ty = sx(40) + by
        th = sx(46)
        _draw_armored_torso(cv, bx, ty, tw, th, mul(body_c, 0.76), body_c, lt_c, sec_c, eye_c)

        # Extra torso signatures & layered tassets
        if form == "shemhaz":
            for ry in (47, 56, 65):
                cv.line(bx - sx(11), sx(ry) + by, bx - sx(3), sx(ry + 3) + by, aura_c, 2)
                cv.line(bx + sx(11), sx(ry) + by, bx + sx(3), sx(ry + 3) + by, aura_c, 2)
        elif form in ("seraph", "satan"):
            # Golden/Crimson seraph breastplate sigil & waist tassets
            cv.poly([(bx, ty + sx(5)), (bx + sx(12), ty + sx(16)), (bx, ty + sx(28)), (bx - sx(12), ty + sx(16))], sec_c)
            cv.ellipse(bx, ty + sx(16), sx(5), sx(5), eye_c)
            cv.px(bx, ty + sx(16), c("white"))
            for s in (-1, 1):
                cv.poly([
                    (bx + s * sx(3), ty + th - sx(4)),
                    (bx + s * sx(17), ty + th - sx(4)),
                    (bx + s * sx(20), ty + th + sx(13)),
                    (bx + s * sx(4), ty + th + sx(11)),
                ], mul(body_c, 0.85))
                cv.line(bx + s * sx(4), ty + th + sx(11), bx + s * sx(20), ty + th + sx(13), sec_c, 2)
        elif form == "vampire_lord":
            # High gothic vampire collar
            cv.poly([(bx - sx(12), ty + sx(3)), (bx - sx(21), ty - sx(14)), (bx - sx(5), ty - sx(1))], sec_c)
            cv.poly([(bx + sx(12), ty + sx(3)), (bx + sx(21), ty - sx(14)), (bx + sx(5), ty - sx(1))], sec_c)

        # Ornate Spiked Pauldrons & Angled Dynamic Arms
        for s in (-1, 1):
            px = bx + s * (tw // 2 + sx(4))
            py = ty + sx(4) + arm_raise // 2
            cv.ellipse(px, py, sx(11), sx(8), mul(sec_c, 0.8))
            cv.ellipse(px, py - 1, sx(8), sx(5), sec_c)
            cv.line(px + s * sx(4), py - sx(4), px + s * sx(14), py - sx(14), lt_c, 2)
            # Angled upper arm + forearm + gauntlet
            sh_x, sh_y = px, py + sx(4)
            el_x, el_y = px + s * sx(7), ty + sx(21) + arm_raise // 2
            ha_x, ha_y = px + s * sx(3), ty + sx(36) + arm_raise
            cv.line(sh_x, sh_y, el_x, el_y, mul(body_c, 0.85), sx(7))
            cv.line(el_x, el_y, ha_x, ha_y, body_c, sx(7))
            cv.ellipse(ha_x, ha_y, sx(5), sx(5), sec_c)

        # Weapons (held in angled gauntlets)
        if form in ("seraph", "satan"):
            sw_x = bx + tw // 2 + sx(8)
            sw_y = sx(8) + by + arm_raise
            blade_c = c("gold_lt") if form == "seraph" else c("ember_red")
            edge_c = c("white") if form == "seraph" else c("#ff1493")
            cv.poly([
                (sw_x - sx(3), sw_y + sx(56)),
                (sw_x + sx(3), sw_y + sx(56)),
                (sw_x + sx(4), sw_y + sx(10)),
                (sw_x, sw_y),
                (sw_x - sx(4), sw_y + sx(10)),
            ], blade_c)
            cv.line(sw_x, sw_y + sx(2), sw_x, sw_y + sx(54), edge_c, 1)
            # Celestial fire sparks along blade
            for fy in (16, 28, 40):
                cv.px(sw_x - sx(5), sw_y + sx(fy), aura_c)
                cv.px(sw_x + sx(5), sw_y + sx(fy + 4), aura_c)
            cv.rect(sw_x - sx(10), sw_y + sx(56), sx(20), sx(4), c("gold"))
            cv.rect(sw_x - sx(2), sw_y + sx(60), sx(4), sx(10), c("crimson_dk"))
            # Hanging chains from left gauntlet
            lx_ch = bx - tw // 2 - sx(7)
            for ci in range(4):
                cv.ring(lx_ch, ty + sx(40 + ci * 7) + arm_raise, sx(3), sx(1.5), c("frost"))
        elif form == "shemhaz":
            for s in (-1, 1):
                wx = bx + s * (tw // 2 + sx(8))
                wy = ty + sx(30) + arm_raise
                cv.poly([
                    (wx - sx(4), wy), (wx + sx(4), wy),
                    (wx + s * sx(7), wy + sx(26)), (wx - s * sx(3), wy + sx(30)),
                ], c("iron"))
                cv.line(wx + s * sx(4), wy, wx + s * sx(7), wy + sx(26), c("ember_red"), 2)
                for ci in range(3):
                    cv.ring(wx, wy + sx(31 + ci * 5), sx(2.5), sx(1.2), c("frost"))
        elif form in ("vampire_lord", "usurper", "rift_knight"):
            wx = bx + tw // 2 + sx(8)
            wy = sx(14) + by + arm_raise
            cv.line(wx, wy, wx, wy + sx(58), lt_c, 3)
            cv.line(wx, wy, wx, wy + sx(56), c("white"), 1)
            cv.rect(wx - sx(7), wy + sx(45), sx(14), sx(3), sec_c)
        elif form in ("lich_king", "abyss_lord", "hierophant", "pharaoh"):
            wx = bx + tw // 2 + sx(8)
            wy = sx(12) + by + arm_raise
            cv.line(wx, wy + sx(8), wx, wy + sx(64), sec_c, 3)
            cv.ellipse(wx, wy + sx(6), sx(7), sx(7), eye_c)
            cv.ellipse(wx, wy + sx(6), sx(3), sx(3), c("white"))

        # Sculpted Head, Crown, Halo, Horns & Glowing Eyes
        hy = sx(18) + by
        if form in ("seraph", "satan"):
            halo_c = c("gold_lt") if form == "seraph" else c("#ff1493")
            cv.ring(bx, hy + sx(4), sx(24), sx(20), halo_c)
            for ra in (0, 60, 120, 240, 300):
                rr = math.radians(ra - 90)
                cv.rect(int(bx + math.cos(rr) * sx(25)) - 1, int(hy + sx(4) + math.sin(rr) * sx(25)) - 1, 3, 3, c("white"))
            # Tapered armored seraph helm
            cv.poly([
                (bx - sx(11), hy + sx(4)), (bx + sx(11), hy + sx(4)),
                (bx + sx(8), hy + sx(21)), (bx, hy + sx(24)), (bx - sx(8), hy + sx(21)),
            ], body_c)
            cv.poly([(bx - sx(12), hy + sx(5)), (bx, hy - sx(7)), (bx + sx(12), hy + sx(5))], sec_c)
            for s in (-1, 1):
                cv.poly([
                    (bx + s * sx(8), hy + sx(7)),
                    (bx + s * sx(24), hy - sx(14)),
                    (bx + s * sx(13), hy + sx(11)),
                ], c("slate_vd"))
                cv.line(bx + s * sx(10), hy + sx(5), bx + s * sx(23), hy - sx(13), c("gold") if form == "seraph" else c("ember_red"), 2)
        elif form == "vampire_lord":
            # Thin Gothic Crescent Blood-Moon behind head (no bulky red ball)
            cv.ring(bx, hy + sx(4), sx(25), sx(21), c("crimson"))
            cv.ellipse(bx, hy - sx(10), sx(18), sx(12), (0, 0, 0, 0))
            # Tapered pale gothic visage + widow's peak
            cv.poly([
                (bx - sx(10), hy + sx(4)), (bx + sx(10), hy + sx(4)),
                (bx + sx(8), hy + sx(19)), (bx, hy + sx(23)), (bx - sx(8), hy + sx(19)),
            ], c("parchment"))
            cv.poly([(bx - sx(11), hy + sx(5)), (bx, hy + sx(1)), (bx + sx(11), hy + sx(5)), (bx, hy + sx(10))], c("slate_vd"))
            cv.px(bx - sx(3), hy + sx(19), c("white"))
            cv.px(bx + sx(3), hy + sx(19), c("white"))
        elif form == "pharaoh":
            cv.poly([(bx - sx(16), hy), (bx + sx(16), hy), (bx + sx(20), hy + sx(22)), (bx - sx(20), hy + sx(22))], sec_c)
            cv.poly([
                (bx - sx(9), hy + sx(5)), (bx + sx(9), hy + sx(5)),
                (bx + sx(7), hy + sx(21)), (bx, hy + sx(24)), (bx - sx(7), hy + sx(21)),
            ], body_c)
            cv.line(bx - sx(6), hy - sx(6), bx - sx(9), hy + sx(5), sec_c, 3)
            cv.line(bx + sx(6), hy - sx(6), bx + sx(9), hy + sx(5), sec_c, 3)
        elif form == "treant_king":
            cv.poly([
                (bx - sx(11), hy + sx(2)), (bx + sx(11), hy + sx(2)),
                (bx + sx(9), hy + sx(22)), (bx - sx(9), hy + sx(22)),
            ], body_c)
            for s in (-1, 1):
                cv.line(bx + s * sx(7), hy + sx(2), bx + s * sx(20), hy - sx(12), sec_c, 3)
                cv.line(bx + s * sx(13), hy - sx(5), bx + s * sx(12), hy - sx(14), lt_c, 2)
        else:
            cv.poly([
                (bx - sx(11), hy + sx(3)), (bx + sx(11), hy + sx(3)),
                (bx + sx(9), hy + sx(21)), (bx, hy + sx(24)), (bx - sx(9), hy + sx(21)),
            ], c("parchment") if form == "lich_king" else body_c)
            if form in ("shemhaz", "magma_titan", "frost_titan", "usurper", "chaos_titan"):
                for s in (-1, 1):
                    cv.poly([
                        (bx + s * sx(7), hy + sx(6)),
                        (bx + s * sx(24), hy - sx(12)),
                        (bx + s * sx(12), hy + sx(11)),
                    ], c("slate_vd") if form == "shemhaz" else sec_c)
            if form in ("lich_king", "usurper", "hierophant"):
                for cx_off in (-8, 0, 8):
                    cv.poly([(bx + sx(cx_off - 3), hy + sx(3)), (bx + sx(cx_off), hy - sx(7)), (bx + sx(cx_off + 3), hy + sx(3))], c("gold"))

        # Glowing Eyes (larger & brighter on attack or idle pulse)
        eye_w = sx(5) if (state == "attack" or (state == "idle" and frame_idx == 1)) else sx(4)
        cv.rect(bx - sx(7), hy + sx(11), eye_w, sx(3), eye_c)
        cv.rect(bx + sx(3), hy + sx(11), eye_w, sx(3), eye_c)
        cv.px(bx - sx(5), hy + sx(12), c("white"))
        cv.px(bx + sx(5), hy + sx(12), c("white"))

    # Attack energy orb / shockwave
    if state == "attack":
        if frame_idx == 0:
            cv.ellipse(bx + sx(32), sx(32) + by, sx(9), sx(9), aura_c)
            cv.ellipse(bx + sx(32), sx(32) + by, sx(4), sx(4), c("white"))
        elif frame_idx == 1:
            cv.ring(bx, S // 2 + by, sx(54), sx(48), aura_c)
            cv.ellipse(bx + sx(36), sx(46) + by, sx(13), sx(13), aura_c)
            cv.ellipse(bx + sx(36), sx(46) + by, sx(5), sx(5), c("white"))
        elif frame_idx == 2:
            cv.ring(bx, S // 2 + by, sx(42), sx(38), (aura_c[0], aura_c[1], aura_c[2], 125), True)

    # Hurt sparks & flash tint
    if state == "hurt":
        for i in range(len(cv.buf)):
            col = cv.buf[i]
            if col[3] > 0:
                if frame_idx == 0:
                    cv.buf[i] = mix(col, c("ember_red"), 0.42)
                elif frame_idx == 1:
                    cv.buf[i] = mix(col, c("white"), 0.50)
        for sxp, syp in [(28, 36), (S - 28, 44), (40, S - 36), (S - 36, S - 44)]:
            cv.rect(sxp, syp, 3, 3, aura_c)

    # Death fracturing & explosion burst
    if state == "death":
        if frame_idx == 2:
            for y in range(S):
                for x in range(S):
                    if (x + y) % 5 == 0:
                        cv.buf[y * S + x] = (0, 0, 0, 0)
        elif frame_idx == 3:
            cv.ellipse(cx, int(S * 0.56), sx(42), sx(42), (aura_c[0], aura_c[1], aura_c[2], 175), True)
            cv.ellipse(cx, int(S * 0.56), sx(24), sx(24), c("gold_glow"))
            cv.ellipse(cx, int(S * 0.56), sx(11), sx(11), c("white"))
            for k in range(18):
                a = k * math.tau / 18.0
                cv.line(cx, int(S * 0.56), int(cx + math.cos(a) * sx(54)), int(S * 0.56 + math.sin(a) * sx(54)), aura_c, 3)
            return cv

    cv.outline(c("crimson_dk") if form == "satan" else c("black"))
    return cv


def generate_bosses() -> int:
    count = 0
    boss_ids = [
        "boss_shemhaz", "boss_satanail", "boss_satan",
        "boss_champion", "boss_sands", "boss_tundra", "boss_peak", "boss_abyss",
        "boss_forest", "boss_rift", "boss_graveyard", "boss_hive",
        "boss_bloodmoon", "boss_chaos", "boss_temple", "boss_throne",
    ]
    for bid in boss_ids:
        idle = [_boss_frame(bid, "idle", i) for i in range(4)]
        walk = [_boss_frame(bid, "walk", i) for i in range(4)]
        attack = [_boss_frame(bid, "attack", i) for i in range(4)]
        hurt = [_boss_frame(bid, "hurt", i) for i in range(3)]
        death = [_boss_frame(bid, "death", i) for i in range(5)]
        count += _save_anim(bid, idle[0], idle, walk, attack, hurt, death)
    return count


def run() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    n += generate_heroes()
    n += generate_enemies()
    n += generate_minibosses()
    n += generate_bosses()
    return n
