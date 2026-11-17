class_name Mover
extends Node2D
## Подвижное препятствие-угроза: перекати-поле, блуждающий огонёк, рой насекомых,
## ледяные осколки. Двигается, наносит урон при касании и исчезает по времени.

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
var spin := 0.0

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
	_build()

func _build() -> void:
	if body != null and is_instance_valid(body):
		body.queue_free()
	body = Node2D.new()
	add_child(body)
	match kind:
		"tumbleweed":
			for i in 3:
				var s := Gfx.square(body, Vector2(radius * 1.6, 2), color, Vector2(0, -radius * 0.5 + float(i) * radius * 0.5))
				s.rotation = float(i) * 0.7
			Gfx.square(body, Vector2(radius * 1.9, radius * 1.9), Color(color.r, color.g, color.b, 0.25))
		"wisp":
			Gfx.square(body, Vector2(radius * 3.4, radius * 3.4), Color(0.45, 0.95, 0.55, 0.13))
			Gfx.square(body, Vector2(radius, radius), Color(0.72, 1.0, 0.75, 0.95))
		"insects":
			for i in 6:
				var ang := TAU * float(i) / 6.0
				Gfx.square(body, Vector2(2, 2), color, Vector2(cos(ang), sin(ang)) * radius * 0.8)
		"shard":
			var p := Polygon2D.new()
			p.polygon = PackedVector2Array([Vector2(-radius * 0.5, radius * 0.6), Vector2(radius * 0.5, radius * 0.6), Vector2(0, -radius * 0.9)])
			p.color = color
			body.add_child(p)
		_:
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
	if body != null:
		if kind == "tumbleweed":
			spin += delta * 6.0 * signf(vel.x if absf(vel.x) > 1.0 else 1.0)
			body.rotation = spin
		elif kind == "wisp":
			body.modulate.a = 0.7 + 0.3 * sin(life * 5.0)
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
