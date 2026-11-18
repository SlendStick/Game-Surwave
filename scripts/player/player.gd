class_name Player
extends CharacterBody2D
## Игрок: движение, ручная стрельба и перезарядка, скилл персонажа, статусы,
## проки перков/синергий/печатей/амулетов.

signal died

var game: Node = null
var char_data: Dictionary = {}
var weapon: Dictionary = {}
var upg: UpgradeSystem
var S: Dictionary = {}

var hp: int = 3
var max_hp: int = 3
var level: int = 1

var aim_dir := Vector2.RIGHT
var aim_pos := Vector2.ZERO
var move_input := Vector2.ZERO

# оружие
var mag: int = 6
var reloading := false
var reload_left := 0.0
var reload_total := 1.0
var fire_cd := 0.0
var shots_fired := 0
var standing_bonus := 0.0
var moving_now := false
var stuck_arrows: Array = []
var weapon_level := 1
var weapon_xp := 0.0
var holy_hits := 0
var reload_shot_ready := true
var summon_cd := 0.0
var aura_cd := 0.0
var harvest_left := 0.0
var harvest_zones := 0
var combo_hits := 0
var dash_buff_double := false
var berserk_left := 0.0
var aimed_left := 0.0
var auto_aim := false
var since_last_shot := 99.0

# скилл
var skill_cd_left := 0.0
var skill_data: Dictionary = {}

# статусы и таймеры
var iframes := 0.0
var statuses: Dictionary = {}
var timers: Dictionary = {}
var stacks: Dictionary = {}

var shield_charges := 0
var shield_recharge_left := 0.0
var revives_left := 0
var guardian_used := false
var bodiless_left := 0.0
var free_ammo := false

var kills := 0
var kills_retribution := 0
var kills_curse := 0
var souls_collected := 0
var soul_convert_pending := 0
var soul_convert_left := 0.0

var sprite: Sprite2D = null
var marker: Sprite2D = null
var shield_ring: Sprite2D = null
var muzzle: Sprite2D = null
var hp_bar: Sprite2D = null
var ammo_pips: Array = []
var hp_marks: Array = []
var bot := false
var bot_wants_fire := true
var dead := false
var world_speed_mult := 1.0
var inf_ammo := false
var terrain_mult := 1.0
var damage_dealt := 0.0
var damage_taken := 0.0

func setup(char_id: String, weapon_id: String, upgrade_system: UpgradeSystem) -> void:
	char_data = DB.character(char_id)
	weapon = DB.weapon(weapon_id)
	upg = upgrade_system
	skill_data = char_data.get("skill", {})
	bot = GameManager.autoplay
	_apply_amulets()
	if String(char_data.get("passive", {}).get("id", "")) == "celestial_shield" or upg.flag_on("shield"):
		shield_charges = 1
	weapon_level = 1
	weapon_xp = 0.0
	recalc()
	hp = max_hp
	mag = int(S.mag)
	revives_left = int(upg.flag_num("amulet_revive", 0.0))
	aim_pos = global_position + Vector2.RIGHT * 40.0

func _apply_amulets() -> void:
	var mode_cfg := DB.mode_config(String(GameManager.run_config.get("mode", "standard")))
	var bonuses: Array = GameManager.amulet_bonuses() if bool(mode_cfg.get("amulets", true)) else []
	for b in bonuses:
		var rank := float(b["rank"])
		var per := float(b["per_rank"])
		match String(b["id"]):
			"amu_echo": upg.apply_flags({"last_shot_echo": per * rank})
			"amu_bodiless": upg.apply_flags({"bodiless_kills": 50, "bodiless_dur": per * rank})
			"amu_rhythm": upg.apply_flags({"rhythm_pierce": per * rank})
			"amu_courage": upg.apply_mods({"mag": per * rank})
			"amu_fortress": upg.apply_flags({"highhp_damage": per * rank})
			"amu_fragility":
				upg.apply_mods({"dmg": per * rank, "hp": -rank})
			"amu_spark": upg.apply_flags({"spark_chance": per * rank})
			"amu_frost": upg.apply_mods({"freeze_chance": per * rank})
			"amu_agility": upg.apply_mods({"dodge": per * rank})
			"amu_foresight": upg.apply_mods({"vision": per * rank})
			"amu_growth": upg.apply_flags({"amulet_growth": rank})
			"amu_endurance": upg.apply_mods({"hp": per * rank})
			"amu_recovery": upg.apply_flags({"amulet_start_heal": per * rank})
			"amu_soulbond": upg.apply_flags({"amulet_revive": per * rank})
			"amu_bulwark": upg.apply_mods({"dr": per * rank})
			"amu_secondwind": upg.apply_flags({"lowhp_speed": per * rank})

func recalc() -> void:
	var base: Dictionary = DB.balance.get("player", {})
	var add := upg.add
	var old_max := max_hp
	S = {}
	S.max_hp = maxi(1, int(char_data.get("hp", 3)) + int(add.get("hp", 0)))
	# --- уровни оружия (1..8) по WEAPONS_COMPLETE_SPECIFICATION.md
	var w_dmg := float(weapon.get("damage", 2.0))
	var w_rate := float(weapon.get("fire_rate", 2.0))
	var w_proj := int(weapon.get("projectiles", 1))
	var w_pierce := int(weapon.get("pierce", 0))
	var w_speed := float(weapon.get("proj_speed", 240.0))
	var w_spread := float(weapon.get("spread", 0.0))
	var w_burn := 0.0
	var lvls: Array = weapon.get("levels", [])
	for i in range(1, mini(weapon_level, lvls.size())):
		var lm: Dictionary = lvls[i]
		w_dmg *= 1.0 + float(lm.get("dmg", 0.0))
		w_rate *= 1.0 + float(lm.get("fire_rate", 0.0))
		w_proj += int(lm.get("proj", 0))
		w_pierce += int(lm.get("pierce", 0))
		w_burn += float(lm.get("burn_dps", 0.0))
	# эволюция полностью заменяет базовые характеристики
	if upg.evolution_done and not upg.weapon_evolution.is_empty():
		var ev: Dictionary = upg.weapon_evolution
		w_dmg = float(ev.get("damage", w_dmg))
		w_rate = float(ev.get("fire_rate", w_rate))
		w_proj = int(ev.get("projectiles", w_proj))
		w_spread = float(ev.get("spread", w_spread))
		if ev.has("proj_speed"):
			w_speed = float(ev["proj_speed"])
		w_pierce = int(ev.get("pierce", w_pierce))
		w_burn = float(ev.get("burn_dps", 0.0))
	S.damage = w_dmg * (1.0 + float(add.get("dmg", 0.0))) + float(add.get("flat_dmg", 0.0))
	S.fire_rate = maxf(0.2, w_rate * (1.0 + float(add.get("fire_rate", 0.0))))
	S.reload_time = maxf(0.12, float(weapon.get("reload", 1.0)) / maxf(0.15, 1.0 + float(add.get("reload", 0.0))))
	S.mag = maxi(1, int(round((float(weapon.get("mag", 6)) + float(add.get("mag", 0.0))) * (1.0 + float(add.get("mag_pct", 0.0))))))
	S.projectiles = maxi(1, w_proj + int(add.get("proj", 0)))
	S.pierce = maxi(0, w_pierce + int(add.get("pierce", 0)))
	S.bounce = maxi(0, int(weapon.get("bounce", 0)) + int(add.get("bounce", 0)))
	S.proj_speed = w_speed * (1.0 + float(add.get("proj_speed", 0.0)))
	S.weapon_burn = w_burn
	S.spread = maxf(0.0, w_spread + float(add.get("spread", 0.0)))
	if upg.flag_on("shield") and not has_meta("shield_perk_init"):
		set_meta("shield_perk_init", true)
		shield_charges = maxi(1, shield_charges)
		shield_recharge_left = 0.0
	S.move_speed = float(base.get("move_speed", 140.0)) * (1.0 + float(add.get("move_speed", 0.0))) * (1.0 + float(add.get("move_speed_mult", 0.0)))
	S.pickup = float(base.get("pickup_range", 64.0)) * (1.0 + float(add.get("pickup", 0.0)))
	S.vision = float(base.get("vision_radius", 190.0)) * (1.0 + float(add.get("vision", 0.0)))
	S.crit = clampf(float(base.get("crit_base", 0.05)) + float(add.get("crit", 0.0)), 0.0, 1.0)
	S.crit_mult = float(base.get("crit_mult", 2.0)) + float(add.get("crit_mult", 0.0))
	S.dodge = clampf(float(add.get("dodge", 0.0)) + (0.15 if String(char_data.get("passive", {}).get("id", "")) == "shadow_step" else 0.0), 0.0, float(base.get("dodge_cap", 0.75)))
	S.dr = clampf(float(add.get("dr", 0.0)), 0.0, 0.85)
	S.lifesteal = float(add.get("lifesteal", 0.0))
	S.knockback = 1.0 + float(add.get("knockback", 0.0))
	S.size = maxf(0.4, 1.0 + float(add.get("size", 0.0)))
	S.summon_dmg = 1.0 + float(add.get("summon_dmg", 0.0))
	S.summon_speed = 1.0 + float(add.get("summon_speed", 0.0))
	S.summon_count = int(add.get("summon_count", 0))
	S.xp_mult = maxf(0.1, 1.0 + float(add.get("xp", 0.0)) + float(char_data.get("xp_bonus", 0.0)))
	S.freeze_chance = clampf(float(add.get("freeze_chance", 0.0)), 0.0, 1.0)
	S.freeze_dur = maxf(0.2, 1.0 + float(add.get("freeze_dur", 0.0)))
	S.burn_mult = maxf(0.0, 1.0 + float(add.get("burn_mult", 0.0)))
	S.burn_dur = maxf(0.1, 1.0 + float(add.get("burn_dur", 0.0)))
	S.shock_dmg = float(add.get("shock_dmg", 0.0))
	max_hp = int(S.max_hp)
	if old_max > 0 and max_hp > old_max:
		hp += max_hp - old_max
	hp = clampi(hp, 0, max_hp)
	_refresh_visual()
	EventBus.hp_changed.emit(hp, max_hp)

