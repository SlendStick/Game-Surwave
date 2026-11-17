extends Control
## фон меню в духе Diablo II: тёмный камень, отсветы факелов, редкие искры.
## Рисуется кодом, без ассетов и без влияния на геймплей.

var tint: Color = Color("#0b0c10")
var t := 0.0
var motes: Array = []
var patches: Array = []
var lights: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	# налёт на камне: крупные пятна светлее и темнее
	for i in 26:
		patches.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"s": rng.randf_range(40.0, 190.0),
			"a": rng.randf_range(0.010, 0.034),
			"warm": rng.randf() < 0.35,
		})
	# искры/пылинки
	for i in 34:
		motes.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"s": rng.randf_range(0.7, 1.7),
			"a": rng.randf_range(0.18, 0.65),
			"v": rng.randf_range(4.0, 16.0),
			"ph": rng.randf_range(0.0, TAU),
		})
	# источники света: два «факела» сверху и слабый снизу
	lights = [
		{"p": Vector2(0.07, 0.02), "r": 430.0, "c": Color(0.72, 0.56, 0.30), "a": 0.085, "f": 1.4},
		{"p": Vector2(0.93, 0.03), "r": 390.0, "c": Color(0.68, 0.52, 0.28), "a": 0.075, "f": 1.9},
		{"p": Vector2(0.5, 1.03), "r": 540.0, "c": Color(0.42, 0.40, 0.42), "a": 0.06, "f": 0.7},
	]

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0:
		return
	# --- основание: тёплый тёмный камень
	var top := Color(tint.r * 0.9, tint.g * 0.9, tint.b * 1.0)
	var bottom := Color(0.022, 0.022, 0.026)
	var rows := 20
	for i in rows:
		var f := float(i) / float(rows - 1)
		draw_rect(Rect2(0, h * float(i) / float(rows), w, h / float(rows) + 1.0), top.lerp(bottom, f))
	# --- пятна на камне
	for p in patches:
		var pos: Vector2 = Vector2(p["p"]) * Vector2(w, h)
		var r: float = float(p["s"])
		var a: float = float(p["a"])
		var c := Color(0.50, 0.47, 0.40, a) if bool(p["warm"]) else Color(0, 0, 0, a * 1.7)
		for k in 5:
			draw_circle(pos, r * (1.0 - 0.16 * float(k)), Color(c.r, c.g, c.b, a * (0.34 + 0.15 * float(k))))
	# --- отсветы факелов, слегка мерцающие
	for l in lights:
		var lp: Vector2 = Vector2(l["p"]) * Vector2(w, h)
		var base: Color = l["c"]
		var flick: float = 0.85 + 0.15 * sin(t * float(l["f"])) + 0.05 * sin(t * float(l["f"]) * 3.7)
		var max_r: float = float(l["r"]) * (0.97 + 0.03 * sin(t * float(l["f"]) * 1.3))
		var steps := 16
		for k in steps:
			var f := 1.0 - float(k) / float(steps)
			draw_circle(lp, max_r * f, Color(base.r, base.g, base.b, float(l["a"]) * flick * 0.11 * f))
	# --- искры: медленно плывут вверх, мерцают
	for m in motes:
		var p: Vector2 = Vector2(m["p"])
		var y := fposmod(p.y - t * float(m["v"]) / h, 1.0)
		var x := fposmod(p.x + 0.012 * sin(t * 0.6 + float(m["ph"])), 1.0)
		var a: float = float(m["a"]) * (0.55 + 0.45 * sin(t * 1.6 + float(m["ph"])))
		var col := Color(0.86, 0.82, 0.68, maxf(0.0, a))
		var s: float = float(m["s"])
		draw_rect(Rect2(Vector2(x, y) * Vector2(w, h), Vector2(s, s)), col)
	# --- виньетка: тёмные края
	var edge := 0.55
	var bands := 14
	for i in bands:
		var f := float(i) / float(bands)
		var a := edge * (1.0 - f) * 0.5
		var inset := f * minf(w, h) * 0.42
		draw_rect(Rect2(0, inset, w, 2), Color(0, 0, 0, a))
		draw_rect(Rect2(0, h - inset - 2, w, 2), Color(0, 0, 0, a))
		draw_rect(Rect2(inset, 0, 2, h), Color(0, 0, 0, a))
		draw_rect(Rect2(w - inset - 2, 0, 2, h), Color(0, 0, 0, a))
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.03, 0.34))
