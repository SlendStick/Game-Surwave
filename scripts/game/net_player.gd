class_name NetPlayer
extends Node2D
## Двойник удалённого игрока в сетевом кооперативе.
## Рисуется тем же спрайтом героя, что и у себя (класс персонажа + кадры
## idle/walk), поэтому напарник выглядит как живой герой, а не как квадрат.
## Над головой — имя, тонкая шкала HP, шкала навыка и облачко эмоции/чата.

const BAR_W := 18.0
const BAR_H := 1.5

var game: Node = null
var peer_id := 0
var display_name := "Игрок"
var char_id := "aldar"
var weapon_id := "revolver"
var hp := 3
var max_hp := 3
var skill_frac := 1.0
var dead := false
var aim := Vector2.RIGHT
var move_dir := Vector2.ZERO
var target_pos := Vector2.ZERO
var moving := false
var hit_flash := 0.0
var revive_ready := false
## Эмоция/реплика над головой: {text, color, left}
var bubble_left := 0.0
var bubble_text := ""
var bubble_color := Color(0.85, 0.95, 1.0)

var sprite: Sprite2D = null
var marker: Sprite2D = null
var weapon_sprite: Sprite2D = null
var name_label: Label = null
var hp_bar: Sprite2D = null
var hp_bar_bg: Sprite2D = null
var skill_bar: Sprite2D = null
var bubble_bg: Sprite2D = null
var bubble_label: Label = null
var soul: Sprite2D = null

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
	marker.texture = Assets.tex("ring", Color(0.45, 0.95, 1.0, 0.55))
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.z_index = -1
	marker.scale = Vector2(0.85, 0.85)
	add_child(marker)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	add_child(sprite)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.z_index = 1
	add_child(weapon_sprite)
	# шкалы: тёмная подложка + HP + микрополоса навыка
	hp_bar_bg = Gfx.square(self, Vector2(BAR_W + 2.0, BAR_H * 3.0 + 3.0), Color(0.03, 0.03, 0.05, 0.75), Vector2(0, -21))
	hp_bar_bg.z_index = 2
	hp_bar = Gfx.square(self, Vector2(BAR_W, BAR_H), Color(0.35, 0.95, 1.0), Vector2(0, -22))
	hp_bar.z_index = 3
	skill_bar = Gfx.square(self, Vector2(BAR_W, BAR_H), Color(0.95, 0.85, 0.4), Vector2(0, -19))
	skill_bar.z_index = 3
	soul = Sprite2D.new()
	soul.texture = Assets.icon("pickup_soul")
	soul.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	soul.position = Vector2(0, -2)
	soul.visible = false
	soul.z_index = 2
	add_child(soul)
	name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_override("font", UI.crisp_font())
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.position = Vector2(-28, -32)
	name_label.size = Vector2(56, 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	# облачко эмоции
	bubble_bg = Gfx.square(self, Vector2(34, 11), Color(0.06, 0.07, 0.1, 0.92), Vector2(0, -38))
	bubble_bg.z_index = 4
	bubble_bg.visible = false
	bubble_label = Label.new()
	bubble_label.add_theme_font_override("font", UI.crisp_font())
	bubble_label.add_theme_font_size_override("font_size", 8)
	bubble_label.add_theme_constant_override("outline_size", 1)
	bubble_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble_label.position = Vector2(-26, -43)
	bubble_label.size = Vector2(52, 12)
	bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_label.z_index = 5
	bubble_label.visible = false
	add_child(bubble_label)
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
	var new_dead := bool(state.get("dead", dead))
	if new_dead != dead:
		dead = new_dead
		_refresh_body()
	skill_frac = clampf(float(state.get("sk", skill_frac)), 0.0, 1.0)
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

## Класс персонажа (knight/rogue/…) — именно по нему лежат спрайты героев.
func _char_cls() -> String:
	var data := DB.character(char_id)
	var cls := String(data.get("cls", ""))
	return cls if cls != "" else char_id

func _refresh_body() -> void:
	if sprite == null:
		return
	var cls := _char_cls()
	var col := Gfx.hex(String(DB.character(char_id).get("color", "#ffffff")))
	var tex := Assets.tex(cls, col)
	if tex != null:
		sprite.texture = tex
		var base := float(maxi(1, tex.get_width()))
		sprite.scale = Vector2(22.0 / base, 22.0 / base)
	if weapon_sprite != null:
		weapon_sprite.texture = Assets.icon("weapon_" + weapon_id)
	if soul != null:
		soul.texture = Assets.icon("pickup_soul") if Assets.icon("pickup_soul") != null else soul.texture

## Показать эмоцию/реплику над головой (облачко живёт несколько секунд).
func show_bubble(text: String, color: Color = Color(0.85, 0.95, 1.0), seconds: float = 4.0) -> void:
	bubble_text = text
	bubble_color = color
	bubble_left = seconds
	if bubble_label != null:
		bubble_label.text = text
		bubble_label.add_theme_color_override("font_color", color)
		var w := clampf(float(text.length()) * 4.6 + 8.0, 20.0, 90.0)
		if bubble_bg != null:
			bubble_bg.scale = Vector2(w, 11.0)
			bubble_bg.visible = true
		bubble_label.size = Vector2(w, 12)
		bubble_label.position = Vector2(-w * 0.5, -43)
		bubble_label.visible = true

func _tick_bubble(delta: float) -> void:
	if bubble_left <= 0.0:
		return
	bubble_left -= delta
	if bubble_left <= 0.0:
		if bubble_bg != null:
			bubble_bg.visible = false
		if bubble_label != null:
			bubble_label.visible = false
		return
	var blink := 1.0 if bubble_left > 0.6 else 0.55
	if bubble_label != null:
		bubble_label.modulate = Color(1, 1, 1, blink)
	if bubble_bg != null:
		bubble_bg.modulate = Color(1, 1, 1, blink)

func update_visual(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)
	var prev := global_position
	global_position = global_position.lerp(target_pos, clampf(14.0 * delta, 0.0, 1.0))
	move_dir = (global_position - prev) / maxf(0.0001, delta)
	var stretch := 1.0 + clampf(move_dir.length() * 0.0016, 0.0, 0.08)
	var walking := move_dir.length() > 6.0 or moving
	if sprite != null:
		var frames := Assets.frames(_char_cls(), "walk" if walking else "idle")
		if not frames.is_empty():
			var fps := 8.0 if walking else 3.0
			var fi := int(floor(float(Time.get_ticks_msec()) * 0.001 * fps)) % frames.size()
			if sprite.texture != frames[fi]:
				sprite.texture = frames[fi]
				var base := float(maxi(1, (frames[fi] as Texture2D).get_width()))
				sprite.scale = Vector2(22.0 / base, 22.0 / base)
		sprite.position.y = -absf(sin(float(Time.get_ticks_msec()) * 0.012)) * (2.2 if walking else 0.0)
		sprite.flip_h = aim.x < -0.1
		if hit_flash > 0.0:
			sprite.modulate = Color(1.6, 0.85, 0.85)
		elif revive_ready:
			sprite.modulate = Color(0.75, 0.95, 1.35)
		else:
			sprite.modulate = Color.WHITE
		sprite.visible = not dead
	if weapon_sprite != null:
		weapon_sprite.visible = not dead
		weapon_sprite.position = aim * 8.0 + Vector2(0, 1)
		weapon_sprite.rotation = aim.angle()
		weapon_sprite.flip_v = aim.x < 0.0
		weapon_sprite.scale = Vector2(0.58, 0.58) * stretch
	if marker != null:
		marker.rotation += delta * 0.9
		marker.modulate = Color(0.55, 0.95, 1.0, 0.26 + 0.1 * sin(float(Time.get_ticks_msec()) * 0.005))
		marker.visible = not dead
	if soul != null:
		soul.visible = dead
		if dead:
			soul.position = Vector2(0, -4.0 + sin(float(Time.get_ticks_msec()) * 0.004) * 2.0)
			soul.modulate = Color(0.8, 0.9, 1.0, 0.8)
	if name_label != null:
		name_label.text = ("☠ " if dead else "") + display_name
		name_label.visible = true
	var show_bars := not dead
	if hp_bar_bg != null:
		hp_bar_bg.visible = show_bars
	if hp_bar != null:
		hp_bar.visible = show_bars
		var ratio := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
		hp_bar.scale = Vector2(maxf(0.5, BAR_W * ratio), BAR_H)
		hp_bar.position = Vector2(-(BAR_W - BAR_W * ratio) * 0.5, -22)
		hp_bar.modulate = Color(0.55, 0.95, 1.0)
	if skill_bar != null:
		skill_bar.visible = show_bars
		var sfrac := clampf(skill_frac, 0.0, 1.0)
		skill_bar.scale = Vector2(maxf(0.5, BAR_W * sfrac), BAR_H)
		skill_bar.position = Vector2(-(BAR_W - BAR_W * sfrac) * 0.5, -19)
		skill_bar.modulate = Color(0.95, 0.85, 0.4) if sfrac >= 1.0 else Color(0.55, 0.5, 0.3)
	_tick_bubble(delta)

## Радиус для столкновений игроков между собой.
func body_radius() -> float:
	return 7.0