func _refresh_visual() -> void:
	var size := Vector2(24, 24) * float(S.get("size", 1.0))
	var col := Gfx.hex(String(char_data.get("color", "#ffffff")))
	var cls := String(char_data.get("cls", "square"))
	var state := "walk" if moving_now else "idle"
	var fr := Assets.frames(cls, state)
	var tex: Texture2D = null
	if not fr.is_empty():
		var fps := 8.0 if moving_now else 3.0
		var idx := int(floor(float(Time.get_ticks_msec()) * 0.001 * fps)) % fr.size()
		tex = fr[idx]
	else:
		tex = Assets.tex(cls, col)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	sprite.texture = tex
	var base := float(maxi(1, tex.get_width()))
	sprite.scale = Vector2(maxf(1.0, size.x) / base, maxf(1.0, size.y) / base)
	sprite.flip_h = aim_dir.x < -0.1
	sprite.position.y = 0.0
	if iframes > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0:
		sprite.modulate = Color(1.4, 0.7, 0.7, 0.75)
	elif bodiless_left > 0.0:
		sprite.modulate = Color(0.75, 0.9, 1.3, 0.65)
	else:
		sprite.modulate = Color.WHITE
	# светлое кольцо, чтобы игрок не терялся среди врагов
	if marker == null:
		marker = Sprite2D.new()
		marker.texture = Assets.tex("ring", Color(1, 1, 1, 0.55))
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.z_index = -1
		add_child(marker)
	var msize := size + Vector2(8, 8)
	marker.scale = Vector2(msize.x / float(Assets.BASE_PX), msize.y / float(Assets.BASE_PX))
	marker.rotation += 0.012
	marker.modulate = Color(1, 1, 1, 0.45 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.006))
	if shield_ring == null:
		shield_ring = Sprite2D.new()
		shield_ring.texture = Assets.tex("ring", Color(0.75, 0.92, 1.0, 0.85))
		shield_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shield_ring.z_index = 2
		add_child(shield_ring)
	shield_ring.visible = shield_charges > 0 or (upg != null and upg.flag_num("gaze_dps") > 0.0)
	if shield_ring.visible:
		var pulse := 1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.009)
		var ring_sz := (size + Vector2(14, 14)) * pulse
		shield_ring.scale = Vector2(ring_sz.x / float(Assets.BASE_PX), ring_sz.y / float(Assets.BASE_PX))
		shield_ring.rotation -= 0.028
		if shield_charges > 0:
			shield_ring.modulate = Color(0.72, 0.92, 1.0, 0.65)
		else:
			shield_ring.modulate = Color(1.0, 0.88, 0.45, 0.36)
	# экипированное оружие в руках, нацеленное в сторону прицела
	var wid := String(weapon.get("id", "revolver"))
	var wtex := Assets.icon("weapon_" + wid)
	if muzzle == null:
		if wtex != null:
			muzzle = Sprite2D.new()
			muzzle.texture = wtex
			muzzle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			muzzle.centered = true
			muzzle.z_index = 1
			add_child(muzzle)
		else:
			muzzle = Gfx.square(self, Vector2(8, 3), Color(1, 1, 1, 0.9))
	elif wtex != null and muzzle.texture != wtex:
		muzzle.texture = wtex
	var kick := maxf(0.0, 1.0 - since_last_shot / 0.08) * 2.5
	muzzle.position = aim_dir * (size.x * 0.45 + 2.5 - kick) + Vector2(0, 1.0)
	muzzle.rotation = aim_dir.angle()
	if wtex != null:
		muzzle.scale = Vector2(0.72, 0.72) * float(S.get("size", 1.0))
		muzzle.flip_v = aim_dir.x < 0.0

# ------------------------------------------------------------------ ВВОД
func read_input() -> void:
	if bot:
		return
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if has_status("charm"):
		dir = -dir
	move_input = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO
	aim_pos = get_global_mouse_position()
	if auto_aim:
		aim_pos = auto_aim_target()

## Ближайший враг для режима автонаведения (Space). Если врагов рядом нет,
## прицел остаётся на курсоре.
func auto_aim_target() -> Vector2:
	if game == null:
		return aim_pos
	var reach := float(DB.balance.get("player", {}).get("auto_aim_radius", 520.0))
	var nearest: Array = game.nearest_enemy(global_position, reach)
	if nearest.is_empty():
		return aim_pos
	return nearest[0].global_position

func look_at_aim() -> void:
	if aim_pos.distance_to(global_position) > 1.0:
		aim_dir = (aim_pos - global_position).normalized()
	if muzzle != null:
		muzzle.position = aim_dir * (7.7 * float(S.get("size", 1.0)) + 3.0)

# ------------------------------------------------------------------ ТИК
func tick(delta: float) -> void:
	if dead:
		return
	_tick_timers(delta)
	_tick_statuses(delta)
	_tick_character(delta)
	_tick_periodic(delta)
	if bot:
		_bot_think(delta)
	read_input()
	look_at_aim()
	_move(delta)
	_tick_weapon(delta)
	_tick_skill(delta)
	_refresh_visual()
	_update_vitals()

## Патроны и здоровье над персонажем — режим включается в настройках
## (Настройки → «Патроны и HP»: «над игроком» / «слева сверху»).
func _update_vitals() -> void:
	var above := String(GameManager.setting("hud_vitals", "corner")) == "player"
	for mark in hp_marks:
		mark.visible = above
	for pip in ammo_pips:
		pip.visible = above
	if not above:
		return
	var total_hp := clampi(max_hp, 1, 12)
	var h_full := Assets.icon("ui_heart_full")
	var h_empty := Assets.icon("ui_heart_empty")
	while hp_marks.size() < total_hp:
		var mark := Sprite2D.new()
		mark.centered = true
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.z_index = 3
		if h_full != null:
			mark.texture = h_full
			mark.scale = Vector2(0.5, 0.5)
		else:
			mark.texture = Gfx.white()
			mark.scale = Vector2(3.0, 3.0)
		add_child(mark)
		hp_marks.append(mark)
	var hp_now := clampi(hp, 0, total_hp)
	for i in hp_marks.size():
		var mark: Sprite2D = hp_marks[i]
		mark.visible = i < total_hp
		if i >= total_hp:
			continue
		mark.position = Vector2((float(i) - (float(total_hp) - 1.0) * 0.5) * 9.5, -26.0)
		if h_full != null and h_empty != null:
			mark.texture = h_full if i < hp_now else h_empty
			mark.modulate = Color.WHITE
		else:
			mark.modulate = Color("#e0524a") if i < hp_now else Color("#3a3a46")
	var total := clampi(int(S.mag), 0, 16)
	while ammo_pips.size() < total:
		var pip: Sprite2D = Gfx.square(self, Vector2(2.0, 3.0), Color(1.0, 0.86, 0.32))
		pip.z_index = 3
		ammo_pips.append(pip)
	# при перезарядке индикатор становится белым и заполняется по мере восстановления
	var frac_reload := 0.0
	if reloading:
		var full := maxf(0.01, reload_total)
		frac_reload = clampf(1.0 - reload_left / full, 0.0, 1.0)
	var filled := clampi(mag, 0, total)
	if reloading:
		filled = int(round(frac_reload * float(total)))
	for i in ammo_pips.size():
		var pip: Sprite2D = ammo_pips[i]
		pip.visible = i < total
		if i >= total:
			continue
		pip.position = Vector2((float(i) - (float(total) - 1.0) * 0.5) * 3.4, -17.0)
		if reloading:
			pip.modulate = Color(1, 1, 1) if i < filled else Color(0.55, 0.55, 0.6, 0.85)
		else:
			pip.modulate = Color(1.0, 0.86, 0.32) if i < filled else Color(0.42, 0.42, 0.5, 0.9)

