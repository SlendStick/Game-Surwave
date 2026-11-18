extends Node
## DB — загрузка всех данных игры из res://data/*.json и индексы для быстрого доступа.
## Все числовые параметры живут в JSON, код только читает их.

var balance: Dictionary = {}
var characters: Array = []
var weapons: Array = []
var perk_trees: Array = []
var perks: Array = []
var synergies: Array = []
var seals: Array = []
var amulets: Array = []
var amulet_costs: Array = []
var darkness: Array = []
var enemies: Array = []
var bosses: Dictionary = {}
var sathan: Dictionary = {}
var maps: Array = []
var waves: Dictionary = {}

var char_by_id: Dictionary = {}
var weapon_by_id: Dictionary = {}
var perk_by_id: Dictionary = {}
var enemy_by_id: Dictionary = {}
var map_by_id: Dictionary = {}
var amulet_by_id: Dictionary = {}
var seal_by_id: Dictionary = {}
var tree_by_id: Dictionary = {}
var specializations: Array = []          # сгенерированные специализации персонажей
var spec_by_id: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DB: файл не найден " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("DB: не удалось разобрать " + path)
	return parsed

func _index(arr: Array, id_key: String = "id") -> Dictionary:
	var d: Dictionary = {}
	for item in arr:
		if item is Dictionary and item.has(id_key):
			d[String(item[id_key])] = item
	return d

func _load_all() -> void:
	balance = _load_json("res://data/balance.json")
	characters = _load_json("res://data/characters.json")
	weapons = _load_json("res://data/weapons.json")
	var perks_data: Dictionary = _load_json("res://data/perks.json")
	perk_trees = perks_data.get("trees", [])
	perks = perks_data.get("perks", [])
	synergies = _load_json("res://data/synergies.json")
	seals = _load_json("res://data/seals.json")
	var amu: Dictionary = _load_json("res://data/amulets.json")
	amulets = amu.get("amulets", [])
	amulet_costs = amu.get("costs", [])
	darkness = _load_json("res://data/darkness.json")
	enemies = _load_json("res://data/enemies.json")
	var bd: Dictionary = _load_json("res://data/bosses.json")
	bosses = bd.get("bosses", {})
	sathan = bd.get("sathan", {})
	maps = _load_json("res://data/maps.json")
	waves = _load_json("res://data/waves.json")

	char_by_id = _index(characters)
	weapon_by_id = _index(weapons)
	perk_by_id = _index(perks)
	enemy_by_id = _index(enemies)
	map_by_id = _index(maps)
	amulet_by_id = _index(amulets)
	seal_by_id = _index(seals)
	tree_by_id = _index(perk_trees)
	_build_specializations()

## Специализации: уникальные мастерства по каждому перку для каждого персонажа.
## Каждая специализация даёт мгновенный эффект своего перка + усиление ×3 следующему перку.
func _build_specializations() -> void:
	specializations.clear()
	spec_by_id.clear()
	const TREE_FALLBACK_MODS := {
		"fast_arrows": {"proj_speed": 0.25, "crit": 0.08},
		"damage": {"dmg": 0.30},
		"fire_rate": {"fire_rate": 0.22},
		"multishot": {"proj": 1, "fire_rate": 0.10},
		"reload": {"reload": 0.20, "mag": 1},
		"proj_speed": {"proj_speed": 0.25, "crit": 0.08},
		"pierce": {"pierce": 1, "proj_speed": 0.15},
		"thunder": {"shock_dmg": 10.0, "fire_rate": 0.12},
		"flame": {"burn_mult": 0.35, "dmg": 0.14},
		"frost": {"freeze_chance": 0.22, "dmg": 0.12},
		"dark": {"curse_chance": 0.25, "dmg": 0.14},
		"light": {"dmg": 0.20, "hp": 1},
		"health": {"hp": 1, "dmg": 0.14},
		"shield": {"hp": 1, "reload": 0.15},
		"dodge": {"dodge": 0.10, "move_speed": 0.10},
		"soul": {"summon_dmg": 0.25, "pickup": 0.25},
		"pickup": {"pickup": 0.35, "vision": 0.18},
		"move": {"move_speed": 0.18, "dodge": 0.06},
		"vision": {"vision": 0.35, "crit": 0.08},
		"wind": {"move_speed": 0.14, "fire_rate": 0.14},
		"summon": {"summon_dmg": 0.35, "summon_speed": 0.20},
		"dragon": {"summon_dmg": 0.35, "burn_mult": 0.25},
		"scythe": {"summon_dmg": 0.35, "summon_speed": 0.25},
		"boomerang": {"summon_dmg": 0.35, "pierce": 1},
		"beast": {"summon_dmg": 0.30, "summon_speed": 0.20},
	}
	for ch in characters:
		var cid := String(ch.get("id", ""))
		for perk in perks:
			var pid := String(perk.get("id", ""))
			var tree_id := String(perk.get("tree", ""))
			var tree_name := String(tree_by_id.get(tree_id, {}).get("name", tree_id))
			var tier := int(perk.get("tier", 1))
			var p_mods: Dictionary = perk.get("mods", {})
			var p_flags: Dictionary = perk.get("flags", {})
			var spec_mods: Dictionary = {}
			if not p_mods.is_empty():
				for k in p_mods.keys():
					var v := float(p_mods[k])
					if k in ["hp", "mag", "proj", "pierce", "bounce", "summon_count"]:
						var iv := int(round(v * 1.5))
						if iv == 0 and v > 0.0:
							iv = 1
						spec_mods[k] = iv
					else:
						spec_mods[k] = snappedf(v * 1.5, 0.01)
			else:
				spec_mods = (TREE_FALLBACK_MODS.get(tree_id, {"dmg": 0.20}) as Dictionary).duplicate(true)
			var p_desc := String(perk.get("desc", "")).strip_edges()
			var spec := {
				"id": "spec_%s_%s" % [cid, pid],
				"name": "Спец: " + String(perk.get("name", "")),
				"char": cid,
				"perk_id": pid,
				"tree": tree_id,
				"tree_name": tree_name,
				"tier": tier,
				"mods": spec_mods,
				"flags": p_flags.duplicate(true),
				"desc": "%s · %s (×1.5) и ×3 следующему перку." % [tree_name, p_desc.trim_suffix(".")],
				"kind": "specialization",
			}
			specializations.append(spec)
			spec_by_id[spec["id"]] = spec

