class_name Enemy
extends Node2D
## Враг: фоддер, стрелок, элита, мини-босс и босс (паттерн-машина по фазам).

var game: Node = null
var data: Dictionary = {}
var id := ""
var role := "fodder"
var hp := 1.0
var max_hp := 1.0
var speed := 50.0
var damage := 1
var radius := 7.0
var color := Color.WHITE
var behavior: Dictionary = {}
var flags: Dictionary = {}
var elite := false
var boss := false
var is_final := false
var boss_def: Dictionary = {}
var phase := 0
var pattern_timers: Array = []
var pattern_angles: Dictionary = {}
var active := false
var dead := false
var sprite: Sprite2D = null
var statuses: Dictionary = {}
var knock := Vector2.ZERO
var knock_timer := 0.0
var teleport_cd := 0.0
var regen_cd := 0.0
var life_left := -1.0
var orbit_angle := 0.0
var dashing := false
var dash_cd := 0.0
var attack_cd := 0.0
var summon_cd := 0.0
var stun := 0.0
var jump_cd := 0.0
var charge_timer := 0.0
var charge_dir := Vector2.ZERO
var charging := false
var walk_phase := 0.0
var hit_flash := 0.0
var last_source := ""
var dot_accum := 0.0
var hp_bar: Sprite2D = null
var label: Label = null
var spawn_anim := 0.0
var elite_ring: Sprite2D = null
var tick_phase := 0
var transition_left := 0.0
var attack_anim := 0.0
var hurt_anim := 0.0

func setup(g: Node) -> void:
	game = g

func init_enemy(g: Node, enemy_data: Dictionary, pos: Vector2, hp_mult: float = 1.0, dmg_mult: float = 1.0, speed_mult: float = 1.0, make_elite: bool = false) -> void:
	game = g
	data = enemy_data
	id = String(data.get("id", ""))
	role = String(data.get("role", "fodder"))
	behavior = data.get("behavior", {"kind": "chase"})
	flags = data.get("flags", {})
	max_hp = maxf(1.0, float(data.get("hp", 1)) * hp_mult)
	hp = max_hp
	speed = float(data.get("speed", 50.0)) * speed_mult
	damage = maxi(1, int(round(float(data.get("damage", 1)) * dmg_mult)))
	radius = float(data.get("radius", 7.0))
	color = Gfx.gothic(Gfx.hex(String(data.get("color", "#ffffff"))), 0.24)
	elite = make_elite or role == "elite"
	boss = false
	is_final = false
	boss_def = {}
	phase = 0
	transition_left = 0.0
	pattern_timers.clear()
	statuses.clear()
	knock = Vector2.ZERO
	attack_cd = float(behavior.get("proj", {}).get("interval", 2.0))
	summon_cd = float(behavior.get("interval", 5.0))
	stun = 0.0
	charging = false
	charge_timer = 0.0
	dead = false
	active = true
	visible = true
	last_source = ""
	dot_accum = 0.0
	spawn_anim = 0.0
	global_position = pos
	tick_phase = randi() % 3
	orbit_angle = randf() * TAU
	teleport_cd = float(flags.get("teleport_interval", 0.0))
	regen_cd = float(flags.get("regen", {}).get("every", 0.0)) if flags.get("regen") != null else 0.0
	life_left = float(flags.get("lifetime", -1.0))
	dash_cd = float(behavior.get("interval", 3.0))
	dashing = false
	_setup_visual()

func init_boss(g: Node, gb: Dictionary, pos: Vector2, hp_override: float = -1.0, final_form: bool = false) -> void:
	game = g
	boss_def = gb
	data = gb
	id = String(gb.get("id", "boss"))
	role = "boss"
	boss = true
	elite = false
	is_final = final_form
	behavior = {"kind": "boss"}
	flags = {}
	max_hp = hp_override if hp_override > 0.0 else float(gb.get("hp", 1000))
	hp = max_hp
	speed = 46.0
	damage = 3
	radius = float(gb.get("radius", 26.0))
	color = Gfx.gothic(Gfx.hex(String(gb.get("color", "#ff4040"))), 0.4)
	phase = 0
	transition_left = 0.0
	attack_anim = 0.0
	hurt_anim = 0.0
	pattern_timers.clear()
	for p in _phase_patterns():
		pattern_timers.append(float(p.get("interval", 2.0)) * 0.6)
	statuses.clear()
	knock = Vector2.ZERO
	attack_cd = 1.0
	summon_cd = 5.0
	stun = 0.0
	dead = false
	active = true
	visible = true
	last_source = ""
	global_position = pos
	_setup_visual()
	EventBus.boss_spawned.emit(String(gb.get("name", "БОСС")), max_hp, is_final)

## Класс визуала: имя спрайта/фигуры (каждый мини-босс и босс карты имеет свой спрайт).
func visual_class() -> String:
	if boss:
		if id == "boss_satanail" and game != null and game.megaphase:
			return "boss_satan"
		if Assets.has_real_sprite(id):
			return id
		var map_key := "boss_" + String(boss_def.get("map", ""))
		if map_key != "boss_" and Assets.has_real_sprite(map_key):
			return map_key
		return "boss_champion"
	if role == "miniboss" or id.begins_with("mb_"):
		if Assets.has_real_sprite(id):
			return id
		return "mb"
	var mid := String(game.map_data.get("id", "")) if (game != null and game.map_data is Dictionary) else ""
	if mid != "":
		var themed := "%s__%s" % [id, mid]
		if Assets.has_real_sprite(themed):
			return themed
	return id

func _base_modulate() -> Color:
	return Color.WHITE if Assets.has_real_sprite(visual_class()) else color