func _tick_timers(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	iframes = maxf(0.0, iframes - delta)
	if moving_now:
		standing_bonus = 0.0
	elif String(weapon.get("id", "")) == "crossbow":
		standing_bonus = minf(1.0, standing_bonus + 0.05 * delta)
	for name in timers.keys():
		timers[name] = float(timers[name]) - delta
	if shield_recharge_left > 0.0:
		shield_recharge_left = maxf(0.0, shield_recharge_left - delta)
		if shield_recharge_left <= 0.0:
			shield_charges = 1
	if bodiless_left > 0.0:
		bodiless_left = maxf(0.0, bodiless_left - delta)
		free_ammo = bodiless_left > 0.0

func has_timer(key: String) -> bool:
	return float(timers.get(key, 0.0)) > 0.0

func set_timer(key: String, value: float) -> void:
	timers[key] = value

func _tick_statuses(delta: float) -> void:
	for key in statuses.keys():
		var st: Dictionary = statuses[key]
		st["left"] = float(st.get("left", 0.0)) - delta
		if key == "burn":
			_damage_over_time(float(st.get("dps", 0.0)) * delta)
		elif key == "poison":
			_damage_over_time(float(st.get("dps", 0.0)) * float(st.get("stacks", 1)) * delta)
		if float(st["left"]) <= 0.0:
			statuses.erase(key)

func has_status(key: String) -> bool:
	return statuses.has(key)

func add_status(key: String, dur: float, params: Dictionary = {}) -> void:
	if key == "slow" and has_meta("boots") and params.has("amount"):
		params = params.duplicate()
		params["amount"] = float(params["amount"]) * 0.5
	var st: Dictionary = statuses.get(key, {})
	st["left"] = maxf(float(st.get("left", 0.0)), dur)
	for k in params.keys():
		st[k] = params[k]
	if key == "poison":
		st["stacks"] = mini(int(st.get("stacks", 1)) + 1, 3)
	statuses[key] = st

func status_speed_mult() -> float:
	var mult := 1.0
	if has_status("slow"):
		mult *= 1.0 - float(statuses["slow"].get("amount", 0.5))
	if has_status("curse"):
		mult *= 0.5
	if upg.flag_num("lowhp_speed") > 0.0 and hp * 2 < max_hp:
		mult *= 1.0 + upg.flag_num("lowhp_speed")
	return mult

func _damage_over_time(amount: float) -> void:
	if amount <= 0.0:
		return
	timers["dot_accum"] = float(timers.get("dot_accum", 0.0)) + amount
	if float(timers["dot_accum"]) >= 1.0:
		var whole := int(timers["dot_accum"])
		timers["dot_accum"] = float(timers["dot_accum"]) - whole
		take_damage(whole, global_position, true)

## Пассивки и таймеры персонажа (аура огня, призыв скелетов, берсерк и т.д.).
## Разовое полное лечение (апгрейд «Благословение»).
func full_heal() -> void:
	hp = max_hp
	EventBus.hp_changed.emit(hp, max_hp)

func _tick_character(delta: float) -> void:
	var passive_id := String(char_data.get("passive", {}).get("id", ""))
	var pp: Dictionary = char_data.get("passive", {}).get("params", {})
	berserk_left = maxf(0.0, berserk_left - delta)
	harvest_left = maxf(0.0, harvest_left - delta)
	if harvest_left <= 0.0:
		harvest_zones = 0
	if passive_id == "fire_aura" or upg.flag_on("aura_boost"):
		var radius := float(pp.get("radius", 64.0)) * (1.0 + float(upg.flag_num("aura_boost")))
		var dps := float(pp.get("dps", 2.0)) * (1.0 + float(upg.flag_num("aura_boost")))
		aura_cd -= delta
		if aura_cd <= 0.0:
			aura_cd = 0.5
			game.aoe_damage(global_position, radius, dps * 0.5 * dmg_multiplier(), {"source": "aura"})
			if upg.flag_on("aura_boost"):
				game.apply_status_radius(global_position, radius, "burn", 1.5, {"dps": dps * 0.5})
	if passive_id == "summon_skeletons":
		summon_cd -= delta
		var max_summon := int(pp.get("max", 3)) + int(upg.flag_num("summon_count"))
		if summon_cd <= 0.0 and game.allies.size() < max_summon:
			summon_cd = float(pp.get("interval", 15.0))
			game.spawn_ally("skeleton", {
				"damage": float(pp.get("damage", 2.0)) * float(S.summon_dmg),
				"duration": float(pp.get("duration", 20.0)),
				"hp": float(pp.get("hp", 5.0)) * (1.0 + float(upg.flag_num("summon_hp")))})
			game.spawn_fx(global_position, Color(0.2, 0.8, 0.3), 24.0, 0.3)
	if upg.flag_num("summon_fear") > 0.0 and game.alive_allies() > 0:
		timers["fear"] = float(timers.get("fear", 0.0)) - delta
		if float(timers["fear"]) <= 0.0:
			timers["fear"] = 4.0
			for ally in game.allies:
				if ally.active:
					for enemy in game.enemies_in_radius(ally.global_position, upg.flag_num("summon_fear")):
						enemy.stun = maxf(float(enemy.stun), 1.0)
	if upg.flag_num("loop_shadow") > 0.0:
		pass
	_tick_perk_summons()

func _tick_perk_summons() -> void:
	if game == null:
		return
	var kinds: Array = upg.flag_list("summon")
	if kinds.is_empty():
		return
	var soul_knight := upg.flag_num("soul_knight") * float(souls_collected)
	for kind_v in kinds:
		var kind := String(kind_v)
		if kind == "":
			continue
		var desired := 1 + int(S.summon_count) if kind in ["scythe", "boomerang", "dragonling"] else 1
		var active_list: Array = []
		for a in game.allies:
			if a.active and a.kind == kind and bool(a.perk_summon):
				active_list.append(a)
		var base_dmg := 12.0
		match kind:
			"scythe": base_dmg = 14.0
			"boomerang": base_dmg = 13.0
			"dragonling": base_dmg = 10.0
			"thunder_beetle": base_dmg = 18.0
		var dmg := base_dmg * float(S.summon_dmg) + soul_knight
		if kind == "boomerang":
			dmg += upg.flag_num("boomerang_soul") * float(souls_collected)
		elif kind == "dragonling":
			var mins := floorf(float(game.elapsed) / 60.0)
			dmg = (base_dmg + upg.flag_num("dragon_flat") * mins) * float(S.summon_dmg) * (1.0 + upg.flag_num("dragon_growth") * mins) + soul_knight
		for ex in active_list:
			ex.damage = dmg
			if kind == "dragonling":
				ex.dragon_breath = upg.flag_on("dragon_breath")
		var missing := desired - active_list.size()
		for i in missing:
			var slot := active_list.size() + i
			var ang := TAU * float(slot) / float(maxi(1, desired))
			game.spawn_ally(kind, {
				"damage": dmg,
				"duration": 999999.0,
				"perk_summon": true,
				"no_extra": true,
				"orbit_angle": ang,
				"interval": 0.9 if kind == "thunder_beetle" else 0.7,
			})

func _tick_periodic(delta: float) -> void:
	var passive_id := String(char_data.get("passive", {}).get("id", ""))
	var passive_params: Dictionary = char_data.get("passive", {}).get("params", {})
	# Порыв ветра
	var gust_every := 0.0
	var gust_damage := 0.0
	if passive_id == "nature_breath":
		gust_every = float(passive_params.get("interval", 2.0))
		gust_damage = float(passive_params.get("damage", 8.0))
	if upg.flag_num("gust_every") > 0.0:
		gust_every = upg.flag_num("gust_every")
		gust_damage = upg.flag_num("gust_damage", 8.0)
	gust_damage += upg.flag_num("gust_damage_add")
	if gust_every > 0.0:
		timers["gust"] = float(timers.get("gust", gust_every)) - delta
		if float(timers["gust"]) <= 0.0:
			timers["gust"] = gust_every
			_cast_gust(gust_damage)
	# Регенерация
	var regen_period := 0.0
	if passive_id == "healing_prayer":
		regen_period = float(passive_params.get("interval", 90.0))
	if upg.flag_num("regen") > 0.0:
		regen_period = upg.flag_num("regen") if regen_period <= 0.0 else minf(regen_period, upg.flag_num("regen"))
	if regen_period > 0.0:
		timers["regen"] = float(timers.get("regen", regen_period)) - delta
		if float(timers["regen"]) <= 0.0:
			timers["regen"] = regen_period
			heal(1)
			game.spawn_perk_fx("holy", global_position, 44.0, 0.34)
	# Ветер в спине
	if passive_id == "wind_in_back" or upg.flag_num("wind_runner") > 0.0:
		var period := 10.0
		var per_stack := float(passive_params.get("per_stack", 0.30))
		var max_st := int(passive_params.get("max_stacks", 4))
		if upg.flag_num("wind_runner") > 0.0:
			per_stack = upg.flag_num("wind_runner")
		timers["wind"] = float(timers.get("wind", period)) - delta
		if float(timers["wind"]) <= 0.0:
			timers["wind"] = period
			stacks["wind"] = mini(int(stacks.get("wind", 0)) + 1, max_st)
			game.spawn_perk_fx("wind", global_position, 36.0, 0.26)
	# Тень ветра: каждые 10 с без урона +10% темпа стрельбы и +1 пробитие (до 4 стаков)
	if upg.flag_on("wind_shadow"):
		timers["wind_shadow"] = float(timers.get("wind_shadow", 10.0)) - delta
		if float(timers["wind_shadow"]) <= 0.0:
			timers["wind_shadow"] = 10.0
			var cur_ws := int(stacks.get("wind_shadow", 0))
			if cur_ws < 4:
				stacks["wind_shadow"] = cur_ws + 1
				game.spawn_perk_fx("wind", global_position, 40.0, 0.28)
	# Пронзительный взгляд
	var gaze := upg.flag_num("gaze_dps", 0.0) * maxf(1.0, upg.flag_num("gaze_mult", 1.0))
	if gaze > 0.0:
		timers["gaze"] = float(timers.get("gaze", 0.25)) - delta
		if float(timers["gaze"]) <= 0.0:
			timers["gaze"] = 0.25
			var g_hits: int = game.aoe_damage(global_position, float(S.vision), gaze * 0.25, {"source": "gaze"})
			if g_hits > 0:
				var near_g: Array = game.nearest_enemy(global_position, float(S.vision))
				if not near_g.is_empty():
					game.spawn_perk_fx("smite", near_g[0].global_position, 28.0, 0.22)
	# Конвертация душ: каждая собранная душа по очереди становится +1 max HP.
	if soul_convert_pending>0 and upg.flag_num("soul_convert")>0.0:
		soul_convert_left-=delta
		if soul_convert_left<=0.0:
			soul_convert_pending-=1; upg.apply_mods({"hp":1}); recalc(); hp=mini(max_hp,hp+1); soul_convert_left=upg.flag_num("soul_convert")
			game.spawn_perk_fx("curse", global_position, 44.0, 0.32)
			game.notify("Душа преобразована: +1 максимум HP")
	# Пылающий разум
	if upg.flag_num("burning_fire_rate") > 0.0:
		var burning: int = game.count_burning_enemies(global_position, 400.0)
		stacks["burning_fr"] = float(burning) * upg.flag_num("burning_fire_rate")
	# Око Грозы (эхо порыва)
	if upg.flag_num("gust_echo") > 0.0:
		pass

func _cast_gust(damage: float) -> void:
	if damage <= 0.0:
		return
	var nearest: Array = game.nearest_enemy(global_position, 400.0)
	if nearest.is_empty():
		return
	var target: Node2D = nearest[0]
	var dmg := damage * float(S.summon_dmg)
	var echoes := maxi(1, int(upg.flag_num("gust_echo", 1.0)))
	dmg *= maxf(1.0, upg.flag_num("gust_mult", 1.0))
	var gust_radius:=20.0*(1.0+upg.flag_num("gust_radius"))
	for i in echoes:
		game.aoe_damage(target.global_position,gust_radius,dmg,{"source":"gust","knockback":35.0})
		game.spawn_fx(target.global_position, Color(0.6, 1.0, 0.7), gust_radius, 0.15)
		game.spawn_perk_fx("wind", target.global_position, gust_radius * 1.4, 0.28)

# ------------------------------------------------------------------ ДВИЖЕНИЕ
func _move(delta: float) -> void:
	if has_status("stun"):
		velocity = Vector2.ZERO
		move_and_slide()
		moving_now = false
		return
	var speed := float(S.move_speed) * status_speed_mult() * world_speed_mult * terrain_mult * GameManager.cheat_speed
	if shield_charges>0 and upg.flag_num("shield_blessing")>0.0:
		speed*=1.0+upg.flag_num("shield_blessing")
	if berserk_left > 0.0:
		speed *= 1.0 + float(char_data.get("skill", {}).get("params", {}).get("speed", 0.5))
	if int(stacks.get("wind", 0)) > 0:
		speed *= 1.0 + float(char_data.get("passive", {}).get("params", {}).get("per_stack", 0.30)) * float(stacks["wind"])
	velocity = move_input * speed
	moving_now = move_input.length() > 0.05
	move_and_slide()
	if moving_now and upg.flag_num("run_burn")>0.0:
		timers["run_burn_tick"]=float(timers.get("run_burn_tick",0.0))-delta
		if float(timers["run_burn_tick"])<=0.0:
			timers["run_burn_tick"]=0.25
			game.spawn_perk_fx("fireball", global_position, 26.0, 0.22)
			for enemy in game.enemies_in_radius(global_position,14.0): game.apply_status(enemy,"burn",3.0,{"dps":upg.flag_num("run_burn")})

# ------------------------------------------------------------------ БОНУСЫ УРОНА
func dmg_multiplier() -> float:
	var m := 1.0
	if upg.flag_num("highhp_damage") > 0.0 and hp * 4 > max_hp * 3:
		m += upg.flag_num("highhp_damage")
	if upg.flag_num("lowhp_fury") > 0.0 and hp * 4 <= max_hp:
		m += upg.flag_num("lowhp_fury")
	if upg.flag_num("rage_point") > 0.0 and has_timer("rage_point"):
		m += upg.flag_num("rage_point")
	if upg.flag_num("fresh_mag") > 0.0 and has_timer("fresh_mag"):
		m += upg.flag_num("fresh_mag")
	if int(stacks.get("wind", 0)) > 0:
		m += float(char_data.get("passive", {}).get("params", {}).get("per_stack", 0.30)) * float(stacks["wind"])
	if upg.flag_num("beast_alone") > 0.0 and game.alive_allies() > 0:
		m += upg.flag_num("beast_alone")
	if upg.flag_num("close_damage") > 0.0 and game.nearest_enemy(global_position, 96.0).size() > 0:
		m += upg.flag_num("close_damage")
	if upg.flag_num("dmg_per_hp") > 0.0:
		m += upg.flag_num("dmg_per_hp") * float(hp)
	if upg.flag_on("wind_damage"):
		m += maxf(0.0, float(upg.add.get("move_speed", 0.0))) * 0.5
	if upg.flag_num("heal_growth") > 0.0 and has_timer("heal_growth"):
		m += upg.flag_num("heal_growth") * float(stacks.get("heal_growth", 1))
	if String(weapon.get("id", "")) == "crossbow":
		m += standing_bonus
	if upg.flag_num("righteous") > 0.0 and hp > 5:
		m += upg.flag_num("righteous") * float(hp - 5)
	if float(stacks.get("kill_stack_dmg", 0.0)) > 0.0:
		m += float(stacks["kill_stack_dmg"])
	if berserk_left > 0.0:
		m += float(char_data.get("skill", {}).get("params", {}).get("damage", 0.25))
	if dash_buff_double:
		m *= 2.0
	if game != null and int(game.combo) > 0:
		var combo_dmg := float(Progression.cfg.get("combo", {}).get("damage_per", 0.005))
		m += float(game.combo) * combo_dmg
	if has_status("curse"):
		m *= 0.7
	return m

func fire_rate_multiplier() -> float:
	var m := 1.0
	m += upg.flag_num("blood_rage_stacks") * 0.10
	if upg.flag_num("rage_point") > 0.0 and has_timer("rage_point"):
		m += upg.flag_num("rage_point")
	if upg.flag_num("lowhp_fury") > 0.0 and hp * 4 <= max_hp:
		m += upg.flag_num("lowhp_fury")
	if upg.flag_num("highhp_fire_rate") > 0.0 and hp * 4 > max_hp * 3:
		m += upg.flag_num("highhp_fire_rate")
	if has_timer("buff_fire_rate"):
		m += float(stacks.get("buff_fire_rate", 0.0))
	if has_timer("xp_rush"):
		m += upg.flag_num("xp_rush")
	if has_timer("resonance"):
		m += upg.flag_num("resonance")
	if int(stacks.get("wind_shadow", 0)) > 0:
		m += 0.10 * float(stacks["wind_shadow"])
	m += float(stacks.get("burning_fr", 0.0))
	if upg.flag_num("aura_fire_rate") > 0.0 and has_timer("aura"):
		m += upg.flag_num("aura_fire_rate")
	return maxf(0.15, m)

## Сколько опыта нужно до следующего уровня оружия.
func weapon_xp_need() -> int:
	var cfg: Dictionary = DB.balance.get("weapon_level", {})
	return int(float(cfg.get("xp_base", 20)) * pow(float(cfg.get("xp_growth", 1.35)), float(weapon_level - 1)))

## Опыт оружия: копится за убийства, при 8 уровне оружие готово к эволюции.
func add_weapon_xp(amount: float) -> void:
	var cfg: Dictionary = DB.balance.get("weapon_level", {})
	if weapon_level >= int(cfg.get("max_level", 8)):
		weapon_xp = 0.0
		return
	weapon_xp += amount
	while weapon_xp >= weapon_xp_need() and weapon_level < int(cfg.get("max_level", 8)):
		weapon_xp -= weapon_xp_need()
		weapon_level += 1
		recalc()
		mag = mini(int(S.mag), mag)
		pass
		AudioManager.play_sfx("levelup", 1.2)
		game.spawn_fx(global_position, Color(1, 0.9, 0.4), 26.0, 0.3)

func current_damage() -> float:
	var dmg := float(S.damage) * dmg_multiplier()
	var passive := String(char_data.get("passive", {}).get("id", ""))
	if passive == "blood_rage":
		var hp_frac := float(hp) / maxf(1.0, float(max_hp))
		dmg *= 1.0 + (1.0 - hp_frac) * float(char_data.get("passive", {}).get("params", {}).get("max_mult", 2.0))
	if passive == "holy_strength":
		dmg += float(holy_hits)
	return dmg * GameManager.cheat_dmg

# ------------------------------------------------------------------ ОРУЖИЕ
func _tick_weapon(delta: float) -> void:
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			_finish_reload()
		return
	var wants := Input.is_action_pressed("fire") if not bot else bot_wants_fire
	since_last_shot += delta
	# Автоперезарядка в простое: если игрок не стреляет, магазин пополняется сам.
	if not wants and not reloading and mag < int(S.mag) and since_last_shot >= float(DB.balance.get("player", {}).get("idle_reload_delay", 0.7)):
		start_reload()
	if upg.flag_num("burning_fire_rate") > 0.0 and fire_cd > 0.0:
		# «Пылающий Разум»: ускорение перезарядки выстрела за каждое горящее существо
		fire_cd = maxf(0.0, fire_cd - delta * upg.flag_num("burning_fire_rate") * float(game.burning_count()))
	if wants and fire_cd <= 0.0 and not has_status("stun"):
		if mag <= 0:
			start_reload()
		else:
			_shoot()

func _on_reload_reset() -> void:
	holy_hits = 0
	reload_shot_ready = true
	stacks["kill_stack_dmg"] = 0.0

func start_reload() -> void:
	if reloading or mag >= int(S.mag):
		return
	reloading = true
	var shield_reload:=upg.flag_num("shield_blessing") if shield_charges>0 else 0.0
	reload_total = float(S.reload_time)/maxf(0.1,1.0+shield_reload+float(stacks.get("blood_mag",0.0)))
	reload_left = reload_total
	AudioManager.play_sfx("reload", randf_range(0.95, 1.1))
	EventBus.ammo_changed.emit(mag, int(S.mag), true)

func _finish_reload() -> void:
	reloading = false
	mag = int(S.mag)
	shots_fired = 0
	var had_blood_mag := float(stacks.get("blood_mag", 0.0)) > 0.0
	stacks["blood_mag"] = 0
	_on_reload_reset()
	EventBus.ammo_changed.emit(mag, int(S.mag), false)
	AudioManager.play_sfx("reload", 1.15)
	if had_blood_mag:
		game.spawn_perk_fx("blood", global_position, 38.0, 0.28)
	if upg.flag_num("fresh_mag") > 0.0:
		set_timer("fresh_mag", 1.0)
		game.spawn_perk_fx("holy", global_position, 36.0, 0.26)
	var passive_id := String(char_data.get("passive", {}).get("id", ""))
	if passive_id == "enchanted_blade":
		var p: Dictionary = char_data["passive"]["params"]
		var blades := 1 + int(upg.flag_num("blade_extra"))
		for i in blades:
			game.spawn_ally("blade", {"damage": float(p.get("damage", 22.0)) * float(S.summon_dmg) * (float(S.damage) / 20.0 if upg.flag_on("blade_from_bullets") else 1.0), "duration": float(p.get("duration", 5.0)), "radius": float(p.get("radius", 38.0)) + i * 14.0})
	for kind in upg.flag_list("summon_on_reload"):
		game.spawn_ally(String(kind), {"damage": float(S.damage) * float(S.summon_dmg), "duration": 10.0})
	for i in int(upg.flag_num("reload_lightning")):
		game.lightning_strike_nearest(global_position, 320.0, 22.0 * float(S.summon_dmg))
	if upg.flag_num("reload_pillar") > 0.0:
		game.aoe_damage(global_position, 96.0, upg.flag_num("reload_pillar"), {"holy": true, "source": "dawn"})
		game.spawn_fx(global_position, Color(1, 0.95, 0.6), 96.0, 0.5)
		game.spawn_perk_fx("holy", global_position, 82.0, 0.36)
	if upg.flag_num("arrow_rain_reload") > 0.0:
		game.aoe_damage(global_position, upg.flag_num("arrow_rain_reload"), current_damage() * 0.6, {"source": "arrow_rain"})
		game.spawn_perk_fx("wind", global_position, 64.0, 0.32)
	var behavior := String(weapon.get("behavior", "straight"))
	if behavior == "blade":
		var radius := 48.0 * (1.0 + upg.flag_num("circle_radius"))
		var hit: int = game.aoe_damage(global_position, radius, 24.0 * dmg_multiplier(), {"source": "circle"})
		game.spawn_fx(global_position, Color(0.9, 0.95, 1.0), radius, 0.25)
		game.spawn_perk_fx("blood", global_position, radius * 1.15, 0.28)
		if upg.flag_on("circle_heal") and hit > 0:
			heal(1)
		for i in int(upg.flag_num("orbit_blades")):
			game.spawn_ally("orbit_blade", {"damage": 18.0 * dmg_multiplier(), "duration": 3.0, "radius": 46.0 + i * 16.0})
	if behavior == "arrow":
		for pos in stuck_arrows:
			game.aoe_damage(pos, 26.0, current_damage() * 0.8, {"source": "arrow_return"})
			game.spawn_perk_fx("wind", pos, 34.0, 0.24)
		stuck_arrows.clear()
	if behavior == "orb":
		game.explode_orbs(current_damage() * 2.0)
		game.spawn_perk_fx("curse", global_position, 56.0, 0.30)
	if upg.flag_num("resonance") > 0.0:
		set_timer("resonance", 2.0)

func _shoot() -> void:
	shots_fired += 1
	since_last_shot = 0.0
	fire_cd = 1.0 / maxf(0.2, float(S.fire_rate) * fire_rate_multiplier())
	AudioManager.play_sfx(_shot_sfx(), randf_range(0.94, 1.07))
	var pellets := int(S.projectiles)
	var spread := float(S.spread)
	var behavior := String(weapon.get("behavior", "straight"))
	var dmg := current_damage()
	var is_crit := randf() < float(S.crit)
	if is_crit:
		dmg *= float(S.crit_mult)
	var passive_now := String(char_data.get("passive", {}).get("id", ""))
	if passive_now == "deadly_shot" and reload_shot_ready:
		dmg *= float(char_data.get("passive", {}).get("params", {}).get("mult", 3.0))
		is_crit = true
		reload_shot_ready = false
	if upg.flag_num("combo_crit") > 0.0 and combo_hits >= int(upg.flag_num("combo_crit")):
		dmg *= 3.0
		is_crit = true
		combo_hits = 0
	if dash_buff_double:
		# «Теневой Удар»: первый выстрел после рывка наносит двойной урон
		dmg *= 2.0
		is_crit = true
		dash_buff_double = false
	var pierce_bonus := int(upg.flag_num("rhythm_pierce")) if game.elapsed < 60.0 else 0
	pierce_bonus += int(stacks.get("wind_shadow", 0))
	if upg.flag_on("unbending") and hp*2<=max_hp: pierce_bonus+=2
	var opts := {
		"speed": float(S.proj_speed), "pierce": int(S.pierce) + pierce_bonus, "bounce": int(S.bounce),
		"radius": 3.0 * float(S.size), "color": Gfx.hex(String(weapon.get("color", "#ffffff"))),
		"crit": is_crit, "knockback": float(S.knockback)+(0.25 if upg.flag_on("unbending") and hp*2<=max_hp else 0.0), "behavior": behavior,
		"weapon_id": String(weapon.get("id", "")),
		"life": clampf(float(weapon.get("max_range", 560.0)) / maxf(60.0, float(S.proj_speed)), 0.45, 4.0) if weapon.has("max_range") else clampf(560.0 / maxf(60.0, float(S.proj_speed)), 1.0, 4.0),
		"max_range": float(weapon.get("max_range", 0.0)),
		"freeze_chance": float(S.freeze_chance), "burn_mult": float(S.burn_mult), "source": "weapon",
		"full_hp_bonus": upg.flag_num("full_hp_bonus", 0.0),
	}
	var weapon_burn := float(DB.balance.get("player", {}).get("burn_dps", 3.0)) + float(S.get("weapon_burn", 0.0))
	if upg.flag_on("bullet_burn") or String(behavior) == "fireball":
		opts["burn"] = {"dps": weapon_burn * float(S.burn_mult), "dur": 3.0}
	if bool(weapon.get("holy", false)):
		opts["holy"] = true
	# статусы оружия прямо из данных (заморозка, яд, оглушение)
	if weapon.has("freeze"):
		var fz: Variant = weapon["freeze"]
		opts["freeze"] = float(fz.get("dur", 1.2)) if fz is Dictionary else float(fz)
	if weapon.has("poison"):
		var pz: Variant = weapon["poison"]
		if pz is Dictionary:
			opts["poison"] = {"dps": float(pz.get("dps", 4.0)), "dur": float(pz.get("dur", 4.0))}
			opts["gas"] = {"dps": float(pz.get("dps", 4.0)), "dur": float(pz.get("dur", 4.0)), "radius": 40.0}
	if weapon.has("stun"):
		opts["stun"] = float(weapon["stun"])
	# уникальные апгрейды персонажей
	if upg.flag_on("holy"):
		opts["holy"] = true
	if upg.flag_on("armor_pierce") or float(upg.add.get("armor_pierce",0.0))>0.0:
		opts["armor_pierce"] = true
	if upg.flag_num("explode_on_hit") > 0.0:
		opts["explode"] = upg.flag_num("explode_on_hit")
		opts["explode_radius"] = 64.0
	if upg.flag_on("bullet_poison"):
		var bp: Dictionary = upg.flags["bullet_poison"]
		opts["poison"] = {"dps": float(bp.get("dps", 5.0)), "dur": float(bp.get("dur", 4.0))}
	if upg.flag_num("boomerang") > 0.0:
		opts["boomerang"] = upg.flag_num("boomerang")
		opts["return_damage"] = upg.flag_num("boomerang")
	# «Сродство Тайн»: +урон магических снарядов, −обычный
	var magic_behaviors := ["fireball", "orb", "curse", "homing", "gas", "lightning"]
	if magic_behaviors.has(String(weapon.get("behavior", ""))):
		dmg *= 1.0 + float(upg.add.get("magic_dmg", 0.0))
	if upg.flag_num("curse_chance") > 0.0 and randf() < upg.flag_num("curse_chance"):
		opts["curse"] = true
	if upg.flag_on("bullet_curse") or upg.flag_on("curse"):
		opts["curse"] = true
	if passive_now == "void_echo" and shots_fired % int(char_data.get("passive",{}).get("params",{}).get("every",5)) == 0:
		dmg *= 1.5; opts["pierce"] = int(opts.get("pierce",0))+4; opts["curse"]=true; opts["color"]=Color("#ff3ca6")
	if upg.flag_num("explode_on_hit") > 0.0:
		opts["explode"] = upg.flag_num("explode_on_hit") * dmg_multiplier()
		opts["explode_radius"] = 64.0 + upg.flag_num("explode_radius")
	if upg.flag_num("split_on_hit") > 0.0:
		opts["split"] = int(upg.flag_num("split_on_hit"))
	if upg.flag_num("chain") > 0.0:
		opts["chain"] = int(upg.flag_num("chain"))
	if upg.flag_on("tornado_on_hit"):
		opts["tornado"] = upg.flag_num("tornado_on_hit", 8.0)
	match behavior:
		"grenade":
			opts["explode"] = float(weapon.get("damage", 45)) * dmg_multiplier()
			opts["explode_radius"] = 64.0 + upg.flag_num("explode_radius")
			opts["speed"] = float(S.proj_speed) * 0.7
			if upg.flag_num("cluster") > 0.0:
				opts["cluster"] = int(upg.flag_num("cluster"))
			if upg.flag_on("napalm"):
				opts["napalm"] = true
		"fireball":
			opts["burn"] = {"dps": 3.0 * float(S.burn_mult), "dur": 3.0}
			opts["radius"] = 4.5 * float(S.size)
			opts["burn_radius"] = 32.0 * (1.0 + upg.flag_num("burn_radius"))
		"homing":
			opts["homing"] = true
			opts["summon_scaled"] = true
		"arrow":
			opts["stick"] = true
		"hammer":
			opts["explode"] = 24.0 * dmg_multiplier()
			opts["explode_radius"] = 64.0 + upg.flag_num("explode_radius")
			opts["holy"] = true
		"curse":
			opts["curse"] = true
		"orb":
			opts["chain"] = maxi(1, int(opts.get("chain", 1)))
			opts["is_orb"] = true
		"lightning":
			opts["chain"] = maxi(1, int(S.pierce))
			opts["stun"] = float(weapon.get("stun", 0.5))
			opts["holy"] = false
			opts["color"] = Color(0.85, 0.95, 1.0)
		"gas":
			opts["gas"] = {"dps": 4.0, "dur": 4.0, "radius": 40.0}
			if weapon.has("poison"):
				opts["gas"] = {"dps": float(weapon["poison"].get("dps", 4.0)), "dur": float(weapon["poison"].get("dur", 4.0)), "radius": 40.0}
			opts["radius"] = 6.0
		"dagger":
			opts["speed"] = float(S.proj_speed)
		"shotgun":
			opts["radius"] = 2.5 * float(S.size)
	for i in pellets:
		var angle := 0.0
		if pellets > 1 and spread > 0.0:
			angle = deg_to_rad(spread) * (float(i) / float(pellets - 1) - 0.5)
		if behavior == "orb":
			angle += deg_to_rad(10.0 if (shots_fired % 2 == 0) else -10.0)
		var dir := aim_dir.rotated(angle + deg_to_rad(randf_range(-1.5, 1.5)))
		var p_opts := opts
		if behavior == "shotgun":
			p_opts = opts.duplicate()
			p_opts["speed"] = float(opts.get("speed", 400.0)) * randf_range(0.88, 1.14)
		game.spawn_bullet(global_position + dir * 10.0, dir, dmg, p_opts)
	if is_crit:
		AudioManager.play_sfx("crit", randf_range(0.96, 1.06))
	# «Перегрузка» (Вольтра): лазер бьёт несколько раз за один выстрел
	if upg.flag_num("triple_shot") > 0.0:
		var extra_beams := maxi(0, int(upg.flag_num("triple_shot")) - 1)
		var side := Vector2(-aim_dir.y, aim_dir.x)
		for i in extra_beams:
			var off := side * (float(i + 1) * 8.0) * (1.0 if i % 2 == 0 else -1.0)
			game.spawn_bullet(global_position + aim_dir * 10.0 + off, aim_dir, dmg * 0.65, opts)
	if passive_now == "double_shot" and randf() < float(char_data.get("passive", {}).get("params", {}).get("chance", 0.2)):
		var extra_angle := deg_to_rad(float(char_data.get("passive", {}).get("params", {}).get("angle", 15.0)))
		var extra_dir := aim_dir.rotated(extra_angle if randf() < 0.5 else -extra_angle)
		game.spawn_bullet(global_position + extra_dir * 10.0, extra_dir, dmg * float(char_data.get("passive", {}).get("params", {}).get("damage", 0.5)), opts)
	if passive_now == "chain_lightning_passive" and shots_fired % int(char_data.get("passive", {}).get("params", {}).get("every", 5)) == 0:
		var cp: Dictionary = char_data.get("passive", {}).get("params", {})
		var near_now: Array = game.nearest_enemy(global_position, float(cp.get("radius", 96.0)))
		if not near_now.is_empty():
			game.chain_lightning(near_now[0], int(cp.get("jumps", 3)) + int(upg.flag_num("chain_bonus")), float(cp.get("damage", 4.0)) * dmg_multiplier())
	_try_special_shot()
	var consume := 1
	if upg.flag_num("siege_save") > 0.0 and not moving_now and randf() < upg.flag_num("siege_save"):
		consume = 0
	if free_ammo:
		consume = 0
	if consume > 0 and not inf_ammo:
		mag = maxi(0, mag - 1)
	EventBus.ammo_changed.emit(mag, int(S.mag), false)
	if mag == 0:
		_on_last_shot()

func _shot_sfx() -> String:
	match String(weapon.get("behavior", "straight")):
		"fireball", "orb", "curse", "homing", "gas":
			return "shot_magic"
		"lightning":
			return "shot_lightning"
		"arrow":
			return "shot_bow"
		"grenade", "hammer", "shotgun":
			return "shot_heavy"
		_:
			return "shot"

func _try_special_shot() -> void:
	var s := shots_fired
	var passive := String(char_data.get("passive", {}).get("id", ""))
	if passive == "arcane_fire":
		var p: Dictionary = char_data["passive"]["params"]
		if s % int(p.get("every", 4)) == 0:
			var af_dmg := float(p.get("damage", 5.0)) * dmg_multiplier()
			_fire_special("fireball", af_dmg, {"behavior": "fireball", "explode": af_dmg, "explode_radius": 48.0, "burn": {"dps": float(p.get("burn_dps", 3.0)) * float(S.burn_mult), "dur": float(p.get("burn_dur", 3.0))}})
	if upg.flag_num("fireball_every") > 0.0 and s % int(upg.flag_num("fireball_every")) == 0:
		var fb_dmg := upg.flag_num("fireball_damage", 5.0) * dmg_multiplier()
		_fire_special("fireball", fb_dmg, {"behavior": "fireball", "explode": fb_dmg, "explode_radius": 48.0, "burn": {"dps": upg.flag_num("fireball_burn", 3.0) * float(S.burn_mult), "dur": 3.0}})
	if upg.flag_num("ice_every") > 0.0 and s % int(upg.flag_num("ice_every")) == 0:
		_fire_special("ice", upg.flag_num("ice_damage", 6.0) * dmg_multiplier(), {"freeze": 1.2 * float(S.freeze_dur)})
	if passive == "frost_moth":
		var p2: Dictionary = char_data["passive"]["params"]
		if s % int(p2.get("every", 6)) == 0:
			var moth_opts := {"damage": float(p2.get("damage", 6.0)) * float(S.summon_dmg), "duration": 8.0, "tick": float(p2.get("tick", 0.6)), "freeze_dur": float(p2.get("freeze_dur", 1.2))}
			game.spawn_ally("moth", moth_opts)
			for i in int(upg.flag_num("moth_extra")):
				game.spawn_ally("moth", moth_opts)
	if upg.flag_num("lightning_every") > 0.0 and s % int(upg.flag_num("lightning_every")) == 0:
		var ldmg:float = (upg.flag_num("lightning_damage", 22.0) + float(S.shock_dmg)) * dmg_multiplier()
		var took: bool = game.lightning_strike_nearest(global_position, 320.0, ldmg)
		if took and upg.flag_num("charged_refill") > 0.0 and randf() < upg.flag_num("charged_refill"):
			mag = mini(int(S.mag), mag + 3)
			EventBus.ammo_changed.emit(mag, int(S.mag), false)
			if upg.flag_num("resonance") > 0.0:
				set_timer("resonance", 2.0)
			game.spawn_perk_fx("lightning", global_position, 36.0, 0.24)
	if upg.flag_num("spark_chance") > 0.0 and randf() < upg.flag_num("spark_chance"):
		game.lightning_strike_nearest(global_position, 260.0, 18.0 * dmg_multiplier())
	if float(S.freeze_chance) > 0.0:
		var target: Array = game.nearest_enemy(global_position, 320.0)
		if not target.is_empty() and randf() < float(S.freeze_chance):
			game.freeze_enemy(target[0], 1.2 * float(S.freeze_dur))
			if upg.flag_num("freeze_burn") > 0.0:
				game.apply_status(target[0], "burn", 3.0, {"dps": upg.flag_num("freeze_burn")})

func _fire_special(kind: String, dmg: float, extra: Dictionary) -> void:
	var opts := {"speed": float(S.proj_speed) * 1.1, "radius": 4.5, "color": Color(1.0, 0.6, 0.2), "source": "special"}
	opts.merge(extra, true)
	if kind == "ice":
		opts["color"] = Color(0.6, 0.9, 1.0)
	if upg.flag_num("magic_dmg") > 0.0:
		dmg *= 1.0 + upg.flag_num("magic_dmg")
	game.spawn_bullet(global_position + aim_dir * 12.0, aim_dir, dmg, opts)

func _on_last_shot() -> void:
	var retribution := upg.flag_num("last_shot_retribution")
	if retribution > 0.0:
		var dmg := retribution + upg.flag_num("retribution_per_hp") * float(hp)
		game.aoe_damage(global_position, 96.0, dmg, {"holy": true, "source": "retribution"})
		game.spawn_fx(global_position, Color(1, 0.95, 0.7), 96.0, 0.3)
		game.spawn_perk_fx("smite", global_position, 72.0, 0.36)
		AudioManager.play_sfx("lightning", 1.2)
	if upg.flag_num("smite") > 0.0:
		var p_cfg: Dictionary = DB.balance.get("player", {})
		var targets: int = int(p_cfg.get("smite_targets", 3))
		var s_radius: float = float(p_cfg.get("smite_radius", 96.0))
		var s_damage: float = float(p_cfg.get("smite_damage", 20.0)) * upg.flag_num("smite") * dmg_multiplier()
		if upg.flag_on("smite_hp_bonus"):
			s_damage += float(hp) * 10.0
		var smite_count := 0
		for e in game.enemies_in_radius(global_position, s_radius):
			if smite_count >= targets:
				break
			game.damage_enemy(e, s_damage, {"source": "smite", "holy": true})
			game.spawn_fx(e.global_position, Color(1, 0.95, 0.7), 18.0, 0.2)
			game.spawn_perk_fx("smite", e.global_position, 38.0, 0.32)
			smite_count += 1
	if upg.flag_num("last_shot_lightning") > 0.0:
		game.lightning_strike_nearest(global_position, 300.0, upg.flag_num("last_shot_lightning") * dmg_multiplier())
	if upg.flag_num("last_shot_fan") > 0.0:
		var fan_n := int(upg.flag_num("last_shot_fan"))
		var fan_dmg := current_damage() * 0.15
		for i in fan_n:
			var a := TAU * float(i) / float(fan_n)
			game.spawn_bullet(global_position + Vector2.RIGHT.rotated(a) * 10.0, Vector2.RIGHT.rotated(a), fan_dmg,
				{"speed": 180.0, "radius": 3.0, "color": Gfx.hex(String(weapon.get("color", "#ffffff"))), "life": 1.5, "source": "fan"})
		game.spawn_perk_fx("wind", global_position, 52.0, 0.28)
		AudioManager.play_sfx("shot_heavy", 1.1)
	if upg.flag_num("last_shot_tornado") > 0.0:
		for i in int(upg.flag_num("last_shot_tornado")):
			game.spawn_ally("tornado", {"damage": 15.0 * float(S.summon_dmg), "duration": 3.0, "radius": 44.0})
	if upg.flag_num("last_shot_echo") > 0.0:
		game.aoe_damage(global_position, 120.0, current_damage() * upg.flag_num("last_shot_echo"), {"source": "echo"})

# ------------------------------------------------------------------ СКИЛЛ
func _tick_aim_mode() -> void:
	if bot or dead:
		return
	if Input.is_action_just_pressed("toggle_aim"):
		auto_aim = not auto_aim
		if game != null:
			game.notify("Автоприцел: %s" % ("включён" if auto_aim else "выключен"))

func _tick_skill(delta: float) -> void:
	_tick_aim_mode()
	skill_cd_left = maxf(0.0, skill_cd_left - delta)
	EventBus.skill_cooldown.emit(skill_cd_left, float(skill_data.get("cd", 10.0)))
	var pressed := (Input.is_action_just_pressed("skill") or Input.is_action_just_pressed("skill_mouse")) if not bot else bot_wants_skill
	if pressed and skill_cd_left <= 0.0 and not dead:
		_use_skill()

func _use_skill() -> void:
	var sid := String(skill_data.get("id", ""))
	var p: Dictionary = skill_data.get("params", {})
	skill_cd_left = 0.4 if OS.get_environment("SURW_SKILL_SPAM") != "" else float(skill_data.get("cd", 10.0))
	AudioManager.play_sfx("skill")
	EventBus.skill_used.emit(sid, skill_cd_left)
	if upg.flag_num("skill_meteor") > 0.0 and sid == "blink":
		_meteor_rain(aim_pos, int(upg.flag_num("skill_meteor")), upg.flag_num("skill_meteor_damage"))
		return
	match sid:
		"blink":
			var target := global_position + (aim_pos - global_position).normalized() * float(p.get("distance", 128.0))
			target = game.clamp_to_map(target)
			var from := global_position
			game.spawn_hazard_zone(from.lerp(target, 0.5), float(p.get("trail_dps", 4.0)) * dmg_multiplier(), float(p.get("trail_dur", 2.0)), 26.0, Color(1, 0.5, 0.2), {"pattern": "fire"})
			global_position = target
			game.spawn_fx(target, Color(1.0, 0.7, 0.3), 30.0, 0.25)
			game.spawn_perk_fx("fireball", from, 36.0, 0.25)
			game.spawn_perk_fx("fireball", target, 46.0, 0.30)
		"divine_shield":
			if upg.flag_on("skill_spear"):
				# «Святое Копьё»: вместо щита — мощный пронзающий снаряд
				var sdir := (aim_pos - global_position).normalized()
				game.spawn_bullet(global_position + sdir * 12.0, sdir, float(p.get("spear_damage", 15.0)) * dmg_multiplier(),
					{"speed": 420.0, "pierce": int(p.get("spear_pierce", 5)), "radius": 6.0, "life": 2.0,
					 "color": Color(1, 0.95, 0.5), "source": "smite", "holy": true})
				game.spawn_fx(global_position, Color(1, 0.95, 0.5), 30.0, 0.25)
				game.spawn_perk_fx("holy", global_position, 44.0, 0.28)
			else:
				shield_charges = int(p.get("absorb", 2))
				shield_recharge_left = float(p.get("duration", 5.0))
				game.spawn_fx(global_position, Color(1, 0.85, 0.3), 48.0, 0.4)
				game.spawn_perk_fx("holy", global_position, 56.0, 0.36)
		"dark_harvest":
			harvest_left = float(p.get("duration", 5.0))
			harvest_zones = 0
			game.spawn_hazard_zone(aim_pos, float(p.get("dps", 3.0)) * dmg_multiplier(),
				float(p.get("duration", 5.0)), float(p.get("radius", 32.0)), Color(0.4, 0.1, 0.6),
				{"slow": float(p.get("slow", 0.3)), "pattern": "void"})
			game.spawn_perk_fx("curse", aim_pos, 56.0, 0.35)
		"berserk":
			berserk_left = float(p.get("duration", 8.0))
			game.spawn_fx(global_position, Color(1, 0.35, 0.1), 48.0, 0.35)
			game.spawn_perk_fx("blood", global_position, 56.0, 0.35)
		"arrow_rain":
			# «Град Стрел» (Лиэль): веер стрел по кругу; поддерживаем и count, и arrows
			var ar: Dictionary = p
			var shots := int(ar.get("count", ar.get("arrows", 12)))
			for i in shots:
				var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(1, shots)))
				game.spawn_bullet(global_position + dir * 8.0, dir, float(ar.get("damage", 4.0)) * dmg_multiplier(),
					{"speed": float(ar.get("speed", 240.0)), "radius": 3.0, "life": float(ar.get("life", 2.5)),
					 "color": Color(0.45, 1.0, 0.35), "source": "arrow_rain"})
			game.spawn_fx(global_position, Color(0.45, 1.0, 0.35), 40.0, 0.25)
			game.spawn_perk_fx("wind", global_position, 54.0, 0.32)
		"shadow_dash":
			var from_pos := global_position
			var to_pos: Vector2 = game.clamp_to_map(global_position + (aim_pos - global_position).normalized() * float(p.get("distance", 192.0)))
			for enemy in game.enemies_in_radius(to_pos.lerp(from_pos, 0.5), float(p.get("distance", 192.0)) * 0.5):
				game.damage_enemy(enemy, float(p.get("damage", 6.0)) * dmg_multiplier(), {"source": "shadow_dash"})
			global_position = to_pos
			dash_buff_double = true
			AudioManager.play_sfx("dash", 1.0)
			game.spawn_fx(from_pos, Color(0.05, 0.05, 0.05), 30.0, 0.2)
			game.spawn_fx(to_pos, Color(0.05, 0.05, 0.05), 30.0, 0.2)
			game.spawn_perk_fx("curse", to_pos, 48.0, 0.28)
			if upg.flag_num("shadow_clones") > 0.0:
				for i in int(upg.flag_num("shadow_clones")):
					game.spawn_ally("shadow_clone", {"damage": 3.0 * float(S.summon_dmg), "duration": 5.0})
		"gravity_gun":
			game.pull_enemies(aim_pos, float(p.get("radius", 192.0)), float(p.get("force", 100.0)), float(p.get("duration", 3.0)))
			game.spawn_fx(aim_pos, Color(0.58, 0.0, 0.83), float(p.get("radius", 192.0)), 0.4)
			game.spawn_perk_fx("curse", aim_pos, 72.0, 0.40)
			if upg.flag_on("skill_blackhole"):
				# «Чёрная Дыра»: зона урона вместо пушки
				game.spawn_hazard_zone(aim_pos, 10.0 * dmg_multiplier(), 5.0, float(p.get("radius", 192.0)) * 0.5,
					Color(0.15, 0.0, 0.25), {"pattern": "void"})
		"aimed_shot":
			var adir := aim_dir
			var count_aimed := int(upg.flag_num("aimed_triple", 1))
			for i in count_aimed:
				var off := 0.0 if count_aimed <= 1 else deg_to_rad(10.0) * (float(i) / float(count_aimed - 1) - 0.5)
				game.spawn_bullet(global_position + adir * 12.0, adir.rotated(off), float(p.get("damage", 50.0)) * dmg_multiplier(),
					{"speed": float(p.get("speed", 640.0)), "pierce": int(p.get("pierce", 10)), "radius": 8.0,
					 "life": float(p.get("life", 3.0)), "color": Color(1, 0.85, 0.2), "source": "aimed", "crit": true})
			game.spawn_fx(global_position, Color(1, 0.85, 0.2), 30.0, 0.25)
			game.spawn_perk_fx("holy", global_position, 44.0, 0.26)
		"firestorm":
			game.spawn_hazard_zone(aim_pos, float(p.get("dps", 8.0)) * dmg_multiplier(), float(p.get("duration", 4.0)),
				float(p.get("radius", 96.0)), Color(1, 0.35, 0.1), {"burn": float(p.get("dps", 8.0)) if upg.flag_on("napalm") else 0.0, "pattern": "fire"})
			game.spawn_fx(aim_pos, Color(1, 0.35, 0.1), float(p.get("radius", 96.0)), 0.4)
			game.spawn_perk_fx("fireball", aim_pos, float(p.get("radius", 96.0)) * 0.85, 0.40)
		"divine_wave":
			game.aoe_damage(global_position, float(p.get("radius", 96.0)), float(p.get("damage", 20.0)) * dmg_multiplier(), {"holy": true, "source": "divine"})
			kills_retribution += 0
			game.spawn_fx(global_position, Color(1, 1, 0.8), float(p.get("radius", 96.0)), 0.35)
			game.spawn_perk_fx("holy", global_position, float(p.get("radius", 96.0)) * 0.9, 0.38)
		"raise_skeleton":
			var corpse: Vector2 = game.pop_corpse()
			var pos := corpse if corpse != Vector2.INF else global_position + Vector2.RIGHT * 20.0
			game.spawn_ally("skeleton", {"damage": float(p.get("damage", 6.0)) * float(S.summon_dmg), "duration": float(p.get("duration", 15.0)), "pos": pos})
			game.spawn_perk_fx("curse", pos, 36.0, 0.30)
		"blood_storm":
			var count := mag
			mag = 0
			EventBus.ammo_changed.emit(0, int(S.mag), false)
			for i in count:
				var dir := Vector2.RIGHT.rotated(randf() * TAU)
				game.spawn_bullet(global_position, dir, current_damage(), {"speed": float(S.proj_speed), "pierce": int(S.pierce), "bounce": int(S.bounce), "radius": 3.0 * float(S.size), "color": Color(0.9, 0.3, 0.2), "source": "blood_storm"})
			game.spawn_perk_fx("blood", global_position, 54.0, 0.30)
			start_reload()
		"turret":
			var mult := 1.5 if upg.flag_num("turret_master") > 0.0 else 1.0
			game.spawn_ally("turret", {"damage": float(p.get("damage", 10.0)) * float(S.summon_dmg), "duration": float(p.get("duration", 8.0)) * mult, "interval": float(p.get("interval", 0.35)) / (1.3 if upg.flag_num("turret_master") > 0.0 else 1.0), "pos": global_position})
			game.spawn_perk_fx("wind", global_position, 40.0, 0.26)
		"shadow_step":
			var t2 := global_position + move_input.normalized() * float(p.get("distance", 120.0)) if move_input.length() > 0.1 else global_position + aim_dir * float(p.get("distance", 120.0))
			var prev := global_position
			global_position = game.clamp_to_map(t2)
			if upg.flag_on("dash_double"):
				dash_buff_double = true
			AudioManager.play_sfx("dash", 1.05)
			game.spawn_ally("shadow_clone", {"damage": current_damage(), "duration": float(p.get("clone_dur", 2.0)), "pos": prev, "radius": float(p.get("radius", 44.0))})
			game.spawn_perk_fx("curse", prev, 42.0, 0.26)
			game.spawn_perk_fx("curse", global_position, 42.0, 0.26)
		"tornado":
			for i in int(p.get("count", 3)):
				var off := Vector2.RIGHT.rotated(TAU * float(i) / maxf(1.0, float(p.get("count", 3)))) * 40.0
				game.spawn_ally("tornado", {"damage": float(p.get("damage", 15.0)) * float(S.summon_dmg), "duration": float(p.get("duration", 3.0)), "radius": float(p.get("radius", 44.0)), "pos": global_position + off})
			game.spawn_perk_fx("wind", global_position, 64.0, 0.34)
		"heal_wave":
			heal(int(p.get("heal", 2)))
			upg.apply_flags({"aura_fire_rate": float(p.get("aura_fire_rate", 0.15))})
			set_timer("aura", float(p.get("duration", 5.0)))
			game.spawn_fx(global_position, Color(1, 0.9, 0.5), float(p.get("radius", 120.0)), 0.5)
			game.spawn_perk_fx("holy", global_position, 72.0, 0.40)
			game.spawn_ally("aura", {"damage": 0.0, "duration": float(p.get("duration", 5.0)), "radius": float(p.get("radius", 120.0))})
		"blood_cleave":
			game.aoe_damage(global_position, float(p.get("radius", 72.0)), float(p.get("damage", 30.0)) * dmg_multiplier(), {"source": "cleave"})
			heal(int(p.get("heal", 1)))
			game.spawn_fx(global_position, Color(0.8, 0.2, 0.2), float(p.get("radius", 72.0)), 0.3)
			game.spawn_perk_fx("blood", global_position, float(p.get("radius", 72.0)) * 0.95, 0.32)

