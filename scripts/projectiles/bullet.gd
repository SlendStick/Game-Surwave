class_name Bullet
extends Node2D
## Снаряд игрока: полёт, пробитие, отскоки, взрывы, цепные молнии, статусы.

var game: Node = null
var vel := Vector2.ZERO
var damage := 1.0
var opts: Dictionary = {}
var life := 2.0
var radius := 3.0
var pierce := 0
var bounce := 0
var hit_list: Array = []
var active := false
var homing := false
var target: Node2D = null
var sprite: Sprite2D = null
var color := Color.WHITE
var stuck := false
var traveled := 0.0
var returned := false
var spin_speed := 0.0
var wave_phase := 0.0

func setup(g: Node) -> void:
	game = g
	if sprite == null:
		sprite = Gfx.square(self, Vector2(6, 6), Color.WHITE)

func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, o: Dictionary) -> void:
	opts = o.duplicate()
	damage = dmg
	global_position = pos
	active = true
	visible = true
	hit_list.clear()
	stuck = false
	traveled = 0.0
	returned = false
	wave_phase = randf() * TAU
	color = opts.get("color", Color.WHITE)
	radius = float(opts.get("radius", 3.0))
	pierce = int(opts.get("pierce", 0))
	bounce = int(opts.get("bounce", 0))
	life = float(opts.get("life", 1.8))
	homing = bool(opts.get("homing", false))
	target = null
	vel = dir.normalized() * float(opts.get("speed", 400.0))
	var cls := "projectile_orb"
	var behavior := String(opts.get("behavior", ""))
	var source := String(opts.get("source", ""))
	var wid := String(opts.get("weapon_id", ""))
	spin_speed = 15.0 if (behavior == "dagger" or behavior == "hammer" or opts.has("boomerang")) else 0.0
	if bool(opts.get("holy", false)) or wid == "holy_spears":
		cls = "projectile_spear"
	elif wid == "shadow_daggers" or behavior == "dagger":
		cls = "projectile_dagger"
	elif wid == "crossbow":
		cls = "projectile_bolt"
	elif wid == "bow" or behavior == "arrow" or source in ["aimed", "split"]:
		cls = "projectile_arrow"
	elif wid == "shotgun" or behavior == "shotgun":
		cls = "projectile_pellet"
	elif wid == "revolver":
		cls = "projectile_bullet"
	elif wid == "lightning_staff" or behavior == "lightning":
		cls = "projectile_lightning"
	elif wid == "poison_clouds" or behavior == "gas":
		cls = "projectile_gas"
	elif opts.has("burn") or behavior == "fireball":
		cls = "projectile_fire"
	elif opts.has("freeze") or wid == "ice_needles":
		cls = "projectile_ice"
	var ptex := Assets.tex(cls, color)
	sprite.texture = ptex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color.WHITE
	var base_w := float(maxi(1, ptex.get_width()))
	var sc := maxf(0.55, (radius * 2.6) / base_w)
	sprite.scale = Vector2(sc, sc)
	rotation = vel.angle()
	if opts.has("angle"):
		rotation = float(opts["angle"])

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	# самонаведение и уникальные траектории
	if homing:
		if target == null or not is_instance_valid(target) or not target.active:
			var near: Array = game.nearest_enemy(global_position, 260.0)
			target = near[0] if not near.is_empty() else null
		if target != null and is_instance_valid(target):
			var want := (target.global_position - global_position).normalized() * vel.length()
			vel = vel.lerp(want, clampf(9.0 * delta, 0.0, 1.0))
	elif bool(opts.get("is_orb", false)):
		wave_phase += delta * 7.5
		var perp := Vector2(-vel.y, vel.x).normalized()
		global_position += perp * sin(wave_phase) * 28.0 * delta
		if target == null or not is_instance_valid(target) or not target.active:
			var near_orb: Array = game.nearest_enemy(global_position, 150.0)
			target = near_orb[0] if not near_orb.is_empty() else null
		if target != null and is_instance_valid(target):
			var want_orb := (target.global_position - global_position).normalized() * vel.length()
			vel = vel.lerp(want_orb, clampf(2.6 * delta, 0.0, 1.0))
	if spin_speed != 0.0:
		rotation += spin_speed * delta
	elif not opts.has("angle"):
		rotation = vel.angle()
	var prev := global_position
	global_position += vel * delta
	life -= delta
	if life <= 0.0:
		_expire()
		return
	# границы карты
	if not game.map_rect.has_point(global_position):
		deactivate()
		return
	# столкновение с препятствием
	var obs: Dictionary = game.obstacle_at(global_position, radius)
	if not obs.is_empty():
		if String(obs.get("kind", "")) == "reflect" and randf() < float(obs.get("reflect", 1.0)):
			var normal: Vector2 = obs.get("normal", Vector2.UP)
			vel = vel.bounce(normal)
			global_position = prev
			pierce = maxi(pierce, 0)
			return
		if float(obs.get("max_hp", 0.0)) > 0.0 and obs.has("ref"):
			game.hit_obstacle(obs["ref"], damage)
			if not opts.has("pierce_obstacles"):
				deactivate()
				return
		if String(obs.get("kind", "")) != "glyph":
			if opts.has("explode"):
				_explode()
			deactivate()
			return
	# столкновение с врагами (свип по отрезку пути — без «прошивания»)
	var travel := prev.distance_to(global_position)
	traveled += travel
	# «Мясник»: топор летит обратно и наносит урон на возврате
	if opts.has("boomerang") and not returned and traveled > 140.0:
		returned = true
		vel = -vel
		damage = maxf(damage, float(opts.get("return_damage", damage)))
		hit_list.clear()
	var steps := maxi(1, int(ceil(travel / maxf(radius * 2.0, 8.0))))
	if steps <= 1:
		var enemy_single: Node2D = game.enemy_at(global_position, radius)
		if enemy_single != null:
			_hit(enemy_single)
			return
	else:
		for i in steps:
			var p := prev.lerp(global_position, float(i + 1) / float(steps))
			var enemy_step: Node2D = game.enemy_at(p, radius)
			if enemy_step != null:
				global_position = p
				_hit(enemy_step)
				return
	# эффект «прилипания» стрел
	if stuck:
		player_stick()

