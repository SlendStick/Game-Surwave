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
var source_role := ""
var sprite: Sprite2D = null
## Снаряд-кукла на клиенте: рисуется по снапшоту и не наносит урон.
var net_remote := false
var net_target := Vector2.ZERO

func setup(g: Node) -> void:
	game = g
	if sprite == null:
		sprite = Gfx.square(self, Vector2(7, 7), color)

func spawn_at(pos: Vector2, dir: Vector2, dmg: int, opts: Dictionary = {}) -> void:
	global_position = pos
	damage = dmg
	vel = dir.normalized() * float(opts.get("speed", 110.0))
	color = opts.get("color", Color(1, 0.4, 0.4))
	radius = float(opts.get("radius", 3.5))
	homing = bool(opts.get("homing", false))
	burn = bool(opts.get("burn", false))
	poison = bool(opts.get("poison", false))
	source_role = String(opts.get("role", ""))
	life = float(opts.get("life", 4.0))
	active = true
	visible = true
	var cls := "projectile_boss" if radius >= 5.0 else ("projectile_fire" if burn else ("projectile_orb" if homing else "projectile_enemy"))
	var ptex := Assets.tex(cls, color)
	sprite.texture = ptex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color.WHITE
	var sc := maxf(0.6, (radius * 2.6) / float(maxi(1, ptex.get_width())))
	sprite.scale = Vector2(sc, sc)
	rotation = vel.angle()

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func tick(delta: float) -> void:
	if not active:
		return
	if net_remote:
		global_position = global_position.lerp(net_target, clampf(20.0 * delta, 0.0, 1.0))
		life -= delta
		if life <= 0.0:
			deactivate()
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
			game.damage_player(damage, global_position, false, source_role)
			deactivate()
			return
	# сетевые напарники: урон считает хост и отправляет клиенту
	if game.net_active and game.net_host:
		for np in game.net_proxies:
			if np.dead:
				continue
			if global_position.distance_to(np.global_position) < radius + 8.0:
				game.net_hit_proxy(np, damage, global_position)
				deactivate()
				return
