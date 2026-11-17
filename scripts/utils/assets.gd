class_name Assets
extends RefCounted
## Слой визуальных ассетов. Сейчас рисует процедурные заглушки (простые фигуры),
## но уже умеет подхватывать настоящие спрайты: если в res://assets/sprites/ есть
## <class>.png (или <class>_<state>_<frame>.png), они используются вместо заглушек.
## Это «подготовленная почва» под будущий визуал: код игры уже спрашивает ассеты
## через этот класс, менять игровую логику при замене графики не придётся.

const SPRITE_DIR := "res://assets/sprites/"
const BASE_PX := 32

static var _cache: Dictionary = {}
static var _frames_cache: Dictionary = {}
static var _exists_cache: Dictionary = {}
static var _manifest: Dictionary = {}

## Загрузить манифест ассетов (список требуемых файлов и анимаций).
static func manifest() -> Dictionary:
	if _manifest.is_empty():
		if FileAccess.file_exists("res://assets/manifest.json"):
			var f := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest

## Есть ли настоящий спрайт для класса объекта.
static func has_real_sprite(cls: String) -> bool:
	if _exists_cache.has(cls):
		return bool(_exists_cache[cls])
	var ok := ResourceLoader.exists(SPRITE_DIR + cls + ".png")
	_exists_cache[cls] = ok
	return ok

## Загрузить текстуру по точному имени файла в assets/sprites (без .png).
static func icon(name: String) -> Texture2D:
	if name == "":
		return null
	if not has_real_sprite(name):
		return null
	return load(SPRITE_DIR + name + ".png") as Texture2D

## Текстура тайла пола карты.
static func tile(map_id: String) -> Texture2D:
	return icon("tile_" + map_id)

## Форма-заглушка по классу объекта (нужна, чтобы враги различались).
static func shape_of(cls: String) -> String:
	match cls:
		"slime", "slime_small":
			return "blob"
		"goblin_archer":
			return "triangle"
		"frozen_zombie":
			return "rect"
		"bat":
			return "diamond"
		"skeleton_warrior":
			return "cross"
		"dark_mage":
			return "pentagon"
		"werewolf":
			return "hex"
		"demon":
			return "inv_triangle"
		"fallen_angel":
			return "star"
		"mb":
			return "ring_hex"
		"boss", "boss_shemhaz", "boss_satanail", "boss_champion":
			return "boss"
		"projectile_arrow", "projectile_spear":
			return "diamond"
		"projectile_fire", "projectile_orb", "projectile_enemy":
			return "circle"
		"projectile_ice":
			return "star"
		"pickup_xp":
			return "diamond"
		"pickup_gold":
			return "hex"
		"pickup_soul":
			return "circle"
		"pickup_heart":
			return "cross"
		"pickup_chest":
			return "rect"
		"ally_spirit", "ally_moth": return "diamond"
		"ally_skeleton": return "cross"
		"ally_turret": return "rect"
		"ally_blade", "ally_scythe", "ally_spear": return "inv_triangle"
		"ally_tornado", "ally_aura": return "ring"
		"ally_phoenix", "ally_dragon": return "star"
		"ally_beetle": return "hex"
		"ally_clone": return "pentagon"
		"mage":
			return "circle"
		"paladin":
			return "cross"
		"necromancer":
			return "pentagon"
		"orc":
			return "hex"
		"elf":
			return "triangle"
		"rogue":
			return "diamond"
		"inventor":
			return "rect"
		"sniper":
			return "rect"
		"pyromancer":
			return "circle"
		_:
			return "square"

## Текстура объекта: настоящий спрайт, если он есть, иначе процедурная фигура.
static func tex(cls: String, color: Color, base_px: int = BASE_PX) -> Texture2D:
	if has_real_sprite(cls):
		var real: Texture2D = load(SPRITE_DIR + cls + ".png")
		if real != null:
			return real
	var key := "%s|%s|%d" % [cls, color.to_html(false), base_px]
	if _cache.has(key):
		return _cache[key]
	var tex := _procedural(shape_of(cls), color, base_px, cls)
	_cache[key] = tex
	return tex