## Тон карты: слегка подкрашивает врагов под палитру, чтобы карты различались.
func apply_map_tint(tint: Color) -> void:
	if tint.a <= 0.0:
		return
	color = color.lerp(tint, 0.3)
	_setup_visual()

func _setup_visual() -> void:
	var vis_px := maxf(20.0, radius * 2.4)
	if boss:
		vis_px = maxf(114.0, radius * 2.0) if (id == "boss_satanail" or id == "boss_satan" or is_final) else maxf(86.0, radius * 2.1)
	elif role == "miniboss":
		vis_px = maxf(40.0, radius * 2.2)
	var size := Vector2(vis_px, vis_px)
	var vcls := visual_class()
	var tex := Assets.tex(vcls, color)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	sprite.texture = tex
	var base := float(maxi(1, tex.get_width()))
	sprite.scale = Vector2(maxf(1.0, size.x) / base, maxf(1.0, size.y) / base)
	sprite.modulate = Color.WHITE
	if elite:
		if elite_ring == null:
			elite_ring = Sprite2D.new()
			elite_ring.texture = Assets.tex("elite", Color(1.0, 0.85, 0.25, 0.7))
			elite_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			elite_ring.z_index = -1
			add_child(elite_ring)
		elite_ring.visible = true
		elite_ring.scale = Vector2((size.x + 10.0) / float(Assets.BASE_PX), (size.y + 10.0) / float(Assets.BASE_PX))
		elite_ring.modulate = Color(1, 1, 1, 0.85)
	elif elite_ring != null:
		elite_ring.visible = false
	if boss:
		# Шкала жизни босса рисуется исключительно в HUD (без дублирования на голове босса).
		if hp_bar != null:
			hp_bar.visible = false
		if label != null:
			label.visible = false
	elif role == "miniboss":
		if hp_bar == null:
			hp_bar = Gfx.square(self, Vector2(14.0, 1.5), Color(0.92, 0.30, 0.24), Vector2(0, -vis_px * 0.5 - 5.0))
		hp_bar.visible = true
		if label == null:
			label = Label.new()
			label.add_theme_font_size_override("font_size", 7)
			label.modulate = Color(1.0, 0.86, 0.55)
			label.position = Vector2(-34, -vis_px * 0.5 - 16.0)
			label.size = Vector2(68, 10)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(label)
		label.visible = true
		label.text = String(data.get("name", ""))
	elif elite:
		if hp_bar != null:
			hp_bar.visible = false
		if label == null:
			label = Label.new()
			label.add_theme_font_size_override("font_size", 7)
			label.modulate = Color(1, 0.9, 0.4)
			label.position = Vector2(-10, -radius - 12.0)
			add_child(label)
		label.visible = true
		label.text = "ЭЛИТА"
	else:
		if hp_bar != null:
			hp_bar.visible = false
		if label != null:
			label.visible = false

func deactivate() -> void:
	active = false
	dead = true
	visible = false
	global_position = Vector2(-10000, -10000)

# ------------------------------------------------------------------ ТИК
func tick(delta: float) -> void:
	if not active:
		return
	spawn_anim = minf(0.15, spawn_anim + delta)
	walk_phase += delta * (8.0 if id == "bat" else 5.0)
	attack_anim = maxf(0.0, attack_anim - delta)
	hurt_anim = maxf(0.0, hurt_anim - delta)
	if sprite:
		var vcls := visual_class()
		var fr: Array = []
		if boss and hurt_anim > 0.0:
			fr = Assets.frames(vcls, "hurt")
			if not fr.is_empty():
				var h_idx := clampi(int((1.0 - hurt_anim / 0.28) * float(fr.size())), 0, fr.size() - 1)
				sprite.texture = fr[h_idx]
		elif boss and attack_anim > 0.0:
			fr = Assets.frames(vcls, "attack")
			if not fr.is_empty():
				var a_idx := clampi(int((1.0 - attack_anim / 0.42) * float(fr.size())), 0, fr.size() - 1)
				sprite.texture = fr[a_idx]
		if fr.is_empty():
			var state := "idle" if (boss and transition_left > 0.0) else "walk"
			fr = Assets.frames(vcls, state)
			if not fr.is_empty():
				var idx := int(floor(walk_phase * 1.4)) % fr.size()
				sprite.texture = fr[idx]
		sprite.position.y = sin(walk_phase) * (1.8 if id == "bat" else 0.5)
		if game.player != null:
			sprite.flip_h = game.player.global_position.x < global_position.x
		if boss:
			sprite.rotation = sin(walk_phase * 0.35) * 0.025
		elif id == "bat" and fr.is_empty():
			sprite.scale.x = absf(sprite.scale.y) * (0.72 + 0.28 * absf(sin(walk_phase)))
	if elite_ring != null and elite_ring.visible:
		elite_ring.rotation += delta * 1.1
	var base_mod := _base_modulate()
	if game.player != null and game.player.has_meta("trial_invisible") and sprite and hit_flash <= 0.0:
		var a := 1.0 if global_position.distance_to(game.player.global_position) < 128.0 else 0.08
		sprite.modulate = Color(base_mod.r, base_mod.g, base_mod.b, a)
	if hit_flash > 0.0:
		hit_flash -= delta
		if sprite:
			sprite.modulate = Color(1.9, 1.9, 1.9) if hit_flash > 0.0 else base_mod
	_tick_statuses(delta)
	if stun > 0.0:
		stun -= delta
		_apply_knock(delta)
		return
	if boss:
		_boss_tick(delta)
	else:
		_normal_tick(delta)
		_tick_specials(delta)
	_apply_knock(delta)
	_try_contact_damage()
	if hp_bar != null and hp_bar.visible:
		var frac := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		hp_bar.scale = Vector2(maxf(0.5, 14.0 * frac), 1.5)
		hp_bar.position.x = -14.0 * (1.0 - frac)

