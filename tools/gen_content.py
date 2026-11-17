# -*- coding: utf-8 -*-
"""Генерация data/characters.json, data/weapons.json, data/synergies.json,
data/seals.json, data/amulets.json, data/darkness.json, data/balance.json."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- ПЕРСОНАЖИ
# passive/skill params читаются в scripts/player/player.gd (см. карту эффектов)
CHARACTERS = [
 {"id":"aldar","name":"Алдар","role":"Маг","hp":3,"price":0,"color":"#7b8cf0",
  "passive":{"id":"arcane_fire","name":"Тайный Огонь","desc":"Каждый 4-й выстрел — огненный шар: 5 урона + поджог 3 дпс на 3 сек.",
             "params":{"every":4,"damage":5.0,"burn_dps":3.0,"burn_dur":3.0}},
  "skill":{"id":"blink","name":"Мерцание","desc":"Рывок на 128 px к курсору, огненный след 2 сек (4 дпс).","cd":10.0,
           "params":{"distance":128.0,"trail_dps":4.0,"trail_dur":2.0}}},
 {"id":"gavan","name":"Сэр Гаван","role":"Паладин","hp":7,"price":1350,"color":"#f0d070",
  "passive":{"id":"celestial_shield","name":"Небесный Щит","desc":"Блокирует одну атаку, восстанавливается 120 сек.",
             "params":{"recharge":120.0}},
  "skill":{"id":"divine_wave","name":"Божественная Кара","desc":"Световая волна: 20 урона в радиусе 96 px.","cd":12.0,
           "params":{"damage":20.0,"radius":96.0}}},
 {"id":"morvena","name":"Морвена","role":"Некромант","hp":4,"price":3150,"color":"#a070f0",
  "passive":{"id":"soul_harvest","name":"Призыв Душ","desc":"При убийстве появляется дух: 8 урона ближайшему врагу.",
             "params":{"damage":8.0}},
  "skill":{"id":"raise_skeleton","name":"Воскрешение","desc":"Ближайший убитый враг становится союзным скелетом на 15 сек.","cd":12.0,
           "params":{"duration":15.0,"damage":6.0}}},
 {"id":"grumm","name":"Грумм","role":"Орк-берсерк","hp":5,"price":3150,"color":"#8fbf5f",
  "passive":{"id":"blood_rage","name":"Кровавая Ярость","desc":"Каждый полученный урон: +10% скорострельности и перезарядки (накопительно).",
             "params":{"per_hit":0.10}},
  "skill":{"id":"blood_storm","name":"Кровавый Шторм","desc":"Выпускает весь магазин в случайных направлениях, можно двигаться.","cd":12.0,
           "params":{}}},
 {"id":"liella","name":"Лиэлла","role":"Эльф-лучник","hp":3,"price":3150,"color":"#70d8c0",
  "passive":{"id":"frost_moth","name":"Морозный Мотылёк","desc":"Каждый 6-й выстрел — ледяной мотылёк, замораживающий врагов.",
             "params":{"every":6,"freeze_dur":1.2,"damage":6.0,"tick":0.6}},
  "skill":{"id":"arrow_rain","name":"Ливень Стрел","desc":"10 стрел веером в сторону курсора.","cd":8.0,
           "params":{"arrows":10,"damage":12.0,"spread":60.0}}},
 {"id":"torin","name":"Торин","role":"Гном-инженер","hp":4,"price":4500,"color":"#d08a50",
  "passive":{"id":"enchanted_blade","name":"Зачарованный Клинок","desc":"После перезарядки магический меч вращается вокруг игрока 5 сек (22 урона за удар).",
             "params":{"duration":5.0,"damage":22.0,"speed":2.4,"radius":38.0}},
  "skill":{"id":"turret","name":"Боевая Турель","desc":"Турель стреляет 8 сек в ближайшего врага.","cd":15.0,
           "params":{"duration":8.0,"damage":10.0,"interval":0.35}}},
 {"id":"finn","name":"Финн","role":"Halfling-вор","hp":3,"price":4500,"color":"#c0c060",
  "passive":{"id":"wind_in_back","name":"Ветер в Спине","desc":"Каждые 10 сек +30% урона и скорости движения (до +120%), сбрасывается от урона.",
             "params":{"interval":10.0,"per_stack":0.30,"max_stacks":4}},
  "skill":{"id":"shadow_step","name":"Теневой Шаг","desc":"Рывок с теневым клоном на 2 сек, атакующим врагов вокруг.","cd":10.0,
           "params":{"distance":120.0,"clone_dur":2.0,"radius":44.0}}},
 {"id":"eowin","name":"Эовин","role":"Друид","hp":4,"price":6000,"color":"#70c060",
  "passive":{"id":"nature_breath","name":"Дыхание Природы","desc":"Каждые 2 сек порыв ветра в ближайшего врага (8 урона).",
             "params":{"interval":2.0,"damage":8.0}},
  "skill":{"id":"tornado","name":"Смерч","desc":"3 торнадо, по 15 урона каждое.","cd":12.0,
           "params":{"count":3,"damage":15.0,"duration":3.0,"radius":44.0}}},
 {"id":"ilaria","name":"Илария","role":"Жрица","hp":4,"price":6000,"color":"#f0e0a0",
  "passive":{"id":"healing_prayer","name":"Молитва Исцеления","desc":"Восстановление 1 HP каждые 90 сек.",
             "params":{"interval":90.0}},
  "skill":{"id":"heal_wave","name":"Волна Исцеления","desc":"Лечит 2 HP, аура +15% скорострельности на 5 сек.","cd":20.0,
           "params":{"heal":2,"aura_fire_rate":0.15,"duration":5.0,"radius":120.0}}},
 {"id":"dark_knight","name":"Тёмный Рыцарь","role":"Секретный","hp":5,"price":0,"color":"#5a5a70",
  "passive":{"id":"vampirism","name":"Вампиризм","desc":"5% нанесённого урона возвращается как лечение.",
             "params":{"lifesteal":0.05}},
  "skill":{"id":"blood_cleave","name":"Кровавый Разрез","desc":"Круговой удар: 30 урона в радиусе 72 px и лечение 1 HP.","cd":11.0,
           "params":{"damage":30.0,"radius":72.0,"heal":1}}},
]

# Уникальные апгрейды персонажей (выпадают только из сундуков элит/мини-боссов)
CHAR_UPGRADES = {
 "aldar": [
  {"id":"aldar_u1","name":"Сродство Тайн","desc":"Урон магических снарядов +50%, обычный урон -25%.","mods":{"magic_dmg":0.50,"dmg":-0.25},"flags":{}},
  {"id":"aldar_u2","name":"Пылающий Разум","desc":"+10% скорострельности за каждое подожжённое существо (сброс при перезарядке).","mods":{},"flags":{"burning_fire_rate":0.10}},
  {"id":"aldar_u3","name":"Звёздный Дождь","desc":"Вместо мерцания — метеоритный дождь: 5 метеоритов по 10 урона.","mods":{},"flags":{"skill_meteor":5,"skill_meteor_damage":10.0}},
 ],
 "gavan": [
  {"id":"gavan_u1","name":"Божественное Благословение","desc":"Пока активен щит: перезарядка и скорость +25%.","mods":{},"flags":{"shield_blessing":0.25}},
  {"id":"gavan_u2","name":"Правосудие","desc":"+1 макс. HP за каждые 500 убийств Карой (макс. +3).","mods":{},"flags":{"justice_cap":3}},
  {"id":"gavan_u3","name":"Небесное Благословение","desc":"Каждые 500 убийств Карой лечат 1 HP.","mods":{},"flags":{"heaven_heal":True}},
 ],
 "morvena": [
  {"id":"morvena_u1","name":"Легион Мёртвых","desc":"Урон призывов +40%.","mods":{"summon_dmg":0.40},"flags":{}},
  {"id":"morvena_u2","name":"Тёмный Властелин","desc":"Призывы получают +30% скорости атаки.","mods":{"summon_speed":0.30},"flags":{}},
  {"id":"morvena_u3","name":"Власть над Мёртвыми","desc":"Духи появляются от любого убийства призывов.","mods":{},"flags":{"summon_souls":True}},
 ],
 "grumm": [
  {"id":"grumm_u1","name":"Масса и Сила","desc":"После лечения +15% урона и размера пуль (накопительно).","mods":{},"flags":{"heal_growth":0.15}},
  {"id":"grumm_u2","name":"Несгибаемая Воля","desc":"При HP ≤ 50%: +2 пробития, +25% отбрасывания.","mods":{},"flags":{"unbending":True}},
  {"id":"grumm_u3","name":"Ярость Крови","desc":"При HP ≤ 25%: +75% урона и скорострельности.","mods":{},"flags":{"lowhp_fury":0.75}},
 ],
 "liella": [
  {"id":"liella_u1","name":"Сродство Мороза","desc":"Шанс заморозки пулями +35%.","mods":{"freeze_chance":0.35},"flags":{}},
  {"id":"liella_u2","name":"Ледяной Укус","desc":"При заморозке враг теряет 15% макс. HP (элиты/боссы 3%).","mods":{},"flags":{"freeze_bite":0.15}},
  {"id":"liella_u3","name":"Двойная Стая","desc":"Дополнительный ледяной мотылёк.","mods":{},"flags":{"moth_extra":1}},
 ],
 "torin": [
  {"id":"torin_u1","name":"Мастерство Клинка","desc":"Урон пуль +40%, мечи получают бонусы от урона пуль.","mods":{"dmg":0.40},"flags":{"blade_from_bullets":True}},
  {"id":"torin_u2","name":"Тысяча Клинков","desc":"После перезарядки призывается дополнительный магический меч.","mods":{},"flags":{"blade_extra":1}},
  {"id":"torin_u3","name":"Мастер Турелей","desc":"Турели живут на 50% дольше и стреляют на 30% быстрее.","mods":{},"flags":{"turret_master":1}},
 ],
 "finn": [
  {"id":"finn_u1","name":"Убийца","desc":"Автоматически убивает врагов с HP < 20%.","mods":{},"flags":{"exec_threshold":0.20}},
  {"id":"finn_u2","name":"Попутный Ветер","desc":"Каждые 10 сек +30% урона и скорости движения.","mods":{},"flags":{"wind_runner":0.30}},
  {"id":"finn_u3","name":"Тень Ветра","desc":"Каждые 10 сек +10% скорострельности и +1 пробитие.","mods":{},"flags":{"wind_shadow":True}},
 ],
 "eowin": [
  {"id":"eowin_u1","name":"Власть Ветра","desc":"После выстрела последним патроном — 3 торнадо.","mods":{},"flags":{"last_shot_tornado":3}},
  {"id":"eowin_u2","name":"Покоритель Ветра","desc":"Порыв ветра наносит +45 урона.","mods":{},"flags":{"gust_damage_add":45.0}},
  {"id":"eowin_u3","name":"Око Грозы","desc":"Каждые 2 сек порыв бьёт x2 урона трижды.","mods":{},"flags":{"gust_echo":3,"gust_mult":2.0}},
 ],
 "ilaria": [
  {"id":"ilaria_u1","name":"Благодать","desc":"Восстановление 1 HP каждые 60 сек.","mods":{},"flags":{"regen":60.0}},
  {"id":"ilaria_u2","name":"Священный Свет","desc":"Аура наносит 10 урона нежити каждые 0.5 сек.","mods":{},"flags":{"holy_aura":10.0}},
  {"id":"ilaria_u3","name":"Покровительство","desc":"При HP = 1 — неуязвимость 3 сек (1 раз за раунд).","mods":{},"flags":{"guardian_angel":3.0}},
 ],
 "dark_knight": [
  {"id":"dk_u1","name":"Печать Крови","desc":"Вампиризм +10%.","mods":{"lifesteal":0.10},"flags":{}},
  {"id":"dk_u2","name":"Ночь Близко","desc":"Урон +30% в радиусе 96 px.","mods":{},"flags":{"close_damage":0.30}},
  {"id":"dk_u3","name":"Рыцарь Бездны","desc":"Убийства лечат 1 HP с шансом 10%.","mods":{},"flags":{"kill_heal":0.10}},
 ],
}

for c in CHARACTERS:
    c["upgrades"] = CHAR_UPGRADES.get(c["id"], [])

# ---------------------------------------------------------------- ОРУЖИЕ
W = [
 {"id":"revolver","name":"Револьвер","price":0,"damage":20,"fire_rate":4.0,"mag":6,"reload":1.0,
  "projectiles":1,"spread":0,"proj_speed":420,"pierce":0,"bounce":0,"behavior":"straight","color":"#e8d878",
  "desc":"Надёжный стартовый револьвер. Баланс урона и темпа.",
  "evolutions":[
   {"id":"ev_marksman","name":"Меткий Стрелок","desc":"Пуля отскакивает от врагов 2 раза.","mods":{},"flags":{"bounce":2}},
   {"id":"ev_dragon","name":"Драконий Калибр","desc":"Пуля поджигает, урон +30%.","mods":{"dmg":0.30},"flags":{"bullet_burn":True}},
   {"id":"ev_executioner","name":"Палач","desc":"Урон x3 по врагам с HP > 75%.","mods":{},"flags":{"full_hp_bonus":3.0}}]},
 {"id":"shotgun","name":"Дробовик","price":800,"damage":12,"fire_rate":5.0,"mag":2,"reload":1.0,
  "projectiles":4,"spread":30,"proj_speed":380,"pierce":0,"bounce":0,"behavior":"straight","color":"#e0a060",
  "desc":"4 снаряда конусом 30°. Большой магазин не нужен — урон вблизи.",
  "evolutions":[
   {"id":"ev_pointblank","name":"Ближний Залп","desc":"Снаряды летят 32 px, +100% урона.","mods":{"dmg":1.0,"range_mult":-0.6},"flags":{"point_blank":True}},
   {"id":"ev_shrapnel","name":"Осколочный Залп","desc":"При попадании снаряд делится на 3.","mods":{},"flags":{"split_on_hit":3}},
   {"id":"ev_inferno","name":"Инферно","desc":"Снаряды поджигают, урон +50%.","mods":{"dmg":0.50},"flags":{"bullet_burn":True}}]},
 {"id":"crossbow","name":"Арбалет","price":1500,"damage":30,"fire_rate":4.0,"mag":1,"reload":1.0,
  "projectiles":1,"spread":0,"proj_speed":520,"pierce":1,"bounce":0,"behavior":"straight","color":"#b0c0e0",
  "desc":"Пробивает 1 врага. Стоя на месте копит +5% урона в секунду (до +100%).",
  "evolutions":[
   {"id":"ev_windbranch","name":"Ветвь Ветра","desc":"Снаряд создаёт торнадо (8 урона по площади).","mods":{},"flags":{"tornado_on_hit":8.0}},
   {"id":"ev_piercer","name":"Пронзатель","desc":"+3 пробития, +50% урона.","mods":{"pierce":3,"dmg":0.50},"flags":{}},
   {"id":"ev_burstbolt","name":"Разрывной Болт","desc":"При попадании взрыв 30 урона, радиус 64.","mods":{},"flags":{"explode_on_hit":30.0,"explode_radius":64.0}}]},
 {"id":"dual_pistols","name":"Парные пистолеты","price":2000,"damage":4,"fire_rate":4.0,"mag":32,"reload":2.5,
  "projectiles":2,"spread":6,"proj_speed":440,"pierce":0,"bounce":0,"behavior":"straight","color":"#d0d0d0",
  "desc":"Два выстрела за нажатие, огромный магазин, долгая перезарядка.",
  "evolutions":[
   {"id":"ev_leadstorm","name":"Шторм Свинца","desc":"+4 снаряда, -20% урона.","mods":{"proj":4,"dmg":-0.20},"flags":{}},
   {"id":"ev_thunderlight","name":"Гром и Молния","desc":"Каждый 3-й выстрел вызывает молнию (10 урона).","mods":{},"flags":{"lightning_every":3,"lightning_damage":10.0}},
   {"id":"ev_twins","name":"Казнящие Близнецы","desc":"+100% скорострельности при HP > 75%.","mods":{},"flags":{"highhp_fire_rate":1.0}}]},
 {"id":"flame_cannon","name":"Огненная Пушка","price":2500,"damage":3,"fire_rate":2.5,"mag":12,"reload":1.4,
  "projectiles":1,"spread":0,"proj_speed":300,"pierce":0,"bounce":0,"behavior":"fireball","color":"#f07030",
  "desc":"Огненный шар: поджигает врагов рядом (3 дпс, 3 сек).",
  "evolutions":[
   {"id":"ev_hellfire","name":"Адское Пламя","desc":"Радиус огня +100%.","mods":{},"flags":{"burn_radius":1.0}},
   {"id":"ev_meteor","name":"Метеорит","desc":"Снаряд взрывается метеором (15 урона).","mods":{},"flags":{"explode_on_hit":15.0,"explode_radius":48.0}},
   {"id":"ev_phoenix","name":"Феникс","desc":"При перезарядке призывает феникса на 10 сек.","mods":{},"flags":{"summon_on_reload":"phoenix"}}]},
 {"id":"grenade_launcher","name":"Гранатомёт","price":3500,"damage":45,"fire_rate":2.9,"mag":6,"reload":1.5,
  "projectiles":1,"spread":0,"proj_speed":280,"pierce":0,"bounce":0,"behavior":"grenade","color":"#a08050",
  "desc":"Граната взрывается в радиусе 64 px.",
  "evolutions":[
   {"id":"ev_cluster","name":"Кассетный Залп","desc":"Граната делится на 3 малых.","mods":{},"flags":{"cluster":3}},
   {"id":"ev_napalm","name":"Напалм","desc":"После взрыва остаётся лужа огня (5 дпс, 4 сек).","mods":{},"flags":{"napalm":True}},
   {"id":"ev_nuke","name":"Ядерный Удар","desc":"+200% урона, -50% скорострельности.","mods":{"dmg":2.0,"fire_rate":-0.5},"flags":{}}]},
 {"id":"wingbow","name":"Летучий Арбалет","price":4000,"damage":6,"fire_rate":2.0,"mag":12,"reload":1.5,
  "projectiles":2,"spread":8,"proj_speed":330,"pierce":0,"bounce":0,"behavior":"homing","color":"#a07090",
  "desc":"Самонаводящиеся рукокрылы. Считаются и пулями, и призывами.",
  "evolutions":[
   {"id":"ev_swarm","name":"Рой","desc":"+4 снаряда.","mods":{"proj":4},"flags":{}},
   {"id":"ev_bloodsucker","name":"Кровопийца","desc":"10% вампиризма.","mods":{"lifesteal":0.10},"flags":{}},
   {"id":"ev_plaguebats","name":"Чумные Рукокрылы","desc":"Мыши накладывают проклятие (5 дпс, 5 сек).","mods":{},"flags":{"bullet_curse":True}}]},
 {"id":"sorcerer_bow","name":"Чародейский Лук","price":5000,"damage":16,"fire_rate":2.5,"mag":4,"reload":1.2,
  "projectiles":1,"spread":0,"proj_speed":460,"pierce":0,"bounce":0,"behavior":"arrow","color":"#90c0f0",
  "desc":"Стрелы втыкаются в землю и возвращаются при перезарядке, нанося урон на пути.",
  "evolutions":[
   {"id":"ev_crystalbow","name":"Кристаллический Лук","desc":"Стрелы создают ледяные кристаллы (заморозка).","mods":{},"flags":{"arrow_freeze":True}},
   {"id":"ev_chainlight","name":"Цепная Молния","desc":"Стрелы поражают 3 врагов цепью.","mods":{},"flags":{"chain":3}},
   {"id":"ev_arrowrain","name":"Дождь Стрел","desc":"При перезарядке дождь стрел в радиусе 128 px.","mods":{},"flags":{"arrow_rain_reload":128.0}}]},
 {"id":"cyclone_blade","name":"Вихревой Клинок","price":6000,"damage":18,"fire_rate":3.0,"mag":1,"reload":1.3,
  "projectiles":1,"spread":0,"proj_speed":420,"pierce":0,"bounce":0,"behavior":"blade","color":"#c0e0e0",
  "desc":"Во время перезарядки — круговая атака вокруг игрока (24 урона, 48 px).",
  "evolutions":[
   {"id":"ev_bladewhirl","name":"Вихрь Клинков","desc":"+100% радиуса круговой атаки.","mods":{},"flags":{"circle_radius":1.0}},
   {"id":"ev_steeldance","name":"Танец Сталей","desc":"3 меча вращаются вокруг игрока.","mods":{},"flags":{"orbit_blades":3}},
   {"id":"ev_souleater","name":"Пожиратель Душ","desc":"Убийства круговой атакой лечат 1 HP.","mods":{},"flags":{"circle_heal":True}}]},
 {"id":"storm_staff","name":"Грозовой Посох","price":7500,"damage":8,"fire_rate":1.5,"mag":8,"reload":2.0,
  "projectiles":1,"spread":0,"proj_speed":300,"pierce":0,"bounce":0,"behavior":"orb","color":"#a0b0ff",
  "desc":"Шар молнии цепляется к врагам, при перезарядке взрывается.",
  "evolutions":[
   {"id":"ev_storm","name":"Гроза","desc":"При перезарядке 5 молний в случайных врагов.","mods":{},"flags":{"reload_lightning":5}},
   {"id":"ev_chaingrom","name":"Цепной Гром","desc":"Шар передаётся 5 врагам.","mods":{},"flags":{"chain":5}},
   {"id":"ev_mjolnir","name":"Мьёльнир","desc":"+300% урона, -50% скорострельности.","mods":{"dmg":3.0,"fire_rate":-0.5},"flags":{}}]},
 {"id":"dark_scepter","name":"Чёрный Жезл","price":8000,"damage":12,"fire_rate":2.0,"mag":6,"reload":1.8,
  "projectiles":1,"spread":0,"proj_speed":360,"pierce":0,"bounce":0,"behavior":"curse","color":"#8050a0",
  "desc":"Снаряд накладывает проклятие: 200% урона пули за 3 сек.",
  "evolutions":[
   {"id":"ev_plague","name":"Моровая Чума","desc":"Убитые проклятием распространяют его.","mods":{},"flags":{"plague":True}},
   {"id":"ev_bloodritual","name":"Ритуал Крови","desc":"+1% урона пуль за каждые 10 убитых проклятием.","mods":{},"flags":{"blood_ritual":0.01}},
   {"id":"ev_soulreaper","name":"Жнец Душ","desc":"Убийства проклятием призывают духов.","mods":{},"flags":{"curse_soul":True}}]},
 {"id":"holy_hammer","name":"Священный Молот","price":10000,"damage":35,"fire_rate":1.2,"mag":1,"reload":2.5,
  "projectiles":1,"spread":0,"proj_speed":340,"pierce":0,"bounce":0,"behavior":"hammer","color":"#f0e8b0",
  "desc":"Молот летит по дуге, святой взрыв 24 урона (64 px). По нежити x2.",
  "unlock":"win_gavan_darkness5",
  "evolutions":[
   {"id":"ev_verdict","name":"Приговор","desc":"+100% радиус взрыва.","mods":{},"flags":{"explode_radius":64.0}},
   {"id":"ev_righteous","name":"Праведная Ярость","desc":"+50% урона за каждое HP выше 5.","mods":{},"flags":{"righteous":0.50}},
   {"id":"ev_dawn","name":"Молот Рассвета","desc":"При перезарядке колонна света с неба (60 урона, 96 px).","mods":{},"flags":{"reload_pillar":60.0}}]},
]
for w in W:
    w.setdefault("unlock", "")

# ---------------------------------------------------------------- СИНЕРГИИ
SYNERGIES = [
 {"id":"syn_reaper","name":"Пули Жнеца","requires":["damage_t3","fire_rate_t2a"],"desc":"+10 урона пуль, -1 HP.",
  "mods":{"flat_dmg":10.0,"hp":-1},"flags":{}},
 {"id":"syn_iceflame","name":"Ледяное Пламя","requires":["flame_t1","frost_t2a"],"desc":"При заморозке — поджог 6 дпс.",
  "mods":{},"flags":{"freeze_burn":6.0}},
 {"id":"syn_weaponmaster","name":"Мастерство Оружия","requires":["reload_t2a","multishot_t2a","fire_rate_t1"],
  "desc":"+30% урона, +15% скорострельности, +15% перезарядки, +1 магазин, +1 пробитие.",
  "mods":{"dmg":0.30,"fire_rate":0.15,"reload":0.15,"mag":1,"pierce":1},"flags":{}},
 {"id":"syn_smallmag","name":"Малый Магазин","requires":["multishot_t2b","reload_t2b"],"desc":"+75% перезарядки, +50% урона, -4 магазина.",
  "mods":{"reload":0.75,"dmg":0.50,"mag":-4},"flags":{}},
 {"id":"syn_overload","name":"Перегрузка","requires":["thunder_t3","flame_t2b"],"desc":"Молния по горящему врагу вызывает взрыв 25 урона.",
  "mods":{},"flags":{"overload":25.0}},
 {"id":"syn_unbreakable","name":"Несокрушимый","requires":["fire_rate_t3","multishot_t2b"],"desc":"+2 снаряда, +25% скорострельности, -25% скорости движения.",
  "mods":{"proj":2,"fire_rate":0.25,"move_speed":-0.25},"flags":{}},
 {"id":"syn_summonpower","name":"Власть Призыва","requires":["summon_t2b","scythe_t2a"],"desc":"+35% урона и скорости призывов, -35% урона пуль.",
  "mods":{"summon_dmg":0.35,"summon_speed":0.35,"dmg":-0.35},"flags":{}},
 {"id":"syn_plague","name":"Моровая Чума","requires":["dark_t2a","damage_t3"],"desc":"Убитые проклятием распространяют его.",
  "mods":{},"flags":{"plague":True}},
 {"id":"syn_resonance","name":"Резонанс","requires":["pickup_t2a","thunder_t2b"],"desc":"При получении патронов +35% скорострельности на 2 сек.",
  "mods":{},"flags":{"resonance":0.35}},
 {"id":"syn_windshadow","name":"Тень Ветра","requires":["dodge_t2b","fast_arrows_t3"],"desc":"+10% скорострельности и +1 пробитие каждые 10 сек.",
  "mods":{"pierce":1},"flags":{"wind_shadow":True}},
 {"id":"syn_swordshield","name":"Меч и Щит","requires":["shield_t1","light_t2b"],"desc":"Убийства карой снижают восстановление щита на 1 сек.",
  "mods":{},"flags":{"sword_and_shield":True}},
 {"id":"syn_giant","name":"Исполин","requires":["health_t2b","light_t3"],"desc":"+2 HP, +25% скорости, +25% размера.",
  "mods":{"hp":2,"move_speed":0.25,"size":0.25},"flags":{}},
]

# ---------------------------------------------------------------- ПЕЧАТИ (томы)
SEALS = [
 {"id":"seal_bounce","name":"Печать Рикошета","desc":"+2 отскока, -25% урона, -1 HP.","mods":{"bounce":2,"dmg":-0.25,"hp":-1},"flags":{}},
 {"id":"seal_thunder","name":"Печать Грома","desc":"+25% перезарядки, -16% урона; последний патрон вызывает молнию 22 урона.","mods":{"reload":0.25,"dmg":-0.16},"flags":{"last_shot_lightning":22.0}},
 {"id":"seal_elements","name":"Печать Стихий","desc":"+35% урона поджога/молнии/длительности заморозки.","mods":{"burn_mult":0.35,"shock_dmg_pct":0.35,"freeze_dur":0.35},"flags":{}},
 {"id":"seal_fragility","name":"Печать Хрупкости","desc":"Уворота нет, x2 урона, смерть от любого удара.","mods":{"dmg":1.0,"dodge":-1.0},"flags":{"fragile":True}},
 {"id":"seal_might","name":"Печать Мощи","desc":"+1 HP, +2 урона за каждый HP.","mods":{"hp":1},"flags":{"dmg_per_hp":2.0}},
 {"id":"seal_strength","name":"Печать Силы","desc":"+50% урона, +100% размера, +1 пробитие, -25% скорострельности, -1 HP.",
  "mods":{"dmg":0.50,"size":1.0,"pierce":1,"fire_rate":-0.25,"hp":-1},"flags":{}},
 {"id":"seal_fury","name":"Печать Ярости","desc":"+60% скорострельности, +60 разброса, -50% урона, -95% отбрасывания, x3 магазин.",
  "mods":{"fire_rate":0.60,"spread":60.0,"dmg":-0.50,"knockback":-0.95,"mag_pct":2.0},"flags":{}},
 {"id":"seal_swift","name":"Печать Стремительности","desc":"+50% скорости движения, -1 HP.","mods":{"move_speed":0.50,"hp":-1},"flags":{}},
 {"id":"seal_steadfast","name":"Печать Непоколебимости","desc":"Скорость ходьбы -100%, +100% урона, +100% размера, +1 снаряд.",
  "mods":{"move_speed":-1.0,"dmg":1.0,"size":1.0,"proj":1},"flags":{}},
 {"id":"seal_summon","name":"Печать Призыва","desc":"+50% урона и скорости призывов, -50% перезарядки (медленнее).",
  "mods":{"summon_dmg":0.50,"summon_speed":0.50,"reload":-0.50},"flags":{}},
 {"id":"seal_life","name":"Печать Жизни","desc":"+4 HP, -25% уворота.","mods":{"hp":4,"dodge":-0.25},"flags":{}},
 {"id":"seal_wind","name":"Печать Ветра","desc":"+10% скорости, урон растёт от бонусов скорости, -15% урона.",
  "mods":{"move_speed":0.10,"dmg":-0.15},"flags":{"wind_damage":True}},
]

# ---------------------------------------------------------------- АМУЛЕТЫ
AMULETS = [
 {"id":"amu_echo","name":"Отголосок","type":"attack","max_rank":5,
  "desc":"Последний патрон: урон всем врагам рядом (+20% урона пули за ранг).","per_rank":0.20},
 {"id":"amu_bodiless","name":"Бестелесный","type":"attack","max_rank":5,
  "desc":"Каждые 50 убийств оружие не тратит патроны (+2 сек за ранг).","per_rank":2.0},
 {"id":"amu_rhythm","name":"Ритм Стрелка","type":"attack","max_rank":5,
  "desc":"+1 пробитие за ранг в первые 60 сек раунда.","per_rank":1},
 {"id":"amu_courage","name":"Отвага","type":"attack","max_rank":5,
  "desc":"+2 магазина за ранг.","per_rank":2},
 {"id":"amu_fortress","name":"Крепость","type":"attack","max_rank":5,
  "desc":"+10% урона за ранг при HP > 75%.","per_rank":0.10},
 {"id":"amu_fragility","name":"Хрупкость","type":"attack","max_rank":5,
  "desc":"+25% урона за ранг, -1 HP за ранг.","per_rank":0.25},
 {"id":"amu_spark","name":"Искра","type":"attack","max_rank":5,
  "desc":"+5% шанс молнии за ранг при попадании.","per_rank":0.05},
 {"id":"amu_frost","name":"Стужа","type":"attack","max_rank":5,
  "desc":"+5% шанс заморозки за ранг.","per_rank":0.05},
 {"id":"amu_agility","name":"Проворство","type":"defense","max_rank":5,
  "desc":"+10% уворота за ранг (кап 75%).","per_rank":0.10},
 {"id":"amu_foresight","name":"Предвидение","type":"defense","max_rank":5,
  "desc":"+25% радиуса видимости за ранг.","per_rank":0.25},
 {"id":"amu_growth","name":"Рост","type":"defense","max_rank":5,
  "desc":"Лечение 1 HP за каждые 5 уровней.","per_rank":1},
 {"id":"amu_endurance","name":"Стойкость","type":"defense","max_rank":5,
  "desc":"+1 макс. HP за ранг.","per_rank":1},
 {"id":"amu_recovery","name":"Восстановление","type":"defense","max_rank":5,
  "desc":"Старт раунда с +1 HP за ранг (запас лечения).","per_rank":1},
 {"id":"amu_soulbond","name":"Связь Душ","type":"defense","max_rank":5,
  "desc":"Воскрешение с 1 HP (1 раз за раунд за ранг).","per_rank":1},
 {"id":"amu_bulwark","name":"Оплот","type":"defense","max_rank":5,
  "desc":"-5% получаемого урона за ранг.","per_rank":0.05},
 {"id":"amu_secondwind","name":"Второе Дыхание","type":"defense","max_rank":5,
  "desc":"+10% скорости за ранг при HP < 50%.","per_rank":0.10},
]
AMULET_COSTS = [500, 1415, 2598, 4000, 5590]

# ---------------------------------------------------------------- СЛОЖНОСТЬ
DARKNESS = [
 {"level":1,"desc":"Мелкие враги спавнятся на 25% чаще.","mods":{"fodder_spawn":0.25}},
 {"level":2,"desc":"Мелкие враги +25% HP.","mods":{"fodder_hp":0.25}},
 {"level":3,"desc":"Элиты появляются на 25% раньше.","mods":{"elite_earlier":0.25}},
 {"level":4,"desc":"Боссы +50% HP.","mods":{"boss_hp":0.50}},
 {"level":5,"desc":"Элиты наносят x2 урона.","mods":{"elite_dmg":1.0}},
 {"level":6,"desc":"Боссы наносят x2 урона.","mods":{"boss_dmg":1.0}},
 {"level":7,"desc":"Мелкие враги +15% скорости.","mods":{"fodder_speed":0.15}},
 {"level":8,"desc":"Элиты +25% скорости.","mods":{"elite_speed":0.25}},
 {"level":9,"desc":"Выбор перков: 4 вместо 5.","mods":{"choices":-1}},
 {"level":10,"desc":"Мелкие враги x2 урона в последние 5 минут.","mods":{"fodder_late_dmg":1.0}},
 {"level":11,"desc":"-15% получаемого опыта.","mods":{"xp":-0.15}},
 {"level":12,"desc":"Мелкие враги +50% HP.","mods":{"fodder_hp":0.50}},
 {"level":13,"desc":"Элиты +75% HP.","mods":{"elite_hp":0.75}},
 {"level":14,"desc":"Боссы +100% HP.","mods":{"boss_hp":1.0}},
 {"level":15,"desc":"Боссы атакуют на 80% чаще.","mods":{"boss_rate":0.80}},
]

# ---------------------------------------------------------------- БАЛАНС
BALANCE = {
 "version": "1.0.0",
 "player": {
   "move_speed": 105.0, "pickup_range": 64.0, "iframes": 0.6,
   "vision_radius": 190.0, "dodge_cap": 0.75, "crit_base": 0.05, "crit_mult": 2.0,
   "bullet_speed_default": 420.0, "bullet_life": 1.6,
 },
 "run": {
   "map_size": [3200, 1800], "max_enemies": 1500, "max_level": 60,
   "xp_base": 8, "xp_growth": 1.16,
   "spawn_interval_start": 2.0, "spawn_interval_end": 0.30,
   "spawn_batch_start": 3, "spawn_batch_end": 30,
   "spawn_ramp_seconds": 1800.0,
   "pickup_xp": {"fodder": 1, "shooter": 1, "elite": 15, "miniboss": 50, "boss": 200},
   "gold_chance": 0.05, "heart_chance": 0.005,
   "souls_per_kill": 0.02, "souls_win": 250, "souls_boss": 120,
 },
 "difficulty_base": {"fodder_hp": 1.0, "elite_hp": 1.0, "boss_hp": 1.0},
 "modes": {
   "standard": {"duration": 1800.0, "amulets": True, "name": "Стандартный (30 мин)"},
   "quick": {"duration": 600.0, "amulets": False, "name": "Быстрый (10 мин)"},
   "endless": {"duration": 1.0e12, "amulets": False, "name": "Бесконечный"},
 },
 "endless": {"perk_stacks": 4, "buff_every": 600.0, "hp_add_mult": 5.0, "speed_add_mult": 0.2, "boss_rate_add": 0.25},
 "secret": {"infernal_secret_boss_hp": 7500, "sathan_hp": 10000, "grotgar_no_hit": True},
}

def dump(name, obj):
    with open(os.path.join(ROOT, "data", name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    print(name, "ok")

if __name__ == "__main__":
    dump("characters.json", CHARACTERS)
    dump("weapons.json", W)
    dump("synergies.json", SYNERGIES)
    dump("seals.json", SEALS)
    dump("amulets.json", {"amulets": AMULETS, "costs": AMULET_COSTS})
    dump("darkness.json", DARKNESS)
    dump("balance.json", BALANCE)
