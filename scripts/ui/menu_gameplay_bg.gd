class_name MenuGameplayBg
extends Control
## Случайно генерируемое слайд-шоу реального геймплея игры на фоне главного меню.
## Каждые несколько секунд переключается на новую сцену биома с героем, врагами,
## снарядами, боссом и эффектами перков/событий.

const SLIDE_DUR := 5.5
const FADE_DUR := 0.8

var t := 0.0
var slide_t := 0.0
var rng := RandomNumberGenerator.new()
var scene_data: Dictionary = {}
var bullets: Array = []
var vfx: Array = []
var shoot_cd := 0.0
var vfx_cd := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	_next_slide()

func _next_slide() -> void:
	slide_t = 0.0
	bullets.clear()
	vfx.clear()
	var maps := DB.maps
	var m: Dictionary = maps[rng.randi() % maxi(1, maps.size())] if not maps.is_empty() else {"id": "sands", "name": "Пустыня"}
	var mid := String(m.get("id", "sands"))
	var chars := DB.characters
	var ch: Dictionary = chars[rng.randi() % maxi(1, chars.size())] if not chars.is_empty() else {"cls": "paladin"}
	var hero_cls := String(ch.get("cls", "paladin"))
	var hero_pos := Vector2(rng.randf_range(120.0, 290.0), rng.randf_range(120.0, 250.0))

	# Собираем препятствия из биома
	var obs_list: Array = []
	var obs_defs: Array = m.get("obstacles", [])
	for i in 10:
		var sh := "rock"
		if not obs_defs.is_empty():
			var od: Dictionary = obs_defs[rng.randi() % obs_defs.size()]
			sh = String(od.get("shape", "rock"))
		obs_list.append({
			"shape": "obs_" + sh,
			"pos": Vector2(rng.randf_range(24.0, 616.0), rng.randf_range(24.0, 336.0)),
		})

	# Собираем врагов и босса биома
	var roster: Dictionary = m.get("roster", {})
	var fodder: Array = roster.get("fodder", ["slime", "skeleton_warrior", "bat"])
	var mob_list: Array = []
	for i in rng.randi_range(12, 18):
		var eid := String(fodder[rng.randi() % maxi(1, fodder.size())])
		var ang := rng.uniform(0.0, TAU)
		var dist := rng.randf_range(65.0, 240.0)
		mob_list.append({
			"id": eid,
			"pos": (hero_pos + Vector2(cos(ang), sin(ang)) * dist).clamp(Vector2(24, 24), Vector2(616, 336)),
			"spd": rng.randf_range(14.0, 28.0),
			"size": 24.0,
		})
	var boss_id := "boss_" + mid
	if not Assets.has_real_sprite(boss_id):
		boss_id = "boss_shemhaz"
	var b_ang := rng.uniform(0.0, TAU)
	var boss_pos := (hero_pos + Vector2(cos(b_ang), sin(b_ang)) * 135.0).clamp(Vector2(54, 54), Vector2(586, 306))

	# Кристаллы опыта на земле
	var xp_list: Array = []
	for i in 9:
		xp_list.append(Vector2(rng.randf_range(40.0, 600.0), rng.randf_range(40.0, 320.0)))

	var proj_kinds := ["projectile_fire", "projectile_arrow", "projectile_lightning", "projectile_spear", "projectile_dagger", "projectile_orb"]
	scene_data = {
		"map_id": mid,
		"map_name": String(m.get("name", mid)),
		"hero_cls": hero_cls,
		"hero_pos": hero_pos,
		"hero_vel": Vector2.RIGHT.rotated(rng.uniform(0.0, TAU)) * 22.0,
		"obs": obs_list,
		"mobs": mob_list,
		"boss_id": boss_id,
		"boss_pos": boss_pos,
		"xp": xp_list,
		"proj": proj_kinds[rng.randi() % proj_kinds.size()],
		"vfx_kind": ["lightning", "fireball", "smite", "meteor"][rng.randi() % 4],
	}