## Особые способности врагов из ENEMIES_COMPLETE_SPECIFICATION.md.
func _tick_specials(delta: float) -> void:
	var player_pos: Vector2 = game.player.global_position
	var to_player := player_pos - global_position
	# время жизни призыва
	if life_left > 0.0:
		life_left -= delta
		if life_left <= 0.0:
			game.spawn_fx(global_position, color, radius * 2.0, 0.25)
			deactivate()
			return
	# телепортация (тёмный маг)
	var tp := float(flags.get("teleport_interval", 0.0))
	if tp > 0.0:
		teleport_cd -= delta
		if teleport_cd <= 0.0:
			teleport_cd = tp
			var dist := float(flags.get("teleport_dist", 64.0))
			global_position = game.clamp_to_map(global_position + Vector2.RIGHT.rotated(randf() * TAU) * dist)
			game.spawn_fx(global_position, color, radius * 2.5, 0.2)
	# регенерация (оборотень)
	if flags.get("regen") != null:
		var rg: Dictionary = flags["regen"]
		regen_cd -= delta
		if regen_cd <= 0.0:
			regen_cd = float(rg.get("every", 5.0))
			hp = minf(max_hp, hp + float(rg.get("hp", 1.0)))
			game.spawn_fx(global_position, Color(0.2, 1.0, 0.3), radius, 0.2)
	# аура холода (замёрзший зомби)
	var aura := float(flags.get("cold_aura", 0.0))
	if aura > 0.0 and to_player.length() < aura:
		game.player.add_status("slow", 0.25, {"amount": float(flags.get("cold_slow", 0.15))})
	# кровожадность (оборотень, при HP игрока < 50%)
	if flags.get("bloodlust") != null and not boss:
		if float(game.player.hp) / maxf(1.0, float(game.player.max_hp)) < 0.5:
			speed = float(data.get("speed", 50.0)) * (1.0 + float(flags["bloodlust"]))
	# рывок (оборотень): charger уже двигает, здесь только fx
	if dashing:
		dash_cd -= delta
		if dash_cd <= 0.0:
			dashing = false
	elif String(behavior.get("kind", "")) == "charger":
		if charge_timer <= 0.0 and not charging:
			game.spawn_fx(global_position, color, radius * 1.6, 0.18)
	# пикирование летучей мыши
	if String(behavior.get("kind", "")) == "orbit":
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior.get("attack_cd", 3.0))
			knock = to_player.normalized() * float(behavior.get("dive_speed", 120.0))
			game.spawn_fx(global_position, color, radius * 1.5, 0.15)

## Отбрасывание длится 0.15 с (техспека 4.2).
func _apply_knock(delta: float) -> void:
	if knock_timer > 0.0:
		knock_timer = maxf(0.0, knock_timer - delta)
		global_position += knock * delta
		if knock_timer <= 0.0:
			knock = Vector2.ZERO
	elif knock.length() > 1.0:
		global_position += knock * delta
		knock = knock.lerp(Vector2.ZERO, clampf(8.0 * delta, 0.0, 1.0))
	else:
		knock = Vector2.ZERO

func _tick_statuses(delta: float) -> void:
	var curse_contributed:=false
	for key in statuses.keys():
		var st: Dictionary = statuses[key]
		st["left"] = float(st.get("left", 0.0)) - delta
		if key == "burn":
			dot_accum += float(st.get("dps", 0.0)) * float(st.get("stacks", 1)) * delta
		elif key == "poison":
			dot_accum += float(st.get("dps", 0.0)) * float(st.get("stacks", 1)) * delta
		elif key == "curse":
			dot_accum += float(st.get("dps", 0.0)) * delta
			curse_contributed=true
		if float(st["left"]) <= 0.0:
			statuses.erase(key)
	if dot_accum >= 1.0:
		var whole := int(dot_accum)
		dot_accum -= float(whole)
		game.damage_enemy(self, float(whole), {"source": "curse_dot" if curse_contributed else "dot", "silent": true})
	if has_status("freeze"):
		return

func has_status(key: String) -> bool:
	return statuses.has(key)

func is_frozen() -> bool:
	return has_status("freeze")

func add_status(key: String, dur: float, params: Dictionary = {}) -> void:
	var st: Dictionary = statuses.get(key, {})
	st["left"] = maxf(float(st.get("left", 0.0)), dur)
	for k in params.keys():
		st[k] = params[k]
	if key == "poison":
		st["stacks"] = mini(int(st.get("stacks", 0)) + 1, int(DB.balance["player"].get("poison_max_stacks", 3)))
	if key == "burn":
		st["stacks"] = mini(int(st.get("stacks", 0)) + 1, int(DB.balance["player"].get("burn_max_stacks", 5)))
	statuses[key] = st
	if key == "freeze":
		if sprite:
			sprite.modulate = Color(0.55, 0.8, 1.2)

func slow_factor() -> float:
	var f := 1.0
	if has_status("slow"):
		f *= 1.0 - float(statuses["slow"].get("amount", 0.5))
	if has_status("freeze"):
		f *= 0.0
	return f

