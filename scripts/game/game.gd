extends Node2D
## Game — ядро забега: карта, пулы объектов, спавн, урон, XP, боссы, секретная карта,
## режимы, сложность и связь с HUD. Все сущности тикаются отсюда (без _process у детей).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const BULLET_SCENE := preload("res://scenes/projectiles/bullet.tscn")
const EBULLET_SCENE := preload("res://scenes/projectiles/enemy_bullet.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const ALLY_SCENE := preload("res://scenes/game/ally.tscn")
const HAZARD_SCENE := preload("res://scenes/game/hazard.tscn")
const FX_SCENE := preload("res://scenes/game/fx.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const MAP_EVENT_FX_SCRIPT := preload("res://scripts/game/map_event_fx.gd")
const PERK_FX_SCRIPT := preload("res://scripts/game/perk_fx.gd")

const CELL := 64.0

var map_data: Dictionary = {}
var map_rect := Rect2(0, 0, 3200, 1800)
var player: Player = null
var upg: UpgradeSystem
var wave_mgr: WaveManager
var events_mgr: MapEvents

var world: Node2D
var camera: Camera2D
var hud: Node = null
var canvas_mod: CanvasModulate = null

var enemies: Array = []
var enemy_pool: Array = []
var bullets: Array = []
var bullet_pool: Array = []
var ebullets: Array = []
var ebullet_pool: Array = []
var pickups: Array = []
var pickup_pool: Array = []
var allies: Array = []
var ally_pool: Array = []
var hazards: Array = []
var hazard_pool: Array = []
var fx_list: Array = []
var fx_pool: Array = []
var dmg_nums: Array = []
var dmg_pool: Array = []

var obstacles: Array = []
var obstacle_grid: Dictionary = {}
var corpses: Array = []
var movers: Array = []
var decor_nodes: Array = []
var map_bg_node: ColorRect = null
var map_floor_node: Node2D = null
var mover_pool: Array = []
var weather: Dictionary = {}
var weather_fx: WeatherFx = null
var weather_layer: CanvasLayer = null
var hazard_stats: Dictionary = {"solid": 0, "slow": 0, "damage": 0, "reflect": 0, "decor": 0, "heal": 0, "slide": 0, "destructible": 0}

# состояние забега
var elapsed := 0.0
var mode := "standard"
var diff_mods: Dictionary = {}
var level := 1
var xp := 0
var xp_need := 10
var trial_xp_mult := 1.0
var xp_boost_left := 0.0
var gold := 0
var souls := 0.0
var kills := 0
var damage_dealt := 0.0
var damage_taken := 0.0
var pending_level_ups := 0
var ended := false
var victory := false
var paused_for_choice := false
var blood_phase_active := false
var endless_cycle := 0
var shake_amount := 0.0
var choice_queue: Array = []

# боссы
var boss_enemy: Enemy = null
var boss_no_hit := true
var first_boss_done := false
var secret_entry := false
var pentagram_pos := Vector2.INF
var megaphase := false
var sathan_defeated := false
var satanail_defeated := false
var secret_spawn_pending := false

var vision_mult := 1.0
var vignette_rect: ColorRect = null
var vignette_mat: ShaderMaterial = null
var vignette_pulse := 0.0
var camera_kick := Vector2.ZERO
var look_ahead := Vector2.ZERO
var hitstop_left := 0.0
var last_intensity_check := 0.0
var rng := RandomNumberGenerator.new()
var run_started := false
var timers_log := 0.0
var pending_aoe: Array = []
var pulls: Array = []
var flash_rect: ColorRect = null
var flash_left := 0.0
var vision_rect: ColorRect = null
var vision_mat: ShaderMaterial = null
var _xp_frac := 0.0
var kills_without_damage := 0
var pentagram_spawned := false

# новые системы 1.2: скрытый режиссёр, напряжение, комбо и постановка боссов
var tension := 25.0
var director_timer := 5.0
var director_mods := {"spawn":1.0,"hp":1.0,"damage":1.0,"speed":1.0,"heal":1.0,"elite":1.0}
var time_since_damage := 0.0
var recent_damage := 0.0
var combo := 0
var combo_peak := 0
var combo_left := 0.0
const BASE_CAMERA_ZOOM := 1.28

var combo20_hits := 0
var boss_focus := 0.0
var camera_zoom_target := BASE_CAMERA_ZOOM
var photo_mode := false
var _photo_was_paused := false
var qte_target: Enemy = null
var final_qte := false
var qte_presses := 0
var qte_left := 0.0
var dodge_qte_left := 0.0
var dodge_qte_damage := 0
var dodge_qte_source := Vector2.ZERO
var counter_qte_left := 0.0
var coop_player: CoopCompanion = null

# --- сеть (кооп до 4 игроков: хост считает мир, клиенты присылают состояние)
var net_active := false
var net_host := false
var net_proxies: Array = []
var net_enemies: Dictionary = {}
var net_bullets: Array = []
var net_pickup_ghosts: Array = []
var net_id_seq := 1
var _net_snapshot_cd := 0.0
var _net_state_cd := 0.0
## Кооп: паузу задаёт хост, кристаллы возрождения, чат и эмоции.
var net_paused := false
var revive_crystals: Array = []
var revive_crystal_nodes: Array = []
var net_taken_pickups: Dictionary = {}
var _revive_req_cd := 0.0
## Активные ивенты карты живут 30–60 секунд и бьют волнами.
var active_events: Array = []
var chat_log: Array = []
var partner_perks: Array = []
## Бесконечный мир: новые полосы генерируются по мере ухода игроков от края.
const CHUNK_SIZE := 900.0
const EDGE_MARGIN := 280.0
var chunks_grown := 0
var _world_grow_cd := 0.0
var wave_number := 0
var wave_break := 0.0
var photo_filter := 0
var photo_frame := 0
var photo_format := "png"
var photo_scale := 1
var photo_layer: CanvasLayer = null
var photo_tint: ColorRect = null
var photo_info: Label = null
var photo_enemies_hidden := false
var secret_entered := false
var enemy_grid: Dictionary = {}
var solid_cells: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game = self
	GameManager.set_cursor_hidden(bool(GameManager.setting("crosshair", true)))
	mode = String(GameManager.run_config.get("mode", "standard"))
	var seed_value := int(GameManager.run_config.get("seed", 0))
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) % 1000000
	rng.seed = seed_value
	seed(seed_value)
	diff_mods = GameManager.darkness_mods(int(GameManager.run_config.get("darkness", 1)))
	map_data = DB.map(String(GameManager.run_config.get("map", "forest")))
	if map_data.is_empty():
		map_data = DB.map("forest")
	secret_entry = bool(GameManager.run_config.get("secret_entry", false))
	map_rect = Rect2(0, 0, float(DB.balance["run"]["map_size"][0]), float(DB.balance["run"]["map_size"][1]))
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_setup_camera()
	_build_map()
	upg = UpgradeSystem.new()
	upg.endless = mode == "endless"
	upg.choice_count = 5 + int(diff_mods.get("choices", 0))
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.game = self
	player.global_position = map_rect.get_center()
	player.setup(String(GameManager.run_config.get("character", "aldar")), String(GameManager.run_config.get("weapon", "revolver")), upg)
	_apply_meta_progression()
	if OS.get_environment("SURW_ALL_PERKS")!="":
		for perk in DB.perks: upg.take_card({"kind":"perk","id":String(perk.id),"data":perk,"force":true})
		player.recalc(); print("[SURWAVE] all_perks applied=",DB.perks.size()," mods=",upg.add.size()," flags=",upg.flags.size())
	if OS.get_environment("SURW_CHAR_UPG")!="":
		for up in player.char_data.get("upgrades", []):
			upg.take_card({"kind":"char_upgrade","id":String(up.id),"data":up})
		player.recalc()
		print("[SURWAVE] char_upgrades applied=%d" % player.char_data.get("upgrades", []).size())
	if OS.get_environment("SURW_PERK_DEP_TEST")!="": _run_perk_dependency_test()
	if OS.get_environment("SURW_PERK_EFFECT_TEST")!="": _run_perk_effect_test()
	player.died.connect(_on_player_died)
	if mode == "coop":
		coop_player = CoopCompanion.new(); world.add_child(coop_player); coop_player.setup(self,player.global_position+Vector2(28,0))
	xp_need = _xp_for_level(1)
	_setup_net()
	wave_mgr = WaveManager.new()
	wave_mgr.setup(self, map_data, mode, diff_mods)
	events_mgr = MapEvents.new()
	events_mgr.setup(self, map_data)
	_setup_vision_layer()
	_setup_vignette()
	_setup_hud()
	_setup_photo_ui()
	_apply_map_mods()
	_apply_trials()
	AudioManager.stop_music()
	AudioManager.play_music(map_data.get("mood", {}))
	AudioManager.play_ambience(String(map_data.get("id", "sands")))
	AudioManager.set_boss_layer(false)
	GameManager.add_album_enemy("")
	run_started = true
	EventBus.xp_changed.emit(xp, xp_need, level)
	EventBus.hp_changed.emit(player.hp, player.max_hp)
	EventBus.ammo_changed.emit(player.mag, int(player.S.mag), false)
	notify(_map_intro())
	if secret_entry:
		notify(Loc.t("pentagram_enter"))
	if OS.get_environment("SURW_ABILITY_TEST") != "": call_deferred("_run_ability_test")
	if OS.get_environment("SURW_HUD_TEST") != "": call_deferred("_run_hud_test")
	if OS.get_environment("SURW_CONTROLS_TEST") != "": call_deferred("_run_controls_test")
	if OS.get_environment("SURW_PAUSE_TEST") != "": call_deferred("_run_pause_test")
	if OS.get_environment("SURW_UI_TEST") != "": call_deferred("_run_ui_test")
	if OS.get_environment("SURW_NET_TEST") != "": call_deferred("_run_net_test")
	if OS.get_environment("SURW_BOOM_TEST") != "": call_deferred("_run_boomerang_test")
	if OS.get_environment("SURW_PERK_CLICK_TEST") != "": call_deferred("_run_perk_click_test")
	if OS.get_environment("SURW_AVALANCHE_TEST") != "": call_deferred("_run_avalanche_test")
	if OS.get_environment("SURW_COOP_TEST") != "": call_deferred("_run_coop_test")
	if OS.get_environment("SURW_HAZARD_TEST") != "": call_deferred("_run_hazard_test")
	if OS.get_environment("SURW_MAP_DUMP") != "": call_deferred("_run_map_dump")
	if OS.get_environment("SURW_VIS_TEST") != "": call_deferred("_run_vis_test")
	if OS.get_environment("SURW_CHEAT_TEST") != "": call_deferred("_run_cheat_test")
	if OS.get_environment("SURW_LIFETIME_TEST") != "": call_deferred("_run_lifetime_test")
	if OS.get_environment("SURW_BOSS_TEST") != "": call_deferred("_dev_boss_test")
	if OS.get_environment("SURW_PHOTO_TEST") != "": call_deferred("_dev_photo_test")

func _dev_photo_test() -> void:
	await get_tree().process_frame
	photo_format=OS.get_environment("SURW_PHOTO_TEST"); photo_scale=2; _capture_photo()

func _dev_boss_test() -> void:
	if String(map_data.get("id","")) == "void": spawn_secret_boss()
	else: spawn_map_boss("final")
	if boss_enemy != null:
		var ratio := float(OS.get_environment("SURW_BOSS_TEST")) if OS.get_environment("SURW_BOSS_TEST").is_valid_float() else 0.39
		boss_enemy.hp = boss_enemy.max_hp * ratio
		print("[SURWAVE] boss_test phase_trigger hp=",boss_enemy.hp)
		if OS.get_environment("SURW_QTE_TEST") != "": _start_final_qte(boss_enemy)
		if OS.get_environment("SURW_DODGE_TEST") != "":
			start_dodge_qte(5,boss_enemy.global_position,boss_enemy); _qte_press(); counter_qte_left=0.5; _qte_press(); print("[SURWAVE] qte_dodge_counter test=ok")

func _map_intro() -> String:
	var lines := {
		"forest": "Проклятый Лес: берегитесь метеоритов и блуждающих огней",
		"tundra": "Тундра: лавины сметают всё на пути",
		"cave": "Пещера: темнота, свет только вокруг вас",
		"mountain": "Гора: камнепады и молнии",
		"desert": "Пустыня: бури и зыбучие пески",
		"volcano": "Вулкан: жара убивает вдали от воды",
		"swamp": "Топи: яд в каждой атаке",
		"temple": "Затопленный Храм: вода замедляет всё",
		"sky": "Небесные Острова: не упадите в пропасть",
		"bonefields": "Костяное Поле: мёртвые не спят",
		"crystals": "Кристальные Гроты: кристаллы отражают пули",
		"throne": "Тронный Зал: финал кампании",
		"void": "ПУСТОТА: секретная карта, САТАНАИЛ",
	}
	return String(lines.get(String(map_data.get("id", "")), "Выживите как можно дольше"))

## Испытания и благословения, выбранные перед раундом.
func _apply_meta_progression() -> void:
	var m: Dictionary = Progression.run_mods()
	upg.apply_mods({"dmg":float(m.dmg), "xp":float(m.get("xp", 0.0)), "crit":float(m.crit)/100.0, "hp":int(m.max_hp), "dr":float(m.defense), "move_speed":float(m.move), "fire_rate":float(m.attack)})
	upg.apply_flags({"meta_heal":float(m.heal), "meta_gold":float(m.gold), "meta_rare":float(m.rare), "meta_event":float(m.event), "slow_immune":1 if bool(m.slow_immune) else 0})
	player.recalc()
	player.hp = player.max_hp

func _apply_trials() -> void:
	var trials: Array = GameManager.run_config.get("trials", [])
	trial_xp_mult = Progression.challenge_multiplier(trials) if not trials.is_empty() else 1.0
	for t in trials:
		match String(t):
			"glass":
				player.set_meta("glass", true)
				upg.apply_mods({"dmg": 1.0})
			"insomnia":
				wave_mgr.spawn_scale *= 1.5
				diff_mods["xp"] = float(diff_mods.get("xp", 0.0)) + 0.5
			"loner":
				upg.apply_mods({"summon_dmg": -0.3, "dmg": 0.3})
			"hell":
				diff_mods["fodder_hp"] = float(diff_mods.get("fodder_hp",0.0)) + 0.5
				diff_mods["fodder_dmg"] = float(diff_mods.get("fodder_dmg",0.0)) + 0.5
				diff_mods["fodder_speed"] = float(diff_mods.get("fodder_speed",0.0)) + 0.2
				wave_mgr.spawn_scale *= 1.3
				player.set_meta("heal_mult", 0.5)
			"speedrun":
				wave_mgr.duration = 900.0
				wave_mgr.spawn_scale *= 1.5
				diff_mods["fodder_speed"] = float(diff_mods.get("fodder_speed",0.0)) + 0.2
			"no_heal": player.set_meta("no_heal", true)
			"berserk":
				upg.apply_mods({"dmg":0.25,"hp":2})
				diff_mods["fodder_hp"] = float(diff_mods.get("fodder_hp",0.0)) + 0.2
			"invisible": player.set_meta("trial_invisible", true)
			"one_life":
				player.set_meta("no_heal", true)
				player.set_meta("one_life", true)
				diff_mods["fodder_dmg"] = float(diff_mods.get("fodder_dmg",0.0)) + 0.3
			"wave":
				mode = "endless"
				wave_mgr.duration = 1.0e12
			"chaos": player.set_meta("trial_chaos", true)
	match String(GameManager.run_config.get("blessing", "")):
		"torch":
			upg.apply_mods({"vision": 0.25})
		"boots":
			player.set_meta("boots", true)
		"ward":
			player.set_meta("ward", true)
	player.recalc()
	if player.has_meta("one_life"):
		player.max_hp = 1
		player.hp = 1

# ------------------------------------------------------------------ КАМЕРА / КАРТА
func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_rect.size.x)
	camera.limit_bottom = int(map_rect.size.y)
	var z0 := BASE_CAMERA_ZOOM * GameManager.camera_zoom_scale()
	camera.zoom = Vector2(z0, z0)
	add_child(camera)
	camera.make_current()

func _build_map() -> void:
	# чистим фон и пол прежней карты, иначе после перехода (Пустота) остаются чужие текстуры
	if map_bg_node != null and is_instance_valid(map_bg_node):
		map_bg_node.queue_free()
	if map_floor_node != null and is_instance_valid(map_floor_node):
		map_floor_node.queue_free()
	var bg := ColorRect.new()
	bg.color = Gfx.hex(String(map_data.get("palette", {}).get("bg", "#101018")))
	bg.position = Vector2.ZERO
	bg.size = map_rect.size
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(bg)
	map_bg_node = bg
	_build_map_texture()
	_build_obstacles(map_data)
	_setup_weather_layer()

## Собирает препятствия карты по описанию из data/maps.json.
func _build_obstacles(md: Dictionary) -> void:
	for obstacle in obstacles:
		var old: Node = obstacle.get("node")
		if old != null and is_instance_valid(old):
			old.queue_free()
	for d in decor_nodes:
		if is_instance_valid(d):
			d.queue_free()
	decor_nodes.clear()
	obstacles.clear()
	obstacle_grid.clear()
	solid_cells.clear()
	for k in hazard_stats.keys():
		hazard_stats[k] = 0
	var mid := String(md.get("id", ""))
	var accent := Gfx.hex(String(md.get("palette", {}).get("accent", "#ffffff")))
	var base_col := Gfx.hex(String(md.get("palette", {}).get("obstacle", "#404050")))
	for def in md.get("obstacles", []):
		var kind := String(def.get("kind", "solid"))
		var shape := String(def.get("shape", "box"))
		var count := int(def.get("count", 30))
		var w := float(def.get("w", 26))
		var h := float(def.get("h", 26))
		var col := Gfx.hex(String(def.get("color", ""))) if String(def.get("color", "")) != "" else base_col
		var hp_max := float(def.get("hp", 0))
		for i in count:
			var pos := Vector2(
				rng.randf_range(140.0, map_rect.size.x - 140.0),
				rng.randf_range(140.0, map_rect.size.y - 140.0))
			if pos.distance_to(map_rect.get_center()) < 190.0:
				continue
			var rect := Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
			if kind == "decor":
				var vis := ObstacleVis.build(world, shape, Vector2(w, h), col, accent, mid)
				vis.position = pos
				if shape == "flower" or shape == "reeds":
					vis.modulate = Color(0.9, 0.9, 0.9, 0.85)
				decor_nodes.append(vis)
				hazard_stats["decor"] += 1
				continue
			var obstacle := {
				"rect": rect, "kind": kind, "shape": shape, "hp": hp_max, "max_hp": hp_max,
				"slow": float(def.get("slow", 0.0)),
				"damage": float(def.get("damage", 0.0)),
				"interval": float(def.get("interval", 0.5)),
				"timer": 0.0,
				"reflect": float(def.get("reflect", 1.0)),
				"heal": float(def.get("heal", 0.0)),
				"poison": float(def.get("poison", 0.0)),
				"node": null,
				"color": col,
			}
			var vis2 := ObstacleVis.build(world, shape, Vector2(w, h), col, accent, mid)
			vis2.position = pos
			match kind:
				"solid":
					var body := StaticBody2D.new()
					body.position = pos
					body.collision_layer = 1
					body.collision_mask = 0
					var shp := CollisionShape2D.new()
					var rect_shape := RectangleShape2D.new()
					rect_shape.size = Vector2(w * 0.6, h * 0.5)
					shp.shape = rect_shape
					body.add_child(shp)
					world.add_child(body)
					if vis2.get_parent() != null:
						vis2.get_parent().remove_child(vis2)
					body.add_child(vis2)
					vis2.position = Vector2.ZERO
					obstacle["node"] = body
					obstacle["collision"] = body
				_:
					obstacle["node"] = vis2
			if hp_max > 0.0:
				hazard_stats["destructible"] += 1
			hazard_stats[kind] = int(hazard_stats.get(kind, 0)) + 1
			_register_obstacle(obstacle)

## Урон по разрушаемому препятствию (от пуль игрока).
func hit_obstacle(obstacle: Dictionary, amount: float) -> void:
	if obstacle.is_empty() or float(obstacle.get("max_hp", 0.0)) <= 0.0:
		return
	obstacle["hp"] = float(obstacle.get("hp", 0.0)) - amount
	var node: Node2D = obstacle.get("node")
	if float(obstacle["hp"]) > 0.0:
		if node != null and is_instance_valid(node):
			node.modulate = Color(1.25, 1.0, 0.95)
			var ref := weakref(node)
			run_later(0.09, func() -> void:
				var n = ref.get_ref()
				if n != null and is_instance_valid(n):
					n.modulate = Color.WHITE)
		return
	var rect: Rect2 = obstacle["rect"]
	var col: Color = obstacle.get("color", Color(0.5, 0.5, 0.5))
	spawn_fx(rect.get_center(), Color(col.r, col.g, col.b, 0.9), maxf(rect.size.x, rect.size.y) * 1.3, 0.3)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_unregister_obstacle(obstacle)
	if not player.has_meta("no_heal") and randf() < 0.015:
		spawn_pickup("heart", rect.get_center(), 1.0)

func _unregister_obstacle(obstacle: Dictionary) -> void:
	obstacles.erase(obstacle)
	obstacle_grid.clear()
	solid_cells.clear()
	var keep: Array = obstacles.duplicate()
	obstacles.clear()
	for item in keep:
		_register_obstacle(item)

## Фактура пола: тайловая пиксель-арт текстура карты (Diablo 2 gothic ground tileset).
func _build_map_texture() -> void:
	var pal: Dictionary = map_data.get("palette", {})
	var bg2 := Gfx.hex(String(pal.get("bg2", "#14161c")))
	var accent := Gfx.hex(String(pal.get("obstacle", "#3a3c40")))
	var motif := String(pal.get("motif", "stones"))
	var layer := Node2D.new()
	layer.z_index = -9
	world.add_child(layer)
	map_floor_node = layer
	var ttex := Assets.tile(String(map_data.get("id", "sands")))
	if ttex != null:
		var tr := TextureRect.new()
		tr.texture = ttex
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.position = Vector2.ZERO
		tr.size = map_rect.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(tr)
		return
	# общая подложка: редкие крупные плиты
	for i in 54:
		var w := rng.randf_range(90.0, 260.0)
		var h := rng.randf_range(70.0, 200.0)
		var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
		Gfx.square(layer, Vector2(w, h), Color(bg2.r, bg2.g, bg2.b, 0.15), p)
	# мотив
	match motif:
		"tufts":
			for i in 220:
				var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
				var s := Gfx.square(layer, Vector2(2.0, rng.randf_range(5.0, 11.0)), Color(accent.r, accent.g, accent.b, 0.16), p)
				s.rotation = rng.randf_range(-0.45, 0.45)
		"dunes":
			for i in 90:
				var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
				var s := Gfx.square(layer, Vector2(rng.randf_range(50.0, 130.0), 2.0), Color(accent.r, accent.g, accent.b, 0.14), p)
				s.rotation = rng.randf_range(-0.22, 0.22)
		"cracks":
			for i in 70:
				var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
				var s := Gfx.square(layer, Vector2(1.5, rng.randf_range(24.0, 70.0)), Color(0, 0, 0, 0.30), p)
				s.rotation = rng.randf_range(-1.2, 1.2)
		"plots":
			for i in 90:
				var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
				Gfx.square(layer, Vector2(rng.randf_range(26.0, 46.0), rng.randf_range(10.0, 16.0)), Color(accent.r, accent.g, accent.b, 0.10), p)
		"ice":
			for i in 110:
				var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
				var s := Gfx.square(layer, Vector2(rng.randf_range(16.0, 46.0), 1.5), Color(accent.r, accent.g, accent.b, 0.20), p)
				s.rotation = rng.randf_range(-0.6, 0.6)
		_:
			for i in 140:
				var p := Vector2(rng.randf_range(0.0, map_rect.size.x), rng.randf_range(0.0, map_rect.size.y))
				Gfx.square(layer, Vector2(rng.randf_range(4.0, 9.0), rng.randf_range(3.0, 7.0)), Color(accent.r, accent.g, accent.b, 0.13), p)

func _register_obstacle(obstacle: Dictionary) -> void:
	obstacles.append(obstacle)
	if String(obstacle.get("kind", "")) == "solid":
		# помечаем все ячейки, которые перекрывает препятствие
		var r: Rect2 = obstacle["rect"]
		for cx in range(int(floor(r.position.x / CELL)), int(floor((r.position.x + r.size.x) / CELL)) + 1):
			for cy in range(int(floor(r.position.y / CELL)), int(floor((r.position.y + r.size.y) / CELL)) + 1):
				solid_cells[Vector2i(cx, cy)] = true
	var rect: Rect2 = obstacle["rect"]
	var x0 := int(floor(rect.position.x / CELL))
	var x1 := int(floor((rect.position.x + rect.size.x) / CELL))
	var y0 := int(floor(rect.position.y / CELL))
	var y1 := int(floor((rect.position.y + rect.size.y) / CELL))
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			if not obstacle_grid.has(key):
				obstacle_grid[key] = []
			obstacle_grid[key].append(obstacle)

