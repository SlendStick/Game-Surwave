extends Control
## Главное меню: играть, магазины, альбом, достижения, настройки, выход.

var overlay: Control = null
var panel_content: VBoxContainer = null
var shop_tab := "characters"
var album_tab := "enemies"
var souls_lbl: Label
var gold_lbl: Label

const ACHIEVEMENTS := [
	{"id": "first_win", "name": "Первая победа", "desc": "Победить на любой карте."},
	{"id": "campaign", "name": "Покоритель карт", "desc": "Победить на всех 11 картах."},
	{"id": "endless", "name": "Бесконечность", "desc": "Победить Мордрета в Проклятых Руинах."},
	{"id": "grotgar_nohit", "name": "Безупречный бой", "desc": "Убить Гротгара, не получив урона."},
	{"id": "infernal_entry", "name": "Врата Пустоты", "desc": "Войти в ПУСТОТУ через пентаграмму."},
	{"id": "satanail_slayer", "name": "Покоритель Ада", "desc": "Победить Сатанаила."},
	{"id": "sathan_slayer", "name": "Падший Ангел", "desc": "Победить САТАНА за паладина."},
	{"id": "darkness_5", "name": "Мрак 5", "desc": "Победить на уровне Тьмы 5."},
	{"id": "darkness_10", "name": "Мрак 10", "desc": "Победить на уровне Тьмы 10."},
	{"id": "darkness_15", "name": "Мрак 15", "desc": "Победить на уровне Тьмы 15."},
	{"id": "kills_1000", "name": "Тысяча", "desc": "Убить 1000 врагов всего."},
	{"id": "all_chars", "name": "Все герои", "desc": "Открыть всех персонажей."},
]

func _ready() -> void:
	if OS.get_environment("SURW_MENU_OVERLAY") != "":
		call_deferred("_open_overlay", OS.get_environment("SURW_MENU_OVERLAY"))
	_build()
	AudioManager.set_boss_layer(false)
	AudioManager.stop_ambience()
	AudioManager.play_music({"root": 50, "scale": "minor", "tempo": 64, "wave": "lute"})
	AudioManager.set_intensity(0.0)

