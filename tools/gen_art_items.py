# -*- coding: utf-8 -*-
"""Pixel-art generator for Weapons, Projectiles, Pickups, Allies, and RPG Icons."""

from __future__ import annotations

import math
from pathlib import Path

from pixel_art_lib import Canvas, Color, c, draw_icon_frame, mix, mul

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"


def _draw_weapon_sprite(wid: str) -> Canvas:
    """24x16 right-facing held weapon sprite."""
    cv = Canvas(24, 16)
    if wid == "revolver":
        cv.rect(6, 5, 13, 3, c("frost_dk"))
        cv.line(6, 5, 18, 5, c("snow"))
        cv.rect(8, 7, 4, 3, c("iron"))  # cylinder
        cv.poly([(4, 7), (8, 7), (6, 13), (3, 12)], c("leather"))
        cv.px(18, 4, c("gold"))
    elif wid == "shotgun":
        cv.rect(3, 6, 18, 2, c("stone_lt"))
        cv.rect(6, 8, 13, 2, c("iron"))
        cv.rect(2, 8, 6, 3, c("leather"))
        cv.rect(11, 7, 2, 3, c("brass"))
    elif wid == "crossbow":
        cv.rect(4, 7, 15, 2, c("leather_lt"))
        cv.line(15, 2, 18, 7, c("stone_lt"), 2)
        cv.line(18, 8, 15, 14, c("stone_lt"), 2)
        cv.line(15, 2, 10, 7, c("bone"))
        cv.line(15, 14, 10, 8, c("bone"))
        cv.line(10, 7, 21, 7, c("frost"))
        cv.px(21, 7, c("amber"))
    elif wid == "fire_staff":
        cv.line(2, 10, 17, 6, c("soil"), 2)
        cv.rect(16, 4, 4, 5, c("bronze"))
        cv.ellipse(19, 6, 2.5, 2.5, c("lava"))
        cv.px(19, 5, c("gold_glow"))
    elif wid == "bow":
        cv.line(11, 1, 15, 5, c("leather_lt"), 2)
        cv.line(15, 5, 15, 10, c("brass"), 2)
        cv.line(15, 10, 11, 14, c("leather_lt"), 2)
        cv.line(11, 2, 11, 13, c("parchment"))
        cv.line(8, 8, 20, 8, c("frost"))
        cv.px(20, 8, c("white"))
    elif wid == "lightning_staff":
        cv.line(2, 10, 17, 6, c("iron_dk"), 2)
        cv.rect(15, 5, 3, 3, c("bronze"))
        cv.line(18, 6, 20, 4, c("ice_glow"))
        cv.line(20, 4, 19, 8, c("white"))
        cv.line(19, 8, 22, 6, c("ice_lt"))
    elif wid == "magic_books":
        cv.rect(6, 3, 11, 10, c("arcane_dk"))
        cv.rect(8, 4, 7, 8, c("parchment"))
        cv.line(11, 4, 11, 11, c("arcane_vd"))
        cv.px(9, 6, c("violet_lt"))
        cv.px(13, 8, c("gold_glow"))
    elif wid == "fire_ring":
        cv.ring(12, 8, 5.5, 3.0, c("gold"))
        cv.rect(11, 2, 3, 3, c("lava"))
        cv.px(12, 3, c("gold_glow"))
    elif wid == "ice_needles":
        for dy in (-3, 0, 3):
            cv.line(5, 8 + dy, 20, 7 + dy // 2, c("ice_lt"))
            cv.px(20, 7 + dy // 2, c("snow_lt"))
    elif wid == "poison_clouds":
        cv.line(4, 10, 13, 7, c("iron_dk"))
        cv.rect(13, 6, 6, 6, c("moss"))
        cv.rect(14, 7, 4, 4, c("glow_green"))
        cv.px(16, 4, c("pale_green"))
    elif wid == "holy_spears":
        cv.line(2, 8, 17, 8, c("brass"))
        cv.poly([(16, 5), (22, 8), (16, 11)], c("gold_lt"))
        cv.px(19, 8, c("white"))
        cv.line(15, 4, 15, 12, c("parchment"))
    elif wid == "shadow_daggers":
        cv.line(5, 10, 11, 10, c("leather"))
        cv.poly([(11, 9), (21, 7), (14, 11)], c("frost_dk"))
        cv.line(12, 9, 20, 7, c("violet_lt"))
    cv.outline(c("black"))
    return cv


def generate_weapons() -> int:
    wids = [
        "revolver", "shotgun", "crossbow", "fire_staff", "bow", "lightning_staff",
        "magic_books", "fire_ring", "ice_needles", "poison_clouds", "holy_spears", "shadow_daggers",
    ]
    count = 0
    for wid in wids:
        sp = _draw_weapon_sprite(wid)
        sp.save(OUT / f"weapon_{wid}.png")
        count += 1
        # Framed 24x24 icon for UI/Shop
        ic = Canvas(24, 24)
        draw_icon_frame(ic, c("gold"))
        for y in range(16):
            for x in range(24):
                col = sp.get(x, y)
                if col[3] > 0:
                    ic.px(x, y + 4, col)
        ic.save(OUT / f"icon_weapon_{wid}.png")
        count += 1
    return count


def generate_projectiles() -> int:
    count = 0

    def save_p(name: str, cv: Canvas) -> None:
        nonlocal count
        cv.save(OUT / f"projectile_{name}.png")
        count += 1

    # bullet (16x16 horizontal right)
    cv = Canvas(16, 16)
    cv.rect(4, 6, 7, 4, c("gold"))
    cv.rect(10, 7, 3, 2, c("cream"))
    cv.outline(c("black"))
    save_p("bullet", cv)

    # pellet
    cv = Canvas(12, 12)
    cv.ellipse(6, 6, 3.0, 2.5, c("amber"))
    cv.px(6, 5, c("white"))
    cv.outline(c("black"))
    save_p("pellet", cv)

    # arrow
    cv = Canvas(18, 12)
    cv.line(2, 6, 13, 6, c("leather_lt"))
    cv.poly([(12, 3), (16, 6), (12, 9)], c("frost"))
    cv.line(2, 4, 4, 6, c("crimson"))
    cv.line(2, 8, 4, 6, c("crimson"))
    cv.outline(c("black"))
    save_p("arrow", cv)

    # bolt
    cv = Canvas(16, 12)
    cv.rect(3, 5, 9, 2, c("iron"))
    cv.poly([(11, 3), (15, 6), (11, 9)], c("gold_lt"))
    cv.outline(c("black"))
    save_p("bolt", cv)

    # fire
    cv = Canvas(16, 16)
    cv.ellipse(8, 8, 5, 4, c("crimson"))
    cv.ellipse(9, 8, 3.5, 3, c("lava"))
    cv.ellipse(10, 8, 2, 2, c("gold_glow"))
    cv.outline(c("blood_vd"))
    save_p("fire", cv)

    # ice
    cv = Canvas(16, 12)
    cv.poly([(2, 6), (9, 3), (14, 6), (9, 9)], c("ice_blue"))
    cv.line(5, 6, 12, 6, c("snow_lt"))
    cv.outline(c("night"))
    save_p("ice", cv)

    # lightning
    cv = Canvas(16, 16)
    cv.line(2, 9, 7, 5, c("ice_glow"), 2)
    cv.line(7, 5, 9, 10, c("white"), 2)
    cv.line(9, 10, 14, 6, c("ice_glow"), 2)
    cv.outline(c("night"))
    save_p("lightning", cv)

    # orb
    cv = Canvas(16, 16)
    cv.ellipse(8, 8, 5, 5, c("arcane"))
    cv.ellipse(8, 8, 3, 3, c("violet_lt"))
    cv.px(7, 7, c("white"))
    cv.outline(c("black"))
    save_p("orb", cv)

    # gas
    cv = Canvas(20, 20)
    cv.ellipse(10, 10, 7, 7, c("moss_dk", 170))
    cv.ellipse(8, 9, 4, 4, c("poison", 200))
    cv.ellipse(12, 11, 3, 3, c("glow_green", 180))
    save_p("gas", cv)

    # spear
    cv = Canvas(22, 12)
    cv.line(2, 6, 15, 6, c("gold"))
    cv.poly([(14, 3), (20, 6), (14, 9)], c("cream"))
    cv.outline(c("black"))
    save_p("spear", cv)

    # dagger
    cv = Canvas(16, 12)
    cv.rect(2, 5, 4, 2, c("leather"))
    cv.poly([(6, 4), (14, 6), (6, 8)], c("violet_lt"))
    cv.line(7, 6, 12, 6, c("frost"))
    cv.outline(c("black"))
    save_p("dagger", cv)

    # enemy bullet
    cv = Canvas(14, 14)
    cv.ellipse(7, 7, 4, 4, c("crimson"))
    cv.ellipse(7, 7, 2.2, 2.2, c("ember_red"))
    cv.px(6, 6, c("gold_glow"))
    cv.outline(c("black"))
    save_p("enemy", cv)

    # boss orb
    cv = Canvas(18, 18)
    cv.ellipse(9, 9, 6, 6, c("arcane_dk"))
    cv.ellipse(9, 9, 4, 4, c("crimson"))
    cv.ellipse(9, 9, 2, 2, c("gold_glow"))
    cv.outline(c("black"))
    save_p("boss", cv)

    return count


def generate_pickups() -> int:
    count = 0

    def save_pk(name: str, cv: Canvas) -> None:
        nonlocal count
        cv.save(OUT / f"pickup_{name}.png")
        count += 1

    # xp gem (faceted emerald/teal shard)
    cv = Canvas(16, 16)
    cv.poly([(8, 2), (13, 8), (8, 14), (3, 8)], c("ice_blue"))
    cv.poly([(8, 3), (11, 8), (8, 12)], c("ice_glow"))
    cv.px(7, 6, c("white"))
    cv.outline(c("black"))
    save_pk("xp", cv)

    # xp_big (amethyst crystal)
    cv = Canvas(18, 18)
    cv.poly([(9, 1), (15, 9), (9, 17), (3, 9)], c("arcane"))
    cv.poly([(9, 3), (13, 9), (9, 15)], c("ghost_violet"))
    cv.px(7, 6, c("white"))
    cv.outline(c("black"))
    save_pk("xp_big", cv)

    # gold coin
    cv = Canvas(16, 16)
    cv.ellipse(8, 8, 5, 5.5, c("bronze"))
    cv.ellipse(8, 8, 4, 4.5, c("gold"))
    cv.rect(7, 5, 2, 6, c("gold_lt"))
    cv.px(6, 5, c("cream"))
    cv.outline(c("black"))
    save_pk("gold", cv)

    # soul wisp skull orb
    cv = Canvas(16, 16)
    cv.ellipse(8, 8, 5.5, 5.5, c("arcane_dk"))
    cv.ellipse(8, 8, 4, 4, c("violet_lt"))
    cv.rect(6, 6, 4, 4, c("parchment"))
    cv.px(7, 7, c("black"))
    cv.px(9, 7, c("black"))
    cv.outline(c("black"))
    save_pk("soul", cv)

    # heart blood-ruby
    cv = Canvas(16, 16)
    cv.ellipse(5.5, 6, 3.2, 3.0, c("crimson"))
    cv.ellipse(10.5, 6, 3.2, 3.0, c("crimson"))
    cv.poly([(3, 7), (13, 7), (8, 13)], c("crimson"))
    cv.px(5, 5, c("ember_red"))
    cv.px(5, 4, c("cream"))
    cv.outline(c("black"))
    save_pk("heart", cv)

    # chest (iron-bound oak chest)
    cv = Canvas(20, 20)
    cv.rect(3, 6, 14, 10, c("leather"))
    cv.rect(4, 7, 12, 3, c("leather_lt"))
    cv.rect(3, 10, 14, 2, c("iron_dk"))
    cv.rect(4, 6, 2, 10, c("brass"))
    cv.rect(14, 6, 2, 10, c("brass"))
    cv.rect(9, 9, 2, 3, c("gold_lt"))
    cv.outline(c("black"))
    save_pk("chest", cv)

    # relic item (wax-sealed tome)
    cv = Canvas(18, 18)
    cv.rect(4, 3, 10, 12, c("crimson_dk"))
    cv.rect(5, 4, 8, 10, c("parchment"))
    cv.rect(5, 4, 3, 10, c("maroon"))
    cv.ellipse(10, 9, 2, 2, c("gold"))
    cv.outline(c("black"))
    save_pk("item", cv)

    return count


def generate_allies() -> int:
    count = 0

    def save_a(name: str, cv: Canvas) -> None:
        nonlocal count
        cv.save(OUT / f"ally_{name}.png")
        count += 1

    # spirit
    cv = Canvas(24, 24)
    cv.ellipse(12, 10, 5, 5, c("ice_blue"))
    cv.poly([(7, 11), (17, 11), (14, 20), (12, 17), (10, 20)], c("frost_blue"))
    cv.px(10, 9, c("white"))
    cv.px(14, 9, c("white"))
    cv.outline(c("night"))
    save_a("spirit", cv)

    # boomerang: бронзовая V-образная пластина с бликом
    cv = Canvas(24, 24)
    cv.line(6, 18, 12, 4, c("brass"), 3)
    cv.line(12, 4, 18, 18, c("brass"), 3)
    cv.line(7, 17, 12, 5, c("gold_lt"))
    cv.line(12, 5, 17, 17, c("gold_lt"))
    cv.px(12, 6, c("cream"))
    cv.px(9, 12, c("gold_glow"))
    cv.px(15, 12, c("gold_glow"))
    cv.outline(c("black"))
    save_a("boomerang", cv)

    # skeleton
    cv = Canvas(24, 24)
    cv.rect(9, 5, 6, 5, c("parchment"))
    cv.px(10, 7, c("ice_glow"))
    cv.px(13, 7, c("ice_glow"))
    cv.rect(9, 11, 6, 7, c("iron_dk"))
    cv.rect(10, 12, 4, 1, c("bone"))
    cv.rect(10, 14, 4, 1, c("bone"))
    cv.line(16, 7, 16, 16, c("frost"))
    cv.rect(9, 18, 2, 4, c("bone"))
    cv.rect(13, 18, 2, 4, c("bone"))
    cv.outline(c("black"))
    save_a("skeleton", cv)

    # turret
    cv = Canvas(24, 24)
    cv.rect(6, 14, 12, 6, c("iron_dk"))
    cv.rect(8, 8, 8, 7, c("bronze"))
    cv.rect(14, 9, 7, 3, c("stone_lt"))
    cv.px(11, 10, c("amber"))
    cv.outline(c("black"))
    save_a("turret", cv)

    # blade
    cv = Canvas(24, 24)
    cv.poly([(11, 3), (14, 7), (13, 17), (11, 17), (10, 7)], c("frost"))
    cv.line(12, 4, 12, 16, c("white"))
    cv.rect(8, 17, 8, 2, c("gold"))
    cv.rect(11, 19, 2, 3, c("leather"))
    cv.outline(c("black"))
    save_a("blade", cv)

    # tornado
    cv = Canvas(24, 24)
    for y, r in [(6, 7), (9, 5.5), (12, 4.5), (15, 3), (18, 1.8)]:
        cv.ellipse(12, y, r, 1.6, c("frost_dk"))
        cv.line(int(12 - r + 1), y, int(12 + r - 1), y, c("snow_lt"))
    cv.outline(c("slate_vd"))
    save_a("tornado", cv)

    # phoenix
    cv = Canvas(24, 24)
    cv.poly([(4, 10), (11, 12), (6, 17)], c("lava"))
    cv.poly([(20, 10), (13, 12), (18, 17)], c("lava"))
    cv.ellipse(12, 12, 3.5, 5, c("flame"))
    cv.px(12, 8, c("gold_glow"))
    cv.outline(c("blood_dk"))
    save_a("phoenix", cv)

    # moth
    cv = Canvas(24, 24)
    cv.ellipse(8, 11, 4.5, 4, c("ice_lt"))
    cv.ellipse(16, 11, 4.5, 4, c("ice_lt"))
    cv.rect(11, 8, 2, 8, c("snow_lt"))
    cv.outline(c("night"))
    save_a("moth", cv)

    # scythe
    cv = Canvas(24, 24)
    cv.line(8, 20, 15, 5, c("soil"))
    cv.poly([(14, 4), (4, 6), (8, 10), (15, 7)], c("frost"))
    cv.line(6, 6, 13, 5, c("violet_lt"))
    cv.outline(c("black"))
    save_a("scythe", cv)

    # spear
    cv = Canvas(24, 24)
    cv.line(12, 19, 12, 8, c("gold"))
    cv.poly([(9, 9), (12, 3), (15, 9)], c("cream"))
    cv.outline(c("black"))
    save_a("spear", cv)

    # beetle
    cv = Canvas(24, 24)
    cv.ellipse(12, 12, 5, 6, c("bronze"))
    cv.line(12, 7, 12, 17, c("gold_glow"))
    cv.line(10, 6, 8, 3, c("amber"))
    cv.line(14, 6, 16, 3, c("amber"))
    cv.outline(c("black"))
    save_a("beetle", cv)

    # clone
    cv = Canvas(24, 24)
    cv.rect(9, 6, 6, 5, c("arcane"))
    cv.rect(8, 11, 8, 8, c("arcane_dk"))
    cv.px(10, 8, c("ghost_violet"))
    cv.px(13, 8, c("ghost_violet"))
    cv.outline(c("black"))
    save_a("clone", cv)

    # dragon
    cv = Canvas(24, 24)
    cv.poly([(4, 9), (10, 11), (6, 16)], c("crimson"))
    cv.poly([(20, 9), (14, 11), (18, 16)], c("crimson"))
    cv.ellipse(12, 12, 4, 5, c("blood"))
    cv.rect(10, 5, 4, 4, c("scarlet"))
    cv.px(12, 4, c("amber"))
    cv.outline(c("black"))
    save_a("dragon", cv)

    # aura
    cv = Canvas(32, 32)
    cv.ring(16, 16, 14, 12, c("gold_lt", 180))
    cv.ring(16, 16, 9, 8, c("amber", 130))
    save_a("aura", cv)

    return count


def _draw_symbol_icon(name: str, accent: Color, motif: str) -> Canvas:
    cv = Canvas(24, 24)
    draw_icon_frame(cv, accent)
    hi = mix(accent, c("white"), 0.45)
    dk = mul(accent, 0.55)

    if motif == "arrow":
        cv.line(6, 17, 17, 6, c("leather_lt"), 2)
        cv.poly([(13, 6), (18, 6), (18, 11)], hi)
        cv.line(6, 14, 8, 16, accent)
        cv.line(8, 16, 10, 18, accent)
    elif motif == "boomerang":
        cv.line(7, 17, 12, 9, hi, 2)
        cv.line(12, 9, 17, 17, hi, 2)
        cv.px(12, 8, c("white"))
        cv.line(6, 18, 9, 14, accent)
        cv.line(18, 18, 15, 14, accent)
    elif motif == "sword":
        cv.line(7, 17, 17, 7, hi, 2)
        cv.line(6, 14, 10, 18, c("gold"))
        cv.px(6, 18, c("crimson"))
    elif motif == "bolt":
        cv.line(14, 5, 9, 12, hi, 2)
        cv.line(9, 12, 14, 12, c("white"), 2)
        cv.line(14, 12, 9, 18, accent, 2)
    elif motif == "flame":
        cv.ellipse(12, 14, 4.5, 4.5, c("crimson"))
        cv.poly([(8, 14), (12, 5), (16, 14)], accent)
        cv.poly([(10, 15), (12, 9), (14, 15)], c("gold_glow"))
    elif motif == "frost":
        cv.line(12, 5, 12, 18, hi)
        cv.line(6, 12, 18, 12, hi)
        cv.line(7, 7, 17, 17, accent)
        cv.line(17, 7, 7, 17, accent)
        cv.px(12, 12, c("white"))
    elif motif == "skull":
        cv.rect(8, 6, 8, 7, c("parchment"))
        cv.rect(9, 13, 6, 4, c("bone"))
        cv.px(10, 9, c("black"))
        cv.px(13, 9, c("black"))
        cv.px(10, 15, dk)
        cv.px(13, 15, dk)
    elif motif == "heart":
        cv.ellipse(9.5, 10, 3, 2.8, accent)
        cv.ellipse(14.5, 10, 3, 2.8, accent)
        cv.poly([(7, 11), (17, 11), (12, 17)], accent)
        cv.px(9, 9, hi)
    elif motif == "shield":
        cv.poly([(7, 6), (17, 6), (16, 14), (12, 18), (8, 14)], dk)
        cv.poly([(8, 7), (16, 7), (15, 13), (12, 16), (9, 13)], accent)
        cv.line(12, 7, 12, 16, hi)
    elif motif == "eye":
        cv.ellipse(12, 12, 6, 3.5, c("parchment"))
        cv.ellipse(12, 12, 2.5, 2.5, accent)
        cv.px(12, 12, c("black"))
    elif motif == "wing":
        cv.poly([(6, 16), (9, 6), (18, 8), (14, 14)], hi)
        cv.line(7, 15, 16, 9, accent)
    elif motif == "ring":
        cv.ring(12, 13, 5.2, 3.0, c("gold"))
        cv.rect(11, 6, 3, 3, hi)
    elif motif == "star":
        cv.line(12, 5, 12, 19, hi)
        cv.line(5, 12, 19, 12, hi)
        cv.line(8, 8, 16, 16, accent)
        cv.line(16, 8, 8, 16, accent)
        cv.px(12, 12, c("white"))
    elif motif == "dragon":
        cv.poly([(6, 15), (10, 7), (17, 8), (15, 14), (11, 17)], accent)
        cv.px(13, 9, c("gold_glow"))
        cv.line(8, 8, 10, 5, hi)
    elif motif == "scythe":
        cv.line(9, 18, 15, 6, c("leather_lt"))
        cv.poly([(15, 5), (6, 7), (9, 10), (15, 7)], hi)
    elif motif == "boot":
        cv.rect(8, 6, 5, 9, c("leather_lt"))
        cv.rect(8, 14, 9, 4, accent)
        cv.line(6, 8, 9, 6, hi)
    elif motif == "crown":
        cv.rect(6, 13, 12, 4, accent)
        cv.poly([(6, 13), (8, 7), (10, 12), (12, 6), (14, 12), (16, 7), (18, 13)], hi)
    else:  # orb / rune
        cv.ellipse(12, 12, 5, 5, dk)
        cv.ellipse(12, 12, 3.5, 3.5, accent)
        cv.px(10, 10, hi)

    return cv


def generate_rpg_icons() -> int:
    count = 0
    trees = {
        "fast_arrows": (c("frost"), "arrow"),
        "damage": (c("crimson"), "sword"),
        "fire_rate": (c("amber"), "bolt"),
        "multishot": (c("gold"), "arrow"),
        "reload": (c("brass"), "ring"),
        "proj_speed": (c("ice_lt"), "arrow"),
        "pierce": (c("snow"), "sword"),
        "thunder": (c("ice_glow"), "bolt"),
        "flame": (c("lava"), "flame"),
        "frost": (c("frost_blue"), "frost"),
        "dark": (c("violet"), "skull"),
        "light": (c("gold_glow"), "star"),
        "health": (c("scarlet"), "heart"),
        "shield": (c("ice_blue"), "shield"),
        "dodge": (c("glow_green"), "wing"),
        "soul": (c("violet_lt"), "skull"),
        "pickup": (c("gold"), "ring"),
        "move": (c("sand_lt"), "boot"),
        "vision": (c("amber"), "eye"),
        "wind": (c("snow"), "wing"),
        "summon": (c("ghost_violet"), "star"),
        "dragon": (c("ember_red"), "dragon"),
        "scythe": (c("crimson"), "scythe"),
        "boomerang": (c("brass"), "boomerang"),
        "beast": (c("life"), "dragon"),
    }
    for tid, (col, mot) in trees.items():
        _draw_symbol_icon(tid, col, mot).save(OUT / f"icon_tree_{tid}.png")
        count += 1

    synergies = {
        "syn_reaper": (c("crimson"), "scythe"),
        "syn_iceflame": (c("ice_glow"), "flame"),
        "syn_weaponmaster": (c("gold_lt"), "sword"),
        "syn_smallmag": (c("amber"), "bolt"),
        "syn_overload": (c("ice_lt"), "bolt"),
        "syn_unbreakable": (c("frost"), "shield"),
        "syn_summonpower": (c("ghost_violet"), "crown"),
        "syn_plague": (c("glow_green"), "skull"),
        "syn_resonance": (c("violet_lt"), "star"),
        "syn_windshadow": (c("moon_stone"), "wing"),
        "syn_swordshield": (c("gold"), "shield"),
        "syn_giant": (c("lava"), "heart"),
    }
    for sid, (col, mot) in synergies.items():
        _draw_symbol_icon(sid, col, mot).save(OUT / f"icon_{sid}.png")
        count += 1

    seals = {
        "seal_bounce": (c("ice_lt"), "star"),
        "seal_thunder": (c("ice_glow"), "bolt"),
        "seal_elements": (c("flame"), "flame"),
        "seal_fragility": (c("ember_red"), "skull"),
        "seal_might": (c("crimson"), "sword"),
        "seal_strength": (c("gold"), "crown"),
        "seal_fury": (c("scarlet"), "flame"),
        "seal_swift": (c("frost"), "boot"),
        "seal_steadfast": (c("bronze"), "shield"),
        "seal_summon": (c("violet_lt"), "ring"),
        "seal_life": (c("life"), "heart"),
        "seal_wind": (c("snow"), "wing"),
    }
    for sid, (col, mot) in seals.items():
        _draw_symbol_icon(sid, col, mot).save(OUT / f"icon_{sid}.png")
        count += 1

    amulets = {
        "amu_echo": (c("violet_lt"), "ring"),
        "amu_bodiless": (c("ice_glow"), "wing"),
        "amu_rhythm": (c("amber"), "star"),
        "amu_courage": (c("gold"), "sword"),
        "amu_fortress": (c("stone_lt"), "shield"),
        "amu_fragility": (c("crimson"), "skull"),
        "amu_spark": (c("ice_lt"), "bolt"),
        "amu_frost": (c("frost_blue"), "frost"),
        "amu_agility": (c("glow_green"), "boot"),
        "amu_foresight": (c("gold_glow"), "eye"),
        "amu_growth": (c("life"), "star"),
        "amu_endurance": (c("bronze"), "heart"),
        "amu_recovery": (c("scarlet"), "heart"),
        "amu_soulbond": (c("ghost_violet"), "skull"),
        "amu_bulwark": (c("gold_lt"), "shield"),
        "amu_secondwind": (c("snow"), "wing"),
    }
    for aid, (col, mot) in amulets.items():
        _draw_symbol_icon(aid, col, mot).save(OUT / f"icon_{aid}.png")
        count += 1

    return count


def run() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    return (
        generate_weapons()
        + generate_projectiles()
        + generate_pickups()
        + generate_allies()
        + generate_rpg_icons()
    )
