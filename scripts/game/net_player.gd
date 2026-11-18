class_name NetPlayer
extends Node2D
## Двойник удалённого игрока в сетевом кооперативе.
## Хост и клиенты видят друг друга: позиция интерполируется между снапшотами,
## над головой — имя и полоска HP, в руках — оружие из лобби.

var game: Node = null
var peer_id := 0
var display_name := "Игрок"
var char_id := "aldar"
var weapon_id := "revolver"
var hp := 3
var max_hp := 3
var dead := false
var aim := Vector2.RIGHT
var move_dir := Vector2.ZERO
var target_pos := Vector2.ZERO
var moving := false
var hit_flash := 0.0

var sprite: Sprite2D = null
var marker: Sprite2D = null
var weapon_sprite: Sprite2D = null
var name_label: Label = null
var hp_bar: Sprite2D = null

func setup(g: Node, id: int, pname: String, ch: String, wp: String, pos: Vector2) -> void:
	game = g
	peer_id = id
	display_name = pname
	char_id = ch
	weapon_id = wp
	global_position = pos
	target_pos = pos
	z_index = 3
	marker = Sprite2D.new()
	marker.texture = Assets.tex("ring", Color(0.45, 0.95, 1.0, 0.65))
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.z_index = -1
	marker.scale = Vector2(1.15, 1.15)
	add_child(marker)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = Assets.tex(char_id, Color.WHITE)
	add_child(sprite)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.texture = Assets.icon("weapon_" + weapon_id)
	weapon_sprite.z_index = 1
	add_child(weapon_sprite)
	hp_bar = Sprite2D.new()
	hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp_bar.position = Vector2(0, -17)
	add_child(hp_bar)
	name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_override("font", UI.crisp_font())
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.position = Vector2(-28, -30)
	name_label.size = Vector2(56, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	_refresh_body()

## Плавно тянется к последней позиции из сети; «рывки» сглаживаются.
func apply_state(state: Dictionary) -> void:
	var px := float(state.get("x", global_position.x))
	var py := float(state.get("y", global_position.y))
	target_pos = Vector2(px, py)
	var ax := float(state.get("ax", aim.x))
	var ay := float(state.get("ay", aim.y))
	if absf(ax) + absf(ay) > 0.01:
		aim = Vector2(ax, ay).normalized()
	var new_hp := int(state.get("hp", hp))
	if new_hp < hp:
		hit_flash = 0.35
		if game != null:
			game.spawn_fx(global_position, Color(0.6, 0.95, 1.0, 0.8), 20.0, 0.2)
	hp = new_hp
	max_hp = maxi(1, int(state.get("max", max_hp)))
	dead = bool(state.get("dead", dead))
	moving = bool(state.get("mv", false))
	var new_char := String(state.get("ch", char_id))
	var new_weapon := String(state.get("wp", weapon_id))
	if new_char != char_id:
		char_id = new_char
		_refresh_body()
	if new_weapon != weapon_id:
		weapon_id = new_weapon
		if weapon_sprite != null:
			weapon_sprite.texture = Assets.icon("weapon_" + weapon_id)

func _refresh_body() -> void:
	if sprite == null:
		return
	var data := DB.character(char_id)
	var size := 22.0
	sprite.texture = Assets.tex(char_id, Gfx.hex(String(data.get("color", "#ffffff"))))
	var base := float(maxi(1, sprite.texture.get_width()))
	sprite.scale = Vector2(size / base, size / base)
	if weapon_sprite != null:
		weapon_sprite.visible = sprite.visible
		weapon_sprite.texture = Assets.icon("weapon_" + weapon_id)

func update_visual(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)
	var prev := global_position
	global_position = global_position.lerp(target_pos, clampf(14.0 * delta, 0.0, 1.0))
	move_dir = (global_position - prev) / maxf(0.0001, delta)
	var stretch := 1.0 + clampf(move_dir.length() * 0.0016, 0.0, 0.08)
	if sprite != null:
		sprite.position.y = -absf(sin(float(Time.get_ticks_msec()) * 0.012)) * (2.2 if move_dir.length() > 4.0 else 0.0)
		sprite.flip_h = aim.x < -0.1
		sprite.modulate = Color(1.6, 0.85, 0.85) if hit_flash > 0.0 else Color.WHITE
	if weapon_sprite != null:
		weapon_sprite.position = aim * 9.0 + Vector2(0, 1)
		weapon_sprite.rotation = aim.angle()
		weapon_sprite.flip_v = aim.x < 0.0
		weapon_sprite.scale = Vector2(0.62, 0.62) * stretch
	if marker != null:
		marker.rotation += delta * 0.9
		marker.modulate = Color(0.55, 0.95, 1.0, 0.32 + 0.1 * sin(float(Time.get_ticks_msec()) * 0.005))
	if name_label != null:
		name_label.visible = not dead
		name_label.text = display_name
	if hp_bar != null:
		var ratio := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
		hp_bar.texture = Assets.tex("pixel", Color(0.35, 0.95, 1.0, 0.9))
		if hp_bar.texture != null:
			hp_bar.scale = Vector2(maxf(0.01, 22.0 * ratio) / float(maxi(1, hp_bar.texture.get_width())), 1.0)
		hp_bar.visible = not dead and hp < max_hp
	visible = not dead
