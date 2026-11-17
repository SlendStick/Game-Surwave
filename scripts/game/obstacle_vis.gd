class_name ObstacleVis
extends RefCounted
## Процедурный вид препятствий по теме карты: только фигуры и цвета, без ассетов.
## Возвращает узел-визуал, который кладётся в world.

static func build(parent: Node, shape: String, size: Vector2, color: Color, accent: Color) -> Node2D:
	var n := Node2D.new()
	color = Gfx.gothic(color, 0.22)
	accent = Gfx.gothic(accent, 0.22)
	parent.add_child(n)
	var otex := Assets.icon("obs_" + shape)
	if otex != null:
		var sp := Sprite2D.new()
		sp.texture = otex
		sp.centered = true
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tw := float(maxi(1, otex.get_width()))
		var th := float(maxi(1, otex.get_height()))
		if shape in ["water", "lava", "swamp", "ice", "ash", "cliff"]:
			sp.scale = Vector2(maxf(0.5, size.x * 1.15 / tw), maxf(0.5, size.y * 1.15 / th))
			sp.z_index = -3
		else:
			var sc := maxf(0.55, maxf(size.x, size.y) * 1.15 / maxf(tw, th))
			sp.scale = Vector2(sc, sc)
		sp.modulate = Color.WHITE.lerp(color, 0.14)
		n.add_child(sp)
		return n
	var w := size.x
	var h := size.y
	var dark := color.darkened(0.35)
	var light := color.lightened(0.22)
	match shape:
		"tree":
			_shadow(n, Vector2(w * 1.5, h * 0.5), Color(0, 0, 0, 0.28))
			_rect(n, Vector2(w * 0.34, h * 1.05), dark, Vector2(0, -h * 0.1))
			_tri(n, w * 1.1, h * 1.5, color, Vector2(0, -h * 0.85))
			_tri(n, w * 0.8, h * 1.0, light, Vector2(0, -h * 1.25))
		"bush":
			_shadow(n, Vector2(w * 1.2, h * 0.45), Color(0, 0, 0, 0.24))
			_ellipse(n, w, h, color, Vector2.ZERO)
			_ellipse(n, w * 0.6, h * 0.7, light, Vector2(-w * 0.18, -h * 0.12))
		"flower":
			_rect(n, Vector2(1.5, 5), Color(0.35, 0.5, 0.28), Vector2(0, 1))
			_rect(n, Vector2(4, 4), color, Vector2(0, -2))
		"mushroom":
			_rect(n, Vector2(w * 0.24, h * 0.7), Color(0.72, 0.66, 0.55), Vector2(0, h * 0.18))
			_ellipse(n, w, h * 0.7, color, Vector2(0, -h * 0.12))
			_rect(n, Vector2(2, 2), Color(0.95, 0.93, 0.85), Vector2(-w * 0.16, -h * 0.2))
			_rect(n, Vector2(2, 2), Color(0.95, 0.93, 0.85), Vector2(w * 0.12, -h * 0.28))
			_glow(n, w * 2.0, Color(color.r, color.g, color.b, 0.16))
		"cactus":
			_shadow(n, Vector2(w * 1.3, h * 0.4), Color(0, 0, 0, 0.22))
			_rect(n, Vector2(w * 0.5, h), color, Vector2.ZERO)
			_rect(n, Vector2(w * 0.28, h * 0.4), color, Vector2(-w * 0.34, -h * 0.12))
			_rect(n, Vector2(w * 0.28, h * 0.32), color, Vector2(w * 0.34, -h * 0.2))
			for i in 3:
				_rect(n, Vector2(1, 2), Color(0.93, 0.92, 0.8), Vector2(-w * 0.16 + float(i) * w * 0.16, -h * 0.3 + float(i) * h * 0.18))
		"rock":
			_shadow(n, Vector2(w * 1.35, h * 0.42), Color(0, 0, 0, 0.3))
			_tri(n, w * 1.15, h, color, Vector2.ZERO)
			_tri(n, w * 0.55, h * 0.55, light, Vector2(-w * 0.18, -h * 0.1))
		"bone":
			_rect(n, Vector2(w, 2.5), Color(0.88, 0.86, 0.74), Vector2.ZERO)
			_rect(n, Vector2(w * 0.3, 2.5), Color(0.88, 0.86, 0.74), Vector2(0, 0)).rotation = 0.6
		"water":
			_ellipse(n, w, h, Color(color.r, color.g, color.b, 0.55), Vector2.ZERO)
			_ellipse(n, w * 0.72, h * 0.66, Color(light.r, light.g, light.b, 0.35), Vector2.ZERO)
			for i in 3:
				_rect(n, Vector2(w * 0.5, 1), Color(1, 1, 1, 0.16), Vector2(0, -h * 0.2 + float(i) * h * 0.2))
		"crystal":
			_glow(n, w * 2.6, Color(color.r, color.g, color.b, 0.14))
			_tri(n, w * 0.55, h, color, Vector2(-w * 0.12, 0))
			_tri(n, w * 0.4, h * 0.75, light, Vector2(w * 0.26, h * 0.1))
			_tri(n, w * 0.22, h * 0.5, accent, Vector2(w * 0.02, -h * 0.22))
		"pillar":
			_shadow(n, Vector2(w * 1.2, h * 0.28), Color(0, 0, 0, 0.3))
			_rect(n, Vector2(w * 0.7, h), color, Vector2.ZERO)
			_rect(n, Vector2(w, h * 0.12), light, Vector2(0, -h * 0.5))
			_rect(n, Vector2(w, h * 0.1), dark, Vector2(0, h * 0.48))
		"grave":
			_shadow(n, Vector2(w * 1.2, h * 0.35), Color(0, 0, 0, 0.26))
			_rect(n, Vector2(w * 0.8, h * 0.85), color, Vector2(0, h * 0.06))
			_ellipse(n, w * 0.8, h * 0.42, color, Vector2(0, -h * 0.34))
			_rect(n, Vector2(w * 0.3, 2), dark, Vector2(0, -h * 0.1))
			_rect(n, Vector2(w * 0.18, 2), dark, Vector2(0, -h * 0.02))
		"cross":
			_rect(n, Vector2(w * 0.28, h), color, Vector2.ZERO)
			_rect(n, Vector2(w, h * 0.16), color, Vector2(0, -h * 0.26))
		"pumpkin":
			_ellipse(n, w, h * 0.86, color, Vector2.ZERO)
			_rect(n, Vector2(2, 4), Color(0.3, 0.5, 0.25), Vector2(0, -h * 0.5))
			_rect(n, Vector2(2, 2), Color(1, 0.85, 0.35), Vector2(-w * 0.16, 0))
			_rect(n, Vector2(2, 2), Color(1, 0.85, 0.35), Vector2(w * 0.16, 0))
		"reeds":
			for i in 3:
				_rect(n, Vector2(1.5, h * (0.6 + 0.2 * float(i % 2))), Color(color.r, color.g, color.b, 0.8), Vector2(-3 + float(i) * 3, 0))
		"lava":
			_glow(n, w * 1.6, Color(color.r, color.g, color.b, 0.22))
			_rect(n, Vector2(w, h), color, Vector2.ZERO)
			_rect(n, Vector2(w * 0.7, h * 0.35), Color(1, 0.85, 0.45, 0.85), Vector2.ZERO)
		"swamp":
			_rect(n, Vector2(w, h), Color(color.r, color.g, color.b, 0.7), Vector2.ZERO)
			_rect(n, Vector2(w * 0.4, 2), Color(0.45, 0.65, 0.35, 0.5), Vector2(-w * 0.16, 0))
			_rect(n, Vector2(w * 0.22, 2), Color(0.45, 0.65, 0.35, 0.45), Vector2(w * 0.22, h * 0.2))
		"ice":
			_rect(n, Vector2(w, h), Color(color.r, color.g, color.b, 0.72), Vector2.ZERO)
			_rect(n, Vector2(w * 0.8, h * 0.18), Color(1, 1, 1, 0.28), Vector2(-w * 0.05, -h * 0.3))
			_rect(n, Vector2(1, h * 0.7), Color(1, 1, 1, 0.2), Vector2(w * 0.1, 0)).rotation = 0.2
		"ash":
			_ellipse(n, w, h, Color(color.r, color.g, color.b, 0.55), Vector2.ZERO)
			_ellipse(n, w * 0.5, h * 0.5, Color(color.r, color.g, color.b, 0.45), Vector2(w * 0.18, -h * 0.1))
		"stalagmite":
			_tri(n, w * 0.55, h, color, Vector2.ZERO)
			_tri(n, w * 0.25, h * 0.5, light, Vector2(-w * 0.08, -h * 0.12))
		"scrap":
			_rect(n, Vector2(w, h * 0.55), color, Vector2(0, h * 0.12))
			_rect(n, Vector2(w * 0.4, h * 0.5), dark, Vector2(-w * 0.16, -h * 0.2)).rotation = 0.35
			_rect(n, Vector2(w * 0.3, h * 0.3), light, Vector2(w * 0.2, -h * 0.16))
		"cliff":
			_shadow(n, Vector2(w * 1.1, h * 0.25), Color(0, 0, 0, 0.35))
			_rect(n, Vector2(w, h), color, Vector2.ZERO)
			_rect(n, Vector2(w, h * 0.12), light, Vector2(0, -h * 0.46))
			_rect(n, Vector2(w * 0.35, h * 0.9), dark, Vector2(-w * 0.22, 0))
		"obelisk":
			_tri(n, w * 0.7, h, dark, Vector2.ZERO)
			_glow(n, w * 2.2, Color(accent.r, accent.g, accent.b, 0.14))
			_rect(n, Vector2(w * 0.12, h * 0.4), accent, Vector2(0, -h * 0.1))
		_:
			_shadow(n, Vector2(w * 1.2, h * 0.35), Color(0, 0, 0, 0.25))
			_rect(n, Vector2(w, h), color, Vector2.ZERO)
			_rect(n, Vector2(w, 2), light, Vector2(0, -h * 0.4))
	return n

static func _rect(parent: Node2D, size: Vector2, color: Color, pos: Vector2) -> Sprite2D:
	var s := Gfx.square(parent, size, color, pos)
	return s

static func _tri(parent: Node2D, w: float, h: float, color: Color, pos: Vector2) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-w * 0.5, h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(0, -h * 0.5)])
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

static func _ellipse(parent: Node2D, w: float, h: float, color: Color, pos: Vector2) -> Node2D:
	# дешёвый «эллипс»: три вложенных квадрата с прозрачностью
	var n := Node2D.new()
	n.position = pos
	parent.add_child(n)
	var base := Gfx.square(n, Vector2(w, h), color)
	base.rotation = 0.0
	var inner := Gfx.square(n, Vector2(w * 0.76, h * 0.88), Color(color.r, color.g, color.b, color.a))
	inner.rotation = PI * 0.25
	return n

static func _shadow(parent: Node2D, size: Vector2, color: Color) -> Sprite2D:
	var s := Gfx.square(parent, size, color, Vector2(0, size.y * 0.35))
	s.z_index = -1
	return s

static func _glow(parent: Node2D, size: float, color: Color) -> Sprite2D:
	var s := Gfx.square(parent, Vector2(size, size), color)
	s.z_index = -2
	return s
