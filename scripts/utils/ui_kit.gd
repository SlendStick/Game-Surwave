class_name UI
## Единый визуальный стиль интерфейса в духе Diablo II:
## тёплый камень, бронза, пергаментные буквы, засечный шрифт.
## Всё рисуется кодом, внешних ассетов нет.

# --- палитра: единый холодный тон — камень, пепел, кость, тусклое золото
const BG := Color("#07080a")
const BG_SOFT := Color("#0d0e12")
const PANEL := Color("#121318")
const PANEL_LIGHT := Color("#191b21")
const PANEL_HI := Color("#23262e")
const BORDER := Color("#34363e")
const BORDER_HI := Color("#5c5e66")
const TEXT := Color("#cbc6ba")
const DIM := Color("#928d80")
const MUTED := Color("#6a665c")
const GOLD := Color("#b39a5f")
const GOLD_BRIGHT := Color("#d8c79a")
const GOLD_DEEP := Color("#5f5133")
const ACCENT := Color("#8f949b")
const ACCENT_DEEP := Color("#3e434a")
const DANGER := Color("#8f2f28")
const GREEN := Color("#6f7a5f")
const PURPLE := Color("#6f6478")
const SHADOW := Color(0, 0, 0, 0.78)

const RADIUS := 0
const FONT_NAMES := ["Georgia", "Times New Roman", "DejaVu Serif", "Liberation Serif", "Noto Serif", "serif"]
const SANS_NAMES := ["DejaVu Sans", "Liberation Sans", "Noto Sans", "Segoe UI", "Arial", "sans-serif"]

static var _serif: Font = null
static var _sans: Font = null

## Засечный шрифт (Georgia / Times / DejaVu Serif) с откатом на шрифт движка.
static func font() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(FONT_NAMES)
		f.allow_system_fallback = true
		_serif = f
	return _serif

## Чёткий рубленый шрифт без засечек — для мелких карточек и дерева улучшений.
static func crisp_font() -> Font:
	if _sans == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(SANS_NAMES)
		f.allow_system_fallback = true
		_sans = f
	return _sans

static func _apply_font(c: Control, size: int) -> void:
	if font() != null:
		c.add_theme_font_override("font", font())
	c.add_theme_font_size_override("font_size", size)

