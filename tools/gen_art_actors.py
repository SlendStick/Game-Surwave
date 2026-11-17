# -*- coding: utf-8 -*-
"""Pixel-art generator for Heroes (32x32), Enemies (32x32), Minibosses (48x48), and Bosses (64x64 + full animations)."""

from __future__ import annotations

import math
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, mix, mul

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"


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


# ------------------------------------------------------------------ 64x64 BOSSES + FULL SPEC ANIMATIONS
def _boss_frame(
    boss_id: str,
    state: str,
    frame_idx: int,
) -> Canvas:
    """Renders a 64x64 boss frame for idle(0..3), walk(0..3), attack(0..3), hurt(0..2), death(0..4)."""
    cv = Canvas(64, 64)
    cx = 32
    bob = 0
    wing_spread = 0
    arm_raise = 0
    lean_x = 0
    step_l = 0
    step_r = 0

    if state == "idle":
        bob = (0, -2, 0, 1)[frame_idx % 4]
        wing_spread = (0, 2, 0, 5)[frame_idx % 4]
    elif state == "walk":
        bob = (-1, 0, -2, 0)[frame_idx % 4]
        wing_spread = (4, 1, 5, 2)[frame_idx % 4]
        step_l = (-2, 1, -1, 0)[frame_idx % 4]
        step_r = (2, -2, 1, 0)[frame_idx % 4]
    elif state == "attack":
        arm_raise = (-7, 2, -2, 0)[frame_idx % 4]
        wing_spread = (2, 7, 4, 0)[frame_idx % 4]
        lean_x = (-2, 4, 2, 0)[frame_idx % 4]
    elif state == "hurt":
        lean_x = (-3, -6, -1)[frame_idx % 3]
        bob = (1, 2, 0)[frame_idx % 3]
    elif state == "death":
        # 5-phase death sequence per BOSSES_COMPLETE_SPECIFICATION.md
        if frame_idx == 4:
            # Phase 5: dissipated with lingering embers/sparkles
            for k in range(12):
                px = int(cx + math.cos(k * 0.9) * (10 + k))
                py = int(38 + math.sin(k * 1.4) * 12)
                cv.rect(px, py, 2, 2, c("gold_glow") if boss_id == "boss_satanail" else c("flame"))
            return cv

    # Death collapse geometry adjustments
    collapse_y = 0
    if state == "death":
        collapse_y = (6, 13, 18, 22)[min(3, frame_idx)]

    bx = cx + lean_x
    by = bob + collapse_y

    # Palette & archetype
    if boss_id == "boss_satanail":
        body_c, sec_c, eye_c, wing_c, aura_c, form = c("crimson_dk"), c("gold"), c("ember_red"), c("frost_dk"), c("gold_glow"), "seraph"
    elif boss_id == "boss_satan":
        body_c, sec_c, eye_c, wing_c, aura_c, form = c("blood_vd"), c("crimson"), c("gold_glow"), c("void"), c("ember_red"), "satan"
    elif boss_id == "boss_shemhaz":
        body_c, sec_c, eye_c, wing_c, aura_c, form = c("crimson_dk"), c("lava"), c("gold_glow"), c("maroon"), c("flame"), "shemhaz"
    else:
        styles = {
            "boss_sands": (c("sand_dk"), c("gold"), c("amber"), c("bronze"), c("gold_glow"), "pharaoh"),
            "boss_tundra": (c("frost_dk"), c("ice_blue"), c("ice_glow"), c("snow_dk"), c("ice_glow"), "queen"),
            "boss_peak": (c("stone_dk"), c("lava"), c("gold_glow"), c("maroon"), c("flame"), "titan"),
            "boss_abyss": (c("slate_vd"), c("violet"), c("ghost_violet"), c("arcane_vd"), c("violet_lt"), "lich"),
            "boss_forest": (c("soil_dark"), c("moss"), c("amber"), c("moss_dk"), c("glow_green"), "titan"),
            "boss_rift": (c("arcane_vd"), c("violet_lt"), c("ember_red"), c("arcane_dk"), c("ghost_violet"), "lich"),
            "boss_graveyard": (c("bone"), c("arcane"), c("glow_green"), c("slate_dk"), c("glow_green"), "lich"),
            "boss_hive": (c("swamp_dk"), c("poison"), c("pale_green"), c("moss_dk"), c("glow_green"), "queen"),
            "boss_bloodmoon": (c("blood_dk"), c("crimson"), c("ember_red"), c("maroon"), c("ember_red"), "baron"),
            "boss_chaos": (c("arcane_dk"), c("scarlet"), c("ice_glow"), c("crimson_dk"), c("violet_lt"), "baron"),
            "boss_temple": (c("bronze_dk"), c("gold"), c("ice_glow"), c("stone"), c("gold_glow"), "titan"),
            "boss_throne": (c("slate_vd"), c("gold"), c("ember_red"), c("crimson_dk"), c("gold"), "baron"),
            "boss_champion": (c("stone_dk"), c("crimson"), c("gold_glow"), c("maroon"), c("flame"), "titan"),
        }
        body_c, sec_c, eye_c, wing_c, aura_c, form = styles.get(boss_id, styles["boss_champion"])

    # Ground shadow
    if not (state == "death" and frame_idx >= 3):
        cv.add_ground_shadow(bx, 59, 20 + wing_spread // 2, 5.0, 110)

    # Aura / trail effect on idle frame 1/3, walk, or attack
    if (state == "idle" and frame_idx in (1, 3)) or state == "walk":
        ar = 23 + (3 if frame_idx == 3 else 0)
        cv.ring(bx, 32 + by, ar, ar - 1.5, (aura_c[0], aura_c[1], aura_c[2], 70), True)

    # Wings (for winged bosses: shemhaz, seraph, satan, baron)
    if form in ("shemhaz", "seraph", "satan", "baron") and not (state == "death" and frame_idx >= 2):
        ws = 24 + wing_spread
        wy_top = 8 - wing_spread // 2 + by
        for s in (-1, 1):
            cv.poly([
                (bx + s * 8, 22 + by),
                (bx + s * ws, wy_top),
                (bx + s * (ws - 3), 34 + by),
                (bx + s * 8, 34 + by),
            ], wing_c)
            cv.line(bx + s * ws, wy_top, bx + s * 10, 24 + by, sec_c, 2)

    # Legs / robe hem
    if not (state == "death" and frame_idx >= 2):
        if form in ("lich", "pharaoh", "seraph", "satan"):
            cv.poly([
                (bx - 11, 22 + by), (bx + 11, 22 + by),
                (bx + 15 + step_r // 2, 55 + by),
                (bx + 7, 51 + by), (bx, 56 + by), (bx - 7, 51 + by),
                (bx - 15 + step_l // 2, 55 + by),
            ], body_c)
        else:
            cv.rect(bx - 10, 43 + by + step_l, 7, 13, mul(body_c, 0.8))
            cv.rect(bx + 3, 43 + by + step_r, 7, 13, mul(body_c, 0.8))

    # Torso & chest sigil
    if not (state == "death" and frame_idx >= 3):
        tw = 24 if form in ("titan", "shemhaz") else 20
        cv.rect(bx - tw // 2, 18 + by, tw, 26, body_c)
        cv.rect(bx - tw // 2 + 3, 20 + by, tw - 6, 18, sec_c if form in ("shemhaz", "titan") else mul(body_c, 1.25))
        if form in ("shemhaz", "satan"):
            for ry in (22, 27, 32):
                cv.line(bx - 6, ry + by, bx + 6, ry + by, aura_c, 2)
        cv.ellipse(bx, 27 + by, 4, 4, eye_c)

        # Pauldrons & arms
        cv.ellipse(bx - tw // 2 - 2, 20 + by + arm_raise // 2, 5, 4, sec_c)
        cv.ellipse(bx + tw // 2 + 2, 20 + by + arm_raise // 2, 5, 4, sec_c)
        arm_y = 21 + by + arm_raise
        cv.rect(bx - tw // 2 - 5, arm_y, 5, 16, body_c)
        cv.rect(bx + tw // 2, arm_y, 5, 16, body_c)

        # Weapon / Cleaver / Sword / Staff
        if form in ("seraph", "satan", "baron"):
            sw_y = 8 + by + arm_raise
            cv.line(bx + 17, sw_y, bx + 17, sw_y + 34, c("crimson") if form == "satan" else c("frost"), 2)
            cv.rect(bx + 12, sw_y + 26, 10, 2, c("gold"))
        elif form == "shemhaz":
            cv.rect(bx - 21, arm_y + 2, 5, 16, c("stone_lt"))
            cv.line(bx - 21, arm_y + 2, bx - 21, arm_y + 17, c("amber"))
            cv.rect(bx + 16, arm_y + 2, 5, 16, c("stone_lt"))
            cv.line(bx + 20, arm_y + 2, bx + 20, arm_y + 17, c("amber"))

        # Head, horns, crown, glowing eyes
        head_y = 8 + by
        if form == "pharaoh":
            cv.rect(bx - 10, head_y, 20, 12, sec_c)
        cv.rect(bx - 6, head_y + 2, 12, 10, c("parchment") if form in ("lich", "baron") else body_c)
        if form in ("shemhaz", "satan", "titan", "baron"):
            cv.line(bx - 5, head_y + 3, bx - 12, max(1, head_y - 5), c("bone") if form != "satan" else c("ember_red"), 2)
            cv.line(bx + 5, head_y + 3, bx + 12, max(1, head_y - 5), c("bone") if form != "satan" else c("ember_red"), 2)
        elif form == "seraph":
            cv.ring(bx, head_y, 9.0, 7.0, c("gold_lt"))
            cv.px(bx, head_y - 8, (0, 0, 0, 0))
        elif form == "lich":
            cv.rect(bx - 7, head_y - 1, 14, 3, c("gold"))
        # Glowing eyes (brighter on idle frame 1 & attack frame 1)
        eye_sz = 3 if (state == "attack" or (state == "idle" and frame_idx == 1)) else 2
        cv.rect(bx - 4, head_y + 5, eye_sz, 2, eye_c)
        cv.rect(bx + 2, head_y + 5, eye_sz, 2, eye_c)

    # Attack energy orb / burst on attack frames 0..2
    if state == "attack":
        if frame_idx == 0:
            cv.ellipse(bx + 16, 16 + by, 5, 5, aura_c)
            cv.ellipse(bx + 16, 16 + by, 2, 2, c("white"))
        elif frame_idx == 1:
            cv.ring(bx, 30 + by, 28, 25, aura_c)
            cv.ellipse(bx + 18, 24 + by, 7, 7, aura_c)
            cv.ellipse(bx + 18, 24 + by, 3, 3, c("white"))
        elif frame_idx == 2:
            cv.ring(bx, 30 + by, 22, 20, (aura_c[0], aura_c[1], aura_c[2], 120), True)

    # Hurt sparks & flash tint
    if state == "hurt":
        for i in range(len(cv.buf)):
            col = cv.buf[i]
            if col[3] > 0:
                if frame_idx == 0:
                    cv.buf[i] = mix(col, c("ember_red"), 0.45)
                elif frame_idx == 1:
                    cv.buf[i] = mix(col, c("white"), 0.55)
        for sx, sy in [(14, 18), (50, 22), (20, 44), (46, 40)]:
            cv.rect(sx, sy, 2, 2, aura_c)

    # Death fracturing & explosion burst
    if state == "death":
        if frame_idx == 2:
            for y in range(64):
                for x in range(64):
                    if (x + y) % 5 == 0:
                        cv.buf[y * 64 + x] = (0, 0, 0, 0)
        elif frame_idx == 3:
            cv.ellipse(cx, 36, 22, 22, (aura_c[0], aura_c[1], aura_c[2], 170), True)
            cv.ellipse(cx, 36, 13, 13, c("gold_glow"))
            cv.ellipse(cx, 36, 6, 6, c("white"))
            for k in range(16):
                a = k * math.tau / 16.0
                cv.line(cx, 36, int(cx + math.cos(a) * 28), int(36 + math.sin(a) * 28), aura_c, 2)
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