func _meteor_rain(center: Vector2, count: int, dmg: float) -> void:
	for i in count:
		var pos := center + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		game.spawn_delayed_aoe(pos, 26.0, dmg * dmg_multiplier(), 0.45, Color(1, 0.5, 0.1))
		game.spawn_event_fx("meteor", pos, 0.45, 26.0)

# ------------------------------------------------------------------ УРОН ИГРОКУ
func take_damage(amount: int, from_pos: Vector2, ignore_iframes: bool = false) -> void:
	if dead or amount <= 0:
		return
	if GameManager.god_mode:
		return
	if not ignore_iframes and iframes > 0.0:
		return
	# уворот
	if not ignore_iframes and S.dodge > 0.0 and randf() < float(S.dodge):
		game.spawn_fx(global_position, Color(0.7, 0.9, 1.0), 22.0, 0.2)
		game.spawn_perk_fx("wind", global_position, 42.0, 0.28)
		return
	# щит
	if shield_charges > 0:
		shield_charges = 0
		shield_recharge_left = float(char_data.get("passive", {}).get("params", {}).get("recharge", upg.flag_num("shield_recharge", 120.0)))
		if shield_recharge_left <= 0.0:
			shield_recharge_left = 120.0
		game.spawn_fx(global_position, Color(0.8, 0.9, 1.0), 34.0, 0.25)
		game.spawn_perk_fx("holy", global_position, 56.0, 0.34)
		AudioManager.play_sfx("hit", 0.7)
		return
	var dmg := amount
	if S.dr > 0.0:
		dmg = int(ceil(float(dmg) * (1.0 - float(S.dr))))
	if upg.flag_on("fragile"):
		dmg = max_hp
	hp -= dmg
	damage_taken += float(dmg)
	iframes = float(DB.balance.get("player", {}).get("iframes", 0.6))
	AudioManager.play_sfx("hurt")
	game.shake(3.0)
	EventBus.player_damaged.emit(dmg, hp)
	EventBus.hp_changed.emit(maxi(hp, 0), max_hp)
	# реакции на урон
	if upg.flag_num("blood_rage") > 0.0 or String(char_data.get("passive", {}).get("id", "")) == "blood_rage":
		stacks["blood_rage_stacks"] = float(stacks.get("blood_rage_stacks", 0.0)) + 1.0
		upg.flags["blood_rage_stacks"] = float(stacks.get("blood_rage_stacks", 0.0))
	if upg.flag_num("rage_point") > 0.0:
		set_timer("rage_point", 30.0)
	if String(char_data.get("passive", {}).get("id", "")) == "wind_in_back" or upg.flag_num("wind_runner") > 0.0:
		stacks["wind"] = 0
	if upg.flag_on("wind_shadow"):
		stacks["wind_shadow"] = 0
	if upg.flag_on("unbending") or upg.flag_on("lowhp_fury"):
		pass
	if hp <= 0:
		_die_or_revive()

