class_name Pickup
extends Node2D
## Подбираемые предметы: опыт, золото, сердце, душа, сундук.

var game: Node = null
var kind := "xp"
var value := 1.0
var active := false
var vel := Vector2.ZERO
var sprite: Sprite2D = null
var color := Color.WHITE
var size := 5.0
var magnet := false
var age := 0.0

func setup(g: Node) -> void:
	game = g
	if sprite == null:
		sprite = Gfx.square(self, Vector2(size, size), color)

func spawn_at(pos: Vector2, k: String, val: float, c: Color, s: float = 5.0) -> void:
	kind = k
	value = val
	color = c
	size = s
	global_position = pos
	vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10.0, 40.0)
	active = true
	visible = true
	magnet = false
	age = 0.0
	var cls: String = String({"xp": ("pickup_xp_big" if value >= 5.0 else "pickup_xp"), "gold": "pickup_gold", "soul": "pickup_soul", "heart": "pickup_heart", "chest": "pickup_chest", "item": "pickup_item"}.get(kind, "pickup_xp"))
	var ptex := Assets.tex(cls, color)
	sprite.texture = ptex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color.WHITE
	var base_w := float(maxi(1, ptex.get_width()))
	var sc := maxf(0.42, (size * 1.45) / base_w) if kind == "xp" else maxf(0.55, (size * 2.1) / base_w)
	sprite.scale = Vector2(sc, sc)
	rotation = 0.0

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	age += delta
	global_position += vel * delta
	vel = vel.lerp(Vector2.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	if game.player == null or game.player.dead:
		return
	var to_player: Vector2 = game.player.global_position - global_position
	var dist := to_player.length()
	var range_pickup := float(game.player.S.pickup) * (2.5 if kind == "soul" else 1.0)
	if dist < range_pickup:
		magnet = true
	elif kind == "xp" and dist < range_pickup * 1.45:
		# Мягкое дальнее притяжение: опыт не остаётся лежать на карте,
		# поэтому даже при спокойном темпе старта прокачка идёт ровно.
		global_position += to_player.normalized() * 62.0 * delta
	if magnet:
		# Чем ближе сфера, тем сильнее притяжение: без медленного «хвоста» у ног игрока.
		var proximity:=clampf(1.0-dist/maxf(1.0,range_pickup),0.0,1.0)
		var base_speed:=150.0 if kind=="xp" else 105.0
		var pull_speed:=base_speed+(760.0 if kind=="xp" else 480.0)*proximity*proximity
		global_position += to_player.normalized()*minf(dist/maxf(delta,0.001),pull_speed)*delta
		if kind=="xp": rotation+=delta*(3.0+proximity*9.0)
	if dist < 9.0:
		game.collect_pickup(self)
		deactivate()