func character(id: String) -> Dictionary:
	if char_by_id.has(id):
		return char_by_id[id]
	return char_by_id.values()[0] if not char_by_id.is_empty() else {}

func weapon(id: String) -> Dictionary:
	if weapon_by_id.has(id):
		return weapon_by_id[id]
	return weapon_by_id.values()[0] if not weapon_by_id.is_empty() else {}

func perk(id: String) -> Dictionary:
	return perk_by_id.get(id, {})

func enemy(id: String) -> Dictionary:
	return enemy_by_id.get(id, {})

func map(id: String) -> Dictionary:
	if map_by_id.has(id):
		return map_by_id[id]
	return maps[0] if not maps.is_empty() else {}

func boss(map_id: String) -> Dictionary:
	var bkey := String(map_by_id.get(map_id, {}).get("boss", ""))
	return bosses.get(bkey, {})

func miniboss_of(map_id: String) -> Dictionary:
	var m := map(map_id)
	var roster: Dictionary = m.get("roster", {})
	return enemy(String(roster.get("miniboss", "")))

## Единая проверка зависимостей. Помимо req/req_any учитывает междревесные
## требования и взаимоисключающие ветви T2a/T2b.
func can_take_perk(perk: Dictionary, taken: Dictionary, endless: bool = false) -> bool:
	var pid := String(perk.get("id", ""))
	var stacks := int(taken.get(pid, 0))
	var max_stacks := 4 if endless else int(perk.get("max_stacks", 1))
	if stacks >= max_stacks:
		return false
	for r in perk.get("req", []):
		if int(taken.get(String(r), 0)) <= 0:
			return false
	var req_any: Array = perk.get("req_any", [])
	if not req_any.is_empty():
		var any_ok := false
		for r in req_any:
			if int(taken.get(String(r), 0)) > 0:
				any_ok = true
				break
		if not any_ok:
			return false
	# Каждое имя здесь — отдельная обязательная группа: в указанном дереве
	# должен быть хотя бы один уже взятый перк.
	for tree_id in perk.get("req_tree_any", []):
		var tree_ok := false
		for taken_id in taken.keys():
			if int(taken.get(taken_id, 0)) <= 0:
				continue
			var owned: Dictionary = perk_by_id.get(String(taken_id), {})
			if String(owned.get("tree", "")) == String(tree_id):
				tree_ok = true
				break
		if not tree_ok:
			return false
	# После выбора направления второе улучшение того же tier 2 блокируется.
	# В endless можно повторять выбранную ветвь, но нельзя открыть противоположную.
	if int(perk.get("tier", 0)) == 2 and String(perk.get("branch", "")) != "":
		for taken_id in taken.keys():
			if int(taken.get(taken_id, 0)) <= 0 or String(taken_id) == pid:
				continue
			var owned: Dictionary = perk_by_id.get(String(taken_id), {})
			if String(owned.get("tree", "")) == String(perk.get("tree", "")) and int(owned.get("tier", 0)) == 2:
				return false
	return true

## Пул перков, доступных с учётом дерева (T1 -> T2a/T2b -> T3).
func available_perks(taken: Dictionary, endless: bool = false) -> Array:
	var out: Array = []
	for perk in perks:
		if can_take_perk(perk, taken, endless):
			out.append(perk)
	return out

func mode_config(mode_id: String) -> Dictionary:
	return balance.get("modes", {}).get(mode_id, {})
