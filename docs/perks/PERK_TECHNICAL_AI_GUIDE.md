# 🎯 ТЕХНИЧЕСКАЯ ДОКУМЕНТАЦИЯ РАБОТЫ ПЕРКОВ
## Для точной настройки ИИ и баланса

> **Полное техническое описание механик перков, формул расчёта, приоритетов выбора и параметров для ИИ**
> 
> **Референс:** 20 Minutes Till Dawn + адаптация для Surwave

---

## 📊 СТРУКТУРА ПЕРКОВ

### Иерархия перков
```
Каждое дерево перков имеет структуру:
├── T1 (Tier 1) — базовый перк
│   ├── Появляется с 1-го уровня
│   ├── Не требует предварительных условий
│   └── Может быть взят любым персонажем
│
├── T2a (Tier 2, вариант A) — первое улучшение
│   ├── Требует: T1 этого дерева
│   ├── Взаимоисключающее с T2b
│   └── Открывает путь к T3a
│
├── T2b (Tier 2, вариант B) — второе улучшение
│   ├── Требует: T1 этого дерева
│   ├── Взаимоисключающее с T2a
│   └── Открывает путь к T3b
│
└── T3 (Tier 3) — финальное улучшение
    ├── Требует: T2a ИЛИ T2b (то, что было взято)
    ├── Усиливает выбранное направление
    └── Может иметь дополнительные эффекты
```

### Специализации (Specialize)
```
Особый тип перка:
├── Выпадает ТОЛЬКО из сундуков элит/мини-боссов
├── Даёт x3 эффект следующего выбранного перка
├── В бесконечном режиме: x(2^(n+1)-1) копий
│   ├── n=0: x1 (первый специализация)
│   ├── n=1: x3
│   ├── n=2: x7
│   ├── n=3: x15
│   └── n=4: x31
├── У каждого персонажа 30+ уникальных специализаций
└── Примеры эффектов в таблице ниже
```

---

## 🔢 ФОРМУЛЫ РАСЧЁТА ЭФФЕКТОВ

### Базовые формулы
```gdscript
# Расчёт урона с учётом перков
func calculate_bullet_damage(base_damage: float, perks: Array) -> float:
    var multiplier = 1.0
    var flat_bonus = 0.0
    
    for perk in perks:
        match perk.id:
            "damage_t1":  # Урон +40%
                multiplier *= 1.40
            "damage_t2a":  # Крупный Калибр +45%
                multiplier *= 1.45
            "damage_t3":  # Пули Жнеца +20%
                multiplier *= 1.20
            "fast_arrows_t3a":  # Снайпер +15% урона
                multiplier *= 1.15
            "holy_might":  # +10 урона за текущее HP
                flat_bonus += player.current_hp * 10.0
    
    return (base_damage * multiplier) + flat_bonus

# Расчёт скорострельности
func calculate_fire_rate(base_rate: float, perks: Array) -> float:
    var multiplier = 1.0
    
    for perk in perks:
        match perk.id:
            "fire_rate_t1":  # Скорострельность +25%
                multiplier *= 1.25
            "fire_rate_t2a":  # Облегчённые Пули +15%
                multiplier *= 1.15
            "haste_t1":  # Haste +5%
                multiplier *= 1.05
    
    return base_rate * multiplier

# Расчёт скорости движения
func calculate_move_speed(base_speed: float, perks: Array) -> float:
    var multiplier = 1.0
    
    for perk in perks:
        match perk.id:
            "speed_t1":  # Скорость +15%
                multiplier *= 1.15
            "speed_t2a":  # Спринт +20%
                multiplier *= 1.20
            "windborne_t2a":  # Windborne +15%
                multiplier *= 1.15
    
    return base_speed * multiplier

# Расчёт урона призывов
func calculate_summon_damage(base_damage: float, perks: Array) -> float:
    var multiplier = 1.0
    var flat_bonus = 0.0
    
    for perk in perks:
        match perk.id:
            "summon_t1":  # Призыв +25% урона
                multiplier *= 1.25
            "summon_t2a":  # Двойное Владение +40%
                multiplier *= 1.40
            "summon_t2b":  # Приз Возмездия +30%
                multiplier *= 1.30
            "feed_beasts_t2":  # +1% за 15 убийств
                flat_bonus += summon_kill_count / 15.0 * 0.01
    
    return (base_damage * multiplier) + flat_bonus
```

