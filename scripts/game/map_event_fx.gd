class_name MapEventFx
extends Node2D
## Анимированные визуалы событий карты: падающие метеориты (в стиле WorldBox),
## камнепады, сталактиты, ледяные шипы, лавина, гейзеры и призрачные руки.

var kind := "meteor"
var telegraph := 1.5
var duration := 2.0
var radius := 30.0
var elapsed := 0.0
var impacted := false
var sprite: Sprite2D = null
var shadow: Sprite2D = null
var crater: Sprite2D = null
var trail_cd := 0.0
var start_offset := Vector2(-190, -250)
var game: Node = null

func setup(g: Node, ev_kind: String, pos: Vector2, tele: float, rad: float, extra: Dictionary = {}) -> void:
	game = g
	kind = ev_kind
	global_position = pos
	telegraph = maxf(0.15, tele)
	radius = rad
	elapsed = 0.0
	impacted = false
	z_index = 6

	shadow = Sprite2D.new()
	shadow.centered = true
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.texture = Assets.tex("fx_burst", Color(0.03, 0.03, 0.04, 0.55))
	shadow.modulate = Color(0.03, 0.03, 0.04, 0.25)
	shadow.z_index = -3
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	match kind:
		"meteor":
			duration = telegraph + 2.8
			start_offset = Vector2(-190.0, -255.0)
			sprite.texture = Assets.icon("event_meteor_0")
			sprite.scale = Vector2(maxf(1.2, radius / 18.0), maxf(1.2, radius / 18.0))
			sprite.position = start_offset
		"boulder":
			duration = telegraph + 0.9
			start_offset = Vector2(randf_range(-24.0, 24.0), -200.0)
			sprite.texture = Assets.icon("event_boulder_0")
			sprite.scale = Vector2(maxf(1.0, radius / 20.0), maxf(1.0, radius / 20.0))
			sprite.position = start_offset
		"stalactite":
			duration = telegraph + 0.7
			start_offset = Vector2(0.0, -185.0)
			sprite.texture = Assets.icon("event_stalactite")
			sprite.scale = Vector2(1.2, 1.3)
			sprite.position = start_offset
		"ice_spike":
			duration = telegraph + 1.1
			sprite.texture = Assets.icon("event_ice_spike_0")
			sprite.position = Vector2(0, -4)
			sprite.modulate.a = 0.25
		"avalanche":
			duration = telegraph + 1.4
			start_offset = Vector2(0.0, -120.0)
			sprite.texture = Assets.icon("event_avalanche_wave")
			var sc := maxf(1.4, radius / 26.0)
			sprite.scale = Vector2(sc, sc * 0.9)
			sprite.position = start_offset
		"geyser":
			duration = telegraph + 1.2
			sprite.texture = Assets.icon("event_geyser_0")
			sprite.position = Vector2(0, -6)
			sprite.modulate.a = 0.25
		"ghost_hand":
			duration = telegraph + float(extra.get("dur", 3.0))
			sprite.texture = Assets.icon("event_ghost_hand_0")
			sprite.position = Vector2(0, -6)
			sprite.modulate.a = 0.35
		_:
			duration = telegraph + 0.6

