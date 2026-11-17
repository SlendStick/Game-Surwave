extends Node2D
## Вид опасной зоны: заливка + чёткая кайма + вращающийся пунктир.
## В фазе предупреждения вокруг растёт круг-таймер, чтобы было видно,
## когда рванёт. Рисуется кодом, без ассетов.

var radius := 40.0
var color := Color(1, 0.3, 0.2)
var alpha := 0.35
var armed := false
var telegraph := 0.0
var elapsed := 0.0
var pattern := "generic"

func _ready() -> void:
	z_index = 1

func _draw() -> void:
	var r := radius
	if r < 2.0:
		return
	var a := clampf(alpha, 0.0, 1.0)
	var bright := Color(
		minf(1.0, color.r + 0.28),
		minf(1.0, color.g + 0.28),
		minf(1.0, color.b + 0.28), 1.0)
	# --- заливка: мягкое ядро темнее к центру
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, a * 0.5))
	draw_circle(Vector2.ZERO, r * 0.78, Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, a * 0.55))
	draw_circle(Vector2.ZERO, r * 0.5, Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, a * 0.65))
	# --- чёткая кайма: сразу видно границу, куда нельзя наступать
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(bright.r, bright.g, bright.b, minf(1.0, a * 2.2)), 2.0)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 40, Color(bright.r, bright.g, bright.b, a * 0.55), 1.0)
	# --- вращающийся пунктир по краю
	var seg := 10
	var spin := elapsed * 0.9
	for i in seg:
		var start := spin + TAU * float(i) / float(seg)
		draw_arc(Vector2.ZERO, r * 0.95, start, start + TAU / float(seg) * 0.45, 6,
			Color(bright.r, bright.g, bright.b, a * 1.1), 1.0)
	# --- узор внутри: свой у каждого типа зоны
	match pattern:
		"swirl":
			for i in 3:
				var rr := r * (0.32 + 0.2 * float(i))
				var st := -elapsed * (1.4 - 0.3 * float(i)) + float(i) * 1.7
				draw_arc(Vector2.ZERO, rr, st, st + 1.9, 12, Color(bright.r, bright.g, bright.b, a * 0.55), 1.5)
		"rune":
			for i in 4:
				var ang := elapsed * 0.6 + TAU * float(i) / 4.0
				var p := Vector2(cos(ang), sin(ang)) * r * 0.6
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(bright.r, bright.g, bright.b, a * 0.9))
		"fire":
			for i in 6:
				var ang2 := elapsed * 1.6 + TAU * float(i) / 6.0
				var p2 := Vector2(cos(ang2), sin(ang2)) * r * 0.55
				draw_circle(p2, 1.6, Color(1.0, 0.72, 0.35, a * 0.9))
	# --- фаза предупреждения: растёт круг-таймер вокруг зоны
	if not armed and telegraph > 0.05:
		var k := clampf(elapsed / telegraph, 0.0, 1.0)
		var col := Color(1.0, 0.86, 0.55, 0.85)
		draw_arc(Vector2.ZERO, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, col, 2.0)
		var blink := 0.35 + 0.35 * sin(elapsed * 18.0)
		draw_arc(Vector2.ZERO, r + 7.5, 0.0, TAU, 36, Color(1.0, 0.86, 0.55, blink), 1.0)
