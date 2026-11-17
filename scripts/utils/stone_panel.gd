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
	var top := Color(0.098, 0.100, 0.114).lerp(accent, 0.12) * tone
	var bottom := Color(0.036, 0.037, 0.044) * tone
	var rows := 28
	for i in rows:
		var f := float(i) / float(rows - 1)
		var col := top.lerp(bottom, f)
		draw_rect(Rect2(0, h * float(i) / float(rows), w, h / float(rows) + 1.0), col)
	# --- тонкие швы каменной кладки (subtle ashlar lines)
	if h > 48.0 and w > 80.0:
		var step_y := 32.0
		var y_line := step_y
		var row_idx := 0
		while y_line < h - 10.0:
			draw_line(Vector2(4, y_line), Vector2(w - 4, y_line), Color(0, 0, 0, 0.14), 1.0)
			draw_line(Vector2(4, y_line + 1), Vector2(w - 4, y_line + 1), Color(1, 1, 1, 0.018), 1.0)
			var x_off := 28.0 + float((row_idx % 2) * 24)
			while x_off < w - 16.0:
				draw_line(Vector2(x_off, y_line - step_y + 4), Vector2(x_off, y_line), Color(0, 0, 0, 0.09), 1.0)
				x_off += 48.0
			y_line += step_y
			row_idx += 1
	# --- крапчатая текстура: детерминированная, чтобы не мерцала
	var spots := int(clampf(w * h / 210.0, 12.0, 360.0))
	for i in spots:
		var fx := fposmod(float(i) * 37.31 + w * 0.13, 1.0)
		var fy := fposmod(float(i) * 91.17 + h * 0.29, 1.0)
		var px := fx * w
		var py := fy * h
		var light := (i % 3) != 0
		var c := Color(0.88, 0.86, 0.94, 0.032) if light else Color(0, 0, 0, 0.13)
		draw_rect(Rect2(px, py, 1.0 + float(i % 2), 1.0), c)
	# --- внутренняя тень по краям (объём)
	for k in 3:
		var a := 0.19 - 0.05 * float(k)
		draw_rect(Rect2(2 + k, 2 + k, w - 4 - k * 2, 1), Color(0, 0, 0, a))
		draw_rect(Rect2(2 + k, 2 + k, 1, h - 4 - k * 2), Color(0, 0, 0, a))
	# --- рамка: тёмный внешний контур, бронза, тёмный шов, тонкая светлая грань
	draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.02, 0.018), false, 1.0)
	draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), Color(accent.r, accent.g, accent.b, 0.88), false, 1.0)
	draw_rect(Rect2(2.0, 2.0, w - 4, h - 4), Color(0, 0, 0, 0.62), false, 1.0)
	draw_rect(Rect2(3.0, 3.0, w - 6, h - 6), Color(accent.r, accent.g, accent.b, 0.24), false, 1.0)
	# --- готические бронзовые уголки и заклёпки
	var nub := Color(minf(1.0, accent.r * 1.45), minf(1.0, accent.g * 1.40), minf(1.0, accent.b * 1.25), 0.85)
	var b_len := minf(9.0, minf(w, h) * 0.22)
	if b_len >= 4.0:
		draw_line(Vector2(1, 1), Vector2(1 + b_len, 1), nub, 1.5)
		draw_line(Vector2(1, 1), Vector2(1, 1 + b_len), nub, 1.5)
		draw_line(Vector2(w - 1, 1), Vector2(w - 1 - b_len, 1), nub, 1.5)
		draw_line(Vector2(w - 1, 1), Vector2(w - 1, 1 + b_len), nub, 1.5)
		draw_line(Vector2(1, h - 1), Vector2(1 + b_len, h - 1), nub, 1.5)
		draw_line(Vector2(1, h - 1), Vector2(1, h - 1 - b_len), nub, 1.5)
		draw_line(Vector2(w - 1, h - 1), Vector2(w - 1 - b_len, h - 1), nub, 1.5)
		draw_line(Vector2(w - 1, h - 1), Vector2(w - 1, h - 1 - b_len), nub, 1.5)
	for p in [Vector2(4.5, 4.5), Vector2(w - 5.5, 4.5), Vector2(4.5, h - 5.5), Vector2(w - 5.5, h - 5.5)]:
		draw_rect(Rect2(p, Vector2(1.5, 1.5)), nub)
	# --- центральный верхний готический ромб для широких плит
	if w >= 120.0 and h >= 44.0:
		var mx := w * 0.5
		draw_polygon(PackedVector2Array([Vector2(mx, 0), Vector2(mx + 4, 3), Vector2(mx, 6), Vector2(mx - 4, 3)]), PackedColorArray([nub, nub, nub, nub]))