func _die_or_revive() -> void:
	if revives_left > 0:
		revives_left -= 1
		hp = 1
		iframes = 2.0
		EventBus.notify.emit(Loc.t("revive_used"))
		EventBus.hp_changed.emit(hp, max_hp)
		return
	if upg.flag_num("guardian_angel") > 0.0 and not guardian_used and hp <= 1:
		guardian_used = true
		hp = 1
		iframes = upg.flag_num("guardian_angel")
		EventBus.hp_changed.emit(hp, max_hp)
		return
	dead = true
	hp = 0
	EventBus.hp_changed.emit(0, max_hp)
	AudioManager.play_sfx("hurt", 0.6)
	died.emit()
	game.on_player_death()

func heal(amount: int) -> void:
	if dead or amount <= 0:
		return
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp != before:
		EventBus.player_healed.emit(hp - before, hp)
		EventBus.hp_changed.emit(hp, max_hp)
		if upg.flag_num("heal_growth") > 0.0:
			stacks["heal_growth"] = float(stacks.get("heal_growth", 1)) * (1.0 + upg.flag_num("heal_growth"))
			upg.apply_mods({"dmg": upg.flag_num("heal_growth"), "size": upg.flag_num("heal_growth") * 0.5})

# ------------------------------------------------------------------ СОБЫТИЯ БОЯ
func on_enemy_hit(enemy: Node2D, dmg: float) -> void:
	damage_dealt += dmg
	var passive_id := String(char_data.get("passive", {}).get("id", ""))
	if passive_id == "holy_strength":
		holy_hits = minf(float(char_data.get("passive", {}).get("params", {}).get("max_bonus", 3)),
			holy_hits + 1.0 / float(char_data.get("passive", {}).get("params", {}).get("every", 3)))
	if upg.flag_num("combo_crit") > 0.0:
		combo_hits += 1
	if float(S.lifesteal) > 0.0:
		timers["lifesteal_acc"] = float(timers.get("lifesteal_acc", 0.0)) + dmg * float(S.lifesteal)
		if float(timers["lifesteal_acc"]) >= 1.0:
			var whole := int(timers["lifesteal_acc"])
			timers["lifesteal_acc"] = float(timers["lifesteal_acc"]) - whole
			heal(whole)