### Формулы статусных эффектов
```gdscript
# Расчёт урона поджога
func calculate_burn_damage(base_burn_dps: float, perks: Array) -> float:
    var multiplier = 1.0
    
    for perk in perks:
        match perk.id:
            "fire_t2a":  # Заклинатель Огня +50% урона поджога
                multiplier *= 1.50
            "intense_burn":  # Intense Burn +35% (референс)
                multiplier *= 1.35
            "pyro_mage_spec":  # Специализация +105%
                multiplier *= 2.05
    
    return base_burn_dps * multiplier

# Расчёт длительности заморозки
func calculate_freeze_duration(base_duration: float, perks: Array) -> float:
    var multiplier = 1.0
    
    for perk in perks:
        match perk.id:
            "frost_t2b":  # Поджигатель +30% длительности
                multiplier *= 1.30
    
    return base_duration * multiplier

# Расчёт урона молнии
func calculate_lightning_damage(base_damage: float, perks: Array) -> float:
    var flat_bonus = 0.0
    var radius_multiplier = 1.0
    
    for perk in perks:
        match perk.id:
            "thunder_t3":  # Власть Молний +12 урона, +75% радиус
                flat_bonus += 12.0
                radius_multiplier *= 1.75
            "electro_mastery":  # Electro Mastery +12, +75%
                flat_bonus += 12.0
                radius_multiplier *= 1.75
    
    return {
        "damage": base_damage + flat_bonus,
        "radius": base_radius * radius_multiplier
    }
```

---

## 🧠 СИСТЕМА ПРИОРИТЕТОВ ДЛЯ ИИ

