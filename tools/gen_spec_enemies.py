# -*- coding: utf-8 -*-
"""Генерация data/enemies.json строго по ENEMIES_COMPLETE_SPECIFICATION.md."""
import json, os

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def enemy(**kw): return kw

ENEMIES = [
 enemy(id="slime", name="Слизень", role="fodder", cls="slime", hp=2, speed=40, damage=1, xp=1,
   radius=5, sprite=[16,16], collide=[10,10], color="#00ff00", color2="#7fff00", color3="#008000",
   desc="Простой зелёный слайм. Идёт прямо к игроку, бьёт при контакте.",
   clan="beast", hp_scale_per_min=0.0, resist={}, immune=[], armor=0.0,
   behavior={"kind":"chase","attack_cd":1.0},
   flags={"group":5,"split_chance":0.2,"split_count":2,"split_enemy":"slime_small"}),
 enemy(id="slime_small", name="Малый слизень", role="fodder", cls="slime", hp=1, speed=30, damage=1, xp=1,
   radius=4, sprite=[8,8], collide=[6,6], color="#7fff00", color2="#00ff00", color3="#008000",
   desc="Осколок слизня: быстрый и хрупкий.", clan="beast", hp_scale_per_min=0.0, resist={}, immune=[], armor=0.0,
   behavior={"kind":"chase","attack_cd":1.0}, flags={"nospawn":True}),
 enemy(id="goblin_archer", name="Гоблин-лучник", role="shooter", cls="goblin_archer", hp=4, speed=50, damage=1, xp=2,
   radius=5, sprite=[16,16], collide=[10,10], color="#00ff7f", color2="#8b4513", color3="#c0c0c0",
   desc="Держит дистанцию 200 px, стреляет стрелами раз в 2 сек.",
   clan="beast", hp_scale_per_min=0.05, resist={}, immune=[], armor=0.0,
   behavior={"kind":"shooter","keep":200,"attack_cd":2.0,
             "proj":{"damage":1,"speed":100,"interval":2.0,"life":3.0,"color":"#c0c0c0"}},
   flags={"group":3,"volley_delay":0.5}),
 enemy(id="frozen_zombie", name="Замёрзший зомби", role="fodder", cls="frozen_zombie", hp=12, speed=30, damage=2, xp=5,
   radius=8, sprite=[24,24], collide=[16,16], color="#a8d8ea", color2="#7fb3c8", color3="#5a5a5a",
   desc="Медленный танк. Аура холода −15% скорости, после смерти лужа льда.",
   clan="undead", hp_scale_per_min=0.08, resist={"all":0.25}, immune=["slow"], armor=0.0,
   behavior={"kind":"chase","attack_cd":1.5},
   flags={"cold_aura":48.0,"cold_slow":0.15,"ice_puddle_radius":32.0,"ice_puddle_dur":3.0,"ice_puddle_slow":0.3}),
 enemy(id="bat", name="Летучая мышь", role="fodder", cls="bat", hp=3, speed=80, damage=1, xp=2,
   radius=5, sprite=[16,16], collide=[10,10], color="#9370db", color2="#4b0082", color3="#ffffff",
   desc="Летает кругом, пикирует на игрока.", clan="beast", hp_scale_per_min=0.04, resist={}, immune=["ground"], armor=0.0,
   behavior={"kind":"orbit","orbit":128.0,"attack_cd":3.0,"dive_speed":120.0},
   flags={"group":5,"dive_delay":1.0}),
 enemy(id="skeleton_warrior", name="Скелет-воин", role="fodder", cls="skeleton_warrior", hp=8, speed=70, damage=2, xp=4,
   radius=8, sprite=[24,24], collide=[16,16], color="#f5f5dc", color2="#808080", color3="#00ff00",
   desc="Идёт в ближний бой, 10% шанс заблокировать удар.",
   clan="undead", hp_scale_per_min=0.06, resist={"physical":0.2}, immune=["poison"], armor=0.0,
   behavior={"kind":"chase","attack_cd":1.2},
   flags={"group":4,"block_chance":0.1}),
 enemy(id="dark_mage", name="Тёмный маг", role="elite", cls="dark_mage", hp=15, speed=45, damage=3, xp=8,
   radius=8, sprite=[24,24], collide=[16,16], color="#9c27b0", color2="#4a148c", color3="#1a0033",
   desc="Элитный стрелок. Телепорт раз в 5 сек, 15% шанс отразить снаряд.",
   clan="demon", hp_scale_per_min=0.10, resist={"magic":0.3}, immune=["burn"], armor=0.0,
   behavior={"kind":"shooter","keep":200,"attack_cd":2.5,
             "proj":{"damage":3,"speed":120,"interval":2.5,"life":3.5,"color":"#9c27b0"}},
   flags={"group":2,"teleport_interval":5.0,"teleport_dist":64.0,"shield_reflect":0.15}),
 enemy(id="werewolf", name="Оборотень", role="elite", cls="werewolf", hp=20, speed=90, damage=4, xp=10,
   radius=10, sprite=[32,32], collide=[20,20], color="#8b4513", color2="#5a2d0c", color3="#ff0000",
   desc="Очень быстрый. Рывок раз в 3 сек, регенерация 1 HP/5 сек.",
   clan="beast", hp_scale_per_min=0.12, resist={"physical":0.4}, immune=["slow"], armor=0.0,
   behavior={"kind":"charger","charge_speed":180.0,"interval":3.0},
   flags={"group":2,"dash_dist":96.0,"regen":{"hp":1.0,"every":5.0},"bloodlust":0.25}),
 # ---- призывы боссов
 enemy(id="demon", name="Демон", role="fodder", cls="demon", hp=5, speed=80, damage=2, xp=2,
   radius=5, sprite=[16,16], collide=[10,10], color="#1a1a1a", color2="#8b0000", color3="#ff0000",
   desc="Призыв Шемхаза. Быстрый, живёт 15 сек.", clan="demon", hp_scale_per_min=0.0, resist={}, immune=[], armor=0.0,
   behavior={"kind":"chase","attack_cd":0.8}, flags={"nospawn":True,"lifetime":15.0}),
 enemy(id="fallen_angel", name="Падший ангел", role="elite", cls="fallen_angel", hp=15, speed=100, damage=5, xp=4,
   radius=9, sprite=[24,24], collide=[18,18], color="#000000", color2="#ffd700", color3="#ffffff",
   desc="Призыв САТАНАИЛА. Живёт 20 сек.", clan="demon", hp_scale_per_min=0.0, resist={}, immune=[], armor=0.0,
   behavior={"kind":"shooter","keep":160,"attack_cd":2.0,
             "proj":{"damage":5,"speed":140,"interval":2.0,"life":3.0,"color":"#ffd700"}},
   flags={"nospawn":True,"lifetime":20.0}),
]