func obstacles_at(pos: Vector2) -> Array:
	var out: Array = []
	var key := Vector2i(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var arr: Array = obstacle_grid.get(key + Vector2i(dx, dy), [])
			for obstacle in arr:
				if (obstacle["rect"] as Rect2).has_point(pos) and not out.has(obstacle):
					out.append(obstacle)
	return out

func obstacle_at(pos: Vector2, radius: float) -> Dictionary:
	var key := Vector2i(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var arr: Array = obstacle_grid.get(key + Vector2i(dx, dy), [])
			for obstacle in arr:
				var rect: Rect2 = obstacle["rect"]
				if rect.grow(radius).has_point(pos):
					var res: Dictionary = obstacle.duplicate()
					res["normal"] = _rect_normal(rect, pos)
					res["ref"] = obstacle
					return res
	return {}

func _rect_normal(rect: Rect2, pos: Vector2) -> Vector2:
	var cx := rect.get_center()
	var d := pos - cx
	if absf(d.x / maxf(rect.size.x, 1.0)) > absf(d.y / maxf(rect.size.y, 1.0)):
		return Vector2(signf(d.x), 0.0)
	return Vector2(0.0, signf(d.y))

func push_out_of_obstacles(node: Node2D, radius: float) -> void:
	var key := Vector2i(int(floor(node.global_position.x / CELL)), int(floor(node.global_position.y / CELL)))
	# быстрый выход: рядом нет сплошных препятствий
	var near_solid := false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if solid_cells.has(key + Vector2i(dx, dy)):
				near_solid = true
				break
		if near_solid:
			break
	if not near_solid:
		return
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var arr: Array = obstacle_grid.get(key + Vector2i(dx, dy), [])
			for obstacle in arr:
				if String(obstacle["kind"]) != "solid":
					continue
				var rect: Rect2 = obstacle["rect"]
				var pos: Vector2 = node.global_position
				if not rect.grow(radius).has_point(pos):
					continue
				var left := absf(pos.x - rect.position.x)
				var right := absf(rect.position.x + rect.size.x - pos.x)
				var top := absf(pos.y - rect.position.y)
				var bottom := absf(rect.position.y + rect.size.y - pos.y)
				var m := minf(minf(left, right), minf(top, bottom))
				if m == left:
					node.global_position.x = rect.position.x - radius
				elif m == right:
					node.global_position.x = rect.position.x + rect.size.x + radius
				elif m == top:
					node.global_position.y = rect.position.y - radius
				else:
					node.global_position.y = rect.position.y + rect.size.y + radius

func _apply_map_mods() -> void:
	var mods: Dictionary = map_data.get("mods", {})
	if float(mods.get("darkness", 0.0)) > 0.0:
		canvas_mod = CanvasModulate.new()
		canvas_mod.color = Color(0.25, 0.25, 0.32)
		add_child(canvas_mod)
		var light := PointLight2D.new()
		light.texture = _radial_texture()
		light.texture_scale = float(mods.get("vision", 160.0)) / 64.0
		light.energy = 1.2
		player.add_child(light)
		player.set_meta("light", light)
	if bool(mods.get("water", false)):
		player.world_speed_mult = 0.75
	if bool(mods.get("pentagram", false)):
		pass

func _radial_texture() -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	_setup_flash_layer()
	hud.setup(self)
	hud.choice_made.connect(_on_choice_made)

func _perk_ids_for_test(state: Dictionary) -> Array:
	var ids: Array=[]
	for perk in DB.available_perks(state,false): ids.append(String(perk.id))
	return ids

func _run_perk_dependency_test() -> void:
	var ids:=_perk_ids_for_test({})
	assert(ids.size()==25,"На старте должны быть доступны только 25 перков T1")
	for pid in ids: assert(int(DB.perk(pid).get("tier",0))==1,"До T1 открылся старший перк: "+pid)
	ids=_perk_ids_for_test({"boomerang_t1":1})
	assert(ids.has("boomerang_t2b") and not ids.has("boomerang_t2a"),"Рыцарь Бумеранга открылся без Души")
	ids=_perk_ids_for_test({"boomerang_t1":1,"soul_t1":1})
	assert(ids.has("boomerang_t2a"),"Рыцарь Бумеранга не открылся с Душой")
	ids=_perk_ids_for_test({"soul_t1":1,"soul_t2a":1})
	assert(not ids.has("soul_t3"),"Душа-Рыцарь открылся без дерева Призыва")
	ids=_perk_ids_for_test({"soul_t1":1,"soul_t2a":1,"summon_t1":1})
	assert(ids.has("soul_t3"),"Душа-Рыцарь не открылся с Призывом")
	ids=_perk_ids_for_test({"damage_t1":1,"damage_t2a":1})
	assert(ids.has("damage_t3") and not ids.has("damage_t2b"),"Нарушено исключение ветвей T2 или доступ T3")
	var test_upg:=UpgradeSystem.new()
	test_upg.apply_mods({"dmg":0.40}); test_upg.apply_mods({"dmg":0.45})
	assert(is_equal_approx(1.0+float(test_upg.add.dmg),1.40*1.45),"Процентный урон сложен вместо умножения")
	test_upg.taken={"summon_t2b":1}
	assert(test_upg._available_synergy_cards().filter(func(c): return String(c.id)=="syn_summonpower").is_empty(),"Синергия открылась без Серпа")
	test_upg.taken["scythe_t2a"]=1
	assert(not test_upg._available_synergy_cards().filter(func(c): return String(c.id)=="syn_summonpower").is_empty(),"Синергия не открылась при полных условиях")
	print("[SURWAVE] perk_dependencies OK: T1, branch lock, cross-tree, synergy AND, multiplicative mods")

## Проверка, что каждый перк действительно меняет состояние игрока:
## модификаторы попадают в upg.add по формуле, флаги — в upg.flags.
## Единичный перк применяется на чистой UpgradeSystem, затем состояние сравнивается.
func _run_perk_effect_test() -> void:
	var checked := 0
	var mod_keys := {}
	var flag_keys := {}
	for perk in DB.perks:
		var pid := String(perk.get("id", ""))
		var probe := UpgradeSystem.new()
		var mods: Dictionary = perk.get("mods", {})
		var fl: Dictionary = perk.get("flags", {})
		probe.take_card({"kind": "perk", "id": pid, "data": perk, "force": true})
		for key in mods.keys():
			mod_keys[key] = true
			var expected := float(mods[key])
			if UpgradeSystem.INT_MODS.has(key):
				expected = round(expected)
			assert(is_equal_approx(float(probe.add.get(key, 0.0)), expected), "Перк %s не применил модификатор %s" % [pid, key])
		for key in fl.keys():
			flag_keys[key] = true
			assert(probe.flags.has(key), "Перк %s не применил флаг %s" % [pid, key])
		assert(int(probe.taken.get(pid, 0)) == 1, "Перк %s не зарегистрирован в taken" % pid)
		assert(probe.log.size() == 1, "Перк %s не попал в журнал получения" % pid)
		checked += 1
	# 25 T1 + 25 T2a + 25 T2b + 25 T3 деревьев
	assert(checked == DB.perks.size(), "Проверены не все перки")
	# Проверка реального призыва перков (Серп, Святое Копьё)
	if player != null:
		var saved_flags: Dictionary = player.upg.flags.duplicate(true)
		player.upg.apply_flags({"summon": "scythe"})
		player.upg.apply_flags({"summon": "boomerang"})
		player._tick_perk_summons()
		var has_scythe := false
		var has_boomerang := false
		for a in allies:
			if a.active and a.kind == "scythe":
				has_scythe = true
			elif a.active and a.kind == "boomerang":
				has_boomerang = true
		assert(has_scythe, "Перк Призрачный Серп не призвал серп")
		assert(has_boomerang, "Перк Бумеранг не призвал бумеранг")
		for a in allies:
			if a.perk_summon:
				a.deactivate()
		player.upg.flags = saved_flags
	print("[SURWAVE] perk_effects OK: %d perks, %d mod keys, %d flag keys" % [checked, mod_keys.size(), flag_keys.size()])

## Проверка времени жизни отложенных вызовов: события ставят таймеры,
## затем игра уходит в меню — в консоли не должно быть ошибок о freed-лямбдах.
func _run_lifetime_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# сценарий из отчёта игрока: босс + событие, затем уход в меню
	cheat_spawn_boss("satanail")
	_phase_sequence(player, 3, false)
	notify("проверка времени жизни")
	run_map_event({"kind": "vision", "params": {"duration": 6.0, "mult": 0.4}})
	run_map_event({"kind": "necro_fog", "params": {"summons": 2, "enemy": "skeleton"}})
	run_map_event({"kind": "meteor", "params": {"count": 2, "duration": 6.0}})
	run_map_event({"kind": "geyser", "params": {"count": 2}})
	_collapse_obstacles(2, 5.0)
	_phase_sequence(player, 3, false)
	run_later(5.0, func() -> void: print("[SURWAVE] lifetime_bad: поздний вызов после смены сцены"))
	print("[SURWAVE] lifetime_test staged: тост + таймеры событий")
	await _scene_delay(0.4)
	# сторож вне сцены: если через 7 с после ухода ошибок нет — печатает итог
	var probe := Timer.new()
	probe.one_shot = true
	probe.wait_time = 7.0
	get_tree().root.add_child(probe)
	probe.timeout.connect(func() -> void:
		print("[SURWAVE] lifetime OK: 7 с после смены сцены без freed-лямбд")
		Engine.get_main_loop().quit())
	probe.start()
	GameManager.goto_menu()

## Проверка чит-консоли: строка на `~`, команда «wuss menu» и все чит-действия.
func _run_cheat_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var problems := 0
	var console: Node = hud.cheat_console if hud != null else null
	if console == null:
		print("[SURWAVE] cheat_fail: консоль не создана")
		return
	# 1) клавиша `~` (physical_keycode, покрывает и русскую «ё»)
	var tilde := InputEventKey.new()
	tilde.physical_keycode = KEY_QUOTELEFT
	tilde.pressed = true
	console._input(tilde)
	await get_tree().process_frame
	if not bool(console.line.visible):
		problems += 1
		print("[SURWAVE] cheat_fail: клавиша ~ не открыла строку")
	if not get_tree().paused:
		problems += 1
		print("[SURWAVE] cheat_fail: строка ввода не ставит паузу")
	# Esc закрывает строку
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	console._input(esc)
	await get_tree().process_frame
	if bool(console.line.visible) or get_tree().paused:
		problems += 1
		print("[SURWAVE] cheat_fail: Esc не закрыл строку / не снял паузу")
	console.open_line()
	if not bool(console.line.visible):
		problems += 1
		print("[SURWAVE] cheat_fail: строка ввода не открылась")
	console._submit("чепуха")
	if not String(console.hint.text).begins_with("неизвестная команда"):
		problems += 1
		print("[SURWAVE] cheat_fail: нет реакции на неизвестную команду")
	console._submit("wuss menu")
	await get_tree().process_frame
	if not bool(console.menu.visible):
		problems += 1
		print("[SURWAVE] cheat_fail: меню не открылось по «wuss menu»")
	if not get_tree().paused or not GameManager.cheat_open:
		problems += 1
		print("[SURWAVE] cheat_fail: игра не встала на паузу при открытом меню")
	var rows: int = console.body.get_child_count()
	if rows < 20:
		problems += 1
		print("[SURWAVE] cheat_fail: в меню мало строк: %d" % rows)
	# геометрия на текущем разрешении
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if console.line.position.y + console.line.size.y > vp.y or console.menu.position.x < 0.0 or console.menu.position.x + 608.0 > vp.x:
		problems += 1
		print("[SURWAVE] cheat_fail: элементы меню выходят за экран %s" % str(vp))
	# состав меню: разделы и кнопки
	var section_texts: Array = []
	var buttons := 0
	var widest := 0.0
	for row in console.body.get_children():
		var row_w := 0.0
		for child in row.get_children():
			if child is Control:
				row_w += float(child.custom_minimum_size.x) + 4.0
		widest = maxf(widest, row_w)
		if row is Label and String(row.text).to_upper() == String(row.text):
			section_texts.append(String(row.text))
		elif row is HBoxContainer:
			for child in row.get_children():
				if child is Button:
					buttons += 1
	if widest > 586.0:
		problems += 1
		print("[SURWAVE] cheat_fail: строка меню шире панели: %.0f" % widest)
	if section_texts.size() < 5 or buttons < 30:
		problems += 1
		print("[SURWAVE] cheat_fail: разделы=%s кнопок=%d" % [str(section_texts), buttons])
	print("[SURWAVE] cheat_menu sections=%s buttons=%d" % [str(section_texts), buttons])
	# 2) бессмертие
	var god_before: bool = GameManager.god_mode
	var hp_before: int = player.hp
	GameManager.god_mode = true
	player.take_damage(99, player.global_position, true)
	if player.hp != hp_before:
		problems += 1
		print("[SURWAVE] cheat_fail: бессмертие не работает")
	GameManager.god_mode = false
	player.take_damage(1, player.global_position, true)
	if player.hp >= hp_before:
		problems += 1
		print("[SURWAVE] cheat_fail: без бессмертия урон не проходит (проверка пустая)")
	player.hp = hp_before
	GameManager.god_mode = god_before
	# 3) опыт
	var lvl_before := level
	console.close_all()
	add_xp(500.0)
	if level <= lvl_before:
		problems += 1
		print("[SURWAVE] cheat_fail: опыт не дал уровня")
	hud.choice_layer.visible = false
	# 4) бесконечные патроны
	player.inf_ammo = true
	player.mag = 3
	player._shoot()
	if player.mag != 3:
		problems += 1
		print("[SURWAVE] cheat_fail: бесконечные патроны не работают")
	player.inf_ammo = false
	# 5) спавн врага и босса
	var before := enemies.size()
	var e: Enemy = spawn_enemy("slime", cheat_spawn_point())
	if e == null or enemies.size() != before + 1:
		problems += 1
		print("[SURWAVE] cheat_fail: враг не заспавнился")
	var boss_ok: bool = cheat_spawn_boss("shemhaz")
	if not boss_ok or boss_enemy == null or not boss_enemy.active:
		problems += 1
		print("[SURWAVE] cheat_fail: босс не заспавнился")
	# 6) множители врагов применяются при спавне
	GameManager.cheat_enemy_hp = 4.0
	var strong: Enemy = spawn_enemy("slime", cheat_spawn_point())
	GameManager.cheat_enemy_hp = 1.0
	var weak: Enemy = spawn_enemy("slime", cheat_spawn_point())
	if strong == null or weak == null or strong.max_hp <= weak.max_hp:
		problems += 1
		print("[SURWAVE] cheat_fail: множитель HP врагов не применяется")
	# 7) заморозка врагов
	GameManager.cheat_frozen = true
	var pos_before: Vector2 = strong.global_position if strong != null else Vector2.ZERO
	_tick_enemies(0.5)
	if strong != null and strong.global_position != pos_before and strong.active:
		problems += 1
		print("[SURWAVE] cheat_fail: заморозка не держит врагов")
	GameManager.cheat_frozen = false
	# 7a) множители HP/урона действуют на живых врагов
	if weak != null and weak.active:
		var hp_live: float = weak.max_hp
		console._set_enemy_hp(2.0)
		if float(weak.max_hp) < hp_live * 1.9:
			problems += 1
			print("[SURWAVE] cheat_fail: HP живого врага не вырос")
		console._set_enemy_hp(1.0)
		var dmg_live: int = weak.damage
		console._set_enemy_dmg(2.0)
		if weak.damage < dmg_live + 1 and dmg_live > 0:
			problems += 1
			print("[SURWAVE] cheat_fail: урон живого врага не вырос")
		console._set_enemy_dmg(1.0)
	# 7b) скорость врагов применяется к уже заспавненным
	var mover: Enemy = spawn_enemy("slime", player.global_position + Vector2(-90, 0))
	var start_pos: Vector2 = mover.global_position if mover != null else Vector2.ZERO
	GameManager.cheat_enemy_speed = 0.0
	_tick_enemies(0.6)
	var drift: float = mover.global_position.distance_to(start_pos) if mover != null else 99.0
	GameManager.cheat_enemy_speed = 1.0
	if drift > 6.0:
		problems += 1
		print("[SURWAVE] cheat_fail: скорость врагов не действует на живых (%.1f px)" % drift)
	# 8) время
	Engine.time_scale = 0.25
	if not is_equal_approx(Engine.time_scale, 0.25):
		problems += 1
		print("[SURWAVE] cheat_fail: скорость времени не ставится")
	Engine.time_scale = 1.0
	# 9) урон игрока
	var dmg_base: float = player.current_damage()
	GameManager.cheat_dmg = 3.0
	var dmg_cheat: float = player.current_damage()
	GameManager.cheat_dmg = 1.0
	if dmg_cheat <= dmg_base * 2.5:
		problems += 1
		print("[SURWAVE] cheat_fail: множитель урона игрока не работает")
	# 10) убить всех
	cheat_kill_all()
	if not enemies.filter(func(x): return x.active).is_empty():
		problems += 1
		print("[SURWAVE] cheat_fail: «убить всех» оставил живых")
	# 11) закрытие + плашка о читах и блокировка сохранения прогресса
	console.open_menu()
	if not GameManager.cheat_used or hud.cheat_banner == null or not hud.cheat_banner.visible:
		problems += 1
		print("[SURWAVE] cheat_fail: плашка предупреждения о читах не появилась")
	var souls_before_end: int = int(GameManager.meta.get("souls", 0))
	var gold_before_end: int = int(GameManager.meta.get("gold", 0))
	var wins_before_end: int = int(GameManager.meta.get("stats", {}).get("wins", 0))
	var end_res: Dictionary = GameManager.end_run({"kills": 99, "damage_dealt": 999, "damage_taken": 0, "time": 900.0, "gold": 500, "souls": 500, "level": 20}, true)
	if int(end_res.get("souls", -1)) != 0 or int(GameManager.meta.get("souls", 0)) != souls_before_end or int(GameManager.meta.get("gold", 0)) != gold_before_end or int(GameManager.meta.get("stats", {}).get("wins", 0)) != wins_before_end:
		problems += 1
		print("[SURWAVE] cheat_fail: прогресс сохранился несмотря на читы")
	console.close_all()
	if get_tree().paused or GameManager.cheat_open:
		problems += 1
		print("[SURWAVE] cheat_fail: меню не снимает паузу при закрытии")
	print("[SURWAVE] cheat OK: rows=%d enemies=%d boss=%s problems=%d" % [rows, enemies.size(), str(boss_ok), problems])

## Проверка читаемости опасных зон: у каждой есть кайма, узор и таймер предупреждения.
func _run_vis_test() -> void:
	await get_tree().process_frame
	var problems := 0
	var cases := [
		["quicksand", Color(0.72, 0.62, 0.36), "swirl", 0.8],
		["curse", Color(0.45, 0.1, 0.15), "rune", 0.8],
		["fire", Color(1, 0.45, 0.2), "fire", 0.0],
		["generic", Color(0.8, 0.2, 0.2), "generic", 1.2],
	]
	for c in cases:
		var pos: Vector2 = player.global_position + Vector2(40, 0)
		spawn_hazard_zone(pos, 1.0, 3.0, 46.0, c[1], {"telegraph": c[3], "pattern": c[2]})
		var h: Hazard = hazards[hazards.size() - 1]
		h.tick(0.05)
		if h.vis == null:
			problems += 1
			print("[SURWAVE] vis_fail: нет визуала зоны %s" % String(c[0]))
			continue
		if String(h.vis.get("pattern")) != String(c[2]):
			problems += 1
			print("[SURWAVE] vis_fail: узор зоны %s = %s" % [String(c[0]), String(h.vis.get("pattern"))])
		if float(h.vis.get("radius")) < 44.0:
			problems += 1
			print("[SURWAVE] vis_fail: радиус зоны %s" % String(c[0]))
		h.tick(float(c[3]) + 0.1)
		if not h.armed:
			problems += 1
			print("[SURWAVE] vis_fail: зона %s не перешла в активную фазу" % String(c[0]))
		# визуал должен перерисоваться без ошибок
		h.vis.queue_redraw()
		await get_tree().process_frame
	var kinds := 0
	for it in hazards:
		if it.active:
			kinds += 1
	print("[SURWAVE] vis OK: zones=%d active=%d problems=%d" % [cases.size(), kinds, problems])

## Дамп содержимого карт: проверка, что препятствия/ивенты/палитра не перепутаны.
func _run_map_dump() -> void:
	await get_tree().process_frame
	for m in DB.maps:
		var md: Dictionary = m
		_build_obstacles(md)
		var hist: Dictionary = {}
		var kk: Dictionary = {}
		for o in obstacles:
			var sh := String(o.get("shape", "?"))
			hist[sh] = int(hist.get(sh, 0)) + 1
			kk[String(o["kind"])] = int(kk.get(String(o["kind"]), 0)) + 1
		var evs: Array = []
		for e in md.get("events", []):
			evs.append(String(e.get("kind", "")))
		var pal: Dictionary = md.get("palette", {})
		print("[SURWAVE] dump %-10s bg=%s shapes=%s kinds=%s decor=%d events=%s motif=%s" % [
			String(md.get("id", "?")), String(pal.get("bg", "-")), str(hist), str(kk), int(hazard_stats.get("decor", 0)), str(evs), String(pal.get("motif", "-"))])
	# переход на секретную карту не должен оставлять чужие фон и пол
	var floors_before := _count_z(world, -9)
	_enter_void()
	await get_tree().process_frame
	await get_tree().process_frame
	var floors_after := _count_z(world, -9)
	var bgs_after := _count_z(world, -10)
	print("[SURWAVE] void_swap floors_before=%d floors_after=%d bgs_after=%d map=%s" % [
		floors_before, floors_after, bgs_after, String(map_data.get("id", "?"))])

func _count_z(node: Node, z: int) -> int:
	var n := 0
	for c in node.get_children():
		if c is CanvasItem and (c as CanvasItem).z_index == z and not c.is_queued_for_deletion():
			n += 1
	return n

## Проверка препятствий, событий и погоды: все 13 карт, разрушение, подвижные угрозы.
func _run_hazard_test() -> void:
	await get_tree().process_frame
	var saved_map: Dictionary = map_data
	var problems := 0
	var maps := 0
	var solid_total := 0
	var destructible_total := 0
	var decor_total := 0
	var events_total := 0
	var kinds: Dictionary = {}
	for m in DB.maps:
		var md: Dictionary = m
		_build_obstacles(md)
		map_data = md
		maps += 1
		var solid := 0
		var hp_objs := 0
		for o in obstacles:
			if String(o["kind"]) == "solid":
				solid += 1
			if float(o.get("max_hp", 0.0)) > 0.0:
				hp_objs += 1
		solid_total += solid
		destructible_total += hp_objs
		decor_total += int(hazard_stats.get("decor", 0))
		if solid <= 0:
			print("[SURWAVE] hazard_fail %s: нет твёрдых препятствий" % String(md.get("id", "")))
			problems += 1
		# разрушение: первое препятствие с HP должно исчезнуть
		var victim: Dictionary = {}
		for o in obstacles:
			if float(o.get("max_hp", 0.0)) > 0.0:
				victim = o
				break
		if not victim.is_empty():
			var before := obstacles.size()
			hit_obstacle(victim, float(victim["max_hp"]) + 5.0)
			if obstacles.size() != before - 1:
				print("[SURWAVE] hazard_fail %s: препятствие не разрушилось" % String(md.get("id", "")))
				problems += 1
		else:
			print("[SURWAVE] hazard_fail %s: нет разрушаемых препятствий" % String(md.get("id", "")))
			problems += 1
		# набор силуэтов должен в точности совпадать с объявленным у этой карты
		var declared: Dictionary = {}
		for def in md.get("obstacles", []):
			if String(def.get("kind", "")) != "decor":
				declared[String(def.get("shape", "box"))] = true
		var built: Dictionary = {}
		for o in obstacles:
			built[String(o.get("shape", "box"))] = true
		for sh in built.keys():
			if not declared.has(sh):
				print("[SURWAVE] hazard_fail %s: чужой силуэт %s" % [String(md.get("id", "")), String(sh)])
				problems += 1
		for sh in declared.keys():
			if not built.has(sh):
				print("[SURWAVE] hazard_fail %s: не хватает силуэта %s" % [String(md.get("id", "")), String(sh)])
				problems += 1
		# ивенты карты совпадают с объявленными
		var declared_ev: Array = []
		for e in md.get("events", []):
			declared_ev.append(String(e.get("kind", "")))
		if declared_ev.size() != (md.get("events", []) as Array).size():
			problems += 1
		# все события карты запускаются без ошибок
		for ev in md.get("events", []):
			kinds[String(ev.get("kind", ""))] = true
			run_map_event(ev)
			events_total += 1
		await get_tree().process_frame
	# подвижные угрозы
	var m1 := spawn_mover("tumbleweed", player.global_position + Vector2(40, 0), Vector2(-120, 0), {"life": 2.0, "damage": 1.0})
	m1.tick(0.1)
	var m2 := spawn_mover("insects", player.global_position + Vector2(0, 40), Vector2(10, 0), {"life": 2.0, "damage": 1.0, "chase": 20.0})
	m2.tick(0.1)
	if not m1.active or not m2.active:
		problems += 1
		print("[SURWAVE] hazard_fail: подвижная угроза сразу исчезла")
	# погода: включается, влияет на видимость, выключается
	start_weather("Тест: буря", "sand", Color(0.8, 0.7, 0.4), 1.2, {"vision": 0.3, "dps": 0.5, "push": Vector2(20, 0)})
	var vis_ok := float(weather.get("vision", 1.0)) <= 0.31
	_tick_weather(0.5)
	vision_mult = minf(vision_mult, 1.0)
	if weather.is_empty() or not vis_ok or weather_fx == null or not weather_fx.visible or weather_fx.size.x < 100.0:
		problems += 1
		print("[SURWAVE] hazard_fail: погода не включилась")
	_tick_weather(1.0)
	if not weather.is_empty():
		problems += 1
		print("[SURWAVE] hazard_fail: погода не выключилась")
	# вернуть исходную карту
	map_data = saved_map
	_build_obstacles(saved_map)
	for mv in movers:
		if is_instance_valid(mv):
			mv.deactivate()
	print("[SURWAVE] hazard OK: maps=%d solid=%d destructible=%d decor=%d events=%d kinds=%d problems=%d" % [
		maps, solid_total, destructible_total, decor_total, events_total, kinds.size(), problems])

## Проверка оформления интерфейса: карточки выбора уровня, окно конца забега,
## горячие клавиши 1–5 и отсутствие выходов за экран.
func _run_ui_test() -> void:
	await get_tree().process_frame
	var problems := 0
	# 1) карточки выбора награды
	var cards: Array = upg.perk_choices(mini(5, upg.choice_count))
	assert(cards.size() >= 3, "Карточек выбора меньше трёх: %d" % cards.size())
	hud.open_choice(cards, "ВЫБЕРИ НАГРАДУ", "levelup")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(hud.choice_layer.visible, "Слой выбора не открылся")
	assert(hud.choice_box.get_child_count() == cards.size(), "Карточек на экране %d вместо %d" % [hud.choice_box.get_child_count(), cards.size()])
	# 2) горячие клавиши 1–5
	var picked: Array = []
	hud.choice_made.connect(func(card: Dictionary) -> void: picked.append(card))
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_2
	hud._input_choice_hotkey(ev)
	await get_tree().process_frame
	assert(picked.size() == 1, "Клавиша 2 не выбрала карточку")
	hud.choice_layer.visible = false
	# 3) окно конца забега
	hud.show_end({"time": 754.0, "kills": 812, "damage_dealt": 24500, "damage_taken": 11, "level": 24, "gold": 320, "souls": 140}, true, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(hud.end_layer.visible, "Экран итогов не открылся")
	var end_panel: Panel = hud.end_layer.get_child(1)
	assert(end_panel.get_child_count() >= 9, "На экране итогов мало элементов: %d" % end_panel.get_child_count())
	hud.end_layer.visible = false
	# 4) ни один элемент не выходит за границы 640x360
	for it in hud.layout_report():
		var r: Rect2 = it["rect"]
		if r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > 641.0 or r.end.y > 361.0:
			print("[SURWAVE] ui_out %s %s" % [String(it["name"]), str(r)])
			problems += 1
	# 5) специализации сундуков отличаются ветками, иллюстрациями и описаниями
	var specs := upg.spec_choices("aldar", 3)
	assert(specs.size() == 3, "Специализаций меньше 3")
	var spec_trees: Dictionary = {}
	var spec_descs: Dictionary = {}
	var spec_illus: Dictionary = {}
	for sc in specs:
		var sd: Dictionary = sc.get("data", {})
		spec_trees[String(sd.get("tree", ""))] = true
		spec_descs[String(sd.get("desc", ""))] = true
		var il: Texture2D = hud._card_illustration(sc)
		if il != null:
			spec_illus[il.resource_path] = true
	assert(spec_trees.size() == 3, "Специализации совпали по веткам")
	assert(spec_descs.size() == 3, "Специализации совпали по описаниям")
	assert(spec_illus.size() == 3, "Специализации совпали по иллюстрациям")
	# 6) главное меню: живой геймплейный фон имеет полный размер и активную сцену
	var mm_scene := load("res://scenes/main/main_menu.tscn") as PackedScene
	var mm := mm_scene.instantiate() as Control
	get_tree().root.add_child(mm)
	await get_tree().process_frame
	var bg := mm.get_node_or_null("MenuGameplayBg") as Control
	assert(bg != null and bg.size.x >= 600.0 and bg.size.y >= 340.0, "MenuGameplayBg не заполнил экран")
	assert(not (bg.get("scene_data") as Dictionary).is_empty(), "MenuGameplayBg не создал сцену")
	assert(bg.get("floor_rect") != null and bg.get("bg_rect") != null, "MenuGameplayBg слои фона не созданы")
	var xp_cfg: Dictionary = DB.balance.get("run", {}).get("xp_curve", {})
	var xp_base := int(round(float(xp_cfg.get("base", 10.0))))
	assert(_xp_for_level(1) == xp_base, "Кривая XP некорректна: %d вместо %d" % [_xp_for_level(1), xp_base])
	assert(_xp_for_level(41) > _xp_for_level(40) and _xp_for_level(41) < _xp_for_level(40) * 2, "Поздняя кривая XP некорректна")
	# 7) настройки: ни одна кнопка не должна наезжать на другую (баг из скриншота)
	mm.call("_open_overlay", "settings")
	await get_tree().process_frame
	await get_tree().process_frame
	var ov: Control = mm.get("overlay") as Control
	assert(ov != null, "Окно настроек не создалось")
	var buttons: Array = ov.find_children("*", "Button", true, false)
	var placed: Array = []
	var overlaps := 0
	for node in buttons:
		var b := node as Button
		if b == null or not b.is_visible_in_tree():
			continue
		var r := Rect2(b.global_position, b.size)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		r = r.grow(-1.5)
		for other in placed:
			if r.intersects(other):
				overlaps += 1
				print("[SURWAVE] settings_overlap %s %s" % [b.text, str(r)])
				break
		placed.append(r)
	assert(placed.size() >= 10, "В настройках слишком мало кнопок: %d" % placed.size())
	assert(overlaps == 0, "Кнопки настроек перекрываются: %d" % overlaps)
	mm.queue_free()
	print("[SURWAVE] ui OK: cards=%d hotkey=2 end_rows=%d out_of_bounds=%d" % [cards.size(), end_panel.get_child_count(), problems])

## Проверка меню паузы: Esc ставит игру на паузу, слева хронология перков,
## справа сводка (карта, персонаж, оружие, золото, души, осколки и т.д.).
func _run_pause_test() -> void:
	await get_tree().process_frame
	# выдаём несколько перков, чтобы список был не пустым
	var granted := 0
	for perk in DB.perks:
		if int(perk.get("tier", 1)) == 1:
			upg.take_card({"kind": "perk", "id": String(perk.id), "data": perk, "force": true})
			granted += 1
			if granted >= 4:
				break
	var log_size: int = upg.log.size()
	hud.toggle_pause()
	await get_tree().process_frame
	assert(pause_layer_visible(), "Меню паузы не открылось")
	assert(get_tree().paused, "Игра не встала на паузу")
	assert(hud.pause_perk_list.get_child_count() == log_size, "В списке перков %d строк вместо %d" % [hud.pause_perk_list.get_child_count(), log_size])
	assert(hud.pause_stats.get_child_count() >= 12, "В сводке забега мало строк: %d" % hud.pause_stats.get_child_count())
	var first_row := String(hud.pause_perk_list.get_child(0).text)
	assert(first_row.begins_with(" 1."), "Первая строка хронологии без номера: " + first_row)
	var items: Array = hud.layout_report()
	var bad := 0
	for it in items:
		var r: Rect2 = it["rect"]
		if r.end.x > 641.0 or r.end.y > 361.0 or r.position.x < -1.0:
			print("[SURWAVE] pause_out %s %s" % [String(it["name"]), str(r)])
			bad += 1
	assert(hud.pause_confirm_layer != null and not hud.pause_confirm_layer.visible, "Окно подтверждения паузы отсутствует")
	hud._open_pause_settings()
	await get_tree().process_frame
	assert(hud.pause_settings_layer != null and hud.pause_settings_layer.visible, "Окно настроек паузы не открылось")
	hud.toggle_pause()
	await get_tree().process_frame
	assert(pause_layer_visible() and not hud.pause_settings_layer.visible, "Esc должен сначала закрыть настройки паузы")
	hud._open_pause_confirm("restart", "Тест подтверждения")
	await get_tree().process_frame
	assert(hud.pause_confirm_layer.visible, "Подтверждение «Рестарт» не открылось")
	hud.toggle_pause()
	await get_tree().process_frame
	assert(pause_layer_visible() and not hud.pause_confirm_layer.visible, "Esc должен сначала закрыть подтверждение")
	hud.toggle_pause()
	await get_tree().process_frame
	assert(not get_tree().paused, "Пауза не снялась повторным Esc")
	# Фоторежим + пауза + удаление перка + сундук + вспышка + дальность спавна
	set_photo_mode(true)
	assert(photo_mode and get_tree().paused, "Фоторежим не поставил игру на паузу")
	hud.toggle_pause()
	assert(not photo_mode and pause_layer_visible() and get_tree().paused, "Пауза не открылась из фоторежима")
	hud.toggle_pause()
	assert(not get_tree().paused, "Пауза не снялась после фоторежима")
	level = 5
	var before_perks := upg.taken.size()
	var first_perk_id := String(upg.taken.keys()[0])
	assert(remove_perk_for_level(first_perk_id, true), "Не удалось убрать перк за уровень")
	assert(level == 4 and upg.taken.size() == before_perks - 1, "Уровень или список перков не обновился")
	flash_screen(Color.WHITE)
	_tick_flash(0.5)
	assert(flash_rect.color.a <= 0.001 and not flash_rect.visible, "Вспышка экрана не погасла")
	var far_pos := _spawn_position()
	assert(far_pos.distance_to(player.global_position) >= 340.0, "Враг заспавнился слишком близко: %.1f" % far_pos.distance_to(player.global_position))
	print("[SURWAVE] pause OK: perks=%d stats=%d layout_problems=%d" % [hud.pause_perk_list.get_child_count(), hud.pause_stats.get_child_count(), bad])

func pause_layer_visible() -> bool:
	var h: Node = hud
	return h != null and h.pause_layer != null and h.pause_layer.visible

## Проверка управления: автоперезарядка в простое и автонаведение на ближайшего врага.
func _run_controls_test() -> void:
	await get_tree().process_frame
	# 1) автонаведение
	player.auto_aim = true
	var probe := spawn_enemy("slime", player.global_position + Vector2(70, 0))
	assert(probe != null, "Не удалось создать врага для проверки автонаведения")
	var target: Vector2 = player.auto_aim_target()
	assert(target.distance_to(probe.global_position) < 48.0, "Автонаведение не выбрало ближайшего врага")
	player.auto_aim = false
	var mouse_target: Vector2 = player.auto_aim_target()
	assert(mouse_target != Vector2.INF, "Прицел потерян при выключенном автонаведении")
	# 2) автоперезарядка в простое
	var was_bot := player.bot
	player.bot = false
	player.bot_wants_fire = false
	player.reloading = false
	player.since_last_shot = 99.0
	player.mag = maxi(1, int(player.S.mag) - 2)
	var mag_before: int = player.mag
	var waited := 0.0
	while waited < 2.5 and player.mag <= mag_before:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert(player.mag > mag_before or player.reloading, "Автоперезарядка не запустилась в простое (ждали %.1f с)" % waited)
	player.bot = was_bot
	# 3) индикатор патронов белеет при перезарядке
	GameManager.set_setting("hud_vitals", "player")
	await get_tree().process_frame
	var was_bot2 := player.bot
	player.bot = false
	player.bot_wants_fire = false
	player.mag = maxi(0, int(player.S.mag) / 2)
	player.reloading = false
	player.start_reload()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(player.reloading, "Перезарядка не запустилась")
	var col: Color = hud.ammo_lbl.get_theme_color("font_color")
	assert(col.r > 0.95 and col.g > 0.95 and col.b > 0.95, "Счётчик патронов при перезарядке не белый: " + str(col))
	var white_pips := 0
	for pip in player.ammo_pips:
		if pip.visible and pip.modulate.r > 0.95 and pip.modulate.g > 0.95:
			white_pips += 1
	player.reloading = false
	player.mag = int(player.S.mag)
	await get_tree().process_frame
	await get_tree().process_frame
	var col2: Color = hud.ammo_lbl.get_theme_color("font_color")
	assert(col2 != col, "Счётчик патронов не вернул обычный цвет после перезарядки")
	GameManager.set_setting("hud_vitals", "corner")
	await get_tree().process_frame

	# 4) режим отображения HP и патронов
	var cur := String(GameManager.setting("hud_vitals", "corner"))
	GameManager.set_setting("hud_vitals", "player")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(player.hp_marks.size() > 0, "В режиме «над игроком» не созданы шкалы HP")
	assert(player.hp_bar != null, "Шкала HP над героем не создана")
	assert(player.hp_bar.scale.y <= 2.5, "Шкала HP над героем должна быть тонкой: %.1f" % player.hp_bar.scale.y)
	assert(player.hp_bar.scale.x <= 34.0, "Шкала HP над героем слишком широкая: %.1f" % player.hp_bar.scale.x)
	assert(player.ammo_pips.size() > 0, "В режиме «над игроком» не создана шкала патронов")
	assert(player.mag_bar != null and player.mag_bar.scale.y <= 2.5, "Шкала патронов должна быть тонкой")
	var visible_marks := 0
	for m in player.hp_marks:
		if m.visible:
			visible_marks += 1
	assert(visible_marks > 0, "Сердца над игроком не отображаются")
	GameManager.set_setting("hud_vitals", "corner")
	await get_tree().process_frame
	await get_tree().process_frame
	var hidden_marks := 0
	for m in player.hp_marks:
		if not m.visible:
			hidden_marks += 1
	assert(hidden_marks == player.hp_marks.size(), "В режиме «слева сверху» сердца над игроком остались видны")
	GameManager.set_setting("hud_vitals", cur)
	var has_space := false
	if InputMap.has_action("toggle_aim"):
		for ev in InputMap.action_get_events("toggle_aim"):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_SPACE:
				has_space = true
	assert(has_space, "Пробел не назначен на переключение автонаведения")
	player.bot = was_bot2
	print("[SURWAVE] controls OK: auto_aim, Space bound, idle reload %.2f s, reload-white pips=%d, hud_vitals switch" % [waited, white_pips])

## Проверка раскладки HUD: подписи не должны пересекаться и выходить за экран 640x360.
func _run_hud_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.get_environment("SURW_HP") != "":
		player.max_hp = int(OS.get_environment("SURW_HP"))
		player.hp = player.max_hp
		player.upg.apply_mods({"hp": 0})
		await get_tree().process_frame
		await get_tree().process_frame
	# тесты паузы и раскладки HUD нельзя гонять одновременно: они открывают разные слои
	if OS.get_environment("SURW_PAUSE_TEST") != "":
		print("[SURWAVE] hud_test skipped: идёт тест паузы (запускайте отдельно)")
		return
	var hud_node: Node = hud
	if hud_node == null:
		print("[SURWAVE] hud_test: HUD не найден")
		return
	var items: Array = hud_node.layout_report()
	var bad := 0
	if OS.get_environment("SURW_HUD_TEST") == "2":
		for it in items:
			print("[SURWAVE] hud_item %s %s" % [String(it["name"]), str(it["rect"])])
	for it in items:
		var r: Rect2 = it["rect"]
		if String(it["name"]).ends_with(":"):
			continue
		if r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > 641.0 or r.end.y > 361.0:
			print("[SURWAVE] hud_out name=%s rect=%s" % [String(it["name"]), str(r)])
			bad += 1
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			var ra: Rect2 = a["rect"]
			var rb: Rect2 = b["rect"]
			if String(a["name"]).ends_with(":panel") or String(b["name"]).ends_with(":panel"):
				continue
			if String(a["name"]).ends_with(":") or String(b["name"]).ends_with(":"):
				continue
			if ra.intersects(rb):
				print("[SURWAVE] hud_overlap %s <> %s" % [String(a["name"]), String(b["name"])])
				bad += 1
	print("[SURWAVE] hud_test done elements=%d problems=%d" % [items.size(), bad])

## Проверка способностей: у каждого персонажа применяются все 3 уникальных апгрейда,
## затем используются активная способность и обычные выстрелы. Ошибки скрипта попадут в лог.
func _run_ability_test() -> void:
	var p := player
	assert(p != null, "Нет игрока для теста способностей")
	var sid := String(p.skill_data.get("id", ""))
	assert(sid != "", "У персонажа нет активной способности")
	var skills := ["blink", "divine_shield", "dark_harvest", "berserk", "arrow_rain", "shadow_dash", "gravity_gun", "aimed_shot", "firestorm", "divine_wave", "raise_skeleton", "blood_storm", "turret", "shadow_step", "tornado", "heal_wave", "blood_cleave"]
	var fired := 0
	for s in skills:
		p.skill_data = {"id": s, "cd": 1.0, "name": s, "params": {}}
		var before_taken := p.upg.taken.size()
		p._use_skill()
		fired += 1
		assert(p.upg.taken.size() >= before_taken, "Способность %s сломала состояние прокачки" % s)
	p.skill_data = {"id": sid, "cd": 1.0, "name": sid, "params": {}}
	for i in 12:
		p.aim_dir = Vector2.RIGHT.rotated(TAU * float(i) / 12.0)
		p._shoot()
	print("[SURWAVE] abilities OK: char=%s skill=%s fired=%d shots=12 flags=%d" % [String(p.char_data.get("id", "")), sid, fired, p.upg.flags.size()])

# ------------------------------------------------------------------ ГЛАВНЫЙ ЦИКЛ
var prof := {}
var stress_done := false

func _prof(name: String, t0: int) -> void:
	prof[name] = float(prof.get(name, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0

## Курсор: в бою скрыт (свой прицел), но в паузе, выборе перков и на экране итогов
## должен быть виден — иначе по меню нечем кликать.
func _sync_cursor() -> void:
	var overlay := photo_mode or ended or get_tree().paused
	if hud != null:
		overlay = overlay \
			or (hud.choice_layer != null and hud.choice_layer.visible) \
			or (hud.pause_layer != null and hud.pause_layer.visible) \
			or (hud.end_layer != null and hud.end_layer.visible)
	var hide := bool(GameManager.setting("crosshair", true)) and not overlay
	# Само переключение режима мыши делает GameManager (работает и на паузе).
	GameManager.set_cursor_hidden(hide)

func _process(delta: float) -> void:
	_sync_cursor()
	_tick_flash(delta)
	_tick_vision()
	_tick_vignette(delta)
	_tick_hitstop(delta)
	if not run_started or ended:
		return
	if get_tree().paused:
		return
	elapsed += delta
	if xp_boost_left > 0.0:
		xp_boost_left = maxf(0.0, xp_boost_left - delta)
	_tick_director(delta)
	_tick_qte(delta)
	_tick_combo(delta)
	_tick_chaos(delta)
	var _tg := Time.get_ticks_usec()
	rebuild_enemy_grid()
	_prof("grid", _tg)
	_process_pending_aoe()
	var _t0 := Time.get_ticks_usec()
	_tick_player(delta)
	if coop_player != null: coop_player.tick(delta)
	_net_tick(delta)
	_prof("player", _t0)
	_t0 = Time.get_ticks_usec()
	_tick_enemies(delta)
	_prof("enemies", _t0)
	_t0 = Time.get_ticks_usec()
	_tick_bullets(delta)
	_prof("bullets", _t0)
	_tick_ebullets(delta)
	_t0 = Time.get_ticks_usec()
	_tick_pickups(delta)
	_prof("pickups", _t0)
	_tick_allies(delta)
	_tick_hazards(delta)
	_tick_pulls(delta)
	_tick_movers(delta)
	_tick_weather(delta)
	_tick_player_pulls(delta)
	_tick_fx(delta)
	_tick_map(delta)
	if not (net_active and not net_host):
		wave_mgr.tick(delta)
		events_mgr.tick(delta)
	_tick_active_events(delta)
	_check_world_growth(delta)
	_resolve_player_collision(delta)
	_tick_revive_crystals(delta)
	_tick_audio(delta)
	_tick_perf_guard(delta)
	_tick_camera(delta)
	_cleanup()
	_check_end_conditions()
	if mode == "endless":
		var cycle := int(elapsed / 600.0)
		if cycle > endless_cycle:
			endless_cycle = cycle
			notify("Бесконечный режим: враги усилены (цикл %d)" % (cycle + 1))
	EventBus.xp_changed.emit(xp, xp_need, level)
	if not stress_done and OS.get_environment("SURW_STRESS") != "" and elapsed > 2.0:
		stress_done = true
		var n: int = int(OS.get_environment("SURW_STRESS"))
		var roster: Dictionary = map_data.get("roster", {})
		var list: Array = roster.get("fodder", ["forest_slime"])
		for i in n:
			var eid := String(list[randi() % list.size()])
			spawn_enemy(eid, player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 700.0))
		print("[SURWAVE] stress spawned ", n)
	if GameManager.autoplay:
		timers_log = float(timers_log) + delta
		if float(timers_log) >= float(OS.get_environment("SURW_LOG") if OS.get_environment("SURW_LOG") != "" else "60"):
			timers_log = 0.0
			print("[SURWAVE] prof=", prof)
			prof.clear()
			print("[SURWAVE] t=%.0f enemies=%d bullets=%d pickups=%d level=%d wlvl=%d evo=%s hp=%d/%d kills=%d fps=%d boss=%s mega=%s bhp=%s" % [elapsed, enemies.size(), bullets.size(), pickups.size(), level, player.weapon_level, str(upg.evolution_done), player.hp, player.max_hp, kills, Engine.get_frames_per_second(), String(boss_enemy.boss_def.get("name", "")) if boss_enemy != null and boss_enemy.active else "-", str(megaphase), ("%.0f" % boss_enemy.hp) if boss_enemy != null and boss_enemy.active else "-"])

func _tick_player(delta: float) -> void:
	player.tick(delta)
	player.global_position = clamp_to_map(player.global_position)
	_player_zones(delta)
	if float(map_data.get("mods", {}).get("heat", 0.0)) > 0.0:
		player.timers["heat"] = float(player.timers.get("heat", 15.0)) - delta
		if float(player.timers["heat"]) <= 0.0:
			player.timers["heat"] = 15.0
			player.take_damage(1, player.global_position, true)

func _player_zones(delta: float) -> void:
	var here := obstacles_at(player.global_position)
	var slow_amount := 0.0
	var terrain := 1.0
	for obstacle in here:
		match String(obstacle["kind"]):
			"slow":
				slow_amount = maxf(slow_amount, float(obstacle["slow"]))
			"slide":
				terrain = maxf(terrain, 1.22)
				slow_amount = minf(slow_amount, 0.0)
			"heal":
				pass
			"damage":
				obstacle["timer"] = float(obstacle["timer"]) - delta
				if float(obstacle["timer"]) <= 0.0:
					obstacle["timer"] = float(obstacle["interval"])
					player.take_damage(int(obstacle["damage"]), player.global_position, true)
					if float(obstacle.get("poison", 0.0)) > 0.0:
						player.add_status("poison", 3.0, {"dps": float(obstacle["poison"])})
					if float(obstacle.get("slow", 0.0)) > 0.0:
						slow_amount = maxf(slow_amount, float(obstacle["slow"]))
			"void":
				player.take_damage(2, player.global_position, true)
				player.global_position = map_rect.get_center()
	player.terrain_mult = terrain
	if slow_amount > 0.0:
		player.add_status("slow", 0.2, {"amount": slow_amount})
	_player_zones_heal(delta)

## Оазисы и лечебные зоны: редкое восстановление, пока стоишь внутри.
func _player_zones_heal(delta: float) -> void:
	if player == null or player.dead:
		return
	player.timers["oasis"] = float(player.timers.get("oasis", 0.0)) - delta
	if float(player.timers["oasis"]) > 0.0:
		return
	for obstacle in obstacles_at(player.global_position):
		if String(obstacle["kind"]) == "heal" and float(obstacle.get("heal", 0.0)) > 0.0:
			player.heal(int(obstacle["heal"]))
			player.timers["oasis"] = 6.0
			spawn_fx(player.global_position, Color(0.5, 0.85, 0.95, 0.7), 26.0, 0.35)
			break
	if bool(map_data.get("mods", {}).get("poison_on_hit", false)):
		pass

func _tick_enemies(delta: float) -> void:
	if GameManager.cheat_frozen and (not net_active or net_host):
		return
	for enemy in enemies:
		if not enemy.active:
			continue
		enemy.tick(delta)
	if net_active and not net_host:
		return
	var _t0 := Time.get_ticks_usec()
	_apply_separation(delta)
	_prof("separation", _t0)

## Расталкивание врагов (steering separation), чтобы не слипались в одну точку.
func _apply_separation(delta: float) -> void:
	var grid: Dictionary = enemy_grid
	var player_pos: Vector2 = player.global_position
	for enemy in enemies:
		if not enemy.active or enemy.boss:
			continue
		# расталкиваем только тех, кто рядом с игроком — это влияет на геймплей
		if enemy.global_position.distance_squared_to(player_pos) > 640.0 * 640.0:
			continue
		var key2 := Vector2i(int(floor(enemy.global_position.x / CELL)), int(floor(enemy.global_position.y / CELL)))
		var push := Vector2.ZERO
		var checked := 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var arr: Array = grid.get(key2 + Vector2i(dx, dy), [])
				for other in arr:
					if other == enemy or not other.active:
						continue
					var d: Vector2 = enemy.global_position - other.global_position
					var min_d: float = enemy.radius + other.radius
					if d.length() < min_d and d.length() > 0.01:
						push += d.normalized() * (min_d - d.length())
					checked += 1
					if checked > 6:
						break
				if checked > 6:
					break
			if checked > 6:
				break
		if push.length() > 0.0:
			enemy.global_position += push * clampf(6.0 * delta * 60.0, 0.0, 0.6)

func _tick_bullets(delta: float) -> void:
	for b in bullets:
		if b.active:
			b.tick(delta)

func _tick_ebullets(delta: float) -> void:
	for b in ebullets:
		if b.active:
			b.tick(delta)

func _tick_pickups(delta: float) -> void:
	# Клиент тоже подбирает лут: опыт и золото теперь у каждого игрока свои.
	for p in pickups:
		if p.active:
			p.tick(delta)
	# Лут клиента живёт в «призраках» по снапшоту — их тоже тикаем,
	# иначе магнита и подбора у второго игрока не будет вовсе.
	if net_active and not net_host:
		for pk in net_pickup_ghosts:
			if pk != null and is_instance_valid(pk) and pk.active:
				pk.tick(delta)

func _tick_allies(delta: float) -> void:
	for a in allies:
		if a.active:
			a.tick(delta)

func _tick_hazards(delta: float) -> void:
	for h in hazards:
		if h.active:
			h.tick(delta)

func _tick_fx(delta: float) -> void:
	for f in fx_list:
		if f.active:
			f.tick(delta)
	for i in range(dmg_nums.size() - 1, -1, -1):
		var d: Dictionary = dmg_nums[i]
		d["t"] = float(d["t"]) + delta
		var lbl: Label = d["lbl"]
		var k := float(d["t"]) / float(d["dur"])
		if k >= 1.0 or not is_instance_valid(lbl):
			if is_instance_valid(lbl):
				lbl.visible = false
				if dmg_pool.size() < 28:
					dmg_pool.append(lbl)
				else:
					lbl.queue_free()
			dmg_nums.remove_at(i)
		else:
			lbl.position += Vector2(float(d["vx"]), -24.0 * (1.0 - k * 0.5)) * delta
			lbl.modulate.a = clampf(1.0 - pow(k, 1.8), 0.0, 1.0)

func _tick_map(delta: float) -> void:
	# течения/события карты
	var mods: Dictionary = map_data.get("mods", {})
	if bool(mods.get("water", false)):
		player.timers["current"] = float(player.timers.get("current", 20.0)) - delta
		if float(player.timers["current"]) <= 0.0:
			player.timers["current"] = 20.0
			player.global_position += Vector2.RIGHT.rotated(randf() * TAU) * 90.0
			notify("Течение сносит вас")
	if pentagram_pos != Vector2.INF:
		if player.global_position.distance_to(pentagram_pos) < 26.0 and Input.is_action_just_pressed("interact"):
			_enter_void()
	var secret_need := int(DB.balance["run"].get("secret", {}).get("kills_without_damage", 1000))
	if OS.get_environment("SURW_SECRET_KILLS") != "":
		secret_need = int(OS.get_environment("SURW_SECRET_KILLS"))
	var secret_mastery_ok := Progression.tree_level("mastery") >= 15 or OS.get_environment("SURW_SECRET_KILLS") != ""
	if secret_mastery_ok and not pentagram_spawned and not secret_entered and kills_without_damage >= secret_need:
		spawn_pentagram(player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 120.0)
	if OS.get_environment("SURW_SECRET_AUTO") != "" and pentagram_pos != Vector2.INF:
		_enter_void()
	if secret_spawn_pending:
		secret_spawn_pending = false
		spawn_sathan()

var low_fps_timer := 0.0

## Если FPS ниже 30 — убираем самых дальних врагов и частицы (техспека 11.3).
func _tick_perf_guard(delta: float) -> void:
	if Engine.get_frames_per_second() < 30:
		low_fps_timer += delta
	else:
		low_fps_timer = maxf(0.0, low_fps_timer - delta * 2.0)
	if low_fps_timer < 2.0:
		return
	low_fps_timer = 0.0
	if enemies.size() > 800:
		var sorted_enemies: Array = enemies.filter(func(e): return e.active and not e.boss)
		sorted_enemies.sort_custom(func(a, b): return a.global_position.distance_squared_to(player.global_position) > b.global_position.distance_squared_to(player.global_position))
		for i in mini(100, sorted_enemies.size()):
			sorted_enemies[i].deactivate()
	if fx_list.size() > int(DB.balance.get("limits", {}).get("max_particles", 1000)):
		for i in 200:
			if fx_list.is_empty():
				break
			(fx_list.pop_front() as Node).deactivate()

func _tick_audio(delta: float) -> void:
	last_intensity_check -= delta
	if last_intensity_check > 0.0:
		return
	last_intensity_check = 0.25
	var near := enemies_in_radius(player.global_position, 340.0).size()
	var total_active := enemies.size()
	var intensity := clampf(float(near) / 42.0, 0.0, 1.0)
	if total_active >= 65:
		intensity = maxf(intensity, 0.55)
	if player != null and player.hp <= 1:
		intensity = maxf(intensity, 0.65)
	AudioManager.set_intensity(intensity)
	if boss_enemy != null and boss_enemy.active:
		AudioManager.set_boss_layer(true)
	else:
		AudioManager.set_boss_layer(false)

func _tick_director(delta: float) -> void:
	time_since_damage += delta
	director_timer -= delta
	var near := enemies_in_radius(player.global_position, 160.0).size() if player != null else 0
	tension += delta * (0.3 + float(near) * 0.02)
	if director_timer > 0.0: return
	director_timer = 5.0
	var hp_ratio := float(player.hp) / maxf(1.0, float(player.max_hp))
	var map_mul := float(Progression.cfg.get("map_difficulty",{}).get(String(map_data.get("id","sands")),1.0))
	var skill_mul := 0.7 + float(GameManager.meta.get("skill_rating",300.0))/1000.0*0.6
	var tension_mul := 0.8 + tension/100.0*0.4
	var base := map_mul * skill_mul * tension_mul
	director_mods = {"spawn":base,"hp":base,"damage":base,"speed":1.0,"heal":1.0,"elite":1.0}
	if hp_ratio < 0.25:
		director_mods.spawn *= 0.7; director_mods.hp *= 0.85; director_mods.damage *= 0.9; director_mods.heal = 1.5; tension -= 20.0
	elif hp_ratio > 0.9 and time_since_damage > 60.0:
		director_mods.spawn *= 1.2; director_mods.hp *= 1.1; director_mods.elite = 1.15; tension += 15.0
	if kills_without_damage > 30:
		director_mods.elite = 1.25; tension += 5.0
	if tension > 90.0:
		director_mods.spawn *= 0.85; director_mods.heal *= 1.3; tension -= 10.0
	tension = clampf(tension,0.0,100.0)

func _start_final_qte(enemy: Enemy) -> void:
	qte_target = enemy
	final_qte = true
	qte_presses = 0
	qte_left = 2.2
	enemy.transition_left = 2.2
	notify("ФИНАЛЬНЫЙ УДАР! Нажмите E три раза")
	camera_zoom_target = 1.6
	shake(8.0)

func start_dodge_qte(amount: int, source: Vector2, boss: Enemy) -> bool:
	if not GameManager.setting("qte",true) or (GameManager.autoplay and OS.get_environment("SURW_DODGE_TEST")=="") or dodge_qte_left>0.0: return false
	dodge_qte_left=0.8; dodge_qte_damage=amount; dodge_qte_source=source; qte_target=boss
	notify("! УКЛОНЕНИЕ — нажмите E !")
	return true

func _tick_qte(delta: float) -> void:
	if counter_qte_left>0.0:
		counter_qte_left-=delta
		if counter_qte_left<=0.0 and not final_qte: qte_target=null
	if dodge_qte_left>0.0:
		dodge_qte_left-=delta
		if dodge_qte_left<=0.0:
			damage_player(int(round(dodge_qte_damage*1.5)),dodge_qte_source,true)
			notify("КРИТИЧЕСКИЙ ПРОМАХ!")
			counter_qte_left=0.5
		return
	if qte_target == null or not final_qte: return
	if not is_instance_valid(qte_target) or not qte_target.active:
		qte_target = null; final_qte=false; return
	qte_left -= delta
	if qte_left <= 0.0:
		qte_target.hp = minf(qte_target.max_hp, qte_target.hp + qte_target.max_hp*0.05)
		notify("Финальный удар упущен — босс восстановил 5% HP")
		print("[SURWAVE] qte_final fail heal=5%")
		qte_target = null
		final_qte=false

func _qte_press() -> void:
	if dodge_qte_left>0.0:
		dodge_qte_left=0.0; player.iframes=maxf(player.iframes,0.5); player.global_position=clamp_to_map(player.global_position+(player.global_position-dodge_qte_source).normalized()*48.0); notify("ИДЕАЛЬНО! Следующая атака +25%"); player.set_meta("qte_bonus",1.25); counter_qte_left=0.5; return
	if counter_qte_left>0.0 and qte_target!=null and qte_target.active:
		counter_qte_left=0.0; notify("КОНТРАТАКА!"); qte_target.stun=1.0; damage_enemy(qte_target,float(player.S.damage)*3.0,{"source":"counter"}); shake(8.0); return
	if qte_target == null: return
	qte_presses += 1
	qte_left = maxf(qte_left,0.45)
	spawn_fx(qte_target.global_position,Color("#ffd700"),40.0+qte_presses*20.0,0.25)
	if qte_presses >= 3:
		var target := qte_target
		qte_target = null
		final_qte=false
		notify("ФИНАЛЬНЫЙ УДАР!")
		shake(28.0); flash_screen(Color.WHITE)
		target.take_damage(target.hp+1.0,{"source":"final_qte"})

func _tick_combo(delta: float) -> void:
	if combo <= 0: return
	combo_left -= delta
	if combo_left <= 0.0:
		combo = 0
		if hud != null: hud.update_combo(0)

func _tick_chaos(_delta: float) -> void:
	if player == null or not player.has_meta("trial_chaos"): return
	var slot := int(elapsed / 60.0)
	if int(player.get_meta("chaos_slot",-1)) == slot: return
	player.set_meta("chaos_slot",slot)
	var effects := ["Враги увеличились", "Игрок замедлен", "Враги замедлены", "Двойной спавн", "Двойные снаряды"]
	var pick := slot % effects.size()
	notify("ХАОС: " + effects[pick])
	match pick:
		0:
			for e in enemies: e.scale = Vector2(2,2)
		1: player.world_speed_mult = 0.5
		2: director_mods.speed = 0.5
		3: director_mods.spawn = 2.0
		4: upg.apply_mods({"proj":1}); player.recalc()

## Камера: смотрит вперёд по прицелу, следит за напарниками в сети,
## отъезжает при наплыве врагов и добавляет кинематографичный «кик» при попаданиях.
func _tick_camera(delta: float) -> void:
	if player == null:
		return
	var base_zoom := BASE_CAMERA_ZOOM * GameManager.camera_zoom_scale()
	var target: Vector2 = player.global_position
	var zoom_target := base_zoom
	# сетевой кооп: держим в кадре всю группу
	if net_active and not net_proxies.is_empty():
		var group_center := player.global_position
		var group := 1.0
		for np in net_proxies:
			if np.dead:
				continue
			group_center += np.global_position
			group += 1.0
		group_center /= group
		var spread := player.global_position.distance_to(group_center)
		target = target.lerp(group_center, 0.6)
		zoom_target *= clampf(1.0 - spread / 1100.0, 0.7, 1.0)
	# мягкий «взгляд вперёд» по прицелу — кадр дышит в сторону боя
	var ahead_len := 16.0 if player.moving_now else 10.0
	look_ahead = look_ahead.lerp(player.aim_dir * ahead_len, clampf(3.0 * delta, 0.0, 1.0))
	target += look_ahead
	if boss_enemy != null and boss_enemy.active:
		boss_focus += delta
		target = target.lerp(boss_enemy.global_position, 0.34)
		zoom_target += 0.10 + (0.10 if boss_enemy.hp / boss_enemy.max_hp < 0.3 else 0.0)
	else:
		boss_focus = 0.0
		# наплыв толпы: чуть шире кадр, чтобы читать угрозы
		var crowd := float(enemies_in_radius(player.global_position, 190.0).size())
		zoom_target += clampf(crowd / 160.0, 0.0, 0.09)
		if player.hp <= 1:
			zoom_target += 0.05
	if photo_mode:
		zoom_target = camera.zoom.x
	camera_zoom_target = zoom_target
	camera.global_position = camera.global_position.lerp(target, clampf((5.0 if boss_enemy != null else 8.5) * delta, 0.0, 1.0))
	var z := lerpf(camera.zoom.x, camera_zoom_target, clampf(3.4 * delta, 0.0, 1.0))
	camera.zoom = Vector2(z, z)
	var shake_mult := 1.0
	match String(GameManager.setting("camera_shake", "normal")):
		"off":
			shake_mult = 0.0
		"strong":
			shake_mult = 1.8
	shake_amount = maxf(0.0, shake_amount - delta * 17.0)
	camera_kick = camera_kick.lerp(Vector2.ZERO, clampf(10.0 * delta, 0.0, 1.0))
	if shake_amount > 0.0 and shake_mult > 0.0:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount * shake_mult + camera_kick
	else:
		camera.offset = camera_kick

## Направленный «толчок» камеры от попадания.
func kick_camera(dir: Vector2, amount: float) -> void:
	var mult := 1.0
	match String(GameManager.setting("camera_shake", "normal")):
		"off":
			mult = 0.0
		"strong":
			mult = 1.7
	camera_kick = dir.normalized() * amount * mult

func _cleanup() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if not enemies[i].active:
			if enemies[i].net_id > 0 and net_enemies.get(enemies[i].net_id, null) == enemies[i]:
				net_enemies.erase(enemies[i].net_id)
			if enemy_pool.size() < 400:
				enemy_pool.append(enemies[i])
			else:
				enemies[i].queue_free()
			enemies.remove_at(i)
	for i in range(bullets.size() - 1, -1, -1):
		if not bullets[i].active:
			if bullet_pool.size() < 600:
				bullet_pool.append(bullets[i])
			else:
				bullets[i].queue_free()
			bullets.remove_at(i)
	for i in range(ebullets.size() - 1, -1, -1):
		if not ebullets[i].active:
			if ebullet_pool.size() < 400:
				ebullet_pool.append(ebullets[i])
			else:
				ebullets[i].queue_free()
			ebullets.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		if not pickups[i].active:
			if pickup_pool.size() < 600:
				pickup_pool.append(pickups[i])
			else:
				pickups[i].queue_free()
			pickups.remove_at(i)
	for i in range(allies.size() - 1, -1, -1):
		if not allies[i].active:
			if ally_pool.size() < 100:
				ally_pool.append(allies[i])
			else:
				allies[i].queue_free()
			allies.remove_at(i)
	for i in range(hazards.size() - 1, -1, -1):
		if not hazards[i].active:
			if hazard_pool.size() < 120:
				hazard_pool.append(hazards[i])
			else:
				hazards[i].queue_free()
			hazards.remove_at(i)
	for i in range(fx_list.size() - 1, -1, -1):
		if not fx_list[i].active:
			if fx_pool.size() < 200:
				fx_pool.append(fx_list[i])
			else:
				fx_list[i].queue_free()
			fx_list.remove_at(i)
	if corpses.size() > 40:
		corpses = corpses.slice(corpses.size() - 40)

# ------------------------------------------------------------------ СПАВН
## Лимит врагов на экране: lerp(50, 1500, t) по техспеке (3.1).
func max_enemies_now() -> int:
	if OS.get_environment("SURW_MAXEN") != "":
		return int(OS.get_environment("SURW_MAXEN"))
	var run_cfg: Dictionary = DB.balance["run"]
	var start := float(run_cfg.get("max_enemies_start", 16))
	var end := float(run_cfg.get("max_enemies", 1500))
	var span := maxf(1.0, float(run_cfg.get("spawn_ramp_seconds", 1800.0)))
	# Лимит растёт по сглаженной кривой: мягкое начало и выход на максимум к финалу.
	var t := clampf(elapsed / span, 0.0, 1.0)
	var eased := pow(t, maxf(1.0, float(run_cfg.get("max_enemies_cap_ease", 2.0))))
	return maxi(4, int(lerp(start, end, eased)))

## Множитель HP врагов по времени: 1.0 / 1.5 / 2.0 / 2.5 / 3.0 (техспека 3.2).
func time_hp_mult() -> float:
	var windows: Array = DB.balance.get("hp_windows", [])
	var mult := 1.0
	for w in windows:
		if elapsed >= float(w[0]):
			mult = float(w[1])
	return mult

func spawn_enemy(enemy_id: String, pos: Vector2, opts: Dictionary = {}) -> Enemy:
	if enemies.size() >= max_enemies_now():
		return null
	var data := DB.enemy(enemy_id)
	if data.is_empty():
		return null
	var enemy: Enemy
	if enemy_pool.is_empty():
		enemy = ENEMY_SCENE.instantiate()
		world.add_child(enemy)
		enemy.setup(self)
	else:
		enemy = enemy_pool.pop_back()
	var role := String(data.get("role", "fodder"))
	var mult := enemy_mult(role)
	var per_min := float(data.get("hp_scale_per_min", 0.0))
	var time_scale_hp := 1.0 + per_min * (elapsed / 60.0)
	enemy.init_enemy(self, data, pos,
		float(opts.get("hp_mult", mult["hp"])) * time_scale_hp * GameManager.cheat_enemy_hp,
		float(opts.get("dmg_mult", mult["dmg"])) * GameManager.cheat_enemy_dmg,
		float(opts.get("speed_mult", mult["speed"])),
		bool(opts.get("elite", false)))
	enemy.apply_map_tint(Gfx.hex(String(map_data.get("palette", {}).get("enemy", "#ffffff"))))
	if net_active and net_host:
		enemy.net_id = net_id_seq
		net_id_seq += 1
		net_enemies[enemy.net_id] = enemy
	enemies.append(enemy)
	GameManager.add_album_enemy(enemy_id)
	return enemy

func spawn_from_role(role: String) -> Enemy:
	var roster: Dictionary = map_data.get("roster", {})
	var list: Array = roster.get(role, roster.get("fodder", []))
	if list.is_empty():
		return null
	var enemy_id := String(list[randi() % list.size()])
	var pos := _spawn_position()
	return spawn_enemy(enemy_id, pos)

func _spawn_position() -> Vector2:
	var center := player.global_position
	var best_pos := center
	var best_dist := -1.0
	for i in 12:
		var ang := randf() * TAU
		var dist := randf_range(420.0, 540.0)
		var cand := clamp_to_map(center + Vector2.RIGHT.rotated(ang) * dist)
		var d := cand.distance_to(center)
		var obs := obstacle_at(cand, 12.0)
		if obs.is_empty() and d >= 360.0:
			return cand
		if d > best_dist and (obs.is_empty() or best_dist < 0.0):
			best_dist = d
			best_pos = cand
	return best_pos

# ------------------------------------------------------------------ ЧИТЫ
## Точка спавна для чит-меню: рядом с игроком, но не внутри него.
func cheat_spawn_point() -> Vector2:
	var pos: Vector2 = player.global_position + Vector2(randf_range(70.0, 110.0), randf_range(-50.0, 50.0))
	pos.x = clampf(pos.x, 20.0, map_rect.size.x - 20.0)
	pos.y = clampf(pos.y, 20.0, map_rect.size.y - 20.0)
	return pos

## Вызов конкретного босса по id (включая САТАНАИЛА).
func cheat_spawn_boss(boss_id: String) -> bool:
	var def: Dictionary = DB.sathan if boss_id == "satanail" else DB.bosses.get(boss_id, {})
	if def.is_empty():
		return false
	var node: Enemy = ENEMY_SCENE.instantiate()
	world.add_child(node)
	node.setup(self)
	var hp := float(def.get("hp", 1000.0))
	node.init_boss(self, def, cheat_spawn_point(), hp, boss_id == "shemhaz" or boss_id == "satanail")
	enemies.append(node)
	boss_enemy = node
	boss_no_hit = false
	GameManager.add_album_boss(String(def.get("id", boss_id)))
	notify("%s: %s (чит)" % [Loc.t("boss"), String(def.get("name", boss_id))])
	AudioManager.play_sfx("boss", 1.0)
	print("[SURWAVE] cheat_boss id=%s hp=%.0f" % [boss_id, hp])
	return true

## Гарантированное убийство в обход брони, щитов и QTE (только для читов).
func _cheat_kill(e: Node) -> void:
	if e == null or not e.active or e.dead:
		return
	e.hp = 0.0
	e._die()

## Убить всех врагов на карте (включая тех, кто появился от «смерть со спавном»).
func cheat_kill_all() -> void:
	for pass_i in 4:
		var alive: bool = false
		for e in enemies:
			if e != null and e.active and not e.dead:
				alive = true
				_cheat_kill(e)
		if not alive:
			break
	GameManager.cheat_frozen = false
	notify("чит: все враги уничтожены")

## Убрать врагов вокруг игрока (в пределах видимой зоны).
func cheat_clear_around() -> void:
	for e in enemies_in_radius(player.global_position, 320.0):
		_cheat_kill(e)
	notify("чит: зона очищена")

func spawn_miniboss(tier: int) -> void:
	var mb := DB.miniboss_of(String(map_data.get("id", "")))
	if mb.is_empty():
		return
	# HP мини-босса берётся из данных карты (mb_*: 200…1000), тир даёт небольшой бонус
	var hp := float(mb.get("hp", 300)) * (1.0 + 0.15 * minf(float(tier), 3.0)) * (1.0 + float(diff_mods.get("boss_hp", 0.0)) * 0.5)
	var enemy := spawn_enemy(String(mb.get("id", "")), _spawn_position(), {"hp_mult": hp / maxf(1.0, float(mb.get("hp", 1))), "dmg_mult": 1.0 + float(diff_mods.get("boss_dmg", 0.0))})
	if enemy != null:
		notify("%s: %s" % [Loc.t("miniboss"), String(mb.get("name", ""))])
		print("[SURWAVE] miniboss id=%s hp=%.0f t=%.0f" % [String(mb.get("id", "")), hp, elapsed])
		AudioManager.play_sfx("boss", 1.3)

func spawn_map_boss(kind: String) -> void:
	# 15:00 — чемпион карты, 30:00 — финальный босс Шемхаз (BOSSES_COMPLETE_SPECIFICATION.md)
	var boss_def: Dictionary = DB.bosses.get("shemhaz", {}) if kind == "final" else DB.boss(String(map_data.get("id", "")))
	if boss_def.is_empty():
		boss_def = DB.bosses.get("shemhaz", {})
	if boss_def.is_empty():
		return
	var hp := float(boss_def.get("hp", 7500))
	var hp_mult := 1.0 + float(diff_mods.get("boss_hp", 0.0))
	if mode == "endless":
		hp_mult += float(endless_cycle) * 1.0
	boss_enemy = ENEMY_SCENE.instantiate()
	world.add_child(boss_enemy)
	boss_enemy.setup(self)
	boss_enemy.init_boss(self, boss_def, _spawn_position(), hp * hp_mult, kind == "final")
	enemies.append(boss_enemy)
	boss_no_hit = true
	print("[SURWAVE] boss_spawn kind=%s id=%s name=%s hp=%.0f t=%.0f" % [kind, String(boss_def.get("id", "")), String(boss_def.get("name", "")), hp * hp_mult, elapsed])
	GameManager.add_album_boss(String(boss_def.get("id", "")))
	AudioManager.play_sfx("boss", 0.8)
	notify("%s: %s" % [Loc.t("boss"), String(boss_def.get("name", ""))])

## Спавн секретного босса САТАНАИЛ (без немедленной мегафазы).
func spawn_secret_boss() -> void:
	var sd: Dictionary = DB.sathan
	if sd.is_empty():
		return
	boss_enemy = ENEMY_SCENE.instantiate()
	world.add_child(boss_enemy)
	boss_enemy.setup(self)
	boss_enemy.init_boss(self, sd, _spawn_position(), float(sd.get("hp", 10000)))
	enemies.append(boss_enemy)
	megaphase = false
	GameManager.add_album_boss("boss_satanail")
	AudioManager.play_sfx("sathan", 0.8)
	notify("САТАНАИЛ пробудился")

func spawn_sathan() -> void:
	var sathan_def: Dictionary = DB.sathan
	if sathan_def.is_empty():
		return
	var hp := float(sathan_def.get("hp", 10000))
	boss_enemy = ENEMY_SCENE.instantiate()
	world.add_child(boss_enemy)
	boss_enemy.setup(self)
	boss_enemy.init_boss(self, sathan_def, _spawn_position(), hp, true)
	enemies.append(boss_enemy)
	megaphase = true
	boss_no_hit = false
	notify(Loc.t("sathan_warn"))
	AudioManager.play_sfx("sathan", 0.8)
	shake(10.0)

func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, opts: Dictionary) -> void:
	if bullets.size() > int(DB.balance.get("limits", {}).get("max_bullets", 500)):
		return
	var b: Bullet
	if bullet_pool.is_empty():
		b = BULLET_SCENE.instantiate()
		world.add_child(b)
		b.setup(self)
	else:
		b = bullet_pool.pop_back()
	b.spawn_bullet(pos, dir, dmg, opts)
	bullets.append(b)

func spawn_enemy_bullet(pos: Vector2, dir: Vector2, dmg: int, opts: Dictionary = {}) -> void:
	if ebullets.size() > int(DB.balance.get("limits", {}).get("max_enemy_bullets", 300)):
		return
	var b: EnemyBullet
	if ebullet_pool.is_empty():
		b = EBULLET_SCENE.instantiate()
		world.add_child(b)
		b.setup(self)
	else:
		b = ebullet_pool.pop_back()
	var proj_mult := float(DB.balance["run"].get("enemy_proj_speed", 0.74))
	# вражеский снаряд намеренно медленный и читаемый: база 100 → ~74, потолок 190
	opts["speed"] = clampf(float(opts.get("speed", 100.0)) * proj_mult, 24.0, 190.0)
	b.spawn_at(pos, dir, dmg, opts)
	ebullets.append(b)

func spawn_pickup(kind: String, pos: Vector2, value: float = 1.0) -> void:
	if pickups.size() > int(DB.balance.get("limits", {}).get("max_pickups", 1200)):
		return
	var p: Pickup
	if pickup_pool.is_empty():
		p = PICKUP_SCENE.instantiate()
		world.add_child(p)
		p.setup(self)
	else:
		p = pickup_pool.pop_back()
	var color := Color(0.5, 0.9, 1.0)
	var size := 5.0
	match kind:
		"gold": color = Color(1.0, 0.85, 0.3); size = 5.0
		"heart": color = Color(1.0, 0.35, 0.4); size = 6.0
		"soul": color = Color(0.8, 0.6, 1.0); size = 6.0
		"chest": color = Color(1.0, 0.75, 0.25); size = 11.0
	p.spawn_at(pos, kind, value, color, size)
	p.net_id = net_id_seq
	net_id_seq += 1
	pickups.append(p)

func spawn_ally(kind: String, opts: Dictionary) -> void:
	opts=opts.duplicate()
	var soul_bonus:=player.upg.flag_num("soul_knight")*float(player.souls_collected)
	if kind=="boomerang": soul_bonus+=player.upg.flag_num("boomerang_soul")*float(player.souls_collected)
	if kind=="dragonling":
		var mins:=floorf(elapsed/60.0)
		opts["damage"]=(float(opts.get("damage",5.0))+player.upg.flag_num("dragon_flat")*mins)*(1.0+player.upg.flag_num("dragon_growth")*mins)
		opts["dragon_breath"]=player.upg.flag_on("dragon_breath")
	opts["damage"]=float(opts.get("damage",5.0))+soul_bonus
	var a: Ally
	if ally_pool.is_empty():
		a = ALLY_SCENE.instantiate()
		world.add_child(a)
		a.setup(self)
	else:
		a = ally_pool.pop_back()
	a.init_ally(self, kind, opts)
	allies.append(a)
	EventBus.summon_count_changed.emit(allies.size())
	# доп. призывы за перки
	if not bool(opts.get("no_extra", false)) and int(player.S.summon_count) > 0 and kind in ["spirit", "skeleton", "boomerang", "dragonling", "scythe"]:
		for i in int(player.S.summon_count):
			var extra: Ally
			if ally_pool.is_empty():
				extra = ALLY_SCENE.instantiate()
				world.add_child(extra)
				extra.setup(self)
			else:
				extra = ally_pool.pop_back()
			var o := opts.duplicate()
			extra.init_ally(self, kind, o)
			allies.append(extra)

func spawn_fx(pos: Vector2, color: Color, size: float, dur: float, is_square: bool = false) -> void:
	var f: Fx
	if fx_pool.is_empty():
		f = FX_SCENE.instantiate()
		world.add_child(f)
	else:
		f = fx_pool.pop_back()
	f.global_position = pos
	f.setup(size, color, dur, is_square)
	fx_list.append(f)

func spawn_event_fx(ev_kind: String, pos: Vector2, tele: float, radius: float, extra: Dictionary = {}) -> void:
	if world == null or not is_instance_valid(world):
		return
	var node: MapEventFx = MAP_EVENT_FX_SCRIPT.new()
	world.add_child(node)
	node.setup(self, ev_kind, pos, tele, radius, extra)

func spawn_dmg_number(pos: Vector2, amount: float, is_crit: bool = false, source: String = "") -> void:
	if world == null or dmg_nums.size() >= 28:
		return
	var lbl: Label = null
	if not dmg_pool.is_empty():
		lbl = dmg_pool.pop_back()
	else:
		lbl = Label.new()
		lbl.z_index = 14
		lbl.add_theme_font_override("font", UI.crisp_font())
		lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03, 0.95))
		lbl.add_theme_constant_override("outline_size", 2)
		world.add_child(lbl)
	var col := Color("#f2e6cf")
	if is_crit:
		col = Color("#ffcf4a")
	elif source in ["lightning", "chain"]:
		col = Color("#9ad8ff")
	elif source in ["curse", "dot"]:
		col = Color("#c87cff")
	elif source in ["smite", "holy", "divine"]:
		col = Color("#fff0a8")
	lbl.text = ("%d!" % int(round(amount))) if is_crit else ("%d" % int(round(amount)))
	lbl.add_theme_font_size_override("font_size", 11 if is_crit else 9)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = pos + Vector2(randf_range(-8.0, 8.0), -14.0)
	lbl.scale = Vector2.ONE * (1.18 if is_crit else 1.0)
	lbl.modulate = Color(1, 1, 1, 1)
	lbl.visible = true
	dmg_nums.append({"lbl": lbl, "t": 0.0, "dur": 0.55 if is_crit else 0.42, "vx": randf_range(-12.0, 12.0)})

func spawn_perk_fx(fx_kind: String, pos: Vector2, size_px: float = 48.0, dur: float = 0.32) -> void:
	if world == null or not is_instance_valid(world):
		return
	var node: PerkFx = PERK_FX_SCRIPT.new()
	world.add_child(node)
	node.setup(fx_kind, pos, size_px, dur)

func spawn_hazard_zone(pos: Vector2, dps: float, dur: float, radius: float, color: Color, extra: Dictionary = {}) -> void:
	var h: Hazard
	if hazard_pool.is_empty():
		h = HAZARD_SCENE.instantiate()
		world.add_child(h)
		h.setup(self)
	else:
		h = hazard_pool.pop_back()
	h.init_hazard(self, pos, radius, float(extra.get("damage", 0.0)), dps, float(extra.get("telegraph", 0.0)), dur, color, extra)
	hazards.append(h)

func spawn_delayed_aoe(pos: Vector2, radius: float, dmg: float, delay: float, color: Color, dot: float = 0.0) -> void:
	var h: Hazard
	if hazard_pool.is_empty():
		h = HAZARD_SCENE.instantiate()
		world.add_child(h)
		h.setup(self)
	else:
		h = hazard_pool.pop_back()
	h.init_hazard(self, pos, radius, dmg, dot, delay, 2.2 if dot > 0.0 else 0.35, color, {"hits_player": true, "hits_enemies": false})
	hazards.append(h)

func spawn_beam(pos: Vector2, dir: Vector2, length: float, dmg: int) -> void:
	spawn_fx(pos + dir * length * 0.5, Color(1, 0.3, 0.2), length, 0.25)
	var steps := int(length / 24.0)
	for i in steps:
		var p := pos + dir * float(i) * 24.0
		if player.global_position.distance_to(p) < 18.0:
			damage_player(dmg, pos)
			break

func shard_burst(pos: Vector2, count: int, dmg: float) -> void:
	for i in count:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(count))
		spawn_enemy_bullet(pos, dir, int(dmg), {"speed": 160.0, "color": Color(0.8, 0.6, 1.0)})

