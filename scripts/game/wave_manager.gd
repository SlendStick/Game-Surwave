class_name WaveManager
extends RefCounted
## Волны, спавн и таймлайн событий (мини-боссы, боссы, кровавая фаза и т.д.).

var game: Node = null
var map_data: Dictionary = {}
var timeline: Array = []
var event_index := 0
var elapsed := 0.0
var duration := 1800.0
var mode := "standard"
var diff: Dictionary = {}
var spawn_timer := 1.0
var roster: Array = ["fodder"]
var spawn_scale := 0.6
var elite_enabled := false
var elite_timer := 45.0
var elite_interval := 45.0
var time_scale := 1.0
var blood_phase := false
var discrete_waves := false
var wave_number := 0
var wave_remaining := 0
var wave_break := 0.0

func setup(g: Node, md: Dictionary, mode_id: String, difficulty: Dictionary) -> void:
	game = g
	map_data = md
	mode = mode_id
	diff = difficulty
	timeline = DB.waves.get("timeline", [])
	var mode_cfg := DB.mode_config(mode_id)
	duration = float(mode_cfg.get("duration", 1800.0))
	if mode_id == "quick":
		time_scale = float(DB.waves.get("quick", {}).get("scale", 0.55))
	if mode_id == "endless":
		duration = 1.0e12
		time_scale = 1.0
	roster = ["fodder"]
	spawn_scale = 0.6
	elapsed = 0.0
	event_index = 0
	spawn_timer = maxf(0.5, float(DB.balance["run"].get("spawn_grace", 4.0)))
	elite_timer = elite_interval
	discrete_waves = (GameManager.run_config.get("trials",[]) as Array).has("wave")
	if discrete_waves: _start_next_wave()

func _start_next_wave() -> void:
	wave_number += 1
	wave_remaining = int(round(50.0 * pow(1.25,float(wave_number-1))))
	game.notify("ВОЛНА %d · %d врагов" % [wave_number,wave_remaining])

func tick(delta: float) -> void:
	elapsed += delta
	if discrete_waves:
		if wave_remaining>0:
			spawn_timer-=delta
			if spawn_timer<=0.0 and game.enemies.size()<game.max_enemies_now():
				spawn_timer=0.08
				for i in mini(5,wave_remaining): game.spawn_from_role("fodder"); wave_remaining-=1
		elif game.enemies.is_empty():
			wave_break+=delta
			if wave_break>=10.0: wave_break=0.0; _start_next_wave()
		return
	_fire_timeline()
	_spawn_loop(delta)
	_elite_loop(delta)

func _fire_timeline() -> void:
	var t := elapsed / time_scale
	while event_index < timeline.size():
		var ev: Dictionary = timeline[event_index]
		if float(ev.get("time", 0.0)) > t:
			break
		event_index += 1
		_handle_event(ev)

func _handle_event(ev: Dictionary) -> void:
	var event := String(ev.get("event", ""))
	var params: Dictionary = ev.get("params", {})
	match event:
		"phase":
			roster = params.get("roster", roster)
			spawn_scale = float(params.get("spawn_scale", spawn_scale))
		"elites_on":
			elite_enabled = true
			elite_interval = float(params.get("interval", 45.0)) * (1.0 - float(diff.get("elite_earlier", 0.0)))
			elite_timer = elite_interval
		"miniboss":
			game.spawn_miniboss(int(params.get("tier", 1)))
		"boss":
			game.spawn_map_boss(String(params.get("kind", "first")))
		"blood_phase":
			blood_phase = true
			game.blood_phase(float(params.get("hp", 0.5)), float(params.get("speed", 0.25)))
		"calm":
			spawn_scale *= 0.3
			game.notify("Затишье перед боссом...")
		"dawn_warning":
			game.notify(Loc.t("dawn"))
		"spawn_scale":
			spawn_scale = float(params.get("value", spawn_scale))

## Плавный разгон сложности: доля от полного темпа спавна.
## Раньше темп рос линейно, из-за чего уже к первой минуте на карте было около сотни врагов.
## Теперь используется сглаженная кривая со степенью spawn_ramp_ease и короткой паузой на старте.
func ramp_t() -> float:
	var run_cfg: Dictionary = DB.balance["run"]
	var span := maxf(1.0, float(run_cfg.get("spawn_ramp_seconds", 1800.0)))
	var t := clampf(elapsed / span, 0.0, 1.0)
	return pow(t, maxf(0.2, float(run_cfg.get("spawn_ramp_ease", 1.0))))

func spawn_interval() -> float:
	var run_cfg: Dictionary = DB.balance["run"]
	var t := ramp_t()
	var base: float = lerpf(float(run_cfg.get("spawn_interval_start", 3.2)), float(run_cfg.get("spawn_interval_end", 0.45)), t)
	var rate_scale := maxf(0.35, 1.0 - float(diff.get("fodder_spawn", 0.0)))
	var director := float(game.director_mods.get("spawn", 1.0)) if game != null else 1.0
	var pressure := float(run_cfg.get("start_enemy_pressure", 1.0))
	return maxf(0.08, (base * rate_scale) / ((pressure + spawn_scale) * director))

func spawn_batch() -> int:
	var run_cfg: Dictionary = DB.balance["run"]
	var t := ramp_t()
	var base: float = lerpf(float(run_cfg.get("spawn_batch_start", 1.0)), float(run_cfg.get("spawn_batch_end", 22.0)), t)
	return maxi(1, int(round(base * maxf(0.4, spawn_scale) * (1.0 + float(diff.get("fodder_spawn", 0.0)) * 0.5))))

func _spawn_loop(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = spawn_interval()
	if game.enemies.size() >= game.max_enemies_now():
		return
	var count := spawn_batch()
	for i in count:
		var role := String(roster[randi() % roster.size()])
		game.spawn_from_role(role)

func _elite_loop(delta: float) -> void:
	if not elite_enabled:
		return
	elite_timer -= delta
	if elite_timer <= 0.0:
		elite_timer = elite_interval
		game.spawn_from_role("elite")