func _process(delta: float) -> void:
	elapsed += delta
	var k := clampf(elapsed / telegraph, 0.0, 1.0)
	var frame_idx := int(elapsed * 12.0)

	match kind:
		"meteor":
			if not impacted:
				# WorldBox-style ускоряющееся падение по диагонали + шлейф огня
				var fall_k := k * k
				sprite.position = start_offset.lerp(Vector2.ZERO, fall_k)
				sprite.texture = Assets.icon("event_meteor_%d" % (frame_idx % 4))
				shadow.scale = Vector2.ONE * (radius * (0.25 + 0.85 * k) / 16.0)
				shadow.modulate = Color(0.03, 0.02, 0.02, 0.18 + 0.38 * k)
				trail_cd -= delta
				if trail_cd <= 0.0 and game != null:
					trail_cd = 0.045
					game.spawn_fx(global_position + sprite.position - Vector2(6, 6), Color(1.0, 0.55, 0.15, 0.75), 14.0, 0.22, true)
				if k >= 1.0:
					_on_impact()
			else:
				var after := elapsed - telegraph
				if crater != null:
					crater.modulate.a = clampf(1.0 - (after / 2.8), 0.0, 0.92)
		"boulder", "stalactite":
			if not impacted:
				var fall_b := k * k
				sprite.position = start_offset.lerp(Vector2.ZERO, fall_b)
				if kind == "boulder":
					sprite.rotation += delta * 6.0
					sprite.texture = Assets.icon("event_boulder_%d" % ((frame_idx / 2) % 2))
				shadow.scale = Vector2.ONE * (radius * (0.3 + 0.7 * k) / 16.0)
				shadow.modulate = Color(0.03, 0.03, 0.04, 0.15 + 0.32 * k)
				if k >= 1.0:
					_on_impact()
			else:
				var after_b := elapsed - telegraph
				sprite.modulate.a = clampf(1.0 - after_b / 0.8, 0.0, 1.0)
				shadow.modulate.a = sprite.modulate.a * 0.35
		"ice_spike":
			if not impacted:
				sprite.texture = Assets.icon("event_ice_spike_0")
				sprite.modulate.a = 0.2 + 0.45 * k
				shadow.scale = Vector2.ONE * (radius * 0.8 / 16.0)
				if k >= 1.0:
					_on_impact()
			else:
				var after_i := elapsed - telegraph
				var sp_f := mini(2, int(after_i * 10.0))
				sprite.texture = Assets.icon("event_ice_spike_%d" % sp_f)
				sprite.modulate.a = clampf(1.0 - maxf(0.0, after_i - 0.5) / 0.6, 0.0, 1.0)
		"avalanche":
			var sweep := clampf(elapsed / duration, 0.0, 1.0)
			sprite.position = Vector2(0, lerpf(-130.0, 160.0, sweep))
			sprite.modulate.a = sin(sweep * PI)
			shadow.visible = false
			trail_cd -= delta
			if trail_cd <= 0.0 and game != null:
				trail_cd = 0.07
				game.spawn_fx(global_position + sprite.position + Vector2(randf_range(-radius * 0.6, radius * 0.6), -10), Color(0.92, 0.96, 1.0, 0.6), 22.0, 0.35, true)
		"geyser":
			if not impacted:
				sprite.texture = Assets.icon("event_geyser_0")
				sprite.modulate.a = 0.25 + 0.5 * k
				if k >= 1.0:
					_on_impact()
			else:
				var after_g := elapsed - telegraph
				sprite.texture = Assets.icon("event_geyser_%d" % mini(2, int(after_g * 9.0)))
				sprite.modulate.a = clampf(1.0 - maxf(0.0, after_g - 0.5) / 0.7, 0.0, 1.0)
		"ghost_hand":
			if not impacted:
				sprite.texture = Assets.icon("event_ghost_hand_0")
				sprite.modulate.a = 0.25 + 0.45 * k
				if k >= 1.0:
					_on_impact()
			else:
				var after_h := elapsed - telegraph
				sprite.texture = Assets.icon("event_ghost_hand_%d" % mini(2, int(after_h * 8.0)))
				sprite.modulate.a = clampf(1.0 - maxf(0.0, after_h - 1.8) / 1.0, 0.0, 0.95)

	if elapsed >= duration:
		queue_free()

func _on_impact() -> void:
	impacted = true
	if kind == "meteor":
		sprite.visible = false
		shadow.visible = false
		crater = Sprite2D.new()
		crater.texture = Assets.icon("event_crater")
		crater.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		crater.scale = Vector2(maxf(1.0, radius / 20.0), maxf(1.0, radius / 20.0))
		crater.z_index = -4
		add_child(crater)
		if game != null:
			game.spawn_perk_fx("fireball", global_position, radius * 2.2)
			game.shake(7.0)
	elif kind == "boulder" or kind == "stalactite":
		shadow.modulate.a = 0.35
		if game != null:
			game.spawn_fx(global_position, Color(0.65, 0.60, 0.55, 0.75), radius * 1.9, 0.30, true)
			game.shake(4.5)
	elif kind == "ice_spike":
		sprite.modulate.a = 1.0
		if game != null:
			game.spawn_perk_fx("frost", global_position, radius * 2.0)
	elif kind == "geyser":
		sprite.modulate.a = 1.0
		if game != null:
			game.spawn_fx(global_position, Color(0.55, 0.95, 0.25, 0.75), radius * 1.8, 0.35)
	elif kind == "ghost_hand":
		sprite.modulate.a = 0.95
