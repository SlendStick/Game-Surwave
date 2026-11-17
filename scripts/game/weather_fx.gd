class_name WeatherFx
extends Control
## Экранный слой погоды: многослойный туман, метель с порывами, песчаная буря,
## пепел, искры, кислотный дождь. Рисуется кодом без потери FPS.

var kind := ""
var tint := Color(0, 0, 0, 0)
var t := 0.0
var parts: Array = []
var fog_banks: Array = []
var strength := 1.0
var wind := Vector2(1, 0.2)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func start(kind_name: String, col: Color, amount: int = 90, wind_dir: Vector2 = Vector2(1, 0.25)) -> void:
	kind = kind_name
	var g := Gfx.gothic(col, 0.25)
	tint = Color(g.r, g.g, g.b, 0.16)
	visible = true
	t = 0.0
	wind = wind_dir
	parts.clear()
	fog_banks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + kind_name.hash()
	for i in amount:
		parts.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"v": rng.randf_range(0.45, 1.15),
			"s": rng.randf_range(1.0, 2.8),
			"a": rng.randf_range(0.30, 0.85),
			"ph": rng.randf_range(0.0, TAU),
		})
	if kind_name in ["fog", "snow", "sand", "spores"]:
		for i in 18:
			fog_banks.append({
				"p": Vector2(rng.randf(), rng.randf()),
				"w": rng.randf_range(90.0, 190.0),
				"h": rng.randf_range(22.0, 48.0),
				"v": rng.randf_range(0.03, 0.09),
				"a": rng.randf_range(0.07, 0.18),
				"ph": rng.randf_range(0.0, TAU),
			})
	queue_redraw()

func stop() -> void:
	visible = false
	kind = ""
	parts.clear()
	fog_banks.clear()

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

	# Дрейфующие клубы тумана / пурги / песчаной завесы
	if not fog_banks.is_empty():
		var bank_col := Color(0.75, 0.80, 0.82, 1.0)
		if kind == "snow":
			bank_col = Color(0.88, 0.94, 1.0, 1.0)
		elif kind == "sand":
			bank_col = Color(0.86, 0.70, 0.45, 1.0)
		elif kind == "spores":
			bank_col = Color(0.65, 0.35, 0.78, 1.0)
		elif tint.g > tint.r * 1.2:
			bank_col = Color(0.45, 0.82, 0.45, 1.0)
		for b in fog_banks:
			var bp: Vector2 = Vector2(b["p"])
			var bw: float = float(b["w"])
			var bh: float = float(b["h"])
			var bx := fposmod(bp.x + (wind.x if absf(wind.x) > 0.1 else 0.6) * t * float(b["v"]), 1.3) * (w + bw) - bw
			var by := bp.y * h + sin(t * 0.8 + float(b["ph"])) * 10.0
			var ba: float = float(b["a"]) * (0.75 + 0.25 * sin(t + float(b["ph"])))
			draw_rect(Rect2(bx, by, bw, bh), Color(bank_col.r, bank_col.g, bank_col.b, ba * 0.55))
			draw_rect(Rect2(bx + bw * 0.15, by + bh * 0.2, bw * 0.7, bh * 0.6), Color(bank_col.r, bank_col.g, bank_col.b, ba * 0.55))

	var speed := 1.0
	var col := Color(1, 1, 1, 0.75)
	var vertical := false
	match kind:
		"sand":
			speed = 0.48
			col = Color(0.92, 0.78, 0.52, 0.80)
		"snow":
			speed = 0.34
			col = Color(0.96, 0.98, 1.0, 0.90)
			vertical = true
		"rain":
			speed = 0.90
			col = Color(0.75, 0.92, 0.80, 0.75)
			vertical = true
		"acid":
			speed = 0.75
			col = Color(0.62, 0.95, 0.30, 0.80)
			vertical = true
		"spores":
			speed = 0.12
			col = Color(0.76, 0.52, 0.96, 0.68)
		"ash":
			speed = 0.14
			col = Color(0.62, 0.58, 0.55, 0.62)
		"embers":
			speed = 0.26
			col = Color(1.0, 0.55, 0.2, 0.85)
		"fog":
			speed = 0.08
			col = Color(0.76, 0.82, 0.80, 0.45)
		"insects":
			speed = 0.32
			col = Color(0.15, 0.14, 0.12, 0.82)
	for p in parts:
		var pos: Vector2 = Vector2(p["p"])
		var v: float = float(p["v"]) * speed
		var x := fposmod(pos.x + wind.x * t * v * 0.42 + 0.025 * sin(t * 1.4 + float(p["ph"])), 1.0)
		var y := fposmod(pos.y + (wind.y * t * v * 0.38) + (t * v * 0.52 if vertical else 0.0) + 0.03 * cos(t * 1.3 + float(p["ph"])), 1.0)
		var s: float = float(p["s"])
		var a: float = float(p["a"])
		var c := Color(col.r, col.g, col.b, col.a * a)
		if kind == "snow":
			# Косые снежные порывы + крупные снежинки
			draw_line(Vector2(x * w, y * h), Vector2(x * w - wind.x * s * 3.0, y * h - s * 2.5), c, maxf(1.0, s * 0.6))
			draw_rect(Rect2(x * w - 1.0, y * h - 1.0, s, s), Color(1, 1, 1, col.a * a))
		elif kind == "sand":
			draw_line(Vector2(x * w, y * h), Vector2(x * w - s * 5.0, y * h - wind.y * s * 2.0), c, 1.0)
		elif kind == "fog":
			draw_rect(Rect2(x * w - s * 16.0, y * h, s * 32.0, s * 6.0), c)
		elif vertical:
			draw_rect(Rect2(x * w, y * h, maxf(1.0, s * 0.6), s * 4.5), c)
		else:
			draw_rect(Rect2(x * w, y * h, s, s), c)
	if kind in ["sand", "fog", "snow", "acid", "spores"]:
		for i in 10:
			var f := float(i) / 10.0
			draw_rect(Rect2(0, f * h * 0.18, w, 3), Color(0, 0, 0, 0.05 * (1.0 - f)))
			draw_rect(Rect2(0, h - f * h * 0.18 - 3, w, 3), Color(0, 0, 0, 0.05 * (1.0 - f)))