### Алгоритм выбора перков
```gdscript
class_name PerkAISystem

# Веса приоритетов для разных ситуаций
var priority_weights = {
    # Базовые веса
    "damage": 1.0,
    "fire_rate": 0.9,
    "speed": 0.7,
    "defense": 0.8,
    "summon": 0.85,
    "utility": 0.6,
    
    # Ситуационные модификаторы
    "low_hp": {"defense": 2.0, "healing": 3.0},
    "high_enemy_count": {"aoe_damage": 1.5, "summon": 1.3},
    "boss_fight": {"damage": 1.4, "defense": 1.2},
    "early_game": {"speed": 1.2, "utility": 1.3}
}

func evaluate_perk(perk: Perk, context: GameContext) -> float:
    """Оценивает перк по шкале 0-100"""
    var score = 0.0
    var weights = get_active_weights(context)
    
    # Оценка по категориям
    score += evaluate_damage(perk, weights) * weights.damage
    score += evaluate_defense(perk, weights) * weights.defense
    score += evaluate_synergy(perk, context) * 1.5  # Синергии важнее
    score += evaluate_progression(perk, context) * 1.2  # Прогрессия важна
    
    return clamp(score, 0.0, 100.0)

func get_active_weights(context: GameContext) -> Dictionary:
    """Получает активные веса в зависимости от ситуации"""
    var weights = priority_weights.duplicate()
    
    # Модификация по ситуации
    if context.player_hp_ratio < 0.3:
        for key in priority_weights.low_hp:
            weights[key] = priority_weights.low_hp[key]
    
    if context.enemy_count > 100:
        for key in priority_weights.high_enemy_count:
            weights[key] = priority_weights.high_enemy_count[key]
    
    if context.is_boss_fight:
        for key in priority_weights.boss_fight:
            weights[key] = priority_weights.boss_fight[key]
    
    if context.time_minutes < 5.0:
        for key in priority_weights.early_game:
            weights[key] = priority_weights.early_game[key]
    
    return weights

func evaluate_damage(perk: Perk, weights: Dictionary) -> float:
    """Оценивает урон от перка"""
    var score = 0.0
    
    match perk.category:
        "bullet_damage":
            score += perk.damage_multiplier * 20.0
            score += perk.flat_damage * 2.0
        "fire_rate":
            score += perk.fire_rate_multiplier * 15.0
        "projectile_count":
            score += perk.projectile_bonus * 10.0
        "piercing":
            score += perk.piercing_bonus * 8.0
    
    return score

func evaluate_defense(perk: Perk, weights: Dictionary) -> float:
    """Оценивает защиту от перка"""
    var score = 0.0
    
    match perk.category:
        "hp":
            score += perk.hp_bonus * 25.0
        "dodge":
            score += perk.dodge_chance * 30.0
        "shield":
            score += 20.0 if perk.has_shield else 0.0
        "damage_reduction":
            score += perk.damage_reduction * 25.0
    
    return score

func evaluate_synergy(perk: Perk, context: GameContext) -> float:
    """Оценивает синергию с текущими перками"""
    var score = 0.0
    
    # Проверяем синергии
    for synergy in available_synergies:
        if synergy.requires_perk(perk.id) and context.has_all_synergy_requirements(synergy):
            score += 30.0  # Большая награда за синергию
    
    # Проверяем завершение дерева
    if context.has_perk(perk.prerequisite):
        score += 15.0  # Награда за прогресс в дереве
    
    return score

func evaluate_progression(perk: Perk, context: GameContext) -> float:
    """Оценивает прогрессия перка"""
    var score = 0.0
    
    # Базовые перки важнее в начале
    if perk.tier == 1 and not context.has_any_perk_in_tree(perk.tree_id):
        score += 20.0
    
    # Улучшения важны если есть база
    if perk.tier > 1 and context.has_perk(perk.prerequisite):
        score += 25.0
    
    # Финальные перки очень важны
    if perk.tier == 3:
        score += 30.0
    
    return score
```

### Таблица приоритетов по ситуациям
```
Ситуация: HP < 30%
├── Приоритет 1: Защита (+200% вес)
├── Приоритет 2: Исцеление (+300% вес)
├── Приоритет 3: Уклонение (+150% вес)
└── Приоритет 4: Урон (базовый вес)

Ситуация: Врагов > 100
├── Приоритет 1: AoE урон (+150% вес)
├── Приоритет 2: Призывы (+130% вес)
├── Приоритет 3: Скорострельность (+120% вес)
└── Приоритет 4: Защита (базовый вес)

Ситуация: Босс-файт
├── Приоритет 1: Одиночный урон (+140% вес)
├── Приоритет 2: Защита (+120% вес)
├── Приоритет 3: Пробитие (+110% вес)
└── Приоритет 4: Скорость (базовый вес)

Ситуация: Первые 5 минут
├── Приоритет 1: Скорость (+120% вес)
├── Приоритет 2: Утилити (+130% вес)
├── Приоритет 3: Базовые перки (+150% вес)
└── Приоритет 4: Синергии (базовый вес)
```

---

## 📋 ТАБЛИЦА ВСЕХ ПЕРКОВ С ПАРАМЕТРАМИ