static func _inside(shape: String, nx: float, ny: float) -> bool:
	# nx, ny в диапазоне [-1, 1]
	var r := sqrt(nx * nx + ny * ny)
	match shape:
		"blob":
			return r < 0.92 - 0.10 * absf(nx) + 0.08 * ny
		"circle":
			return r < 0.85
		"ring":
			return r < 0.95 and r > 0.62
		"ring_hex":
			return (absf(nx) < 0.9 and absf(ny) < 0.9) and not (absf(nx) < 0.45 and absf(ny) < 0.45)
		"triangle":
			return ny > -0.85 and ny < 0.85 - absf(nx) * 1.4
		"inv_triangle":
			return ny < 0.85 and ny > -0.85 + absf(nx) * 1.4
		"diamond":
			return absf(nx) + absf(ny) < 1.0
		"rect":
			return absf(nx) < 0.8 and absf(ny) < 0.8
		"square":
			return absf(nx) <= 1.0 and absf(ny) <= 1.0
		"cross":
			return (absf(nx) < 0.28 and absf(ny) < 0.9) or (absf(ny) < 0.22 and absf(nx) < 0.85)
		"hex":
			return absf(nx) < 0.9 and absf(ny) < 0.9 and absf(nx) * 0.6 + absf(ny) < 0.95
		"pentagon":
			return r < 0.9 and (ny > -0.95) and (absf(nx) < 0.9 - maxf(0.0, ny) * 0.4)
		"star":
			return r < 0.95 and (absf(nx) < 0.22 or absf(ny) < 0.22 or r < 0.45)
		"boss":
			return r < 0.95 or (absf(nx) < 0.25 and absf(ny) < 0.98) or (absf(ny) < 0.25 and absf(nx) < 0.98)
		_:
			return absf(nx) <= 1.0 and absf(ny) <= 1.0

static func _procedural(shape: String, color: Color, base_px: int, cls: String = "") -> Texture2D:
	var img := Image.create(base_px, base_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 1.0)
	for y in base_px:
		for x in base_px:
			var nx := (float(x) + 0.5) / float(base_px) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(base_px) * 2.0 - 1.0
			if _inside(shape, nx, ny):
				# Толстый контур + простой объём: верх светлее, низ темнее.
				var edge := _inside(shape, nx * 1.22, ny * 1.22) == false
				var shade := clampf(1.12 - (ny + 1.0) * 0.16, 0.72, 1.18)
				var fill := Color(minf(1.0,color.r*shade),minf(1.0,color.g*shade),minf(1.0,color.b*shade),color.a)
				img.set_pixel(x, y, outline if edge else fill)
	_paint_details(img, cls, color, base_px)
	var tex := ImageTexture.create_from_image(img)
	return tex

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x>=0 and y>=0 and x<img.get_width() and y<img.get_height(): img.set_pixel(x,y,col)

static func _rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	for y in range(y0,y0+h):
		for x in range(x0,x0+w): _px(img,x,y,col)

