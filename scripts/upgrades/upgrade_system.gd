class_name UpgradeSystem
## Прокачка в забеге: перки деревьев, синергии, специализации, уникальные апгрейды
## персонажа, древние печати, эволюции оружия. Здесь только учёт и подсчёт модификаторов.

var add: Dictionary = {}          # аддитивные модификаторы (проценты как 0.4 = +40%)
var flags: Dictionary = {}        # спец. эффекты
var taken: Dictionary = {}        # perk_id -> стаки
var taken_synergies: Array = []
var taken_seals: Array = []
var taken_char_upgrades: Array = []
var weapon_evolution: Dictionary = {}
var evolution_done := false
var specialization_pending := 0   # сколько раз следующий перк получает x3
var spec_mult := 3.0
var endless := false
var choice_count := 5
var log: Array = []
var _extra_ops: Array = []
var _card_records: Array = []
var _replaying := false

# модификаторы, которые являются целыми (прибавка, а не процент)
const INT_MODS := ["hp", "mag", "proj", "pierce", "bounce", "summon_count"]
# Основные процентные множители из технического ТЗ складываются не линейно:
# +40% и +45% дают x1.40*x1.45, а не x1.85.
const MULT_MODS := ["dmg", "fire_rate", "proj_speed", "reload", "move_speed", "move_speed_mult", "pickup", "vision", "knockback", "size", "summon_dmg", "summon_speed", "xp"]

func reset() -> void:
	add.clear()
	flags.clear()
	taken.clear()
	taken_synergies.clear()
	taken_seals.clear()
	taken_char_upgrades.clear()
	weapon_evolution.clear()
	evolution_done = false
	specialization_pending = 0
	log.clear()
	_extra_ops.clear()
	_card_records.clear()

# ------------------------------------------------------------------ утилиты
func mod(key: String, def: float = 0.0) -> float:
	return float(add.get(key, def))

func flag(key: String, def: Variant = false) -> Variant:
	return flags.get(key, def)

func flag_on(key: String) -> bool:
	var v: Variant = flags.get(key, false)
	if v is bool:
		return v
	if v is float or v is int:
		return float(v) != 0.0
	return v != null

func flag_num(key: String, def: float = 0.0) -> float:
	var v: Variant = flags.get(key, def)
	if v is float or v is int:
		return float(v)
	return def

func flag_list(key: String) -> Array:
	var v: Variant = flags.get(key, [])
	if v is Array:
		return v
	if v is String and v != "":
		return [v]
	return []

func apply_mods(mods: Dictionary, mult: float = 1.0) -> void:
	if not _replaying and not mods.is_empty():
		_extra_ops.append({"op": "mods", "mods": mods.duplicate(true), "mult": mult})
	for key in mods.keys():
		var value := float(mods[key]) * mult
		if INT_MODS.has(key):
			value = round(value)
		if MULT_MODS.has(key):
			var current := float(add.get(key, 0.0))
			add[key] = (1.0 + current) * (1.0 + value) - 1.0
		else:
			add[key] = float(add.get(key, 0.0)) + value

func apply_flags(new_flags: Dictionary) -> void:
	if not _replaying and not new_flags.is_empty():
		_extra_ops.append({"op": "flags", "flags": new_flags.duplicate(true)})
	for key in new_flags.keys():
		var value: Variant = new_flags[key]
		if not flags.has(key):
			flags[key] = value
			continue
		var current: Variant = flags[key]
		if value is bool:
			flags[key] = (current if current is bool else false) or value
		elif value is float or value is int:
			if current is Array:
				continue
			var cur_num := float(current) if (current is float or current is int) else 0.0
			flags[key] = cur_num + float(value)
		elif value is String:
			if current is String:
				if String(current) != String(value):
					flags[key] = [current, value]
			elif current is Array:
				var arr: Array = current
				if not arr.has(value):
					arr.append(value)
				flags[key] = arr
			else:
				flags[key] = value
		elif value is Array:
			var arr2: Array = current if current is Array else [current]
			for item in value:
				if not arr2.has(item):
					arr2.append(item)
			flags[key] = arr2
		else:
			flags[key] = value

# ------------------------------------------------------------------ ВЫБОР УЛУЧШЕНИЙ
func _available_synergy_cards() -> Array:
	var result: Array = []
	for syn in DB.synergies:
		var sid := String(syn["id"])
		if taken_synergies.has(sid):
			continue
		var ok := true
		for req in syn.get("requires", []):
			if int(taken.get(String(req), 0)) <= 0:
				ok = false
				break
		if ok:
			result.append({"kind": "synergy", "id": sid, "data": syn, "weight": 1.0})
	return result