func _build() -> void:
	UI.full_rect(self)
	UI.backdrop(self, Color("#0b0c10"))
	var slideshow: Control = load("res://scripts/ui/menu_gameplay_bg.gd").new()
	slideshow.name = "MenuGameplayBg"
	slideshow.position = Vector2.ZERO
	slideshow.size = Vector2(640.0, 360.0)
	UI.full_rect(slideshow)
	add_child(slideshow)
	slideshow.queue_redraw()

	# --- левая часть: логотип и подпись
	var logo := UI.title(self, "SURWAVE", 40, Vector2(38, 54), UI.GOLD)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	UI.label(self, "выживание · рогалик · ручная стрельба", 9, UI.DIM, Vector2(42, 100))
	UI.divider(self, Vector2(42, 114), 250.0, UI.GOLD_DEEP)

	# --- карточка героя дня: готический герб и герои в пиксель-арте
	var crest_tex := Assets.icon("ui_crest")
	if crest_tex != null:
		var crest := TextureRect.new()
		crest.texture = crest_tex
		crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.position = Vector2(90, 152)
		crest.size = Vector2(76, 76)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(crest)
		var hero_classes: PackedStringArray = ["paladin", "mage", "necromancer"]
		for idx_h in hero_classes.size():
			var h_cls: String = hero_classes[idx_h]
			var htex := Assets.icon(h_cls)
			if htex != null:
				var hr := TextureRect.new()
				hr.texture = htex
				hr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				hr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				hr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hr.position = Vector2(68 + idx_h * 42, 232)
				hr.size = Vector2(36, 36)
				hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(hr)
	UI.label(self, "версия 1.4.16", 8, UI.MUTED, Vector2(42, 283))

	# --- правая часть: меню на полупрозрачной готической раме поверх живого геймплея
	var menu_frame := Panel.new()
	menu_frame.position = Vector2(342, 46)
	menu_frame.size = Vector2(272, 246)
	menu_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_frame.add_theme_stylebox_override("panel", UI.style(Color(0.045, 0.048, 0.062, 0.72), UI.GOLD_DEEP, 1, 0))
	add_child(menu_frame)

	var menu := Control.new()
	menu.position = Vector2(352, 56)
	menu.size = Vector2(252, 240)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var play := UI.primary_button(menu, Loc.t("play"), 14, Vector2(252, 34))
	play.position = Vector2(0, 0)
	play.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui")
		GameManager.goto_select())
	var y := 44
	for item in [
		[Loc.t("album"), "album"],
		["ДРЕВО ПРОГРЕССИИ", "progression"],
		["ЗАДАНИЯ И СЕЗОН", "quests"],
		["РЕКОРДЫ И ГАЛЕРЕЯ", "records"],
		[Loc.t("achievements"), "achievements"],
		[Loc.t("settings"), "settings"],
	]:
		var btn := UI.button(menu, String(item[0]), 10, Vector2(252, 24))
		btn.position = Vector2(0, y)
		var key := String(item[1])
		btn.pressed.connect(func() -> void: _open_overlay(key))
		y += 27
	var quit := UI.button(menu, Loc.t("quit"), 10, Vector2(252, 24))
	quit.position = Vector2(0, y + 4)
	quit.pressed.connect(func() -> void: get_tree().quit())

	# --- нижняя панель со статистикой
	var info := UI.panel(self, Rect2(30, 300, 580, 50), UI.PANEL, UI.BORDER)
	var line := ColorRect.new()
	line.color = Color(0.36, 0.37, 0.41, 0.8)
	line.position = Vector2(0, 0)
	line.size = Vector2(580, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(line)
	souls_lbl = UI.label(info, "", 9, UI.PURPLE, Vector2(12, 8))
	gold_lbl = UI.label(info, "", 9, UI.GOLD, Vector2(12, 24))
	var ctrl_lbl := UI.crisp_label(info, Loc.t("controls"), 8, UI.MUTED, Vector2(214, 7))
	ctrl_lbl.size = Vector2(354, 36)
	ctrl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctrl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ctrl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctrl_lbl.clip_text = true
	_refresh_info()

func _refresh_info() -> void:
	if souls_lbl == null:
		return
	souls_lbl.text = "%s: %d" % [Loc.t("souls").capitalize(), int(GameManager.meta.get("souls", 0))]
	gold_lbl.text = "%s: %d   ·   %s: %d" % [Loc.t("gold").capitalize(), int(GameManager.meta.get("gold", 0)), Loc.t("stats_runs"), int(GameManager.meta.get("stats", {}).get("runs", 0))]

# ------------------------------------------------------------------ ОВЕРЛЕЙ
func _open_overlay(kind: String) -> void:
	AudioManager.play_sfx("ui")
	if overlay != null:
		overlay.queue_free()
	overlay = Control.new()
	UI.full_rect(overlay)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.015, 0.02, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.full_rect(dim)
	overlay.add_child(dim)
	var panel := UI.panel(overlay, Rect2(24, 18, 592, 324), UI.PANEL, UI.BORDER_HI)
	var accent := ColorRect.new()
	accent.color = Color(0.42, 0.43, 0.47, 0.75)
	accent.position = Vector2(1, 1)
	accent.size = Vector2(590, 1)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)
	var titles := {"shops": Loc.t("shops"), "album": Loc.t("album"), "progression":"ДРЕВО ПРОГРЕССИИ", "quests":"ЗАДАНИЯ И СЕЗОН", "records":"ЛОКАЛЬНЫЕ РЕКОРДЫ И ГАЛЕРЕЯ", "achievements": Loc.t("achievements"), "settings": Loc.t("settings")}
	UI.label(panel, String(titles.get(kind, "")), 14, UI.GOLD, Vector2(10, 6))
	var back := UI.button(panel, Loc.t("back"), 9, Vector2(70, 20))
	back.position = Vector2(508, 6)
	back.pressed.connect(func() -> void:
		overlay.queue_free()
		overlay = null
		_refresh_info())
	var body := Control.new()
	body.position = Vector2(10, 28)
	body.size = Vector2(572, 288)
	panel.add_child(body)
	match kind:
		"shops": _build_shops(body)
		"album": _build_album(body)
		"progression": _build_progression(body)
		"quests": _build_quests(body)
		"records": _build_records(body)
		"achievements": _build_achievements(body)
		"settings": _build_settings(body)

