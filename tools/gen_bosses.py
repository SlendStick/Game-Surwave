# -*- coding: utf-8 -*-
"""data/bosses.json по промпту COMPLETE_BOSS_FIGHTS_PROMPT (14 обычных + секретный).

Каждый босс: 3–5 фаз с порогами 1.0 / 0.70 / 0.40 / 0.15, свой набор атак из
словаря `_exec_pattern` в scripts/enemies/enemy.gd, телеграфы и награды.

Запуск: python3 tools/gen_bosses.py
"""
import json
import os

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def pat(t, interval, **params):
    return {"type": t, "interval": interval, "params": params}


def phase(at, mult, patterns, regen=0.0, mega=False):
    ph = {"at": at, "speed_mult": mult, "patterns": patterns}
    if regen > 0.0:
        ph["regen"] = regen
    if mega:
        ph["mega"] = True
    return ph


# ---------------------------------------------------------------- РЕГУЛЯРНЫЕ БОССЫ
# Ключ = карта (boss_<ключ>.png), имя/HP/атаки — из спеки босс-файтов.
REGULAR = {
    # 1. Инфернальный Лорд — огненный демон, первый босс
    "sands": dict(
        ai="aggressive",
        name="Инфернальный Лорд", hp=3000, color="#8b0000", color2="#ff4500",
        damage=5, speed=35, element="fire", souls=150,
        desc="Демон огня. Первый босс забега, 4 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("fireball", 3.0, count=1, spread=0.0, speed=180, damage=8, size=32),
                pat("ring", 6.0, count=8, speed=140, damage=5, burn=True),
            ]),
            phase(0.70, 1.15, [
                pat("fireball", 3.0, count=2, spread=30.0, speed=200, damage=8, size=32),
                pat("pillar", 5.0, count=1, radius=64, damage=10),
            ]),
            phase(0.40, 1.3, [
                pat("fireball", 2.5, count=3, spread=45.0, speed=220, damage=8, size=36),
                pat("pillar", 4.0, count=2, radius=64, damage=10),
                pat("summon", 8.0, enemy="demon", count=3),
            ]),
            phase(0.15, 1.5, [
                pat("storm_aura", 10.0, radius=128, dps=5.0, duration=3.0, color="#ff4500"),
                pat("ring", 5.0, count=12, speed=170, damage=8, burn=True),
            ], regen=2.0),
        ],
    ),
    # 2. Ледяная Королева
    "tundra": dict(
        ai="tactical",
        name="Ледяная Королева", hp=4500, color="#a8d8ea", color2="#4a90d9",
        damage=5, speed=30, element="ice", souls=150,
        desc="Повелительница льда, 4 фазы. Замораживает и бьёт лучами.",
        phases=[
            phase(1.0, 1.0, [
                pat("beam", 2.5, length=280, damage=6),
                pat("spikes", 6.0, count=2, radius=44, damage=8),
            ]),
            phase(0.70, 1.15, [
                pat("beam", 2.0, length=300, damage=6),
                pat("spikes", 5.0, count=3, radius=44, damage=8),
                pat("storm_aura", 6.0, radius=96, dps=3.0, duration=3.0, color="#a8d8ea"),
            ]),
            phase(0.40, 1.3, [
                pat("ring", 4.0, count=12, speed=160, damage=6),
                pat("spikes", 4.0, count=4, radius=48, damage=9),
                pat("summon", 10.0, enemy="frozen_zombie", count=2),
            ]),
            phase(0.15, 1.5, [
                pat("seal", 9.0, radius=110, damage=16),
                pat("storm_aura", 12.0, radius=160, dps=5.0, duration=4.0, color="#a8d8ea"),
            ], regen=3.0),
        ],
    ),
    # 3. Титан Грозы
    "peak": dict(
        ai="cautious",
        name="Титан Грозы", hp=6000, color="#6a5acd", color2="#ffd700",
        damage=6, speed=25, element="storm", souls=150,
        desc="Грозовой гигант. Медленный, но бьёт молниями по площади, 4 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("lightning", 3.0, count=1, damage=12, radius=32),
                pat("chain_slam", 6.0, radius=128, damage=8, slow=0.4, slow_dur=2.0),
            ]),
            phase(0.70, 1.1, [
                pat("lightning", 2.5, count=2, damage=12, radius=32),
                pat("wing", 5.0, count=3, damage=8),
            ]),
            phase(0.40, 1.25, [
                pat("lightning", 2.0, count=3, damage=12, radius=32),
                pat("pull", 7.0, radius=200, force=120),
                pat("summon", 12.0, enemy="dark_mage", count=2),
            ]),
            phase(0.15, 1.45, [
                pat("lightning", 1.8, count=4, damage=12, radius=32),
                pat("chain_slam", 5.0, radius=160, damage=18, slow=0.5, slow_dur=2.5),
                pat("storm_aura", 15.0, radius=192, dps=8.0, duration=5.0, color="#ffd700"),
            ], regen=4.0),
        ],
    ),
    # 4. Кровавый Рыцарь — вампиризм
    "forest": dict(
        ai="aggressive",
        name="Кровавый Рыцарь", hp=5000, color="#8b0000", color2="#b22222",
        damage=5, speed=45, element="blood", souls=150,
        desc="Рыцарь в кровавых доспехах. Рывки, конусы и лечение, 3 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("dash", 4.0, speed=300),
                pat("cone", 5.0, radius=110, angle=70, damage=10),
            ]),
            phase(0.70, 1.2, [
                pat("dash", 3.5, speed=320),
                pat("scythe", 5.0, count=5, damage=10),
                pat("heal", 9.0, amount=60),
            ]),
            phase(0.40, 1.4, [
                pat("dash", 3.0, speed=340),
                pat("pentagram", 7.0, count=3, damage=10),
                pat("summon", 9.0, enemy="skeleton_warrior", count=3),
            ], regen=3.0),
        ],
    ),
    # 5. Некромант
    "graveyard": dict(
        ai="tactical",
        name="Некромант", hp=4000, color="#4b0082", color2="#9370db",
        damage=4, speed=40, element="dark", souls=150,
        desc="Повелитель мёртвых. Призывает скелетов и ставит печати, 3 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("aim", 4.0, count=3, spread=20.0, speed=190, damage=7),
                pat("gaze", 7.0, radius=140, duration=5.0),
            ]),
            phase(0.70, 1.15, [
                pat("summon", 8.0, enemy="skeleton_warrior", count=4),
                pat("dark_chains", 5.0, radius=160, damage=7, root=1.5),
            ]),
            phase(0.40, 1.35, [
                pat("summon", 6.0, enemy="skeleton_warrior", count=6),
                pat("seal", 8.0, radius=96, damage=12),
                pat("spiral", 6.0, count=16, speed=130, damage=6),
            ], regen=2.0),
        ],
    ),
    # 6. Дракон Хаоса
    "rift": dict(
        ai="chaotic",
        name="Дракон Хаоса", hp=7000, color="#9400d3", color2="#7fff00",
        damage=6, speed=40, element="chaos", souls=150,
        desc="Древний дракон хаоса. Непредсказуемые атаки, 4 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("fireball", 3.0, count=3, spread=45.0, speed=200, damage=8),
                pat("meteor", 7.0, count=3, radius=52, damage=12),
            ]),
            phase(0.70, 1.2, [
                pat("teleport", 6.0),
                pat("ring", 4.0, count=12, speed=160, damage=7),
                pat("summon", 10.0, enemy="demon", count=2),
            ]),
            phase(0.40, 1.35, [
                pat("spiral", 5.0, count=20, speed=150, damage=8),
                pat("meteor", 5.0, count=5, radius=52, damage=12),
                pat("beam", 6.0, length=300, damage=9),
            ]),
            phase(0.15, 1.5, [
                pat("apocalypse", 20.0, damage=12),
                pat("wing", 4.0, count=5, damage=10),
            ], regen=4.0),
        ],
    ),
    # 7. Повелитель Теней
    "abyss": dict(
        ai="tactical",
        name="Повелитель Теней", hp=5500, color="#2f004f", color2="#9370db",
        damage=5, speed=42, element="shadow", souls=150,
        desc="Мастер теней: телепорты, цепи и проклятия, 3 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("aim", 3.5, count=3, spread=24.0, speed=200, damage=8),
                pat("gaze", 6.0, radius=140, duration=5.0),
            ]),
            phase(0.70, 1.2, [
                pat("teleport", 5.0),
                pat("dark_chains", 5.0, radius=180, damage=8, root=2.0),
            ]),
            phase(0.40, 1.4, [
                pat("teleport", 4.0),
                pat("pentagram", 6.0, count=3, damage=9),
                pat("mirror", 12.0, count=2),
            ], regen=2.0),
        ],
    ),
    # 8. Каменный Голем
    "temple": dict(
        ai="aggressive",
        name="Каменный Голем", hp=8000, color="#808080", color2="#c0c0c0",
        damage=8, speed=22, element="earth", souls=150,
        desc="Очень прочный и медленный страж храма, 3 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("chain_slam", 5.0, radius=160, damage=12, slow=0.5, slow_dur=2.0),
                pat("spikes", 7.0, count=4, radius=44, damage=10),
            ]),
            phase(0.70, 1.1, [
                pat("dash", 6.0, speed=260),
                pat("chain_slam", 4.0, radius=170, damage=12, slow=0.5, slow_dur=2.5),
            ]),
            phase(0.40, 1.2, [
                pat("spikes", 5.0, count=6, radius=48, damage=11),
                pat("aoe", 6.0, radius=120, damage=15, delay=1.4),
                pat("heal", 15.0, amount=80),
            ], regen=5.0),
        ],
    ),
    # 9. Чумной Доктор
    "hive": dict(
        ai="cautious",
        name="Чумной Доктор", hp=4500, color="#6b8e23", color2="#9acd32",
        damage=4, speed=38, element="plague", souls=150,
        desc="Ядовитые облака и слизни, 3 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("aoe", 4.0, radius=90, damage=8, delay=1.2, dot=4.0),
                pat("aim", 5.0, count=3, spread=30.0, speed=180, damage=6),
            ]),
            phase(0.70, 1.15, [
                pat("aoe", 4.0, radius=100, damage=9, delay=1.2, dot=6.0),
                pat("summon", 8.0, enemy="slime", count=4),
            ]),
            phase(0.40, 1.3, [
                pat("aoe", 3.5, radius=110, damage=10, delay=1.1, dot=8.0),
                pat("summon", 6.0, enemy="slime", count=6),
                pat("storm_aura", 12.0, radius=120, dps=4.0, duration=4.0, color="#6b8e23"),
            ], regen=2.0),
        ],
    ),
    # 10. Архидемон
    "bloodmoon": dict(
        ai="aggressive",
        name="Архидемон", hp=7500, color="#8b0000", color2="#ff6347",
        damage=7, speed=40, element="infernal", souls=150,
        desc="Высший демон: комбинации огня и тьмы, 4 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("fireball", 3.0, count=3, spread=40.0, speed=210, damage=9),
                pat("chain_slam", 5.0, radius=140, damage=10, slow=0.4, slow_dur=2.0),
            ]),
            phase(0.70, 1.15, [
                pat("scythe", 5.0, count=6, damage=10),
                pat("summon", 10.0, enemy="demon", count=3),
            ]),
            phase(0.40, 1.35, [
                pat("ring", 4.0, count=14, speed=170, damage=9, burn=True),
                pat("fireball", 2.5, count=5, spread=90.0, speed=230, damage=9),
                pat("pillar", 6.0, count=3, radius=56, damage=11),
            ]),
            phase(0.15, 1.5, [
                pat("apocalypse", 18.0, damage=15),
                pat("storm_aura", 12.0, radius=160, dps=8.0, duration=4.0, color="#ff4500"),
            ], regen=4.0),
        ],
    ),
    # 11. Огненный Титан
    "chaos": dict(
        ai="aggressive",
        name="Огненный Титан", hp=7000, color="#ff4500", color2="#ffd700",
        damage=7, speed=30, element="fire", souls=150,
        desc="Титан из лавы: столпы, метеоры и огненный след, 4 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("pillar", 4.0, count=2, radius=56, damage=10),
                pat("ring", 6.0, count=10, speed=150, damage=8, burn=True),
            ]),
            phase(0.70, 1.15, [
                pat("fireball", 3.0, count=5, spread=60.0, speed=220, damage=8),
                pat("pillar", 3.5, count=3, radius=56, damage=10),
            ]),
            phase(0.40, 1.3, [
                pat("storm_aura", 8.0, radius=160, dps=6.0, duration=4.0, color="#ff4500"),
                pat("meteor", 6.0, count=4, radius=56, damage=13),
            ]),
            phase(0.15, 1.5, [
                pat("apocalypse", 20.0, damage=14),
                pat("pillar", 2.5, count=4, radius=60, damage=12),
            ], regen=3.0),
        ],
    ),
    # 12. Ледяной Император
    "throne": dict(
        ai="tactical",
        name="Ледяной Император", hp=6500, color="#a8d8ea", color2="#ffffff",
        damage=6, speed=28, element="ice", souls=150,
        desc="Император ледяного мира: лучи, бураны и печати, 4 фазы.",
        phases=[
            phase(1.0, 1.0, [
                pat("beam", 3.0, length=300, damage=7),
                pat("spikes", 6.0, count=3, radius=44, damage=9),
            ]),
            phase(0.70, 1.1, [
                pat("spikes", 4.5, count=4, radius=48, damage=9),
                pat("storm_aura", 8.0, radius=140, dps=4.0, duration=4.0, color="#a8d8ea"),
            ]),
            phase(0.40, 1.25, [
                pat("seal", 7.0, radius=110, damage=16),
                pat("beam", 2.5, length=320, damage=9),
                pat("summon", 10.0, enemy="frozen_zombie", count=3),
            ]),
            phase(0.15, 1.45, [
                pat("storm_aura", 12.0, radius=180, dps=8.0, duration=5.0, color="#a8d8ea"),
                pat("ring", 5.0, count=16, speed=170, damage=8),
            ], regen=3.0),
        ],
    ),
    # 13. Пустота (бездонное эхо) — карта с секретом, включается в бесконечном режиме
    "void": dict(
        ai="chaotic",
        name="Пустота", hp=8500, color="#1a0033", color2="#9400d3",
        damage=7, speed=45, element="void", souls=150,
        desc="Воплощение небытия: притяжение, разрывы и апокалипсис, 5 фаз.",
        phases=[
            phase(1.0, 1.0, [
                pat("pull", 5.0, radius=240, force=120),
                pat("aim", 4.0, count=4, spread=30.0, speed=200, damage=8),
            ]),
            phase(0.70, 1.15, [
                pat("teleport", 4.0),
                pat("dark_chains", 5.0, radius=200, damage=9, root=2.0),
                pat("spiral", 5.0, count=18, speed=140, damage=7),
            ]),
            phase(0.40, 1.3, [
                pat("pull", 4.0, radius=260, force=140),
                pat("pentagram", 6.0, count=3, damage=10),
                pat("wing", 5.0, count=4, damage=10),
            ]),
            phase(0.25, 1.45, [
                pat("apocalypse", 18.0, damage=16),
                pat("teleport", 3.0),
            ]),
            phase(0.12, 1.6, [
                pat("apocalypse", 12.0, damage=20),
                pat("storm_aura", 10.0, radius=200, dps=10.0, duration=6.0, color="#9400d3"),
            ], regen=6.0),
        ],
    ),
    # 14. Шемхаз — финальный босс (5 фаз + мегафаза)
    "shemhaz": dict(
        ai="aggressive",
        name="Шемхаз", hp=10000, color="#8b0000", color2="#ff4500",
        damage=5, speed=40, element="final", souls=500,
        desc="Корень-демон. Финальный босс забега: 5 фаз и мегаформа.",
        phases=[
            phase(1.00, 1.0, [
                pat("fireball", 3.0, count=1, spread=0.0, speed=200, damage=5, size=32),
                pat("chain_slam", 5.0, radius=128, damage=5, slow=0.5, slow_dur=2.0),
            ]),
            phase(0.70, 1.25, [
                pat("fireball", 2.0, count=3, spread=60.0, speed=240, damage=5, size=32),
                pat("chain_slam", 4.0, radius=160, damage=5, slow=0.5, slow_dur=3.0),
                pat("summon", 10.0, enemy="demon", count=3),
            ]),
            phase(0.40, 1.5, [
                pat("fireball", 1.5, count=5, spread=90.0, speed=280, damage=5, size=40),
                pat("chain_slam", 3.0, radius=192, damage=5, slow=0.5, slow_dur=4.0),
                pat("summon", 8.0, enemy="demon", count=5),
                pat("storm_aura", 12.0, radius=128, dps=3.0, duration=5.0, color="#ff4500"),
            ], regen=5.0),
            phase(0.20, 1.6, [
                pat("fireball", 1.2, count=6, spread=110.0, speed=300, damage=6, size=40),
                pat("wing", 5.0, count=5, damage=8),
                pat("seal", 9.0, radius=110, damage=14),
            ], regen=8.0),
            phase(0.10, 1.8, [
                pat("apocalypse", 16.0, damage=14),
                pat("storm_aura", 10.0, radius=160, dps=6.0, duration=5.0, color="#ffd700"),
            ], regen=10.0, mega=True),
        ],
    ),
}

