# -*- coding: utf-8 -*-
"""Генерация data/enemies.json, data/maps.json, data/waves.json."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ENEMIES = []

def e(eid, name, role, hp, speed, dmg, color, desc, behavior=None, flags=None, radius=7):
    ENEMIES.append({
        "id": eid, "name": name, "role": role, "hp": hp, "speed": speed,
        "damage": dmg, "color": color, "desc": desc, "radius": radius,
        "behavior": behavior or {"kind": "chase"},
        "flags": flags or {},
    })

# kind: chase / jump / fly / shooter / charger / summoner / exploder
# clan: используется для "нежити" (святой урон x2) и альбома
CLANS = {}

# ---------------------------------------------------------------- ЛЕС
e("forest_slime", "Слизень", "fodder", 2, 42, 1, "#6fbf5f", "Медленно прыгает к игроку.", {"kind": "jump"}, radius=7); CLANS["forest_slime"] = "beast"
e("forest_goblin_archer", "Гоблин-лучник", "shooter", 3, 52, 1, "#8fbf4f", "Держит дистанцию, стреляет раз в 2 сек.", {"kind": "shooter", "keep": 170, "proj": {"damage": 2, "speed": 170, "interval": 2.0}})
e("forest_mosquito", "Комар-кровосос", "fodder", 1, 88, 1, "#c0a040", "Быстрый, при ударе крадёт патрон.", {"kind": "fly"}, {"steal_ammo": True}, radius=5); CLANS["forest_mosquito"] = "beast"
e("forest_leshy", "Леший", "elite", 30, 58, 2, "#4f9f3f", "Призывает гоблинов каждые 5 сек.", {"kind": "summoner", "summon": "forest_goblin_archer", "count": 3, "interval": 5.0}, radius=11); CLANS["forest_leshy"] = "beast"
e("forest_ancient", "Древень", "miniboss", 200, 44, 3, "#3f7f2f", "Удары по площади, роняет сундук.", {"kind": "chase", "slam": {"radius": 64, "damage": 3, "interval": 4.0}}, radius=16); CLANS["forest_ancient"] = "beast"

# ---------------------------------------------------------------- ТУНДРА
e("tundra_zombie", "Замороженный зомби", "fodder", 4, 40, 1, "#a8c8d8", "При смерти взрывается ледяными осколками.", {"kind": "chase"}, {"explode": {"damage": 2, "radius": 32}}); CLANS["tundra_zombie"] = "undead"
e("tundra_wolf", "Ледяной волк", "fodder", 3, 78, 1, "#c8e8f8", "Быстрый, замораживает при атаке.", {"kind": "chase"}, {"freeze_on_hit": 1.0}); CLANS["tundra_wolf"] = "beast"
e("tundra_golem", "Снежный голем", "elite", 50, 48, 2, "#d8e8f0", "Стреляет ледяными глыбами.", {"kind": "shooter", "keep": 150, "proj": {"damage": 2, "speed": 150, "interval": 2.5}}); CLANS["tundra_golem"] = "elemental"
e("tundra_yeti", "Йети", "miniboss", 300, 50, 3, "#e8f4ff", "Бросает снежки, призывает вьюгу.", {"kind": "chase", "shoot": {"damage": 3, "speed": 160, "interval": 2.0}}); CLANS["tundra_yeti"] = "beast"
e("tundra_shard", "Осколок", "fodder", 2, 62, 1, "#bfe8ff", "Мелкий осколок льда.", {"kind": "chase"}); CLANS["tundra_shard"] = "elemental"

# ---------------------------------------------------------------- ПЕЩЕРА
e("cave_spider", "Пещерный паук", "fodder", 2, 72, 1, "#8060a0", "Прыгает на игрока.", {"kind": "jump"}); CLANS["cave_spider"] = "beast"
e("cave_bat", "Летучая мышь", "fodder", 1, 92, 1, "#9070b0", "Летает, сбивается при попадании.", {"kind": "fly"}); CLANS["cave_bat"] = "beast"
e("cave_troll", "Тролль", "elite", 60, 52, 2, "#5f8f6f", "Регенерирует 1 HP/сек, пока не горит.", {"kind": "chase"}, {"regen": 1.0}); CLANS["cave_troll"] = "beast"
e("cave_worm", "Каменный червь", "miniboss", 350, 40, 3, "#7f7f6f", "Выходит из-под земли, ударная волна.", {"kind": "chase", "slam": {"radius": 80, "damage": 3, "interval": 3.5}}, radius=16); CLANS["cave_worm"] = "beast"
e("cave_spitter", "Пещерный плеватель", "shooter", 4, 50, 1, "#9f8f70", "Плюётся камнями.", {"kind": "shooter", "keep": 180, "proj": {"damage": 1, "speed": 180, "interval": 2.2}})

# ---------------------------------------------------------------- ГОРА
e("mountain_harpy", "Гарпия", "fodder", 3, 74, 1, "#c0b090", "Летает, стреляет перьями.", {"kind": "fly", "shoot": {"damage": 1, "speed": 200, "interval": 2.6}}); CLANS["mountain_harpy"] = "beast"
e("mountain_goat", "Горный козёл-берсерк", "fodder", 5, 84, 1, "#b09070", "Быстрый таран.", {"kind": "charger", "charge_speed": 220, "interval": 3.0}); CLANS["mountain_goat"] = "beast"
e("mountain_griffin", "Грифон", "elite", 80, 66, 2, "#d0c090", "Пикирует с высоты.", {"kind": "charger", "charge_speed": 260, "interval": 4.0}); CLANS["mountain_griffin"] = "beast"
e("mountain_guard", "Каменный страж", "miniboss", 400, 42, 3, "#9f9f9f", "Кидает камни, неуязвим к заморозке.", {"kind": "chase", "shoot": {"damage": 3, "speed": 150, "interval": 2.0}}, {"ice_immune": True}, radius=16)
e("mountain_elemental", "Элементаль ветра", "shooter", 4, 56, 1, "#bff0f0", "Стреляет порывами.", {"kind": "shooter", "keep": 190, "proj": {"damage": 1, "speed": 190, "interval": 2.4}})

# ---------------------------------------------------------------- ПУСТЫНЯ
e("desert_scorpion", "Скорпион", "fodder", 2, 66, 1, "#d0a050", "Накладывает яд (3 дпс, 4 сек).", {"kind": "chase"}, {"poison": {"dps": 3, "dur": 4}}); CLANS["desert_scorpion"] = "beast"
e("desert_mummy", "Мумия", "fodder", 5, 44, 1, "#c0b080", "При смерти призывает 2 скарабеев.", {"kind": "chase"}, {"death_spawn": {"enemy": "desert_scarab", "count": 2}}); CLANS["desert_mummy"] = "undead"
e("desert_scarab", "Скарабей", "fodder", 1, 96, 1, "#a08040", "Быстрый жук.", {"kind": "chase"}, radius=5); CLANS["desert_scarab"] = "beast"
e("desert_worm", "Песчаный червь", "elite", 90, 46, 2, "#c09050", "Появляется из-под песка, огромная зона атаки.", {"kind": "chase", "slam": {"radius": 90, "damage": 3, "interval": 4.0}}); CLANS["desert_worm"] = "beast"
e("desert_sphinx", "Сфинкс", "miniboss", 450, 40, 3, "#e0c070", "Загадки — случайные дебаффы на 10 сек.", {"kind": "chase", "debuff": {"interval": 8.0, "duration": 10.0}}, radius=16); CLANS["desert_sphinx"] = "beast"

# ---------------------------------------------------------------- ВУЛКАН
e("volcano_elemental", "Огненный элементаль", "fodder", 4, 64, 1, "#f06030", "Взрывается при смерти (3 урона, 48 px).", {"kind": "chase"}, {"explode": {"damage": 3, "radius": 48}, "fire_immune": True}); CLANS["volcano_elemental"] = "elemental"
e("volcano_golem", "Лавовый голем", "fodder", 7, 38, 1, "#c04020", "Оставляет огненный след.", {"kind": "chase"}, {"trail": {"dps": 3, "dur": 2}, "fire_immune": True}); CLANS["volcano_golem"] = "elemental"
e("volcano_salamander", "Саламандра", "elite", 100, 60, 2, "#ff8040", "Стреляет лавой, иммунитет к огню.", {"kind": "shooter", "keep": 160, "proj": {"damage": 2, "speed": 170, "interval": 2.0}}, {"fire_immune": True}); CLANS["volcano_salamander"] = "elemental"
e("volcano_dragon", "Пепельный дракон", "miniboss", 500, 46, 3, "#a05030", "Дышит огнём конусом, призывает элементалей.", {"kind": "chase", "cone": {"angle": 60, "radius": 130, "damage": 3, "interval": 4.0}, "summon": "volcano_elemental", "summon_count": 2}, {"fire_immune": True}, radius=16)
e("volcano_imp", "Бес-поджигатель", "shooter", 3, 70, 1, "#ff9050", "Швыряет искры.", {"kind": "shooter", "keep": 150, "proj": {"damage": 1, "speed": 210, "interval": 2.0}})

# ---------------------------------------------------------------- ТОПИ
e("swamp_creature", "Болотная тварь", "fodder", 3, 46, 1, "#5f8f4f", "Оставляет ядовитый след.", {"kind": "chase"}, {"trail": {"dps": 2, "dur": 3, "poison": True}})
e("swamp_frog", "Ядовитая жаба", "shooter", 3, 48, 1, "#7faf5f", "Плевки накладывают 2 стака яда.", {"kind": "shooter", "keep": 170, "proj": {"damage": 1, "speed": 160, "interval": 2.5, "poison_stacks": 2}})
e("swamp_vodyanoy", "Водяной", "elite", 85, 50, 2, "#4f7f6f", "Призывает топь под игроком (замедление 80%).", {"kind": "chase", "slow_zone": {"radius": 56, "slow": 0.8, "interval": 5.0, "duration": 3.0}})
e("swamp_hydra", "Гидра", "miniboss", 480, 42, 3, "#6f9f5f", "3 головы, каждая стреляет ядом.", {"kind": "chase", "shoot": {"damage": 2, "speed": 160, "interval": 1.6, "count": 3}}, radius=16)
e("swamp_mosquito", "Болотный комар", "fodder", 1, 84, 1, "#90a050", "Быстрый.", {"kind": "fly"}, radius=5)

# ---------------------------------------------------------------- ХРАМ
e("temple_piranha", "Рыба-пиранья", "fodder", 1, 100, 1, "#60b0d0", "Очень быстрая, спавнится стаями.", {"kind": "chase"}, radius=5); CLANS["temple_piranha"] = "beast"
e("temple_serpent", "Морской змей", "fodder", 5, 62, 1, "#40a0b0", "Создаёт отталкивающие волны.", {"kind": "chase"}, {"push_on_hit": 60}); CLANS["temple_serpent"] = "beast"
e("temple_kraken", "Кракен-отпрыск", "elite", 110, 44, 2, "#307080", "Щупальца тянут игрока к себе.", {"kind": "chase", "pull": {"radius": 140, "force": 90, "interval": 4.0}}); CLANS["temple_kraken"] = "beast"
e("temple_guardian", "Древний страж", "miniboss", 520, 40, 3, "#a0b0a0", "Стреляет трезубцами.", {"kind": "chase", "shoot": {"damage": 3, "speed": 190, "interval": 1.8, "count": 3}}, radius=16)
e("temple_mimic", "Мимик", "shooter", 3, 56, 1, "#80d0e0", "Притворяется сиянием глубин.", {"kind": "shooter", "keep": 150, "proj": {"damage": 1, "speed": 180, "interval": 2.4}})

# ---------------------------------------------------------------- НЕБЕСНЫЕ ОСТРОВА
e("sky_ray", "Воздушный скат", "fodder", 2, 78, 1, "#a0d0f0", "Летает, ныряет на игрока.", {"kind": "fly"}); CLANS["sky_ray"] = "beast"
e("sky_cloud", "Облачный элементаль", "fodder", 3, 60, 1, "#d0e8ff", "Стреляет молниями.", {"kind": "fly", "shoot": {"damage": 1, "speed": 200, "interval": 2.8}}); CLANS["sky_cloud"] = "elemental"
e("sky_griffin_rider", "Гриф-наездник", "elite", 95, 70, 2, "#c0d0e0", "Неуязвим, пока в полёте.", {"kind": "fly", "dive": {"interval": 4.0, "damage": 3}}); CLANS["sky_griffin_rider"] = "beast"
e("sky_storm_giant", "Штормовой великан", "miniboss", 480, 42, 3, "#b0c0e0", "Молнии и ветряные воронки.", {"kind": "chase", "aoe": {"radius": 64, "damage": 3, "interval": 3.5}}, radius=16)
e("sky_wisp", "Ветряной дух", "shooter", 2, 68, 1, "#e0f0ff", "Быстрый стрелок.", {"kind": "shooter", "keep": 160, "proj": {"damage": 1, "speed": 210, "interval": 2.0}})

# ---------------------------------------------------------------- КОСТЯНОЕ ПОЛЕ
e("bone_skeleton", "Скелет-воин", "shooter", 2, 56, 1, "#d8d8c0", "Стреляет костяными стрелами.", {"kind": "shooter", "keep": 170, "proj": {"damage": 1, "speed": 180, "interval": 2.2}}); CLANS["bone_skeleton"] = "undead"
e("bone_ghost", "Призрак", "fodder", 3, 66, 1, "#c0c0f0", "Проходит сквозь препятствия, замораживает.", {"kind": "fly"}, {"freeze_on_hit": 1.0}); CLANS["bone_ghost"] = "undead"
e("bone_lich", "Лич", "elite", 120, 46, 2, "#a0a0d0", "Призывает скелетов, стреляет лучами.", {"kind": "summoner", "summon": "bone_skeleton", "count": 2, "interval": 5.0}, radius=11); CLANS["bone_lich"] = "undead"
e("bone_banshee", "Банши", "miniboss", 440, 44, 3, "#d0d0f0", "Крик оглушает на 2 сек.", {"kind": "chase", "shout": {"radius": 140, "stun": 2.0, "interval": 6.0}}, radius=16); CLANS["bone_banshee"] = "undead"
e("bone_rat", "Костяная крыса", "fodder", 1, 90, 1, "#c8c8b0", "Мелкая и быстрая.", {"kind": "chase"}, radius=5); CLANS["bone_rat"] = "undead"

# ---------------------------------------------------------------- КРИСТАЛЛЫ
e("crystal_spider", "Кристальный паук", "fodder", 3, 76, 1, "#b070f0", "При смерти разлетается 6 осколками.", {"kind": "chase"}, {"shards_on_death": {"count": 6, "damage": 2}})
e("crystal_golem", "Голем-самоцвет", "fodder", 6, 40, 1, "#9070d0", "Отражает 50% урона.", {"kind": "chase"}, {"reflect": 0.5})
e("crystal_mage", "Хрустальный маг", "elite", 130, 48, 2, "#c090f0", "Стреляет лучами, ставит кристаллы-ловушки.", {"kind": "shooter", "keep": 180, "proj": {"damage": 2, "speed": 220, "interval": 1.8}})
e("crystal_dragon", "Призмарный дракон", "miniboss", 540, 46, 3, "#e0a0ff", "Кристаллическое дыхание, призывает кристаллы.", {"kind": "chase", "cone": {"angle": 50, "radius": 150, "damage": 3, "interval": 4.0}}, radius=16)
e("crystal_shardling", "Осколочник", "shooter", 2, 62, 1, "#d0b0ff", "Швыряет осколки.", {"kind": "shooter", "keep": 170, "proj": {"damage": 1, "speed": 230, "interval": 2.2}})

# ---------------------------------------------------------------- РУИНЫ
e("ruins_demon", "Демон руин", "fodder", 6, 70, 1, "#c05050", "Уникальный демон руин.", {"kind": "chase"}, radius=8)
e("ruins_skeleton", "Скелет-страж", "shooter", 4, 58, 1, "#d0d0b0", "Стреляет из арбалета.", {"kind": "shooter", "keep": 170, "proj": {"damage": 2, "speed": 200, "interval": 2.0}}); CLANS["ruins_skeleton"] = "undead"
e("ruins_wraith", "Тень руин", "elite", 140, 62, 2, "#9060c0", "Быстрая, проходит сквозь стены.", {"kind": "fly"}, radius=11)
e("ruins_colossus", "Колосс руин", "miniboss", 600, 38, 3, "#a08060", "Удары по площади.", {"kind": "chase", "slam": {"radius": 90, "damage": 3, "interval": 3.0}}, radius=16)
e("ruins_ghoul", "Упырь", "fodder", 4, 74, 1, "#a0a080", "Быстрый, кусает.", {"kind": "chase"}); CLANS["ruins_ghoul"] = "undead"

# ---------------------------------------------------------------- ПРЕИСПОДНЯЯ
e("infernal_imp", "Бес", "fodder", 2, 92, 1, "#ff6030", "Взрывается при смерти (4 урона, 32 px).", {"kind": "fly"}, {"explode": {"damage": 4, "radius": 32}, "fire_immune": True})
e("infernal_guard", "Демон-страж", "shooter", 6, 46, 1, "#c04030", "Стреляет огненными шарами.", {"kind": "shooter", "keep": 160, "proj": {"damage": 2, "speed": 170, "interval": 2.0}, "fire_immune": True})
e("infernal_hound", "Адский пёс", "fodder", 4, 100, 1, "#b03020", "Очень быстрый, поджигает.", {"kind": "charger", "charge_speed": 260, "interval": 2.5}, {"burn_on_hit": 3, "fire_immune": True})
e("infernal_succubus", "Суккуб", "elite", 140, 60, 2, "#e05090", "Призывает бесов, очарование (управление инвертировано).", {"kind": "summoner", "summon": "infernal_imp", "count": 3, "interval": 6.0, "charm": {"interval": 10.0, "duration": 3.0}}, {"fire_immune": True}, radius=11)
e("infernal_archdemon", "Архидемон", "miniboss", 600, 40, 3, "#ff4020", "Адский луч, иммунитет к огню.", {"kind": "chase", "beam": {"damage": 3, "length": 260, "interval": 3.0}}, {"fire_immune": True}, radius=16)

for en in ENEMIES:
    en["clan"] = CLANS.get(en["id"], "demon" if en["id"].startswith("infernal") else "beast")

# ---------------------------------------------------------------- БОССЫ
def pat(kind, interval, **params):
    return {"type": kind, "interval": interval, "params": params}

def boss(bid, name, hp, color, desc, phases, final_hp=None, clan="boss"):
    return {"id": bid, "name": name, "hp": hp, "final_hp": final_hp or int(hp * 1.9),
            "color": color, "desc": desc, "phases": phases, "clan": clan, "radius": 26}

BOSSES = {
 "forest": boss("boss_shemhaz", "Шемхаз", 1500, "#4f7f2f", "Корень-демон леса. 3 фазы.", [
   {"at": 1.0, "patterns": [pat("ring", 3.0, count=10, speed=150, damage=8), pat("aim", 2.0, count=3, spread=20, speed=200, damage=6), pat("summon", 8.0, enemy="forest_goblin_archer", count=3)]},
   {"at": 0.66, "patterns": [pat("ring", 2.2, count=14, speed=160, damage=8), pat("spiral", 4.0, count=24, speed=140, damage=8), pat("summon", 6.0, enemy="forest_slime", count=5)]},
   {"at": 0.33, "patterns": [pat("aoe", 3.0, radius=72, damage=10, delay=1.2), pat("ring", 1.8, count=18, speed=170, damage=9), pat("summon", 7.0, enemy="forest_leshy", count=1)]}]),
 "tundra": boss("boss_imiral", "Имираль", 2000, "#a8d8f0", "Ледяная королева. Замораживает области, призывает лавины.", [
   {"at": 1.0, "patterns": [pat("ring", 2.6, count=12, speed=150, damage=8), pat("aoe", 4.0, radius=80, damage=10, delay=1.4, freeze=True), pat("summon", 9.0, enemy="tundra_wolf", count=4)]},
   {"at": 0.6, "patterns": [pat("spiral", 3.5, count=30, speed=150, damage=9), pat("aoe", 3.0, radius=90, damage=12, delay=1.2, freeze=True), pat("summon", 7.0, enemy="tundra_zombie", count=6)]},
   {"at": 0.3, "patterns": [pat("ring", 1.6, count=20, speed=180, damage=10), pat("aoe", 2.2, radius=100, damage=14, delay=1.0, freeze=True), pat("summon", 6.0, enemy="tundra_golem", count=2)]}]),
 "cave": boss("boss_grotgar", "Гротгар", 2500, "#8f8f7f", "Каменный гигант. Бросает валуны, вызывает обвалы.", [
   {"at": 1.0, "patterns": [pat("aim", 2.2, count=4, spread=24, speed=190, damage=9), pat("aoe", 3.6, radius=90, damage=12, delay=1.4), pat("summon", 10.0, enemy="cave_spider", count=5)]},
   {"at": 0.65, "patterns": [pat("ring", 2.4, count=16, speed=160, damage=10), pat("aoe", 2.8, radius=100, damage=14, delay=1.1), pat("dash", 6.0, speed=320, damage=12)]},
   {"at": 0.32, "patterns": [pat("ring", 1.7, count=22, speed=180, damage=11), pat("aoe", 2.0, radius=110, damage=16, delay=0.9), pat("summon", 7.0, enemy="cave_bat", count=8)]}]),
 "mountain": boss("boss_tarvos", "Тарвос", 2800, "#b0b0c0", "Грозовой великан. Молнии и камнепады.", [
   {"at": 1.0, "patterns": [pat("lightning", 3.0, count=3, damage=20, radius=48), pat("aim", 2.4, count=3, spread=20, speed=200, damage=9), pat("summon", 9.0, enemy="mountain_goat", count=4)]},
   {"at": 0.6, "patterns": [pat("lightning", 2.2, count=4, damage=20, radius=48), pat("ring", 2.2, count=16, speed=170, damage=10), pat("dash", 5.0, speed=340, damage=13)]},
   {"at": 0.3, "patterns": [pat("lightning", 1.6, count=5, damage=24, radius=56), pat("spiral", 3.0, count=30, speed=160, damage=10), pat("summon", 6.0, enemy="mountain_griffin", count=2)]}]),
 "desert": boss("boss_anubis", "Анубис", 3000, "#e0c070", "Повелитель песков. Призывает воинов, создаёт бури.", [
   {"at": 1.0, "patterns": [pat("aim", 2.0, count=3, spread=18, speed=210, damage=9), pat("summon", 8.0, enemy="desert_mummy", count=4), pat("aoe", 4.0, radius=90, damage=12, delay=1.5)]},
   {"at": 0.6, "patterns": [pat("ring", 2.2, count=16, speed=170, damage=10), pat("spiral", 4.0, count=26, speed=150, damage=10), pat("summon", 6.0, enemy="desert_scorpion", count=6)]},
   {"at": 0.3, "patterns": [pat("ring", 1.5, count=22, speed=190, damage=11), pat("lightning", 2.0, count=4, damage=18, radius=56), pat("summon", 5.0, enemy="desert_worm", count=2)]}]),
 "volcano": boss("boss_igniskar", "Игнис'Кар", 3200, "#ff6030", "Повелитель магмы. 3 фазы, трансформация в голема.", [
   {"at": 1.0, "patterns": [pat("ring", 2.4, count=14, speed=170, damage=9, burn=True), pat("aoe", 3.4, radius=100, damage=13, delay=1.3, dot=4), pat("summon", 8.0, enemy="volcano_elemental", count=4)]},
   {"at": 0.6, "patterns": [pat("meteor", 3.0, count=6, damage=14, radius=56), pat("spiral", 3.4, count=28, speed=160, damage=10, burn=True), pat("summon", 7.0, enemy="volcano_golem", count=3)]},
   {"at": 0.3, "patterns": [pat("ring", 1.5, count=20, speed=190, damage=12, burn=True), pat("meteor", 2.0, count=8, damage=16, radius=64), pat("dash", 5.0, speed=330, damage=14)]}]),
 "swamp": boss("boss_malachia", "Малахия", 3000, "#6f9f5f", "Гниющая ведьма. Ядовитые облака, исцеление в топи.", [
   {"at": 1.0, "patterns": [pat("ring", 2.6, count=12, speed=150, damage=8, poison=True), pat("aoe", 3.5, radius=100, damage=10, delay=1.4, dot=4), pat("summon", 9.0, enemy="swamp_creature", count=5)]},
   {"at": 0.6, "patterns": [pat("spiral", 3.6, count=26, speed=150, damage=9, poison=True), pat("aoe", 2.6, radius=110, damage=12, delay=1.2, dot=5), pat("summon", 7.0, enemy="swamp_frog", count=4)]},
   {"at": 0.3, "patterns": [pat("ring", 1.6, count=20, speed=175, damage=10, poison=True), pat("summon", 5.0, enemy="swamp_vodyanoy", count=2), pat("heal", 8.0, amount=40)]}]),
 "temple": boss("boss_leviafan", "Левиафан", 3500, "#40a0b0", "Морской ужас. Щупальца, водовороты, поглощение.", [
   {"at": 1.0, "patterns": [pat("aim", 1.8, count=4, spread=22, speed=200, damage=9), pat("aoe", 3.2, radius=100, damage=12, delay=1.4), pat("summon", 8.0, enemy="temple_piranha", count=6)]},
   {"at": 0.65, "patterns": [pat("ring", 2.0, count=18, speed=170, damage=10), pat("pull", 5.0, radius=220, force=140), pat("summon", 7.0, enemy="temple_serpent", count=3)]},
   {"at": 0.3, "patterns": [pat("ring", 1.4, count=24, speed=185, damage=12), pat("aoe", 2.0, radius=120, damage=16, delay=1.0), pat("summon", 5.0, enemy="temple_kraken", count=2)]}]),
 "sky": boss("boss_aeriel", "Аэриэль", 3300, "#a0d0f0", "Повелительница бурь. Летает, призывает торнадо и молнии.", [
   {"at": 1.0, "patterns": [pat("lightning", 2.6, count=3, damage=25, radius=64), pat("ring", 2.2, count=16, speed=180, damage=9), pat("summon", 8.0, enemy="sky_ray", count=6)]},
   {"at": 0.6, "patterns": [pat("spiral", 3.0, count=30, speed=170, damage=10), pat("lightning", 2.0, count=4, damage=25, radius=64), pat("dash", 5.0, speed=360, damage=12)]},
   {"at": 0.3, "patterns": [pat("ring", 1.4, count=22, speed=195, damage=11), pat("lightning", 1.5, count=5, damage=28, radius=72), pat("summon", 5.0, enemy="sky_storm_giant", count=2)]}]),
 "bonefields": boss("boss_nekros", "Некрос", 3400, "#c0c0e0", "Владыка мёртвых. Воскрешает врагов, проклинает область.", [
   {"at": 1.0, "patterns": [pat("summon", 6.0, enemy="bone_skeleton", count=5), pat("ring", 2.4, count=14, speed=160, damage=9), pat("aoe", 3.6, radius=100, damage=12, delay=1.4)]},
   {"at": 0.6, "patterns": [pat("summon", 4.5, enemy="bone_ghost", count=4), pat("spiral", 3.2, count=28, speed=155, damage=10), pat("ring", 2.0, count=18, speed=175, damage=11)]},
   {"at": 0.3, "patterns": [pat("summon", 3.5, enemy="bone_lich", count=2), pat("ring", 1.5, count=24, speed=190, damage=12), pat("aoe", 2.2, radius=120, damage=16, delay=1.0, curse=True)]}]),
 "crystals": boss("boss_kristalin", "Криста'Лин", 3600, "#c090f0", "Зеркальная королева. Копии игрока, отражение атак, шипы.", [
   {"at": 1.0, "patterns": [pat("ring", 2.2, count=16, speed=180, damage=10), pat("spikes", 3.4, count=6, damage=12, radius=40), pat("summon", 9.0, enemy="crystal_spider", count=5)]},
   {"at": 0.6, "patterns": [pat("ring", 1.8, count=20, speed=190, damage=11), pat("spikes", 2.6, count=8, damage=14, radius=44), pat("mirror", 10.0, count=2)]},
   {"at": 0.3, "patterns": [pat("ring", 1.3, count=26, speed=205, damage=12), pat("spikes", 2.0, count=10, damage=16, radius=48), pat("summon", 5.0, enemy="crystal_mage", count=2)]}]),
 "ruins": boss("boss_mordret", "Мордрет", 5000, "#7050a0", "Повелитель Тьмы. 5 фаз, атаки всех боссов.", [
   {"at": 1.0, "patterns": [pat("ring", 2.2, count=16, speed=180, damage=10), pat("aim", 1.8, count=4, spread=20, speed=210, damage=10), pat("summon", 8.0, enemy="ruins_skeleton", count=5)]},
   {"at": 0.8, "patterns": [pat("lightning", 2.6, count=4, damage=22, radius=56), pat("spiral", 3.4, count=26, speed=165, damage=11), pat("summon", 6.0, enemy="ruins_wraith", count=3)]},
   {"at": 0.6, "patterns": [pat("aoe", 2.6, radius=110, damage=15, delay=1.2), pat("ring", 1.8, count=22, speed=190, damage=12), pat("summon", 5.0, enemy="ruins_demon", count=4)]},
   {"at": 0.4, "patterns": [pat("meteor", 2.6, count=8, damage=16, radius=60), pat("spikes", 2.2, count=8, damage=14, radius=46), pat("dash", 5.0, speed=340, damage=14)]},
   {"at": 0.2, "patterns": [pat("ring", 1.2, count=28, speed=210, damage=13), pat("lightning", 1.6, count=6, damage=26, radius=64), pat("summon", 4.0, enemy="ruins_colossus", count=1), pat("aoe", 1.8, radius=130, damage=18, delay=0.9)]}]),
 "infernal": boss("boss_satanail", "Сатанаил", 7500, "#ff3020", "Падший ангел. 5 фаз.", [
   {"at": 1.0, "patterns": [pat("ring", 2.0, count=16, speed=180, damage=8, burn=True), pat("pentagram", 5.0, count=4, radius=48, damage=8), pat("aim", 2.0, count=2, spread=10, speed=220, damage=12)]},
   {"at": 0.8, "patterns": [pat("pillar", 3.0, count=5, damage=5, radius=48), pat("pentagram", 6.0, count=12, radius=48, damage=8), pat("summon", 8.0, enemy="infernal_hound", count=2)]},
   {"at": 0.6, "patterns": [pat("teleport", 5.0), pat("pentagram", 4.0, count=8, radius=48, damage=8, duration=15), pat("scythe", 2.6, count=5, damage=10)]},
   {"at": 0.4, "patterns": [pat("aoe", 4.0, radius=128, damage=10, delay=1.0, dot=10), pat("aim", 2.2, count=15, spread=40, speed=200, damage=8), pat("summon", 10.0, enemy="infernal_imp", count=4)]},
   {"at": 0.2, "patterns": [pat("ring", 1.1, count=30, speed=210, damage=12, burn=True), pat("cone", 2.4, angle=70, radius=110, damage=15, interval_note="breath"), pat("pentagram", 5.0, count=1, radius=48, damage=8, under_player=True), pat("summon", 5.0, enemy="infernal_imp", count=6)]}]),
}

SATHAN = {
  "id": "boss_sathan", "name": "САТАН", "hp": 10000, "final_hp": 10000, "color": "#1a1020",
  "desc": "Истинная форма Сатанаила. Только для паладина.", "clan": "boss", "radius": 34,
  "phases": [
    {"at": 1.0, "patterns": [pat("wing", 8.0, count=3, damage=12), pat("gaze", 12.0, angle=60, radius=128, duration=6.0), pat("spikes", 10.0, count=5, damage=8, radius=24)]},
    {"at": 0.7, "patterns": [pat("seal", 15.0, radius=96, damage=15, pool_dps=6, pool_dur=4.0), pat("wing", 6.0, count=3, damage=12), pat("spikes", 6.0, count=5, damage=8, radius=24)]},
    {"at": 0.3, "patterns": [pat("apocalypse", 20.0, damage=12), pat("dash", 6.0, speed=380, damage=20), pat("wing", 5.0, count=3, damage=12), pat("seal", 10.0, radius=96, damage=15, pool_dps=6, pool_dur=4.0)]},
  ]}

# ---------------------------------------------------------------- КАРТЫ
def ev(kind, interval, **params):
    return {"kind": kind, "interval": interval, "params": params}

MAPS = [
 {"id":"forest","name":"Проклятый Лес","unlock":"","palette":{"bg":"#14240f","obstacle":"#1f3b17","accent":"#8fd05f","fog":"#0b1a08"},
  "desc":"Тёмный туман, шёпот деревьев. Метеоритные дожди и блуждающие огни.",
  "roster":{"fodder":["forest_slime","forest_mosquito"],"shooter":["forest_goblin_archer"],"elite":["forest_leshy"],"miniboss":"forest_ancient"},
  "obstacles":[{"kind":"solid","count":70,"w":26,"h":26,"hp":100},{"kind":"slow","count":40,"w":30,"h":30,"slow":0.3}],
  "events":[ev("aoe_zone",60.0,count=5,radius=26,damage=15,telegraph=1.5,area=128),ev("heal",45.0,count=1,teleport_risk=True)],
  "mods":{}, "boss":"forest", "mood":{"root":50,"scale":"minor","tempo":76,"wave":"lute"}},

 {"id":"tundra","name":"Тундра","unlock":"beat_forest","palette":{"bg":"#10202c","obstacle":"#2a4a5c","accent":"#a8e8ff","fog":"#0a1620"},
  "desc":"Метель и лавины. Ледяные глыбы отражают пули.",
  "roster":{"fodder":["tundra_zombie","tundra_wolf","tundra_shard"],"shooter":["tundra_golem"],"elite":["tundra_golem"],"miniboss":"tundra_yeti"},
  "obstacles":[{"kind":"solid","count":50,"w":24,"h":24,"hp":80},{"kind":"reflect","count":20,"w":22,"h":22,"hp":60}],
  "events":[ev("band",90.0,damage=3,width=320,push=140),ev("vision",50.0,mult=0.35,duration=8.0)],
  "mods":{}, "boss":"tundra", "mood":{"root":48,"scale":"minor","tempo":70,"wave":"strings"}},

 {"id":"cave","name":"Пещера","unlock":"beat_tundra","palette":{"bg":"#0b0b10","obstacle":"#26262e","accent":"#b070f0","fog":"#050508"},
  "desc":"Темнота и сталактиты. Свет только вокруг игрока.",
  "roster":{"fodder":["cave_spider","cave_bat"],"shooter":["cave_spitter"],"elite":["cave_troll"],"miniboss":"cave_worm"},
  "obstacles":[{"kind":"solid","count":90,"w":28,"h":28,"hp":120}],
  "events":[ev("aoe_zone",30.0,count=1,radius=24,damage=8,telegraph=1.2),ev("obstacle_toggle",120.0,count=6,duration=15.0)],
  "mods":{"darkness":0.85,"vision":160.0}, "boss":"cave", "mood":{"root":45,"scale":"phrygian","tempo":64,"wave":"drone"}},

 {"id":"mountain","name":"Гора","unlock":"beat_cave","palette":{"bg":"#2a2a30","obstacle":"#4a4a52","accent":"#ffe060","fog":"#1a1a20"},
  "desc":"Камнепады и грозовые разряды.",
  "roster":{"fodder":["mountain_harpy","mountain_goat"],"shooter":["mountain_elemental"],"elite":["mountain_griffin"],"miniboss":"mountain_guard"},
  "obstacles":[{"kind":"solid","count":60,"w":26,"h":26,"hp":150}],
  "events":[ev("roll",45.0,damage=3,push=120),ev("lightning",75.0,count=1,damage=20,radius=48)],
  "mods":{}, "boss":"mountain", "mood":{"root":52,"scale":"major","tempo":96,"wave":"brass"}},

 {"id":"desert","name":"Пустыня","unlock":"beat_mountain","palette":{"bg":"#3a2a12","obstacle":"#6a5020","accent":"#f0d060","fog":"#241a0c"},
  "desc":"Песчаные бури, зыбучие пески и перекати-поле.",
  "roster":{"fodder":["desert_scorpion","desert_mummy","desert_scarab"],"shooter":["desert_scorpion"],"elite":["desert_worm"],"miniboss":"desert_sphinx"},
  "obstacles":[{"kind":"damage","count":40,"w":20,"h":26,"damage":1,"interval":0.5},{"kind":"slow","count":30,"w":40,"h":40,"slow":0.2}],
  "events":[ev("vision",90.0,mult=0.2,duration=10.0,enemy_speed=0.3),ev("slow_zones",40.0,count=3,radius=48,slow=0.8,duration=8.0)],
  "mods":{}, "boss":"desert", "mood":{"root":50,"scale":"hijaz","tempo":88,"wave":"oud"}},

 {"id":"volcano","name":"Вулкан Крак'Тор","unlock":"beat_desert","palette":{"bg":"#2a0c08","obstacle":"#4a1a10","accent":"#ff8030","fog":"#180604"},
  "desc":"Лава, жара и огненный дождь. Держитесь у воды.",
  "roster":{"fodder":["volcano_elemental","volcano_golem"],"shooter":["volcano_imp"],"elite":["volcano_salamander"],"miniboss":"volcano_dragon"},
  "obstacles":[{"kind":"damage","count":30,"w":34,"h":24,"damage":4,"interval":1.0},{"kind":"solid","count":40,"w":26,"h":26,"hp":100}],
  "events":[ev("aoe_zone",75.0,count=1,radius=80,damage=12,telegraph=2.0,duration=8.0,dot=4),ev("rain",100.0,count=7,damage=10,radius=32),ev("vision",60.0,mult=0.45,duration=6.0,enemy_speed=0.2)],
  "mods":{"heat":15.0}, "boss":"volcano", "mood":{"root":43,"scale":"minor","tempo":104,"wave":"drums"}},

 {"id":"swamp","name":"Гнилые Топи","unlock":"beat_volcano","palette":{"bg":"#15220f","obstacle":"#2a3a1a","accent":"#a0d040","fog":"#0e1a0c"},
  "desc":"Ядовитые испарения. Каждая атака врагов травит.",
  "roster":{"fodder":["swamp_creature","swamp_mosquito"],"shooter":["swamp_frog"],"elite":["swamp_vodyanoy"],"miniboss":"swamp_hydra"},
  "obstacles":[{"kind":"slow","count":60,"w":30,"h":30,"slow":0.5}],
  "events":[ev("aoe_zone",55.0,count=1,radius=64,damage=0,telegraph=0.5,duration=10.0,dot=4),ev("rain",40.0,count=1,damage=6,radius=32)],
  "mods":{"poison_on_hit":True,"vision":180.0}, "boss":"swamp", "mood":{"root":46,"scale":"phrygian","tempo":68,"wave":"woodwind"}},

 {"id":"temple","name":"Затопленный Храм","unlock":"beat_swamp","palette":{"bg":"#0c2030","obstacle":"#1e4658","accent":"#60e0e0","fog":"#081420"},
  "desc":"Вода замедляет всё. Течения сносят игрока.",
  "roster":{"fodder":["temple_piranha","temple_serpent"],"shooter":["temple_mimic"],"elite":["temple_kraken"],"miniboss":"temple_guardian"},
  "obstacles":[{"kind":"solid","count":50,"w":26,"h":26,"hp":120},{"kind":"slow","count":30,"w":30,"h":30,"slow":0.4}],
  "events":[ev("pull",80.0,count=1,radius=96,force=120,damage=5),ev("buff",60.0,damage_taken=0.5,duration=4.0),ev("heal",35.0,count=1,mimic_chance=0.35)],
  "mods":{"water":True}, "boss":"temple", "mood":{"root":48,"scale":"major","tempo":72,"wave":"harp"}},

 {"id":"sky","name":"Небесные Острова","unlock":"beat_temple","palette":{"bg":"#20304a","obstacle":"#4a5a72","accent":"#e0f0ff","fog":"#16243c"},
  "desc":"Пропасти, ветер и молнии Зевса.",
  "roster":{"fodder":["sky_ray","sky_cloud"],"shooter":["sky_wisp"],"elite":["sky_griffin_rider"],"miniboss":"sky_storm_giant"},
  "obstacles":[{"kind":"void","count":60,"w":70,"h":70}],
  "events":[ev("push",45.0,force=160,duration=2.0),ev("lightning",70.0,count=1,damage=25,radius=64)],
  "mods":{"void_fall":2}, "boss":"sky", "mood":{"root":55,"scale":"major","tempo":92,"wave":"flute"}},

 {"id":"bonefields","name":"Костяное Поле","unlock":"beat_sky","palette":{"bg":"#1a1a1c","obstacle":"#3a3a3c","accent":"#c8c8e0","fog":"#0f0f12"},
  "desc":"Проклятая земля и восстание мёртвых.",
  "roster":{"fodder":["bone_ghost","bone_rat"],"shooter":["bone_skeleton"],"elite":["bone_lich"],"miniboss":"bone_banshee"},
  "obstacles":[{"kind":"solid","count":60,"w":24,"h":30,"hp":60}],
  "events":[ev("spawn",50.0,enemy="bone_skeleton",count=8),ev("buff",80.0,speed=0.5,damage=0.25,duration=5.0),ev("cursed_ground",30.0,count=2,radius=48,dot=3,slow=0.3,duration=10.0)],
  "mods":{}, "boss":"bonefields", "mood":{"root":44,"scale":"minor","tempo":60,"wave":"organ"}},

 {"id":"crystals","name":"Кристальные Гроты","unlock":"beat_bonefields","palette":{"bg":"#1a102a","obstacle":"#3a2450","accent":"#d0a0ff","fog":"#120a1e"},
  "desc":"Кристаллы отражают пули — включая ваши.",
  "roster":{"fodder":["crystal_spider","crystal_golem"],"shooter":["crystal_shardling"],"elite":["crystal_mage"],"miniboss":"crystal_dragon"},
  "obstacles":[{"kind":"reflect","count":60,"w":22,"h":22,"hp":50},{"kind":"solid","count":30,"w":28,"h":28,"hp":90}],
  "events":[ev("aoe_zone",65.0,count=1,radius=80,damage=4,telegraph=1.0),ev("vision",40.0,mult=0.15,duration=4.0),ev("reflect_buff",90.0,duration=8.0)],
  "mods":{}, "boss":"crystals", "mood":{"root":53,"scale":"lydian","tempo":80,"wave":"bells"}},

 {"id":"ruins","name":"Проклятые Руины","unlock":"beat_all_11","palette":{"bg":"#1a1220","obstacle":"#3a2a44","accent":"#f0c060","fog":"#100a16"},
  "desc":"Финал кампании. Все ивенты прошлых карт сразу.",
  "roster":{"fodder":["ruins_demon","ruins_ghoul","ruins_skeleton"],"shooter":["ruins_skeleton"],"elite":["ruins_wraith"],"miniboss":"ruins_colossus"},
  "obstacles":[{"kind":"solid","count":60,"w":26,"h":26,"hp":140}],
  "events":[ev("aoe_zone",45.0,count=2,radius=60,damage=10,telegraph=1.2),ev("lightning",60.0,count=1,damage=20,radius=48),ev("spawn",55.0,enemy="ruins_demon",count=4),ev("vision",70.0,mult=0.4,duration=6.0)],
  "mods":{}, "boss":"ruins", "mood":{"root":41,"scale":"harmonic","tempo":100,"wave":"choir"}},

 {"id":"infernal","name":"ПРЕИСПОДНЯЯ","unlock":"secret","secret":True,"palette":{"bg":"#180404","obstacle":"#3a0c08","accent":"#ff5020","fog":"#0c0202"},
  "desc":"Секретная карта. Пентаграммы, демоны и Сатанаил.",
  "roster":{"fodder":["infernal_imp","infernal_hound"],"shooter":["infernal_guard"],"elite":["infernal_succubus"],"miniboss":"infernal_archdemon"},
  "obstacles":[{"kind":"pentagram","count":40,"radius":24}],
  "events":[ev("hell_flame",20.0,share=0.3),ev("spawn",45.0,enemy="infernal_imp",count=3),ev("blood_rain",90.0,duration=10.0),ev("band",60.0,damage=5,width=320,burn=True)],
  "mods":{"pentagram":True,"fire_immune":False}, "boss":"infernal", "mood":{"root":38,"scale":"phrygian","tempo":110,"wave":"organ"}},
]

# ---------------------------------------------------------------- ВОЛНЫ
WAVES = {
 "timeline": [
  {"time": 0.0,   "event": "phase", "params": {"name": "start", "roster": ["fodder"], "spawn_scale": 0.6}},
  {"time": 30.0,  "event": "phase", "params": {"name": "fodder2", "roster": ["fodder"], "spawn_scale": 1.0}},
  {"time": 120.0, "event": "phase", "params": {"name": "shooters", "roster": ["fodder", "shooter"], "spawn_scale": 1.1}},
  {"time": 180.0, "event": "miniboss", "params": {"tier": 1}},
  {"time": 200.0, "event": "elites_on", "params": {"interval": 45.0}},
  {"time": 300.0, "event": "miniboss", "params": {"tier": 2}},
  {"time": 420.0, "event": "phase", "params": {"name": "mass", "roster": ["fodder", "shooter"], "spawn_scale": 1.35}},
  {"time": 600.0, "event": "miniboss", "params": {"tier": 3}},
  {"time": 840.0, "event": "miniboss", "params": {"tier": 4}},
  {"time": 870.0, "event": "calm", "params": {"duration": 30.0}},
  {"time": 900.0, "event": "boss", "params": {"kind": "first"}},
  {"time": 1080.0,"event": "phase", "params": {"name": "elites_strong", "roster": ["fodder", "shooter", "elite"], "spawn_scale": 1.5}},
  {"time": 1200.0,"event": "miniboss", "params": {"tier": 5}},
  {"time": 1200.0,"event": "blood_phase", "params": {"hp": 0.5, "speed": 0.25}},
  {"time": 1500.0,"event": "miniboss", "params": {"tier": 6}},
  {"time": 1540.0,"event": "phase", "params": {"name": "final_wave", "roster": ["fodder", "shooter", "elite"], "spawn_scale": 1.9}},
  {"time": 1740.0,"event": "dawn_warning", "params": {}},
  {"time": 1800.0,"event": "boss", "params": {"kind": "final"}},
 ],
 "miniboss_tiers": [
  {"tier": 1, "hp": [200, 300]}, {"tier": 2, "hp": [400, 500]}, {"tier": 3, "hp": [600, 800]},
  {"tier": 4, "hp": [800, 1000]}, {"tier": 5, "hp": [1000, 1500]}, {"tier": 6, "hp": [1500, 2000]},
 ],
 "quick": {"duration": 600.0, "scale": 0.55},
}

def dump(name, obj):
    with open(os.path.join(ROOT, "data", name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    print(name, len(json.dumps(obj)), "bytes")

if __name__ == "__main__":
    dump("enemies.json", ENEMIES)
    dump("bosses.json", {"bosses": BOSSES, "sathan": SATHAN})
    dump("maps.json", MAPS)
    dump("waves.json", WAVES)