func on_kill(enemy: Node2D) -> void:
	kills += 1
	add_weapon_xp(float(DB.balance.get("weapon_level", {}).get("xp_per_kill", 1)))
	if upg.flag_num("kill_stack_dmg") > 0.0:
		stacks["kill_stack_dmg"] = minf(float(upg.flag_num("kill_stack_max", 0.5)),
			float(stacks.get("kill_stack_dmg", 0.0)) + float(upg.flag_num("kill_stack_dmg")))
	if harvest_left > 0.0 and harvest_zones < int(char_data.get("skill", {}).get("params", {}).get("max", 3)):
		harvest_zones += 1
		var sp: Dictionary = char_data.get("skill", {}).get("params", {})
		game.spawn_hazard_zone(enemy.global_position, float(sp.get("dps", 3.0)) * dmg_multiplier() * 0.35,
			float(sp.get("duration", 5.0)), float(sp.get("radius", 32.0)), Color(0.4, 0.1, 0.6), {"slow": float(sp.get("slow", 0.3))})
	var role := String(enemy.role) if enemy.get("role") != null else "fodder"
	if String(enemy.last_source) in ["retribution","smite"]:
		kills_retribution+=1
	# Кровавый магазин
	if upg.flag_num("blood_mag") > 0.0:
		stacks["blood_mag"] = float(stacks.get("blood_mag", 0.0)) + upg.flag_num("blood_mag")
	# Душа-рыцарь / Ритуал Крови / прочее
	var curse_kill:bool=String(enemy.last_source) in ["curse","curse_dot"]
	var cursed_enemy:bool=enemy.has_status("curse") or curse_kill
	if upg.flag_num("blood_ritual")>0.0 and curse_kill:
		kills_curse+=1
		if kills_curse%10==0: upg.apply_mods({"dmg":upg.flag_num("blood_ritual")}); recalc(); game.notify("Ритуал Крови: урон увеличен")
	if upg.flag_on("summon_souls") or String(char_data.get("passive", {}).get("id", "")) == "soul_harvest":
		game.spawn_ally("spirit", {"damage": 8.0 * float(S.summon_dmg), "duration": 6.0})
	if upg.flag_on("curse_soul") and cursed_enemy:
		game.spawn_ally("spirit", {"damage": 8.0 * float(S.summon_dmg), "duration": 6.0})
	if upg.flag_on("scythe_soul") and String(enemy.last_source) == "scythe":
		game.spawn_ally("spirit", {"damage": 8.0 * float(S.summon_dmg), "duration": 6.0})
	if upg.flag_num("split_on_kill") > 0.0:
		var n := int(upg.flag_num("split_on_kill"))
		for i in n:
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(1, n)))
			game.spawn_bullet(enemy.global_position, dir, current_damage() * upg.flag_num("split_dmg", 0.1), {"speed": float(S.proj_speed), "radius": 2.5, "color": Color(1, 0.9, 0.5), "source": "split"})
		game.spawn_perk_fx("wind", enemy.global_position, 32.0, 0.22)
	if upg.flag_num("kill_heal") > 0.0 and randf() < upg.flag_num("kill_heal"):
		heal(1)
		game.spawn_perk_fx("holy", global_position, 36.0, 0.26)
	if upg.flag_on("sword_and_shield") and String(enemy.last_source) in ["retribution","smite"]:
		shield_recharge_left=maxf(0.0,shield_recharge_left-1.0)
		if shield_recharge_left<=0.0:
			shield_charges=1
			game.spawn_perk_fx("smite", global_position, 48.0, 0.30)
	if upg.flag_on("beast_kill_stack"):
		var need := maxi(1, int(upg.flag_num("beast_kill_stack")))
		if kills % need == 0:
			upg.apply_mods({"summon_dmg": 0.01})
			recalc()
			game.spawn_perk_fx("blood", global_position, 40.0, 0.28)
	if String(enemy.last_source) in ["retribution", "smite"]:
		if upg.flag_on("justice") and int(stacks.get("justice_hp", 0)) < 3:
			var jk := int(stacks.get("justice_kills", 0)) + 1
			if jk >= 500:
				jk -= 500
				stacks["justice_hp"] = int(stacks.get("justice_hp", 0)) + 1
				upg.apply_mods({"hp": 1})
				recalc()
			stacks["justice_kills"] = jk
		if upg.flag_on("heaven_bless"):
			var bk := int(stacks.get("bless_kills", 0)) + 1
			if bk >= 500:
				bk -= 500
				heal(1)
			stacks["bless_kills"] = bk
	if upg.flag_num("bodiless_kills") > 0.0 and kills % int(upg.flag_num("bodiless_kills")) == 0:
		bodiless_left = upg.flag_num("bodiless_dur", 2.0)
	# сброс духов для некроманта
	if role == "boss":
		AudioManager.play_sfx("kill", 0.8)