func _shops_tabs(parent: Control) -> void:
	var tabs: Array = [["characters", Loc.t("shops_chars")], ["weapons", Loc.t("shops_weapons")], ["amulets", Loc.t("shops_amulets")]]
	var x := 0
	for tab in tabs:
		var b := UI.button(parent, String(tab[1]), 9, Vector2(96, 20))
		b.position = Vector2(x, 0)
		var id := String(tab[0])
		b.pressed.connect(func() -> void:
			shop_tab = id
			_open_overlay("shops"))
		x += 100
	UI.label(parent, "%s: %d" % [Loc.t("souls"), int(GameManager.meta.get("souls", 0))], 10, UI.PURPLE, Vector2(440, 2))

func _add_icon(parent: Control, icon_name: String, sz: int = 18) -> void:
	var t := Assets.icon(icon_name)
	if t == null:
		return
	var r := TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _build_shops(body: Control) -> void:
	_shops_tabs(body)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 26)
	scroll.size = Vector2(572, 262)
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 3)
	scroll.add_child(v)
	match shop_tab:
		"characters":
			for ch in DB.characters:
				var id := String(ch["id"])
				var owned := GameManager.is_char_unlocked(id)
				var price := int(ch.get("price", 0))
				var h := UI.hbox(v, 6)
				_add_icon(h, String(ch.get("cls", "")), 18)
				var txt := "%s (%s) — HP %d" % [String(ch["name"]), String(ch["role"]), int(ch["hp"])]
				if String(ch.get("unlock", "")) != "":
					txt = "%s — открывается особым условием" % String(ch["name"])
				var l := UI.label(h, txt, 9, UI.TEXT if owned else UI.DIM)
				l.custom_minimum_size = Vector2(356, 16)
				if owned:
					UI.label(h, "куплен", 8, UI.GREEN)
				elif String(ch.get("unlock", "")) != "":
					UI.label(h, "секрет", 8, UI.PURPLE)
				else:
					var b := UI.button(h, "%s (%d)" % [Loc.t("buy"), price], 8, Vector2(120, 18))
					b.disabled = int(GameManager.meta.get("souls", 0)) < price
					b.pressed.connect(func() -> void:
						if GameManager.buy_character(id):
							AudioManager.play_sfx("gold")
						else:
							AudioManager.play_sfx("error")
						_open_overlay("shops"))
		"weapons":
			for w in DB.weapons:
				var wid := String(w["id"])
				var owned := GameManager.is_weapon_unlocked(wid)
				var price := int(w.get("price", 0))
				var h := UI.hbox(v, 6)
				_add_icon(h, "icon_weapon_" + wid, 18)
				var l := UI.label(h, "%s — %s" % [String(w["name"]), String(w.get("desc", ""))], 9, UI.TEXT if owned else UI.DIM)
				l.custom_minimum_size = Vector2(356, 16)
				if owned:
					UI.label(h, "куплен", 8, UI.GREEN)
				elif String(w.get("unlock", "")) != "":
					UI.label(h, "особое условие", 8, UI.PURPLE)
				else:
					var b := UI.button(h, "%s (%d)" % [Loc.t("buy"), price], 8, Vector2(120, 18))
					b.disabled = int(GameManager.meta.get("souls", 0)) < price
					b.pressed.connect(func() -> void:
						if GameManager.buy_weapon(wid):
							AudioManager.play_sfx("gold")
						else:
							AudioManager.play_sfx("error")
						_open_overlay("shops"))
		"amulets":
			for amu in DB.amulets:
				var aid := String(amu["id"])
				var rank := GameManager.amulet_rank(aid)
				var cost := GameManager.amulet_cost(aid)
				var h := UI.hbox(v, 6)
				_add_icon(h, "icon_" + aid, 18)
				var l := UI.label(h, "%s [%s] (%s %d/5) — %s" % [String(amu["name"]), String(amu["type"]), Loc.t("rank"), rank, String(amu.get("desc", ""))], 8, UI.TEXT if rank > 0 else UI.DIM)
				l.custom_minimum_size = Vector2(346, 16)
				if cost > 0:
					var b := UI.button(h, "%s (%d)" % [Loc.t("upgrade_rank"), cost], 8, Vector2(100, 18))
					b.disabled = int(GameManager.meta.get("souls", 0)) < cost
					b.pressed.connect(func() -> void:
						GameManager.upgrade_amulet(aid)
						_open_overlay("shops"))
				else:
					UI.label(h, "макс.", 8, UI.GREEN)
				if rank > 0:
					var eq := UI.button(h, "экип." if not GameManager.amulet_equipped(aid) else "снять", 8, Vector2(54, 18))
					eq.pressed.connect(func() -> void:
						GameManager.toggle_amulet(aid)
						_open_overlay("shops"))