# ------------------------------------------------------------------ ОБЫЧНЫЕ ВРАГИ
func _normal_tick(delta: float) -> void:
	var player_pos: Vector2 = game.player.global_position
	var to_player := player_pos - global_position
	var dir := to_player.normalized() if to_player.length() > 0.1 else Vector2.RIGHT
	var kind := String(behavior.get("kind", "chase"))
	var spd := speed * slow_factor() * GameManager.cheat_enemy_speed
	var move_dir := dir
	match kind:
		"fly":
			move_dir = dir
		"orbit":
			# кружит вокруг игрока на радиусе orbit, при сближении отлетает
			orbit_angle += delta * 2.0
			var orbit_r := float(behavior.get("orbit", 128.0))
			if to_player.length() < orbit_r * 0.7:
				orbit_angle += delta * 3.0
			var target_pos: Vector2 = player_pos + Vector2.RIGHT.rotated(orbit_angle) * orbit_r
			move_dir = (target_pos - global_position).normalized()
			spd = speed * GameManager.cheat_enemy_speed
		"jump":
			jump_cd -= delta
			if jump_cd <= 0.0:
				jump_cd = float(behavior.get("jump_interval", 1.5))
				knock = dir * spd * 2.2
			spd *= 0.5
		"shooter":
			var keep := float(behavior.get("keep", 170.0))
			if to_player.length() < keep - 20.0:
				move_dir = -dir
			elif to_player.length() < keep + 20.0:
				move_dir = dir.orthogonal()
			_attack_projectile(delta)
		"charger":
			charge_timer -= delta
			if charging:
				move_dir = charge_dir
				spd = float(behavior.get("charge_speed", 220.0))
				if charge_timer <= 0.0:
					charging = false
					charge_timer = float(behavior.get("interval", 3.0))
			elif charge_timer <= 0.0:
				charging = true
				charge_dir = dir
				charge_timer = 0.6
		"summoner":
			summon_cd -= delta
			if summon_cd <= 0.0:
				summon_cd = float(behavior.get("interval", 5.0))
				for i in int(behavior.get("count", 2)):
					var off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, 50.0)
					game.spawn_enemy(String(behavior.get("summon", "")), global_position + off)
			_attack_projectile(delta)
	# --- бюджет производительности: тяжёлые проверки способностей идут
	# не каждый кадр, а 1/3 кадров (со сдвигом по врагам), дельта компенсируется.
	if (Engine.get_process_frames() + tick_phase) % 3 != 0:
		return
	delta *= 3.0
	# элитные способности
	if behavior.has("slam"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["slam"].get("interval", 4.0))
			game.spawn_delayed_aoe(player_pos, float(behavior["slam"].get("radius", 64.0)), float(damage), 0.6, Color(1, 0.4, 0.3))
	if behavior.has("shoot") and kind != "shooter":
		_attack_projectile_custom(delta, behavior["shoot"])
	if behavior.has("slow_zone"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["slow_zone"].get("interval", 5.0))
			game.spawn_hazard_zone(player_pos, 0.0, float(behavior["slow_zone"].get("duration", 3.0)), float(behavior["slow_zone"].get("radius", 56.0)), Color(0.4, 0.7, 0.4), true)
			game.player.add_status("slow", float(behavior["slow_zone"].get("duration", 3.0)), {"amount": float(behavior["slow_zone"].get("slow", 0.8))})
	if behavior.has("pull"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["pull"].get("interval", 4.0))
			if to_player.length() < float(behavior["pull"].get("radius", 140.0)):
				game.player.global_position += -dir * float(behavior["pull"].get("force", 90.0)) * 0.15
	if behavior.has("cone"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["cone"].get("interval", 4.0))
			if to_player.length() < float(behavior["cone"].get("radius", 130.0)):
				game.damage_player(int(behavior["cone"].get("damage", 3)), global_position)
	if behavior.has("beam"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["beam"].get("interval", 3.0))
			game.spawn_beam(global_position, dir, float(behavior["beam"].get("length", 260.0)), int(behavior["beam"].get("damage", 3)))
	if behavior.has("shout"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["shout"].get("interval", 6.0))
			if to_player.length() < float(behavior["shout"].get("radius", 140.0)):
				game.player.add_status("stun", float(behavior["shout"].get("stun", 2.0)))
				game.spawn_fx(global_position, Color(0.8, 0.8, 1.0), float(behavior["shout"].get("radius", 140.0)), 0.4)
	if behavior.has("debuff"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["debuff"].get("interval", 8.0))
			var pick := randi() % 3
			if pick == 0:
				game.player.add_status("slow", float(behavior["debuff"].get("duration", 10.0)), {"amount": 0.5})
			elif pick == 1:
				game.player.add_status("curse", float(behavior["debuff"].get("duration", 10.0)), {})
			else:
				game.player.add_status("poison", float(behavior["debuff"].get("duration", 10.0)), {"dps": 1.0})
	if behavior.has("charm"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["charm"].get("interval", 10.0))
			game.player.add_status("charm", float(behavior["charm"].get("duration", 3.0)))
	if behavior.has("dive"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["dive"].get("interval", 4.0))
			knock = (player_pos - global_position).normalized() * 280.0
			game.spawn_fx(global_position, Color(0.8, 0.9, 1.0), 24.0, 0.2)
	if behavior.has("aoe"):
		attack_cd -= delta
		if attack_cd <= 0.0:
			attack_cd = float(behavior["aoe"].get("interval", 3.5))
			game.spawn_delayed_aoe(player_pos, float(behavior["aoe"].get("radius", 64.0)), float(damage), 0.7, Color(0.7, 0.4, 1.0))
	# движение
	var step: float = spd
	global_position += move_dir * step * delta
	if not bool(kind == "fly") and not _ignore_obstacles():
		game.push_out_of_obstacles(self, radius)

func _ignore_obstacles() -> bool:
	return flags.has("ghost") or role == "miniboss" or role == "boss"

func _attack_projectile(delta: float) -> void:
	_attack_projectile_custom(delta, behavior.get("proj", {}))