func _process(delta: float) -> void:
	t += delta
	slide_t += delta
	if slide_t >= SLIDE_DUR:
		_next_slide()
		return
	var hpos: Vector2 = scene_data.get("hero_pos", Vector2(200, 180))
	var hvel: Vector2 = scene_data.get("hero_vel", Vector2(20, 0))
	hpos += hvel * delta
	if hpos.x < 70.0 or hpos.x > 340.0:
		hvel.x = -hvel.x
	if hpos.y < 60.0 or hpos.y > 290.0:
		hvel.y = -hvel.y
	scene_data["hero_pos"] = hpos
	scene_data["hero_vel"] = hvel

	var mobs: Array = scene_data.get("mobs", [])
	for mb in mobs:
		var mp: Vector2 = mb["pos"]
		var d := hpos - mp
		if d.length() > 26.0:
			mp += d.normalized() * float(mb["spd"]) * delta
			mb["pos"] = mp

	var bpos: Vector2 = scene_data.get("boss_pos", Vector2(360, 160))
	var bd := hpos - bpos
	if bd.length() > 64.0:
		bpos += bd.normalized() * 12.0 * delta
		scene_data["boss_pos"] = bpos

	shoot_cd -= delta
	if shoot_cd <= 0.0:
		shoot_cd = 0.28
		var aim_target: Vector2 = bpos
		if not mobs.is_empty():
			aim_target = Vector2(mobs[rng.randi() % mobs.size()]["pos"])
		var dir: Vector2 = (aim_target - hpos).normalized()
		for k in [-0.15, 0.0, 0.15]:
			bullets.append({"pos": hpos, "vel": dir.rotated(k) * 210.0, "life": 1.4})

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] = Vector2(b["pos"]) + Vector2(b["vel"]) * delta
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			bullets.remove_at(i)

	vfx_cd -= delta
	if vfx_cd <= 0.0:
		vfx_cd = 0.65
		var vp: Vector2 = bpos if rng.randf() < 0.4 else (Vector2(mobs[rng.randi() % mobs.size()]["pos"]) if not mobs.is_empty() else hpos + Vector2(60, 0))
		vfx.append({"kind": String(scene_data.get("vfx_kind", "lightning")), "pos": vp, "t": 0.0, "dur": 0.48})

	for i in range(vfx.size() - 1, -1, -1):
		vfx[i]["t"] = float(vfx[i]["t"]) + delta
		if float(vfx[i]["t"]) >= float(vfx[i]["dur"]):
			vfx.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or scene_data.is_empty():
		return
	var fade := 1.0
	if slide_t < FADE_DUR:
		fade = slide_t / FADE_DUR
	elif slide_t > SLIDE_DUR - FADE_DUR:
		fade = (SLIDE_DUR - slide_t) / FADE_DUR
	fade = clampf(fade, 0.0, 1.0)
	var mod := Color(0.80, 0.80, 0.86, 0.88 * fade)

	# 1. Пол биома тайлами 64x64 с плавным дрейфом камеры
	var pan := Vector2(sin(slide_t * 0.45) * 14.0, cos(slide_t * 0.35) * 8.0)
	var tile_tex := Assets.tile(String(scene_data.get("map_id", "sands")))
	if tile_tex != null:
		for tx in range(-64, int(w) + 64, 64):
			for ty in range(-64, int(h) + 64, 64):
				draw_texture_rect(tile_tex, Rect2(Vector2(float(tx), float(ty)) + pan, Vector2(64, 64)), false, mod)

	# 2. Препятствия
	for ob in scene_data.get("obs", []):
		var otex := Assets.icon(String(ob["shape"]))
		if otex != null:
			var op: Vector2 = Vector2(ob["pos"]) + pan
			draw_texture_rect(otex, Rect2(op - Vector2(16, 16), Vector2(32, 32)), false, mod)

	# 3. Кристаллы опыта
	var xp_tex := Assets.icon("pickup_xp")
	if xp_tex != null:
		for xp_p in scene_data.get("xp", []):
			draw_texture_rect(xp_tex, Rect2(Vector2(xp_p) + pan - Vector2(7, 7), Vector2(14, 14)), false, mod)

	# 4. Враги (walk-кадры 32x32)
	var f_idx := int(t * 7.0)
	for mb in scene_data.get("mobs", []):
		var fr := Assets.frames(String(mb["id"]), "walk")
		var mtex: Texture2D = fr[f_idx % fr.size()] if not fr.is_empty() else Assets.icon(String(mb["id"]))
		if mtex != null:
			var mp: Vector2 = Vector2(mb["pos"]) + pan
			draw_texture_rect(mtex, Rect2(mp - Vector2(13, 13), Vector2(26, 26)), false, mod)

	# 5. Босс (64x64)
	var b_fr := Assets.frames(String(scene_data.get("boss_id", "boss_shemhaz")), "attack" if (int(t) % 3 == 0) else "walk")
	var btex: Texture2D = b_fr[f_idx % b_fr.size()] if not b_fr.is_empty() else Assets.icon(String(scene_data.get("boss_id", "boss_shemhaz")))
	if btex != null:
		var bp: Vector2 = Vector2(scene_data["boss_pos"]) + pan
		draw_texture_rect(btex, Rect2(bp - Vector2(32, 32), Vector2(64, 64)), false, mod)

	# 6. Герой (32x32)
	var h_fr := Assets.frames(String(scene_data.get("hero_cls", "paladin")), "walk")
	var htex: Texture2D = h_fr[f_idx % h_fr.size()] if not h_fr.is_empty() else Assets.icon(String(scene_data.get("hero_cls", "paladin")))
	if htex != null:
		var hp: Vector2 = Vector2(scene_data["hero_pos"]) + pan
		draw_texture_rect(htex, Rect2(hp - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 1, 1, fade))

	# 7. Снаряды
	var ptex := Assets.icon(String(scene_data.get("proj", "projectile_fire")))
	if ptex != null:
		for b in bullets:
			var bp2: Vector2 = Vector2(b["pos"]) + pan
			draw_texture_rect(ptex, Rect2(bp2 - Vector2(7, 7), Vector2(14, 14)), false, Color(1, 1, 1, fade))

	# 8. VFX перков и метеоритов
	for fx in vfx:
		var k := clampf(float(fx["t"]) / float(fx["dur"]), 0.0, 1.0)
		var fk := String(fx["kind"])
		var fi := mini(3, int(k * 4.0))
		var fp: Vector2 = Vector2(fx["pos"]) + pan
		var ftex: Texture2D = null
		if fk == "lightning":
			ftex = Assets.icon("vfx_lightning_%d" % fi)
			if ftex != null:
				draw_texture_rect(ftex, Rect2(fp - Vector2(16, 56), Vector2(32, 64)), false, Color(1, 1, 1, fade * (1.0 - k * 0.6)))
		elif fk == "smite":
			ftex = Assets.icon("vfx_smite_%d" % fi)
			if ftex != null:
				draw_texture_rect(ftex, Rect2(fp - Vector2(16, 56), Vector2(32, 64)), false, Color(1, 1, 1, fade * (1.0 - k * 0.6)))
		elif fk == "meteor":
			ftex = Assets.icon("event_meteor_%d" % fi)
			if ftex != null:
				var mp2 := fp + Vector2(-90, -120).lerp(Vector2.ZERO, k * k)
				draw_texture_rect(ftex, Rect2(mp2 - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, fade))
		else:
			ftex = Assets.icon("vfx_fireball_%d" % fi)
			if ftex != null:
				draw_texture_rect(ftex, Rect2(fp - Vector2(22, 22), Vector2(44, 44)), false, Color(1, 1, 1, fade * (1.0 - k * 0.5)))

	# Затемнение и виньетка, чтобы интерфейс меню отлично читался поверх боя
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.035, 0.05, 0.52))
	draw_rect(Rect2(342, 46, 272, 248), Color(0.02, 0.025, 0.035, 0.35))