func _build_progression(body: Control) -> void:
	UI.label(body, "Осколки Душ: %d   ·   Рейтинг навыка: %d/1000" % [int(GameManager.meta.get("souls",0)), int(GameManager.meta.get("skill_rating",300))], 10, UI.GOLD, Vector2(0,0))
	UI.label(body, "Постоянные улучшения применяются в начале каждого забега.", 8, UI.DIM, Vector2(0,18))
	var branches := ["power","fortitude","speed","luck","mastery"]
	var names := {"power":"СИЛА · +3% урона/ур.","fortitude":"СТОЙКОСТЬ · HP/защита/лечение","speed":"СКОРОСТЬ · движение/темп","luck":"УДАЧА · золото/редкость/события","mastery":"МАСТЕРСТВО · персонажи/карты/режимы"}
	var v := UI.vbox(body, 7); v.position = Vector2(0,42); v.size = Vector2(560,230)
	for branch in branches:
		var h := UI.hbox(v,8)
		var lv := Progression.tree_level(branch); var max_lv := int(Progression.cfg.tree[branch].max); var cost := Progression.tree_cost(branch)
		var l := UI.label(h, "%s   %d/%d" % [names[branch],lv,max_lv], 9, UI.TEXT); l.custom_minimum_size = Vector2(390,22)
		var b := UI.button(h, "МАКС." if cost < 0 else "Купить · %d ОД" % cost, 8, Vector2(145,22)); b.disabled = cost < 0 or int(GameManager.meta.get("souls",0)) < cost
		b.pressed.connect(func() -> void:
			Progression.buy_tree(branch)
			_open_overlay("progression"))

func _build_quests(body: Control) -> void:
	UI.label(body, "Кристаллы редкости: %d · всё хранится локально" % int(GameManager.meta.get("crystals",0)), 9, UI.PURPLE, Vector2(0,0))
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(0,22); scroll.size=Vector2(570,264); body.add_child(scroll)
	var v:=VBoxContainer.new(); v.custom_minimum_size=Vector2(550,0); v.add_theme_constant_override("separation",4); scroll.add_child(v)
	for group in ["daily","weekly"]:
		UI.label(v,"ЕЖЕДНЕВНЫЕ" if group=="daily" else "ЕЖЕНЕДЕЛЬНЫЕ",10,UI.GOLD)
		var arr:Array=GameManager.meta.get("quests",{}).get(group,[])
		for i in arr.size():
			var q:Dictionary=arr[i]; var h:=UI.hbox(v,6); var l:=UI.label(h,"%s — %d/%d · %d ОД + %d КР"%[q.name,q.progress,q.goal,q.souls,q.crystals],8,UI.GREEN if int(q.progress)>=int(q.goal) else UI.TEXT); l.custom_minimum_size=Vector2(420,20)
			var claim:=UI.button(h,"ПОЛУЧЕНО" if q.claimed else "ПОЛУЧИТЬ",8,Vector2(110,20)); claim.disabled=q.claimed or int(q.progress)<int(q.goal); claim.pressed.connect(func(): Progression.claim(group,i); _open_overlay("quests"))
	UI.label(v,"СЕЗОН · ПРОБУЖДЕНИЕ ТЬМЫ",10,UI.GOLD)
	var seasonal:Array=GameManager.meta.get("season",{}).get("tasks",[])
	for i in seasonal.size():
		var q:Dictionary=seasonal[i]; var h:=UI.hbox(v,6); var l:=UI.label(h,"%s — %d/%d · %d ОД + %d КР"%[q.name,q.progress,q.goal,q.souls,q.crystals],8,UI.GREEN if int(q.progress)>=int(q.goal) else UI.TEXT); l.custom_minimum_size=Vector2(420,20)
		var claim:=UI.button(h,"ПОЛУЧЕНО" if q.claimed else "ПОЛУЧИТЬ",8,Vector2(110,20)); claim.disabled=q.claimed or int(q.progress)<int(q.goal); claim.pressed.connect(func(): Progression.claim_season(i); _open_overlay("quests"))