### Дерево 1: Быстрые Стрелы
```
T1: Скорость пуль +30%
├── ID: "fast_arrows_t1"
├── Category: "bullet_speed"
├── Effect: bullet_speed_multiplier = 1.30
├── AI Priority: 0.7 (speed)
└── Synergy: нет

T2a: Пробитие +1
├── ID: "fast_arrows_t2a"
├── Category: "piercing"
├── Effect: piercing_bonus = 1
├── Prerequisite: "fast_arrows_t1"
├── AI Priority: 0.8 (damage)
└── Synergy: "sniper_build"

T2b: Скорость +15% + урон +15%
├── ID: "fast_arrows_t2b"
├── Category: "mixed"
├── Effect: bullet_speed_multiplier = 1.15, damage_multiplier = 1.15
├── Prerequisite: "fast_arrows_t1"
├── AI Priority: 0.85 (damage + speed)
└── Synergy: "killer_build"

T3a: Снайпер +25% скорости +15% урона
├── ID: "fast_arrows_t3a"
├── Category: "bullet_damage"
├── Effect: bullet_speed_multiplier = 1.25, damage_multiplier = 1.15
├── Prerequisite: "fast_arrows_t2a"
├── AI Priority: 0.9 (damage)
└── Synergy: "sniper_master"

T3b: Убийца (убийство с <20% HP)
├── ID: "fast_arrows_t3b"
├── Category: "executive"
├── Effect: instant_kill_below_20_percent = true
├── Prerequisite: "fast_arrows_t2b"
├── AI Priority: 0.75 (utility)
└── Synergy: "execute_build"
```

### Дерево 2: Урон
```
T1: Урон +40%, отбрасывание +20%
├── ID: "damage_t1"
├── Category: "bullet_damage"
├── Effect: damage_multiplier = 1.40, knockback_multiplier = 1.20
├── AI Priority: 1.0 (damage)
└── Synergy: "heavy_hitter"

T2a: Крупный Калибр +45% урона +40% размера
├── ID: "damage_t2a"
├── Category: "bullet_damage"
├── Effect: damage_multiplier = 1.45, projectile_size_multiplier = 1.40
├── Prerequisite: "damage_t1"
├── AI Priority: 1.0 (damage)
└── Synergy: "tank_build"

T2b: Осколочная Пуля (враги взрываются на 3 пули, 10% урона)
├── ID: "damage_t2b"
├── Category: "aoe"
├── Effect: on_death_explode = true, explosion_count = 3, explosion_damage_ratio = 0.10
├── Prerequisite: "damage_t1"
├── AI Priority: 0.95 (aoe)
└── Synergy: "chain_reaction"

T3: Пули Жнеца (+20% урона, пробитие сквозь)
├── ID: "damage_t3"
├── Category: "bullet_damage"
├── Effect: damage_multiplier = 1.20, infinite_piercing = true
├── Prerequisite: "damage_t2a" OR "damage_t2b"
├── AI Priority: 1.0 (damage)
└── Synergy: "reaper_build"
```

### Дерево 8: Гром (референс 20MTD)
```
T1: Каждый 2-й выстрел → молния 22 урона
├── ID: "thunder_t1"
├── Category: "lightning"
├── Effect: lightning_on_every_2nd_shot = true, lightning_damage = 22.0
├── AI Priority: 0.85 (damage)
├── Trigger: "on_shot", condition: "shot_count % 2 == 0"
└── Synergy: "electro_build"

T2a: Громовой Жук (призыв)
├── ID: "thunder_t2a"
├── Category: "summon"
├── Effect: summon_electro_bug = true, bug_lightning_damage = 22.0, bug_targets = 2
├── Prerequisite: "thunder_t1"
├── AI Priority: 0.9 (summon + damage)
└── Synergy: "summon_master"

T2b: Заряженный (20% шанс восполнить 3 патрона при ударе молнии)
├── ID: "thunder_t2b"
├── Category: "utility"
├── Effect: on_lightning_hit_ammo_restore_chance = 0.20, ammo_restore_amount = 3
├── Prerequisite: "thunder_t1"
├── AI Priority: 0.7 (utility)
└── Synergy: "generator_build"

T3: Власть Молний +12 к урону молнии, +75% радиус
├── ID: "thunder_t3"
├── Category: "lightning"
├── Effect: lightning_damage_bonus = 12.0, lightning_radius_multiplier = 1.75
├── Prerequisite: "thunder_t2a" OR "thunder_t2b"
├── AI Priority: 0.95 (damage + aoe)
└── Synergy: "lightning_master"
```