# ---------------------------------------------------------------- СЕКРЕТНЫЙ БОСС
SATANAIL = dict(
    id="boss_satanail", name="САТАНАИЛ", hp=10000, color="#8b0000", color2="#ffd700",
    radius=64, sprite=[192, 192], collide=[128, 128], damage=7, speed=50,
    xp=2000, souls=500, element="void", ai="chaotic", reward="5 реликвий + Крыло САТАНАИЛА",
    desc="Секретный босс Пустоты, 5 фаз + мегафаза САТАН.",
    phases=[
        phase(1.00, 1.0, [
            pat("holy_light", 4.0, count=1, spread=0.0, speed=240, damage=7, size=48),
            pat("dark_chains", 6.0, radius=192, damage=7, root=1.5),
        ]),
        phase(0.80, 1.2, [
            pat("holy_light", 3.0, count=3, spread=60.0, speed=280, damage=7, size=48),
            pat("dark_chains", 5.0, radius=224, damage=7, root=2.0),
            pat("summon", 12.0, enemy="fallen_angel", count=5),
        ]),
        phase(0.60, 1.35, [
            pat("holy_light", 2.5, count=4, spread=75.0, speed=300, damage=7, size=52),
            pat("dark_chains", 4.5, radius=240, damage=8, root=2.2),
            pat("summon", 11.0, enemy="fallen_angel", count=6),
        ]),
        phase(0.40, 1.5, [
            pat("holy_light", 2.0, count=5, spread=90.0, speed=320, damage=7, size=56),
            pat("wing", 5.0, count=5, damage=9),
            pat("seal", 9.0, radius=120, damage=15),
            pat("storm_aura", 15.0, radius=192, dps=5.0, duration=6.0, color="#000000"),
        ], regen=10.0),
        phase(0.20, 2.0, [
            pat("holy_light", 1.5, count=7, spread=120.0, speed=360, damage=10, size=64),
            pat("dark_chains", 3.0, radius=320, damage=10, root=3.0),
            pat("summon", 8.0, enemy="fallen_angel", count=10),
            pat("storm_aura", 12.0, radius=256, dps=8.0, duration=8.0, color="#000000"),
            pat("apocalypse", 20.0, damage=15),
        ], regen=20.0, mega=True),
    ],
)


def build() -> dict:
    bosses = {}
    for key, spec in REGULAR.items():
        entry = {
            "id": "boss_" + key,
            "name": spec["name"],
            "map": key,
            "hp": spec["hp"],
            "color": spec["color"],
            "color2": spec["color2"],
            "radius": 40,
            "sprite": [128, 128],
            "collide": [96, 96],
            "damage": spec["damage"],
            "speed": spec["speed"],
            "xp": 500 if key != "shemhaz" else 2000,
            "souls": spec["souls"],
            "element": spec["element"],
            "ai": spec.get("ai", "aggressive"),
            "reward": "реликвия",
            "desc": spec["desc"],
            "phases": spec["phases"],
        }
        if key == "shemhaz":
            entry["final"] = True
        bosses[key] = entry
    bosses["satanail"] = SATANAIL
    return bosses


def main() -> None:
    bosses = build()
    doc = {"bosses": bosses, "sathan": SATANAIL}
    path = os.path.join(W, "data", "bosses.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")
    kinds = sorted({p["type"] for b in bosses.values() for ph in b["phases"] for p in ph["patterns"]})
    print("bosses:", len(bosses), "| pattern types:", ", ".join(kinds))


if __name__ == "__main__":
    main()