func _build_records(body: Control) -> void:
	var scroll:=ScrollContainer.new(); scroll.size=Vector2(570,285); body.add_child(scroll)
	var v:=VBoxContainer.new(); v.custom_minimum_size=Vector2(550,0); scroll.add_child(v)
	UI.label(v,"ТОП-10 ЛОКАЛЬНЫХ РЕЗУЛЬТАТОВ",10,UI.GOLD)
	var board:Array=GameManager.meta.get("leaderboard",[])
	for i in mini(10,board.size()):
		var r:Dictionary=board[i]; UI.label(v,"%d. %d очк. · %d убийств · %s · %s · %s"%[i+1,r.score,r.kills,r.character,r.map,String(r.date)],8,UI.TEXT)
	UI.label(v,"ГАЛЕРЕЯ ФОТО-СТОПА",10,UI.GOLD)
	var dir:=DirAccess.open("user://screenshots")
	if dir==null: UI.label(v,"Снимков пока нет. В забеге: F12 → Space.",8,UI.DIM)
	else:
		var files:=dir.get_files(); files.reverse()
		for i in mini(20,files.size()): UI.label(v,String(files[i]),8,UI.TEXT)

func _build_album(body: Control) -> void:
	var tabs: Array = [["enemies", Loc.t("album_enemies")], ["bosses", Loc.t("album_bosses")], ["chars", Loc.t("album_chars")], ["weapons", Loc.t("album_weapons")]]
	var x := 0
	for tab in tabs:
		var b := UI.button(body, String(tab[1]), 9, Vector2(96, 20))
		b.position = Vector2(x, 0)
		var id := String(tab[0])
		b.pressed.connect(func() -> void:
			album_tab = id
			_open_overlay("album"))
		x += 100
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 26)
	scroll.size = Vector2(572, 262)
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	scroll.add_child(v)
	match album_tab:
		"enemies":
			for e in DB.enemies:
				var eid := String(e["id"])
				var seen: bool = (GameManager.meta.get("album_enemies", []) as Array).has(eid)
				var h := UI.hbox(v, 8)
				var p_name := "portrait_" + eid
				if seen:
					_add_icon(h, p_name if Assets.has_real_sprite(p_name) else eid, 40)
				else:
					var lock_box := UI.panel(h, Rect2(0, 0, 40, 40), Color("#0b0c10"), UI.BORDER)
					lock_box.custom_minimum_size = Vector2(40, 40)
				var text := "%s — %s" % [String(e["name"]), String(e.get("desc", ""))] if seen else ("%s — %s" % [String(e["name"]), Loc.t("not_met")])
				var lbl := UI.label(h, text, 8, UI.TEXT if seen else UI.DIM)
				lbl.custom_minimum_size = Vector2(490, 0)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		"bosses":
			var keys := (DB.bosses as Dictionary).keys()
			for k in keys:
				var bd: Dictionary = DB.bosses[k]
				var bid := String(bd.get("id", ""))
				var seen := (GameManager.meta.get("album_bosses", []) as Array).has(bid)
				var h := UI.hbox(v, 8)
				if seen:
					var bp := "portrait_" + bid
					var bmap := "portrait_boss_" + String(k)
					var bicon := bp if Assets.has_real_sprite(bp) else (bmap if Assets.has_real_sprite(bmap) else "portrait_boss_champion")
					_add_icon(h, bicon, 44)
				else:
					var lock_b := UI.panel(h, Rect2(0, 0, 44, 44), Color("#0b0c10"), UI.BORDER)
					lock_b.custom_minimum_size = Vector2(44, 44)
				var b_lbl := UI.label(h, "%s — HP %d%s" % [String(bd.get("name", "")), int(bd.get("hp", 0)), (" · " + String(bd.get("desc", ""))) if seen else " · " + Loc.t("not_met")], 8, UI.TEXT if seen else UI.DIM)
				b_lbl.custom_minimum_size = Vector2(486, 0)
				b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var st: Dictionary = DB.sathan
			var seen2 := bool(GameManager.meta.get("sathan_defeated", false))
			var hs := UI.hbox(v, 8)
			if seen2:
				_add_icon(hs, "portrait_boss_satan", 44)
			else:
				var lock_s := UI.panel(hs, Rect2(0, 0, 44, 44), Color("#0b0c10"), UI.BORDER)
				lock_s.custom_minimum_size = Vector2(44, 44)
			var s_lbl := UI.label(hs, "%s — HP %d · %s" % [String(st.get("name", "САТАН")), int(st.get("hp", 0)), String(st.get("desc", "")) if seen2 else Loc.t("not_met")], 8, UI.TEXT if seen2 else UI.DIM)
			s_lbl.custom_minimum_size = Vector2(486, 0)
			s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		"chars":
			for ch in DB.characters:
				var unlocked := GameManager.is_char_unlocked(String(ch["id"]))
				var h := UI.hbox(v, 8)
				var cls_name := String(ch.get("cls", ""))
				if unlocked:
					_add_icon(h, "portrait_" + cls_name if Assets.has_real_sprite("portrait_" + cls_name) else cls_name, 42)
				else:
					var lock_c := UI.panel(h, Rect2(0, 0, 42, 42), Color("#0b0c10"), UI.BORDER)
					lock_c.custom_minimum_size = Vector2(42, 42)
				var c_lbl := UI.label(h, "%s (%s) — %s" % [String(ch["name"]), String(ch["role"]), String(ch.get("passive", {}).get("desc", ""))] if unlocked else Loc.t("not_met"), 8, UI.TEXT if unlocked else UI.DIM)
				c_lbl.custom_minimum_size = Vector2(488, 0)
				c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		"weapons":
			for w in DB.weapons:
				var wid := String(w["id"])
				var owned := GameManager.is_weapon_unlocked(wid)
				var h := UI.hbox(v, 6)
				if owned:
					_add_icon(h, "icon_weapon_" + wid, 22)
				UI.label(h, "%s — %s" % [String(w["name"]), String(w.get("desc", ""))] if owned else Loc.t("not_met"), 8, UI.TEXT if owned else UI.DIM)

