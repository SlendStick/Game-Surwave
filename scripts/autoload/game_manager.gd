extends Node
## GameManager — состояние мета-прогрессии, конфиг забега, магазины, переходы сцен.

const SCENE_MENU := "res://scenes/main/main_menu.tscn"
const SCENE_SELECT := "res://scenes/main/character_select.tscn"
const SCENE_GAME := "res://scenes/main/game.tscn"

var meta: Dictionary = {}
var run_config: Dictionary = {}
var run_results: Dictionary = {}
var game: Node = null

# режимы тестирования (включаются ключами командной строки при запуске)
var autoplay := false
var fast_test := false
var god_mode := false

# --- читы (сбрасываются на каждом новом забеге)
signal cheat_state_changed(used: bool)
var cheat_open := false
var cheat_used := false
var cheat_dmg := 1.0
var cheat_speed := 1.0
var cheat_enemy_hp := 1.0
var cheat_enemy_dmg := 1.0
var cheat_enemy_speed := 1.0
var cheat_frozen := false

const MAP_ORDER := ["sands", "tundra", "peak", "abyss", "forest", "rift", "graveyard", "hive",
	"bloodmoon", "chaos", "temple", "throne"]

## Курсор: игра просит спрятать его только в бою со «своим прицелом».
## Применяется каждый кадр автозагрузкой, поэтому меню паузы и выбор перков
## (когда дерево стоит на паузе) всё равно получают видимый курсор.
var cursor_hidden := false

func _ready() -> void:
	# F11 и настройки должны работать и на паузе/в экране выбора перков
	process_mode = Node.PROCESS_MODE_ALWAYS
	meta = SaveManager.data
	god_mode = bool(meta.get("settings", {}).get("god_mode", false))
	_setup_input()
	apply_display_settings()
	AudioManager.apply_settings(float(meta["settings"].get("music", 0.8)), float(meta["settings"].get("sfx", 0.8)))
	Loc.set_lang(String(meta["settings"].get("lang", "ru")))
	_parse_cli()
	if autoplay:
		call_deferred("_autostart_test")
	if OS.get_environment("SURW_HUD_VITALS") != "":
		set_setting("hud_vitals", OS.get_environment("SURW_HUD_VITALS"))
	if OS.get_environment("SURW_SCREEN") == "select":
		call_deferred("goto_select")
	if OS.get_environment("SURW_SHOT") != "":
		call_deferred("_dev_screenshot")

## Служебное: снимок экрана для проверки UI (SURW_SHOT=<имя>, SURW_SHOT_DELAY=<сек>).
func _dev_screenshot() -> void:
	var delay := float(OS.get_environment("SURW_SHOT_DELAY")) if OS.get_environment("SURW_SHOT_DELAY") != "" else 3.0
	await get_tree().create_timer(delay).timeout
	var dir := OS.get_environment("SURW_SHOT_DIR")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir) if dir.begins_with("user://") else dir)
	var path := "%s/%s.png" % [dir, OS.get_environment("SURW_SHOT")]
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[SURWAVE] shot ", path, " err=", err)
	if OS.get_environment("SURW_SHOT_KEEP") == "":
		get_tree().quit()

## Автозапуск забега для автоматических проверок (без участия игрока).
func _autostart_test() -> void:
	if fast_test:
		Engine.time_scale = 20.0
	var cfg := {
		"character": _env("SURW_CHAR", "aldar"),
		"weapon": _env("SURW_WEAPON", "revolver"),
		"map": _env("SURW_MAP", "forest"),
		"mode": _env("SURW_MODE", "standard"),
		"darkness": int(_env("SURW_DARK", "1")),
		"trials": Array(_env("SURW_TRIALS", "").split(",", false)),
		"blessing": "",
	}
	start_run(cfg)