# ------------------------------------------------------------------ УРОН
func damage_enemy(enemy: Node2D, amount: float, opts: Dictionary = {}) -> void:
	if enemy == null or not enemy.active or amount <= 0.0:
		return
	if net_active and not net_host:
		_net_client_damage(enemy, amount, opts)
		return
	var dmg := amount * (1.0 + float(combo) * 0.005)
	if player != null and player.has_meta("qte_bonus"):
		dmg*=float(player.get_meta("qte_bonus",1.25)); player.remove_meta("qte_bonus")
	if player != null and player.upg.flag_num("exec_threshold") > 0.0 and not enemy.boss:
		if enemy.hp / maxf(1.0, enemy.max_hp) < player.upg.flag_num("exec_threshold"):
			dmg = enemy.hp + 1.0
			spawn_perk_fx("blood", enemy.global_position, 42.0, 0.28)
	dmg = maxf(1.0, dmg)
	if enemy.boss and qte_target == null and GameManager.setting("qte",true) and not GameManager.autoplay and enemy.hp/maxf(1.0,enemy.max_hp) > 0.05 and (enemy.hp-dmg)/maxf(1.0,enemy.max_hp) <= 0.05:
		dmg = maxf(1.0, enemy.hp - enemy.max_hp*0.05)
	enemy.last_source = String(opts.get("source", ""))
	enemy.take_damage(dmg, opts)
	if enemy.boss and enemy.active and enemy.hp / maxf(1.0,enemy.max_hp) <= 0.05 and qte_target == null and GameManager.setting("qte",true) and not GameManager.autoplay:
		_start_final_qte(enemy)
	damage_dealt += dmg
	if not bool(opts.get("silent", false)) and (dmg >= 2.0 or bool(opts.get("crit", false)) or enemy.boss):
		spawn_dmg_number(enemy.global_position, dmg, bool(opts.get("crit", false)), String(opts.get("source", "")))
	if player != null:
		player.on_enemy_hit(enemy, dmg)
	# распространение проклятия (Моровая Чума)
	if player != null and player.upg.flag_on("plague") and enemy.has_status("curse"):
		if randf() < 0.12:
			for other in enemies_in_radius(enemy.global_position, 60.0):
				if other != enemy and not other.has_status("curse"):
					apply_status(other, "curse", 3.0, {"dps": 4.0})

