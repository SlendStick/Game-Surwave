class_name Gfx
## Утилиты отрисовки. Визуал текущей версии намеренно минимальный:
## всё рисуется цветными квадратами из одной белой текстуры (быстро и без ассетов).

static var _white_tex: Texture2D = null

static func white() -> Texture2D:
	if _white_tex == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

## Создаёт квадратный спрайт-«квадратик» нужного размера и цвета.
static func square(parent: Node, size: Vector2, color: Color, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = white()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	s.modulate = color
	s.position = offset
	parent.add_child(s)
	return s

static func set_square(sprite: Sprite2D, size: Vector2, color: Color) -> void:
	if sprite == null:
		return
	sprite.scale = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	sprite.modulate = color

static func dim(color: Color, amount: float) -> Color:
	return Color(color.r * amount, color.g * amount, color.b * amount, color.a)

## Единый «готический» тон: приглушает цвет и подмешивает общий холодный камень.
static func gothic(c: Color, amount: float = 0.5, tone: Color = Color(0.60, 0.59, 0.55)) -> Color:
	var lum := c.get_luminance()
	var grey := Color(lum, lum, lum)
	var base := c.lerp(grey, 0.75).lerp(tone, 0.35)
	var out := c.lerp(base, amount)
	# немного притемняем, чтобы всё жило в одном диапазоне яркости
	out = out.lerp(Color(0.10, 0.10, 0.11), amount * 0.22)
	return Color(out.r, out.g, out.b, c.a)

static func hex(code: String) -> Color:
	return Color(code) if Color.html_is_valid(code) else Color.MAGENTA
