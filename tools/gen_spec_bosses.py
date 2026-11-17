# -*- coding: utf-8 -*-
"""data/bosses.json по BOSSES_COMPLETE_SPECIFICATION.md (Шемхаз + САТАНАИЛ + мегафаза САТАН)."""
import json, os
W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def pat(t, interval, **params):
    return {"type": t, "interval": interval, "params": params}

SHEMHAZ = {
 "id": "boss_shemhaz", "name": "Шемхаз", "hp": 7500, "color": "#8b0000", "color2": "#ff4500",
 "radius": 48, "sprite": [128,128], "collide": [96,96], "damage": 5, "speed": 40,
 "xp": 500, "reward": "реликвия", "desc": "Корень-демон. Финальный босс забега, 3 фазы.",
 "phases": [
  {"at": 1.00, "speed_mult": 1.0, "patterns": [
     pat("fireball", 3.0, count=1, spread=0.0, speed=200, damage=5, size=32),
     pat("chain_slam", 5.0, radius=128, damage=5, slow=0.5, slow_dur=2.0)]},
  {"at": 0.70, "speed_mult": 1.25, "patterns": [
     pat("fireball", 2.0, count=3, spread=60.0, speed=240, damage=5, size=32),
     pat("chain_slam", 4.0, radius=160, damage=5, slow=0.5, slow_dur=3.0),
     pat("summon", 10.0, enemy="demon", count=3)]},
  {"at": 0.40, "speed_mult": 1.5, "regen": 5.0, "patterns": [
     pat("fireball", 1.5, count=5, spread=90.0, speed=280, damage=5, size=40),
     pat("chain_slam", 3.0, radius=192, damage=5, slow=0.5, slow_dur=4.0),
     pat("summon", 8.0, enemy="demon", count=5),
     pat("storm_aura", 12.0, radius=128, dps=3.0, duration=5.0, color="#ff4500")]},
 ],
}

SATANAIL = {
 "id": "boss_satanail", "name": "САТАНАИЛ", "hp": 10000, "color": "#8b0000", "color2": "#ffd700",
 "radius": 64, "sprite": [192,192], "collide": [128,128], "damage": 7, "speed": 50,
 "xp": 2000, "reward": "5 реликвий + Крыло САТАНАИЛА", "desc": "Секретный босс Пустоты, 3 фазы + мегафаза САТАН.",
 "phases": [
  {"at": 1.00, "speed_mult": 1.0, "patterns": [
     pat("holy_light", 4.0, count=1, spread=0.0, speed=240, damage=7, size=48),
     pat("dark_chains", 6.0, radius=192, damage=7, root=1.5)]},
  {"at": 0.80, "speed_mult": 1.25, "patterns": [
     pat("holy_light", 3.0, count=3, spread=60.0, speed=280, damage=7, size=48),
     pat("dark_chains", 5.0, radius=224, damage=7, root=2.0),
     pat("summon", 12.0, enemy="fallen_angel", count=5)]},
  {"at": 0.50, "speed_mult": 1.5, "regen": 10.0, "patterns": [
     pat("holy_light", 2.0, count=5, spread=90.0, speed=320, damage=7, size=56),
     pat("dark_chains", 4.0, radius=256, damage=7, root=2.5),
     pat("summon", 10.0, enemy="fallen_angel", count=7),
     pat("storm_aura", 15.0, radius=192, dps=5.0, duration=6.0, color="#000000")]},
  {"at": 0.20, "speed_mult": 2.0, "regen": 20.0, "mega": True, "patterns": [
     pat("holy_light", 1.5, count=7, spread=120.0, speed=360, damage=10, size=64),
     pat("dark_chains", 3.0, radius=320, damage=10, root=3.0),
     pat("summon", 8.0, enemy="fallen_angel", count=10),
     pat("storm_aura", 12.0, radius=256, dps=8.0, duration=8.0, color="#000000"),
     pat("apocalypse", 20.0, damage=15, warn=3.0, balls=100)]},
 ],
}

# Чемпионы карт на 15:00 — используют те же паттерны Шемхаза, но слабее и своих цветов.
CHAMPIONS = {
 "sands":     ("Песчаный Владыка",  "#c4a55a", 1600),
 "tundra":    ("Ледяной Ужас",      "#a8d8ea", 1800),
 "peak":      ("Пик Огня",          "#ff4500", 2000),
 "abyss":     ("Эхо Бездны",        "#9370db", 2200),
 "forest":    ("Древень-Патриарх",  "#2d5a2d", 2400),
 "rift":      ("Разлом Безумия",    "#7fff00", 2600),
 "graveyard": ("Владыка Погоста",   "#808080", 2800),
 "hive":      ("Матка Улья",        "#6b8e23", 3000),
 "bloodmoon": ("Кровавый Лунарх",   "#8b0000", 3200),
 "chaos":     ("Искажение",         "#9400d3", 3400),
 "temple":    ("Хранитель Храма",   "#ffd700", 3600),
 "throne":    ("Шелтик",            "#b8860b", 4000),
}
bosses = {"shemhaz": SHEMHAZ, "satanail": SATANAIL}
for key, (name, color, hp) in CHAMPIONS.items():
    champ = json.loads(json.dumps(SHEMHAZ))
    champ.update({"id": "champ_" + key, "name": name, "hp": hp, "color": color,
                  "radius": 40, "sprite": [96,96], "collide": [72,72], "damage": 4, "speed": 45,
                  "xp": 300, "desc": "Чемпион карты. Появляется на 15:00."})
    champ["phases"] = champ["phases"][:2]
    bosses[key] = champ

json.dump({"bosses": bosses, "sathan": SATANAIL}, open(os.path.join(W, "data", "bosses.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("bosses:", list(bosses.keys()))
