class_name PerkFx
extends Node2D
## Богатые покадровые пиксель-арт эффекты для перков: удар молнии с неба,
## огненный шар, небесная кара, ледяной взрыв.

var kind := "lightning"
var elapsed := 0.0
var duration := 0.32
var size_px := 48.0
var sprite: Sprite2D = null
var glow: Sprite2D = null

func setup(fx_kind: String, pos: Vector2, sz: float = 48.0, dur: float = 0.32) -> void:
	kind = fx_kind
	global_position = pos
	size_px = maxf(24.0, sz)
	duration = maxf(0.18, dur)
	elapsed = 0.0
	z_index = 10

	glow = Sprite2D.new()
	glow.centered = true
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.texture = Assets.tex("fx_burst", Color.WHITE)
	add_child(glow)

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	match kind:
		"lightning":
			sprite.offset = Vector2(0, -28)
			sprite.scale = Vector2(maxf(1.0, size_px / 28.0), 1.35)
			glow.modulate = Color(0.75, 0.90, 1.0, 0.75)
			glow.scale = Vector2.ONE * (size_px / 14.0)
		"smite":
			sprite.offset = Vector2(0, -26)
			sprite.scale = Vector2(maxf(1.0, size_px / 30.0), 1.4)
			glow.modulate = Color(1.0, 0.92, 0.55, 0.8)
			glow.scale = Vector2.ONE * (size_px / 14.0)
		"fireball":
			sprite.scale = Vector2.ONE * (size_px / 32.0)
			glow.modulate = Color(1.0, 0.52, 0.15, 0.7)
			glow.scale = Vector2.ONE * (size_px / 14.0)
		"frost":
			sprite.scale = Vector2.ONE * (size_px / 26.0)
			glow.modulate = Color(0.65, 0.92, 1.0, 0.65)
			glow.scale = Vector2.ONE * (size_px / 16.0)
	_apply_frame(0)

func _apply_frame(idx: int) -> void:
	if sprite == null:
		return
	match kind:
		"lightning":
			sprite.texture = Assets.icon("vfx_lightning_%d" % clampi(idx, 0, 3))
		"smite":
			sprite.texture = Assets.icon("vfx_smite_%d" % clampi(idx, 0, 3))
		"fireball":
			sprite.texture = Assets.icon("vfx_fireball_%d" % clampi(idx, 0, 3))
		"frost":
			sprite.texture = Assets.icon("vfx_frost_%d" % clampi(idx, 0, 2))

func _process(delta: float) -> void:
	elapsed += delta
	var k := clampf(elapsed / duration, 0.0, 1.0)
	var frames := 3 if kind == "frost" else 4
	_apply_frame(mini(frames - 1, int(k * float(frames))))
	var alpha := 1.0 - pow(k, 1.8)
	if sprite != null:
		sprite.modulate.a = alpha
	if glow != null:
		glow.modulate.a = (1.0 - k) * 0.65
		glow.scale = Vector2.ONE * ((size_px / 14.0) * (1.0 + k * 0.45))
	if k >= 1.0:
		queue_free()
