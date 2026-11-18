extends Node
## SaveManager — зашифрованное сохранение прогресса (JSON + пароль) и бэкап.

const SAVE_PATH := "user://save.dat"
const BACKUP_PATH := "user://save_backup.dat"
const SAVE_PASS := "surwave_secret_key"

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	return {
		"version": "1.5.0",
		"gold": 0,
		"souls": 0,
		"crystals": 0,
		"skill_rating": 300.0,
		"rated_runs": 0,
		"meta_tree": {"power": 0, "fortitude": 0, "speed": 0, "luck": 0, "mastery": 0},
		"quests": {"daily_stamp": "", "weekly_stamp": "", "daily": [], "weekly": []},
		"quest_totals": {"kills": 0, "runs": 0, "wins": 0, "boss": 0, "combo20": 0},
		"challenge_records": [],
		"unlocked_chars": ["aldar", "gavan", "morkana", "korgash", "liel"],
		"unlocked_weapons": ["revolver"],
		"unlocked_maps": ["sands", "tundra", "peak", "abyss", "forest", "graveyard", "hive"],
		"beaten_maps": {},
		"endless_unlocked": false,
		"throne_unlocked": false,
		"sathan_defeated": false,
		"amulet_ranks": {},
		"equipped_amulets": [],
		"max_darkness": 1,
		"records": {},
		"achievements": [],
		"album_enemies": [],
		"album_bosses": [],
		"settings": {"music": 0.8, "sfx": 0.8, "lang": "ru", "shake": true, "god_mode": false,
			"boss_fx": true, "slowmo": true, "qte": true, "post_fx": true, "photo_ui": true,
			"hud_vitals": "corner", "window_mode": "windowed", "vsync": true,
			"camera_distance": "normal", "camera_shake": "normal", "damage_numbers": true,
			"crosshair": true, "aim_line": true, "vignette": true, "screen_flash": true,
			"hit_stop": true, "combo_fx": true, "net_name": "", "net_port": 7777, "net_last_ip": ""},
		"stats": {"kills": 0, "runs": 0, "wins": 0, "damage_dealt": 0, "souls_earned": 0},
	}

## Миграция сохранений прошлых версий: старые id карт/персонажей заменяются новыми.
const LEGACY_MAP_IDS := {"desert": "sands", "tundra": "tundra", "mountain": "peak", "cave": "abyss",
	"forest": "forest", "swamp": "rift", "bonefields": "graveyard", "volcano": "peak",
	"swamp2": "rift", "sky": "graveyard", "crystals": "hive", "ruins": "throne", "infernal": "void",
	"temple": "temple"}

func _migrate(data: Dictionary) -> void:
	var maps_in: Array = data.get("unlocked_maps", [])
	if maps_in.is_empty():
		maps_in = ["sands"]
	var maps_out: Array = []
	for mid in maps_in:
		var nid: String = String(LEGACY_MAP_IDS.get(String(mid), String(mid)))
		if not maps_out.has(nid):
			maps_out.append(nid)
	data["unlocked_maps"] = maps_out
	var beaten_in: Dictionary = data.get("beaten_maps", {})
	var beaten_out: Dictionary = {}
	for k in beaten_in.keys():
		beaten_out[String(LEGACY_MAP_IDS.get(String(k), String(k)))] = true
	data["beaten_maps"] = beaten_out
	var base_chars := ["aldar", "gavan", "morkana", "korgash", "liel"]
	var chars: Array = data.get("unlocked_chars", [])
	for cid in base_chars:
		if not chars.has(cid): chars.append(cid)
	data["unlocked_chars"] = chars
	var base_maps := ["sands", "tundra", "peak", "abyss", "forest", "graveyard", "hive"]
	for mid in base_maps:
		if not maps_out.has(mid): maps_out.append(mid)
	data["unlocked_maps"] = maps_out
	if (data.get("unlocked_weapons", []) as Array).is_empty():
		data["unlocked_weapons"] = ["revolver"]

func load_game() -> void:
	data = default_data()
	var loaded := _read(SAVE_PATH)
	if loaded.is_empty():
		loaded = _read(BACKUP_PATH)
	if not loaded.is_empty():
		# дополняем отсутствующие ключи значениями по умолчанию
		for key in data.keys():
			if not loaded.has(key):
				loaded[key] = data[key]
		data = loaded
	var default_settings: Dictionary = default_data()["settings"]
	var settings: Dictionary = data.get("settings", {})
	for skey in default_settings.keys():
		if not settings.has(skey):
			settings[skey] = default_settings[skey]
	data["settings"] = settings
	if not data.get("settings", {}).has("lang"):
		data["settings"]["lang"] = "ru"
	if not data.get("settings", {}).has("hud_vitals"):
		data["settings"]["hud_vitals"] = "corner"
	_migrate(data)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, SAVE_PASS)
	if f == null:
		push_warning("SaveManager: не удалось открыть " + path)
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	return {}

func save_game() -> void:
	_write(SAVE_PATH)
	_write(BACKUP_PATH)

func _write(path: String) -> void:
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, SAVE_PASS)
	if f == null:
		push_error("SaveManager: запись невозможна " + path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func reset() -> void:
	data = default_data()
	save_game()

func get_value(key: String, def: Variant = null) -> Variant:
	return data.get(key, def)

func set_value(key: String, value: Variant) -> void:
	data[key] = value