### Дерево 9: Пламя (референс 20MTD)
```
T1: 5-й выстрел → огненный шар (3 дпс поджог)
├── ID: "fire_t1"
├── Category: "fire"
├── Effect: fireball_on_every_5th_shot = true, fireball_damage = 40.0, burn_dps = 3.0, burn_duration = 3.0
├── AI Priority: 0.85 (damage + aoe)
├── Trigger: "on_shot", condition: "shot_count % 5 == 0"
└── Synergy: "pyro_build"

T2a: Заклинатель Огня +50% урона поджога
├── ID: "fire_t2a"
├── Category: "fire"
├── Effect: burn_damage_multiplier = 1.50
├── Prerequisite: "fire_t1"
├── AI Priority: 0.9 (damage over time)
└── Synergy: "burn_master"

T2b: Поджигатель (поджог +30% длительности)
├── ID: "fire_t2b"
├── Category: "fire"
├── Effect: burn_duration_multiplier = 1.30
├── Prerequisite: "fire_t1"
├── AI Priority: 0.85 (damage over time)
└── Synergy: "inferno_build"

T3: Инферно (поджоги взрываются)
├── ID: "fire_t3"
├── Category: "fire_aoe"
├── Effect: burn_explodes_on_death = true, explosion_damage = burn_total_damage, explosion_radius = 48.0
├── Prerequisite: "fire_t2a" OR "fire_t2b"
├── AI Priority: 1.0 (aoe damage)
└── Synergy: "inferno_master"
```

### Дерево 14: Щит (референс 20MTD)
```
T1: Небесный Щит (блокирует 1 атаку, восстановление 120с)
├── ID: "shield_t1"
├── Category: "defense"
├── Effect: holy_shield = true, shield_blocks = 1, shield_regen_time = 120.0
├── AI Priority: 0.9 (defense)
├── State: "shield_active", "shield_broken", "shield_regen"
└── Synergy: "shield_build"

T2a: Божественное Благословение (+25% перезарядки и скорости при активном щите)
├── ID: "shield_t2a"
├── Category: "defense_buff"
├── Effect: while_shield_active_reload_multiplier = 1.25, while_shield_active_speed_multiplier = 1.25
├── Prerequisite: "shield_t1"
├── AI Priority: 0.85 (defense + utility)
└── Synergy: "divine_build"

T2b: Несгибаемая Воля (при HP ≤ 50%: +2 пробития, +25% отбрасывания)
├── ID: "shield_t2b"
├── Category: "defense_offense"
├── Effect: when_hp_below_50_percent_piercing_bonus = 2, when_hp_below_50_percent_knockback_multiplier = 1.25
├── Prerequisite: "shield_t1"
├── AI Priority: 0.8 (defense + damage)
├── Trigger: "on_hp_change", condition: "hp_ratio <= 0.5"
└── Synergy: "stalwart_build"

T3: Меч и Щит (убийства карой снижают время восстановления щита)
├── ID: "shield_t3"
├── Category: "defense_utility"
├── Effect: on_smite_kill_reduce_regen_time = 1.0  # секунды
├── Prerequisite: "shield_t2a" OR "shield_t2b"
├── AI Priority: 0.85 (defense utility)
├── Trigger: "on_enemy_killed", condition: "killed_by_smite"
└── Synergy: "paladin_build"
```

