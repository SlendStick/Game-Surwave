class_name EnemyBullet
extends Node2D
## Снаряд врага (уворачиваемый).

var game: Node = null
var vel := Vector2.ZERO
var damage := 1
var life := 4.0
var radius := 3.5
var color := Color(1, 0.4, 0.4)
var active := false
var homing := false
var burn := false
var poison := false
var sprite: Sprite2D = null

func setup(g: Node) -> void:
	game = g
	if sprite == null:
		sprite = Gfx.square(self, Vector2(7, 7), color)

func spawn_at(pos: Vector2, dir: Vector2, dmg: int, opts: Dictionary = {}) -> void:
	global_position = pos
	damage = dmg
	vel = dir.normalized() * float(opts.get("speed", 170.0))
	color = opts.get("color", Color(1, 0.4, 0.4))
	radius = float(opts.get("radius", 3.5))
	homing = bool(opts.get("homing", false))
	burn = bool(opts.get("burn", false))
	poison = bool(opts.get("poison", false))
	life = float(opts.get("life", 4.0))
	active = true
	visible = true
	var cls:="projectile_fire" if burn else ("projectile_orb" if homing else "projectile_enemy")
	sprite.texture=Assets.tex(cls,color); sprite.modulate=Color.WHITE; sprite.scale=Vector2(radius*2.0/Assets.BASE_PX,radius*2.0/Assets.BASE_PX)
	rotation=vel.angle()

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	if homing:
		var dir: Vector2 = (game.player.global_position - global_position)
		if dir.length() > 1.0:
			vel = vel.lerp(dir.normalized() * vel.length(), clampf(1.2 * delta, 0.0, 1.0))
	global_position += vel * delta
	life -= delta
	if life <= 0.0 or not game.map_rect.has_point(global_position):
		deactivate()
		return
	var obs: Dictionary = game.obstacle_at(global_position, radius)
	if not obs.is_empty() and String(obs.get("kind", "")) != "glyph":
		deactivate()
		return
	if game.player != null and not game.player.dead:
		if global_position.distance_to(game.player.global_position) < radius + 7.0:
			if burn:
				game.player.add_status("burn", 3.0, {"dps": 3.0})
			if poison:
				game.player.add_status("poison", 4.0, {"dps": 2.0})
			game.damage_player(damage, global_position)
			deactivate()