# Мини-боссы карт: чемпионы, собранные по тем же архетипам (спецификация боссов описывает только 2 финальных).
MINIBOSSES = [
 ("sands",    "Песчаный Колосс",  "skeleton_warrior", 200),
 ("tundra",   "Ледяной Йети",     "frozen_zombie",    240),
 ("peak",     "Скальный Голем",   "skeleton_warrior", 280),
 ("abyss",    "Эхо-Страж",        "bat",              320),
 ("forest",   "Древень",          "slime",            370),
 ("rift",     "Безумный Жнец",    "skeleton_warrior", 420),
 ("graveyard","Могильщик",        "frozen_zombie",    480),
 ("hive",     "Королева Улья",    "bat",              550),
 ("bloodmoon","Кровавый Палач",   "werewolf",         640),
 ("chaos",    "Искажённый",       "dark_mage",        740),
 ("temple",   "Хранитель Храма",  "skeleton_warrior", 860),
 ("throne",   "Шелтик",           "werewolf",        1000),
]
by_id = {e["id"]: e for e in ENEMIES}
for mid, mname, base, hp in MINIBOSSES:
    b = dict(by_id[base])
    b = json.loads(json.dumps(b))
    b.update({"id": "mb_" + mid, "name": mname, "role": "miniboss", "cls": b["cls"] + "_chief",
              "hp": hp, "speed": round(float(b["speed"]) * 0.8, 1), "damage": max(3, int(b["damage"]) + 1),
              "xp": 50, "radius": float(b["radius"]) * 1.6, "sprite": [48,48], "collide": [36,36],
              "hp_scale_per_min": 0.0, "desc": "Чемпион карты. Усиленная версия обычного врага.",
              "flags": {"group": 0}})
    b["flags"]["nospawn"] = True
    if base == "dark_mage":
        b["behavior"] = {"kind":"shooter","keep":220,"attack_cd":2.0,
                         "proj":{"damage":6,"speed":150,"interval":2.0,"life":3.5,"color":"#9c27b0"}}
        b["flags"].update({"teleport_interval":4.0,"teleport_dist":80.0,"shield_reflect":0.2})
    if base == "werewolf":
        b["behavior"] = {"kind":"charger","charge_speed":200.0,"interval":2.5}
        b["flags"].update({"regen":{"hp":3.0,"every":4.0},"bloodlust":0.3})
    ENEMIES.append(b)

json.dump(ENEMIES, open(os.path.join(W, "data", "enemies.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("enemies:", len(ENEMIES))
