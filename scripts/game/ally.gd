class_name Ally
extends Node2D
## Призывы и временные союзники: духи, скелеты, турели, клинки, торнадо, мотыльки,
## феникс, дракончик, бумеранги, теневые клоны.

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

# --- бумеранг: висит у героя, летит к одной цели по дуге и возвращается
var boom_state := "idle"
var boom_target := Vector2.ZERO
var boom_timer := 0.0
var boom_arc := 1.0
var boom_spin := 0.0
## Рикошеты: каждое улучшение дерева бумеранга добавляет 1–3 отскока к другому врагу.
var boom_bounce_left := 0
var boom_last_target := 0

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
	boom_state = "idle"
	boom_target = Vector2.ZERO
	boom_timer = randf_range(0.15, 0.5)
	boom_bounce_left = 0
	boom_last_target = 0
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
		"boomerang": color = Color(0.86, 0.72, 0.42); radius = 9.0; speed = 168.0
		"thunder_beetle": color = Color(0.7, 0.8, 1.0); radius = 9.0; speed = 135.0
		"shadow_clone": color = Color(0.35, 0.3, 0.45); radius = 10.0; speed = 0.0
		"dragonling": color = Color(0.6, 0.9, 0.6); radius = 11.0; speed = 150.0
		"aura": color = Color(1.0, 0.9, 0.5); radius = float(opts.get("radius", 120.0)); speed = 0.0
	var cls:={"spirit":"ally_spirit","skeleton":"ally_skeleton","turret":"ally_turret","blade":"ally_blade","orbit_blade":"ally_blade","tornado":"ally_tornado","phoenix":"ally_phoenix","moth":"ally_moth","scythe":"ally_scythe","boomerang":"ally_boomerang","thunder_beetle":"ally_beetle","shadow_clone":"ally_clone","dragonling":"ally_dragon","aura":"ally_aura"}.get(kind,"ally_spirit")
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
		"boomerang":
			_boomerang_tick(delta)
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

const BOOMERANG_RANGE := 300.0
const BOOMERANG_ORBIT := 34.0

func _boomerang_slot() -> int:
	var idx := 0
	for a in game.allies:
		if a == self:
			return idx
		if a.active and a.kind == "boomerang":
			idx += 1
	return idx