func _build_achievements(body: Control) -> void:
	UI.label(body, Loc.t("achievements_empty"), 8, UI.DIM, Vector2(0, 2))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 20)
	scroll.size = Vector2(572, 268)
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	scroll.add_child(v)
	var got: Array = GameManager.meta.get("achievements", [])
	for a in ACHIEVEMENTS:
		var unlocked := got.has(String(a["id"]))
		UI.label(v, "%s %s — %s" % ["✔" if unlocked else "✖", String(a["name"]), String(a["desc"])], 9, UI.GREEN if unlocked else UI.DIM)
	var st: Dictionary = GameManager.meta.get("stats", {})
	UI.label(v, "%s: %d · %s: %d · %s: %d" % [Loc.t("stats_kills"), int(st.get("kills", 0)), Loc.t("stats_runs"), int(st.get("runs", 0)), Loc.t("stats_wins"), int(st.get("wins", 0))], 9, UI.TEXT)

func _build_settings(body: Control) -> void:
	var y := 6
	UI.label(body, Loc.t("music"), 10, UI.TEXT, Vector2(0, y))
	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = float(GameManager.setting("music", 0.8))
	music.position = Vector2(120, y)
	music.size = Vector2(180, 16)
	music.value_changed.connect(func(val: float) -> void:
		GameManager.set_setting("music", val))
	body.add_child(music)
	y += 28
	UI.label(body, Loc.t("sfx"), 10, UI.TEXT, Vector2(0, y))
	var sfx := HSlider.new()
	sfx.min_value = 0.0
	sfx.max_value = 1.0
	sfx.step = 0.05
	sfx.value = float(GameManager.setting("sfx", 0.8))
	sfx.position = Vector2(120, y)
	sfx.size = Vector2(180, 16)
	sfx.value_changed.connect(func(val: float) -> void:
		GameManager.set_setting("sfx", val)
		AudioManager.play_sfx("ui"))
	body.add_child(sfx)
	y += 28
	var lang_btn := UI.button(body, "%s: %s" % [Loc.t("lang"), "RU" if Loc.lang == "ru" else "EN"], 9, Vector2(150, 20))
	lang_btn.position = Vector2(0, y)
	lang_btn.pressed.connect(func() -> void:
		GameManager.set_setting("lang", "en" if Loc.lang == "ru" else "ru")
		_open_overlay("settings"))
	y += 26
	var shake_btn := UI.button(body, "%s: %s" % [Loc.t("shake"), Loc.t("on") if bool(GameManager.setting("shake", true)) else Loc.t("off")], 9, Vector2(150, 20))
	shake_btn.position = Vector2(0, y)
	shake_btn.pressed.connect(func() -> void:
		GameManager.set_setting("shake", not bool(GameManager.setting("shake", true)))
		_open_overlay("settings"))
	y += 26
	var god_btn := UI.button(body, "%s: %s" % [Loc.t("god_mode"), Loc.t("on") if bool(GameManager.setting("god_mode", false)) else Loc.t("off")], 9, Vector2(190, 20))
	god_btn.position = Vector2(0, y)
	god_btn.pressed.connect(func() -> void:
		GameManager.set_setting("god_mode", not bool(GameManager.setting("god_mode", false)))
		GameManager.god_mode = bool(GameManager.setting("god_mode", false))
		_open_overlay("settings"))
	var vitals_btn := UI.button(body, "Патроны и HP: %s" % ("над игроком" if String(GameManager.setting("hud_vitals", "corner")) == "player" else "слева сверху"), 9, Vector2(220, 20))
	vitals_btn.position = Vector2(0, y + 26)
	vitals_btn.pressed.connect(func() -> void:
		var now := String(GameManager.setting("hud_vitals", "corner"))
		GameManager.set_setting("hud_vitals", "corner" if now == "player" else "player")
		_open_overlay("settings"))
	var reset := UI.button(body, Loc.t("reset_save"), 9, Vector2(170, 20))
	reset.position = Vector2(240, y)
	reset.pressed.connect(func() -> void:
		SaveManager.reset()
		GameManager.meta = SaveManager.data
		GameManager.god_mode = false
		Loc.set_lang("ru")
		_open_overlay("settings"))
	UI.label(body, "God mode — только для проверки, влияет на получаемый урон.", 8, UI.DIM, Vector2(0, y + 50))
	var fx_keys := [["boss_fx","Постановка боссов"],["slowmo","Замедления"],["qte","QTE"],["post_fx","Экранные эффекты"]]
	var fy := 62
	for pair in fx_keys:
		var key := String(pair[0]); var b := UI.button(body, "%s: %s" % [pair[1], "ВКЛ" if bool(GameManager.setting(key,true)) else "ВЫКЛ"], 8, Vector2(190,20))
		b.position = Vector2(350,fy); fy += 26
		b.pressed.connect(func() -> void:
			GameManager.set_setting(key,not bool(GameManager.setting(key,true)))
			_open_overlay("settings"))

func _process(_delta: float) -> void:
	_refresh_info()

func _input(event: InputEvent) -> void:
	if overlay != null and event.is_action_pressed("pause"):
		overlay.queue_free()
		overlay = null
		_refresh_info()
		get_viewport().set_input_as_handled()