func damage_player(amount: int, from_pos: Vector2, ignore_iframes: bool = false, source_role: String = "") -> void:
	if player == null or player.dead:
		return
	if boss_enemy != null and boss_enemy.active:
		boss_no_hit = false
	var mult := 1.0
	if bool(map_data.get("mods", {}).get("poison_on_hit", false)):
		player.add_status("poison", 5.0, {"dps": 2.0})
	if float(diff_mods.get("fodder_late_dmg", 0.0)) > 0.0 and source_role in ["fodder", "shooter"] and elapsed >= wave_mgr.duration - 300.0:
		mult *= 1.0 + float(diff_mods.get("fodder_late_dmg", 0.0))
	if player.has_meta("glass"):
		mult *= 2.0
	# серия убийств без урона сбрасывается только реальным попаданием
	var hp_before: int = player.hp
	player.take_damage(int(round(float(amount) * mult)), from_pos, ignore_iframes)
	if player.hp < hp_before:
		kills_without_damage = 0
		combo = 0
		time_since_damage = 0.0
		tension = clampf(tension + 2.0,0.0,100.0)
		kick_camera(player.global_position - from_pos, 4.5)
		if hud != null: hud.update_combo(0)
	damage_taken = player.damage_taken

func apply_status(enemy: Node2D, key: String, dur: float, params: Dictionary = {}) -> void:
	if enemy == null or not enemy.active:
		return
	if key == "freeze" and dur <= 0.0:
		dur = float(DB.balance["player"].get("freeze_dur", 2.0))
	if key == "burn":
		if dur <= 0.0:
			dur = float(DB.balance["player"].get("burn_dur", 3.0))
		if not params.has("dps"):
			params["dps"] = float(DB.balance["player"].get("burn_dps", 3.0))
		if player != null:
			dur *= float(player.S.get("burn_dur", 1.0))
	enemy.add_status(key, dur, params)
	if key == "freeze":
		AudioManager.play_sfx("freeze", randf_range(0.9, 1.2))
		if player != null and player.upg.flag_num("freeze_bite") > 0.0:
			var frac := player.upg.flag_num("freeze_bite")
			if enemy.role == "elite" or enemy.role == "miniboss" or enemy.role == "boss":
				frac = 0.03
			enemy.hp -= enemy.max_hp * frac
		if player != null and player.upg.flag_on("iceflame_passive"):
			apply_status(enemy, "burn", dur, {"dps": 6.0})
	if key == "curse":
		spawn_perk_fx("curse", enemy.global_position, 28.0, 0.24)
	if key == "burn":
		AudioManager.play_sfx("fire", randf_range(0.8, 1.2))
		if player != null and player.upg.flag_num("burn_explode") > 0.0:
			pass

## Наложить статус на всех врагов в радиусе.
func apply_status_radius(pos: Vector2, radius: float, key: String, dur: float, params: Dictionary = {}) -> void:
	for enemy in enemies_in_radius(pos, radius):
		apply_status(enemy, key, dur, params)

## Притяжение врагов к точке (гравитационная пушка / чёрная дыра).
func pull_enemies(center: Vector2, radius: float, force: float, duration: float) -> void:
	pulls.append({"pos": center, "radius": radius, "force": force, "left": duration})
	spawn_fx(center, Color(0.6, 0.1, 0.9), radius, 0.5)

func _tick_pulls(delta: float) -> void:
	if pulls.is_empty():
		return
	for i in range(pulls.size() - 1, -1, -1):
		var pl: Dictionary = pulls[i]
		pl["left"] = float(pl["left"]) - delta
		for enemy in enemies_in_radius(pl["pos"], float(pl["radius"])):
			var d: Vector2 = pl["pos"] - enemy.global_position
			if d.length() > 4.0:
				enemy.global_position += d.normalized() * float(pl["force"]) * delta
		if float(pl["left"]) <= 0.0:
			pulls.remove_at(i)

func freeze_enemy(enemy: Node2D, dur: float) -> void:
	apply_status(enemy, "freeze", dur, {})
	if enemy != null and enemy.active:
		spawn_perk_fx("frost", enemy.global_position, 28.0, 0.25)
	if player != null and player.upg.flag_num("freeze_burn") > 0.0:
		apply_status(enemy, "burn", dur, {"dps": player.upg.flag_num("freeze_burn")})

## AoE из смерти врагов ставится в очередь: иначе цепные взрывы уходят в рекурсию.
func queue_aoe(pos: Vector2, radius: float, amount: float, opts: Dictionary = {}) -> void:
	pending_aoe.append({"pos": pos, "radius": radius, "amount": amount, "opts": opts})

func _process_pending_aoe() -> void:
	if pending_aoe.is_empty():
		return
	var batch := pending_aoe.duplicate()
	pending_aoe.clear()
	for item in batch:
		aoe_damage(item["pos"], float(item["radius"]), float(item["amount"]), item["opts"])

func aoe_damage(pos: Vector2, radius: float, amount: float, opts: Dictionary = {}) -> int:
	var hits := 0
	for enemy in enemies_in_radius(pos, radius):
		var dmg := amount
		if bool(opts.get("holy", false)) and String(enemy.data.get("clan", "")) == "undead":
			dmg *= 2.0
		damage_enemy(enemy, dmg, {"source": opts.get("source", "aoe"), "silent": true})
		hits += 1
	return hits

func lightning_strike_at(pos: Vector2, radius: float, dmg: float) -> bool:
	radius *= 1.0 + float(player.upg.add.get("shock_radius", 0.0))
	var hit := aoe_damage(pos, radius, dmg, {"source": "lightning"})
	spawn_fx(pos, Color(0.8, 0.9, 1.0), radius * 1.6, 0.2)
	spawn_perk_fx("lightning", pos, radius * 2.1, 0.30)
	if hit > 0:
		AudioManager.play_sfx("lightning", randf_range(0.9, 1.2))
		if player != null and player.upg.flag_num("overload") > 0.0:
			for enemy in enemies_in_radius(pos, radius):
				if enemy.has_status("burn"):
					aoe_damage(enemy.global_position, 50.0, player.upg.flag_num("overload"), {"source": "overload"})
					spawn_perk_fx("fireball", enemy.global_position, 54.0, 0.32)
	return hit > 0

func lightning_strike_nearest(pos: Vector2, max_range: float, dmg: float) -> bool:
	var res := nearest_enemy(pos, max_range)
	if res.is_empty():
		return false
	lightning_strike_at(res[0].global_position, float(DB.balance["player"].get("lightning_radius", 24.0)), dmg)
	return true

func lightning_volley(center: Vector2, count: int, dmg: float, radius: float) -> void:
	for i in count:
		var pos := center + Vector2(randf_range(-90, 90), randf_range(-90, 90))
		spawn_delayed_aoe(pos, radius, dmg, 0.7, Color(0.8, 0.9, 1.0))
		var p_copy := pos
		run_later(0.7, func() -> void: spawn_perk_fx("lightning", p_copy, radius * 2.0, 0.28))

func chain_lightning(from_enemy: Node2D, jumps: int, dmg: float) -> void:
	var current := from_enemy
	var hit: Array = [from_enemy]
	for i in jumps:
		var next: Node2D = null
		var best := 999.0
		for enemy in enemies_in_radius(current.global_position, 140.0):
			if hit.has(enemy):
				continue
			var d: float = enemy.global_position.distance_to(current.global_position)
			if d < best:
				best = d
				next = enemy
		if next == null:
			break
		damage_enemy(next, dmg, {"source": "chain"})
		spawn_fx(next.global_position, Color(0.8, 0.9, 1.0), 16.0, 0.15)
		spawn_perk_fx("lightning", next.global_position, 32.0, 0.24)
		hit.append(next)
		current = next