func _env(key: String, def: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else def

func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		match arg:
			"--autoplay": autoplay = true
			"--fast": fast_test = true
			"--god": god_mode = true

func _setup_input() -> void:
	_add_action("move_left", [KEY_A])
	_add_action("move_right", [KEY_D])
	_add_action("move_up", [KEY_W])
	_add_action("move_down", [KEY_S])
	_add_action("reload", [KEY_R])
	_add_action("skill", [KEY_SHIFT, KEY_Q])
	_add_action("interact", [KEY_E])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("synergies", [KEY_TAB])
	_add_action("fullscreen", [KEY_F11])
	_add_action("photo_mode", [KEY_F12, KEY_P])
	_add_action("photo_capture", [KEY_SPACE, KEY_F5])
	_add_action("photo_hud", [KEY_H])
	_add_action("coop_left", [KEY_LEFT])
	_add_action("coop_right", [KEY_RIGHT])
	_add_action("coop_up", [KEY_UP])
	_add_action("coop_down", [KEY_DOWN])
	_add_action("coop_fire", [KEY_KP_0])
	_add_action("auto_test", [KEY_F4])
	_add_action("fire", [], [MOUSE_BUTTON_LEFT])
	_add_action("skill_mouse", [], [MOUSE_BUTTON_RIGHT])
	_add_action("confirm", [KEY_ENTER, KEY_KP_ENTER])
	_add_action("toggle_aim", [KEY_SPACE])

func _add_action(action: String, keys: Array = [], mouse_buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for m in mouse_buttons:
		var mev := InputEventMouseButton.new()
		mev.button_index = m
		InputMap.action_add_event(action, mev)

# ------------------------------------------------------------------ СЦЕНЫ
func goto(path: String) -> void:
	get_tree().paused = false
	game = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(path)

func goto_menu() -> void:
	AudioManager.stop_music()
	goto(SCENE_MENU)

func goto_select() -> void:
	AudioManager.stop_ambience()
	goto(SCENE_SELECT)

# ------------------------------------------------------------------ ЗАБЕГ
func start_run(config: Dictionary) -> void:
	reset_cheats()
	run_config = {
		"character": String(config.get("character", "aldar")),
		"weapon": String(config.get("weapon", "revolver")),
		"map": String(config.get("map", "forest")),
		"mode": String(config.get("mode", "standard")),
		"darkness": int(config.get("darkness", 1)),
		"secret_entry": bool(config.get("secret_entry", false)),
		"seed": int(config.get("seed", 0)),
		"trials": (config.get("trials", []) as Array).duplicate(),
		"blessing": String(config.get("blessing", "")),
		"network": bool(config.get("network", false)),
		"is_host": bool(config.get("is_host", false)),
		"players": int(config.get("players", 1)),
		"loadouts": (config.get("loadouts", {}) as Dictionary).duplicate(true),
	}
	if (run_config["trials"] as Array).has("sniper") and not ["crossbow","bow","lightning_staff"].has(String(run_config["weapon"])):
		run_config["weapon"] = "crossbow"
	if (run_config["trials"] as Array).has("berserk") and not ["shotgun","fire_ring","shadow_daggers","holy_spears"].has(String(run_config["weapon"])):
		run_config["weapon"] = "shadow_daggers"
	run_results = {}
	meta["stats"]["runs"] = int(meta["stats"].get("runs", 0)) + 1
	SaveManager.save_game()
	goto(SCENE_GAME)

## Возвращает награду и обновляет прогресс. Вызывается из Game при победе/поражении.
func end_run(results: Dictionary, victory: bool) -> Dictionary:
	run_results = results
	if cheat_used:
		results["cheats_used"] = true
		results["souls"] = 0
		results["gold"] = 0
		return {"souls": 0, "gold": 0}
	var souls_gain := int(results.get("souls", 0))
	var gold_reward := int(results.get("gold", 0))
	meta["souls"] = int(meta["souls"]) + souls_gain
	meta["gold"] = int(meta["gold"]) + gold_reward
	meta["stats"]["kills"] = int(meta["stats"].get("kills", 0)) + int(results.get("kills", 0))
	meta["stats"]["damage_dealt"] = int(meta["stats"].get("damage_dealt", 0)) + int(results.get("damage_dealt", 0))
	meta["stats"]["souls_earned"] = int(meta["stats"].get("souls_earned", 0)) + souls_gain
	if victory:
		meta["stats"]["wins"] = int(meta["stats"].get("wins", 0)) + 1
		if int(results.get("damage_taken",0)) == 0:
			meta["crystals"] = int(meta.get("crystals",0)) + 1

	var map_id := String(run_config.get("map", "forest"))
	var records: Dictionary = meta.get("records", {})
	var prev: Dictionary = records.get(map_id, {})
	var time_survived := float(results.get("time", 0.0))
	if float(prev.get("time", 0.0)) < time_survived:
		prev["time"] = time_survived
	prev["kills"] = maxi(int(prev.get("kills", 0)), int(results.get("kills", 0)))
	prev["level"] = maxi(int(prev.get("level", 0)), int(results.get("level", 0)))
	records[map_id] = prev
	meta["records"] = records

	if victory and not bool(meta.get("beaten_maps", {}).get(map_id, false)):
		meta["beaten_maps"][map_id] = true
		_unlock_next_map(map_id)
	# Тьма: победа открывает следующий уровень и достижения за 5/10/15
	var played_dark := int(run_config.get("darkness", 1))
	if victory:
		meta["max_darkness"] = maxi(int(meta.get("max_darkness", 1)), clampi(played_dark + 1, 1, 15))
		if played_dark >= 5:
			add_achievement("darkness_5")
		if played_dark >= 10:
			add_achievement("darkness_10")
		if played_dark >= 15:
			add_achievement("darkness_15")
	if String(run_config.get("weapon", "")) == "holy_hammer" and victory and played_dark >= 5:
		_unlock_weapon("holy_hammer")
	Progression.add_progress("kills", int(results.get("kills", 0)))
	Progression.add_progress("runs", 1)
	Progression.add_progress("wins", 1 if victory else 0)
	Progression.add_progress("minutes", int(float(results.get("time", 0.0)) / 60.0))
	Progression.update_rating(results, victory)
	Progression.record_score(results,run_config.get("trials",[]),String(run_config.get("character","")),map_id)
	var trials: Array = run_config.get("trials", [])
	if victory and not trials.is_empty():
		Progression.add_progress("challenges",1)
		var challenge_gain := int(100.0 * Progression.challenge_multiplier(trials))
		meta["souls"] = int(meta.get("souls", 0)) + challenge_gain
		results["challenge_souls"] = challenge_gain
	SaveManager.save_game()
	return {"souls": souls_gain, "gold": gold_reward}

func _unlock_next_map(beaten: String) -> void:
	if beaten == "void":
		return
	var all_beaten := true
	for mid in MAP_ORDER:
		if not bool(meta.get("beaten_maps", {}).get(mid, false)):
			all_beaten = false
			break
	if all_beaten:
		_unlock_map("throne")
		meta["endless_unlocked"] = true
		return
	if beaten == "throne":
		meta["endless_unlocked"] = true
		return
	var idx := MAP_ORDER.find(beaten)
	if idx >= 0 and idx + 1 < MAP_ORDER.size():
		var next_id: String = MAP_ORDER[idx + 1]
		var nd := DB.map(next_id)
		if String(nd.get("unlock", "")) != "secret":
			_unlock_map(next_id)

func _unlock_map(map_id: String) -> void:
	var arr: Array = meta.get("unlocked_maps", [])
	if not arr.has(map_id):
		arr.append(map_id)
	meta["unlocked_maps"] = arr

func _unlock_weapon(weapon_id: String) -> void:
	var arr: Array = meta.get("unlocked_weapons", [])
	if not arr.has(weapon_id):
		arr.append(weapon_id)

func _unlock_char(char_id: String) -> void:
	var arr: Array = meta.get("unlocked_chars", [])
	if not arr.has(char_id):
		arr.append(char_id)

# ------------------------------------------------------------------ ПРОВЕРКИ ДОСТУПА
func is_char_unlocked(id: String) -> bool:
	if (meta.get("unlocked_chars", []) as Array).has(id):
		return true
	if id == "nox": return Progression.tree_level("mastery") >= 14 and bool(meta.get("sathan_defeated",false))
	var req := {"ten":1,"voltra":4,"rain":8,"ignis":11}
	if req.has(id): return Progression.tree_level("mastery") >= int(req[id])
	return false

func is_weapon_unlocked(id: String) -> bool:
	return (meta.get("unlocked_weapons", []) as Array).has(id)

func is_map_unlocked(id: String) -> bool:
	if id == "void":
		return false   # секретная карта не показывается в меню
	if (meta.get("unlocked_maps", []) as Array).has(id):
		return true
	var req := {"rift":2,"bloodmoon":5,"chaos":6,"temple":9}
	if req.has(id): return Progression.tree_level("mastery") >= int(req[id])
	if id == "throne": return bool(meta.get("throne_unlocked",false))
	return false

func is_endless_unlocked() -> bool:
	return Progression.tree_level("mastery") >= 12 or bool(meta.get("endless_unlocked", false))

# ------------------------------------------------------------------ ПОКУПКИ В МЕНЮ ВЫБОРА
func buy_character(id: String) -> bool:
	var ch := DB.character(id)
	if ch.is_empty() or is_char_unlocked(id):
		return false
	if String(ch.get("unlock", "")) != "":
		return false
	var price := int(ch.get("price", 0))
	if price <= 0 or int(meta["souls"]) < price:
		return false
	meta["souls"] = int(meta["souls"]) - price
	_unlock_char(id)
	SaveManager.save_game()
	return true

func buy_weapon(id: String) -> bool:
	var w := DB.weapon(id)
	if w.is_empty() or is_weapon_unlocked(id):
		return false
	if String(w.get("unlock", "")) != "":
		return false      # открывается особым условием
	var price := int(w.get("price", 0))
	if price <= 0 or int(meta["souls"]) < price:
		return false
	meta["souls"] = int(meta["souls"]) - price
	_unlock_weapon(id)
	SaveManager.save_game()
	return true

func buy_map(id: String) -> bool:
	var m := DB.map(id)
	if m.is_empty() or is_map_unlocked(id):
		return false
	if String(m.get("unlock", "")) == "secret" or bool(m.get("secret", false)):
		return false
	var price := int(m.get("price", 0))
	if price <= 0 or int(meta["souls"]) < price:
		return false
	meta["souls"] = int(meta["souls"]) - price
	_unlock_map(id)
	SaveManager.save_game()
	return true

func amulet_rank(id: String) -> int:
	return int(meta.get("amulet_ranks", {}).get(id, 0))

func amulet_cost(id: String) -> int:
	var rank := amulet_rank(id)
	if rank >= 5:
		return -1
	return int(DB.amulet_costs[rank]) if rank < DB.amulet_costs.size() else -1

func upgrade_amulet(id: String) -> bool:
	var cost := amulet_cost(id)
	if cost < 0 or int(meta["souls"]) < cost:
		return false
	meta["souls"] = int(meta["souls"]) - cost
	var ranks: Dictionary = meta.get("amulet_ranks", {})
	ranks[id] = amulet_rank(id) + 1
	meta["amulet_ranks"] = ranks
	SaveManager.save_game()
	return true

## Слоты: 4 уровня, в каждом до 1 атакующего и 1 защитного амулета.
func equipped_amulets() -> Array:
	return meta.get("equipped_amulets", [])

func amulet_equipped(id: String) -> bool:
	return equipped_amulets().has(id)

func toggle_amulet(id: String) -> bool:
	var amu := DB.amulet_by_id.get(id, {})
	if amu.is_empty() or amulet_rank(id) <= 0:
		return false
	var arr: Array = equipped_amulets().duplicate()
	if arr.has(id):
		arr.erase(id)
		meta["equipped_amulets"] = arr
		SaveManager.save_game()
		return true
	var kind := String(amu.get("type", "attack"))
	var same_kind := 0
	for other_id in arr:
		var other: Dictionary = DB.amulet_by_id.get(String(other_id), {})
		if String(other.get("type", "")) == kind:
			same_kind += 1
	if same_kind >= 4:
		EventBus.notify.emit("Максимум 4 амулета одного пути")
		return false
	arr.append(id)
	meta["equipped_amulets"] = arr
	SaveManager.save_game()
	return true

## Бонусы амулетов, применяемые в начале забега.
func amulet_bonuses() -> Array:
	var out: Array = []
	for id in equipped_amulets():
		var rank := amulet_rank(String(id))
		if rank <= 0:
			continue
		var amu: Dictionary = DB.amulet_by_id.get(String(id), {})
		if amu.is_empty():
			continue
		out.append({"id": String(id), "rank": rank, "per_rank": float(amu.get("per_rank", 0.0))})
	return out

# ------------------------------------------------------------------ ОКНО / ДИСПЛЕЙ
## Порядок переключения режимов окна кнопкой в настройках и по F11.
const WINDOW_MODES := ["windowed", "borderless", "fullscreen"]
const WINDOW_MODE_NAMES := {
	"windowed": "ОКОННЫЙ",
	"borderless": "ОКНО НА ВЕСЬ ЭКРАН",
	"fullscreen": "ПОЛНОЭКРАННЫЙ",
}
const CAMERA_MODES := ["normal", "close", "far"]
const CAMERA_MODE_NAMES := {"normal": "СТАНДАРТ", "close": "БЛИЗКО", "far": "ДАЛЕКО"}
const CAMERA_ZOOM_SCALE := {"normal": 1.0, "close": 1.16, "far": 0.84}

func window_mode() -> String:
	var m := String(setting("window_mode", "windowed"))
	return m if WINDOW_MODES.has(m) else "windowed"

func window_mode_name() -> String:
	return String(WINDOW_MODE_NAMES.get(window_mode(), "ОКОННЫЙ"))

## Следующий режим окна по кругу: оконный → окно на весь экран → полный экран.
func cycle_window_mode() -> String:
	var idx := WINDOW_MODES.find(window_mode())
	var next_mode := String(WINDOW_MODES[(idx + 1) % WINDOW_MODES.size()])
	set_setting("window_mode", next_mode)
	apply_window_mode(next_mode)
	return next_mode

## Применяет режим окна. В headless-режиме (CI) ничего не трогает.
## Используется API окна (а не DisplayServer напрямую): оно само следит за порядком
## переключения, поэтому режимы реально срабатывают и на Windows, и на Linux.
## Единственная точка, где мы трогаем режим мыши.
func set_cursor_hidden(hidden: bool) -> void:
	cursor_hidden = hidden
	_apply_cursor()

func _apply_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := Input.MOUSE_MODE_HIDDEN if cursor_hidden else Input.MOUSE_MODE_VISIBLE
	if Input.get_mouse_mode() != want:
		Input.set_mouse_mode(want)

func _process(_delta: float) -> void:
	# Работает и на паузе (PROCESS_MODE_ALWAYS): курсор не «залипает».
	_apply_cursor()

func apply_window_mode(mode: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	match mode:
		"fullscreen":
			win.borderless = false
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"borderless":
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			call_deferred("_fit_window", "borderless")
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			call_deferred("_fit_window", "windowed")

## Размер и позиция окна — отдельным кадром, иначе оконный менеджер их игнорирует.
func _fit_window(mode: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	if mode == "borderless":
		win.size = usable.size
		win.position = usable.position
		return
	var target := Vector2i(mini(1280, usable.size.x), mini(720, usable.size.y))
	win.size = target
	win.position = usable.position + (usable.size - target) / 2

func apply_vsync() -> void:
	var enabled := bool(setting("vsync", true))
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func apply_display_settings() -> void:
	apply_vsync()
	apply_window_mode(window_mode())

## Множитель зума камеры из настроек (близко / стандарт / далеко).
func camera_zoom_scale() -> float:
	return float(CAMERA_ZOOM_SCALE.get(String(setting("camera_distance", "normal")), 1.0))

# ------------------------------------------------------------------ НАСТРОЙКИ
## Сброс читов перед новым забегом: время, множители, заморозка.
func reset_cheats() -> void:
	cheat_open = false
	cheat_used = false
	cheat_dmg = 1.0
	cheat_speed = 1.0
	cheat_enemy_hp = 1.0
	cheat_enemy_dmg = 1.0
	cheat_enemy_speed = 1.0
	cheat_frozen = false
	Engine.time_scale = 1.0
	cheat_state_changed.emit(false)

func mark_cheat_used() -> void:
	if not cheat_used:
		cheat_used = true
		cheat_state_changed.emit(true)

func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = meta.get("settings", {})
	s[key] = value
	meta["settings"] = s
	if key == "lang":
		Loc.set_lang(String(value))
	if key == "music" or key == "sfx":
		AudioManager.apply_settings(float(s.get("music", 0.8)), float(s.get("sfx", 0.8)))
	if key == "window_mode":
		apply_window_mode(String(value))
	if key == "vsync":
		apply_vsync()
	SaveManager.save_game()

## F11 в любом экране: оконный → окно на весь экран → полный экран.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		cycle_window_mode()
		get_viewport().set_input_as_handled()

func setting(key: String, def: Variant = null) -> Variant:
	return meta.get("settings", {}).get(key, def)

func darkness_mods(level: int) -> Dictionary:
	var mods: Dictionary = {}
	var mult_keys := ["fodder_hp", "elite_hp", "boss_hp", "fodder_dmg", "elite_dmg", "boss_dmg", "fodder_speed", "elite_speed", "fodder_late_dmg"]
	for entry in DB.darkness:
		if int(entry.get("level", 0)) <= level:
			for k in entry.get("mods", {}).keys():
				var val := float(entry["mods"][k])
				if mult_keys.has(String(k)):
					mods[k] = (1.0 + float(mods.get(k, 0.0))) * (1.0 + val) - 1.0
				else:
					mods[k] = float(mods.get(k, 0.0)) + val
	return mods

func add_achievement(id: String) -> void:
	if cheat_used:
		return
	var arr: Array = meta.get("achievements", [])
	if not arr.has(id):
		arr.append(id)
		meta["achievements"] = arr
		SaveManager.save_game()

func add_album_enemy(id: String) -> void:
	if cheat_used:
		return
	var arr: Array = meta.get("album_enemies", [])
	if not arr.has(id):
		arr.append(id)
		meta["album_enemies"] = arr
		SaveManager.save_game()

func add_album_boss(id: String) -> void:
	if cheat_used:
		return
	var arr: Array = meta.get("album_bosses", [])
	if not arr.has(id):
		arr.append(id)
		meta["album_bosses"] = arr
		SaveManager.save_game()
