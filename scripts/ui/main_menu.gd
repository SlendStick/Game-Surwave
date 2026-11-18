extends Control
## Главное меню: играть, магазины, альбом, достижения, настройки, выход.

var overlay: Control = null
var panel_content: VBoxContainer = null
var shop_tab := "characters"
var album_tab := "enemies"
var souls_lbl: Label
var gold_lbl: Label
var overlay_kind := ""
var reset_armed := false
var lobby_map := "forest"
var status := ""
var _net_status_label: Label = null
var _net_rebuilding := false

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
	AudioManager.play_menu_music()
	Net.session_start_requested.connect(_on_session_start)
	Net.lobby_changed.connect(_on_net_lobby_changed)
	Net.notice.connect(_on_net_notice)
	Net.connection_failed.connect(_on_net_failed)
	if Net.enabled:
		status = "Соединение активно" if Net.is_client() else "Сервер открыт"
	else:
		Net.start_lan_listen()

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

	# --- левая часть: только логотип, поднятый выше
	var logo := UI.title(self, "SURWAVE", 40, Vector2(36, 18), UI.GOLD)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	UI.divider(self, Vector2(38, 66), 220.0, UI.GOLD_DEEP)
	UI.label(self, "версия 1.5.0 · сетевой кооп", 8, UI.MUTED, Vector2(20, 318))

	# --- правая часть: меню на полупрозрачной готической раме поверх живого геймплея
	var menu_frame := Panel.new()
	menu_frame.position = Vector2(342, 18)
	menu_frame.size = Vector2(276, 324)
	menu_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_frame.add_theme_stylebox_override("panel", UI.style(Color(0.045, 0.048, 0.062, 0.78), UI.GOLD_DEEP, 1, 0))
	add_child(menu_frame)

	var menu := Control.new()
	menu.position = Vector2(354, 28)
	menu.size = Vector2(252, 304)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var play := UI.primary_button(menu, Loc.t("play"), 15, Vector2(252, 38))
	play.position = Vector2(0, 0)
	play.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui")
		GameManager.goto_select())
	var net_btn := UI.primary_button(menu, "СЕТЕВАЯ ИГРА", 13, Vector2(252, 30))
	net_btn.position = Vector2(0, 42)
	net_btn.pressed.connect(func() -> void: _open_overlay("network"))
	var y := 78
	for item in [
		[Loc.t("album"), "album"],
		["ДРЕВО ПРОГРЕССИИ", "progression"],
		["ЗАДАНИЯ И СЕЗОН", "quests"],
		["РЕКОРДЫ И ГАЛЕРЕЯ", "records"],
		[Loc.t("achievements"), "achievements"],
		[Loc.t("settings"), "settings"],
	]:
		var btn := UI.button(menu, String(item[0]), 10, Vector2(252, 27))
		btn.position = Vector2(0, y)
		var key := String(item[1])
		btn.pressed.connect(func() -> void: _open_overlay(key))
		y += 30
	var quit := UI.button(menu, Loc.t("quit"), 10, Vector2(252, 27))
	quit.position = Vector2(0, y + 4)
	quit.pressed.connect(func() -> void: get_tree().quit())

	_refresh_info()

func _refresh_info() -> void:
	if souls_lbl == null:
		return
	souls_lbl.text = "%s: %d" % [Loc.t("souls").capitalize(), int(GameManager.meta.get("souls", 0))]
	gold_lbl.text = "%s: %d   ·   %s: %d" % [Loc.t("gold").capitalize(), int(GameManager.meta.get("gold", 0)), Loc.t("stats_runs"), int(GameManager.meta.get("stats", {}).get("runs", 0))]