## Бумеранг: 1) кружит у героя, 2) летит к выбранной цели по дуге,
## 3) возвращается к герою. Урон наносится в обе стороны, скорость намеренно невысокая.
func _boomerang_tick(delta: float) -> void:
	if game == null or game.player == null:
		return
	var speed_add := 1.0 + float(game.player.upg.mod("summon_speed")) * 0.5
	var ppos: Vector2 = game.player.global_position
	boom_spin += delta * (11.0 + speed * 0.02) * speed_add
	if sprite != null:
		sprite.rotation = boom_spin
	boom_timer -= delta
	match boom_state:
		"idle":
			orbit_angle += delta * 1.9 * speed_add
			var home: Vector2 = ppos + Vector2.RIGHT.rotated(orbit_angle) * BOOMERANG_ORBIT
			global_position = global_position.lerp(home, clampf(8.0 * delta, 0.0, 1.0))
			if boom_timer <= 0.0 and game.player != null:
				var cand: Array = game.nearest_enemies(ppos, BOOMERANG_RANGE, 6)
				if not cand.is_empty():
					var slot := _boomerang_slot()
					var tgt: Node2D = cand[slot % cand.size()]
					if tgt != null and is_instance_valid(tgt) and tgt.active:
						boom_target = tgt.global_position
						boom_last_target = int(tgt.get_instance_id())
						boom_arc = 1.0 if slot % 2 == 0 else -1.0
						boom_bounce_left = int(game.player.upg.flag_num("boomerang_ricochet"))
						boom_state = "out"
						boom_timer = 0.0
						attack_cd = 0.0
						hit_cd.clear()
		"out":
			var to_target: Vector2 = boom_target - global_position
			var dist := to_target.length()
			var dir: Vector2 = to_target / dist if dist > 0.5 else Vector2.RIGHT
			var step := speed * speed_add * delta
			global_position += dir * step + Vector2(-dir.y, dir.x) * boom_arc * 34.0 * delta
			if dist <= step + 12.0 or boom_timer <= -1.5:
				if boom_bounce_left > 0 and _boomerang_retarget():
					# Рикошет: бумеранг уходит к следующему врагу, не возвращаясь к герою
					boom_bounce_left -= 1
					boom_timer = 0.0
					attack_cd = 0.25
					hit_cd.clear()
					game.spawn_fx(global_position, color, 20.0, 0.2)
					game.spawn_perk_fx("boomerang", global_position, 34.0, 0.24)
					AudioManager.play_sfx("boomerang", randf_range(1.06, 1.22))
				else:
					boom_state = "back"
					boom_timer = 0.0
					hit_cd.clear()
					if attack_cd <= 0.0:
						attack_cd = 0.2
						game.spawn_fx(global_position, color, 16.0, 0.18)
						game.spawn_perk_fx("boomerang", global_position, 26.0, 0.2)
						AudioManager.play_sfx("boomerang", randf_range(0.94, 1.08))
		"back":
			var to_player: Vector2 = ppos - global_position
			var back_dist := to_player.length()
			var back_step := speed * speed_add * 1.2 * delta
			if back_dist > 0.5:
				global_position += to_player / back_dist * minf(back_dist, back_step)
			if back_dist <= 13.0:
				boom_state = "idle"
				boom_timer = randf_range(0.45, 0.85)
				orbit_angle = (global_position - ppos).angle()
	for enemy in game.enemies_in_radius(global_position, radius + 10.0):
		var key: int = int(enemy.get_instance_id())
		if float(hit_cd.get(key, 0.0)) > 0.0:
			continue
		hit_cd[key] = 0.3
		game.damage_enemy(enemy, damage, {"source": "boomerang", "knockback": 14.0,
			"knock_dir": (enemy.global_position - global_position)})
		game.spawn_fx(enemy.global_position, color, 12.0, 0.16)
		game.spawn_perk_fx("boomerang", enemy.global_position, 24.0, 0.18)
	for key in hit_cd.keys():
		hit_cd[key] = float(hit_cd[key]) - delta
		if float(hit_cd[key]) <= 0.0:
			hit_cd.erase(key)

## Выбирает следующего врага для рикошета рядом с бумерангом (не того же самого).
func _boomerang_retarget() -> bool:
	if game == null:
		return false
	var best: Node2D = null
	var best_d := 1e20
	for e in game.enemies_in_radius(global_position, 230.0):
		if e == null or not is_instance_valid(e) or not e.active:
			continue
		if int(e.get_instance_id()) == boom_last_target:
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	boom_last_target = int(best.get_instance_id())
	boom_target = best.global_position
	boom_arc = -boom_arc
	return true

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
			var follow: Vector2 = game.player.global_position + Vector2.RIGHT.rotated(orbit_angle) * 44.0
			var to_f: Vector2 = follow - global_position
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
				for b_tgt in game.nearest_enemies(global_position, 260.0, 2):
					game.lightning_strike_at(b_tgt.global_position, 28.0, damage)
			_:
				if kind=="dragonling" and dragon_breath:
					game.aoe_damage(tgt.global_position,48.0,damage,{"source":"dragon_breath"}); game.apply_status_radius(tgt.global_position,48.0,"burn",3.0,{"dps":4.0}); game.spawn_fx(tgt.global_position,Color("#ff6a20"),48.0,0.3); game.spawn_perk_fx("fireball", tgt.global_position, 52.0, 0.30)
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
		if kind == "scythe":
			game.spawn_perk_fx("curse", enemy.global_position, 28.0, 0.22)
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
