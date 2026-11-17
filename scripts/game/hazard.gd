class_name Hazard
extends Node2D
## Опасная зона: телеграф (предупреждение) -> активная фаза.
## Используется событиями карт, скиллами, взрывами боссов, пентаграммами.

var game: Node = null
var radius := 40.0
var damage := 10.0          # разовый урон при активации (если > 0)
var dps := 0.0              # периодический урон в секунду
var telegraph := 0.0        # время предупреждения
var duration := 1.0         # длительность активной фазы
var color := Color(1, 0.3, 0.2)
var hits_player := true
var hits_enemies := false
var active := false
var armed := false
var elapsed := 0.0
var tick_cd := 0.0
var vis: Node2D = null
var pattern: String = "generic"
var slow := 0.0
var burns := false
var pulse := false
var root := 0.0

func setup(g: Node) -> void:
	game = g
	if vis == null:
		vis = load("res://scripts/game/hazard_vis.gd").new()
		add_child(vis)

func _set_visual(alpha: float) -> void:
	if vis == null:
		return
	vis.set("radius", radius)
	vis.set("color", color)
	vis.set("alpha", alpha)
	vis.set("armed", armed)
	vis.set("telegraph", telegraph)
	vis.set("elapsed", elapsed)
	vis.set("pattern", pattern)
	vis.queue_redraw()

func init_hazard(g: Node, pos: Vector2, r: float, dmg: float, dot: float, tele: float, dur: float, col: Color, flags: Dictionary = {}) -> void:
	game = g
	radius = r
	damage = dmg
	dps = dot
	telegraph = tele
	duration = dur
	color = col
	hits_player = bool(flags.get("hits_player", true))
	hits_enemies = bool(flags.get("hits_enemies", true))
	slow = float(flags.get("slow", 0.0))
	burns = bool(flags.get("burn", false))
	pulse = bool(flags.get("pulse", false))
	root = float(flags.get("root", 0.0))
	pattern = String(flags.get("pattern", "generic"))
	global_position = pos
	elapsed = 0.0
	armed = telegraph <= 0.0
	active = true
	visible = true
	tick_cd = 0.0
	if vis == null:
		setup(g)
	_set_visual(0.24 if armed else 0.16)
	if armed and damage > 0.0:
		_apply_hit()
		damage = 0.0

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var total_life := telegraph + duration
	var fade := clampf((total_life - elapsed) / 0.5, 0.0, 1.0)
	if vis != null and visible:
		_set_visual(clampf(0.22 + (0.06 if armed else 0.0), 0.0, 0.38) * fade)
	if not armed:
		# телеграф
		if elapsed >= telegraph:
			armed = true
			_set_visual(0.26)
			if damage > 0.0:
				_apply_hit()
				damage = 0.0
		return
	# активная фаза
	if dps > 0.0 or slow > 0.0:
		tick_cd -= delta
		if tick_cd <= 0.0:
			tick_cd = 0.35
			if dps > 0.0:
				_apply_dot(0.35)
	if elapsed >= total_life:
		deactivate()

func _apply_hit() -> void:
	if hits_enemies:
		game.aoe_damage(global_position, radius, damage, {"source": "hazard"})
	if hits_player and game.player != null and not game.player.dead:
		if global_position.distance_to(game.player.global_position) < radius + 6.0:
			var ward := 0.5 if game.player.has_meta("ward") else 1.0
			game.damage_player(int(float(damage) * ward), global_position)
			if root > 0.0:
				game.player.add_status("stun", root)
			if burns:
				game.player.add_status("burn", 3.0, {"dps": 4.0})

func _apply_dot(step: float) -> void:
	if hits_enemies:
		game.aoe_damage(global_position, radius, dps * step, {"source": "hazard_dot"})
	if hits_player and game.player != null and not game.player.dead:
		if global_position.distance_to(game.player.global_position) < radius + 6.0:
			game.player._damage_over_time(dps * step)
			if slow > 0.0:
				game.player.add_status("slow", 0.4, {"amount": slow})
			if root > 0.0:
				game.player.add_status("stun", 0.4)
			if burns:
				game.player.add_status("burn", 2.0, {"dps": 3.0})