func _attack_projectile_custom(delta: float, proj: Dictionary) -> void:
	if proj.is_empty():
		return
	attack_cd -= delta
	if attack_cd > 0.0:
		return
	attack_cd = float(proj.get("interval", 2.0))
	var count := int(proj.get("count", 1))
	var to_player: Vector2 = (game.player.global_position - global_position).normalized()
	for i in count:
		var spread := 0.0
		if count > 1:
			spread = (float(i) / float(count - 1) - 0.5) * 0.5
		var dir := to_player.rotated(spread)
		game.spawn_enemy_bullet(global_position, dir, int(proj.get("damage", 1)), {
			"speed": float(proj.get("speed", 170.0)),
			"color": color.lerp(Color.WHITE, 0.35),
			"poison_stacks": int(proj.get("poison_stacks", 0)),
		})

func _try_contact_damage() -> void:
	if game.coop_player != null and game.coop_player.active and global_position.distance_to(game.coop_player.global_position) < radius + 8.0:
		game.coop_player.take_damage(damage,global_position)
	var p: Node2D = game.player
	if p == null or p.dead:
		return
	# «Неудержимый»: во время берсерка контактный урон не проходит
	if float(p.berserk_left) > 0.0 and bool(p.upg.flag_on("berserk_immune")):
		return
	if global_position.distance_to(p.global_position) < radius + 8.0:
		var dmg := damage
		if flags.has("burn_on_hit"):
			p.add_status("burn", 3.0, {"dps": float(flags["burn_on_hit"])})
		if flags.has("poison"):
			p.add_status("poison", float(flags["poison"].get("dur", 4.0)), {"dps": float(flags["poison"].get("dps", 3.0))})
		if flags.has("freeze_on_hit"):
			p.add_status("slow", float(flags["freeze_on_hit"]), {"amount": 0.5})
		if flags.has("steal_ammo"):
			game.player.mag = maxi(0, game.player.mag - 1)
			EventBus.ammo_changed.emit(game.player.mag, int(game.player.S.mag), false)
		if flags.has("push_on_hit"):
			p.global_position += (p.global_position - global_position).normalized() * float(flags["push_on_hit"]) * 0.2
		game.damage_player(dmg, global_position)
		# отталкивание врага от игрока
		knock = (global_position - p.global_position).normalized() * 120.0

# ------------------------------------------------------------------ БОСС
func _phase_patterns() -> Array:
	var phases: Array = boss_def.get("phases", [])
	if phases.is_empty():
		return []
	var idx := mini(phase, phases.size() - 1)
	return phases[idx].get("patterns", [])

func _boss_tick(delta: float) -> void:
	if transition_left > 0.0:
		transition_left -= delta
		_update_boss_bar()
		return
	var phases: Array = boss_def.get("phases", [])
	if phases.is_empty():
		return
	# выбор фазы по проценту HP
	var ratio := hp / maxf(1.0, max_hp)
	var target_phase := 0
	for i in phases.size():
		if ratio <= float(phases[i].get("at", 1.0)):
			target_phase = i
	if target_phase != phase:
		var become_mega := bool(phases[target_phase].get("mega", false))
		phase = target_phase
		transition_left = (12.0 if become_mega else (6.0 if target_phase>=2 else 5.0)) if GameManager.setting("slowmo",true) else 0.0
		game.boss_phase_transition(self, phase + 1, become_mega)
		if become_mega:
			game.megaphase = true
			radius = float(boss_def.get("radius", 48.0)) * 1.33
			_setup_visual()
			game.notify("МЕГАФАЗА: САТАН")
			game.shake(12.0)
			game.flash_screen(Color(1, 0.1, 0.1))
		pattern_timers.clear()
		for p in _phase_patterns():
			pattern_timers.append(float(p.get("interval", 2.0)) * 0.5)
		game.shake(5.0)
		game.spawn_fx(global_position, color, radius * 2.0, 0.5)
		if sprite:
			sprite.modulate = _base_modulate()
	var player_pos: Vector2 = game.player.global_position
	var to_player := (player_pos - global_position)
	var dir := to_player.normalized() if to_player.length() > 0.1 else Vector2.RIGHT
	var boss_rate_mult := float(game.diff_mods.get("boss_rate", 0.0))
	var phase_cfg: Dictionary = phases[mini(phase, phases.size() - 1)]
	var spd := speed * slow_factor() * float(phase_cfg.get("speed_mult", 1.0)) * GameManager.cheat_enemy_speed
	if float(phase_cfg.get("regen", 0.0)) > 0.0:
		hp = minf(max_hp, hp + float(phase_cfg["regen"]) * delta)
	# Телеграфированный рывок босса: сначала 0.42s замах, затем рывок с проверкой контакта
	if charge_timer > 0.0:
		charge_timer -= delta
		if charge_timer <= 0.0:
			knock = charge_dir * float(behavior.get("dash_speed", 310.0))
			knock_timer = 0.42
			game.spawn_fx(global_position, color.lightened(0.3), radius * 1.4, 0.25)
	else:
		var move_v := dir
		if to_player.length() < 115.0:
			move_v = (dir * 0.45 + dir.orthogonal() * sin(walk_phase * 0.4) * 0.75).normalized()
		global_position += move_v * spd * delta
	game.push_out_of_obstacles(self, radius)
	var patterns := _phase_patterns()
	while pattern_timers.size() < patterns.size():
		pattern_timers.append(1.0)
	for i in patterns.size():
		var p: Dictionary = patterns[i]
		pattern_timers[i] = float(pattern_timers[i]) - delta * (1.0 + boss_rate_mult)
		if float(pattern_timers[i]) <= 0.0:
			pattern_timers[i] = float(p.get("interval", 2.0))
			_exec_pattern(p)
	_update_boss_bar()

