class_name WeatherFx
extends Control
## Экранный слой погоды: тонировка, ветер, частицы (песок, снег, дождь, туман, искры).
## Рисуется кодом поверх world, не влияет на логику и не требует ассетов.

var kind := ""
var tint := Color(0, 0, 0, 0)
var t := 0.0
var parts: Array = []
var strength := 1.0
var wind := Vector2(1, 0.2)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func start(kind_name: String, col: Color, amount: int = 90, wind_dir: Vector2 = Vector2(1, 0.25)) -> void:
	kind = kind_name
	var g := Gfx.gothic(col, 0.25)
	tint = Color(g.r, g.g, g.b, 0.15)
	visible = true
	t = 0.0
	wind = wind_dir
	parts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + kind_name.hash()
	for i in amount:
		parts.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"v": rng.randf_range(0.35, 1.0),
			"s": rng.randf_range(1.0, 2.6),
			"a": rng.randf_range(0.25, 0.8),
			"ph": rng.randf_range(0.0, TAU),
		})
	queue_redraw()

func stop() -> void:
	visible = false
	kind = ""
	parts.clear()

func tick(delta: float) -> void:
	if not visible:
		return
	t += delta
	queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

func _draw() -> void:
	if not visible:
		return
	var w := size.x
	var h := size.y
	if w < 2.0:
		return
	draw_rect(Rect2(0, 0, w, h), tint)
	var speed := 1.0
	var angle := 0.0
	var col := Color(1, 1, 1, 0.7)
	var vertical := false
	match kind:
		"sand":
			speed = 0.35
			col = Color(0.90, 0.78, 0.54, 0.75)
			angle = 0.12
		"snow":
			speed = 0.16
			col = Color(0.95, 0.97, 1.0, 0.85)
			angle = 0.35
			vertical = true
		"rain":
			speed = 0.85
			col = Color(0.75, 0.92, 0.80, 0.7)
			vertical = true
		"acid":
			speed = 0.7
			col = Color(0.62, 0.95, 0.30, 0.75)
			vertical = true
		"spores":
			speed = 0.1
			col = Color(0.72, 0.55, 0.95, 0.6)
		"ash":
			speed = 0.12
			col = Color(0.55, 0.55, 0.55, 0.55)
		"embers":
			speed = 0.22
			col = Color(1.0, 0.55, 0.2, 0.8)
		"fog":
			speed = 0.06
			col = Color(0.72, 0.76, 0.78, 0.4)
		"insects":
			speed = 0.3
			col = Color(0.15, 0.14, 0.12, 0.8)
	for p in parts:
		var pos: Vector2 = Vector2(p["p"])
		var v: float = float(p["v"]) * speed
		var x := fposmod(pos.x + wind.x * t * v * 0.35 + 0.02 * sin(t + float(p["ph"])), 1.0)
		var y := fposmod(pos.y + (wind.y * t * v * 0.35) + (t * v * 0.5 if vertical else 0.0) + 0.03 * cos(t * 1.3 + float(p["ph"])), 1.0)
		var s: float = float(p["s"])
		var a: float = float(p["a"])
		var c := Color(col.r, col.g, col.b, col.a * a)
		if kind == "fog":
			draw_rect(Rect2(x * w - s * 14.0, y * h, s * 28.0, s * 5.0), c)
		elif vertical:
			draw_rect(Rect2(x * w, y * h, maxf(1.0, s * 0.6), s * 4.0), c)
		else:
			draw_rect(Rect2(x * w, y * h, s, s), c)
	# виньетка: при плохой видимости края темнеют сильнее
	if kind in ["sand", "fog", "snow", "acid", "spores"]:
		for i in 10:
			var f := float(i) / 10.0
			draw_rect(Rect2(0, f * h * 0.18, w, 3), Color(0, 0, 0, 0.05 * (1.0 - f)))
			draw_rect(Rect2(0, h - f * h * 0.18 - 3, w, 3), Color(0, 0, 0, 0.05 * (1.0 - f)))