### Дерево 16: Душа ⚠️ С МЕЖДРЕВЕСНОЙ ЗАВИСИМОСТЬЮ
```
T1: Душа (дропается с редких врагов, +1 HP перманентно)
├── ID: "soul_t1"
├── Category: "soul_collection"
├── Effect: soul_drop_from_rare_enemies = true, soul_grants_max_hp = 1
├── AI Priority: 0.75 (defense + utility)
└── Synergy: "soul_build"

T2a: Сбор душ (+25% шанс дропа)
├── ID: "soul_t2a"
├── Category: "soul_collection"
├── Effect: soul_drop_chance_bonus = 0.25
├── Prerequisite: "soul_t1"
├── AI Priority: 0.8 (utility)
└── Synergy: "soul_collector"

T2b: Конвертация душ (через 60 сек душа → макс. HP)
├── ID: "soul_t2b"
├── Category: "soul_utility"
├── Effect: soul_convert_to_max_hp_after_60_sec = true
├── Prerequisite: "soul_t1"
├── AI Priority: 0.75 (defense)
└── Synergy: "soul_converter"

T3: Душа-рыцарь (+15 урона призывов за каждую собранную душу)
├── ID: "soul_t3"
├── Category: "soul_summon"
├── Effect: summon_damage_bonus_per_soul = 15.0
├── Prerequisite: ("soul_t2a" OR "soul_t2b") AND "has_any_summon_perk"
├── Cross-tree requirement: "summon_t1" OR "summon_t2a" OR "summon_t2b" OR "summon_t3"
├── AI Priority: 0.9 (summon damage)
└── Synergy: "soul_knight"
```

### Дерево 24: Святое Копьё ⚠️ С МЕЖДРЕВЕСНОЙ ЗАВИСИМОСТЬЮ
```
T1: Святое Копьё (призыв, преследует)
├── ID: "holy_spear_t1"
├── Category: "summon"
├── Effect: summon_holy_spear = true, spear_damage = 30.0, spear_pursues_target = true
├── AI Priority: 0.85 (summon)
└── Synergy: "holy_build"

T2a: Рыцарь Копья (+15 урона за каждую душу)
├── ID: "holy_spear_t2a"
├── Category: "summon_damage"
├── Effect: spear_damage_bonus_per_soul = 15.0
├── Prerequisite: "holy_spear_t1" AND "soul_t1"  # ⚠️ ТРЕБУЕТ ДУШУ!
├── Cross-tree requirement: "soul_t1"
├── AI Priority: 0.9 (summon damage)
└── Synergy: "spear_knight"

T2b: Мастер Копья (+40% урона)
├── ID: "holy_spear_t2b"
├── Category: "summon_damage"
├── Effect: spear_damage_multiplier = 1.40
├── Prerequisite: "holy_spear_t1"
├── AI Priority: 0.85 (summon damage)
└── Synergy: "spear_master"

T3: Святые Копья (+3 копья)
├── ID: "holy_spear_t3"
├── Category: "summon_count"
├── Effect: additional_spear_count = 3
├── Prerequisite: "holy_spear_t2a" OR "holy_spear_t2b"
├── AI Priority: 1.0 (summon count)
└── Synergy: "holy_lance"
```

---

## 🎯 ТАБЛИЦА СПЕЦИАЛИЗАЦИЙ (20MTD РЕФЕРЕНС)