func _update_boss_bar() -> void:
	EventBus.boss_damaged.emit(maxf(hp, 0.0), max_hp)

func _exec_pattern(p: Dictionary) -> void:
	attack_anim = 0.42
	var kind := String(p.get("type", ""))
	var pr: Dictionary = p.get("params", {})
	var player_pos: Vector2 = game.player.global_position
	var dir := (player_pos - global_position).normalized()
	var vivid := Color("#ffd55a") if id == "boss_satanail" else (Color("#ff3a6e") if id == "boss_satan" else color.lightened(0.35))
	match kind:
		"fireball", "holy_light":
			# веер снарядов (Огненный Шар / Святой Свет)
			var cnt := int(pr.get("count", 1))
			var spread_total := deg_to_rad(float(pr.get("spread", 0.0)))
			for i in cnt:
				var off := 0.0 if cnt <= 1 else (float(i) / float(cnt - 1) - 0.5) * spread_total
				var col := Color("#ff5522") if kind == "fireball" else Color("#ffe699")
				game.spawn_enemy_bullet(global_position, dir.rotated(off), int(pr.get("damage", 5)), {
					"speed": float(pr.get("speed", 200.0)), "color": col, "size": float(pr.get("size", 32.0)),
					"life": float(pr.get("life", 4.0)), "burn": kind == "fireball"})
			game.spawn_perk_fx("fireball" if kind == "fireball" else "smite", global_position + dir * (radius * 0.8), 36.0, 0.25)
		"chain_slam":
			# Телеграфированный Цепной Удар (0.35s предупреждение -> удар + замедление)
			var r1 := float(pr.get("radius", 128.0))
			game.spawn_fx(global_position, Color(0.85, 0.45, 0.35), r1, 0.4, false)
			var slam_dmg := int(pr.get("damage", 5))
			var slam_slow := float(pr.get("slow", 0.5))
			var slam_dur := float(pr.get("slow_dur", 2.0))
			game.run_later(0.35, func() -> void:
				if not active or dead or game == null or game.player == null:
					return
				game.spawn_fx(global_position, Color(0.65, 0.65, 0.72), r1, 0.3)
				if game.player.global_position.distance_to(global_position) < r1:
					if not game.start_dodge_qte(slam_dmg, global_position, self):
						game.damage_player(slam_dmg, global_position)
					game.player.add_status("slow", slam_dur, {"amount": slam_slow}))
		"dark_chains":
			# Тёмные Цепи с чётким телеграфом
			var r2 := float(pr.get("radius", 192.0))
			game.spawn_fx(global_position, Color(0.75, 0.2, 0.65), r2, 0.45, false)
			var dc_dmg := int(pr.get("damage", 7))
			var dc_root := float(pr.get("root", 1.5))
			game.run_later(0.4, func() -> void:
				if not active or dead or game == null or game.player == null:
					return
				game.spawn_perk_fx("smite", global_position, r2 * 0.5, 0.32)
				if game.player.global_position.distance_to(global_position) < r2:
					if not game.start_dodge_qte(dc_dmg, global_position, self):
						game.damage_player(dc_dmg, global_position)
					game.player.add_status("stun", dc_root))
		"storm_aura":
			# Огненный/Тёмный Шторм: зона вокруг босса
			game.spawn_hazard_zone(global_position, float(pr.get("dps", 3.0)), float(pr.get("duration", 5.0)),
				float(pr.get("radius", 128.0)), Color(String(pr.get("color", "#ff4500"))), {})
			game.notify("Шторм!")
		"ring":
			var count := int(pr.get("count", 12))
			for i in count:
				var a := TAU * float(i) / float(count)
				game.spawn_enemy_bullet(global_position, Vector2.RIGHT.rotated(a), int(pr.get("damage", 8)), {
					"speed": float(pr.get("speed", 160.0)), "color": vivid,
					"burn": bool(pr.get("burn", false)), "poison": bool(pr.get("poison", false)),
				})
		"aim":
			var count2 := int(pr.get("count", 3))
			for i in count2:
				var spread := deg_to_rad(float(pr.get("spread", 20.0))) * (float(i) / maxf(1.0, float(count2 - 1)) - 0.5)
				game.spawn_enemy_bullet(global_position, dir.rotated(spread), int(pr.get("damage", 8)), {"speed": float(pr.get("speed", 200.0)), "color": vivid})
		"spiral":
			var count3 := int(pr.get("count", 24))
			var base_angle := float(pattern_angles.get("spiral", 0.0))
			pattern_angles["spiral"] = base_angle + 0.7
			for i in count3:
				var a2 := base_angle + TAU * float(i) / float(count3)
				game.spawn_enemy_bullet(global_position, Vector2.RIGHT.rotated(a2), int(pr.get("damage", 8)), {"speed": float(pr.get("speed", 150.0)), "color": vivid, "burn": bool(pr.get("burn", false))})
		"summon":
			for i in int(pr.get("count", 3)):
				var off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(36.0, 86.0)
				game.spawn_enemy(String(pr.get("enemy", "")), global_position + off)
		"aoe":
			game.spawn_delayed_aoe(player_pos, float(pr.get("radius", 90.0)), float(pr.get("damage", 12)), float(pr.get("delay", 1.2)), vivid, float(pr.get("dot", 0.0)))
		"dash":
			# Телеграф рывка вместо мгновенного удара через весь экран
			charge_dir = dir
			charge_timer = 0.42
			behavior["dash_speed"] = float(pr.get("speed", 320.0))
			game.spawn_fx(global_position + dir * 28.0, vivid, radius * 1.3, 0.42)
		"lightning":
			game.lightning_volley(player_pos, int(pr.get("count", 3)), float(pr.get("damage", 20)), float(pr.get("radius", 48.0)))
		"meteor":
			for i in int(pr.get("count", 5)):
				var pos := player_pos + Vector2(randf_range(-140, 140), randf_range(-140, 140))
				game.spawn_delayed_aoe(pos, float(pr.get("radius", 56.0)), float(pr.get("damage", 14)), 1.0, Color(1, 0.5, 0.2))
				game.spawn_event_fx("meteor", pos, 1.0, 1.6, float(pr.get("radius", 56.0)))
		"spikes":
			for i in int(pr.get("count", 5)):
				var pos2: Vector2 = player_pos + Vector2(randf_range(-90, 90), randf_range(-90, 90)) if i > 0 else player_pos
				game.spawn_delayed_aoe(pos2, float(pr.get("radius", 40.0)), float(pr.get("damage", 10)), 1.2, Color(0.8, 0.5, 1.0))
				game.spawn_event_fx("ice_spikes", pos2, 1.2, 1.8, float(pr.get("radius", 40.0)))
		"teleport":
			game.spawn_fx(global_position, vivid, radius * 1.4, 0.25)
			global_position = game.clamp_to_map(player_pos + Vector2.RIGHT.rotated(randf() * TAU) * 120.0)
			game.spawn_fx(global_position, vivid, radius * 1.5, 0.3)
		"pull":
			var d := player_pos - global_position
			if d.length() < float(pr.get("radius", 220.0)):
				game.player.global_position -= d.normalized() * float(pr.get("force", 140.0)) * 0.2
		"pillar":
			for i in int(pr.get("count", 4)):
				var pos3 := player_pos + Vector2(randf_range(-120, 120), randf_range(-120, 120))
				game.spawn_delayed_aoe(pos3, float(pr.get("radius", 48.0)), float(pr.get("damage", 5)), 0.9, Color(1, 0.6, 0.2))
				game.spawn_perk_fx("fireball", pos3, float(pr.get("radius", 48.0)), 0.35)
		"cone":
			game.spawn_fx(global_position + dir * 40.0, Color(1, 0.65, 0.25), float(pr.get("radius", 110.0)), 0.35)
			var cone_r := float(pr.get("radius", 110.0))
			var cone_ang := float(pr.get("angle", 70.0)) * 0.5
			var cone_dmg := int(pr.get("damage", 15))
			game.run_later(0.32, func() -> void:
				if not active or dead or game == null or game.player == null:
					return
				if game.player.global_position.distance_to(global_position) < cone_r:
					var angle_ok := absf(rad_to_deg(dir.angle_to(global_position.direction_to(game.player.global_position)))) < cone_ang
					if angle_ok:
						game.damage_player(cone_dmg, global_position))
		"pentagram":
			for i in int(pr.get("count", 3)):
				var pos4: Vector2 = player_pos if bool(pr.get("under_player", false)) else player_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))
				game.spawn_delayed_aoe(pos4, float(pr.get("radius", 48.0)), float(pr.get("damage", 8)), 1.0, Color(1, 0.2, 0.1))
		"scythe":
			var count4 := int(pr.get("count", 5))
			for i in count4:
				var a3 := deg_to_rad(float(i) * 20.0 - 40.0)
				game.spawn_enemy_bullet(global_position, dir.rotated(a3), int(pr.get("damage", 10)), {"speed": 190.0, "color": Color(1, 0.4, 0.2), "burn": true})
		"wing":
			for i in int(pr.get("count", 3)):
				var a4 := TAU * float(i) / 3.0 + randf() * TAU
				game.spawn_enemy_bullet(global_position, Vector2.RIGHT.rotated(a4), int(pr.get("damage", 12)), {"speed": 220.0, "color": Color(0.85, 0.35, 0.95), "homing": true})
		"gaze":
			if player_pos.distance_to(global_position) < float(pr.get("radius", 128.0)):
				game.player.add_status("curse", float(pr.get("duration", 6.0)), {})
				game.spawn_fx(global_position + dir * 40.0, Color(0.75, 0.25, 0.85), 60.0, 0.4)
		"seal":
			game.spawn_delayed_aoe(player_pos, float(pr.get("radius", 96.0)), float(pr.get("damage", 15)), 3.0, Color(0.7, 0.15, 0.45), float(pr.get("pool_dps", 6.0)))
		"apocalypse":
			game.apocalypse(float(pr.get("damage", 12)))
		"heal":
			hp = minf(max_hp, hp + float(pr.get("amount", 40.0)))
		"mirror":
			for i in int(pr.get("count", 2)):
				game.spawn_enemy("crystal_spider", global_position + Vector2.RIGHT.rotated(randf() * TAU) * 60.0)
		"beam":
			var b_len := float(pr.get("length", 260.0))
			var b_dmg := int(pr.get("damage", 3))
			game.spawn_fx(global_position + dir * (b_len * 0.45), vivid, 28.0, 0.45)
			game.run_later(0.45, func() -> void:
				if active and not dead and game != null:
					game.spawn_beam(global_position, dir, b_len, b_dmg))