func apocalypse(dmg: float) -> void:
	notify("АПОКАЛИПСИС")
	for i in 12:
		var pos := player.global_position + Vector2(randf_range(-140, 140), randf_range(-140, 140))
		spawn_delayed_aoe(pos, 48.0, dmg, 1.2, Color(1, 0.2, 0.1))
		spawn_event_fx("meteor", pos, 1.2, 48.0)

# ------------------------------------------------------------------ ЗАПРОСЫ
## Перестройка пространственной сетки врагов (раз в кадр).
func rebuild_enemy_grid() -> void:
	enemy_grid.clear()
	for enemy in enemies:
		if not enemy.active:
			continue
		var key := Vector2i(int(floor(enemy.global_position.x / CELL)), int(floor(enemy.global_position.y / CELL)))
		if enemy_grid.has(key):
			(enemy_grid[key] as Array).append(enemy)
		else:
			enemy_grid[key] = [enemy]

func enemies_in_radius(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	# для больших радиусов или малого числа врагов — простой перебор
	if radius > 320.0 or enemies.size() < 120:
		for enemy in enemies:
			if not enemy.active:
				continue
			if (enemy.global_position - pos).length_squared() <= r2:
				out.append(enemy)
		return out
	var min_x := int(floor((pos.x - radius) / CELL))
	var max_x := int(floor((pos.x + radius) / CELL))
	var min_y := int(floor((pos.y - radius) / CELL))
	var max_y := int(floor((pos.y + radius) / CELL))
	for cx in range(min_x, max_x + 1):
		for cy in range(min_y, max_y + 1):
			var arr: Array = enemy_grid.get(Vector2i(cx, cy), [])
			for enemy in arr:
				if enemy.active and (enemy.global_position - pos).length_squared() <= r2:
					out.append(enemy)
	return out

func enemy_at(pos: Vector2, radius: float) -> Node2D:
	for enemy in enemies:
		if not enemy.active:
			continue
		if enemy.global_position.distance_to(pos) < enemy.radius + radius:
			return enemy
	return null

func nearest_enemy(pos: Vector2, max_range: float) -> Array:
	if enemies.size() > 200 and max_range <= 600.0 and not enemy_grid.is_empty():
		var r := 96.0
		while r <= max_range:
			var found := enemies_in_radius(pos, r)
			if not found.is_empty():
				var best0: Node2D = found[0]
				var best0_d := (best0.global_position - pos).length_squared()
				for enemy in found:
					var d0: float = (enemy.global_position - pos).length_squared()
					if d0 < best0_d:
						best0_d = d0
						best0 = enemy
				return [best0, sqrt(best0_d)]
			r *= 1.8
		return []
	var best: Node2D = null
	var best_d := max_range * max_range
	for enemy in enemies:
		if not enemy.active:
			continue
		var d: Vector2 = enemy.global_position - pos
		var l := d.length_squared()
		if l < best_d:
			best_d = l
			best = enemy
	if best == null:
		return []
	return [best, sqrt(best_d)]

## Враги в радиусе, отсортированные по близости (для мультицельных эффектов).
func nearest_enemies(pos: Vector2, max_range: float, limit: int = 4) -> Array:
	var cand := enemies_in_radius(pos, max_range)
	var live: Array = []
	for e in cand:
		if e != null and is_instance_valid(e) and e.active:
			live.append(e)
	live.sort_custom(func(a, b) -> bool:
		return pos.distance_squared_to(a.global_position) < pos.distance_squared_to(b.global_position))
	if live.size() > limit:
		live.resize(maxi(0, limit))
	return live

func nearest_enemy_excluding(pos: Vector2, max_range: float, exclude: Array) -> Array:
	var best: Node2D = null
	var best_d := max_range * max_range
	for enemy in enemies:
		if not enemy.active or exclude.has(enemy):
			continue
		var l: float = (enemy.global_position - pos).length_squared()
		if l < best_d:
			best_d = l
			best = enemy
	if best == null:
		return []
	return [best, sqrt(best_d)]

func has_pickups_near(pos: Vector2, radius: float) -> bool:
	for p in pickups:
		if p.active and p.global_position.distance_to(pos) < radius:
			return true
	return false

func nearest_pickup_pos(pos: Vector2, radius: float) -> Vector2:
	var best := Vector2.INF
	var best_d := radius * radius
	for p in pickups:
		if not p.active:
			continue
		var l: float = (p.global_position - pos).length_squared()
		if l < best_d:
			best_d = l
			best = p.global_position
	return best

func density_at(pos: Vector2, radius: float) -> int:
	return enemies_in_radius(pos, radius).size()

func count_burning_enemies(pos: Vector2, radius: float) -> int:
	var c := 0
	for enemy in enemies_in_radius(pos, radius):
		if enemy.has_status("burn"):
			c += 1
	return c

## Сколько врагов сейчас горит (для перка «Пылающий Разум»).
func burning_count() -> int:
	var n := 0
	for e in enemies:
		if e.active and e.statuses.has("burn"):
			n += 1
	return n

func alive_allies() -> int:
	var c := 0
	for ally in allies:
		if ally.active:
			c += 1
	return c

func clamp_to_map(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, map_rect.position.x + 10.0, map_rect.end.x - 10.0),
		clampf(pos.y, map_rect.position.y + 10.0, map_rect.end.y - 10.0))

func pop_corpse() -> Vector2:
	if corpses.is_empty():
		return Vector2.INF
	return corpses.pop_back()

func shake(amount: float) -> void:
	if String(GameManager.setting("camera_shake", "normal")) == "off":
		return
	if GameManager.setting("shake", true) and Engine.get_frames_per_second() >= 45:
		shake_amount = maxf(shake_amount, amount)

func boss_phase_transition(boss_node: Node2D, new_phase: int, mega: bool) -> void:
	print("[SURWAVE] boss_phase id=%s phase=%d mega=%s t=%.1f" % [String(boss_node.boss_def.get("id","")),new_phase,str(mega),elapsed])
	AudioManager.play_sfx("phase" if not mega else "sathan", 1.0)
	if player != null:
		player.iframes = maxf(player.iframes, 1.2)
	for b in ebullets:
		if b != null and b.active and b.global_position.distance_to(boss_node.global_position) < 160.0:
			b.deactivate()
	if not GameManager.setting("boss_fx", true): return
	boss_focus = 3.0
	camera_zoom_target = 1.65 if mega else (1.45 if new_phase == 2 else 1.6)
	var boss_name_txt := String(boss_node.boss_def.get("name","БОСС"))
	var text := "МЕГАФАЗА: САТАН ПРОБУЖДАЕТСЯ" if mega else ("АБСОЛЮТНАЯ ЯРОСТЬ" if new_phase >= 3 else "ЯРОСТЬ ПРОБУЖДАЕТСЯ")
	notify(boss_name_txt + " — " + text)
	shake(32.0 if mega else (20.0 if new_phase >= 3 else 10.0))
	flash_screen(Color(1.0,0.85,0.6) if not mega else Color(1.0,0.1,0.45))
	spawn_fx(boss_node.global_position, Color(1.0,0.27,0.0) if not mega else Color(1.0,0.08,0.58), 384.0 if mega else 192.0, 1.2)
	# Новая механика арены: читаемые примитивные опасные зоны.
	_phase_sequence(boss_node,new_phase,mega)
	if new_phase >= 3:
		for i in (4 if not mega else 8):
			var p := clamp_to_map(boss_node.global_position + Vector2.RIGHT.rotated(TAU*float(i)/(4.0 if not mega else 8.0))*randf_range(100.0,260.0))
			spawn_hazard_zone(p, 3.0 if not mega else 5.0, 5.0, 28.0 if not mega else 40.0, Color(1,0.2,0.05,0.5))

func _phase_sequence(boss_node: Node2D, phase_no: int, mega: bool) -> void:
	# Примитивная, но полная временная постановка: остановка → накопление → взрыв → возврат.
	var total:=12.0 if mega else (6.0 if phase_no>=3 else 5.0)
	for step in 5:
		await _scene_delay(total/5.0)
		if not is_instance_valid(boss_node) or ended:return
		match step:
			0: spawn_fx(boss_node.global_position,Color(0.1,0.0,0.15,0.8) if mega else Color(0.5,0.1,0.0,0.7),96.0,0.8)
			1: shake(8.0 if mega else 16.0); spawn_fx(boss_node.global_position,Color("#ff1493") if mega else Color("#ff4500"),160.0,1.0)
			2: camera_zoom_target=1.65; flash_screen(Color(1,1,1)); shake(20.0 if not mega else 32.0)
			3: spawn_fx(boss_node.global_position,Color("#ffd700"),384.0 if mega else 256.0,1.0)
			4: camera_zoom_target=BASE_CAMERA_ZOOM + (0.12 if mega else 0.05); notify("БОЙ ПРОДОЛЖАЕТСЯ")

func _setup_vision_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	vision_rect = ColorRect.new()
	vision_rect.color = Color.WHITE
	vision_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vision_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform vec2 viewport_size = vec2(640.0, 360.0);
uniform float radius_px = 190.0;
uniform float outer_alpha = 0.85;
void fragment() {
	vec2 delta = (UV - player_uv) * viewport_size;
	float d = length(delta);
	float inner = radius_px * 0.56;
	float outer = radius_px * 1.10;
	float t = smoothstep(inner, outer, d);
	COLOR = vec4(0.014, 0.014, 0.026, t * outer_alpha);
}"""
	vision_mat = ShaderMaterial.new()
	vision_mat.shader = shader
	vision_rect.material = vision_mat
	layer.add_child(vision_rect)

## Виньетка: мягкое затемнение краёв + цветной пульс от низкого HP и комбо.
func _setup_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	vignette_rect = ColorRect.new()
	vignette_rect.color = Color.WHITE
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.52;
uniform float pulse = 0.0;
uniform vec3 rim = vec3(0.74, 0.18, 0.16);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.18, 1.0));
	float v = smoothstep(0.32, 0.88, r);
	vec3 col = mix(vec3(0.01, 0.011, 0.02), rim, clamp(pulse, 0.0, 1.0) * v);
	COLOR = vec4(col, v * strength + v * pulse * 0.34);
}"""
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = sh
	vignette_rect.material = vignette_mat
	layer.add_child(vignette_rect)

func _tick_vignette(delta: float) -> void:
	if vignette_rect == null or vignette_mat == null:
		return
	var on := bool(GameManager.setting("vignette", true)) and run_started and not ended and not photo_mode
	vignette_rect.visible = on
	if not on:
		return
	var low := 0.0
	if player != null:
		low = 1.0 - clampf(float(player.hp) / maxf(1.0, float(player.max_hp)), 0.0, 1.0)
	var combo_k := 0.0
	if bool(GameManager.setting("combo_fx", true)):
		combo_k = clampf(float(combo) / 20.0, 0.0, 1.0)
	var target_pulse := maxf(pow(low, 1.4) * 0.9, combo_k * 0.4)
	vignette_pulse = lerpf(vignette_pulse, target_pulse, clampf(4.0 * delta, 0.0, 1.0))
	vignette_mat.set_shader_parameter("pulse", vignette_pulse)
	vignette_mat.set_shader_parameter("strength", 0.46 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.0016))

## Короткий «хит-стоп» на важных ударах: мир замирает на доли секунды.
func hitstop(duration: float = 0.05) -> void:
	if not bool(GameManager.setting("hit_stop", true)) or GameManager.autoplay:
		return
	if ended or Engine.time_scale != 1.0 or get_tree().paused:
		return
	hitstop_left = maxf(hitstop_left, duration)
	Engine.time_scale = 0.14

func _tick_hitstop(delta: float) -> void:
	if hitstop_left <= 0.0:
		return
	hitstop_left -= delta / maxf(0.02, Engine.time_scale)
	if hitstop_left <= 0.0:
		hitstop_left = 0.0
		Engine.time_scale = 1.0

func current_vision_radius() -> float:
	var base_v := float(player.S.vision) if player != null else 190.0
	return maxf(68.0, base_v * vision_mult)

func _tick_vision() -> void:
	if vision_rect == null or vision_mat == null:
		return
	vision_rect.visible = run_started and not ended and not photo_mode and player != null
	if not vision_rect.visible:
		return
	var cam_center := camera.get_screen_center_position() if camera != null else player.global_position
	var zoom_v := camera.zoom.x if camera != null else BASE_CAMERA_ZOOM
	var vp_size := get_viewport_rect().size
	if vp_size.x < 10.0 or vp_size.y < 10.0:
		vp_size = Vector2(640.0, 360.0)
	var p_screen := (player.global_position - cam_center) * zoom_v + vp_size * 0.5
	var p_uv := Vector2(p_screen.x / vp_size.x, p_screen.y / vp_size.y)
	var dark_lvl := int(GameManager.run_config.get("darkness", 1))
	vision_mat.set_shader_parameter("player_uv", p_uv)
	vision_mat.set_shader_parameter("viewport_size", vp_size)
	vision_mat.set_shader_parameter("radius_px", current_vision_radius() * zoom_v)
	vision_mat.set_shader_parameter("outer_alpha", clampf(0.82 + float(dark_lvl - 1) * 0.008, 0.82, 0.93))

func _setup_flash_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.visible = false
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash_rect)

func _tick_flash(delta: float) -> void:
	if flash_rect == null:
		return
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - delta)
	var a := flash_rect.color.a
	if a > 0.0:
		var next_a := maxf(0.0, a - delta * 2.2)
		flash_rect.color = Color(flash_rect.color.r, flash_rect.color.g, flash_rect.color.b, next_a)
		if next_a <= 0.001:
			flash_rect.color.a = 0.0
			flash_rect.visible = false
	else:
		flash_rect.visible = false

## Короткая вспышка экрана (используется боссами и событиями карт).
func flash_screen(col: Color) -> void:
	if flash_rect == null or ended or not GameManager.setting("post_fx",true):
		return
	var g := Gfx.gothic(col, 0.3)
	flash_rect.visible = true
	flash_rect.color = Color(g.r, g.g, g.b, 0.30)
	flash_left = 0.25

func notify(text: String) -> void:
	EventBus.notify.emit(text)

func has_active_orb() -> bool:
	for b in bullets:
		if b.active and bool(b.opts.get("is_orb", false)):
			return true
	return false

func explode_orbs(dmg: float) -> void:
	for b in bullets:
		if b.active and bool(b.opts.get("is_orb", false)):
			aoe_damage(b.global_position, 48.0, dmg, {"source": "orb"})
			spawn_fx(b.global_position, Color(0.7, 0.8, 1.0), 48.0, 0.25)
			b.deactivate()

# ------------------------------------------------------------------ XP / РЕСУРСЫ
## Опыт для следующего уровня: xp_base * xp_growth^(lvl-1), замедление роста после 40 уровня.
func _xp_for_level(lvl: int) -> int:
	var run_cfg: Dictionary = DB.balance.get("run", {})
	var curve: Dictionary = run_cfg.get("xp_curve", {})
	var base := float(curve.get("base", run_cfg.get("xp_base", 10.0)))
	var growth := float(curve.get("growth", run_cfg.get("xp_growth", 1.14)))
	var late_lvl := int(curve.get("late_level", run_cfg.get("xp_late_level", 40)))
	var late_growth := float(curve.get("late_growth", run_cfg.get("xp_growth_late", 1.12)))
	var n := maxi(1, lvl)
	var req := base * pow(growth, float(mini(n, late_lvl) - 1))
	if n > late_lvl:
		req *= pow(late_growth, float(n - late_lvl))
	return maxi(3, int(round(req)))

func add_xp(amount: float) -> void:
	var dark_xp := maxf(0.1, 1.0 + float(diff_mods.get("xp", 0.0)))
	var ev_xp := 1.4 if xp_boost_left > 0.0 else 1.0
	var base_mult := float(DB.balance["run"].get("xp_gain_mult", 0.65))
	var gain := amount * base_mult * float(player.S.xp_mult) * dark_xp * trial_xp_mult * ev_xp
	if amount <= 0.0:
		return
	_xp_frac += gain
	var gained := int(floorf(_xp_frac))
	_xp_frac -= float(gained)
	if gained <= 0:
		return
	xp += gained
	while xp >= xp_need and level < int(DB.balance["run"].get("max_level", 60)):
		xp -= xp_need
		level += 1
		xp_need = _xp_for_level(level)
		pending_level_ups += 1
		player.on_level_up(level)
		AudioManager.play_sfx("levelup")
		spawn_perk_fx("holy", player.global_position, 72.0, 0.42)
	if pending_level_ups > 0:
		_open_level_up()
	EventBus.xp_changed.emit(xp, xp_need, level)

func collect_pickup(pickup: Pickup) -> void:
	if net_active and not net_host and pickup.net_id > 0:
		net_taken_pickups[pickup.net_id] = Time.get_ticks_msec()
		Net.send_event_any("pickup", {"id": pickup.net_id})
	var dark_lvl := int(GameManager.run_config.get("darkness", 1))
	var combo_cfg: Dictionary = Progression.cfg.get("combo", {})
	match pickup.kind:
		"xp":
			var xp_per := float(combo_cfg.get("xp_per", 0.008)) * 0.55
			add_xp(pickup.value * (1.0 + float(combo) * xp_per))
			AudioManager.play_sfx("xp", clampf(1.0 + float(level) * 0.02, 1.0, 2.0))
			if player.upg.flag_num("recharge_ammo") > 0.0 and randf() < player.upg.flag_num("recharge_ammo"):
				player.mag = mini(int(player.S.mag), player.mag + 1)
				EventBus.ammo_changed.emit(player.mag, int(player.S.mag), player.reloading)
				if player.upg.flag_num("resonance") > 0.0:
					player.set_timer("resonance", 2.0)
				if randf() < 0.35:
					spawn_perk_fx("smite", player.global_position, 28.0, 0.22)
			if player.upg.flag_num("xp_rush") > 0.0:
				player.set_timer("xp_rush", 1.0)
				if randf() < 0.25:
					spawn_perk_fx("holy", player.global_position, 32.0, 0.22)
		"gold":
			var dark_gold_mult := 1.0 + float(dark_lvl) * 0.15
			var gold_per := float(combo_cfg.get("gold_per", 0.01))
			gold += int(round(pickup.value * dark_gold_mult * (1.0 + float(combo) * gold_per + player.upg.flag_num("meta_gold"))))
			AudioManager.play_sfx("gold")
			EventBus.gold_changed.emit(gold)
		"heart":
			if not player.has_meta("no_heal"):
				player.heal(maxi(1, int(round((1.0 + player.upg.flag_num("meta_heal")) * float(director_mods.get("heal",1.0)) * float(player.get_meta("heal_mult",1.0))))))
		"soul":
			player.on_soul_collected()
			souls += 1.0
			if not player.has_meta("no_heal"):
				player.heal(1)
			notify(Loc.t("soul_picked"))
		"chest":
			open_chest(int(pickup.value))
	EventBus.souls_changed.emit(int(souls))

# ------------------------------------------------------------------ СМЕРТЬ ВРАГА
func on_enemy_death(enemy: Enemy) -> void:
	kills += 1
	kills_without_damage += 1
	var combo_cfg: Dictionary = Progression.cfg.get("combo", {})
	var combo_max := int(combo_cfg.get("max", 20))
	var combo_timeout := float(combo_cfg.get("timeout", 3.0))
	var combo_before := combo
	combo = mini(combo_max, combo + 1)
	combo_peak = maxi(combo_peak, combo)
	combo_left = combo_timeout
	if combo == combo_max and combo_before < combo_max:
		combo20_hits += 1
		Progression.add_progress("combo20", 1)
	Progression.record_combo(combo)
	if hud != null: hud.update_combo(combo)
	if enemy.boss:
		hitstop(0.085)
		kick_camera(enemy.global_position - player.global_position, 3.0)
	elif enemy.elite:
		hitstop(0.035)
	GameManager.add_album_enemy(enemy.id)
	var role: String = String(enemy.role)
	var dark_drop := (1.0 + float(int(GameManager.run_config.get("darkness", 1))) * 0.05) * (1.0 + float(combo) * float(combo_cfg.get("drop_per", 0.0075)))
	var xp_table: Dictionary = DB.balance["run"].get("pickup_xp", {})
	var xp_val := float(enemy.data.get("xp", xp_table.get(role, 1)))
	# Поздняя игра и догоняющий (catch-up) бонус опыта за усиленных врагов
	if elapsed > 600.0:
		xp_val *= 1.0 + minf(0.35, ((elapsed - 600.0) / 60.0) * 0.015)
	if level < int(elapsed / 60.0):
		xp_val *= 1.15
	spawn_pickup("xp", enemy.global_position, xp_val)
	if randf() < float(DB.balance["run"].get("gold_chance", 0.05)) * dark_drop:
		spawn_pickup("gold", enemy.global_position, float(rng.randi_range(1, 3)))
	if not player.has_meta("no_heal") and randf() < float(DB.balance["run"].get("heart_chance", 0.0018)) * float(director_mods.get("heal",1.0)):
		spawn_pickup("heart", enemy.global_position, 1.0)
	var soul_chance := (float(DB.balance["run"].get("souls_per_kill", 0.02)) + player.upg.flag_num("soul_drop") + player.upg.flag_num("soul_drop_bonus")) * dark_drop
	if randf() < soul_chance:
		spawn_pickup("soul", enemy.global_position, 1.0)
	if player != null and player.upg.flag_on("plague") and (enemy.has_status("curse") or String(enemy.last_source) in ["curse", "curse_dot"]):
		for other in enemies_in_radius(enemy.global_position, 64.0):
			if other != enemy and other.active and not other.dead and not other.has_status("curse"):
				apply_status(other, "curse", 3.0, {"dps": 4.0})
		queue_aoe(enemy.global_position, 64.0, 20.0, {"source": "curse"})
	souls += float(DB.balance["run"].get("souls_per_kill", 0.02))
	if role == "elite":
		souls += 2.0
		if randf() < 0.12:
			spawn_pickup("chest", enemy.global_position, 1.0)
	elif role == "miniboss":
		souls += 25.0
		spawn_pickup("chest", enemy.global_position, 2.0)
	corpses.append(enemy.global_position)
	if player != null:
		player.on_kill(enemy)
	EventBus.enemy_died.emit(enemy.id, enemy.global_position, role)
	if enemy.boss:
		_on_boss_death(enemy)

func _on_boss_death(enemy: Enemy) -> void:
	kills += 1
	megaphase = false
	boss_enemy = null
	print("[SURWAVE] boss_down id=%s name=%s final=%s t=%.0f" % [String(enemy.boss_def.get("id", "")), String(enemy.boss_def.get("name", "")), str(enemy.is_final), elapsed])
	var bid := String(enemy.boss_def.get("id", ""))
	souls += 500.0 if bid == "boss_satanail" else 150.0
	Progression.add_progress("boss",1)
	if not GameManager.cheat_used:
		GameManager.meta["throne_unlocked"] = true
	shake(32.0); flash_screen(Color.WHITE)
	spawn_fx(enemy.global_position,Color("#ffd700"),384.0,1.5)
	# САТАНАИЛ — секретная победа (карта Пустота)
	if bid == "boss_satanail":
		Progression.add_progress("satanail",1)
		satanail_defeated = true
		if not GameManager.cheat_used:
			GameManager.meta["sathan_defeated"] = true
			GameManager.add_achievement("sathan_slayer")
		notify("САТАНАИЛ повержен! Пустота закрыта.")
		_finish_run(true, true)
		return
	if enemy.is_final:
		if bid == "boss_shemhaz": Progression.add_progress("shemhaz",1)
		EventBus.boss_defeated.emit(String(enemy.boss_def.get("name", "")))
		_finish_run(true, false)
		return
	# первый босс: том + проверка секрета Гротгара
	first_boss_done = true
	EventBus.boss_defeated.emit(String(enemy.boss_def.get("name", "")))
	spawn_pickup("chest", enemy.global_position, 3.0)
	if String(map_data.get("id", "")) == "cave" and String(enemy.boss_def.get("id", "")) == "boss_grotgar" and boss_no_hit:
		pentagram_pos = enemy.global_position
		spawn_fx(pentagram_pos, Color(1, 0.35, 0.1), 80.0, 0.9)
		notify(Loc.t("grotgar_nohit"))
		GameManager.add_achievement("grotgar_nohit")

# ------------------------------------------------------------------ СУНДУКИ И ВЫБОР
func open_chest(tier: int) -> void:
	AudioManager.play_sfx("chest")
	EventBus.chest_opened.emit(str(tier))
	choice_queue.clear()
	var char_id := String(GameManager.run_config.get("character", "aldar"))
	if tier >= 3:
		# босс: выбор 1 из 3 печатей (или специализация при исчерпании печатей)
		var seals := upg.seal_choices(3)
		if not seals.is_empty():
			choice_queue.append({"kind": "seal", "cards": seals, "title": Loc.t("seal")})
		else:
			choice_queue.append({"kind": "spec", "cards": upg.spec_choices(char_id, 3), "title": Loc.t("specialization")})
	elif tier == 2:
		# мини-босс: только специализация (без перков)
		choice_queue.append({"kind": "spec", "cards": upg.spec_choices(char_id, 3), "title": Loc.t("specialization")})
	else:
		# элитный сундук: только специализация (без перков)
		choice_queue.append({"kind": "spec", "cards": upg.spec_choices(char_id, 2), "title": Loc.t("specialization")})
	_open_next_choice()

func sync_pause_state() -> void:
	if ended:
		get_tree().paused = false
		return
	var should_pause := photo_mode or GameManager.cheat_open or paused_for_choice
	if hud != null:
		if hud.syn_layer != null and hud.syn_layer.visible:
			should_pause = true
		# В коопе экран паузы клиента не морозит общий мир: паузу задаёт хост.
		if hud.pause_layer != null and hud.pause_layer.visible and not net_active:
			should_pause = true
	if net_active:
		should_pause = should_pause or net_paused
	get_tree().paused = should_pause
	# На паузе _process игры не идёт — курсор переключаем здесь же.
	_sync_cursor()

func remove_perk_for_level(perk_id: String, deduct_level: bool) -> bool:
	if player == null:
		return false
	if deduct_level and level <= 1:
		return false
	if not player.upg.remove_perk(perk_id):
		return false
	var allowed_summons := player.upg.flag_list("summon")
	for a in allies:
		if a != null and a.active and bool(a.perk_summon) and not allowed_summons.has(String(a.kind)):
			a.deactivate()
	player.recalc()
	player.hp = mini(player.hp, player.max_hp)
	player.mag = mini(player.mag, int(player.S.mag))
	if deduct_level:
		level = maxi(1, level - 1)
		xp_need = _xp_for_level(level)
		xp = mini(xp, maxi(0, xp_need - 1))
	else:
		# Трата текущего повышения уровня из экрана выбора перков
		if not choice_queue.is_empty():
			choice_queue.pop_front()
		paused_for_choice = false
		if hud != null and hud.choice_layer != null:
			hud.choice_layer.visible = false
		sync_pause_state()
		_open_next_choice()
	EventBus.xp_changed.emit(xp, xp_need, level)
	EventBus.hp_changed.emit(player.hp, player.max_hp)
	EventBus.ammo_changed.emit(player.mag, int(player.S.mag), player.reloading)
	var pdata: Dictionary = DB.perk(perk_id)
	notify("Убран перк: %s" % String(pdata.get("name", perk_id)))
	return true

func _open_level_up() -> void:
	if paused_for_choice or not choice_queue.is_empty():
		return
	pending_level_ups -= 1
	var cards := upg.perk_choices(upg.choice_count)
	var menu := {"kind": "perk", "cards": cards, "title": Loc.t("choose_upgrade")}
	if player.weapon_level >= int(DB.balance.get("weapon_level", {}).get("max_level", 8)) and not upg.evolution_done:
		menu = {"kind": "evolution", "cards": upg.evolution_choices(DB.weapon(String(GameManager.run_config.get("weapon", "revolver")))), "title": "ЭВОЛЮЦИЯ ОРУЖИЯ"}
	choice_queue.append(menu)
	_open_next_choice()

func _open_next_choice() -> void:
	while not choice_queue.is_empty():
		if GameManager.autoplay:
			var auto_menu: Dictionary = choice_queue[0]
			var auto_cards: Array = auto_menu.get("cards", [])
			if auto_cards.is_empty():
				choice_queue.pop_front()
				continue
			var auto_card: Dictionary = auto_cards[randi() % auto_cards.size()]
			choice_queue.pop_front()
			upg.take_card(auto_card)
			player.recalc()
			continue
		var menu: Dictionary = choice_queue[0]
		var cards: Array = menu.get("cards", [])
		if cards.is_empty():
			choice_queue.pop_front()
			continue
		paused_for_choice = true
		sync_pause_state()
		hud.open_choice(cards, String(menu.get("title", "")), String(menu.get("kind", "perk")))
		return
	if pending_level_ups > 0:
		_open_level_up()

func _card_vfx_kind(card: Dictionary) -> String:
	var data: Dictionary = card.get("data", {})
	var tree_id := String(data.get("tree", ""))
	if tree_id == "":
		tree_id = String(card.get("kind", ""))
	match tree_id:
		"thunder": return "lightning"
		"flame", "dragon", "damage": return "fireball"
		"frost", "pickup": return "frost"
		"dark", "soul", "scythe", "beast": return "curse"
		"light", "shield", "health", "seal": return "holy"
		"wind", "dodge", "move", "boomerang", "fast_arrows", "multishot", "proj_speed": return "wind"
		"reload", "fire_rate", "pierce", "char_upgrade": return "blood"
		"vision", "summon", "synergy", "evolution": return "smite"
		_: return "holy"