## Перки при повышении уровня: синергия занимает не более одной позиции и,
## если её полные условия выполнены, получает ровно 30% шанс появления.
func perk_choices(count: int) -> Array:
	var pool: Array = DB.available_perks(taken, endless)
	var normal: Array = []
	for perk in pool:
		normal.append({"kind": "perk", "id": String(perk["id"]), "data": perk, "weight": 1.0})
	var picked: Array = []
	var synergy_cards := _available_synergy_cards()
	if not synergy_cards.is_empty() and randf() < 0.30 and count > 0:
		picked.append(synergy_cards.pick_random())
	picked.append_array(_weighted_pick(normal, count - picked.size()))
	return picked

func _weighted_pick(cards: Array, count: int) -> Array:
	var out: Array = []
	var remaining := cards.duplicate()
	while out.size() < count and not remaining.is_empty():
		var total := 0.0
		for c in remaining:
			total += maxf(float(c.get("weight", 1.0)), 0.01)
		var roll := randf() * total
		var idx := 0
		var acc := 0.0
		for i in remaining.size():
			acc += maxf(float(remaining[i].get("weight", 1.0)), 0.01)
			if roll <= acc:
				idx = i
				break
		var card: Dictionary = remaining[idx]
		remaining.remove_at(idx)
		if String(card.get("kind", "")) == "spec_note":
			continue
		out.append(card)
	# если пул меньше нужного — добиваем шансами синергий (не дублируем)
	return out

## Сундук элиты: уникальные апгрейды персонажа + обычные перки.
func elite_choices(char_id: String, count: int = 4) -> Array:
	var cards: Array = []
	var ch := DB.character(char_id)
	for up in ch.get("upgrades", []):
		if taken_char_upgrades.has(String(up["id"])):
			continue
		cards.append({"kind": "char_upgrade", "id": String(up["id"]), "data": up, "weight": 2.5})
	var perks_pool := DB.available_perks(taken, endless)
	for perk in perks_pool:
		cards.append({"kind": "perk", "id": String(perk["id"]), "data": perk, "weight": 1.0})
	var picked: Array = []
	var synergy_cards := _available_synergy_cards()
	if not synergy_cards.is_empty() and randf() < 0.30 and count > 0:
		picked.append(synergy_cards.pick_random())
	picked.append_array(_weighted_pick(cards, count - picked.size()))
	return picked

## Специализации персонажа (уникальный дар ветки + x3 следующему перку).
func spec_choices(char_id: String, count: int = 3) -> Array:
	var pool: Array = []
	for spec in DB.specializations:
		if String(spec.get("char", "")) == char_id:
			pool.append(spec)
	pool.shuffle()
	var cards: Array = []
	var used_trees: Dictionary = {}
	for spec in pool:
		if cards.size() >= count:
			break
		var tree_id := String(spec.get("tree", ""))
		if tree_id != "" and used_trees.has(tree_id):
			continue
		used_trees[tree_id] = true
		cards.append({"kind": "specialization", "id": String(spec["id"]), "data": spec, "weight": 1.0})
	if cards.size() < count:
		for spec in pool:
			if cards.size() >= count:
				break
			var sid := String(spec["id"])
			var dup := false
			for c in cards:
				if String(c["id"]) == sid:
					dup = true
					break
			if not dup:
				cards.append({"kind": "specialization", "id": sid, "data": spec, "weight": 1.0})
	return cards

## Древние печати (с боссов): выбор 1 из 3.
func seal_choices(count: int = 3) -> Array:
	var pool: Array = []
	for seal in DB.seals:
		if taken_seals.has(String(seal["id"])):
			continue
		pool.append({"kind": "seal", "id": String(seal["id"]), "data": seal, "weight": 1.0})
	return _weighted_pick(pool, count)

## Эволюции оружия (выбор на 20 уровне).
func evolution_choices(weapon: Dictionary) -> Array:
	var cards: Array = []
	if weapon.has("evolution"):
		var single: Dictionary = weapon["evolution"]
		cards.append({"kind": "evolution", "id": String(single.get("id", "")), "data": single, "weight": 1.0})
		return cards
	for evo in weapon.get("evolutions", []):
		cards.append({"kind": "evolution", "id": String(evo["id"]), "data": evo, "weight": 1.0})
	return cards

