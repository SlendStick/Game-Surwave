class_name Fx
extends Node2D
## Простой эффект: расширяющийся и затухающий квадрат.

var duration := 0.3
var elapsed := 0.0
var max_size := 30.0
var color := Color.WHITE
var sprite: Sprite2D = null
var active := false
var square := false

func setup(max_s: float, col: Color, dur: float, is_square: bool = false) -> void:
	max_size = max_s
	color = col
	duration = maxf(0.05, dur)
	elapsed = 0.0
	square = is_square
	active = true
	visible = true
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	var ftex := Assets.tex("fx_burst" if square else "fx_ring", color)
	sprite.texture = ftex
	var bw := float(maxi(1, ftex.get_width()))
	sprite.scale = Vector2(6.0 / bw, 6.0 / bw)
	sprite.modulate = color

func deactivate() -> void:
	active = false
	visible = false
	global_position = Vector2(-10000, -10000)
	elapsed = 0.0

func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var k := clampf(elapsed / duration, 0.0, 1.0)
	var size := lerpf(6.0, max_size, k)
	var alpha := 1.0 - k
	if sprite:
		var bw := float(maxi(1, sprite.texture.get_width())) if sprite.texture != null else 16.0
		sprite.scale = Vector2(size / bw, size / bw)
		sprite.modulate = Color(color.r, color.g, color.b, alpha * 0.85)
	if k >= 1.0:
		deactivate()
