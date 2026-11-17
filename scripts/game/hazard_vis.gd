extends Node2D
## Естественный грунтовый вид зон (без ярких рамок «опасных зон»).
## Зыбучие пески выглядят максимально незаметно и лишь слегка отличаются от песчаного фона.

var radius := 40.0
var color := Color(1, 0.3, 0.2)
var alpha := 0.25
var armed := false
var telegraph := 0.0
var elapsed := 0.0
var pattern := "generic"

func _ready() -> void:
	z_index = -5

func _draw() -> void:
	var r := radius
	if r < 2.0:
		return
	var a := clampf(alpha, 0.0, 0.45)
	match pattern:
		"swirl":
			# Зыбучие пески: почти сливаются с песком (#1c1610 / #2d2217), лишь лёгкое затемнение и слабая рябь
			draw_circle(Vector2.ZERO, r * 0.94, Color(0.16, 0.12, 0.08, a * 0.42))
			draw_circle(Vector2.ZERO, r * 0.68, Color(0.13, 0.10, 0.06, a * 0.48))
			draw_circle(Vector2.ZERO, r * 0.36, Color(0.10, 0.08, 0.05, a * 0.52))
			for i in 3:
				var rr := r * (0.28 + 0.22 * float(i))
				var st := -elapsed * (0.85 - 0.18 * float(i)) + float(i) * 2.1
				draw_arc(Vector2.ZERO, rr, st, st + 1.5, 10, Color(0.24, 0.18, 0.12, a * 0.40), 1.0)
		"rune":
			# Проклятая земля: тёмная дымка и тусклые руны
			draw_circle(Vector2.ZERO, r * 0.85, Color(color.r * 0.45, color.g * 0.35, color.b * 0.50, a * 0.32))
			for i in 4:
				var ang := elapsed * 0.45 + TAU * float(i) / 4.0
				var p := Vector2(cos(ang), sin(ang)) * r * 0.52
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(color.r, color.g, color.b, a * 0.55))
		"fire":
			# Выжженная земля с редкими угольками
			draw_circle(Vector2.ZERO, r * 0.82, Color(0.12, 0.06, 0.04, a * 0.40))
			for i in 5:
				var ang2 := elapsed * 1.4 + TAU * float(i) / 5.0
				var p2 := Vector2(cos(ang2), sin(ang2)) * r * 0.48
				draw_circle(p2, 1.5, Color(0.95, 0.48, 0.18, a * 0.65))
		"poison":
			draw_circle(Vector2.ZERO, r * 0.88, Color(0.10, 0.24, 0.12, a * 0.42))
			for i in 4:
				var ang3 := elapsed * 0.9 + TAU * float(i) / 4.0
				var p3 := Vector2(cos(ang3), sin(ang3)) * r * (0.28 + 0.15 * sin(elapsed * 2.0 + float(i)))
				draw_circle(p3, 2.0, Color(0.45, 0.88, 0.45, a * 0.55))
		"blood":
			draw_circle(Vector2.ZERO, r * 0.86, Color(0.28, 0.04, 0.05, a * 0.45))
			draw_arc(Vector2.ZERO, r * 0.55, elapsed * 0.5, elapsed * 0.5 + 2.2, 10, Color(0.75, 0.14, 0.16, a * 0.50), 1.4)
		"ice":
			draw_circle(Vector2.ZERO, r * 0.86, Color(0.28, 0.45, 0.64, a * 0.36))
			for i in 6:
				var a4 := TAU * float(i) / 6.0
				draw_line(Vector2.ZERO, Vector2(cos(a4), sin(a4)) * r * 0.68, Color(0.78, 0.92, 1.0, a * 0.35), 1.0)
		"void":
			draw_circle(Vector2.ZERO, r * 0.90, Color(0.08, 0.04, 0.12, a * 0.52))
			draw_arc(Vector2.ZERO, r * 0.64, -elapsed * 1.1, -elapsed * 1.1 + 3.4, 12, Color(0.65, 0.35, 0.92, a * 0.48), 1.5)
		_:
			# Обычные события/удары: без красных рамок опасных зон — только лёгкая тень падения
			if not armed and telegraph > 0.05:
				var k := clampf(elapsed / telegraph, 0.0, 1.0)
				draw_circle(Vector2.ZERO, r * (0.25 + 0.45 * k), Color(0.04, 0.04, 0.05, 0.16 + 0.18 * k))
			else:
				draw_circle(Vector2.ZERO, r * 0.72, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, a * 0.20))