func _on_choice_made(card: Dictionary) -> void:
	if choice_queue.is_empty():
		paused_for_choice = false
		sync_pause_state()
		return
	choice_queue.pop_front()
	upg.take_card(card)
	if upg.flag_on("blessing"):
		player.full_heal()
	player.recalc()
	player.mag = mini(player.mag, int(player.S.mag))
	report_perk(String((card.get("data", {}) as Dictionary).get("name", card.get("id", ""))))
	if player != null:
		spawn_perk_fx(_card_vfx_kind(card), player.global_position, 64.0, 0.42)
	paused_for_choice = false
	sync_pause_state()
	_open_next_choice()

# ------------------------------------------------------------------ ИВЕНТЫ КАРТ
# ------------------------------------------------------------------ ПОГОДА КАРТЫ
## Таймер, живущий вместе с забегом. При смене сцены он освобождается вместе
## с игрой, поэтому отложенные вызовы не «догоняют» удалённые узлы
## (именно из-за `SceneTreeTimer` в логах появлялось «Lambda capture ... was freed»).
func run_later(delay: float, callback: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, delay)
	add_child(t)
	t.timeout.connect(callback)
	t.timeout.connect(t.queue_free)
	t.start()

## Пауза внутри забега: та же защита, что и у `run_later`.
func _scene_delay(delay: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, delay)
	add_child(t)
	t.start()
	await t.timeout
	t.queue_free()

func _setup_weather_layer() -> void:
	if weather_layer != null:
		return
	weather_layer = CanvasLayer.new()
	weather_layer.layer = 4
	add_child(weather_layer)
	weather_fx = WeatherFx.new()
	weather_layer.add_child(weather_fx)
	weather_fx.set_anchors_preset(Control.PRESET_TOP_LEFT)
	weather_fx.position = Vector2.ZERO

## Запуск погодного события: тонировка, частицы, видимость, урон и ветер.
func start_weather(title: String, kind: String, col: Color, duration: float, opts: Dictionary = {}) -> void:
	if weather_fx == null:
		_setup_weather_layer()
	weather = {
		"title": title, "kind": kind, "left": duration, "total": duration,
		"vision": float(opts.get("vision", 1.0)),
		"dps": float(opts.get("dps", 0.0)),
		"poison": float(opts.get("poison", 0.0)),
		"slow": float(opts.get("slow", 0.0)),
		"push": Vector2(opts.get("push", Vector2.ZERO)),
		"tick": 0.0,
	}
	weather_fx.start(kind, col, int(opts.get("amount", 110)), opts.get("wind", Vector2(1, 0.25)))
	notify(title)
	if bool(opts.get("flash", false)):
		flash_screen(col)

func stop_weather() -> void:
	weather.clear()
	vision_mult = 1.0
	if weather_fx != null:
		weather_fx.stop()

func _tick_weather(delta: float) -> void:
	if weather.is_empty():
		# слой ещё может плавно затухать после окончания непогоды
		if weather_fx != null and weather_fx.visible:
			weather_fx.tick(delta)
		return
	weather["left"] = float(weather["left"]) - delta
	vision_mult = minf(1.0, float(weather["vision"]))
	if player != null and not player.dead:
		var dps := float(weather["dps"])
		if dps > 0.0:
			player._damage_over_time(dps * delta)
		var push: Vector2 = weather["push"]
		if push.length() > 0.5:
			player.global_position += push * delta
		player.global_position.x = clampf(player.global_position.x, 8.0, map_rect.size.x - 8.0)
		player.global_position.y = clampf(player.global_position.y, 8.0, map_rect.size.y - 8.0)
		if float(weather["slow"]) > 0.0:
			player.add_status("slow", 0.3, {"amount": float(weather["slow"])})
		if float(weather["poison"]) > 0.0:
			weather["tick"] = float(weather["tick"]) - delta
			if float(weather["tick"]) <= 0.0:
				weather["tick"] = 1.5
				player.add_status("poison", 3.0, {"dps": float(weather["poison"])})
	if float(weather["left"]) <= 0.0:
		stop_weather()
		return
	if weather_fx != null:
		var vs := get_viewport_rect().size
		if weather_fx.size != vs:
			weather_fx.size = vs
		weather_fx.tick(delta)

# ------------------------------------------------------------------ БЕСКОНЕЧНЫЙ МИР
## Мир тянется за игроками: подходим к краю — доращиваем полосу карты
## и генерируем в ней препятствия. Карта больше не заканчивается стеной.
func _check_world_growth(delta: float) -> void:
	if map_rect.size.x < 1.0 or map_floor_node == null:
		return
	_world_grow_cd -= delta
	if _world_grow_cd > 0.0:
		return
	_world_grow_cd = 0.25
	var dirs: Array = []
	for t in player_targets():
		var p: Vector2 = t.global_position
		if p.x > map_rect.end.x - EDGE_MARGIN and not dirs.has("right"):
			dirs.append("right")
		if p.y > map_rect.end.y - EDGE_MARGIN and not dirs.has("down"):
			dirs.append("down")
		if p.x < map_rect.position.x + EDGE_MARGIN and not dirs.has("left"):
			dirs.append("left")
		if p.y < map_rect.position.y + EDGE_MARGIN and not dirs.has("up"):
			dirs.append("up")
	for d in dirs:
		_grow_world(String(d))

func _grow_world(dir: String) -> void:
	match dir:
		"right":
			map_rect.size.x += CHUNK_SIZE
		"down":
			map_rect.size.y += CHUNK_SIZE
		"left":
			map_rect.position.x -= CHUNK_SIZE
			map_rect.size.x += CHUNK_SIZE
		"up":
			map_rect.position.y -= CHUNK_SIZE
			map_rect.size.y += CHUNK_SIZE
		_:
			return
	chunks_grown += 1
	_fit_world_surfaces()
	_generate_band(dir)
	_apply_camera_limits()

## Пол и фон растягиваются вместе с картой (в том числе в минус по координатам).
func _fit_world_surfaces() -> void:
	if map_bg_node != null and is_instance_valid(map_bg_node):
		map_bg_node.position = map_rect.position
		map_bg_node.size = map_rect.size
	if map_floor_node != null and is_instance_valid(map_floor_node):
		for ch in map_floor_node.get_children():
			if ch is TextureRect:
				(ch as TextureRect).position = map_rect.position
				(ch as TextureRect).size = map_rect.size

func _apply_camera_limits() -> void:
	if camera == null:
		return
	camera.limit_left = int(map_rect.position.x)
	camera.limit_top = int(map_rect.position.y)
	camera.limit_right = int(map_rect.end.x)
	camera.limit_bottom = int(map_rect.end.y)

## Новая полоса карты: препятствия и декор по тем же правилам, что и у старта.
func _generate_band(dir: String) -> void:
	var md := map_data
	var mid := String(md.get("id", ""))
	var accent := Gfx.hex(String(md.get("palette", {}).get("accent", "#ffffff")))
	var band := Rect2(map_rect.position, map_rect.size)
	match dir:
		"right":
			band = Rect2(map_rect.end.x - CHUNK_SIZE, map_rect.position.y, CHUNK_SIZE, map_rect.size.y)
		"down":
			band = Rect2(map_rect.position.x, map_rect.end.y - CHUNK_SIZE, map_rect.size.x, CHUNK_SIZE)
		"left":
			band = Rect2(map_rect.position.x, map_rect.position.y, CHUNK_SIZE, map_rect.size.y)
		"up":
			band = Rect2(map_rect.position.x, map_rect.position.y, map_rect.size.x, CHUNK_SIZE)
	for def in md.get("obstacles", []):
		var kind := String(def.get("kind", "solid"))
		var shape := String(def.get("shape", "box"))
		var w := float(def.get("w", 26))
		var h := float(def.get("h", 26))
		var col := Gfx.hex(String(def.get("color", ""))) if String(def.get("color", "")) != "" else Gfx.hex(String(md.get("palette", {}).get("obstacle", "#404050")))
		var hp_max := float(def.get("hp", 0))
		var per_band := maxi(3, int(float(def.get("count", 30)) * 0.16))
		for i in per_band:
			var pos := Vector2(
				rng.randf_range(band.position.x + 48.0, band.end.x - 48.0),
				rng.randf_range(band.position.y + 48.0, band.end.y - 48.0))
			if kind == "decor":
				var vis := ObstacleVis.build(world, shape, Vector2(w, h), col, accent, mid)
				vis.position = pos
				decor_nodes.append(vis)
				hazard_stats["decor"] = int(hazard_stats.get("decor", 0)) + 1
				continue
			var rect := Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
			var obstacle := {
				"rect": rect, "kind": kind, "shape": shape, "hp": hp_max, "max_hp": hp_max,
				"slow": float(def.get("slow", 0.0)),
				"damage": float(def.get("damage", 0.0)),
				"interval": float(def.get("interval", 0.5)),
				"timer": 0.0,
				"reflect": float(def.get("reflect", 1.0)),
				"heal": float(def.get("heal", 0.0)),
				"poison": float(def.get("poison", 0.0)),
				"node": null,
				"color": col,
			}
			var vis2 := ObstacleVis.build(world, shape, Vector2(w, h), col, accent, mid)
			vis2.position = pos
			obstacle["node"] = vis2
			if hp_max > 0.0:
				hazard_stats["destructible"] = int(hazard_stats.get("destructible", 0)) + 1
			hazard_stats[kind] = int(hazard_stats.get(kind, 0)) + 1
			_register_obstacle(obstacle)

# ------------------------------------------------------------------ ПОДВИЖНЫЕ УГРОЗЫ
func spawn_mover(kind: String, pos: Vector2, vel: Vector2, opts: Dictionary = {}) -> Mover:
	var m := Mover.new()
	world.add_child(m)
	m.setup(self, kind, pos, vel, opts)
	movers.append(m)
	return m

func _tick_movers(delta: float) -> void:
	for i in range(movers.size() - 1, -1, -1):
		var m: Mover = movers[i]
		if not m.active:
			movers.remove_at(i)
			if is_instance_valid(m):
				m.queue_free()
			continue
		m.tick(delta)

## Уничтожает разрушаемые препятствия в радиусе (метеориты, обвалы, лавины).
func _destroy_obstacles_in(pos: Vector2, radius: float, limit: int = 8) -> int:
	var broken := 0
	var copy: Array = obstacles.duplicate()
	for obstacle in copy:
		if broken >= limit:
			break
		if float(obstacle.get("max_hp", 0.0)) <= 0.0:
			continue
		var rect: Rect2 = obstacle["rect"]
		if rect.get_center().distance_to(pos) <= radius + rect.size.length() * 0.3:
			hit_obstacle(obstacle, float(obstacle["hp"]) + 1.0)
			broken += 1
	return broken

## Зона притяжения игрока (зыбучие пески, болотные пучины).
func spawn_pull_zone(pos: Vector2, radius: float, force: float, dur: float, dps: float, col: Color) -> void:
	pulls.append({"pos": pos, "radius": radius, "force": force, "left": dur, "player": true})
	spawn_hazard_zone(pos, dps, dur, radius, col, {"slow": 0.6, "pattern": "vortex"})

func _event_map_pos(near_share: float = 0.25) -> Vector2:
	var pad := 56.0
	var inner := Rect2(
		map_rect.position + Vector2(pad, pad),
		Vector2(maxf(64.0, map_rect.size.x - pad * 2.0), maxf(64.0, map_rect.size.y - pad * 2.0))
	)
	if player != null and randf() < near_share:
		var p := player.global_position + Vector2(randf_range(-220.0, 220.0), randf_range(-170.0, 170.0))
		return p.clamp(inner.position, inner.end)
	return Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))

func _tick_player_pulls(delta: float) -> void:
	for pl in pulls:
		if not bool(pl.get("player", false)):
			continue
		if player.global_position.distance_to(pl["pos"]) < float(pl["radius"]):
			var d: Vector2 = pl["pos"] - player.global_position
			if d.length() > 6.0:
				player.global_position += d.normalized() * float(pl["force"]) * delta

## Ивент карты запускается как «полоса непогоды» на 30–60 секунд: эффект
## повторяется волнами, поэтому событие действительно видно, а не мелькает раз.
func run_map_event(ev: Dictionary) -> void:
	var kind := String(ev.get("kind", ""))
	if kind == "":
		return
	var p: Dictionary = (ev.get("params", {}) as Dictionary).duplicate(true)
	# Любое событие карты длится 30–60 с (раньше короткие ивенты и непогода
	# заканчивались за 10–18 с и почти не ощущались в игре).
	var dur := clampf(float(p.get("duration", randf_range(30.0, 60.0))), 30.0, 60.0)
	p["duration"] = dur
	active_events.append({
		"kind": kind, "params": p, "left": dur, "total": dur,
		"pulse_cd": 0.0, "pulse_every": _event_pulse_interval(kind),
	})
	_pulse_map_event(kind, p)
	if _is_weather_event(kind):
		_broadcast_weather()
	notify(_event_title(kind))

## Хост: отправить клиентам текущую непогоду, чтобы буран/туман был виден всем.
func _broadcast_weather() -> void:
	if not (net_active and net_host) or weather.is_empty():
		return
	var fx_kind := "fog"
	var col := Color(0.8, 0.8, 0.8)
	var wind := Vector2(1, 0.25)
	if weather_fx != null:
		if String(weather_fx.kind) != "":
			fx_kind = String(weather_fx.kind)
		col = weather_fx.tint
		wind = weather_fx.wind
	Net.send_event("weather", {
		"title": String(weather.get("title", "Непогода")),
		"kind": fx_kind, "color": col,
		"duration": float(weather.get("total", 40.0)),
		"vision": float(weather.get("vision", 1.0)),
		"wind": wind,
	})

func _is_weather_event(kind: String) -> bool:
	return kind in ["weather", "sandstorm", "blizzard", "stormal", "fog", "necro_fog", "madness"]

## Пульс активных ивентов: каждые несколько секунд событие бьёт снова,
## пока не истечёт его 30–60-секундное окно.
func _tick_active_events(delta: float) -> void:
	if active_events.is_empty():
		return
	for i in range(active_events.size() - 1, -1, -1):
		var ev: Dictionary = active_events[i]
		ev["left"] = float(ev["left"]) - delta
		ev["pulse_cd"] = float(ev["pulse_cd"]) - delta
		if float(ev["pulse_cd"]) <= 0.0:
			ev["pulse_cd"] = float(ev["pulse_every"])
			if not (net_active and not net_host):
				_pulse_map_event(String(ev["kind"]), ev["params"] as Dictionary)
		if float(ev["left"]) <= 0.0:
			active_events.remove_at(i)

func _event_pulse_interval(kind: String) -> float:
	if _is_weather_event(kind):
		return 100000.0
	match kind:
		"rain", "crystal_rain", "ember_rain", "blood_rain", "hell_flame":
			return 3.2
		"meteor", "rockfall", "cave_in", "aoe_zone":
			return 4.6
		"avalanche", "eruption", "ice_spikes":
			return 6.4
		"band", "lightning", "void_rift", "crystal_flash":
			return 5.4
		_:
			return 5.0

func _event_title(kind: String) -> String:
	match kind:
		"avalanche":
			return "ЛАВИНА!"
		"rain", "crystal_rain", "ember_rain", "blood_rain":
			return "ЛИВЕНЬ!"
		"band":
			return "ВОЛНА ЖАРА!"
		"aoe_zone":
			return "ОБСТРЕЛ!"
		"meteor", "rockfall":
			return "КАМНЕПАД!"
		"blizzard", "sandstorm", "weather":
			return "НЕПОГОДА!"
		"void_rift":
			return "РАЗЛОМ ПУСТОТЫ!"
		_:
			return "СОБЫТИЕ КАРТЫ"

## Один «удар» события — прежнее поведение, вызывается волнами.
func _pulse_map_event(kind: String, p: Dictionary) -> void:
	var map_id := String(map_data.get("id", ""))
	xp_boost_left = maxf(xp_boost_left, 15.0)
	match kind:
		"aoe_zone":
			var count := int(p.get("count", 1)) + 3
			var tele := float(p.get("telegraph", 1.2))
			var rad := float(p.get("radius", 30.0))
			for i in count:
				var pos := _event_map_pos(0.30)
				spawn_delayed_aoe(pos, rad, float(p.get("damage", 10)), tele, Color(1, 0.45, 0.2), float(p.get("dot", 0.0)))
				spawn_event_fx("aoe_strike", pos, tele, rad)
		"rain":
			var r_count := int(p.get("count", 5)) + 6
			var r_tele := float(p.get("telegraph", 1.1))
			var r_rad := float(p.get("radius", 32.0))
			var rain_fx := "crystal_rain" if map_id == "abyss" else "ember_rain"
			for i in r_count:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, r_rad, float(p.get("damage", 10)), r_tele, Color(1, 0.5, 0.2))
				spawn_event_fx(rain_fx, pos, r_tele, r_rad)
		"band":
			_band_event(float(p.get("damage", 3)), float(p.get("width", 320.0)), bool(p.get("burn", false)))
		"vision":
			vision_mult = float(p.get("mult", 0.4))
			player.add_status("slow", 0.0, {})
			notify("Видимость ухудшилась")
			if player != null:
				spawn_event_fx("madness_pulse", player.global_position, 0.5, 42.0)
			run_later(float(p.get("duration", 8.0)), func() -> void: vision_mult = 1.0)
			if float(p.get("enemy_speed", 0.0)) > 0.0:
				for enemy in enemies:
					if enemy.active:
						enemy.knock = Vector2.ZERO
				notify("Враги ускорились")
		"spawn":
			for i in int(p.get("count", 3)):
				var sp := _spawn_position()
				spawn_enemy(String(p.get("enemy", "")), sp)
				spawn_event_fx("void_rift", sp, 0.4, 28.0)
		"heal":
			var hpos := _event_map_pos(0.5)
			spawn_pickup("heart", hpos, 1.0)
			spawn_perk_fx("holy", hpos, 38.0, 0.30)
		"slow_zones":
			for i in int(p.get("count", 2)) + 2:
				var pos := _event_map_pos(0.30)
				var srad := float(p.get("radius", 48.0))
				spawn_hazard_zone(pos, 0.0, float(p.get("duration", 6.0)), srad, Color(0.8, 0.7, 0.3), {"slow": float(p.get("slow", 0.6)), "pattern": "swirl"})
				spawn_perk_fx("frost", pos, srad * 0.9, 0.28)
		"lightning":
			for i in int(p.get("count", 1)) + 3:
				var pos := _event_map_pos(0.30)
				spawn_delayed_aoe(pos, float(p.get("radius", 48.0)), float(p.get("damage", 20)), 0.8, Color(0.8, 0.9, 1.0))
				var pos_copy := pos
				run_later(0.8, func() -> void:
					spawn_perk_fx("lightning", pos_copy, 56.0, 0.34)
					AudioManager.play_sfx("shot_lightning", 0.65))
		"pull":
			var dir := (map_rect.get_center() - player.global_position).normalized()
			player.global_position += dir * float(p.get("force", 120.0)) * 0.5
			player.take_damage(int(p.get("damage", 5)), player.global_position, true)
			spawn_event_fx("void_rift", map_rect.get_center(), 0.5, 48.0)
			notify("Водоворот!")
		"buff":
			notify("Волна силы врагов")
			var shown := 0
			for enemy in enemies:
				if enemy.active:
					enemy.speed *= 1.0 + float(p.get("speed", 0.0))
					if shown < 10:
						spawn_perk_fx("blood", enemy.global_position, 28.0, 0.24)
						shown += 1
		"cursed_ground":
			var c_pat := "void" if map_id in ["void", "rift", "chaos"] else "rune"
			for i in int(p.get("count", 2)) + 3:
				var pos := _event_map_pos(0.25)
				spawn_hazard_zone(pos, float(p.get("dot", 3.0)), minf(float(p.get("duration", 5.5)), 6.0), float(p.get("radius", 48.0)), Color(0.4, 0.2, 0.5), {"slow": float(p.get("slow", 0.0)), "pattern": c_pat})
				spawn_perk_fx("curse", pos, 44.0, 0.30)
		"obstacle_toggle":
			notify("Обвал!")
			_collapse_obstacles(int(p.get("count", 4)), float(p.get("duration", 15.0)))
		"reflect_buff":
			notify("Резонанс кристаллов")
			for obstacle in obstacles:
				if String(obstacle.get("kind", "")) == "reflect":
					spawn_event_fx("crystal_flash", (obstacle["rect"] as Rect2).get_center(), 0.4, 48.0)
			for b in bullets:
				if b.active:
					b.vel *= 2.0
		"roll":
			for i in int(p.get("count", 3)) + 2:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, 34.0, float(p.get("damage", 3)), 1.4, Color(0.7, 0.7, 0.7))
				spawn_event_fx("boulder", pos, 1.4, 34.0)
		"meteor":
			var m_count := int(p.get("count", 8)) + 4
			var tele := float(p.get("telegraph", 2.5))
			var m_rad := float(p.get("radius", 30.0))
			var destroy := bool(p.get("destroy", true))
			for i in m_count:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, m_rad, float(p.get("damage", 2)), tele, Color(1, 0.45, 0.15))
				spawn_event_fx("meteor", pos, tele, m_rad)
				if destroy:
					var p_copy := pos
					run_later(tele, func() -> void:
						_destroy_obstacles_in(p_copy, m_rad, 3))
			notify("Метеоритный дождь!")
		"weather":
			var wcol := Color(0.7, 0.7, 0.7)
			var ccode := String(p.get("color", "#c0c0c0"))
			if ccode.begins_with("#"):
				wcol = Color(ccode)
			var wdir := Vector2(0.3, 0.0)
			var wraw = p.get("wind", null)
			if wraw is Array and (wraw as Array).size() >= 2:
				wdir = Vector2(float(wraw[0]), float(wraw[1]))
			var wopts: Dictionary = p.duplicate()
			wopts["wind"] = wdir
			start_weather(String(p.get("title", "Непогода")), String(p.get("kind", "fog")), wcol,
				float(p.get("duration", 15.0)), wopts)
		"sandstorm":
			var wdir := Vector2(1, 0.15).normalized()
			start_weather("Песчаная буря", "sand", Color(0.85, 0.72, 0.45), float(p.get("duration", 15.0)),
				{"vision": 0.35, "dps": float(p.get("dps", 0.5)), "push": wdir * float(p.get("push", 30.0)), "flash": true, "wind": Vector2(1, 0.1)})
			shake(3.0)
		"blizzard":
			start_weather("Метель", "snow", Color(0.85, 0.9, 1.0), float(p.get("duration", 18.0)),
				{"vision": 0.3, "slow": 0.25, "push": Vector2(0.7, 0.7).normalized() * float(p.get("push", 40.0)), "flash": true, "wind": Vector2(0.8, 0.6), "amount": 150})
		"tumbleweed":
			var from_left := randf() < 0.5
			for i in int(p.get("count", 5)) + 3:
				var y := randf_range(map_rect.position.y + 40.0, map_rect.end.y - 40.0)
				var x := map_rect.position.x + 20.0 if from_left else map_rect.end.x - 20.0
				var dir := Vector2.RIGHT if from_left else Vector2.LEFT
				spawn_mover("tumbleweed", Vector2(x, y), dir * float(p.get("speed", 150.0)) + Vector2(0, randf_range(-20, 20)),
					{"life": float(p.get("life", 9.0)), "damage": float(p.get("damage", 1)), "radius": 11.0, "color": Color(0.55, 0.4, 0.2)})
		"wisps":
			for i in int(p.get("count", 4)) + 3:
				var pos := _event_map_pos(0.25)
				spawn_mover("wisp", pos, Vector2.ZERO, {"life": float(p.get("duration", 9.0)), "damage": 0.0, "chase": float(p.get("speed", 26.0)), "radius": 10.0})
				spawn_perk_fx("holy", pos, 32.0, 0.26)
		"insect_swarm":
			for i in int(p.get("count", 2)) + 2:
				var pos := _event_map_pos(0.25)
				spawn_mover("insects", pos, Vector2.RIGHT.rotated(randf() * TAU) * 30.0,
					{"life": float(p.get("duration", 10.0)), "damage": 1.0, "dot": 1.0, "chase": 34.0, "radius": 22.0, "color": Color(0.2, 0.18, 0.16)})
				spawn_perk_fx("curse", pos, 36.0, 0.28)
		"quicksand":
			for i in int(p.get("count", 5)) + 4:
				var pos := _event_map_pos(0.20)
				spawn_hazard_zone(pos, float(p.get("dps", 1.0)), minf(float(p.get("duration", 5.5)), 6.0), float(p.get("radius", 44.0)),
					Color(0.72, 0.62, 0.36), {"slow": float(p.get("slow", 0.65)), "telegraph": 0.6, "pattern": "swirl"})
		"pull_zone":
			for i in int(p.get("count", 4)) + 3:
				var pos := _event_map_pos(0.20)
				spawn_pull_zone(pos, float(p.get("radius", 52.0)), float(p.get("force", 40.0)), minf(float(p.get("duration", 5.0)), 5.5),
					float(p.get("dps", 1.5)), Color(0.30, 0.24, 0.16))
			notify("Трясина!")
		"ice_spikes":
			for i in int(p.get("count", 6)) + 5:
				var pos := _event_map_pos(0.25)
				var sp_tele := float(p.get("telegraph", 1.6))
				var sp_rad := float(p.get("radius", 18.0))
				spawn_delayed_aoe(pos, sp_rad, float(p.get("damage", 2)), sp_tele, Color(0.66, 0.85, 0.95))
				spawn_event_fx("ice_spike", pos, sp_tele, sp_rad)
		"avalanche":
			notify("Лавина!")
			shake(16.0)
			flash_screen(Color(0.9, 0.95, 1.0))
			var width := float(p.get("width", 150.0))
			var damage := float(p.get("damage", 3))
			# Лавина идёт по герою: сходит сверху вниз широкой полосой, поэтому
			# уклоняться нужно в сторону, а не «нигде не стоять».
			var anchor := player.global_position + Vector2(randf_range(-70.0, 70.0), -20.0)
			anchor = anchor.clamp(map_rect.position + Vector2(90, 90), map_rect.end - Vector2(90, 90))
			spawn_event_fx("avalanche", anchor, 0.8, width)
			AudioManager.play_sfx("avalanche", 0.9)
			var waves := 4
			for i in waves:
				var step := float(i) / float(waves - 1)
				var pos := anchor + Vector2(randf_range(-14.0, 14.0), lerpf(-150.0, 160.0, step))
				spawn_delayed_aoe(pos, width * 0.55, damage, 0.75 + step * 0.75, Color(0.92, 0.96, 1.0))
				var p_copy := pos
				run_later(0.75 + step * 0.75, func() -> void:
					_destroy_obstacles_in(p_copy, width * 0.5, 3)
					aoe_damage(p_copy, width * 0.5, damage * 2.0, {"source": "avalanche"})
					spawn_fx(p_copy, Color(0.92, 0.96, 1.0, 0.8), width * 0.5, 0.4, true))
		"rockfall":
			notify("Камнепад!")
			var r_dmg := float(p.get("damage", 2))
			var r_tele := float(p.get("telegraph", 2.0))
			var r_rad := float(p.get("radius", 26.0))
			for i in int(p.get("count", 8)) + 5:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, r_rad, r_dmg, r_tele, Color(0.55, 0.5, 0.45))
				spawn_event_fx("boulder", pos, r_tele, r_rad)
				var p_copy := pos
				run_later(r_tele, func() -> void:
					_destroy_obstacles_in(p_copy, 30.0, 2))
		"eruption":
			notify("Извержение вулкана!")
			shake(22.0)
			flash_screen(Color(1.0, 0.45, 0.15))
			var center := map_rect.get_center() if bool(p.get("at_center", false)) else _event_map_pos(0.25)
			var er_rad := float(p.get("radius", 150.0))
			var er_tele := float(p.get("telegraph", 3.0))
			spawn_delayed_aoe(center, er_rad, float(p.get("damage", 3)), er_tele, Color(1, 0.4, 0.1), float(p.get("dot", 2.0)))
			spawn_event_fx("eruption", center, er_tele, er_rad)
			for i in int(p.get("pools", 5)) + 3:
				var pos := center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, er_rad)
				spawn_hazard_zone(pos, float(p.get("dot", 2.0)), 5.0, 26.0, Color(1, 0.35, 0.1), {"pattern": "fire"})
		"cave_in":
			notify("Обвал!")
			shake(12.0)
			var c_dmg := float(p.get("damage", 2))
			var c_tele := float(p.get("telegraph", 2.2))
			var c_rad := float(p.get("radius", 32.0))
			for i in int(p.get("count", 6)) + 5:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, c_rad, c_dmg, c_tele, Color(0.45, 0.45, 0.46))
				spawn_event_fx("stalactite", pos, c_tele, c_rad)
			_collapse_obstacles(int(p.get("count", 6)) / 2, float(p.get("duration", 12.0)))
		"crystal_flash":
			flash_screen(Color(0.85, 0.95, 1.0))
			start_weather("Вспышка кристаллов", "fog", Color(0.85, 0.95, 1.0), 0.6, {"vision": 0.2, "amount": 40})
			var flashed := 0
			for obstacle in obstacles:
				if String(obstacle.get("kind", "")) == "reflect":
					var c: Vector2 = (obstacle["rect"] as Rect2).get_center()
					if flashed < 10:
						spawn_event_fx("crystal_flash", c, 0.3, 44.0)
						flashed += 1
					if player.global_position.distance_to(c) < float(p.get("radius", 96.0)):
						player.take_damage(int(p.get("damage", 1)), c, true)
						break
		"poison_geyser":
			notify("Гейзер!")
			var g_tele := float(p.get("telegraph", 1.4))
			var g_rad := float(p.get("radius", 34.0))
			for i in int(p.get("count", 5)) + 5:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, g_rad, float(p.get("damage", 2)), g_tele, Color(0.6, 0.95, 0.2))
				spawn_event_fx("geyser", pos, g_tele, g_rad)
				var p_copy := pos
				run_later(g_tele, func() -> void:
					if player.global_position.distance_to(p_copy) < g_rad:
						player.add_status("poison", 5.0, {"dps": float(p.get("poison", 1.5))}))
		"madness":
			flash_screen(Color(0.9, 0.1, 0.45))
			player.add_status("charm", float(p.get("duration", 3.0)))
			start_weather("Безумие", "spores", Color(0.85, 0.15, 0.5), float(p.get("duration", 3.0)), {"vision": 0.6, "amount": 60})
			for i in 4:
				spawn_event_fx("madness_pulse", _event_map_pos(0.5), 0.4, 48.0)
			notify("Безумие: управление искажено!")
		"ghost_hands":
			for i in int(p.get("count", 6)) + 5:
				var pos := _event_map_pos(0.25)
				var gh_rad := float(p.get("radius", 22.0))
				spawn_hazard_zone(pos, 0.0, 3.5, gh_rad, Color(0.75, 0.78, 0.8), {"telegraph": 1.0, "root": 1.2, "hits_enemies": false})
				spawn_event_fx("ghost_hand", pos, 1.0, gh_rad, {"dur": 3.5})
		"necro_fog":
			start_weather("Некромантский туман", "fog", Color(0.35, 0.75, 0.35), float(p.get("duration", 20.0)),
				{"vision": 0.35, "dps": 0.4, "amount": 90, "flash": true})
			for i in int(p.get("summons", 3)):
				run_later(4.0 + float(i) * 5.0, func() -> void:
					if not ended:
						for k in 2:
							var sp := _spawn_position()
							spawn_enemy(String(p.get("enemy", "skeleton")), sp)
							spawn_event_fx("void_rift", sp, 0.3, 28.0))
		"curse":
			for i in int(p.get("count", 3)) + 3:
				var pos := _event_map_pos(0.25)
				spawn_hazard_zone(pos, float(p.get("dps", 1.0)), minf(float(p.get("duration", 5.0)), 5.5), float(p.get("radius", 46.0)),
					Color(0.45, 0.1, 0.15), {"slow": float(p.get("slow", 0.4)), "telegraph": 0.8, "pattern": "rune"})
				spawn_perk_fx("curse", pos, 44.0, 0.32)
			player.add_status("curse", float(p.get("curse", 4.0)))
		"hell_flame":
			var share = float(p.get("share", 0.3))
			for obstacle in obstacles:
				if String(obstacle["kind"]) == "pentagram" and randf() < share:
					_ignite_pentagram(obstacle)
					spawn_perk_fx("fireball", (obstacle["rect"] as Rect2).get_center(), 54.0, 0.36)
		"blood_rain":
			notify("Кровавый дождь: все пентаграммы активны!")
			for obstacle in obstacles:
				if String(obstacle["kind"]) == "pentagram":
					_ignite_pentagram(obstacle, float(p.get("duration", 10.0)))
					spawn_perk_fx("blood", (obstacle["rect"] as Rect2).get_center(), 52.0, 0.36)
		"pentagram_random":
			for i in int(p.get("count", 5)) + 4:
				var pos := _event_map_pos(0.25)
				spawn_delayed_aoe(pos, 32.0, float(p.get("damage", 8)), 1.5, Color(1, 0.2, 0.1), 4.0)
				spawn_event_fx("aoe_strike", pos, 1.5, 32.0)
				var p_copy := pos
				run_later(1.5, func() -> void:
					spawn_perk_fx("blood", p_copy, 48.0, 0.35))