func player_stick() -> void:
	pass

func _hit(enemy: Node2D) -> void:
	if hit_list.has(enemy):
		return
	hit_list.append(enemy)
	var dmg := damage
	if float(opts.get("full_hp_bonus", 0.0)) > 0.0 and enemy.hp >= enemy.max_hp * 0.75:
		dmg *= float(opts.get("full_hp_bonus", 1.0))
	if bool(opts.get("holy", false)) and String(enemy.data.get("clan", "")) == "undead":
		dmg *= 2.0
	var knock_dir := vel.normalized()
	# базовое отбрасывание зависит от типа врага (техспека 4.2)
	var kb_table: Dictionary = DB.balance.get("knockback_base", {})
	var kb_base := float(kb_table.get(String(enemy.role), 40.0))
	game.damage_enemy(enemy, dmg, {
		"source": opts.get("source", "weapon"),
		"knockback": kb_base * float(opts.get("knockback", 1.0)),
		"knock_dir": knock_dir,
		"crit": bool(opts.get("crit", false)),
		"armor_pierce": bool(opts.get("armor_pierce", false)),
	})
	# статусы
	if opts.has("burn"):
		var b: Dictionary = opts["burn"]
		game.apply_status(enemy, "burn", float(b.get("dur", 3.0)), {"dps": float(b.get("dps", 3.0))})
	if bool(opts.get("curse", false)):
		game.apply_status(enemy, "curse", 3.0, {"dps": damage * 2.0 / 3.0})
		game.spawn_perk_fx("curse", enemy.global_position, 32.0, 0.26)
	if float(opts.get("stun", 0.0)) > 0.0:
		enemy.stun = maxf(float(enemy.stun), float(opts["stun"]))
	if opts.has("gas"):
		var g: Dictionary = opts["gas"]
		game.spawn_hazard_zone(global_position, float(g.get("dps", 4.0)), float(g.get("dur", 4.0)),
			float(g.get("radius", 40.0)), Color(0.5, 1.0, 0.2), {"poison": float(g.get("dps", 4.0)), "pattern": "poison"})
	if opts.has("poison"):
		var pz: Dictionary = opts["poison"]
		game.apply_status(enemy, "poison", float(pz.get("dur", 4.0)), {"dps": float(pz.get("dps", 4.0))})
	if float(opts.get("freeze", 0.0)) > 0.0:
		game.freeze_enemy(enemy, float(opts["freeze"]))
	if float(opts.get("freeze_chance", 0.0)) > 0.0 and randf() < float(opts["freeze_chance"]):
		game.freeze_enemy(enemy, float(DB.balance["player"].get("freeze_dur", 2.0)))
	if float(opts.get("tornado", 0.0)) > 0.0:
		game.spawn_ally("tornado", {"damage": float(opts["tornado"]), "duration": 2.0, "radius": 34.0, "pos": enemy.global_position})
		game.spawn_perk_fx("wind", enemy.global_position, 36.0, 0.28)
	if String(opts.get("behavior", "")) == "lightning":
		game.spawn_perk_fx("lightning", enemy.global_position, 34.0, 0.26)
	elif bool(opts.get("crit", false)):
		game.spawn_perk_fx("blood", enemy.global_position, 28.0, 0.22)
	if opts.has("explode"):
		_explode()
	if int(opts.get("split", 0)) > 0:
		var n := int(opts["split"])
		for i in n:
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(n))
			game.spawn_bullet(global_position, dir, damage * 0.4, {"speed": float(vel.length()), "radius": radius * 0.7, "color": color, "life": 0.6, "source": "split"})
	if int(opts.get("chain", 0)) > 0:
		game.chain_lightning(enemy, int(opts["chain"]), damage * 0.6)
	if bool(opts.get("stick", false)):
		game.player.stuck_arrows.append(global_position)
		deactivate()
		return
	if pierce > 0:
		pierce -= 1
		damage *= 0.8  # -20% урона за каждое пробитие (техспека 4.3)
		game.spawn_fx(global_position, color.lightened(0.25), 14.0, 0.14, true)
		return
	if bounce > 0:
		bounce -= 1
		damage *= 0.9  # -10% урона за каждый отскок (техспека 4.4)
		game.spawn_fx(global_position, Color(1.0, 0.9, 0.45), 16.0, 0.16)
		var near: Array = game.nearest_enemy_excluding(global_position, 200.0, hit_list)
		if not near.is_empty():
			vel = (near[0].global_position - global_position).normalized() * vel.length()
			return
	deactivate()