```
Специализация: Frost Mage (Эльф + Мороз)
├── ID: "spec_frost_mage"
├── Character: "elf"
├── Requires: "frost_t1"
├── Effect: freeze_chance = 0.73  # с 35% до 73%
├── Formula: base_chance * 2.08 + 0.03
└── AI Priority: 1.0

Специализация: Frostbite (Эльф + Мороз T2)
├── ID: "spec_frostbite"
├── Character: "elf"
├── Requires: "frost_t2a" OR "frost_t2b"
├── Effect: on_freeze_enemy_lose_max_hp_percent = 0.45
├── Elite boss effect: lose_max_hp_percent = 0.03
├── AI Priority: 1.0

Специализация: Fusillade (Шана + Шквальный Огонь)
├── ID: "spec_fusillade"
├── Character: "shana"
├── Requires: "volley_t3"
├── Effect: projectile_count_bonus = 3, spread_bonus = 45, bullet_damage_bonus = -0.58
├── Formula: base_projectile_count * 8
├── AI Priority: 0.95

Специализация: Generator (Вольтра + Заряженный)
├── ID: "spec_generator"
├── Character: "inventor"
├── Requires: "thunder_t2b"
├── Effect: on_ammo_gain_fire_rate_multiplier = 2.05, duration = 2.0
├── AI Priority: 0.9

Специализация: Ghost Friend (Некромант + Призрак)
├── ID: "spec_ghost_friend"
├── Character: "necromancer"
├── Requires: "ghost_t1"
├── Effect: ghost_count = 3  # вместо 1
├── AI Priority: 1.0

Специализация: Giant (Паладин + Исполин)
├── ID: "spec_giant"
├── Character: "paladin"
├── Requires: "health_t2b"
├── Effect: max_hp_bonus = 6, character_size_multiplier = 2.5
├── AI Priority: 0.85

Специализация: Glare (Маг + Зрение)
├── ID: "spec_glare"
├── Character: "mage"
├── Requires: "vision_t2b"
├── Effect: vision_range_multiplier = 1.25, damage_to_enemies_in_vision = 45.0, damage_interval = 1.0
├── AI Priority: 0.9

Специализация: Gun Mastery (Снайпер + Мастерство Оружия)
├── ID: "spec_gun_mastery"
├── Character: "sniper"
├── Requires: "synergy_gun_mastery"
├── Effect: bullet_damage_multiplier = 1.45, fire_rate_multiplier = 1.45, reload_multiplier = 1.45, max_ammo_bonus = 3, piercing_bonus = 3
├── AI Priority: 1.0

Специализация: Haste (Орк + Скорость)
├── ID: "spec_haste"
├── Character: "orc"
├── Requires: "speed_t2a"
├── Effect: move_speed_multiplier = 1.60, fire_rate_multiplier = 1.15
├── AI Priority: 0.95

Специализация: Holy Arts (Паладин + Светлая Магия)
├── ID: "spec_holy_arts"
├── Character: "paladin"
├── Requires: "light_magic_t1"
├── Effect: smite_all_enemies_in_vision_3_times = true, smite_damage = 20.0
├── AI Priority: 1.0

Специализация: Holy Might (Паладин + Священная Мощь)
├── ID: "spec_holy_might"
├── Character: "paladin"
├── Requires: "light_magic_t2a"
├── Effect: smite_damage_per_current_hp = 30.0
├── Formula: current_hp * 30.0
├── AI Priority: 1.0

Специализация: Ice Shard (Эльф + Ледяной Осколок)
├── ID: "spec_ice_shard"
├── Character: "elf"
├── Requires: "frost_t2b"
├── Effect: additional_ice_shard_count = 9  # всего 12 вместо 3
├── AI Priority: 0.95

Специализация: Intense Burn (Пиромант + Поджог)
├── ID: "spec_intense_burn"
├── Character: "pyromaniac"
├── Requires: "fire_t2a"
├── Effect: burn_damage_multiplier = 2.05  # +105%
├── AI Priority: 0.95

Специализация: Justice (Паладин + Правосудие)
├── ID: "spec_justice"
├── Character: "paladin"
├── Requires: "light_magic_t2b"
├── Effect: max_hp_bonus_per_500_smite_kills = 3
├── AI Priority: 0.85

Специализация: Kill Clip (Снайпер + Кровавый Магазин)
├── ID: "spec_kill_clip"
├── Character: "sniper"
├── Requires: "reload_t3"
├── Effect: reload_rate_bonus_per_kill = 0.15, resets_after_reload = true
├── AI Priority: 0.9

Специализация: Kunoichi (Рог + Тень)
├── ID: "spec_kunoichi"
├── Character: "rogue"
├── Requires: "shadow_t2b"
├── Effect: fire_rate_bonus = 0.30, piercing_bonus = 3, duration = 10.0, resets_on_hit = true
├── AI Priority: 0.95
```

---

## 💻 РЕАЛИЗАЦИЯ В GODOT