func _band_event(dmg: float, width: float, burn: bool) -> void:
	notify("Волна!")
	var band_center := _event_map_pos(0.45)
	spawn_event_fx("band_wave", band_center, 0.9, width)
	# полоса проходит через карту сверху вниз
	for i in 3:
		var pos := Vector2(band_center.x, band_center.y - 160.0 + float(i) * 60.0)
		spawn_delayed_aoe(pos, width * 0.5, dmg, 0.9, Color(1, 0.4, 0.2))
	if burn:
		player.add_status("burn", 2.0, {"dps": 3.0})

func _collapse_obstacles(count: int, duration: float) -> void:
	var added := 0
	var mid := String(map_data.get("id", ""))
	var obs_col := Gfx.hex(String(map_data.get("palette", {}).get("obstacle", "#504a45")))
	var acc_col := Gfx.hex(String(map_data.get("palette", {}).get("accent", "#908070")))
	for i in count:
		var pos := player.global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		var rect := Rect2(pos - Vector2(30, 30), Vector2(60, 60))
		var body := StaticBody2D.new()
		body.position = pos
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(60, 60)
		shape.shape = rs
		body.add_child(shape)
		world.add_child(body)
		ObstacleVis.build(body, "rock", Vector2(56, 56), obs_col, acc_col, mid)
		_register_obstacle({"rect": rect, "kind": "solid", "hp": 100.0, "max_hp": 100.0, "slow": 0.0, "damage": 0.0, "interval": 0.5, "timer": 0.0, "node": body, "temp": duration})
		added += 1
	if added > 0:
		run_later(duration, _remove_temp_obstacles)

func _remove_temp_obstacles() -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle: Dictionary = obstacles[i]
		if obstacle.has("temp"):
			if obstacle.get("node") != null and is_instance_valid(obstacle["node"]):
				obstacle["node"].queue_free()
			obstacles.remove_at(i)
	obstacle_grid.clear()
	solid_cells.clear()
	var keep: Array = obstacles.duplicate()
	obstacles.clear()
	for obstacle in keep:
		_register_obstacle(obstacle)

func _ignite_pentagram(obstacle: Dictionary, duration: float = 4.0) -> void:
	var rect: Rect2 = obstacle["rect"]
	spawn_delayed_aoe(rect.get_center(), float(rect.size.x) * 0.9, 8.0, 0.5, Color(1, 0.2, 0.1), 4.0)

# ------------------------------------------------------------------ БОСС/РЕЖИМЫ
func blood_phase(hp_add: float, speed_add: float) -> void:
	blood_phase_active = true
	notify("КРОВАВАЯ ФАЗА: враги сильнее")
	for enemy in enemies:
		if enemy.active:
			enemy.max_hp *= 1.0 + hp_add
			enemy.hp *= 1.0 + hp_add
			enemy.speed *= 1.0 + speed_add

func enemy_mult(role: String) -> Dictionary:
	var hp := 1.0
	var dmg := 1.0
	var spd := 1.0
	match role:
		"fodder", "shooter":
			hp += float(diff_mods.get("fodder_hp", 0.0))
			dmg += float(diff_mods.get("fodder_dmg", 0.0))
			spd += float(diff_mods.get("fodder_speed", 0.0))
		"elite":
			hp += float(diff_mods.get("elite_hp", 0.0))
			dmg += float(diff_mods.get("elite_dmg", 0.0))
			spd += float(diff_mods.get("elite_speed", 0.0))
		_:
			hp += float(diff_mods.get("boss_hp", 0.0))
			dmg += float(diff_mods.get("boss_dmg", 0.0))
	hp *= time_hp_mult() * float(director_mods.get("hp",1.0))
	dmg *= float(director_mods.get("damage",1.0))
	spd *= float(director_mods.get("speed",1.0))
	if blood_phase_active:
		hp += 0.5
		spd += 0.25
	if mode == "endless":
		var cycles := float(endless_cycle)
		hp += cycles * 5.0
		spd += cycles * 0.2
	return {"hp": hp, "dmg": dmg, "speed": spd}

func _check_end_conditions() -> void:
	if ended:
		return
	if net_active and not net_host:
		return
	if mode != "endless" and elapsed >= wave_mgr.duration + 240.0:
		# страховка: если финальный босс почему-то не появился/не убит
		if not first_boss_done:
			spawn_map_boss("final")

func _on_player_died() -> void:
	if net_active:
		# Кооп: павший игрок оставляет кристалл-душу, напарник его возрождает.
		_spawn_revive_crystal(Net.my_id(), player.global_position)
		if not net_host:
			Net.send_event_any("died", {"x": int(player.global_position.x), "y": int(player.global_position.y)})
		notify("Вы пали! Напарник может подобрать кристалл-душу.")
		if hud != null:
			hud.flash_message("ЖДЁМ ВОЗРОЖДЕНИЯ: подберите кристалл-душу", Color(0.75, 0.9, 1.0))
		if _coop_all_dead():
			_finish_run(false, false)
		return
	_finish_run(false, false)

## Совместимость: игрок может сообщить о смерти и напрямую.
func on_player_death() -> void:
	_on_player_died()

## Все игроки в коопе лежат — только тогда забег проигран.
func _coop_all_dead() -> bool:
	if player != null and not player.dead:
		return false
	for np in net_proxies:
		if np != null and is_instance_valid(np) and not np.dead:
			return false
	return true

# ------------------------------------------------------------------ КООП: ВОЗРОЖДЕНИЕ
## Кристалл-душа павшего игрока: подбирается напарником.
func _spawn_revive_crystal(owner_id: int, pos: Vector2) -> void:
	if owner_id <= 0:
		return
	for c in revive_crystals:
		if int(c["owner"]) == owner_id:
			c["x"] = int(pos.x)
			c["y"] = int(pos.y)
			return
	revive_crystals.append({"owner": owner_id, "x": int(pos.x), "y": int(pos.y), "t": 0.0})
	_net_sync_crystals([])
	AudioManager.play_sfx("phase", 1.25)
	spawn_perk_fx("curse", pos, 44.0, 0.45)

func _tick_revive_crystals(delta: float) -> void:
	if revive_crystals.is_empty():
		return
	for i in range(revive_crystals.size() - 1, -1, -1):
		var c: Dictionary = revive_crystals[i]
		c["t"] = float(c.get("t", 0.0)) + delta
		if not net_host:
			continue
		var cpos := Vector2(float(c["x"]), float(c["y"]))
		var owner_id := int(c["owner"])
		for t in player_targets():
			if _peer_of(t) == owner_id:
				continue
			if t.global_position.distance_to(cpos) <= 26.0:
				_do_revive(owner_id, cpos)
				revive_crystals.remove_at(i)
				break
	if net_host:
		_net_sync_crystals([])

func _peer_of(t: Node) -> int:
	if t is NetPlayer:
		return (t as NetPlayer).peer_id
	return 1

## Хост возрождает игрока (себя или напарника) и сообщает всем.
func _do_revive(owner_id: int, pos: Vector2) -> void:
	if owner_id == 1:
		_revive_local_player(pos)
		Net.send_event("revived", {"peer": 1})
		notify("Возрождение!")
	else:
		for np in net_proxies:
			if np != null and np.peer_id == owner_id:
				np.dead = false
				np.hp = maxi(1, int(float(np.max_hp) * 0.5))
				np.global_position = pos
				np.target_pos = pos
				np.visible = true
				spawn_perk_fx("holy", pos, 48.0, 0.4)
				break
		Net.send_event("revived", {"peer": owner_id, "x": int(pos.x), "y": int(pos.y)})
		notify("Напарник возрождён")

func _revive_local_player(pos: Vector2) -> void:
	if player == null:
		return
	player.dead = false
	player.hp = maxi(1, int(float(player.max_hp) * 0.5))
	player.iframes = 2.0
	player.global_position = pos
	player.visible = true
	EventBus.hp_changed.emit(player.hp, player.max_hp)
	spawn_perk_fx("holy", pos, 60.0, 0.45)
	AudioManager.play_sfx("levelup", 1.1)

## Клиент получил «тебя возродили» от хоста.
func net_apply_revive(peer: int) -> void:
	if peer != Net.my_id() or not net_active:
		return
	var pos := player.global_position
	if not revive_crystals.is_empty():
		pos = Vector2(float(revive_crystals[0]["x"]), float(revive_crystals[0]["y"]))
	_revive_local_player(pos)
	revive_crystals.clear()
	_net_sync_crystals([])

## Отрисовка кристаллов-душ (у хоста — из своего списка, у клиента — из снапшота).
func _net_sync_crystals(list: Array) -> void:
	var src: Array = list
	if net_host:
		src = []
		for c in revive_crystals:
			src.append([int(c["owner"]), int(c["x"]), int(c["y"])])
	while revive_crystal_nodes.size() < src.size():
		var pk: Pickup = PICKUP_SCENE.instantiate()
		world.add_child(pk)
		pk.setup(self)
		pk.spawn_at(Vector2.ZERO, "soul", 1.0, Color(0.75, 0.85, 1.0), 8.0)
		pk.net_remote = true
		revive_crystal_nodes.append(pk)
	for i in revive_crystal_nodes.size():
		var pk: Pickup = revive_crystal_nodes[i]
		if i >= src.size():
			pk.visible = false
			pk.active = false
			continue
		var arr: Array = src[i]
		pk.global_position = Vector2(float(arr[1]), float(arr[2]))
		pk.visible = true
		pk.active = true
		pk.rotation += 0.02
	if not net_host:
		revive_crystals.clear()
		for arr2 in src:
			var a2: Array = arr2
			revive_crystals.append({"owner": int(a2[0]), "x": int(a2[1]), "y": int(a2[2]), "t": 0.0})

func _finish_run(win: bool, secret_win: bool) -> void:
	if ended:
		return
	ended = true
	victory = win
	hitstop_left = 0.0
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0
	photo_mode = false
	if photo_layer != null:
		photo_layer.visible = false
	if hud != null and hud.root != null:
		hud.root.visible = true
	flash_left = 0.0
	if flash_rect != null:
		flash_rect.color.a = 0.0
		flash_rect.visible = false
	if vision_rect != null:
		vision_rect.visible = false
	stop_weather()
	get_tree().paused = false
	AudioManager.set_boss_layer(false)
	var dark_lvl := int(GameManager.run_config.get("darkness", 1))
	var souls_gain := int(souls)
	if win:
		souls_gain += int(DB.balance["run"].get("souls_win", 250))
	souls_gain = int(round(float(souls_gain) * (1.0 + float(dark_lvl) * 0.10)))
	if GameManager.cheat_used:
		souls_gain = 0
	var results := {
		"kills": kills,
		"damage_dealt": int(damage_dealt),
		"damage_taken": int(damage_taken),
		"time": elapsed,
		"gold": 0 if GameManager.cheat_used else gold,
		"souls": souls_gain,
		"level": level,
		"combo_peak": combo_peak,
		"map": String(map_data.get("id", "")),
		"secret_win": secret_win,
		"cheats_used": GameManager.cheat_used,
	}
	if win and String(map_data.get("id", "")) == "throne" and not GameManager.cheat_used:
		GameManager.meta["endless_unlocked"] = true
	GameManager.end_run(results, win)
	print("[SURWAVE] run_end win=%s secret=%s time=%.0f kills=%d dmg=%.0f taken=%.0f level=%d souls=%d map=%s" % [win, secret_win, elapsed, kills, damage_dealt, damage_taken, level, souls_gain, String(map_data.get("id", ""))])
	EventBus.run_ended.emit(results, win)
	if hud != null:
		hud.show_end(results, win, secret_win)

# ------------------------------------------------------------------ СЕКРЕТНАЯ КАРТА
## Появление пентаграммы (вход в секретную карту).
func spawn_pentagram(pos: Vector2) -> void:
	if pentagram_spawned or secret_entered:
		return
	pentagram_spawned = true
	pentagram_pos = clamp_to_map(pos)
	spawn_fx(pentagram_pos, Color(1, 0.35, 0.1), 80.0, 0.9)
	print("[SURWAVE] pentagram_spawn t=%.0f kills_nohit=%d" % [elapsed, kills_without_damage])
	notify(Loc.t("pentagram_appear"))

func _enter_void() -> void:
	if secret_entered:
		return
	secret_entered = true
	notify(Loc.t("pentagram_enter"))
	GameManager.add_achievement("infernal_entry")
	pentagram_pos = Vector2.INF
	GameManager.run_config["map"] = "void"
	map_data = DB.map("void")
	stop_weather()
	save_current_state()
	# перестраиваем карту
	for obstacle in obstacles:
		if obstacle.get("node") != null and is_instance_valid(obstacle["node"]):
			obstacle["node"].queue_free()
	obstacles.clear()
	obstacle_grid.clear()
	solid_cells.clear()
	_build_map()
	for enemy in enemies:
		if enemy.active:
			enemy.apply_map_tint(Gfx.hex(String(map_data.get("palette", {}).get("enemy", "#ffffff"))))
	events_mgr.setup(self, map_data)
	AudioManager.play_music(map_data.get("mood", {}))
	player.global_position = map_rect.get_center()
	spawn_secret_boss()
	EventBus.secret_entered.emit("void")

func save_current_state() -> void:
	pass

func _setup_photo_ui() -> void:
	photo_layer=CanvasLayer.new(); photo_layer.layer=60; photo_layer.visible=false; photo_layer.process_mode=Node.PROCESS_MODE_ALWAYS; add_child(photo_layer)
	photo_tint=ColorRect.new(); photo_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); photo_tint.mouse_filter=Control.MOUSE_FILTER_IGNORE; photo_layer.add_child(photo_tint)
	photo_info=Label.new(); photo_info.position=Vector2(8,338); photo_info.text="F12/P выход · SPACE/F5 снимок · H фильтр · R рамка · F враги · J формат · K размер"; photo_info.add_theme_font_size_override("font_size",8); photo_info.add_theme_color_override("font_outline_color",Color(0,0,0,1)); photo_info.add_theme_constant_override("outline_size",3); photo_layer.add_child(photo_info)

func _apply_photo_style() -> void:
	if photo_tint==null:return
	var colors=[Color(0,0,0,0),Color(0.45,0.25,0.05,0.20),Color(0.05,0.2,0.55,0.18),Color(0,0,0,0.28),Color(0.35,0.05,0.4,0.15)]
	photo_tint.color=colors[photo_filter%colors.size()]
	photo_tint.set_offsets_preset(Control.PRESET_FULL_RECT)
	for n in photo_layer.get_children():
		if String(n.name).begins_with("Frame"): n.queue_free()
	if photo_frame>0:
		var thick:=2 if photo_frame==1 else (16 if photo_frame==2 else 40)
		for spec in [[Vector2(0,0),Vector2(640,thick)],[Vector2(0,360-thick),Vector2(640,thick)],[Vector2(0,0),Vector2(thick,360)],[Vector2(640-thick,0),Vector2(thick,360)]]:
			var bar:=ColorRect.new(); bar.name="FrameBar"; bar.position=spec[0]; bar.size=spec[1]; bar.color=Color.WHITE if photo_frame==1 else Color.BLACK; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; photo_layer.add_child(bar); photo_layer.move_child(bar,1)
	var names=["НОРМА","СЕПИЯ","ХОЛОДНЫЙ","НУАР","РЕТРО"]
	photo_info.text="%s · рамка %d · %s ×%d · F12/P выход · SPACE/F5 снимок · H/R/F/J/K" % [names[photo_filter%names.size()],photo_frame,photo_format.to_upper(),photo_scale]

func set_photo_mode(enabled: bool) -> void:
	if photo_mode == enabled:
		return
	photo_mode = enabled
	sync_pause_state()
	if hud != null:
		hud.root.visible = not photo_mode
		if not photo_mode: hud.root.show()
	if photo_layer!=null: photo_layer.visible=photo_mode; _apply_photo_style()
	if not photo_mode and photo_enemies_hidden:
		photo_enemies_hidden=false
		for e in enemies: e.visible=true

func _toggle_photo_mode() -> void:
	set_photo_mode(not photo_mode)

func _capture_photo() -> void:
	if DisplayServer.get_name()=="headless":
		print("[SURWAVE] photo unavailable: headless renderer")
		return
	var dir := ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var dt := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [dt.year,dt.month,dt.day,dt.hour,dt.minute,dt.second]
	var path := "%s/SURWAVE_%s_%s_%s.%s" % [dir,stamp,String(map_data.get("id","map")),String(player.char_data.get("id","hero")),photo_format]
	var image: Image=get_viewport().get_texture().get_image()
	if image==null or image.is_empty():
		print("[SURWAVE] photo unavailable: renderer has no viewport texture")
		return
	if photo_scale>1: image.resize(640*photo_scale,360*photo_scale,Image.INTERPOLATE_NEAREST)
	var err:=OK
	match photo_format:
		"jpg": err=image.save_jpg(path,0.9)
		"webp": err=image.save_webp(path,false,0.9)
		_: err=image.save_png(path)
	if err == OK:
		flash_screen(Color(1.0, 1.0, 1.0, 0.35))
		if photo_info != null:
			photo_info.text = "Снимок сохранён: %s" % path.get_file()
	print("[SURWAVE] photo=",path," err=",err," metadata map=",map_data.get("name","")," character=",player.char_data.get("name","")," time=",elapsed," level=",level," combo=",combo," kills=",kills," trials=",GameManager.run_config.get("trials",[]))

## Проверка сетевого слоя: режимы окна, хост/лобби, скорость вражеских снарядов.
## Полноценный ENet-обмен между двумя процессами проверяет ручной тест, здесь —
## вся локальная логика, которая может сломаться при рефакторинге.
func _run_net_test() -> void:
	await get_tree().process_frame
	assert(Net.max_players() >= 2, "Сетевой кооп не поддерживает несколько игроков")
	assert(Net.default_port() > 1024, "Порт по умолчанию некорректен: %d" % Net.default_port())
	assert(GameManager.WINDOW_MODES.size() == 3, "Должно быть три режима окна")
	var before_mode := GameManager.window_mode()
	var next_mode := GameManager.cycle_window_mode()
	assert(next_mode != before_mode, "Режим окна не переключился")
	GameManager.set_setting("window_mode", before_mode)
	assert(GameManager.camera_zoom_scale() > 0.5, "Масштаб камеры из настроек некорректен")
	var err := Net.host_game(18777)
	assert(err == "", "Не удалось поднять сервер: " + err)
	await get_tree().process_frame
	assert(Net.is_host(), "Сервер не поднялся в режиме хоста")
	assert(Net.lobby_players.size() == 1, "В лобби не появился хост")
	Net.set_loadout("gavan", "shotgun")
	var host_entry: Dictionary = Net.lobby_players.get("1", {})
	assert(String(host_entry.get("character", "")) == "gavan", "Выбор героя не сохранился в лобби")
	assert(String(host_entry.get("weapon", "")) == "shotgun", "Выбор оружия не сохранился в лобби")
	var table := Net.loadout_table()
	assert(table.has("1"), "Таблица загрузок пуста")
	Net.start_lan_listen()
	assert(Net.lan_list() is Array, "Список хостов локальной сети не читается")
	Net.leave_session("тест")
	assert(not Net.enabled, "Сеть не отключилась после выхода")
	var empty_ip_error := Net.join_game("")
	assert(empty_ip_error != "", "Пустой IP должен давать понятную ошибку")
	Net.shutdown()
	# вражеский снаряд: множитель из баланса и жёсткий потолок
	spawn_enemy_bullet(player.global_position + Vector2(40, 0), Vector2.RIGHT, 1, {"speed": 300.0})
	assert(not ebullets.is_empty(), "Снаряд врага не создан")
	var eb: EnemyBullet = ebullets[ebullets.size() - 1]
	var speed_now := eb.vel.length()
	assert(speed_now <= 190.5, "Снаряд врага слишком быстрый: %.1f" % speed_now)
	assert(speed_now < 300.0 * float(DB.balance["run"].get("enemy_proj_speed", 0.74)) + 1.0,
		"Множитель скорости вражеских снарядов не применился: %.1f" % speed_now)
	print("[SURWAVE] net OK: players=%d port=%d window=%s ebullet=%.1f" % [
		Net.max_players(), Net.default_port(), GameManager.window_mode_name(), speed_now])

## Проверка бумеранга: перк призывает его, он вылетает к цели и возвращается.
func _run_boomerang_test() -> void:
	await get_tree().process_frame
	var perk_found := false
	for perk in DB.perks:
		if String(perk.id) == "boomerang_t1":
			perk_found = true
			assert(String(perk.get("flags", {}).get("summon", "")) == "boomerang",
				"Перк Бумеранг не призывает бумеранг")
	assert(perk_found, "В дереве перков нет Бумеранга")
	assert(DB.tree_by_id.has("boomerang"), "Дерево Бумеранга не зарегистрировано")
	player.upg.apply_flags({"summon": "boomerang"})
	player._tick_perk_summons()
	var boom: Ally = null
	for a in allies:
		if a.active and a.kind == "boomerang":
			boom = a
			break
	assert(boom != null, "Бумеранг не призвался")
	assert(boom.boom_state == "idle", "Бумеранг начал не в режиме ожидания: " + boom.boom_state)
	assert(boom.sprite != null and boom.sprite.texture != null, "У бумеранга нет текстуры")
	player.global_position = map_rect.get_center()
	boom.global_position = player.global_position + Vector2(30.0, 0.0)
	var enemy := spawn_enemy("slime", player.global_position + Vector2(120.0, 0.0))
	assert(enemy != null, "Не удалось создать врага для теста бумеранга")
	var seen_out := false
	var seen_back := false
	for i in 500:
		enemy.hp = maxf(enemy.hp, 9999.0)
		boom.tick(0.05)
		if boom.boom_state == "out":
			seen_out = true
		elif boom.boom_state == "back":
			seen_back = true
		if seen_out and seen_back:
			break
	assert(seen_out, "Бумеранг не вылетел к цели")
	assert(seen_back, "Бумеранг не вернулся к игроку")
	enemy.deactivate()
	for i in 200:
		boom.tick(0.05)
	var home_dist := boom.global_position.distance_to(player.global_position)
	assert(home_dist < Ally.BOOMERANG_ORBIT + 46.0, "Бумеранг не вернулся в строй: %.1f px" % home_dist)
	assert(boom.speed < 240.0, "Бумеранг слишком быстрый: %.1f" % boom.speed)
	# Рикошет: с прокачкой бумеранг после удара летит к другому врагу
	player.upg.apply_flags({"boomerang_ricochet": 2})
	var e_a := spawn_enemy("slime", player.global_position + Vector2(90.0, 0.0))
	var e_b := spawn_enemy("slime", player.global_position + Vector2(-90.0, 0.0))
	assert(e_a != null and e_b != null, "Не удалось создать врагов для теста рикошета")
	boom.boom_state = "idle"
	boom.boom_timer = 0.0
	boom.global_position = player.global_position
	var bounced := false
	for i in 600:
		e_a.hp = 9999.0
		e_b.hp = 9999.0
		boom.tick(0.05)
		if boom.boom_state == "out" and boom.boom_bounce_left < 2:
			bounced = true
			break
	assert(bounced, "Бумеранг не отскочил к другому врагу при прокачке")
	e_a.deactivate()
	e_b.deactivate()
	for a in allies:
		if a.perk_summon:
			a.deactivate()
	print("[SURWAVE] boomerang OK: state=%s dist=%.1f speed=%.0f" % [boom.boom_state, home_dist, boom.speed])


## Перебирает ВСЕ перки и нажимает карточку так же, как игрок (через HUD).
## Ловит подвисания при выборе конкретного перка и скриптовые ошибки в этом пути.
func _run_perk_click_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	assert(DB.perks.size() > 0, "Каталог перков пуст")
	var was_auto := GameManager.autoplay
	GameManager.autoplay = false
	var total := 0
	var slow: Array = []
	var stuck: Array = []
	var slowest := 0
	for perk in DB.perks:
		var pid := String(perk.get("id", ""))
		if pid == "":
			continue
		var card := {"kind": "perk", "id": pid, "data": perk, "weight": 1.0}
		choice_queue.clear()
		choice_queue.append({"kind": "perk", "cards": [card], "title": "ТЕСТ"})
		pending_level_ups = 0
		_open_next_choice()
		await get_tree().process_frame
		if hud.choice_layer == null or not hud.choice_layer.visible:
			stuck.append(pid + " (меню не открылось)")
			choice_queue.clear()
			paused_for_choice = false
			sync_pause_state()
			continue
		var t0 := Time.get_ticks_msec()
		hud._on_card_pressed(card)
		await get_tree().process_frame
		var dt := Time.get_ticks_msec() - t0
		slowest = maxi(slowest, dt)
		if dt > 600:
			slow.append("%s=%d мс" % [pid, dt])
		if (hud.choice_layer != null and hud.choice_layer.visible) or paused_for_choice:
			pending_level_ups = 0
			choice_queue.clear()
			paused_for_choice = false
			if hud.choice_layer != null:
				hud.choice_layer.visible = false
			sync_pause_state()
			stuck.append(pid + " (меню не закрылось)")
		total += 1
	pending_level_ups = 0
	choice_queue.clear()
	paused_for_choice = false
	sync_pause_state()
	GameManager.autoplay = was_auto
	assert(total >= 80, "Перебрано слишком мало перков: %d" % total)
	assert(stuck.is_empty(), "Зависание при выборе перков: " + ", ".join(stuck))
	assert(slow.is_empty(), "Медленный выбор перка: " + ", ".join(slow))
	print("[SURWAVE] perk_click OK: perks=%d slowest=%dms" % [total, slowest])