func on_soul_collected() -> void:
	souls_collected+=1
	game.spawn_perk_fx("curse", global_position, 36.0, 0.28)
	if upg.flag_num("soul_convert")>0.0:
		soul_convert_pending+=1
		if soul_convert_left<=0.0: soul_convert_left=upg.flag_num("soul_convert")

func on_level_up(new_level: int) -> void:
	level = new_level
	if upg.flag_num("amulet_growth") > 0.0 and new_level % 5 == 0:
		heal(1)

# ------------------------------------------------------------------ АВТОИГРА (тест)
func _bot_think(delta: float) -> void:
	# Бот для автоматических проверок: стреляет по ближайшему, отходит от толпы,
	# подбирает орбы, когда рядом никого нет.
	var nearby: Array = game.enemies_in_radius(global_position, 320.0)
	bot_wants_fire = false
	bot_wants_skill = false
	if nearby.is_empty():
		move_input = Vector2.ZERO
		if game.has_pickups_near(global_position, 400.0):
			var orb: Vector2 = game.nearest_pickup_pos(global_position, 400.0)
			if orb != Vector2.INF:
				move_input = (orb - global_position).normalized()
		return
	# прицел — самый близкий враг
	var nearest_enemy: Node2D = nearby[0]
	var best_d := global_position.distance_to(nearest_enemy.global_position)
	for enemy in nearby:
		var d: float = global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			nearest_enemy = enemy
	aim_pos = nearest_enemy.global_position
	# босс в приоритете — как у живого игрока
	if game.boss_enemy != null and game.boss_enemy.active and global_position.distance_to(game.boss_enemy.global_position) < 420.0:
		aim_pos = game.boss_enemy.global_position
	bot_wants_fire = true
	# отход от плотности врагов
	var flee := Vector2.ZERO
	var close_count := 0
	for enemy in nearby:
		var d2: Vector2 = global_position - enemy.global_position
		var length := maxf(d2.length(), 1.0)
		if length < 170.0:
			flee += d2 / length * (170.0 - length) / 170.0
			close_count += 1
	var desired := Vector2.ZERO
	if close_count > 2:
		desired = flee.normalized()
	elif best_d > 230.0:
		# подойти на дистанцию стрельбы, если врагов мало
		desired = (nearest_enemy.global_position - global_position).normalized() * 0.6
		if game.has_pickups_near(global_position, 300.0):
			var orb2: Vector2 = game.nearest_pickup_pos(global_position, 300.0)
			if orb2 != Vector2.INF:
				desired = (orb2 - global_position).normalized()
	elif close_count > 0:
		# при небольшом числе врагов бот не забывает собирать опыт
		desired = flee.normalized()
		var orb3: Vector2 = game.nearest_pickup_pos(global_position, 220.0)
		if orb3 != Vector2.INF:
			desired = (desired * 0.5 + (orb3 - global_position).normalized() * 0.5).normalized()
	# не прижиматься к краю карты
	var edge := 90.0
	var pos := global_position
	if pos.x < edge:
		desired += Vector2.RIGHT * 0.8
	elif pos.x > game.map_rect.size.x - edge:
		desired += Vector2.LEFT * 0.8
	if pos.y < edge:
		desired += Vector2.DOWN * 0.8
	elif pos.y > game.map_rect.size.y - edge:
		desired += Vector2.UP * 0.8
	move_input = desired.normalized() if desired.length() > 0.05 else Vector2.ZERO
	bot_wants_skill = skill_cd_left <= 0.0 and (close_count > 4 or OS.get_environment("SURW_SKILL_SPAM") != "")
	if mag <= 0 and not reloading:
		start_reload()

var bot_wants_skill := false
