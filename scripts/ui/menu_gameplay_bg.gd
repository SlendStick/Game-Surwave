class_name MenuGameplayBg
extends Control
## Живое слайд-шоу реального геймплея на фоне главного меню.
## Использует те же ColorRect / TextureRect (STRETCH_TILE) / Sprite2D узлы,
## что и игровой мир, чтобы фон всегда рендерился чётко и без артефактов.

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

var bg_rect: ColorRect
var floor_rect: TextureRect
var world_layer: Node2D
var mobs_layer: Node2D
var actors_layer: Node2D
var fx_layer: Node2D
var popups_layer: Control
var fade_rect: ColorRect
var menu_scrim: ColorRect
var tag_lbl: Label

var obs_sprites: Array[Sprite2D] = []
var xp_sprites: Array[Sprite2D] = []
var mob_sprites: Array[Sprite2D] = []
var ally_sprites: Array[Sprite2D] = []
var bullet_sprites: Array[Sprite2D] = []
var ebullet_sprites: Array[Sprite2D] = []
var vfx_sprites: Array[Sprite2D] = []
var popup_labels: Array[Label] = []
var hero_sprite: Sprite2D
var boss_sprite: Sprite2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	UI.full_rect(self)
	if size.x < 10.0 or size.y < 10.0:
		size = Vector2(640.0, 360.0)
	rng.randomize()
	_build_layers()
	_next_slide()
	slide_t = FADE_DUR
	_sync_visuals()

func _build_layers() -> void:
	bg_rect = ColorRect.new()
	bg_rect.color = Color("#0c0c10")
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(bg_rect)
	add_child(bg_rect)

	floor_rect = TextureRect.new()
	floor_rect.position = Vector2(-64, -64)
	floor_rect.size = Vector2(768, 488)
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)

	world_layer = Node2D.new()
	add_child(world_layer)

	mobs_layer = Node2D.new()
	world_layer.add_child(mobs_layer)

	actors_layer = Node2D.new()
	world_layer.add_child(actors_layer)

	fx_layer = Node2D.new()
	world_layer.add_child(fx_layer)

	boss_sprite = _make_sprite(actors_layer, Vector2(72, 72))
	hero_sprite = _make_sprite(actors_layer, Vector2(28, 28))

	popups_layer = Control.new()
	popups_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(popups_layer)
	add_child(popups_layer)

	# Лёгкая атмосферная дымка и тёмная подложка под правой панелью меню
	var top_vignette := ColorRect.new()
	top_vignette.color = Color(0.015, 0.018, 0.025, 0.24)
	top_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(top_vignette)
	add_child(top_vignette)

	menu_scrim = ColorRect.new()
	menu_scrim.position = Vector2(342, 18)
	menu_scrim.size = Vector2(276, 324)
	menu_scrim.color = Color(0.015, 0.018, 0.026, 0.34)
	menu_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_scrim)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.035, 0.045, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(fade_rect)
	add_child(fade_rect)

	tag_lbl = UI.crisp_label(self, "", 8, Color(0.92, 0.85, 0.68, 0.88), Vector2(20, 336))
	tag_lbl.size = Vector2(300, 16)

