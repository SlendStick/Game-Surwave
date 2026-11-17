class_name MenuGameplayBg
extends Control
## Случайно генерируемое живое слайд-шоу реального геймплея игры на фоне главного меню.
## Показывает разные карты, персонажей, врагов, боссов, призывы и анимации перков.

const SLIDE_DUR := 5.8
const FADE_DUR := 0.75

var t := 0.0
var slide_t := 0.0
var rng := RandomNumberGenerator.new()
var scene_data: Dictionary = {}
var bullets: Array = []
var ebullets: Array = []
var vfx: Array = []
var popups: Array = []
var shoot_cd := 0.0
var eshoot_cd := 0.0
var vfx_cd := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	_next_slide()

func _next_slide() -> void:
	slide_t = 0.0
	bullets.clear()
	ebullets.clear()
	vfx.clear()
	popups.clear()
	var maps := DB.maps
	var m: Dictionary = maps[rng.randi() % maxi(1, maps.size())] if not maps.is_empty() else {"id": "sands", "name": "Пустыня"}
	var mid := String(m.get("id", "sands"))
	var chars := DB.characters
	var ch: Dictionary = chars[rng.randi() % maxi(1, chars.size())] if not chars.is_empty() else {"cls": "paladin", "name": "Сэр Гаван"}
	var hero_cls := String(ch.get("cls", "paladin"))
	var hero_pos := Vector2(rng.randf_range(120.0, 270.0), rng.randf_range(125.0, 245.0))

	# Препятствия в теме карты
	var obs_list: Array = []
	var obs_defs: Array = m.get("obstacles", [])
	for i in 12:
		var sh := "rock"
		if not obs_defs.is_empty():
			var od: Dictionary = obs_defs[rng.randi() % obs_defs.size()]
			sh = String(od.get("shape", "rock"))
		var themed_obs := "obs_%s__%s" % [sh, mid]
		obs_list.append({
			"shape": themed_obs if Assets.has_real_sprite(themed_obs) else ("obs_" + sh),
			"pos": Vector2(rng.randf_range(24.0, 616.0), rng.randf_range(24.0, 336.0)),
		})

	# Враги с карточными скинами и босс биома
	var roster: Dictionary = m.get("roster", {})
	var fodder: Array = roster.get("fodder", ["slime", "skeleton_warrior", "bat"])
	var shooters: Array = roster.get("shooter", [])
	var pool_ids: Array = fodder.duplicate()
	pool_ids.append_array(shooters)
	var mob_list: Array = []
	for i in rng.randi_range(14, 22):
		var eid := String(pool_ids[rng.randi() % maxi(1, pool_ids.size())])
		var themed_eid := "%s__%s" % [eid, mid]
		var vis_eid := themed_eid if Assets.has_real_sprite(themed_eid) else eid
		var ang: float = rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(62.0, 245.0)
		mob_list.append({
			"id": vis_eid,
			"pos": (hero_pos + Vector2(cos(ang), sin(ang)) * dist).clamp(Vector2(24, 24), Vector2(616, 336)),
			"spd": rng.randf_range(15.0, 30.0),
		})
	var boss_id := "boss_" + mid
	if mid == "void":
		boss_id = "boss_satanail"
	if not Assets.has_real_sprite(boss_id):
		boss_id = "boss_shemhaz"
	var b_ang: float = rng.randf_range(-0.9, 0.9)
	var boss_pos := (hero_pos + Vector2(cos(b_ang), sin(b_ang)) * 135.0).clamp(Vector2(64, 64), Vector2(560, 290))

	# Призывы / союзники рядом с героем
	var ally_kinds := ["ally_spirit", "ally_dragon", "ally_scythe", "ally_skeleton", "ally_spear"]
	var ally_list: Array = []
	for i in rng.randi_range(2, 4):
		ally_list.append({
			"id": ally_kinds[rng.randi() % ally_kinds.size()],
			"angle": float(i) * TAU / 3.0,
			"dist": rng.randf_range(26.0, 52.0),
		})

	# Кристаллы опыта и золота
	var xp_list: Array = []
	for i in 12:
		xp_list.append({
			"pos": Vector2(rng.randf_range(40.0, 600.0), rng.randf_range(40.0, 320.0)),
			"kind": "pickup_gold" if (i % 4 == 0) else "pickup_xp",
		})

	var proj_kinds := ["projectile_fire", "projectile_arrow", "projectile_lightning", "projectile_spear", "projectile_dagger", "projectile_orb", "projectile_ice"]
	var vfx_pool := ["lightning", "fireball", "smite", "frost", "curse", "holy", "wind", "blood", "meteor"]
	scene_data = {
		"map_id": mid,
		"map_name": String(m.get("name", mid)),
		"hero_name": String(ch.get("name", hero_cls)),
		"hero_cls": hero_cls,
		"hero_pos": hero_pos,
		"hero_vel": Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * 24.0,
		"obs": obs_list,
		"mobs": mob_list,
		"allies": ally_list,
		"boss_id": boss_id,
		"boss_pos": boss_pos,
		"xp": xp_list,
		"proj": proj_kinds[rng.randi() % proj_kinds.size()],
		"vfx_a": vfx_pool[rng.randi() % vfx_pool.size()],
		"vfx_b": vfx_pool[rng.randi() % vfx_pool.size()],
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
	if hpos.x < 70.0 or hpos.x > 330.0:
		hvel.x = -hvel.x
	if hpos.y < 64.0 or hpos.y > 282.0:
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
	if bd.length() > 68.0:
		bpos += bd.normalized() * 14.0 * delta
		scene_data["boss_pos"] = bpos

	shoot_cd -= delta
	if shoot_cd <= 0.0:
		shoot_cd = 0.24
		var aim_target: Vector2 = bpos
		if not mobs.is_empty() and rng.randf() < 0.7:
			aim_target = Vector2(mobs[rng.randi() % mobs.size()]["pos"])
		var dir: Vector2 = (aim_target - hpos).normalized()
		for k in [-0.18, 0.0, 0.18]:
			bullets.append({"pos": hpos, "vel": dir.rotated(k) * 230.0, "life": 1.35})

	eshoot_cd -= delta
	if eshoot_cd <= 0.0:
		eshoot_cd = 1.15
		for k in 6:
			var a := t + TAU * float(k) / 6.0
			ebullets.append({"pos": bpos, "vel": Vector2(cos(a), sin(a)) * 88.0, "life": 2.2})

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] = Vector2(b["pos"]) + Vector2(b["vel"]) * delta
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			bullets.remove_at(i)

	for i in range(ebullets.size() - 1, -1, -1):
		var eb: Dictionary = ebullets[i]
		eb["pos"] = Vector2(eb["pos"]) + Vector2(eb["vel"]) * delta
		eb["life"] = float(eb["life"]) - delta
		if float(eb["life"]) <= 0.0:
			ebullets.remove_at(i)

	vfx_cd -= delta
	if vfx_cd <= 0.0:
		vfx_cd = 0.52
		var vp: Vector2 = bpos if rng.randf() < 0.35 else (Vector2(mobs[rng.randi() % mobs.size()]["pos"]) if not mobs.is_empty() else hpos + Vector2(60, 0))
		var fk := String(scene_data.get("vfx_a", "lightning")) if rng.randf() < 0.6 else String(scene_data.get("vfx_b", "fireball"))
		vfx.append({"kind": fk, "pos": vp, "t": 0.0, "dur": 0.48})
		if popups.size() < 10:
			var is_c := rng.randf() < 0.35
			popups.append({
				"pos": vp + Vector2(rng.randf_range(-8, 8), -14),
				"txt": ("%d!" % rng.randi_range(24, 96)) if is_c else str(rng.randi_range(8, 28)),
				"crit": is_c,
				"t": 0.0,
				"dur": 0.65,
			})

	for i in range(vfx.size() - 1, -1, -1):
		vfx[i]["t"] = float(vfx[i]["t"]) + delta
		if float(vfx[i]["t"]) >= float(vfx[i]["dur"]):
			vfx.remove_at(i)

	for i in range(popups.size() - 1, -1, -1):
		popups[i]["t"] = float(popups[i]["t"]) + delta
		popups[i]["pos"] = Vector2(popups[i]["pos"]) + Vector2(0, -18.0 * delta)
		if float(popups[i]["t"]) >= float(popups[i]["dur"]):
			popups.remove_at(i)
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
	var mod := Color(0.84, 0.84, 0.90, 0.90 * fade)

	var pan := Vector2(sin(slide_t * 0.45) * 14.0, cos(slide_t * 0.35) * 8.0)
	var tile_tex := Assets.tile(String(scene_data.get("map_id", "sands")))
	if tile_tex != null:
		for tx in range(-64, int(w) + 64, 64):
			for ty in range(-64, int(h) + 64, 64):
				draw_texture_rect(tile_tex, Rect2(Vector2(float(tx), float(ty)) + pan, Vector2(64, 64)), false, mod)

	for ob in scene_data.get("obs", []):
		var otex := Assets.icon(String(ob["shape"]))
		if otex != null:
			var op: Vector2 = Vector2(ob["pos"]) + pan
			draw_texture_rect(otex, Rect2(op - Vector2(16, 16), Vector2(32, 32)), false, mod)

	for xp_item in scene_data.get("xp", []):
		var xtex := Assets.icon(String(xp_item["kind"]))
		if xtex != null:
			draw_texture_rect(xtex, Rect2(Vector2(xp_item["pos"]) + pan - Vector2(7, 7), Vector2(14, 14)), false, mod)

	var f_idx := int(t * 7.0)
	for mb in scene_data.get("mobs", []):
		var fr := Assets.frames(String(mb["id"]), "walk")
		var mtex: Texture2D = fr[f_idx % fr.size()] if not fr.is_empty() else Assets.icon(String(mb["id"]))
		if mtex != null:
			var mp: Vector2 = Vector2(mb["pos"]) + pan
			draw_texture_rect(mtex, Rect2(mp - Vector2(13, 13), Vector2(26, 26)), false, mod)

	var b_fr := Assets.frames(String(scene_data.get("boss_id", "boss_shemhaz")), "attack" if (int(t) % 3 == 0) else "walk")
	var btex: Texture2D = b_fr[f_idx % b_fr.size()] if not b_fr.is_empty() else Assets.icon(String(scene_data.get("boss_id", "boss_shemhaz")))
	if btex != null:
		var bp: Vector2 = Vector2(scene_data["boss_pos"]) + pan
		draw_texture_rect(btex, Rect2(bp - Vector2(36, 36), Vector2(72, 72)), false, mod)

	var hpos: Vector2 = scene_data["hero_pos"]
	for al in scene_data.get("allies", []):
		var atex := Assets.icon(String(al["id"]))
		if atex != null:
			var ang := float(al["angle"]) + t * 2.1
			var ap := hpos + Vector2(cos(ang), sin(ang)) * float(al["dist"]) + pan
			draw_texture_rect(atex, Rect2(ap - Vector2(10, 10), Vector2(20, 20)), false, mod)

	var h_fr := Assets.frames(String(scene_data.get("hero_cls", "paladin")), "walk")
	var htex: Texture2D = h_fr[f_idx % h_fr.size()] if not h_fr.is_empty() else Assets.icon(String(scene_data.get("hero_cls", "paladin")))
	if htex != null:
		var hp: Vector2 = hpos + pan
		draw_texture_rect(htex, Rect2(hp - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 1, 1, fade))

	var ptex := Assets.icon(String(scene_data.get("proj", "projectile_fire")))
	if ptex != null:
		for b in bullets:
			var bp2: Vector2 = Vector2(b["pos"]) + pan
			draw_texture_rect(ptex, Rect2(bp2 - Vector2(7, 7), Vector2(14, 14)), false, Color(1, 1, 1, fade))

	var eptex := Assets.icon("projectile_enemy")
	if eptex != null:
		for eb in ebullets:
			var ep2: Vector2 = Vector2(eb["pos"]) + pan
			draw_texture_rect(eptex, Rect2(ep2 - Vector2(5, 5), Vector2(10, 10)), false, Color(1, 0.7, 0.7, fade * 0.9))

	for fx in vfx:
		var k := clampf(float(fx["t"]) / float(fx["dur"]), 0.0, 1.0)
		var fk := String(fx["kind"])
		var fi := mini(3, int(k * 4.0))
		var fi3 := mini(2, int(k * 3.0))
		var fp: Vector2 = Vector2(fx["pos"]) + pan
		var alpha := fade * (1.0 - k * 0.55)
		match fk:
			"lightning":
				var ft := Assets.icon("vfx_lightning_%d" % fi)
				if ft != null:
					draw_texture_rect(ft, Rect2(fp - Vector2(16, 56), Vector2(32, 64)), false, Color(1, 1, 1, alpha))
			"smite":
				var ft2 := Assets.icon("vfx_smite_%d" % fi)
				if ft2 != null:
					draw_texture_rect(ft2, Rect2(fp - Vector2(16, 56), Vector2(32, 64)), false, Color(1, 1, 1, alpha))
			"frost":
				var ft3 := Assets.icon("vfx_frost_%d" % fi3)
				if ft3 != null:
					draw_texture_rect(ft3, Rect2(fp - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, alpha))
			"curse":
				var ft4 := Assets.icon("vfx_curse_%d" % fi)
				if ft4 != null:
					draw_texture_rect(ft4, Rect2(fp - Vector2(20, 20), Vector2(40, 40)), false, Color(1, 1, 1, alpha))
			"holy":
				var ft5 := Assets.icon("vfx_holy_%d" % fi)
				if ft5 != null:
					draw_texture_rect(ft5, Rect2(fp - Vector2(20, 20), Vector2(40, 40)), false, Color(1, 1, 1, alpha))
			"wind":
				var ft6 := Assets.icon("vfx_wind_%d" % fi3)
				if ft6 != null:
					draw_texture_rect(ft6, Rect2(fp - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, alpha))
			"blood":
				var ft7 := Assets.icon("vfx_blood_%d" % fi3)
				if ft7 != null:
					draw_texture_rect(ft7, Rect2(fp - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, alpha))
			"meteor":
				var ft8 := Assets.icon("event_meteor_%d" % fi)
				if ft8 != null:
					var mp2 := fp + Vector2(-90, -120).lerp(Vector2.ZERO, k * k)
					draw_texture_rect(ft8, Rect2(mp2 - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, fade))
			_:
				var ft9 := Assets.icon("vfx_fireball_%d" % fi)
				if ft9 != null:
					draw_texture_rect(ft9, Rect2(fp - Vector2(22, 22), Vector2(44, 44)), false, Color(1, 1, 1, alpha))

	var font := UI.crisp_font()
	for pop in popups:
		var pk := clampf(float(pop["t"]) / float(pop["dur"]), 0.0, 1.0)
		var pcol := Color(1.0, 0.85, 0.30, (1.0 - pk) * fade) if bool(pop["crit"]) else Color(0.95, 0.90, 0.82, (1.0 - pk) * fade)
		draw_string(font, Vector2(pop["pos"]) + pan, String(pop["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10 if bool(pop["crit"]) else 8, pcol)

	# Мягкое готическое затемнение по краям для читаемости интерфейса
	draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.03, 0.045, 0.48))
	draw_rect(Rect2(342, 46, 272, 248), Color(0.02, 0.025, 0.035, 0.42))
	var tag := "%s · %s" % [String(scene_data.get("map_name", "")), String(scene_data.get("hero_name", ""))]
	draw_string(font, Vector2(32, 290), tag, HORIZONTAL_ALIGNMENT_LEFT, 260, 8, Color(0.82, 0.76, 0.62, 0.72 * fade))