### Структура данных перка
```gdscript
class_name Perk extends Resource

# Базовая информация
@export var id: String
@export var name: String
@export var description: String
@export var icon: Texture2D

# Иерархия
@export var tree_id: String
@export var tier: int  # 1, 2, 3
@export var branch: String  # "a" or "b" для T2
@export var prerequisite: String  # ID требуемого перка

# Категории
@export var category: String  # "damage", "defense", "utility", etc.
@export var ai_priority: float  # 0.0 - 1.0

# Эффекты
@export var effects: Dictionary  # Все эффекты перка

# Зависимости
@export var cross_tree_requirements: Array[String]  # Перки из других деревьев
@export var synergy_requirements: Array[String]  # Для синергий

# Специализация
@export var is_specialize: bool = false
@export var specialize_character: String = ""
@export var specialize_multiplier: int = 3  # x3 для обычного, другое для бесконечного

func apply_to_player(player: Player):
    """Применяет эффекты перка к игроку"""
    for effect_key in effects:
        var effect_value = effects[effect_key]
        
        match effect_key:
            "damage_multiplier":
                player.damage_multiplier *= effect_value
            "fire_rate_multiplier":
                player.fire_rate_multiplier *= effect_value
            "move_speed_multiplier":
                player.move_speed_multiplier *= effect_value
            "piercing_bonus":
                player.piercing += effect_value
            "projectile_count_bonus":
                player.projectile_count += effect_value
            "max_hp_bonus":
                player.max_hp += effect_value
                player.current_hp += effect_value
            # ... и так далее для всех эффектов
```

### Система проверки зависимостей
```gdscript
class_name PerkDependencyChecker extends Node

var player_perks: Array[Perk] = []

func can_show_perk(perk: Perk) -> bool:
    """Проверяет, можно ли показать перк в селекторе"""
    
    # Проверяем базовый prerequisite
    if perk.prerequisite != "":
        if not has_perk(perk.prerequisite):
            return false
    
    # Проверяем междревесные зависимости
    for req in perk.cross_tree_requirements:
        if not has_perk(req):
            return false
    
    # Специальная проверка для T2 (нужен T1)
    if perk.tier == 2:
        if not has_perk_in_tree(perk.tree_id, 1):
            return false
    
    # Специальная проверка для T3 (нужен T2a или T2b)
    if perk.tier == 3:
        if not (has_perk_in_tree(perk.tree_id, 2)):
            return false
    
    return true

func has_perk(perk_id: String) -> bool:
    """Проверяет, есть ли у игрока этот перк"""
    for perk in player_perks:
        if perk.id == perk_id:
            return true
    return false

func has_perk_in_tree(tree_id: String, tier: int) -> bool:
    """Проверяет, есть ли у игрока перк из дерева определённого уровня"""
    for perk in player_perks:
        if perk.tree_id == tree_id and perk.tier == tier:
            return true
    return false

func get_available_perks(all_perks: Array[Perk]) -> Array[Perk]:
    """Возвращает список доступных перков"""
    var available: Array[Perk] = []
    
    for perk in all_perks:
        if can_show_perk(perk):
            available.append(perk)
    
    return available
```

---

## 📊 СВОДНАЯ ТАБЛИЦА ДЛЯ БАЛАНСИРОВКИ

| Параметр | Минимум | Норма | Максимум | Комментарий |
|----------|---------|-------|----------|-------------|
| Урон множитель | ×1.0 | ×2.5 | ×5.0 | Сумма всех перков урона |
| Скорострельность | ×1.0 | ×2.0 | ×3.5 | Сумма всех перков скорости |
| Скорость движения | ×1.0 | ×1.5 | ×2.0 | Сумма всех перков скорости |
| Пробитие | 0 | 3 | 10 | Максимум для баланса |
| Кол-во снарядов | 1 | 3 | 8 | Осторожно с балансом |
| HP | 3 | 7 | 15 | Зависит от персонажа |
| Уклонение | 0% | 25% | 75% | Кап 75% |
| Урон призывов | ×1.0 | ×2.5 | ×4.0 | Сумма всех перков |

---

*Документ содержит полную техническую информацию о работе перков, формулах расчёта, приоритетах ИИ и параметрах для балансировки.*

**Версия: 1.0.0**
**Референс: 20 Minutes Till Dawn + адаптация для Surwave**