# ------------------------------------------------------------------ ОВЕРЛЕЙ
func _open_overlay(kind: String, silent: bool = false) -> void:
	if not silent:
		AudioManager.play_sfx("ui")
	overlay_kind = kind
	_net_status_label = null
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
	var titles := {"shops": Loc.t("shops"), "album": Loc.t("album"), "progression":"ДРЕВО ПРОГРЕССИИ", "quests":"ЗАДАНИЯ И СЕЗОН", "records":"ЛОКАЛЬНЫЕ РЕКОРДЫ И ГАЛЕРЕЯ", "achievements": Loc.t("achievements"), "settings": Loc.t("settings"), "network":"СЕТЕВАЯ ИГРА"}
	UI.label(panel, String(titles.get(kind, "")), 14, UI.GOLD, Vector2(10, 6))
	var back := UI.button(panel, Loc.t("back"), 9, Vector2(70, 20))
	back.position = Vector2(508, 6)
	back.pressed.connect(func() -> void:
		overlay.queue_free()
		overlay = null
		overlay_kind = ""
		status = ""
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
		"network": _build_network(body)

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
	var names := {"power":"СИЛА · +3% урона, +4% XP/ур.","fortitude":"СТОЙКОСТЬ · HP/защита/лечение","speed":"СКОРОСТЬ · движение/темп","luck":"УДАЧА · золото/редкость/события","mastery":"МАСТЕРСТВО · персонажи/карты/режимы"}
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

# ------------------------------------------------------------------ НАСТРОЙКИ
func _settings_cell(parent: Control) -> HBoxContainer:
	var cell := UI.hbox(parent, 6)
	cell.custom_minimum_size = Vector2(272, 22)
	return cell

func _settings_section(v: Control, title: String) -> void:
	var l := UI.label(v, title, 9, UI.GOLD)
	l.custom_minimum_size = Vector2(556, 13)
	var line := ColorRect.new()
	line.color = Color(UI.GOLD_DEEP.r, UI.GOLD_DEEP.g, UI.GOLD_DEEP.b, 0.5)
	line.custom_minimum_size = Vector2(556, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)

func _settings_toggle(parent: Control, key: String, text: String, def_value: bool = true) -> void:
	var cell := _settings_cell(parent)
	var l := UI.label(cell, text, 8, UI.TEXT)
	l.custom_minimum_size = Vector2(160, 18)
	l.clip_text = true
	var value := bool(GameManager.setting(key, def_value))
	var b := UI.button(cell, "ВКЛ" if value else "ВЫКЛ", 8, Vector2(74, 20))
	b.custom_minimum_size = Vector2(74, 20)
	b.add_theme_color_override("font_color", UI.GREEN if value else UI.DIM)
	b.pressed.connect(func() -> void:
		GameManager.set_setting(key, not bool(GameManager.setting(key, def_value)))
		AudioManager.play_sfx("ui")
		_open_overlay("settings"))

func _settings_cycle(parent: Control, key: String, text: String, values: Array, names: Array, def_value: String = "") -> void:
	var cell := _settings_cell(parent)
	var l := UI.label(cell, text, 8, UI.TEXT)
	l.custom_minimum_size = Vector2(104, 18)
	l.clip_text = true
	var raw_cur: Variant = GameManager.setting(key, def_value)
	var current := raw_cur if raw_cur is String else str(raw_cur)
	var idx := values.find(current)
	if idx < 0:
		idx = 0
	var b := UI.button(cell, String(names[idx]), 8, Vector2(140, 20))
	b.custom_minimum_size = Vector2(140, 20)
	b.pressed.connect(func() -> void:
		var raw_now: Variant = GameManager.setting(key, def_value)
		var cur := raw_now if raw_now is String else str(raw_now)
		var i := values.find(cur)
		if i < 0:
			i = 0
		GameManager.set_setting(key, String(values[(i + 1) % values.size()]))
		AudioManager.play_sfx("ui")
		_open_overlay("settings"))

func _settings_slider(parent: Control, key: String, text: String) -> void:
	var cell := _settings_cell(parent)
	var l := UI.label(cell, text, 8, UI.TEXT)
	l.custom_minimum_size = Vector2(88, 18)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	var raw: Variant = GameManager.setting(key, 0.8)
	s.value = float(raw) if (raw is int or raw is float) else 0.8
	s.custom_minimum_size = Vector2(168, 16)
	s.value_changed.connect(func(val: float) -> void: GameManager.set_setting(key, val))
	cell.add_child(s)

func _settings_text(parent: Control, key: String, text: String, def_value: String, numeric: bool = false, max_len: int = 16) -> void:
	var cell := _settings_cell(parent)
	var l := UI.label(cell, text, 8, UI.TEXT)
	l.custom_minimum_size = Vector2(96, 18)
	l.clip_text = true
	var edit := LineEdit.new()
	var raw_text: Variant = GameManager.setting(key, def_value)
	edit.text = raw_text if raw_text is String else str(raw_text)
	edit.max_length = max_len
	edit.custom_minimum_size = Vector2(160, 20)
	edit.add_theme_font_override("font", UI.crisp_font())
	edit.add_theme_font_size_override("font_size", 9)
	edit.add_theme_color_override("font_color", UI.TEXT)
	edit.add_theme_color_override("font_placeholder_color", UI.MUTED)
	edit.add_theme_stylebox_override("normal", UI.style(Color(0.07, 0.065, 0.055, 0.95), UI.BORDER, 1, 0))
	edit.add_theme_stylebox_override("focus", UI.style(Color(0.10, 0.09, 0.07, 1.0), UI.GOLD_DEEP, 1, 0))
	if numeric:
		edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	edit.text_submitted.connect(func(value: String) -> void: _apply_text_setting(key, value, numeric))
	edit.focus_exited.connect(func() -> void: _apply_text_setting(key, edit.text, numeric))
	cell.add_child(edit)

func _apply_text_setting(key: String, value: String, numeric: bool) -> void:
	var clean := value.strip_edges()
	if numeric:
		if not clean.is_valid_int():
			return
		GameManager.set_setting(key, clampi(int(clean), 1024, 65535))
	else:
		GameManager.set_setting(key, clean)
		if key == "net_name":
			Net.set_my_name(clean)

func _build_settings(body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(572, 252)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(556, 0)
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)

	_settings_section(v, "ЗВУК")
	var srow := UI.hbox(v, 8)
	_settings_slider(srow, "music", Loc.t("music"))
	_settings_slider(srow, "sfx", Loc.t("sfx"))

	_settings_section(v, "ЭКРАН И ОКНО")
	var r1 := UI.hbox(v, 8)
	_settings_cycle(r1, "window_mode", "Режим окна", ["windowed", "borderless", "fullscreen"],
		["ОКОННЫЙ", "ОКНО НА ВЕСЬ ЭКРАН", "ПОЛНОЭКРАННЫЙ"], "windowed")
	_settings_toggle(r1, "vsync", "Вертикальная синхронизация", true)
	var r2 := UI.hbox(v, 8)
	_settings_cycle(r2, "camera_distance", "Дальность камеры", ["normal", "close", "far"],
		["СТАНДАРТ", "БЛИЗКО", "ДАЛЕКО"], "normal")
	_settings_cycle(r2, "camera_shake", "Тряска камеры", ["normal", "off", "strong"],
		["УМЕРЕННАЯ", "ВЫКЛ", "СИЛЬНАЯ"], "normal")
	var r3 := UI.hbox(v, 8)
	_settings_toggle(r3, "post_fx", "Экранные эффекты", true)
	_settings_toggle(r3, "vignette", "Виньетка и глубина", true)
	var r4 := UI.hbox(v, 8)
	_settings_toggle(r4, "screen_flash", "Вспышки экрана", true)
	_settings_toggle(r4, "hit_stop", "Хит-стоп на ударах", true)

	_settings_section(v, "ИНТЕРФЕЙС")
	var r5 := UI.hbox(v, 8)
	_settings_cycle(r5, "lang", "Язык", ["ru", "en"], ["RU", "EN"], "ru")
	_settings_toggle(r5, "damage_numbers", "Цифры урона", true)
	var r6 := UI.hbox(v, 8)
	_settings_toggle(r6, "crosshair", "Свой прицел в бою", true)
	_settings_cycle(r6, "hud_vitals", "Патроны и HP", ["corner", "player"],
		["СЛЕВА СВЕРХУ", "НАД ИГРОКОМ"], "corner")
	var r7 := UI.hbox(v, 8)
	_settings_toggle(r7, "boss_fx", "Постановка боссов", true)
	_settings_toggle(r7, "qte", "QTE-добивания", true)
	var r8 := UI.hbox(v, 8)
	_settings_toggle(r8, "slowmo", "Замедления", true)
	_settings_toggle(r8, "combo_fx", "Эффекты комбо", true)

	_settings_section(v, "ИГРОВОЙ ПРОЦЕСС")
	var r9 := UI.hbox(v, 8)
	_settings_toggle(r9, "god_mode", "Бессмертие (тест)", false)
	var hint := UI.label(r9, "God mode влияет на получаемый урон.", 8, UI.DIM)
	hint.custom_minimum_size = Vector2(272, 18)
	hint.clip_text = true

	_settings_section(v, "СЕТЬ")
	var r10 := UI.hbox(v, 8)
	_settings_text(r10, "net_name", "Имя в сети", Net.my_name, false, 16)
	_settings_text(r10, "net_port", "Порт", "7777", true, 5)

	_settings_section(v, "СБРОС")
	var r11 := UI.hbox(v, 8)
	var reset := UI.button(r11, "ТОЧНО СБРОСИТЬ?" if reset_armed else Loc.t("reset_save"), 9, Vector2(206, 22))
	reset.custom_minimum_size = Vector2(206, 22)
	reset.add_theme_color_override("font_color", UI.DANGER if reset_armed else UI.DIM)
	reset.pressed.connect(func() -> void:
		if reset_armed:
			reset_armed = false
			SaveManager.reset()
			GameManager.meta = SaveManager.data
			GameManager.god_mode = false
			GameManager.apply_display_settings()
			Loc.set_lang("ru")
		else:
			reset_armed = true
			AudioManager.play_sfx("error")
		_open_overlay("settings"))
	var r11_hint := UI.label(r11, "F11 — переключение режима окна.", 8, UI.DIM)
	r11_hint.custom_minimum_size = Vector2(320, 18)
	var foot := UI.label(v, "Настройки сохраняются сразу. F11 циклично меняет оконный / «окно на весь экран» / полный экран.", 8, UI.MUTED)
	foot.custom_minimum_size = Vector2(556, 14)

# ------------------------------------------------------------------ СЕТЕВАЯ ИГРА
func _net_edit(parent: Control, value: String, pos: Vector2, size: Vector2, placeholder: String, max_len: int = 24) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.max_length = max_len
	edit.position = pos
	edit.size = size
	edit.add_theme_font_override("font", UI.crisp_font())
	edit.add_theme_font_size_override("font_size", 9)
	edit.add_theme_color_override("font_color", UI.TEXT)
	edit.add_theme_color_override("font_placeholder_color", UI.MUTED)
	edit.add_theme_stylebox_override("normal", UI.style(Color(0.07, 0.065, 0.055, 0.95), UI.BORDER, 1, 0))
	edit.add_theme_stylebox_override("focus", UI.style(Color(0.10, 0.09, 0.07, 1.0), UI.GOLD_DEEP, 1, 0))
	parent.add_child(edit)
	return edit

func _net_status(text: String, color: Color = UI.DIM) -> void:
	if not is_instance_valid(_net_status_label):
		return
	_net_status_label.text = text
	_net_status_label.add_theme_color_override("font_color", color)

func _build_network(body: Control) -> void:
	# ---------------------------------------------------------- левая колонна: подключение
	UI.label(body, "ИМЯ В СЕТИ", 9, UI.GOLD, Vector2(0, 0))
	var name_edit := _net_edit(body, Net.my_name, Vector2(0, 14), Vector2(254, 20), "Странник", 16)
	name_edit.text_submitted.connect(func(value: String) -> void:
		var clean := value.strip_edges()
		if clean != "":
			Net.set_my_name(clean))
	name_edit.focus_exited.connect(func() -> void:
		var clean := name_edit.text.strip_edges()
		if clean != "":
			Net.set_my_name(clean))
	var host_btn := UI.button(body, "СОЗДАТЬ СЕРВЕР", 9, Vector2(254, 24))
	host_btn.position = Vector2(0, 40)
	host_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui")
		var err := Net.host_game()
		if err != "":
			status = err
		else:
			status = "Сервер открыт. Друзья подключаются по вашему IP."
		_open_overlay("network", true))
	UI.label(body, "IP ХОСТА (локальная сеть или интернет)", 9, UI.GOLD, Vector2(0, 70))
	var ip_edit := _net_edit(body, str(GameManager.setting("net_last_ip", "")), Vector2(0, 84), Vector2(254, 20), "192.168.1.10", 40)
	var port_edit := _net_edit(body, str(int(GameManager.setting("net_port", 7777))), Vector2(188, 110), Vector2(66, 20), "7777", 5)
	var join_btn := UI.button(body, "ПОДКЛЮЧИТЬСЯ", 9, Vector2(180, 24))
	join_btn.position = Vector2(0, 108)
	join_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui")
		var port := int(port_edit.text) if port_edit.text.is_valid_int() else int(GameManager.setting("net_port", 7777))
		GameManager.set_setting("net_port", port)
		var err := Net.join_game(ip_edit.text, port)
		status = err if err != "" else "Подключаемся…"
		_open_overlay("network", true))
	var lan_btn := UI.button(body, "ОБНОВИТЬ СПИСОК ЛОКАЛЬНОЙ СЕТИ", 8, Vector2(254, 22))
	lan_btn.position = Vector2(0, 136)
	lan_btn.pressed.connect(func() -> void:
		Net.start_lan_listen()
		status = "Ищем хосты в локальной сети…"
		_open_overlay("network", true))
	var char_btn := UI.button(body, "ГЕРОЙ: %s" % _char_name(Net.local_character), 8, Vector2(254, 22))
	char_btn.position = Vector2(0, 164)
	char_btn.pressed.connect(func() -> void:
		var ids := _available_chars()
		var idx := maxi(0, ids.find(Net.local_character))
		Net.set_loadout(String(ids[(idx + 1) % ids.size()]), Net.local_weapon)
		_open_overlay("network"))
	var weap_btn := UI.button(body, "ОРУЖИЕ: %s" % _weapon_name(Net.local_weapon), 8, Vector2(254, 22))
	weap_btn.position = Vector2(0, 190)
	weap_btn.pressed.connect(func() -> void:
		var ids := _available_weapons()
		var idx := maxi(0, ids.find(Net.local_weapon))
		Net.set_loadout(Net.local_character, String(ids[(idx + 1) % ids.size()]))
		_open_overlay("network"))
	UI.label(body, "МОЙ АДРЕС ДЛЯ ДРУЗЕЙ", 8, UI.GOLD, Vector2(0, 212))
	var addr_lbl := UI.label(body, Net.address_text(), 9, UI.PURPLE, Vector2(0, 224))
	addr_lbl.size = Vector2(254, 16)
	addr_lbl.clip_text = true
	var copy_btn := UI.button(body, "КОПИРОВАТЬ IP И ПОРТ", 8, Vector2(254, 20))
	copy_btn.position = Vector2(0, 242)
	copy_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Net.address_text())
		AudioManager.play_sfx("ui")
		status = "Скопировано: %s" % Net.address_text()
		_open_overlay("network", true))
	if Net.enabled:
		var disc := UI.button(body, "ОТКЛЮЧИТЬСЯ", 8, Vector2(254, 20))
		disc.position = Vector2(0, 264)
		disc.add_theme_color_override("font_color", UI.DANGER)
		disc.pressed.connect(func() -> void:
			Net.leave_session("Вы отключились")
			status = "Соединение закрыто"
			_open_overlay("network", true))

	# ---------------------------------------------------------- правая колонна: лобби и LAN
	var right := 270
	UI.label(body, "ИГРОКИ В ЛОББИ: %d/%d" % [maxi(1, Net.peer_count()) if Net.enabled else 1, Net.max_players()], 9, UI.GOLD, Vector2(right, 0))
	var lobby := VBoxContainer.new()
	lobby.position = Vector2(right, 15)
	lobby.size = Vector2(286, 70)
	lobby.add_theme_constant_override("separation", 2)
	body.add_child(lobby)
	if Net.lobby_players.is_empty():
		var empty_lbl := UI.label(lobby, "Никто не подключён. Создайте сервер или найдите хост в LAN.", 8, UI.DIM)
		empty_lbl.custom_minimum_size = Vector2(286, 16)
	for key in Net.lobby_players.keys():
		var entry: Dictionary = Net.lobby_players[key]
		var is_me := String(key) == str(Net.my_id())
		var role := "ХОСТ" if String(key) == "1" else "ИГРОК"
		var text := "%s · %s · %s" % [String(entry.get("name", "Игрок")), _char_name(String(entry.get("character", "aldar"))), role]
		var row := UI.label(lobby, ("▸ " if is_me else "  ") + text, 8, UI.GOLD_BRIGHT if is_me else UI.TEXT)
		row.custom_minimum_size = Vector2(286, 15)
		row.clip_text = true
	UI.label(body, "ХОСТЫ В ЛОКАЛЬНОЙ СЕТИ", 9, UI.GOLD, Vector2(right, 90))
	var lan_box := VBoxContainer.new()
	lan_box.position = Vector2(right, 105)
	lan_box.size = Vector2(286, 100)
	lan_box.add_theme_constant_override("separation", 2)
	body.add_child(lan_box)
	var hosts := Net.lan_list()
	if hosts.is_empty():
		var no_lan := UI.label(lan_box, "Хосты не найдены. Обновите список или введите IP вручную.", 8, UI.DIM)
		no_lan.custom_minimum_size = Vector2(286, 16)
	for h in hosts:
		var host_entry: Dictionary = h
		var label := "%s · %s:%d · %d/%d" % [String(host_entry.get("name", "Хост")), String(host_entry.get("ip", "")), int(host_entry.get("port", 7777)), int(host_entry.get("players", 1)), int(host_entry.get("max", Net.max_players()))]
		var btn := UI.button(lan_box, label, 8, Vector2(286, 20))
		btn.pressed.connect(func() -> void:
			var err := Net.join_game(String(host_entry.get("ip", "")), int(host_entry.get("port", 7777)))
			status = err if err != "" else "Подключаемся…"
			_open_overlay("network"))
	if Net.is_host():
		var map_btn := UI.button(body, "КАРТА: %s" % _map_name(lobby_map), 9, Vector2(286, 22))
		map_btn.position = Vector2(right, 210)
		map_btn.pressed.connect(func() -> void:
			var ids := _available_maps()
			var idx := maxi(0, ids.find(lobby_map))
			lobby_map = String(ids[(idx + 1) % ids.size()])
			_open_overlay("network"))
		var start := UI.primary_button(body, "НАЧАТЬ ЗАБЕГ", 11, Vector2(286, 28))
		start.position = Vector2(right, 238)
		start.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui")
			Net.start_session({
				"map": lobby_map,
				"mode": "standard",
				"darkness": 1,
				"seed": randi() % 999983 + 1,
				"loadouts": Net.loadout_table(),
			}))
	else:
		var wait_txt := "Ждём старта от хоста…" if Net.is_client() else "Подключитесь, чтобы играть вместе."
		UI.label(body, wait_txt, 9, UI.DIM, Vector2(right, 214))
	_net_status_label = UI.label(body, status, 8, UI.GREEN if Net.enabled else UI.DIM, Vector2(right, 264))
	_net_status_label.size = Vector2(286, 18)
	_net_status_label.clip_text = true