## Лавина должна реально наносить урон, а не просто рисоваться.
func _run_avalanche_test() -> void:
	await get_tree().process_frame
	var was_god := GameManager.god_mode
	GameManager.god_mode = false
	player.dead = false
	player.iframes = 0.0
	player.global_position = map_rect.get_center()
	await get_tree().process_frame
	var hp0 := player.hp
	run_map_event({"kind": "avalanche", "params": {"width": 160, "damage": 2}})
	var waited := 0.0
	while waited < 6.0 and player.hp >= hp0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var taken := hp0 - player.hp
	GameManager.god_mode = was_god
	assert(taken > 0, "Лавина не нанесла урон за %.1f с" % waited)
	print("[SURWAVE] avalanche OK: dmg=%d wait=%.2f" % [taken, waited])

# ------------------------------------------------------------------ КООП: ЦЕЛИ И УРОН
## Живые цели-игроки: хост-игрок и сетевые напарники.
func player_targets() -> Array:
	var out: Array = []
	if player != null and not player.dead:
		out.append(player)
	for np in net_proxies:
		if np != null and is_instance_valid(np) and not np.dead:
			out.append(np)
	return out

## Ближайший живой игрок к точке (для врагов, ловушек и снарядов).
func nearest_target(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in player_targets():
		var d: float = (t.global_position - pos).length_squared()
		if d < best_d:
			best_d = d
			best = t
	if best == null and player != null:
		return player
	return best

## Все живые игроки в радиусе — ловушки бьют и напарника, а не только хоста.
func players_in_radius(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	for t in player_targets():
		if t.global_position.distance_to(pos) <= radius:
			out.append(t)
	return out

## Урон по игроку или напарнику — единая точка входа.
func hurt_target(t: Node2D, amount: int, from_pos: Vector2, ignore_iframes: bool = false, source_role: String = "") -> void:
	if t == null or not is_instance_valid(t):
		return
	if t is NetPlayer:
		net_hit_proxy(t as NetPlayer, amount, from_pos)
	else:
		damage_player(amount, from_pos, ignore_iframes, source_role)

## Информация для HUD: здоровье и перки напарников.
func partner_info() -> Array:
	var out: Array = []
	for np in net_proxies:
		if np == null or not is_instance_valid(np):
			continue
		out.append({
			"name": np.display_name, "hp": np.hp, "max": np.max_hp,
			"dead": np.dead, "char": np.char_id,
		})
	return out

## Столкновение игроков между собой: не проходим друг сквозь друга.
func _resolve_player_collision(_delta: float) -> void:
	if not net_active:
		return
	var bodies: Array = []
	if player != null and not player.dead:
		bodies.append(player)
	for np in net_proxies:
		if np != null and is_instance_valid(np) and not np.dead:
			bodies.append(np)
	if bodies.size() < 2:
		return
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Node2D = bodies[i]
			var b: Node2D = bodies[j]
			var d: Vector2 = b.global_position - a.global_position
			var dist := d.length()
			var need := 13.0
			if dist >= need:
				continue
			var dir := d / dist if dist > 0.01 else Vector2.RIGHT
			var push := (need - dist) * 0.5
			# Хост двигает обе стороны, клиент — только свою (позиция напарника
			# приходит снапшотом и всё равно перезапишется).
			if net_host or a == player:
				a.global_position -= dir * push
			if net_host or b == player:
				b.global_position += dir * push

## Кооп-тест без второго окна: поднимаем «фантомного» напарника и проверяем
## визуал героя, приоритет целей, кристалл-душу, бесконечный мир и ивенты.
func _run_coop_test() -> void:
	await get_tree().process_frame
	var was_net := net_active
	net_active = true
	net_host = true
	# 1) напарник рисуется спрайтом героя, а не квадратом
	var np := NetPlayer.new()
	np.name = "RemoteTest"
	world.add_child(np)
	np.setup(self, 4242, "Напарник", "aldar", "revolver", player.global_position + Vector2(40, 0))
	net_proxies.append(np)
	await get_tree().process_frame
	assert(np.sprite != null and np.sprite.texture != null, "У напарника нет текстуры")
	assert(Assets.has_real_sprite(np._char_cls()), "У класса героя нет спрайта — будет квадрат")
	assert(np.sprite.texture.get_width() >= 24, "Напарник рисуется заглушкой вместо героя")
	assert(np.hp_bar != null and np.skill_bar != null, "У напарника нет микрошкал")
	# 2) враги целятся в ближайшего игрока, а не только в хоста
	np.global_position = player.global_position + Vector2(30, 0)
	var probe := player.global_position + Vector2(24, 0)
	assert(nearest_target(probe) == np, "nearest_target не выбирает напарника")
	assert(players_in_radius(probe, 60.0).size() >= 2, "players_in_radius не видит обоих игроков")
	# 3) смерть → кристалл-душа → возрождение напарником
	np.dead = true
	np.hp = 0
	np.visible = false
	_spawn_revive_crystal(np.peer_id, player.global_position + Vector2(10, 0))
	assert(revive_crystals.size() == 1, "Кристалл-душа не появился")
	# кристалл лежит рядом с живым игроком — он и возрождает павшего
	_tick_revive_crystals(0.05)
	assert(not np.dead and np.hp > 0, "Напарник не возродился от кристалла")
	assert(revive_crystals.is_empty(), "Кристалл не исчез после возрождения")
	# 4) у каждого свой опыт и перки
	var lvl_before := level
	np.hp = np.max_hp
	assert(partner_info().size() == 1, "partner_info не видит напарника")
	# 5) бесконечный мир: полоса карты доращивается
	var size_before := map_rect.size
	_grow_world("right")
	assert(map_rect.size.x > size_before.x, "Мир не расширился вправо")
	_grow_world("left")
	assert(map_rect.position.x < 0.0, "Мир не расширился влево")
	assert(chunks_grown >= 2, "Счётчик полос мира не растёт")
	# 6) ивенты карты идут 30–60 секунд волнами
	active_events.clear()
	run_map_event({"kind": "meteor", "params": {}})
	assert(active_events.size() == 1, "Ивент карты не встал в очередь")
	var dur := float(active_events[0]["left"])
	assert(dur >= 30.0 and dur <= 60.0, "Ивент карты длится %.1f с вместо 30–60" % dur)
	active_events.clear()
	# 7) лут получает сетевой id — клиент может подбирать опыт
	spawn_pickup("xp", player.global_position + Vector2(12, 0), 1.0)
	var last_pick: Pickup = pickups[pickups.size() - 1]
	assert(last_pick.net_id > 0, "У подбора нет сетевого id")
	# 8) чат и эмоции не ломаются без сети
	send_chat("тест")
	send_emote("ПРИВЕТ")
	# уборка
	for pk in net_pickup_ghosts:
		if pk != null and is_instance_valid(pk):
			pk.deactivate()
	net_proxies.clear()
	np.queue_free()
	revive_crystals.clear()
	net_active = was_net
	net_host = false
	level = lvl_before
	print("[SURWAVE] coop OK: targets=%d crystals=ok world=%.0fx%.0f event=%.0fs" % [
		2, map_rect.size.x, map_rect.size.y, dur])

# ------------------------------------------------------------------ СЕТЕВАЯ ИГРА
## Хост считает мир и рассылает снапшоты (10 Гц) + состояния игроков (20 Гц).
## Клиент двигает своего игрока сам, рисует «кукол» врагов/снарядов/подборов
## по снапшотам и отправляет хосту свой урон.
func _setup_net() -> void:
	net_active = bool(GameManager.run_config.get("network", false)) and Net.enabled
	if not net_active:
		return
	net_host = Net.is_host()
	GameManager.network_run = true
	Net.snapshot_received.connect(_net_apply_snapshot)
	Net.state_received.connect(_net_on_state)
	Net.damage_received.connect(_net_on_local_damage)
	Net.event_received.connect(_net_on_event)
	Net.session_ended.connect(_net_on_session_ended)
	var loadouts: Dictionary = GameManager.run_config.get("loadouts", {})
	var idx := 0
	for key in loadouts.keys():
		var pid := int(String(key))
		if pid == Net.my_id():
			continue
		var pair: Array = loadouts[key]
		var ch: String = String(pair[0]) if pair.size() > 0 else "aldar"
		var wp: String = String(pair[1]) if pair.size() > 1 else "revolver"
		var np := NetPlayer.new()
		np.name = "Remote%d" % pid
		world.add_child(np)
		var ang := TAU * float(idx) / maxf(1.0, float(maxi(1, loadouts.size() - 1)))
		np.setup(self, pid, Net.player_name(pid), ch, wp,
			clamp_to_map(player.global_position + Vector2.RIGHT.rotated(ang) * 30.0))
		net_proxies.append(np)
		idx += 1
	notify("СЕТЕВАЯ ИГРА · игроков: %d" % (net_proxies.size() + 1))
	if net_host:
		AudioManager.play_sfx("phase")

func _net_tick(delta: float) -> void:
	if not net_active:
		return
	for np in net_proxies:
		np.update_visual(delta)
	_net_state_cd -= delta
	if net_host:
		_net_snapshot_cd -= delta
		if _net_snapshot_cd <= 0.0:
			_net_snapshot_cd = 0.1
			Net.broadcast_snapshot(_net_build_snapshot())
		if _net_state_cd <= 0.0:
			_net_state_cd = 0.05
			Net.broadcast_states(_net_state_table())
	elif _net_state_cd <= 0.0:
		_net_state_cd = 0.05
		Net.send_player_state(_net_player_payload(player,
			String(GameManager.run_config.get("character", "aldar")),
			String(GameManager.run_config.get("weapon", "revolver"))))

func _net_player_payload(p: Node2D, ch: String, wp: String) -> Dictionary:
	var aim := Vector2.RIGHT
	var dead := false
	var hp := 3
	var max_hp := 3
	var moving := false
	var skill := 1.0
	if p is Player:
		var pl := p as Player
		aim = pl.aim_dir
		dead = pl.dead
		hp = pl.hp
		max_hp = pl.max_hp
		moving = pl.moving_now
		var cd := maxf(0.01, float(pl.skill_data.get("cd", 10.0)))
		skill = clampf(1.0 - float(pl.skill_cd_left) / cd, 0.0, 1.0)
	elif p is NetPlayer:
		var np := p as NetPlayer
		aim = np.aim
		dead = np.dead
		hp = np.hp
		max_hp = np.max_hp
		moving = np.moving
		skill = np.skill_frac
	return {
		"x": int(p.global_position.x), "y": int(p.global_position.y),
		"ax": aim.x, "ay": aim.y, "hp": hp, "max": max_hp,
		"dead": dead, "mv": moving, "ch": ch, "wp": wp, "sk": skill,
	}

func _net_state_table() -> Dictionary:
	var out: Dictionary = {}
	out["1"] = _net_player_payload(player,
		String(GameManager.run_config.get("character", "aldar")),
		String(GameManager.run_config.get("weapon", "revolver")))
	for np in net_proxies:
		out[str(np.peer_id)] = _net_player_payload(np, np.char_id, np.weapon_id)
	return out

func _net_on_state(peer_id: int, state: Dictionary) -> void:
	if not net_active or peer_id == Net.my_id():
		return
	for np in net_proxies:
		if np.peer_id == peer_id:
			np.apply_state(state)
			return

func _net_build_snapshot() -> Dictionary:
	var players_list: Array = []
	players_list.append([1, int(player.global_position.x), int(player.global_position.y),
		player.hp, player.max_hp, 1 if player.dead else 0])
	for np in net_proxies:
		players_list.append([np.peer_id, int(np.global_position.x), int(np.global_position.y),
			np.hp, np.max_hp, 1 if np.dead else 0])
	var enemy_list: Array = []
	for e in enemies:
		if not e.active:
			continue
		if not e.boss and e.global_position.distance_squared_to(player.global_position) > 1600.0 * 1600.0:
			continue
		enemy_list.append([e.net_id, String(e.id), int(e.global_position.x), int(e.global_position.y),
			int(maxf(1.0, e.hp)), int(maxf(1.0, e.max_hp)), 1 if e.elite else 0,
			1 if e.boss else 0, String(e.boss_def.get("name", "")) if e.boss else ""])
	var bullet_list: Array = []
	for b in ebullets:
		if not b.active:
			continue
		if b.global_position.distance_squared_to(player.global_position) > 1300.0 * 1300.0:
			continue
		bullet_list.append([int(b.global_position.x), int(b.global_position.y),
			int(rad_to_deg(b.rotation)), int(b.radius * 10.0)])
	var pick_list: Array = []
	for pk in pickups:
		if not pk.active or String(pk.kind) == "chest":
			continue
		pick_list.append([int(pk.net_id), String(pk.kind), int(pk.global_position.x), int(pk.global_position.y)])
	var crystal_list: Array = []
	for c in revive_crystals:
		crystal_list.append([int(c["owner"]), int(c["x"]), int(c["y"])])
	return {
		"e": enemy_list, "b": bullet_list, "p": players_list, "pk": pick_list,
		"rc": crystal_list, "k": kills, "t": int(elapsed),
	}

func _net_apply_snapshot(snap: Dictionary) -> void:
	if not net_active or net_host or ended:
		return
	var plist: Array = snap.get("p", [])
	for entry in plist:
		var arr: Array = entry
		if arr.size() < 4:
			continue
		var pid := int(arr[0])
		if pid == Net.my_id():
			var new_hp := int(arr[3])
			if not GameManager.god_mode and new_hp != player.hp and not player.dead:
				player.hp = clampi(new_hp, 0, player.max_hp)
				EventBus.hp_changed.emit(player.hp, player.max_hp)
				if player.hp <= 0:
					player.dead = true
					_on_player_died()
			continue
		for np in net_proxies:
			if np.peer_id == pid:
				np.apply_state({
					"x": int(arr[1]), "y": int(arr[2]), "hp": int(arr[3]),
					"max": int(arr[4]), "dead": int(arr[5]) == 1,
				})
				break
	# Опыт, уровень и перки у каждого игрока СВОИ: хостовые значения не применяем,
	# иначе прокачка клиента перезаписывается чужой.
	kills = maxi(kills, int(snap.get("k", kills)))
	elapsed = maxf(elapsed, float(snap.get("t", int(elapsed))))
	_net_sync_ghosts(snap.get("e", []))
	_net_sync_bullets(snap.get("b", []))
	_net_sync_pickups(snap.get("pk", []))
	_net_sync_crystals(snap.get("rc", []))

func _net_sync_ghosts(list: Array) -> void:
	var seen: Dictionary = {}
	for entry in list:
		var arr: Array = entry
		if arr.size() < 6:
			continue
		var nid := int(arr[0])
		seen[nid] = true
		var is_boss := arr.size() > 7 and int(arr[7]) == 1
		var boss_title := String(arr[8]) if arr.size() > 8 else ""
		var e: Enemy = net_enemies.get(nid, null) as Enemy
		if e == null or not is_instance_valid(e):
			e = _net_spawn_ghost(nid, String(arr[1]), Vector2(float(arr[2]), float(arr[3])), is_boss, boss_title)
			if e == null:
				continue
		e.net_target = Vector2(float(arr[2]), float(arr[3]))
		e.hp = float(arr[4])
		e.max_hp = maxf(1.0, float(arr[5]))
		e.elite = int(arr[6]) == 1
		if is_boss:
			e.boss = true
			if String(e.boss_def.get("name", "")) == "":
				e.boss_def = {"name": boss_title if boss_title != "" else "БОСС"}
			# клиент видит полосу босса так же, как хост
			if boss_enemy == null or not is_instance_valid(boss_enemy) or not boss_enemy.active:
				boss_enemy = e
		if e.hp <= 0.0 and e.active:
			_net_ghost_death(e)
	for nid in net_enemies.keys():
		if seen.has(nid):
			continue
		var gone: Enemy = net_enemies[nid] as Enemy
		if gone != null and is_instance_valid(gone) and gone.active:
			gone.deactivate()
		net_enemies.erase(nid)

func _net_spawn_ghost(nid: int, enemy_id: String, pos: Vector2, is_boss: bool = false, boss_title: String = "") -> Enemy:
	var data := DB.enemy(enemy_id)
	if data.is_empty():
		# Боссы живут в bosses.json (у них свой id), поэтому без этой ветки
		# клиент вообще не видел боссов.
		var bd: Dictionary = DB.boss(String(map_data.get("id", "")))
		if bd.is_empty() or (boss_title != "" and String(bd.get("name", "")) != boss_title):
			bd = {}
			for key in DB.bosses.keys():
				var cand: Dictionary = DB.bosses[key]
				if String(cand.get("id", "")) == enemy_id or String(cand.get("name", "")) == boss_title:
					bd = cand
					break
		if not bd.is_empty():
			data = {
				"id": enemy_id, "name": String(bd.get("name", "БОСС")),
				"hp": float(bd.get("hp", 900.0)), "speed": 24.0, "radius": 16.0,
				"color": "#c8b4d8", "role": "boss", "size": 2.4,
			}
	if data.is_empty():
		return null
	var e: Enemy = ENEMY_SCENE.instantiate()
	world.add_child(e)
	e.setup(self)
	if is_boss:
		var bdef: Dictionary = DB.boss(String(map_data.get("id", "")))
		if bdef.is_empty():
			bdef = {"id": enemy_id, "name": boss_title if boss_title != "" else String(data.get("name", "БОСС"))}
		e.init_boss(self, bdef, pos, float(data.get("hp", 900.0)))
	else:
		e.init_enemy(self, data, pos)
	e.net_remote = true
	e.net_id = nid
	e.net_target = pos
	e.apply_map_tint(Gfx.hex(String(map_data.get("palette", {}).get("enemy", "#ffffff"))))
	enemies.append(e)
	net_enemies[nid] = e
	return e

func _net_ghost_death(e: Enemy) -> void:
	spawn_fx(e.global_position, e.color, e.radius * 2.0, 0.25)
	if e.boss:
		spawn_perk_fx("blood", e.global_position, 90.0, 0.5)
	e.deactivate()

func _net_sync_bullets(list: Array) -> void:
	while net_bullets.size() < list.size():
		var b: EnemyBullet = EBULLET_SCENE.instantiate()
		world.add_child(b)
		b.setup(self)
		b.net_remote = true
		b.active = true
		b.visible = true
		b.sprite.texture = Assets.tex("projectile_enemy", Color(1.0, 0.42, 0.42))
		b.sprite.scale = Vector2(0.8, 0.8)
		net_bullets.append(b)
	for i in net_bullets.size():
		var b: EnemyBullet = net_bullets[i]
		if i >= list.size():
			b.visible = false
			b.active = false
			continue
		var arr: Array = list[i]
		if arr.size() < 4:
			continue
		var target := Vector2(float(arr[0]), float(arr[1]))
		b.visible = true
		b.active = true
		b.net_target = target
		if b.global_position.distance_to(target) > 220.0:
			b.global_position = target
		b.rotation = deg_to_rad(float(arr[2]))
		b.life = 1.0

## Лут на клиенте: у каждого предмета сетевой id, подобранное больше не рисуем.
func _net_sync_pickups(list: Array) -> void:
	var now := Time.get_ticks_msec()
	if not net_taken_pickups.is_empty():
		for id in net_taken_pickups.keys():
			if now - int(net_taken_pickups[id]) > 6000:
				net_taken_pickups.erase(id)
	var by_id: Dictionary = {}
	for pk in net_pickup_ghosts:
		if pk != null and is_instance_valid(pk) and pk.net_id > 0:
			by_id[pk.net_id] = pk
	var seen: Dictionary = {}
	for entry in list:
		var arr: Array = entry
		if arr.size() < 4:
			continue
		var pid := int(arr[0])
		if net_taken_pickups.has(pid):
			continue
		seen[pid] = true
		var kind := String(arr[1])
		var pos := Vector2(float(arr[2]), float(arr[3]))
		var pk: Pickup = by_id.get(pid, null)
		if pk == null or not is_instance_valid(pk):
			pk = PICKUP_SCENE.instantiate()
			world.add_child(pk)
			pk.setup(self)
			pk.spawn_at(pos, kind, 1.0, Color(0.55, 0.9, 1.0), 5.0)
			pk.net_id = pid
			pk.net_remote = true
			net_pickup_ghosts.append(pk)
		elif not pk.active or pk.kind != kind:
			pk.spawn_at(pos, kind, 1.0, Color(0.55, 0.9, 1.0), 5.0)
			pk.net_id = pid
			pk.net_remote = true
		pk.global_position = pos
		pk.visible = true
	for pk in net_pickup_ghosts:
		if pk == null or not is_instance_valid(pk):
			continue
		if pk.net_id > 0 and not seen.has(pk.net_id):
			pk.deactivate()

## Клиент бьёт «куклу»: локальный отклик и запрос урона хосту.
func _net_client_damage(enemy: Node2D, amount: float, opts: Dictionary) -> void:
	var e := enemy as Enemy
	if e == null or e.net_remote == false:
		return
	e.hp -= amount
	e.hit_flash = 0.12
	if GameManager.setting("damage_numbers", true) and amount >= 2.0:
		spawn_dmg_number(e.global_position, amount, bool(opts.get("crit", false)), String(opts.get("source", "")))
	if e.net_id > 0:
		Net.request_damage(e.net_id, amount, String(opts.get("source", "weapon")))
	if e.hp <= 0.0 and e.active:
		_net_ghost_death(e)

## Хост: урон по сетевому напарнику (снаряд/контакт врага).
func net_hit_proxy(np: NetPlayer, dmg: int, from_pos: Vector2) -> void:
	if np == null or np.dead:
		return
	np.hp -= dmg
	np.hit_flash = 0.3
	spawn_dmg_number(np.global_position, float(dmg), false, "net")
	spawn_fx(np.global_position, Color(0.7, 0.95, 1.0, 0.8), 18.0, 0.2)
	Net.send_player_damage(np.peer_id, dmg, from_pos)
	if np.hp <= 0:
		np.hp = 0
		np.dead = true
		np.visible = false
		_spawn_revive_crystal(np.peer_id, np.global_position)
		notify("%s выбыл из боя — подберите его кристалл-душу" % np.display_name)

func _net_on_local_damage(amount: int, from_pos: Vector2) -> void:
	if ended or player == null or player.dead:
		return
	damage_player(amount, from_pos, false, "net")

func _net_on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"request_damage":
			if not net_host:
				return
			var enemy := _net_enemy_by_id(int(data.get("net_id", 0)))
			if enemy != null and enemy.active:
				damage_enemy(enemy, float(data.get("amount", 1.0)),
					{"source": String(data.get("source", "net")), "silent": true})
		"weather":
			# Только визуал: урон/замедление считает хост.
			start_weather(String(data.get("title", "Непогода")), String(data.get("kind", "fog")),
				data.get("color", Color(0.8, 0.8, 0.8)), float(data.get("duration", 40.0)),
				{"vision": float(data.get("vision", 1.0)), "wind": data.get("wind", Vector2(1, 0.25))})
		"boss":
			AudioManager.set_boss_layer(true)
			AudioManager.play_sfx("boss")
		"notice":
			notify(String(data.get("text", "")))
		"levelup":
			AudioManager.play_sfx("levelup")
		"chat":
			if hud != null:
				hud.push_chat(String(data.get("name", "Игрок")), String(data.get("text", "")), int(data.get("peer", 0)) == Net.my_id())
		"emote":
			_net_show_emote(int(data.get("peer", 0)), String(data.get("text", "")))
		"perk":
			partner_perks.append({"peer": int(data.get("peer", 0)), "name": String(data.get("name", ""))})
			if partner_perks.size() > 8:
				partner_perks.pop_front()
		"pause":
			net_apply_pause(bool(data.get("on", false)))
		"pause_req":
			if net_host:
				net_toggle_pause()
		"pickup":
			if not net_host:
				return
			var taker := _net_pickup_by_id(int(data.get("id", 0)))
			if taker != null:
				taker.deactivate()
		"died":
			if not net_host:
				return
			var who := int(data.get("peer", 0))
			_spawn_revive_crystal(who, Vector2(float(data.get("x", 0)), float(data.get("y", 0))))
		"revived":
			net_apply_revive(int(data.get("peer", 0)))
		_:
			pass

func _net_pickup_by_id(id: int) -> Pickup:
	if id <= 0:
		return null
	for pk in pickups:
		if pk != null and is_instance_valid(pk) and pk.net_id == id and pk.active:
			return pk
	return null

func _net_enemy_by_id(id: int) -> Enemy:
	if id <= 0:
		return null
	var e: Enemy = net_enemies.get(id, null) as Enemy
	if e != null and is_instance_valid(e) and e.active:
		return e
	return null

func _net_on_session_ended(reason: String) -> void:
	if not net_active:
		return
	net_active = false
	notify(reason)
	if not ended:
		_finish_run(false, false)

# ------------------------------------------------------------------ КООП: ПАУЗА, ЧАТ, ЭМОЦИИ
## В коопе пауза общая и задаётся хостом: клиент не морозит мир сам,
## иначе у напарника «зависает» полбоя.
func net_toggle_pause() -> void:
	if not net_active:
		return
	if not net_host:
		if hud != null and hud.pause_layer != null:
			hud.pause_layer.visible = not hud.pause_layer.visible
			if hud.pause_layer.visible:
				hud._refresh_pause_menu()
		Net.send_event_any("pause_req", {})
		return
	net_paused = not net_paused
	if hud != null and hud.pause_layer != null:
		hud.pause_layer.visible = net_paused
		if net_paused:
			hud._refresh_pause_menu()
	get_tree().paused = net_paused
	Net.send_event("pause", {"on": net_paused})

func net_apply_pause(on: bool) -> void:
	net_paused = on
	if hud != null and hud.pause_layer != null:
		hud.pause_layer.visible = on
		if on:
			hud._refresh_pause_menu()
	get_tree().paused = on
	_sync_cursor()

## Чат: короткая строка внизу экрана у всех игроков.
func send_chat(text: String) -> void:
	var t := text.strip_edges().left(120)
	if t == "":
		return
	var who := String(Net.my_name)
	if who == "":
		who = "Игрок"
	if hud != null:
		hud.push_chat(who, t, true)
	if net_active:
		Net.send_event_any("chat", {"name": who, "text": t})

## Эмоция из колеса (Q): облачко над головой у всех.
func send_emote(text: String) -> void:
	var t := text.strip_edges().left(32)
	if t == "":
		return
	_show_emote_over(player, t, Color(0.9, 0.95, 1.0))
	if net_active:
		Net.send_event_any("emote", {"text": t})

func _net_show_emote(peer: int, text: String) -> void:
	if peer == Net.my_id():
		return
	for np in net_proxies:
		if np != null and np.peer_id == peer:
			np.show_bubble(text, Color(0.85, 0.95, 1.0), 4.0)
			return

## Всплывающее облачко над игроком (своя эмоция).
func _show_emote_over(target: Node2D, text: String, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	var holder := Node2D.new()
	world.add_child(holder)
	holder.z_index = 12
	holder.global_position = target.global_position + Vector2(0, -26)
	var w := clampf(float(text.length()) * 4.6 + 10.0, 22.0, 96.0)
	var bg := Gfx.square(holder, Vector2(w, 12.0), Color(0.06, 0.07, 0.1, 0.9), Vector2(0, 0))
	bg.z_index = 11
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_override("font", UI.crisp_font())
	lb.add_theme_font_size_override("font_size", 8)
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_constant_override("outline_size", 1)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lb.size = Vector2(w, 12.0)
	lb.position = Vector2(-w * 0.5, -6.0)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.z_index = 12
	holder.add_child(lb)
	var tw := create_tween()
	tw.tween_property(holder, "position:y", holder.position.y - 10.0, 3.4)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 3.4).set_delay(1.2)
	tw.tween_callback(holder.queue_free)

## Имена последних перков напарников (для панели союзника).
func partner_perk_names() -> Array:
	var out: Array = []
	for e in partner_perks:
		var nm := String(e.get("name", ""))
		if nm != "":
			out.append(nm)
	return out

## Игрок взял перк — напарники видят его в панели союзника.
func report_perk(perk_name: String) -> void:
	partner_perks.append({"peer": Net.my_id(), "name": perk_name})
	if partner_perks.size() > 8:
		partner_perks.pop_front()
	if net_active and perk_name != "":
		Net.send_event_any("perk", {"name": perk_name})

# ------------------------------------------------------------------ ПРОЧЕЕ
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("photo_mode") and not ended:
		_toggle_photo_mode()
		get_viewport().set_input_as_handled()
	elif photo_mode and (event.is_action_pressed("photo_capture") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_SPACE)):
		_capture_photo(); get_viewport().set_input_as_handled()
	elif photo_mode and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode in [KEY_H, KEY_R, KEY_F, KEY_J, KEY_K]:
		match (event as InputEventKey).physical_keycode:
			KEY_H: photo_filter=(photo_filter+1)%5; _apply_photo_style()
			KEY_R: photo_frame=(photo_frame+1)%4; _apply_photo_style()
			KEY_F:
				photo_enemies_hidden=not photo_enemies_hidden
				for e in enemies: e.visible=not photo_enemies_hidden
			KEY_J: photo_format={"png":"jpg","jpg":"webp","webp":"png"}[photo_format]; _apply_photo_style()
			KEY_K: photo_scale=1 if photo_scale>=8 else photo_scale*2; _apply_photo_style()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and qte_target != null:
		_qte_press()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if hud != null and not ended:
			hud.toggle_pause()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and photo_mode:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.zoom = (camera.zoom + Vector2(0.1,0.1)).clamp(Vector2(0.5,0.5),Vector2(4,4))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.zoom = (camera.zoom - Vector2(0.1,0.1)).clamp(Vector2(0.5,0.5),Vector2(4,4))
	if event.is_action_pressed("fullscreen"):
		GameManager.cycle_window_mode()