static func style(bg: Color, border: Color = BORDER, border_w: int = 1, radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

## Панель-плита: тёмный камень, бронзовая рамка, мягкая тень.
static func panel_style(bg: Color = PANEL, border: Color = BORDER, radius: int = RADIUS, accent_top: bool = true) -> StyleBoxFlat:
	var sb := style(bg, border, 1, radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	if accent_top:
		sb.border_width_top = 2
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

## Каменная плита с текстурой и бронзовой оправой (рисуется stone_panel.gd).
static func stone(parent: Node, rect: Rect2, accent: Color = BORDER) -> Panel:
	var p: Panel = load("res://scripts/utils/stone_panel.gd").new()
	p.set("accent", accent)
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	return p

static func panel(parent: Node, rect: Rect2, bg: Color = PANEL, border: Color = BORDER) -> Panel:
	var p := stone(parent, rect, border)
	return p

## Панель с цветной полосой сверху — для карточек и выделенных блоков.
static func panel_striped(parent: Node, rect: Rect2, stripe: Color, bg: Color = PANEL) -> Panel:
	var p := stone(parent, rect, stripe.darkened(0.25))
	var bar := ColorRect.new()
	bar.color = stripe
	bar.position = Vector2(3, 3)
	bar.size = Vector2(rect.size.x - 6, 2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bar)
	return p

static func label(parent: Node, text: String, size: int = 10, color: Color = TEXT, pos: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = text
	_apply_font(l, size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## Чёткая подпись без размытого контура для компактных карточек и дерева перков.
static func crisp_label(parent: Node, text: String, size: int = 8, color: Color = TEXT, pos: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = text
	if crisp_font() != null:
		l.add_theme_font_override("font", crisp_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 1)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 0.9))
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## Крупный заголовок: бронзовые буквы с тёмным контуром и свечением.
static func title(parent: Node, text: String, size: int = 30, pos: Vector2 = Vector2.ZERO, color: Color = GOLD) -> Label:
	var l := label(parent, text, size, color, pos)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_color_override("font_shadow_color", Color(0.35, 0.24, 0.06, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

## Разделитель с ромбом посередине — как гравировка на камне.
static func divider(parent: Node, pos: Vector2, width: float, color: Color = BORDER_HI) -> void:
	var holder := Control.new()
	holder.position = pos
	holder.size = Vector2(width, 9)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var half := width * 0.5
	for i in int(half / 2.0):
		var f := float(i) / maxf(1.0, half / 2.0)
		var seg := ColorRect.new()
		seg.color = Color(color.r, color.g, color.b, 0.65 * (1.0 - f * 0.85))
		seg.position = Vector2(half - 10 - i * 2, 4)
		seg.size = Vector2(2, 1)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(seg)
		var seg2 := ColorRect.new()
		seg2.color = seg.color
		seg2.position = Vector2(half + 10 + i * 2, 4)
		seg2.size = Vector2(2, 1)
		seg2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(seg2)
	var dia := Polygon2D.new()
	dia.polygon = PackedVector2Array([Vector2(half, 0), Vector2(half + 5, 4), Vector2(half, 8), Vector2(half - 5, 4)])
	dia.color = color
	holder.add_child(dia)
	var dia2 := Polygon2D.new()
	dia2.polygon = PackedVector2Array([Vector2(half, 2), Vector2(half + 3, 4), Vector2(half, 6), Vector2(half - 3, 4)])
	dia2.color = Color(0.05, 0.04, 0.03)
	holder.add_child(dia2)

static func button(parent: Node, text: String, size: int = 10, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	_apply_font(b, size)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	b.add_theme_color_override("font_pressed_color", Color("#f4e6b8"))
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color("#57492f"))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 1)
	b.add_theme_constant_override("outline_size", 2)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	var normal := stone_box(Color(0.10, 0.082, 0.062, 0.45), Color(0.32, 0.25, 0.14, 0.55))
	var hover := stone_box(Color(0.20, 0.16, 0.10, 0.95), GOLD_DEEP)
	hover.shadow_color = Color(0.78, 0.60, 0.20, 0.20)
	hover.shadow_size = 4
	var pressed := stone_box(Color(0.06, 0.05, 0.04, 1.0), GOLD)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", stone_box(Color(0.07, 0.06, 0.05, 0.8), Color(0.18, 0.15, 0.1)))
	var focus := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("focus", focus)
	if min_size != Vector2.ZERO:
		b.custom_minimum_size = min_size
	parent.add_child(b)
	return b

## Плоская каменная плашка с бронзовой рамкой (общая основа кнопок).
static func stone_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := style(bg, border, 1, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb

## Главная кнопка: широкая плита с двойной бронзовой оправой и золотой надписью.
static func primary_button(parent: Node, text: String, size: int = 13, min_size: Vector2 = Vector2(200, 30)) -> Button:
	var b := button(parent, text, size, min_size)
	b.add_theme_color_override("font_color", GOLD_BRIGHT)
	b.add_theme_color_override("font_hover_color", Color("#fff0bf"))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_constant_override("outline_size", 3)
	var normal := style(Color("#2a2116"), BORDER_HI, 2, 0)
	normal.shadow_color = Color(0, 0, 0, 0.6)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 2)
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := style(Color("#3a2d1c"), GOLD, 2, 0)
	hover.shadow_color = Color(0.85, 0.65, 0.22, 0.28)
	hover.shadow_size = 8
	var pressed := style(Color("#1c150e"), GOLD_DEEP, 2, 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	var shine := ColorRect.new()
	shine.color = Color(0.85, 0.68, 0.30, 0.28)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shine.offset_left = 4
	shine.offset_right = -4
	shine.offset_top = 3
	shine.offset_bottom = 4
	b.add_child(shine)
	return b

static func card(parent: Node, min_size: Vector2, border: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.add_theme_stylebox_override("normal", style(Color("#1e1811"), border, 2, 0))
	var hover := style(Color("#2c2418"), border.lightened(0.22), 2, 0)
	hover.shadow_color = Color(border.r, border.g, border.b, 0.28)
	hover.shadow_size = 8
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", style(Color("#15100b"), border, 2, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_apply_font(b, 10)
	b.add_theme_color_override("font_color", TEXT)
	parent.add_child(b)
	return b

static func vbox(parent: Node, separation: int = 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v

static func hbox(parent: Node, separation: int = 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	return h

## Небольшой значок-плашка с текстом (уровень, режим, число).
static func badge(parent: Node, text: String, pos: Vector2, color: Color, size: Vector2 = Vector2(50, 14)) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", style(Color(0.08, 0.065, 0.05, 0.95), Color(color.r, color.g, color.b, 0.7), 1, 0))
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l := label(p, text, 8, color)
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return p

static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0

static func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

## Цвета по типу награды — как цвета редкости в Diablo II.
static func kind_color(kind: String) -> Color:
	match kind:
		"perk": return Color("#b39a5f")
		"synergy": return Color("#8a7145")
		"char_upgrade": return Color("#7c8270")
		"specialization": return Color("#7b8189")
		"seal": return Color("#8a5c3e")
		"evolution": return Color("#94899f")
		_: return Color("#b39a5f")

static func kind_name(kind: String) -> String:
	match kind:
		"synergy": return Loc.t("synergy")
		"char_upgrade": return Loc.t("char_upgrade")
		"specialization": return Loc.t("specialization")
		"seal": return Loc.t("seal")
		"evolution": return "ЭВОЛЮЦИЯ"
		_: return Loc.t("perk")

static func fmt_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]

# ------------------------------------------------------------------ ФОН
## Живой фон меню: тёмный камень со светом факелов и редкими искрами.
static func backdrop(parent: Node, tint: Color = Color("#120d08")) -> Node:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(layer)
	var script := load("res://scripts/utils/menu_backdrop.gd")
	layer.set_script(script)
	layer.set("tint", tint)
	return layer