func _make_sprite(parent: Node, target_sz: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.set_meta("target_sz", target_sz)
	parent.add_child(sp)
	return sp

func _set_sprite_tex(sp: Sprite2D, tex: Texture2D, mod_col: Color = Color.WHITE) -> void:
	if tex == null:
		sp.visible = false
		return
	sp.visible = true
	sp.texture = tex
	sp.modulate = mod_col
	var tsz: Vector2 = sp.get_meta("target_sz", Vector2(24, 24))
	var tw := maxf(1.0, float(tex.get_width()))
	var th := maxf(1.0, float(tex.get_height()))
	sp.scale = Vector2(tsz.x / tw, tsz.y / th)

func _ensure_sprite_pool(pool: Array[Sprite2D], parent: Node, needed: int, target_sz: Vector2) -> void:
	while pool.size() < needed:
		pool.append(_make_sprite(parent, target_sz))

func _next_slide() -> void:
	slide_t = 0.0
	bullets.clear()
	ebullets.clear()
	vfx.clear()
	popups.clear()
	var maps := DB.maps
	var m: Dictionary = maps[rng.randi() % maxi(1, maps.size())] if not maps.is_empty() else {"id": "sands", "name": "Выжженные Пески"}
	var mid := String(m.get("id", "sands"))
	var chars := DB.characters
	var ch: Dictionary = chars[rng.randi() % maxi(1, chars.size())] if not chars.is_empty() else {"cls": "paladin", "name": "Сэр Гаван"}
	var hero_cls := String(ch.get("cls", "paladin"))
	var hero_pos := Vector2(rng.randf_range(120.0, 270.0), rng.randf_range(125.0, 245.0))

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

	var ally_kinds := ["ally_spirit", "ally_dragon", "ally_scythe", "ally_skeleton", "ally_spear"]
	var ally_list: Array = []
	for i in rng.randi_range(2, 4):
		ally_list.append({
			"id": ally_kinds[rng.randi() % ally_kinds.size()],
			"angle": float(i) * TAU / 3.0,
			"dist": rng.randf_range(26.0, 52.0),
		})

	var xp_list: Array = []
	for i in 12:
		xp_list.append({
			"pos": Vector2(rng.randf_range(40.0, 600.0), rng.randf_range(40.0, 320.0)),
			"kind": "pickup_gold" if (i % 4 == 0) else "pickup_xp",
		})

	var proj_kinds := ["projectile_fire", "projectile_arrow", "projectile_lightning", "projectile_spear", "projectile_dagger", "projectile_orb", "projectile_ice"]
	var vfx_pool := ["lightning", "fireball", "smite", "frost", "curse", "holy", "wind", "blood", "meteor"]
	var va: String = vfx_pool[rng.randi() % vfx_pool.size()]
	var vb: String = vfx_pool[rng.randi() % vfx_pool.size()]
	scene_data = {
		"map_id": mid,
		"map_name": String(m.get("name", mid)),
		"bg_color": Gfx.hex(String(m.get("palette", {}).get("bg", "#101218"))).darkened(0.18),
		"accent_color": Gfx.hex(String(m.get("palette", {}).get("accent", "#9c834c"))),
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
		"vfx_a": va,
		"vfx_b": vb,
	}
	var aim0: Vector2 = (boss_pos - hero_pos).normalized()
	for k in [-0.20, 0.0, 0.20]:
		var bdir := aim0.rotated(float(k))
		bullets.append({"pos": hero_pos + bdir * 34.0, "vel": bdir * 230.0, "life": 1.15})
	vfx.append({"kind": va, "pos": boss_pos, "t": 0.08, "dur": 0.48})
	if not mob_list.is_empty():
		var mp0: Vector2 = mob_list[0]["pos"]
		vfx.append({"kind": vb, "pos": mp0, "t": 0.04, "dur": 0.48})
		popups.append({"pos": mp0 + Vector2(0, -14), "txt": "48!", "crit": true, "t": 0.05, "dur": 0.65})
	shoot_cd = 0.14
	eshoot_cd = 0.25
	vfx_cd = 0.20

	var bg_col: Color = scene_data["bg_color"]
	bg_col.a = 1.0
	bg_rect.color = bg_col
	var ttex := Assets.tile(mid)
	floor_rect.texture = ttex
	floor_rect.visible = ttex != null
	floor_rect.modulate = Color(0.90, 0.90, 0.94, 0.92)
	tag_lbl.text = "%s · %s" % [String(scene_data.get("map_name", "")), String(scene_data.get("hero_name", ""))]

func _process(delta: float) -> void:
	t += delta
	slide_t += delta
	if slide_t >= SLIDE_DUR:
		_next_slide()
		_sync_visuals()
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
			bullets.append({"pos": hpos, "vel": dir.rotated(float(k)) * 230.0, "life": 1.35})

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

	_sync_visuals()

func _sync_visuals() -> void:
	if scene_data.is_empty():
		return
	var fade := 1.0
	if slide_t < FADE_DUR:
		fade = slide_t / FADE_DUR
	elif slide_t > SLIDE_DUR - FADE_DUR:
		fade = (SLIDE_DUR - slide_t) / FADE_DUR
	fade = clampf(fade, 0.0, 1.0)
	var pan := Vector2(sin(slide_t * 0.45) * 14.0, cos(slide_t * 0.35) * 8.0)
	floor_rect.position = Vector2(-64, -64) + pan
	world_layer.position = pan
	fade_rect.color = Color(0.03, 0.035, 0.045, 1.0 - fade)
	tag_lbl.modulate.a = fade

	var obs: Array = scene_data.get("obs", [])
	_ensure_sprite_pool(obs_sprites, mobs_layer, obs.size(), Vector2(32, 32))
	for i in obs_sprites.size():
		if i < obs.size():
			var ob: Dictionary = obs[i]
			obs_sprites[i].position = Vector2(ob["pos"])
			_set_sprite_tex(obs_sprites[i], Assets.icon(String(ob["shape"])))
		else:
			obs_sprites[i].visible = false

	var xp_list: Array = scene_data.get("xp", [])
	_ensure_sprite_pool(xp_sprites, mobs_layer, xp_list.size(), Vector2(14, 14))
	for i in xp_sprites.size():
		if i < xp_list.size():
			var xp_item: Dictionary = xp_list[i]
			xp_sprites[i].position = Vector2(xp_item["pos"])
			_set_sprite_tex(xp_sprites[i], Assets.icon(String(xp_item["kind"])))
		else:
			xp_sprites[i].visible = false

	var f_idx := int(t * 7.0)
	var mobs: Array = scene_data.get("mobs", [])
	_ensure_sprite_pool(mob_sprites, mobs_layer, mobs.size(), Vector2(26, 26))
	var hpos: Vector2 = scene_data.get("hero_pos", Vector2(200, 180))
	for i in mob_sprites.size():
		if i < mobs.size():
			var mb: Dictionary = mobs[i]
			var fr := Assets.frames(String(mb["id"]), "walk")
			var mtex: Texture2D = fr[f_idx % fr.size()] if not fr.is_empty() else Assets.icon(String(mb["id"]))
			var mp: Vector2 = Vector2(mb["pos"])
			mob_sprites[i].position = mp
			mob_sprites[i].flip_h = hpos.x < mp.x
			_set_sprite_tex(mob_sprites[i], mtex)
		else:
			mob_sprites[i].visible = false

	var bid := String(scene_data.get("boss_id", "boss_shemhaz"))
	var b_fr := Assets.frames(bid, "attack" if (int(t) % 3 == 0) else "walk")
	var btex: Texture2D = b_fr[f_idx % b_fr.size()] if not b_fr.is_empty() else Assets.icon(bid)
	var bpos: Vector2 = Vector2(scene_data.get("boss_pos", Vector2(360, 160)))
	boss_sprite.position = bpos
	boss_sprite.flip_h = hpos.x < bpos.x
	_set_sprite_tex(boss_sprite, btex)

	var allies: Array = scene_data.get("allies", [])
	_ensure_sprite_pool(ally_sprites, actors_layer, allies.size(), Vector2(20, 20))
	for i in ally_sprites.size():
		if i < allies.size():
			var al: Dictionary = allies[i]
			var ang := float(al["angle"]) + t * 2.1
			ally_sprites[i].position = hpos + Vector2(cos(ang), sin(ang)) * float(al["dist"])
			_set_sprite_tex(ally_sprites[i], Assets.icon(String(al["id"])))
		else:
			ally_sprites[i].visible = false

	var hcls := String(scene_data.get("hero_cls", "paladin"))
	var h_fr := Assets.frames(hcls, "walk")
	var htex: Texture2D = h_fr[f_idx % h_fr.size()] if not h_fr.is_empty() else Assets.icon(hcls)
	hero_sprite.position = hpos
	hero_sprite.flip_h = float(Vector2(scene_data.get("hero_vel", Vector2.RIGHT)).x) < 0.0
	_set_sprite_tex(hero_sprite, htex)

	var ptex := Assets.icon(String(scene_data.get("proj", "projectile_fire")))
	_ensure_sprite_pool(bullet_sprites, fx_layer, bullets.size(), Vector2(14, 14))
	for i in bullet_sprites.size():
		if i < bullets.size():
			bullet_sprites[i].position = Vector2(bullets[i]["pos"])
			bullet_sprites[i].rotation = Vector2(bullets[i]["vel"]).angle()
			_set_sprite_tex(bullet_sprites[i], ptex)
		else:
			bullet_sprites[i].visible = false

	var eptex := Assets.icon("projectile_enemy")
	_ensure_sprite_pool(ebullet_sprites, fx_layer, ebullets.size(), Vector2(10, 10))
	for i in ebullet_sprites.size():
		if i < ebullets.size():
			ebullet_sprites[i].position = Vector2(ebullets[i]["pos"])
			_set_sprite_tex(ebullet_sprites[i], eptex, Color(1, 0.72, 0.72, 0.92))
		else:
			ebullet_sprites[i].visible = false

	_ensure_sprite_pool(vfx_sprites, fx_layer, vfx.size(), Vector2(40, 40))
	for i in vfx_sprites.size():
		if i < vfx.size():
			var fx: Dictionary = vfx[i]
			var k := clampf(float(fx["t"]) / float(fx["dur"]), 0.0, 1.0)
			var fk := String(fx["kind"])
			var fi := mini(3, int(k * 4.0))
			var fi3 := mini(2, int(k * 3.0))
			var fp: Vector2 = Vector2(fx["pos"])
			var alpha := 1.0 - k * 0.55
			var ft: Texture2D = null
			var tsz := Vector2(36, 36)
			var pos_out := fp
			match fk:
				"lightning":
					ft = Assets.icon("vfx_lightning_%d" % fi)
					tsz = Vector2(32, 64)
					pos_out = fp - Vector2(0, 24)
				"smite":
					ft = Assets.icon("vfx_smite_%d" % fi)
					tsz = Vector2(32, 64)
					pos_out = fp - Vector2(0, 24)
				"frost":
					ft = Assets.icon("vfx_frost_%d" % fi3)
				"curse":
					ft = Assets.icon("vfx_curse_%d" % fi)
					tsz = Vector2(40, 40)
				"holy":
					ft = Assets.icon("vfx_holy_%d" % fi)
					tsz = Vector2(40, 40)
				"wind":
					ft = Assets.icon("vfx_wind_%d" % fi3)
				"blood":
					ft = Assets.icon("vfx_blood_%d" % fi3)
				"meteor":
					ft = Assets.icon("event_meteor_%d" % fi)
					pos_out = fp + Vector2(-90, -120).lerp(Vector2.ZERO, k * k)
					alpha = 1.0
				_:
					ft = Assets.icon("vfx_fireball_%d" % fi)
					tsz = Vector2(44, 44)
			vfx_sprites[i].set_meta("target_sz", tsz)
			vfx_sprites[i].position = pos_out
			_set_sprite_tex(vfx_sprites[i], ft, Color(1, 1, 1, alpha))
		else:
			vfx_sprites[i].visible = false

	while popup_labels.size() < popups.size():
		var pl := UI.crisp_label(popups_layer, "", 9, Color.WHITE)
		popup_labels.append(pl)
	for i in popup_labels.size():
		if i < popups.size():
			var pop: Dictionary = popups[i]
			var pk := clampf(float(pop["t"]) / float(pop["dur"]), 0.0, 1.0)
			var pl := popup_labels[i]
			pl.visible = true
			pl.text = String(pop["txt"])
			pl.position = Vector2(pop["pos"]) + pan
			pl.add_theme_font_size_override("font_size", 10 if bool(pop["crit"]) else 8)
			var pcol := Color(1.0, 0.85, 0.30, (1.0 - pk) * fade) if bool(pop["crit"]) else Color(0.95, 0.90, 0.82, (1.0 - pk) * fade)
			pl.add_theme_color_override("font_color", pcol)
		else:
			popup_labels[i].visible = false