# ------------------------------------------------------------------ ПРИМЕНЕНИЕ
func take_card(card: Dictionary) -> String:
	var kind := String(card.get("kind", ""))
	var data: Dictionary = card.get("data", {})
	var id := String(card.get("id", ""))
	_replaying = true
	match kind:
		"perk":
			if not bool(card.get("force", false)) and not DB.can_take_perk(data, taken, endless):
				_replaying = false
				push_warning("Заблокирована недоступная карточка перка: %s" % id)
				return "blocked"
			var mult := spec_mult if specialization_pending > 0 else 1.0
			if specialization_pending > 0:
				specialization_pending -= 1
			taken[id] = int(taken.get(id, 0)) + 1
			apply_mods(data.get("mods", {}), mult)
			apply_flags(data.get("flags", {}))
			log.append({"kind": kind, "id": id, "mult": mult})
			_card_records.append(card.duplicate(true))
		"char_upgrade":
			taken_char_upgrades.append(id)
			apply_mods(data.get("mods", {}))
			apply_flags(data.get("flags", {}))
			log.append({"kind": kind, "id": id})
			_card_records.append(card.duplicate(true))
		"synergy":
			taken_synergies.append(id)
			apply_mods(data.get("mods", {}))
			apply_flags(data.get("flags", {}))
			EventBus.synergy_unlocked.emit(id)
			log.append({"kind": kind, "id": id})
			_card_records.append(card.duplicate(true))
		"specialization":
			apply_mods(data.get("mods", {}))
			apply_flags(data.get("flags", {}))
			specialization_pending += 1
			log.append({"kind": kind, "id": id, "perk_id": String(data.get("perk_id", ""))})
			_card_records.append(card.duplicate(true))
		"seal":
			taken_seals.append(id)
			apply_mods(data.get("mods", {}))
			apply_flags(data.get("flags", {}))
			log.append({"kind": kind, "id": id})
			_card_records.append(card.duplicate(true))
		"evolution":
			weapon_evolution = data
			evolution_done = true
			apply_mods(data.get("mods", {}))
			apply_flags(data.get("flags", {}))
			log.append({"kind": kind, "id": id})
			_card_records.append(card.duplicate(true))
	_replaying = false
	EventBus.upgrade_picked.emit(id, kind)
	return kind

## Убирает 1 стак приобретённого перка и точно пересчитывает все модификаторы/флаги.
func remove_perk(perk_id: String) -> bool:
	if int(taken.get(perk_id, 0)) <= 0:
		return false
	var remove_idx := -1
	for i in range(_card_records.size() - 1, -1, -1):
		var rec: Dictionary = _card_records[i]
		if String(rec.get("kind", "")) == "perk" and String(rec.get("id", "")) == perk_id:
			remove_idx = i
			break
	if remove_idx < 0:
		return false
	_card_records.remove_at(remove_idx)
	var saved_extra := _extra_ops.duplicate(true)
	var saved_cards := _card_records.duplicate(true)
	reset()
	_extra_ops = saved_extra
	_replaying = true
	for op in _extra_ops:
		if String(op.get("op", "")) == "mods":
			apply_mods(op.get("mods", {}), float(op.get("mult", 1.0)))
		elif String(op.get("op", "")) == "flags":
			apply_flags(op.get("flags", {}))
	for rec in saved_cards:
		var c: Dictionary = (rec as Dictionary).duplicate(true)
		if String(c.get("kind", "")) == "perk":
			c["force"] = true
		var kind := String(c.get("kind", ""))
		var data: Dictionary = c.get("data", {})
		var id := String(c.get("id", ""))
		match kind:
			"perk":
				var mult := spec_mult if specialization_pending > 0 else 1.0
				if specialization_pending > 0:
					specialization_pending -= 1
				taken[id] = int(taken.get(id, 0)) + 1
				apply_mods(data.get("mods", {}), mult)
				apply_flags(data.get("flags", {}))
				log.append({"kind": kind, "id": id, "mult": mult})
				_card_records.append(c)
			"char_upgrade":
				taken_char_upgrades.append(id)
				apply_mods(data.get("mods", {}))
				apply_flags(data.get("flags", {}))
				log.append({"kind": kind, "id": id})
				_card_records.append(c)
			"synergy":
				taken_synergies.append(id)
				apply_mods(data.get("mods", {}))
				apply_flags(data.get("flags", {}))
				log.append({"kind": kind, "id": id})
				_card_records.append(c)
			"specialization":
				apply_mods(data.get("mods", {}))
				apply_flags(data.get("flags", {}))
				specialization_pending += 1
				log.append({"kind": kind, "id": id, "perk_id": String(data.get("perk_id", ""))})
				_card_records.append(c)
			"seal":
				taken_seals.append(id)
				apply_mods(data.get("mods", {}))
				apply_flags(data.get("flags", {}))
				log.append({"kind": kind, "id": id})
				_card_records.append(c)
			"evolution":
				weapon_evolution = data
				evolution_done = true
				apply_mods(data.get("mods", {}))
				apply_flags(data.get("flags", {}))
				log.append({"kind": kind, "id": id})
				_card_records.append(c)
	_replaying = false
	return true

func summary() -> Array:
	return log.duplicate()
