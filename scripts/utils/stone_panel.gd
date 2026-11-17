extends Panel
## Каменная панель в духе Diablo II: тёплый тёмный камень, вертикальный градиент,
## крапчатая текстура, скошенная рамка из бронзы. Рисуется кодом.

var accent: Color = Color("#4a4d55")
var tone: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 3.0 or h < 3.0:
		return
	# --- основание: тёплый камень с вертикальным градиентом
	var top := Color(0.098, 0.100, 0.110).lerp(accent, 0.10) * tone
	var bottom := Color(0.038, 0.039, 0.045) * tone
	var rows := 26
	for i in rows:
		var f := float(i) / float(rows - 1)
		var col := top.lerp(bottom, f)
		draw_rect(Rect2(0, h * float(i) / float(rows), w, h / float(rows) + 1.0), col)
	# --- крапчатая текстура: детерминированная, чтобы не мерцала
	var spots := int(clampf(w * h / 220.0, 12.0, 340.0))
	for i in spots:
		var fx := fposmod(float(i) * 37.31 + w * 0.13, 1.0)
		var fy := fposmod(float(i) * 91.17 + h * 0.29, 1.0)
		var px := fx * w
		var py := fy * h
		var light := (i % 3) != 0
		var c := Color(0.86, 0.88, 0.95, 0.030) if light else Color(0, 0, 0, 0.12)
		draw_rect(Rect2(px, py, 1.0 + float(i % 2), 1.0), c)
	# --- внутренняя тень по краям (объём)
	for k in 3:
		var a := 0.16 - 0.045 * float(k)
		draw_rect(Rect2(2 + k, 2 + k, w - 4 - k * 2, 1), Color(0, 0, 0, a))
		draw_rect(Rect2(2 + k, 2 + k, 1, h - 4 - k * 2), Color(0, 0, 0, a))
	# --- рамка: тёмный внешний контур, бронза, тёмный шов, тонкая светлая грань
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.025, 0.02), false, 1.0)
	draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
	draw_rect(Rect2(2.0, 2.0, w - 4, h - 4), Color(0, 0, 0, 0.55), false, 1.0)
	draw_rect(Rect2(3.0, 3.0, w - 6, h - 6), Color(accent.r, accent.g, accent.b, 0.22), false, 1.0)
	# --- заклёпки-уголки
	var nub := Color(accent.r * 1.5, accent.g * 1.45, accent.b * 1.3, 0.75)
	for p in [Vector2(5, 5), Vector2(w - 5, 5), Vector2(5, h - 5), Vector2(w - 5, h - 5)]:
		draw_rect(Rect2(p, Vector2(1.5, 1.5)), nub)
