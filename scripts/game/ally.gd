class_name Ally
extends Node2D
## Призывы и временные союзники: духи, скелеты, турели, клинки, торнадо, мотыльки,
## феникс, дракончик, святые копья, теневые клоны.

var game: Node = null
var kind := "spirit"
var damage := 5.0
var duration := 5.0
var remaining := 5.0
var radius := 8.0
var speed := 120.0
var attack_cd := 0.0
var interval := 0.6
var active := false
var sprite: Sprite2D = null
var orbit_angle := 0.0
var orbit_radius := 40.0
var color := Color(0.8, 0.9, 1.0)
var target: Node2D = null
var hit_cd: Dictionary = {}
var dragon_breath := false
var perk_summon := false

func setup(g: Node) -> void:
	game = g
	if sprite == null:
		sprite = Gfx.square(self, Vector2(radius * 2.0, radius * 2.0), color)

func init_ally(g: Node, k: String, opts: Dictionary) -> void:
	game = g
	kind = k
	damage = float(opts.get("damage", 5.0))
	duration = float(opts.get("duration", 5.0))
	remaining = duration
	radius = float(opts.get("radius", 8.0))
	speed = float(opts.get("speed", 130.0))
	interval = float(opts.get("interval", 0.6))
	attack_cd = 0.0
	active = true
	visible = true
	target = null
	hit_cd.clear()
	dragon_breath = bool(opts.get("dragon_breath", false))
	perk_summon = bool(opts.get("perk_summon", false))
	orbit_angle = float(opts.get("orbit_angle", randf() * TAU))
	orbit_radius = float(opts.get("radius", 40.0))
	global_position = opts.get("pos", game.player.global_position)
	match kind:
		"spirit": color = Color(0.75, 0.85, 1.0); radius = 7.0; speed = 260.0
		"skeleton": color = Color(0.85, 0.85, 0.75); radius = 9.0; speed = 95.0
		"turret": color = Color(0.9, 0.75, 0.4); radius = 10.0; speed = 0.0
		"blade", "orbit_blade": color = Color(0.7, 0.95, 1.0); radius = 9.0
		"tornado": color = Color(0.75, 0.9, 1.0); radius = float(opts.get("radius", 44.0)); speed = 55.0
		"phoenix": color = Color(1.0, 0.55, 0.2); radius = 12.0; speed = 150.0
		"moth": color = Color(0.7, 0.9, 1.0); radius = 8.0; speed = 170.0
		"scythe": color = Color(0.8, 0.7, 1.0); radius = 12.0; orbit_radius = 46.0
		"holy_spear": color = Color(1.0, 0.95, 0.6); radius = 10.0; speed = 280.0
		"thunder_beetle": color = Color(0.7, 0.8, 1.0); radius = 9.0; speed = 135.0
		"shadow_clone": color = Color(0.35, 0.3, 0.45); radius = 10.0; speed = 0.0
		"dragonling": color = Color(0.6, 0.9, 0.6); radius = 11.0; speed = 150.0
		"aura": color = Color(1.0, 0.9, 0.5); radius = float(opts.get("radius", 120.0)); speed = 0.0
	var cls:={"spirit":"ally_spirit","skeleton":"ally_skeleton","turret":"ally_turret","blade":"ally_blade","orbit_blade":"ally_blade","tornado":"ally_tornado","phoenix":"ally_phoenix","moth":"ally_moth","scythe":"ally_scythe","holy_spear":"ally_spear","thunder_beetle":"ally_beetle","shadow_clone":"ally_clone","dragonling":"ally_dragon","aura":"ally_aura"}.get(kind,"ally_spirit")
	if sprite == null:
		sprite=Sprite2D.new(); sprite.centered=true; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(sprite)
	var atex := Assets.tex(String(cls), color)
	sprite.texture = atex
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	var sc := maxf(0.65, (radius * 2.2) / float(maxi(1, atex.get_width())))
	sprite.scale = Vector2(sc, sc)

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	remaining -= delta
	if remaining <= 0.0:
		deactivate()
		return
	attack_cd -= delta
	match kind:
		"spirit":
			_chase_and_touch(delta, true)
		"holy_spear":
			_spear_hunt(delta)
		"skeleton", "dragonling", "phoenix", "thunder_beetle":
			_chase_and_shoot(delta)
		"turret":
			_shoot_nearest(delta)
		"blade", "orbit_blade", "scythe":
			_orbit(delta)
		"tornado":
			_tornado(delta)
		"moth":
			_moth(delta)
		"shadow_clone":
			_clone(delta)
		"aura":
			pass

func _nearest() -> Node2D:
	var res: Array = game.nearest_enemy(global_position, 420.0)
	if res.is_empty():
		return null
	return res[0]

