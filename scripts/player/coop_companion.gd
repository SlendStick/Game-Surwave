class_name CoopCompanion
extends Node2D
## Локальный второй игрок: стрелки — движение, Numpad 0 — ручной выстрел; автоогонь держит темп боя.

var game: Node
var hp := 3
var max_hp := 3
var fire_cd := 0.0
var invuln := 0.0
var active := true
var sprite: Sprite2D

func setup(g: Node, pos: Vector2) -> void:
	game = g
	global_position = pos
	sprite = Sprite2D.new()
	sprite.texture = Assets.tex("diamond", Color("#36e1ff"))
	sprite.scale = Vector2(0.75,0.75)
	add_child(sprite)
	var ring := Sprite2D.new(); ring.texture = Assets.tex("ring",Color(0.2,0.9,1,0.7)); ring.scale=Vector2(1.2,1.2); ring.z_index=-1; add_child(ring)

func tick(delta: float) -> void:
	if not active: return
	fire_cd -= delta; invuln -= delta
	var dir := Vector2(Input.get_action_strength("coop_right")-Input.get_action_strength("coop_left"),Input.get_action_strength("coop_down")-Input.get_action_strength("coop_up")).normalized()
	global_position += dir*135.0*delta
	global_position = game.clamp_to_map(global_position)
	var target: Array = game.nearest_enemy(global_position,420.0)
	if not target.is_empty() and (fire_cd <= 0.0 or Input.is_action_pressed("coop_fire")):
		fire_cd = 0.45
		var e: Node2D = target[0]
		game.spawn_bullet(global_position,(e.global_position-global_position).normalized(),3.0,{"speed":300.0,"life":2.0,"color":Color("#36e1ff"),"source":"coop"})

func take_damage(amount: int, from_pos: Vector2) -> void:
	if invuln > 0.0 or not active: return
	hp -= amount; invuln=1.0
	global_position += (global_position-from_pos).normalized()*30.0
	if hp <= 0:
		active=false; visible=false
		game.notify("Второй игрок выбыл")