# ------------------------------------------------------------------ УРОН ВРАГУ
func take_damage(amount: float, opts: Dictionary = {}) -> void:
	if dead or not active:
		return
	if has_status("freeze") and float(game.player.upg.flag_num("frozen_vuln")) > 0.0:
		amount *= 1.0 + float(game.player.upg.flag_num("frozen_vuln"))
	if flags.has("reflect") and String(opts.get("source", "")) != "dot":
		game.damage_player(int(float(amount) * float(flags["reflect"])), global_position)
	var armor := float(data.get("armor", 0.0))
	# «Бронебойные Пули»: половина брони игнорируется
	if game != null and game.player != null and game.player.upg.flag_num("armor_pierce") > 0.0:
		armor *= 0.5
	if armor > 0.0:
		amount *= (1.0 - clampf(armor, 0.0, 0.9))
	var src := String(opts.get("source", "weapon"))
	var dmg_kind := "magic" if src in ["lightning", "curse", "chain", "smite", "holy"] else ("dot" if src == "dot" else "physical")
	var resist: Dictionary = data.get("resist", {})
	var red := float(resist.get("all", 0.0))
	if resist.has(dmg_kind):
		red = maxf(red, float(resist[dmg_kind]))
	if red > 0.0:
		amount *= (1.0 - clampf(red, 0.0, 0.9))
	# блок щитом (скелет 10%)
	if float(flags.get("block_chance", 0.0)) > 0.0 and randf() < float(flags["block_chance"]):
		game.spawn_fx(global_position, Color(0.96, 0.96, 0.86), radius * 1.4, 0.2)
		return
	# магический щит (тёмный маг: 15% отразить снаряд)
	if float(flags.get("shield_reflect", 0.0)) > 0.0 and randf() < float(flags["shield_reflect"]):
		game.spawn_fx(global_position, color, radius * 2.0, 0.25)
		var to_player: Vector2 = (game.player.global_position - global_position).normalized()
		game.spawn_enemy_bullet(global_position, to_player, int(maxf(1.0, amount)), {"speed": 120.0, "color": color})
		return
	hp -= amount
	last_source = String(opts.get("source", ""))
	hit_flash = 0.06
	if boss:
		hurt_anim = 0.28
	if sprite:
		sprite.modulate = Color(1.8, 1.8, 1.8)
	if float(opts.get("knockback", 0.0)) > 0.0 and not boss:
		var kd: Vector2 = opts.get("knock_dir", Vector2.RIGHT)
		knock = kd.normalized() * float(opts["knockback"])
		knock_timer = float(DB.balance.get("knockback_time", 0.15))
	# прок заморозки (взрыв/укус)
	if has_status("freeze") and hp <= 0.0:
		pass
	if hp <= 0.0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	if has_status("freeze") and float(game.player.upg.flag_num("frozen_explode")) > 0.0:
		game.queue_aoe(global_position, 48.0, float(game.player.upg.flag_num("frozen_explode")), {"source": "frozen_explode"})
		game.spawn_perk_fx("frost", global_position, 52.0, 0.30)
	if has_status("burn") and float(game.player.upg.flag_num("burn_explode"))>0.0:
		var burn: Dictionary=statuses["burn"]
		var total_burn:=float(burn.get("dps",0.0))*float(burn.get("left",0.0))*float(burn.get("stacks",1))
		var explosion_damage:=maxf(float(game.player.upg.flag_num("burn_explode")),total_burn)
		game.queue_aoe(global_position,48.0,explosion_damage,{"source":"burn_explode"}); game.spawn_fx(global_position,Color("#ff6a20"),48.0,0.2); game.spawn_perk_fx("fireball", global_position, 56.0, 0.32)
	if flags.has("explode"):
		var ex: Dictionary = flags["explode"]
		game.queue_aoe(global_position, float(ex.get("radius", 32.0)), float(ex.get("damage", 2)), {"source": "enemy_explode"})
		game.spawn_fx(global_position, color, float(ex.get("radius", 32.0)), 0.25)
	if flags.has("shards_on_death"):
		var sh: Dictionary = flags["shards_on_death"]
		game.shard_burst(global_position, int(sh.get("count", 6)), float(sh.get("damage", 2)))
	if flags.has("death_spawn"):
		var ds: Dictionary = flags["death_spawn"]
		for i in int(ds.get("count", 2)):
			game.spawn_enemy(String(ds.get("enemy", "")), global_position + Vector2.RIGHT.rotated(randf() * TAU) * 20.0)
	# разделение слизня
	if float(flags.get("split_chance", 0.0)) > 0.0 and randf() < float(flags["split_chance"]):
		var child_id := String(flags.get("split_enemy", ""))
		for i in int(flags.get("split_count", 2)):
			game.spawn_enemy(child_id, global_position + Vector2.RIGHT.rotated(randf() * TAU) * 10.0)
	# ледяная лужа после смерти
	if float(flags.get("ice_puddle_radius", 0.0)) > 0.0:
		game.spawn_hazard_zone(global_position, 0.0, float(flags.get("ice_puddle_dur", 3.0)),
			float(flags.get("ice_puddle_radius", 32.0)), Color(0.65, 0.85, 1.0), {"slow": float(flags.get("ice_puddle_slow", 0.3))})
	if boss and game != null and game.world != null:
		_spawn_boss_death_anim(visual_class(), global_position, sprite.scale if sprite != null else Vector2.ONE)
	game.on_enemy_death(self)
	deactivate()

func _spawn_boss_death_anim(vcls: String, pos: Vector2, sc: Vector2) -> void:
	var fr := Assets.frames(vcls, "death")
	if fr.is_empty():
		return
	var holder := Node2D.new()
	holder.global_position = pos
	holder.z_index = 8
	var sp := Sprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = sc
	sp.texture = fr[0]
	holder.add_child(sp)
	game.world.add_child(holder)
	for i in fr.size():
		var idx := i
		game.run_later(float(idx) * 0.14, func() -> void:
			if is_instance_valid(sp):
				sp.texture = fr[idx])
	game.run_later(float(fr.size()) * 0.14 + 0.15, func() -> void:
		if is_instance_valid(holder):
			holder.queue_free())