func _spear_hunt(delta: float) -> void:
	var speed_add := 1.0 + float(game.player.upg.mod("summon_speed"))
	var tgt := _nearest()
	if tgt != null:
		var dir := (tgt.global_position - global_position)
		if dir.length() > 1.0:
			var move_dir := dir.normalized()
			global_position += move_dir * speed * speed_add * delta
			if sprite != null:
				sprite.rotation = move_dir.angle() + PI * 0.25
	else:
		orbit_angle += delta * 2.4 * speed_add
		var home := game.player.global_position + Vector2.RIGHT.rotated(orbit_angle) * 36.0
		var to_home := home - global_position
		if to_home.length() > 2.0:
			var mdir := to_home.normalized()
			global_position += mdir * minf(to_home.length(), speed * speed_add * delta)
			if sprite != null:
				sprite.rotation = mdir.angle() + PI * 0.25
	for enemy in game.enemies_in_radius(global_position, radius + 12.0):
		var key: int = int(enemy.get_instance_id())
		if float(hit_cd.get(key, 0.0)) > 0.0:
			continue
		hit_cd[key] = 0.35
		game.damage_enemy(enemy, damage, {"source": "holy_spear", "knockback": 18.0, "knock_dir": (enemy.global_position - global_position)})
		game.spawn_fx(enemy.global_position, color, 14.0, 0.18)
	for key in hit_cd.keys():
		hit_cd[key] = float(hit_cd[key]) - delta
		if float(hit_cd[key]) <= 0.0:
			hit_cd.erase(key)

func _chase_and_touch(delta: float, die_on_hit: bool) -> void:
	var tgt := _nearest()
	if tgt == null:
		return
	var dir: Vector2 = (tgt.global_position - global_position)
	if dir.length() < radius + tgt.radius:
		game.damage_enemy(tgt, damage, {"source": "summon", "knockback": 20.0, "knock_dir": dir})
		if die_on_hit:
			game.spawn_fx(global_position, color, 18.0, 0.2)
			deactivate()
		return
	global_position += dir.normalized() * speed * delta

func _chase_and_shoot(delta: float) -> void:
	var tgt := _nearest()
	if tgt == null:
		if game.player != null:
			orbit_angle += delta * 1.4
			var follow := game.player.global_position + Vector2.RIGHT.rotated(orbit_angle) * 44.0
			var to_f := follow - global_position
			if to_f.length() > 6.0:
				global_position += to_f.normalized() * minf(to_f.length(), speed * delta)
		return
	var dir: Vector2 = (tgt.global_position - global_position)
	if dir.length() > 70.0:
		global_position += dir.normalized() * speed * delta
	if attack_cd <= 0.0:
		attack_cd = interval
		match kind:
			"thunder_beetle":
				game.lightning_strike_at(tgt.global_position, 28.0, damage)
			_:
				if kind=="dragonling" and dragon_breath:
					game.aoe_damage(tgt.global_position,48.0,damage,{"source":"dragon_breath"}); game.apply_status_radius(tgt.global_position,48.0,"burn",3.0,{"dps":4.0}); game.spawn_fx(tgt.global_position,Color("#ff6a20"),48.0,0.3)
				else:
					game.spawn_bullet(global_position, dir.normalized(), damage, {"speed": 300.0, "radius": 3.5, "color": color, "source": "summon", "burn": {"dps": 2.0, "dur": 2.0} if kind in ["dragonling", "phoenix"] else {}})

func _shoot_nearest(delta: float) -> void:
	var tgt := _nearest()
	if tgt == null:
		return
	if attack_cd <= 0.0:
		attack_cd = interval
		var dir: Vector2 = (tgt.global_position - global_position).normalized()
		game.spawn_bullet(global_position, dir, damage, {"speed": 340.0, "radius": 3.0, "color": color, "source": "summon"})

func _orbit(delta: float) -> void:
	var speed_add := 1.0 + float(game.player.upg.mod("summon_speed"))
	orbit_angle += delta * 2.8 * speed_add * (2.0 if kind == "orbit_blade" else 1.0)
	global_position = game.player.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
	if sprite != null:
		sprite.rotation += delta * (10.0 if kind == "scythe" else 6.0) * speed_add
	for enemy in game.enemies_in_radius(global_position, radius + 14.0):
		var key: int = int(enemy.get_instance_id())
		if float(hit_cd.get(key, 0.0)) > 0.0:
			continue
		hit_cd[key] = 0.45
		game.damage_enemy(enemy, damage, {"source": "scythe" if kind == "scythe" else "summon"})
	# остывание индивидуальных целей
	for key in hit_cd.keys():
		hit_cd[key] = float(hit_cd[key]) - delta
		if float(hit_cd[key]) <= 0.0:
			hit_cd.erase(key)

func _tornado(delta: float) -> void:
	var tgt := _nearest()
	if tgt != null:
		var dir: Vector2 = tgt.global_position - global_position
		global_position += dir.normalized() * speed * delta
	global_position += Vector2.RIGHT.rotated(orbit_angle + remaining) * 20.0 * delta
	if attack_cd <= 0.0:
		attack_cd = 0.4
		game.aoe_damage(global_position, radius, damage * 0.4, {"source": "tornado"})

func _moth(delta: float) -> void:
	var tgt := _nearest()
	if tgt == null:
		global_position = global_position.lerp(game.player.global_position + Vector2.RIGHT.rotated(orbit_angle) * 40.0, delta * 2.0)
		return
	var dir: Vector2 = tgt.global_position - global_position
	if dir.length() > 40.0:
		global_position += dir.normalized() * speed * delta
	if attack_cd <= 0.0:
		attack_cd = interval
		game.freeze_enemy(tgt, 1.2)
		game.damage_enemy(tgt, damage, {"source": "summon"})

func _clone(delta: float) -> void:
	if attack_cd <= 0.0:
		attack_cd = 0.4
		game.aoe_damage(global_position, radius, damage * 0.5, {"source": "summon"})
