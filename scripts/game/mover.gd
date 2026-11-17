class_name Mover
extends Node2D
## Подвижное препятствие-угроза: перекати-поле, блуждающий огонёк, рой насекомых,
## ледяные осколки. Двигается с покадровым пиксель-арт визуалом и следом.

var game: Node = null
var kind := "tumbleweed"
var vel := Vector2.ZERO
var life := 5.0
var max_life := 5.0
var radius := 12.0
var damage := 3.0
var dot := 0.0
var chase := 0.0
var hit_cd := 0.0
var color := Color(0.6, 0.45, 0.2)
var active := false
var body: Node2D = null
var sprite: Sprite2D = null
var shadow: Sprite2D = null
var spin := 0.0
var bounce_t := 0.0
var dust_cd := 0.0

func setup(g: Node, kind_name: String, pos: Vector2, v: Vector2, opts: Dictionary = {}) -> void:
	game = g
	kind = kind_name
	global_position = pos
	vel = v
	life = float(opts.get("life", 5.0))
	max_life = life
	radius = float(opts.get("radius", 12.0))
	damage = float(opts.get("damage", 2.0))
	dot = float(opts.get("dot", 0.0))
	chase = float(opts.get("chase", 0.0))
	color = opts.get("color", Color(0.6, 0.45, 0.2))
	active = true
	visible = true
	hit_cd = 0.0
	spin = 0.0
	bounce_t = randf() * TAU
	dust_cd = 0.1
	_build()

func _build() -> void:
	if body != null and is_instance_valid(body):
		body.queue_free()
	if shadow != null and is_instance_valid(shadow):
		shadow.queue_free()
	shadow = Sprite2D.new()
	shadow.centered = true
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.texture = Assets.tex("fx_burst", Color(0.05, 0.04, 0.03, 0.42))
	shadow.scale = Vector2(radius * 1.3 / 16.0, radius * 0.55 / 16.0)
	shadow.position = Vector2(0, radius * 0.65)
	shadow.modulate = Color(0.05, 0.04, 0.03, 0.42)
	add_child(shadow)

	body = Node2D.new()
	add_child(body)
	var spr_name := "mover_" + kind
	var tex: Texture2D = Assets.icon(spr_name)
	if tex != null:
		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var target_px: float = maxf(20.0, radius * 2.15)
		var w: float = float(maxi(1, tex.get_width()))
		sprite.scale = Vector2(target_px / w, target_px / w)
		body.add_child(sprite)
	else:
		Gfx.square(body, Vector2(radius * 1.6, radius * 1.6), color)

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	life -= delta
	if life <= 0.0:
		if game != null:
			game.spawn_fx(global_position, Color(color.r, color.g, color.b, 0.6), radius * 2.0, 0.25)
		deactivate()
		return
	if chase > 0.0 and game != null and game.player != null and not game.player.dead:
		var want: Vector2 = (game.player.global_position - global_position).normalized() * vel.length()
		vel = vel.lerp(want * chase, clampf(delta * 1.5, 0.0, 1.0))
	global_position += vel * delta
	bounce_t += delta * 7.5
	if body != null:
		if kind == "tumbleweed":
			var spd_sign: float = signf(vel.x) if absf(vel.x) > 1.0 else 1.0
			spin += delta * 7.2 * spd_sign
			body.rotation = spin
			var hop: float = absf(sin(bounce_t)) * 5.0
			body.position = Vector2(0, -hop)
			if shadow != null:
				var sscale: float = clampf(1.0 - hop * 0.06, 0.65, 1.0)
				shadow.scale = Vector2(radius * 1.3 / 16.0 * sscale, radius * 0.55 / 16.0 * sscale)
			dust_cd -= delta
			if dust_cd <= 0.0 and game != null:
				dust_cd = 0.22
				game.spawn_fx(global_position + Vector2(0, radius * 0.45), Color(0.68, 0.56, 0.36, 0.42), 14.0, 0.32, true)
		elif kind == "wisp":
			body.modulate.a = 0.72 + 0.28 * sin(life * 5.5)
			body.position = Vector2(0, sin(bounce_t * 0.8) * 3.0)
		elif kind == "insects":
			body.rotation += delta * 2.4
			body.position = Vector2(cos(bounce_t * 1.8) * 2.0, sin(bounce_t * 2.2) * 2.0)
	# границы карты: отражаемся
	if game != null:
		var r: Rect2 = game.map_rect
		if global_position.x < r.position.x + radius:
			vel.x = absf(vel.x)
		elif global_position.x > r.end.x - radius:
			vel.x = -absf(vel.x)
		if global_position.y < r.position.y + radius:
			vel.y = absf(vel.y)
		elif global_position.y > r.end.y - radius:
			vel.y = -absf(vel.y)
		_touch(delta)

func _touch(delta: float) -> void:
	hit_cd = maxf(0.0, hit_cd - delta)
	if game.player == null or game.player.dead:
		return
	var d: float = global_position.distance_to(game.player.global_position)
	if d > radius + 8.0 or hit_cd > 0.0:
		return
	hit_cd = 0.5
	if damage > 0.0:
		game.damage_player(int(damage), global_position)
	if dot > 0.0:
		game.player.add_status("poison", 3.0, {"dps": dot})
