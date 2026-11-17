# -*- coding: utf-8 -*-
"""Pixel-art generator for Heroes, Enemies, Minibosses, and Bosses."""

from __future__ import annotations

import math
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, mix, mul

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"


def _save_anim(base_name: str, base_cv: Canvas, idle_frames: list[Canvas], walk_frames: list[Canvas]) -> int:
    base_cv.save(OUT / f"{base_name}.png")
    count = 1
    for i, fr in enumerate(idle_frames):
        fr.save(OUT / f"{base_name}_idle_{i}.png")
        count += 1
    for i, fr in enumerate(walk_frames):
        fr.save(OUT / f"{base_name}_walk_{i}.png")
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
    """Renders a crisp 32x32 gothic RPG hero with shading, outline, and animation."""
    cv = Canvas(32, 32)
    cx = 15
    # Ground shadow
    cv.add_ground_shadow(15.5, 29.0, 8.0 if broad else 6.5, 2.5, 95)

    # Legs / boots (animated by leg_phase: 0 neutral, 1 left fwd, 2 neutral, 3 right fwd)
    l_dy = -1 if leg_phase == 1 else (1 if leg_phase == 3 else 0)
    r_dy = -1 if leg_phase == 3 else (1 if leg_phase == 1 else 0)
    boot_dk = c("dark_brown")
    boot_lt = c("leather")
    cv.rect(cx - 4, 24 + l_dy, 3, 4, boot_dk)
    cv.rect(cx - 4, 24 + l_dy, 2, 2, boot_lt)
    cv.rect(cx + 2, 24 + r_dy, 3, 4, boot_dk)
    cv.rect(cx + 2, 24 + r_dy, 2, 2, boot_lt)

    y0 = bob_y
    # Back cape / cloak silhouette
    if head_style in ("mage_hat", "hood", "paladin_helm", "ranger_hood", "void_horns", "witch_hat"):
        cape_w = 13 if broad else 11
        cv.poly([(cx - 4, 13 + y0), (cx + 5, 13 + y0), (cx + cape_w // 2 + 1, 25 + y0), (cx - cape_w // 2, 25 + y0)], mul(robe_dk, 0.85))
        cv.line(cx - 4, 15 + y0, cx - cape_w // 2 + 1, 24 + y0, robe_md)

    # Torso
    tw = 12 if broad else 9
    tx = cx - tw // 2 + (0 if broad else 1)
    cv.rect(tx, 13 + y0, tw, 12, robe_dk)
    cv.rect(tx + 1, 13 + y0, tw - 2, 10, robe_md)
    cv.rect(tx + 2, 14 + y0, max(2, tw - 5), 5, robe_lt)
    # Belt & buckle
    cv.rect(tx, 20 + y0, tw, 2, c("iron_dk"))
    cv.rect(cx - 1, 20 + y0, 3, 2, accent)
    # Chest emblem / runes
    cv.rect(cx - 1, 15 + y0, 2, 4, accent)
    if broad:
        # Pauldrons for paladin / orc
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
    cv.rect(cx - 3, 12 + y0, 7, 2, mul(skin, 0.78))
    # Eyes (crisp 2px glowing or dark)
    cv.px(cx - 1, 10 + y0, eye_col)
    cv.px(cx + 2, 10 + y0, eye_col)

    # Headwear / Hair / Horns
    if head_style == "mage_hat":
        cv.rect(cx - 6, 7 + y0, 13, 2, robe_md)
        cv.poly([(cx - 4, 7 + y0), (cx + 5, 7 + y0), (cx + 2, 1 + y0)], robe_dk)
        cv.line(cx - 3, 6 + y0, cx + 1, 2 + y0, robe_lt)
        cv.rect(cx - 3, 6 + y0, 7, 1, accent)
        # Silver wizard beard
        cv.poly([(cx - 2, 12 + y0), (cx + 3, 12 + y0), (cx + 1, 17 + y0)], c("bone"))
        cv.px(cx, 13 + y0, c("parchment"))
    elif head_style == "paladin_helm":
        cv.rect(cx - 4, 5 + y0, 9, 8, c("stone_lt"))
        cv.rect(cx - 3, 6 + y0, 7, 3, c("frost"))
        cv.rect(cx - 2, 9 + y0, 5, 1, c("black"))  # visor slit
        cv.px(cx - 1, 9 + y0, eye_col)
        cv.px(cx + 1, 9 + y0, eye_col)
        # Crimson plume
        cv.poly([(cx - 1, 5 + y0), (cx + 2, 5 + y0), (cx + 4, 1 + y0), (cx - 1, 2 + y0)], c("crimson"))
        cv.px(cx + 1, 3 + y0, c("scarlet"))
    elif head_style == "hood":
        cv.poly([(cx - 5, 12 + y0), (cx - 4, 5 + y0), (cx + 4, 5 + y0), (cx + 5, 12 + y0)], robe_dk)
        cv.rect(cx - 3, 7 + y0, 7, 5, c("void"))
        cv.px(cx - 1, 10 + y0, eye_col)
        cv.px(cx + 2, 10 + y0, eye_col)
        cv.rect(cx - 4, 5 + y0, 9, 1, accent)
    elif head_style == "orc_tusks":
        cv.rect(cx - 4, 6 + y0, 9, 2, c("soil_dark"))  # braided hair
        cv.rect(cx + 3, 7 + y0, 2, 5, c("soil"))
        # Tusks & scars
        cv.px(cx - 2, 12 + y0, c("parchment"))
        cv.px(cx + 2, 12 + y0, c("parchment"))
        cv.line(cx - 2, 8 + y0, cx, 10 + y0, c("maroon"))
    elif head_style == "ranger_hood":
        cv.poly([(cx - 4, 11 + y0), (cx - 3, 5 + y0), (cx + 4, 5 + y0), (cx + 5, 11 + y0)], robe_dk)
        cv.rect(cx - 2, 7 + y0, 5, 5, skin)
        # Pointed elf ears
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

    # Iconic class gear held / on back
    if gear_style == "staff":
        cv.line(cx + 6, 4 + y0, cx + 6, 27 + y0, c("leather"))
        cv.rect(cx + 5, 3 + y0, 3, 3, accent)
        cv.px(cx + 6, 4 + y0, c("white"))
    elif gear_style == "sword_shield":
        cv.line(cx + 7, 6 + y0, cx + 7, 22 + y0, c("frost"))
        cv.rect(cx + 5, 19 + y0, 5, 1, c("gold"))
        cv.rect(cx - 8, 13 + y0, 4, 9, c("crimson_dk"))
        cv.box_outline(cx - 8, 13 + y0, 4, 9, c("gold"))
    elif gear_style == "grimoire":
        # Floating skull tome on left
        cv.rect(cx - 9, 10 + y0, 5, 6, c("arcane_dk"))
        cv.box_outline(cx - 9, 10 + y0, 5, 6, c("parchment"))
        cv.px(cx - 7, 12 + y0, c("glow_green"))
    elif gear_style == "axe":
        cv.line(cx + 7, 7 + y0, cx + 7, 26 + y0, c("soil"))
        cv.poly([(cx + 6, 7 + y0), (cx + 11, 5 + y0), (cx + 11, 13 + y0), (cx + 6, 11 + y0)], c("frost"))
        cv.line(cx + 11, 6 + y0, cx + 11, 12 + y0, c("white"))
    elif gear_style == "bow_quiver":
        cv.line(cx - 6, 12 + y0, cx - 3, 21 + y0, c("leather"))
        cv.px(cx - 6, 11 + y0, c("parchment"))
        cv.arc_pts = None
        cv.line(cx + 6, 10 + y0, cx + 8, 16 + y0, c("leather_lt"))
        cv.line(cx + 8, 16 + y0, cx + 6, 22 + y0, c("leather_lt"))
        cv.line(cx + 6, 10 + y0, cx + 6, 22 + y0, c("frost"))
    elif gear_style == "daggers":
        cv.line(cx - 7, 19 + y0, cx - 10, 14 + y0, c("frost"))
        cv.line(cx + 7, 19 + y0, cx + 10, 14 + y0, c("frost"))
        cv.px(cx - 10, 14 + y0, accent)
        cv.px(cx + 10, 14 + y0, accent)
    elif gear_style == "tesla":
        cv.rect(cx - 8, 11 + y0, 3, 9, c("bronze"))
        cv.px(cx - 7, 9 + y0, c("ice_glow"))
        cv.px(cx - 6, 8 + y0, c("white"))
    elif gear_style == "rifle":
        cv.line(cx + 4, 18 + y0, cx + 12, 12 + y0, c("iron_dk"))
        cv.px(cx + 12, 12 + y0, c("frost"))
    elif gear_style == "braziers":
        cv.rect(cx - 8, 17 + y0, 3, 4, c("flame"))
        cv.px(cx - 7, 16 + y0, c("gold_glow"))
        cv.rect(cx + 6, 17 + y0, 3, 4, c("flame"))
        cv.px(cx + 7, 16 + y0, c("gold_glow"))
    elif gear_style == "void_halo":
        cv.ring(cx, 6 + y0, 9.0, 7.5, c("violet_lt"), True)

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
    bob = -1 if phase in (1, 3) else 0
    step = 1 if phase == 1 else (-1 if phase == 3 else 0)

    if kind in ("slime", "slime_small"):
        sz = 16 if kind == "slime_small" else 24
        cv = Canvas(sz, sz)
        cx, cy = sz // 2, sz // 2 + 1
        rx = (sz * 0.36) * (1.08 if phase in (1, 3) else 0.96)
        ry = (sz * 0.30) * (0.92 if phase in (1, 3) else 1.06)
        cv.add_ground_shadow(cx, sz - 2.5, rx + 1, 2.0, 85)
        cv.ellipse(cx, cy + 1, rx, ry, c("moss_dk"))
        cv.ellipse(cx, cy, rx * 0.85, ry * 0.82, c("moss"))
        cv.ellipse(cx - 1, cy - 1, rx * 0.55, ry * 0.45, c("poison"))
        cv.px(int(cx - 2), int(cy - 2), c("pale_green"))
        # Skull/bones suspended inside gothic slime
        if sz >= 24:
            cv.rect(cx - 2, cy, 4, 3, c("parchment"))
            cv.px(cx - 1, cy + 1, c("black"))
            cv.px(cx + 1, cy + 1, c("black"))
        # Angry glowing eyes
        cv.px(cx - 2, cy - 1, c("ember_red"))
        cv.px(cx + 2, cy - 1, c("ember_red"))
        cv.outline(c("black"))
        return cv

    if kind == "bat":
        cv = Canvas(24, 16)
        cx, cy = 12, 8
        cv.add_ground_shadow(cx, 14, 5, 1.5, 65)
        wing_y = -4 if phase in (0, 2) else (3 if phase == 1 else 0)
        # Bat wings
        cv.poly([(cx - 2, cy), (cx - 10, cy + wing_y - 2), (cx - 8, cy + 3), (cx - 3, cy + 2)], c("umber"))
        cv.poly([(cx + 2, cy), (cx + 10, cy + wing_y - 2), (cx + 8, cy + 3), (cx + 3, cy + 2)], c("umber"))
        cv.line(cx - 2, cy, cx - 10, cy + wing_y - 2, c("leather"))
        cv.line(cx + 2, cy, cx + 10, cy + wing_y - 2, c("leather"))
        # Furry body & ears
        cv.ellipse(cx, cy, 3.0, 4.0, c("soil_dark"))
        cv.px(cx - 2, cy - 4, c("soil"))
        cv.px(cx + 2, cy - 4, c("soil"))
        cv.px(cx - 1, cy - 1, c("ember_red"))
        cv.px(cx + 1, cy - 1, c("ember_red"))
        cv.px(cx, cy + 1, c("parchment"))
        cv.outline(c("black"))
        return cv

    if kind == "goblin_archer":
        cv = Canvas(24, 24)
        cx = 11
        cv.add_ground_shadow(cx, 21, 5.5, 2.0, 85)
        cv.rect(cx - 3, 17 + step, 2, 4, c("moss_dk"))
        cv.rect(cx + 1, 17 - step, 2, 4, c("moss_dk"))
        # Hunched body + leather tunic
        cv.rect(cx - 4, 10 + bob, 8, 8, c("soil_dark"))
        cv.rect(cx - 3, 11 + bob, 6, 5, c("leather"))
        # Pointed ears & goblin head
        cv.rect(cx - 3, 5 + bob, 6, 5, c("moss"))
        cv.rect(cx - 6, 6 + bob, 3, 2, c("moss_dk"))
        cv.rect(cx + 3, 6 + bob, 3, 2, c("moss_dk"))
        cv.px(cx - 1, 7 + bob, c("amber"))
        cv.px(cx + 2, 7 + bob, c("amber"))
        # Hood & shortbow
        cv.poly([(cx - 4, 7 + bob), (cx, 3 + bob), (cx + 4, 7 + bob)], c("crimson_dk"))
        cv.line(cx + 5, 7 + bob, cx + 7, 13 + bob, c("leather_lt"))
        cv.line(cx + 7, 13 + bob, cx + 5, 19 + bob, c("leather_lt"))
        cv.line(cx + 5, 7 + bob, cx + 5, 19 + bob, c("bone"))
        cv.outline(c("black"))
        return cv

    if kind == "frozen_zombie":
        cv = Canvas(24, 32)
        cx = 12
        cv.add_ground_shadow(cx, 29, 6.5, 2.5, 90)
        cv.rect(cx - 4, 22 + step, 3, 6, c("slate_dk"))
        cv.rect(cx + 1, 22 - step, 3, 6, c("slate_dk"))
        # Frozen rotting torso
        cv.rect(cx - 5, 11 + bob, 10, 12, c("slate"))
        cv.rect(cx - 4, 12 + bob, 8, 9, c("moss_dk"))
        # Ice crystals jutting out
        cv.poly([(cx - 6, 12 + bob), (cx - 2, 8 + bob), (cx - 1, 14 + bob)], c("ice_lt"))
        cv.poly([(cx + 3, 14 + bob), (cx + 7, 9 + bob), (cx + 6, 17 + bob)], c("frost_blue"))
        # Head
        cv.rect(cx - 4, 5 + bob, 8, 7, c("frost_dk"))
        cv.rect(cx - 2, 9 + bob, 4, 2, c("void"))
        cv.px(cx - 2, 7 + bob, c("ice_glow"))
        cv.px(cx + 1, 7 + bob, c("ice_glow"))
        # Outstretched zombie arms
        cv.rect(cx - 8, 13 + bob, 3, 3, c("frost_dk"))
        cv.rect(cx + 5, 13 + bob, 3, 3, c("frost_dk"))
        cv.outline(c("black"))
        return cv

    if kind == "skeleton_warrior":
        cv = Canvas(24, 32)
        cx = 11
        cv.add_ground_shadow(cx, 29, 6.0, 2.2, 85)
        cv.rect(cx - 3, 21 + step, 2, 7, c("bone"))
        cv.rect(cx + 2, 21 - step, 2, 7, c("bone"))
        # Ribcage + rusted armor
        cv.rect(cx - 4, 12 + bob, 9, 9, c("iron_dk"))
        for ry in (13, 15, 17):
            cv.rect(cx - 3, ry + bob, 7, 1, c("parchment"))
        cv.line(cx, 12 + bob, cx, 19 + bob, c("bone"))
        # Skull
        cv.rect(cx - 3, 5 + bob, 7, 7, c("parchment"))
        cv.rect(cx - 2, 10 + bob, 5, 2, c("sand_lt"))
        cv.px(cx - 2, 8 + bob, c("black"))
        cv.px(cx + 1, 8 + bob, c("black"))
        cv.px(cx - 2, 8 + bob, c("ember_red"))
        cv.px(cx + 1, 8 + bob, c("ember_red"))
        # Shield & notched sword
        cv.rect(cx - 8, 12 + bob, 4, 8, c("iron"))
        cv.box_outline(cx - 8, 12 + bob, 4, 8, c("bronze"))
        cv.line(cx + 6, 7 + bob, cx + 6, 19 + bob, c("frost"))
        cv.rect(cx + 4, 17 + bob, 4, 1, c("bronze"))
        cv.outline(c("black"))
        return cv

    if kind == "dark_mage":
        cv = Canvas(24, 32)
        cx = 12
        cv.add_ground_shadow(cx, 29, 6.5, 2.2, 95)
        # Floating cultist robes
        cv.poly([(cx - 5, 11 + bob), (cx + 5, 11 + bob), (cx + 7, 27 + bob), (cx - 7, 27 + bob)], c("arcane_vd"))
        cv.poly([(cx - 3, 12 + bob), (cx + 3, 12 + bob), (cx + 4, 26 + bob), (cx - 4, 26 + bob)], c("arcane_dk"))
        cv.rect(cx - 1, 14 + bob, 2, 9, c("violet"))
        # Horned cowl
        cv.poly([(cx - 5, 11 + bob), (cx, 4 + bob), (cx + 5, 11 + bob)], c("maroon"))
        cv.line(cx - 3, 6 + bob, cx - 6, 2 + bob, c("bone"))
        cv.line(cx + 3, 6 + bob, cx + 6, 2 + bob, c("bone"))
        cv.px(cx - 1, 8 + bob, c("violet_lt"))
        cv.px(cx + 1, 8 + bob, c("violet_lt"))
        # Floating hex staff
        cv.line(cx + 7, 5 + bob, cx + 7, 25 + bob, c("soil_dark"))
        cv.rect(cx + 6, 4 + bob, 3, 3, c("ghost_violet"))
        cv.outline(c("black"))
        return cv

    if kind == "werewolf":
        cv = Canvas(32, 32)
        cx = 15
        cv.add_ground_shadow(cx, 29, 9.0, 2.8, 95)
        cv.rect(cx - 5, 22 + step, 3, 6, c("soil_dark"))
        cv.rect(cx + 2, 22 - step, 3, 6, c("soil_dark"))
        # Muscular hunched wolf torso & mane
        cv.ellipse(cx, 15 + bob, 7.5, 7.0, c("umber"))
        cv.ellipse(cx, 13 + bob, 6.0, 5.0, c("soil"))
        # Wolf head, snout, pointed ears
        cv.rect(cx - 4, 5 + bob, 8, 7, c("soil"))
        cv.rect(cx - 2, 9 + bob, 6, 3, c("sand_dk"))
        cv.poly([(cx - 5, 7 + bob), (cx - 4, 1 + bob), (cx - 2, 6 + bob)], c("umber"))
        cv.poly([(cx + 2, 6 + bob), (cx + 4, 1 + bob), (cx + 5, 7 + bob)], c("umber"))
        cv.px(cx - 2, 7 + bob, c("amber"))
        cv.px(cx + 1, 7 + bob, c("amber"))
        # Long razor claws
        cv.rect(cx - 10, 14 + bob, 3, 5, c("soil_dark"))
        cv.line(cx - 10, 19 + bob, cx - 11, 22 + bob, c("parchment"))
        cv.line(cx - 8, 19 + bob, cx - 9, 22 + bob, c("parchment"))
        cv.rect(cx + 7, 14 + bob, 3, 5, c("soil_dark"))
        cv.line(cx + 9, 19 + bob, cx + 10, 22 + bob, c("parchment"))
        cv.outline(c("black"))
        return cv

    if kind == "demon":
        cv = Canvas(24, 24)
        cx = 12
        cv.add_ground_shadow(cx, 21, 6.0, 2.0, 90)
        # Bat wings & tail
        cv.poly([(cx - 3, 11 + bob), (cx - 10, 6 + bob), (cx - 9, 14 + bob)], c("blood_dk"))
        cv.poly([(cx + 3, 11 + bob), (cx + 10, 6 + bob), (cx + 9, 14 + bob)], c("blood_dk"))
        cv.line(cx + 4, 17 + bob, cx + 9, 19 + bob, c("crimson"))
        cv.px(cx + 9, 18 + bob, c("scarlet"))
        # Body & horns
        cv.rect(cx - 4, 10 + bob, 8, 9, c("crimson_dk"))
        cv.rect(cx - 3, 11 + bob, 6, 5, c("crimson"))
        cv.rect(cx - 3, 4 + bob, 6, 6, c("blood"))
        cv.line(cx - 2, 4 + bob, cx - 5, 1 + bob, c("bone"))
        cv.line(cx + 2, 4 + bob, cx + 5, 1 + bob, c("bone"))
        cv.px(cx - 1, 6 + bob, c("gold_glow"))
        cv.px(cx + 1, 6 + bob, c("gold_glow"))
        cv.rect(cx - 3, 18 + step, 2, 4, c("blood_dk"))
        cv.rect(cx + 1, 18 - step, 2, 4, c("blood_dk"))
        cv.outline(c("black"))
        return cv

    # fallen_angel
    cv = Canvas(32, 32)
    cx = 16
    cv.add_ground_shadow(cx, 29, 7.5, 2.5, 90)
    # Tattered ash-white & bloodied wings
    wing_dy = -1 if phase in (1, 3) else 0
    cv.poly([(cx - 3, 12 + bob), (cx - 14, 5 + wing_dy), (cx - 12, 18 + wing_dy), (cx - 4, 18 + bob)], c("frost"))
    cv.poly([(cx + 3, 12 + bob), (cx + 14, 5 + wing_dy), (cx + 12, 18 + wing_dy), (cx + 4, 18 + bob)], c("frost"))
    cv.line(cx - 13, 10 + wing_dy, cx - 10, 17 + wing_dy, c("crimson"))
    cv.line(cx + 13, 10 + wing_dy, cx + 10, 17 + wing_dy, c("crimson"))
    # Robe & cracked halo
    cv.poly([(cx - 4, 11 + bob), (cx + 4, 11 + bob), (cx + 6, 26 + bob), (cx - 6, 26 + bob)], c("parchment"))
    cv.rect(cx - 2, 13 + bob, 4, 10, c("crimson_dk"))
    cv.rect(cx - 3, 6 + bob, 6, 5, c("bone"))
    cv.px(cx - 1, 8 + bob, c("ember_red"))
    cv.px(cx + 1, 8 + bob, c("ember_red"))
    cv.line(cx - 4, 3 + bob, cx + 3, 3 + bob, c("gold"))
    cv.px(cx, 3 + bob, (0, 0, 0, 0))  # cracked halo!
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
        # Tail curling overhead
        for i, (tx, ty) in enumerate([(24, 14), (27, 9), (24, 5), (19, 6)]):
            cv.ellipse(tx, ty, 3 - i * 0.2, 3 - i * 0.2, sec_c)
        cv.px(17, 7, c("crimson"))
        # Claws
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
        # Hulking armored/golem/yeti/idol silhouette
        cv.rect(cx - 10, 14, 20, 20, body_c)
        cv.rect(cx - 8, 16, 16, 14, sec_c)
        cv.rect(cx - 14, 15, 5, 13, body_c)
        cv.rect(cx + 9, 15, 5, 13, body_c)
        cv.rect(cx - 7, 34, 5, 8, body_c)
        cv.rect(cx + 2, 34, 5, 8, body_c)
        cv.rect(cx - 5, 6, 10, 9, sec_c)
        # Crown / horns
        cv.line(cx - 4, 6, cx - 8, 2, eye_c, 2)
        cv.line(cx + 4, 6, cx + 8, 2, eye_c, 2)
        cv.rect(cx - 3, 9, 2, 2, eye_c)
        cv.rect(cx + 1, 9, 2, 2, eye_c)
        # Glowing core rune
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


def _draw_boss_shemhaz() -> Canvas:
    cv = Canvas(64, 64)
    cx = 32
    cv.add_ground_shadow(cx, 59, 22, 5.5, 115)
    # Blazing wings / gnarled horns behind
    cv.poly([(cx - 8, 20), (cx - 28, 6), (cx - 24, 34), (cx - 8, 32)], c("maroon"))
    cv.poly([(cx + 8, 20), (cx + 28, 6), (cx + 24, 34), (cx + 8, 32)], c("maroon"))
    cv.line(cx - 26, 8, cx - 12, 24, c("flame"), 2)
    cv.line(cx + 26, 8, cx + 12, 24, c("flame"), 2)
    # Armored magma-root torso
    cv.rect(cx - 12, 18, 24, 28, c("soil_dark"))
    cv.rect(cx - 9, 20, 18, 20, c("crimson_dk"))
    # Molten ribs / core
    for ry in (22, 27, 32):
        cv.line(cx - 7, ry, cx + 7, ry, c("lava"), 2)
    cv.ellipse(cx, 27, 4, 5, c("amber"))
    cv.px(cx, 27, c("gold_glow"))
    # Legs
    cv.rect(cx - 10, 45, 7, 12, c("umber"))
    cv.rect(cx + 3, 45, 7, 12, c("umber"))
    # Horned demon head & flaming crown
    cv.rect(cx - 7, 9, 14, 11, c("crimson"))
    cv.line(cx - 6, 10, cx - 13, 3, c("bone"), 2)
    cv.line(cx + 6, 10, cx + 13, 3, c("bone"), 2)
    cv.rect(cx - 4, 13, 3, 2, c("gold_glow"))
    cv.rect(cx + 1, 13, 3, 2, c("gold_glow"))
    # Twin cleaver blades
    cv.rect(cx - 20, 22, 6, 20, c("stone_lt"))
    cv.line(cx - 20, 22, cx - 20, 41, c("amber"))
    cv.rect(cx + 14, 22, 6, 20, c("stone_lt"))
    cv.line(cx + 19, 22, cx + 19, 41, c("amber"))
    cv.outline(c("black"))
    return cv


def _draw_boss_satanail(megaphase: bool = False) -> Canvas:
    cv = Canvas(96, 96)
    cx = 48
    cv.add_ground_shadow(cx, 89, 32, 7.0, 125)

    if not megaphase:
        # Fallen Seraph Satanail: feathered serrated wings, pauldrons, tattered robes, cracked halo, greatsword
        for s in (-1, 1):
            # Multi-tiered feathered wing pinions
            pts = [
                (cx + s * 9, 28),
                (cx + s * 22, 16),
                (cx + s * 40, 10),
                (cx + s * 43, 20),
                (cx + s * 36, 25),
                (cx + s * 41, 32),
                (cx + s * 33, 37),
                (cx + s * 37, 45),
                (cx + s * 28, 49),
                (cx + s * 24, 42),
                (cx + s * 11, 46),
            ]
            cv.poly(pts, c("frost_dk"))
            cv.poly([(cx + s * 10, 30), (cx + s * 34, 15), (cx + s * 30, 40), (cx + s * 12, 43)], c("slate"))
            # Feather ribs + crimson bloodstain streaks
            for k in range(4):
                cv.line(cx + s * 14, 30 + k * 3, cx + s * (38 - k * 3), 14 + k * 8, c("snow_dk"))
            cv.line(cx + s * 38, 14, cx + s * 28, 36, c("crimson"), 2)

        # Jagged tattered robe hem
        cv.poly([
            (cx - 12, 24), (cx + 12, 24), (cx + 18, 78),
            (cx + 12, 73), (cx + 6, 80), (cx, 74), (cx - 6, 80), (cx - 12, 73), (cx - 18, 78),
        ], c("parchment"))
        cv.poly([(cx - 10, 26), (cx + 10, 26), (cx + 12, 66), (cx - 12, 66)], c("crimson_dk"))
        cv.poly([(cx - 8, 28), (cx + 8, 28), (cx + 6, 56), (cx - 6, 56)], c("maroon"))
        # Armored pauldrons & chestplate
        cv.ellipse(cx - 13, 27, 6, 5, c("stone_lt"))
        cv.ellipse(cx + 13, 27, 6, 5, c("stone_lt"))
        cv.rect(cx - 8, 25, 16, 14, c("stone"))
        cv.rect(cx - 2, 26, 4, 42, c("gold"))
        cv.rect(cx - 7, 31, 14, 2, c("gold_lt"))
        # Head, hood shadow & cracked halo
        cv.ellipse(cx, 18, 7, 7, c("bone"))
        cv.rect(cx - 5, 16, 10, 4, c("slate_vd"))
        cv.rect(cx - 4, 17, 3, 2, c("ember_red"))
        cv.rect(cx + 1, 17, 3, 2, c("ember_red"))
        cv.ring(cx, 8, 13.0, 10.5, c("gold_lt"))
        cv.rect(cx - 2, 4, 4, 6, (0, 0, 0, 0))  # jagged crack
        # Ornate Greatsword
        cv.poly([(cx + 22, 12), (cx + 25, 6), (cx + 28, 12), (cx + 27, 58), (cx + 23, 58)], c("frost"))
        cv.line(cx + 25, 8, cx + 25, 57, c("white"))
        cv.rect(cx + 17, 57, 16, 3, c("gold"))
        cv.rect(cx + 24, 60, 2, 10, c("crimson_dk"))
        cv.ellipse(cx + 25, 71, 3, 3, c("gold_lt"))
    else:
        # TRUE MEGAPHASE: SATAN — towering ragged bat wings, curved demon horns, ribcage sigil, hellblade
        for s in (-1, 1):
            cv.poly([
                (cx + s * 8, 28),
                (cx + s * 28, 10),
                (cx + s * 45, 5),
                (cx + s * 42, 34),
                (cx + s * 36, 48),
                (cx + s * 28, 42),
                (cx + s * 20, 56),
                (cx + s * 12, 48),
            ], c("void"))
            # Wing bone struts
            cv.line(cx + s * 9, 28, cx + s * 45, 5, c("crimson_dk"), 2)
            cv.line(cx + s * 26, 15, cx + s * 39, 34, c("blood_dk"), 2)
            cv.line(cx + s * 18, 21, cx + s * 26, 44, c("blood_dk"), 2)
            cv.px(cx + s * 45, 5, c("ember_red"))

        # Shadow cloak + jagged hem
        cv.poly([
            (cx - 14, 24), (cx + 14, 24), (cx + 22, 82),
            (cx + 14, 75), (cx + 7, 84), (cx, 76), (cx - 7, 84), (cx - 14, 75), (cx - 22, 82),
        ], c("black"))
        cv.poly([(cx - 10, 27), (cx + 10, 27), (cx + 12, 62), (cx - 12, 62)], c("blood_vd"))
        # Spiked pauldrons
        cv.poly([(cx - 18, 28), (cx - 11, 21), (cx - 6, 31)], c("maroon"))
        cv.poly([(cx + 18, 28), (cx + 11, 21), (cx + 6, 31)], c("maroon"))
        cv.line(cx - 16, 24, cx - 22, 16, c("crimson"), 2)
        cv.line(cx + 16, 24, cx + 22, 16, c("crimson"), 2)
        # Glowing hellfire ribcage sigil
        cv.line(cx, 29, cx, 54, c("ember_red"), 2)
        for ry, rw in [(33, 8), (39, 7), (45, 5)]:
            cv.line(cx - rw, ry, cx + rw, ry, c("crimson"), 2)
            cv.px(cx, ry, c("gold_glow"))
        # Curved ram/demon horns
        for s in (-1, 1):
            pts_h = [(cx + s * 5, 16), (cx + s * 11, 9), (cx + s * 17, 5), (cx + s * 20, 10)]
            for i in range(len(pts_h) - 1):
                cv.line(pts_h[i][0], pts_h[i][1], pts_h[i + 1][0], pts_h[i + 1][1], c("crimson_dk"), 3)
                cv.line(pts_h[i][0], pts_h[i][1] - 1, pts_h[i + 1][0], pts_h[i + 1][1] - 1, c("ember_red"), 1)
        # Demon head & blazing eyes
        cv.ellipse(cx, 18, 7, 7, c("black"))
        cv.rect(cx - 5, 17, 3, 2, c("ember_red"))
        cv.rect(cx + 2, 17, 3, 2, c("ember_red"))
        cv.px(cx - 4, 17, c("gold_glow"))
        cv.px(cx + 3, 17, c("gold_glow"))
        # Hellfire Greatsword
        cv.poly([(cx + 24, 12), (cx + 27, 5), (cx + 30, 12), (cx + 29, 60), (cx + 25, 60)], c("crimson"))
        cv.line(cx + 27, 7, cx + 27, 58, c("flame"), 2)
        cv.line(cx + 27, 10, cx + 27, 52, c("gold_glow"))
        cv.rect(cx + 18, 59, 18, 3, c("ember_red"))
        cv.rect(cx + 26, 62, 2, 11, c("maroon"))
        cv.outline(c("crimson_dk"))
        return cv

    cv.outline(c("black"))
    return cv


def _draw_map_boss(boss_id: str) -> Canvas:
    cv = Canvas(64, 64)
    cx = 32
    cv.add_ground_shadow(cx, 59, 20, 5.0, 110)
    styles = {
        "boss_sands": (c("sand_dk"), c("gold"), c("amber"), "pharaoh"),
        "boss_tundra": (c("frost_dk"), c("ice_blue"), c("ice_glow"), "queen"),
        "boss_peak": (c("stone_dk"), c("lava"), c("gold_glow"), "titan"),
        "boss_abyss": (c("slate_vd"), c("violet"), c("ghost_violet"), "lich"),
        "boss_forest": (c("soil_dark"), c("moss"), c("amber"), "patriarch"),
        "boss_rift": (c("arcane_vd"), c("violet_lt"), c("ember_red"), "elder"),
        "boss_graveyard": (c("bone"), c("arcane"), c("glow_green"), "lich"),
        "boss_hive": (c("swamp_dk"), c("poison"), c("pale_green"), "queen"),
        "boss_bloodmoon": (c("blood_dk"), c("crimson"), c("ember_red"), "baron"),
        "boss_chaos": (c("arcane_dk"), c("scarlet"), c("ice_glow"), "elder"),
        "boss_temple": (c("bronze_dk"), c("gold"), c("ice_glow"), "titan"),
        "boss_throne": (c("slate_vd"), c("gold"), c("ember_red"), "baron"),
        "boss_champion": (c("stone_dk"), c("crimson"), c("gold_glow"), "titan"),
    }
    body_c, sec_c, eye_c, form = styles.get(boss_id, styles["boss_champion"])

    if form == "lich":
        # Crowned lich floating above bone throne silhouette
        cv.rect(cx - 18, 16, 36, 36, c("soil_dark"))
        for bx in (-16, -8, 8, 16):
            cv.line(cx + bx, 10, cx + bx, 20, c("bone"), 2)
        cv.poly([(cx - 10, 18), (cx + 10, 18), (cx + 14, 54), (cx - 14, 54)], body_c)
        cv.rect(cx - 3, 20, 6, 28, sec_c)
        cv.rect(cx - 6, 10, 12, 10, c("parchment"))
        cv.rect(cx - 7, 6, 14, 4, c("gold"))
        cv.px(cx - 3, 14, eye_c)
        cv.px(cx + 3, 14, eye_c)
        cv.line(cx + 18, 8, cx + 18, 54, c("leather"), 2)
        cv.ellipse(cx + 18, 8, 4, 4, eye_c)
    elif form == "baron":
        # Winged Vampire / Dread Knight
        cv.poly([(cx - 8, 22), (6, 8), (10, 44), (cx - 8, 40)], body_c)
        cv.poly([(cx + 8, 22), (58, 8), (54, 44), (cx + 8, 40)], body_c)
        cv.rect(cx - 11, 18, 22, 34, sec_c)
        cv.rect(cx - 8, 20, 16, 20, body_c)
        cv.rect(cx - 6, 8, 12, 10, c("parchment"))
        cv.line(cx - 5, 8, cx - 9, 2, c("stone_lt"), 2)
        cv.line(cx + 5, 8, cx + 9, 2, c("stone_lt"), 2)
        cv.rect(cx - 4, 12, 3, 2, eye_c)
        cv.rect(cx + 1, 12, 3, 2, eye_c)
        cv.rect(cx - 18, 14, 4, 38, c("frost"))
        cv.rect(cx - 21, 40, 10, 3, c("gold"))
    elif form == "pharaoh":
        cv.poly([(cx - 12, 16), (cx + 12, 16), (cx + 16, 54), (cx - 16, 54)], body_c)
        cv.rect(cx - 11, 8, 22, 14, sec_c)  # nemes headdress
        cv.rect(cx - 6, 10, 12, 10, c("sand_lt"))
        cv.rect(cx - 3, 14, 2, 2, eye_c)
        cv.rect(cx + 1, 14, 2, 2, eye_c)
        cv.rect(cx - 4, 24, 8, 14, sec_c)
        cv.line(cx + 17, 10, cx + 17, 54, c("gold"), 2)
    else:
        # Titan / Patriarch / Queen
        cv.rect(cx - 14, 16, 28, 26, body_c)
        cv.rect(cx - 10, 19, 20, 18, sec_c)
        cv.rect(cx - 19, 18, 6, 18, body_c)
        cv.rect(cx + 13, 18, 6, 18, body_c)
        cv.rect(cx - 10, 42, 7, 14, body_c)
        cv.rect(cx + 3, 42, 7, 14, body_c)
        cv.rect(cx - 7, 7, 14, 10, sec_c)
        cv.line(cx - 6, 7, cx - 11, 2, eye_c, 2)
        cv.line(cx + 6, 7, cx + 11, 2, eye_c, 2)
        cv.rect(cx - 4, 10, 3, 2, eye_c)
        cv.rect(cx + 1, 10, 3, 2, eye_c)
        cv.ellipse(cx, 27, 4, 4, eye_c)

    cv.outline(c("black"))
    return cv


def generate_bosses() -> int:
    count = 0
    _draw_boss_shemhaz().save(OUT / "boss_shemhaz.png")
    count += 1
    _draw_boss_satanail(False).save(OUT / "boss_satanail.png")
    count += 1
    _draw_boss_satanail(True).save(OUT / "boss_satan.png")
    count += 1
    boss_ids = [
        "boss_champion", "boss_sands", "boss_tundra", "boss_peak", "boss_abyss",
        "boss_forest", "boss_rift", "boss_graveyard", "boss_hive",
        "boss_bloodmoon", "boss_chaos", "boss_temple", "boss_throne",
    ]
    for bid in boss_ids:
        _draw_map_boss(bid).save(OUT / f"{bid}.png")
        count += 1
    return count


def run() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    n += generate_heroes()
    n += generate_enemies()
    n += generate_minibosses()
    n += generate_bosses()
    return n