static func _paint_details(img: Image, cls: String, color: Color, n: int) -> void:
	# Детали намеренно геометрические: глаза, оружие и эмблемы делают силуэты читаемыми.
	var dark:=Color(0.04,0.05,0.07,1); var light:=Color(1,1,0.88,1); var accent:=Color(minf(1.0,color.r*1.7+0.15),minf(1.0,color.g*1.7+0.15),minf(1.0,color.b*1.7+0.15),1)
	var c:int=floori(float(n)/2.0); var u:int=maxi(1,floori(float(n)/16.0))
	if cls in ["slime","slime_small","goblin_archer","frozen_zombie","bat","skeleton_warrior","dark_mage","werewolf","demon","fallen_angel","boss","boss_shemhaz","boss_satanail","boss_champion","mb"]:
		_rect(img,c-6*u,c-3*u,3*u,3*u,light); _rect(img,c+3*u,c-3*u,3*u,3*u,light)
		_rect(img,c-5*u,c-2*u,u,u,dark); _rect(img,c+4*u,c-2*u,u,u,dark)
	match cls:
		"goblin_archer":
			_rect(img,n-7*u,5*u,u,n-10*u,Color("#7a4b20")); _rect(img,n-10*u,c,u*5,u,light)
		"frozen_zombie":
			_rect(img,c-u,4*u,2*u,n-8*u,Color("#b9f4ff")); _rect(img,4*u,c-u,n-8*u,2*u,Color("#b9f4ff"))
		"bat":
			_rect(img,2*u,c,8*u,2*u,dark); _rect(img,n-10*u,c,8*u,2*u,dark)
		"skeleton_warrior":
			_rect(img,c-u,4*u,2*u,n-8*u,light); _rect(img,6*u,c, n-12*u,2*u,light)
		"dark_mage": _rect(img,c-2*u,c+2*u,4*u,4*u,Color("#cf60ff"))
		"werewolf":
			_rect(img,5*u,2*u,4*u,6*u,dark); _rect(img,n-9*u,2*u,4*u,6*u,dark)
		"boss_shemhaz":
			_rect(img,2*u,2*u,7*u,3*u,Color("#ff5a20")); _rect(img,n-9*u,2*u,7*u,3*u,Color("#ff5a20")); _rect(img,c-2*u,c+3*u,4*u,7*u,Color("#ffd040"))
		"boss_satanail":
			_rect(img,2*u,c-2*u,8*u,3*u,Color("#ff1493")); _rect(img,n-10*u,c-2*u,8*u,3*u,Color("#ff1493")); _rect(img,c-u,2*u,2*u,n-4*u,Color("#ffd700"))
		"boss", "boss_champion", "mb": _rect(img,c-2*u,c+2*u,4*u,4*u,accent)
		"mage", "pyromancer": _rect(img,c-2*u,c-2*u,4*u,4*u,accent)
		"paladin":
			_rect(img,c-u,4*u,2*u,n-8*u,light); _rect(img,6*u,c-u,n-12*u,2*u,light)
		"necromancer": _rect(img,c-2*u,c-2*u,4*u,4*u,Color("#62ff82"))
		"elf":
			_rect(img,3*u,c-1*u,n-6*u,2*u,light); _rect(img,n-8*u,c-4*u,5*u,8*u,Color("#7a4b20"))
		"rogue": _rect(img,c-5*u,c-1*u,10*u,2*u,light)
		"inventor":
			_rect(img,c-5*u,c-5*u,10*u,2*u,dark); _rect(img,c-1*u,c-9*u,2*u,18*u,light)
		"sniper": _rect(img,c-10*u,c-1*u,20*u,2*u,light)
		"projectile_arrow", "projectile_spear": _rect(img,2*u,c-u,n-4*u,2*u,light)
		"projectile_fire": _rect(img,c-u,3*u,2*u,n-6*u,Color("#fff1a0"))
		"projectile_ice":
			_rect(img,c-u,3*u,2*u,n-6*u,light); _rect(img,3*u,c-u,n-6*u,2*u,light)
		"pickup_xp": _rect(img,c-u,c-u,2*u,2*u,light)
		"pickup_gold": _rect(img,c-2*u,c-2*u,4*u,4*u,Color("#fff2a0"))
		"pickup_soul": _rect(img,c-u,c-5*u,2*u,10*u,light)
		"pickup_heart": _rect(img,c-4*u,c-4*u,8*u,8*u,Color("#ffcfda"))
		"pickup_chest": _rect(img,3*u,c-u,n-6*u,2*u,Color("#ffd75a"))

## Кадры анимации для класса и состояния ("idle"/"walk"/"attack"/"hurt"/"death").
static func frames(cls: String, state: String) -> Array:
	var key := cls + "|" + state
	if _frames_cache.has(key):
		return _frames_cache[key]
	var out: Array = []
	for i in 8:
		var path := SPRITE_DIR + "%s_%s_%d.png" % [cls, state, i]
		if ResourceLoader.exists(path):
			out.append(load(path))
	_frames_cache[key] = out
	return out