func _char_name(id: String) -> String:
	var ch := DB.character(id)
	return String(ch.get("name", id))

func _weapon_name(id: String) -> String:
	var w := DB.weapon(id)
	return String(w.get("name", id))

func _map_name(id: String) -> String:
	var m := DB.map(id)
	return String(m.get("name", id))

func _available_chars() -> Array:
	var out: Array = []
	for ch in DB.characters:
		var cid := String(ch.get("id", ""))
		if cid != "" and GameManager.is_char_unlocked(cid):
			out.append(cid)
	if out.is_empty():
		out.append("aldar")
	return out

func _available_weapons() -> Array:
	var out: Array = []
	for w in DB.weapons:
		var wid := String(w.get("id", ""))
		if wid != "" and GameManager.is_weapon_unlocked(wid):
			out.append(wid)
	if out.is_empty():
		out.append("revolver")
	return out

func _available_maps() -> Array:
	var out: Array = []
	for m in DB.maps:
		var mid := String(m.get("id", ""))
		if mid != "" and not bool(m.get("secret", false)) and GameManager.is_map_unlocked(mid):
			out.append(mid)
	if out.is_empty():
		out.append("forest")
	return out

## Хост нажал «начать» или клиент получил старт: каждый грузит забег со своим героем.
func _on_session_start(config: Dictionary) -> void:
	AudioManager.play_sfx("ui")
	var cfg := config.duplicate(true)
	var loadouts: Dictionary = cfg.get("loadouts", {})
	var mine: Array = loadouts.get(str(Net.my_id()), [])
	var ch: String = String(mine[0]) if mine.size() > 0 else Net.local_character
	var wp: String = String(mine[1]) if mine.size() > 1 else Net.local_weapon
	GameManager.start_run({
		"character": ch,
		"weapon": wp,
		"map": String(cfg.get("map", "forest")),
		"mode": String(cfg.get("mode", "standard")),
		"darkness": int(cfg.get("darkness", 1)),
		"seed": int(cfg.get("seed", 0)),
		"network": true,
		"is_host": Net.is_host(),
		"players": maxi(1, Net.peer_count()),
		"loadouts": loadouts,
	})

func _on_net_lobby_changed() -> void:
	if overlay_kind != "network" or overlay == null or _net_rebuilding:
		return
	_net_rebuilding = true
	_open_overlay("network", true)
	_net_rebuilding = false

func _on_net_notice(text: String) -> void:
	status = text
	_on_net_lobby_changed()

func _on_net_failed(reason: String) -> void:
	status = reason
	_on_net_lobby_changed()

func _process(_delta: float) -> void:
	_refresh_info()

func _input(event: InputEvent) -> void:
	if overlay != null and event.is_action_pressed("pause"):
		overlay.queue_free()
		overlay = null
		overlay_kind = ""
		status = ""
		_refresh_info()
		get_viewport().set_input_as_handled()