func _explode() -> void:
	var power := float(opts.get("explode", 0.0))
	if power <= 0.0:
		return
	var r := float(opts.get("explode_radius", 64.0))
	game.aoe_damage(global_position, r, power, {"source": "explosion", "holy": bool(opts.get("holy", false))})
	game.spawn_fx(global_position, color, r, 0.28)
	if opts.has("burn") or String(opts.get("behavior", "")) == "fireball" or bool(opts.get("napalm", false)):
		game.spawn_perk_fx("fireball", global_position, r * 1.1, 0.30)
	elif bool(opts.get("holy", false)):
		game.spawn_perk_fx("holy", global_position, r * 0.95, 0.30)
	AudioManager.play_sfx("shot_heavy", 1.25)
	if bool(opts.get("napalm", false)):
		game.spawn_hazard_zone(global_position, 5.0, 4.0, r * 0.7, Color(1.0, 0.45, 0.1), {"pattern": "fire"})
	if int(opts.get("cluster", 0)) > 0:
		var n := int(opts["cluster"])
		for i in n:
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(n))
			game.spawn_bullet(global_position, dir, power * 0.5, {"speed": 200.0, "radius": 3.0, "life": 0.4, "explode": power * 0.5, "explode_radius": r * 0.6, "color": color, "source": "cluster"})

func _expire() -> void:
	if opts.has("explode"):
		_explode()
	deactivate()
