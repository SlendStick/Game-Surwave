extends Control
## Экран выбора перед раундом: персонаж, оружие, карта, режим/Тьма/амулеты.

## Понятные названия событий карт (kind → текст).
const EVENT_NAMES := {
	"meteor": "Метеоритный дождь",
	"sandstorm": "Песчаная буря",
	"blizzard": "Метель",
	"tumbleweed": "Перекати-поле",
	"wisps": "Блуждающие огни",
	"insect_swarm": "Рои насекомых",
	"quicksand": "Зыбучие пески",
	"pull_zone": "Трясина и водовороты",
	"ice_spikes": "Ледяные шипы",
	"avalanche": "Лавина",
	"rockfall": "Камнепад",
	"eruption": "Извержение вулкана",
	"cave_in": "Обрушения",
	"crystal_flash": "Вспышки кристаллов",
	"poison_geyser": "Ядовитые гейзеры",
	"madness": "Безумные вспышки",
	"ghost_hands": "Призрачные руки",
	"necro_fog": "Некромантский туман",
	"curse": "Проклятия",
	"weather": "Погода карты",
	"aoe_zone": "Зоны обстрела",
	"rain": "Падающие снаряды",
	"band": "Гроза над ареной",
	"vision": "Ухудшение видимости",
	"spawn": "Волны призыва",
	"heal": "Источники лечения",
	"slow_zones": "Замедляющая земля",
	"lightning": "Удары молний",
	"pull": "Порывы ветра",
	"buff": "Благословение",
	"cursed_ground": "Проклятая земля",
	"obstacle_toggle": "Движущиеся препятствия",
	"reflect_buff": "Отражение снарядов",
}

var tab := 0
var sel := {
	"character": "aldar",
	"weapon": "revolver",
	"map": "sands",
	"mode": "standard",
	"darkness": 1,
	"trials": [],
	"blessing": "",
}
var preview := {
	"character": "aldar",
	"weapon": "revolver",
	"map": "sands",
}
var content: Control
var summary: Label
var tab_buttons: Array = []

func _ready() -> void:
	tab = int(OS.get_environment("SURW_TAB")) if OS.get_environment("SURW_TAB") != "" else 0
	_build()
	AudioManager.play_menu_music()

func _build() -> void:
	UI.full_rect(self)
	UI.backdrop(self, Color("#0b0c10"))

	# --- шапка с заголовком и кнопкой назад
	UI.label(self, "ПОДГОТОВКА К ЗАБЕГУ", 15, UI.GOLD, Vector2(14, 10))
	UI.label(self, "выбери героя, оружие и карту", 8, UI.MUTED, Vector2(15, 28))
	UI.divider(self, Vector2(15, 40), 610.0, UI.GOLD_DEEP)
	var back := UI.button(self, "‹ " + Loc.t("back"), 9, Vector2(72, 22))
	back.position = Vector2(556, 12)
	back.pressed.connect(func() -> void: GameManager.goto_menu())

	# --- вкладки-«таблетки» (Персонаж, Оружие, Карта, Амулеты, Режим)
	var tabs: Array = [Loc.t("character"), Loc.t("weapon"), Loc.t("map"), Loc.t("amulets"), Loc.t("mode")]
	var x := 14
	for i in tabs.size():
		var b := UI.button(self, String(tabs[i]).to_upper(), 9, Vector2(118, 22))
		b.position = Vector2(x, 48)
		var idx := i
		b.pressed.connect(func() -> void:
			tab = idx
			_rebuild())
		tab_buttons.append(b)
		x += 123

	content = Control.new()
	content.position = Vector2(14, 76)
	content.size = Vector2(612, 226)
	add_child(content)

	# --- нижняя панель: сводка и кнопка старта
	var footer := UI.panel(self, Rect2(14, 306, 612, 46), UI.PANEL, UI.BORDER_HI)
	var accent := ColorRect.new()
	accent.color = Color(0.42, 0.43, 0.47, 0.7)
	accent.position = Vector2(1, 1)
	accent.size = Vector2(610, 1)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(accent)
	summary = UI.label(footer, "", 8, UI.TEXT, Vector2(10, 6))
	summary.size = Vector2(420, 34)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var start := UI.primary_button(footer, Loc.t("start"), 13, Vector2(170, 32))
	start.position = Vector2(430, 6)
	start.pressed.connect(_start_run)
	_rebuild()

func _rebuild() -> void:
	for i in tab_buttons.size():
		var b: Button = tab_buttons[i]
		if i == tab:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 1))
			b.add_theme_color_override("font_color", UI.GOLD)
		else:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL, UI.BORDER, 1))
			b.add_theme_color_override("font_color", UI.TEXT)
	UI.clear(content)
	match tab:
		0: _build_characters()
		1: _build_weapons()
		2: _build_maps()
		3: _build_amulets()
		4: _build_modes()
	_refresh_summary()

func _refresh_summary() -> void:
	var ch := DB.character(String(sel["character"]))
	var w := DB.weapon(String(sel["weapon"]))
	var m := DB.map(String(sel["map"]))
	var mode_name := {"standard": Loc.t("mode_standard"), "quick": Loc.t("mode_quick"), "endless": Loc.t("mode_endless"), "coop":"Локальный кооператив"}
	summary.text = "%s: %s · %s: %s · %s: %s\n%s: %s · %s %d · %s: %d %s" % [
		Loc.t("character"), String(ch.get("name", "")), Loc.t("weapon"), String(w.get("name", "")),
		Loc.t("map"), String(m.get("name", "")), Loc.t("mode"), String(mode_name.get(String(sel["mode"]), "")),
		Loc.t("darkness"), int(sel["darkness"]), Loc.t("souls"), int(GameManager.meta.get("souls", 0)), Loc.t("souls")]

# ------------------------------------------------------------------ ПЕРСОНАЖИ
func _build_characters() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(158, 224)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(150, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var cur_id := String(preview.get("character", sel["character"]))
	for ch in DB.characters:
		var id := String(ch["id"])
		var unlocked := GameManager.is_char_unlocked(id)
		var price := int(ch.get("price", 0))
		var label_txt := String(ch["name"])
		if not unlocked:
			label_txt = "%s (%d)" % [label_txt, price] if price > 0 and String(ch.get("unlock", "")) == "" else "%s (секрет)" % label_txt
		var b := UI.button(list, label_txt, 9, Vector2(148, 20))
		if id == String(sel["character"]):
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 2))
			b.add_theme_color_override("font_color", UI.GOLD)
		elif id == cur_id:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.BORDER_HI, 1))
			b.add_theme_color_override("font_color", UI.TEXT if unlocked else UI.PURPLE)
		elif not unlocked:
			b.add_theme_color_override("font_color", UI.DIM)
		b.pressed.connect(func() -> void:
			preview["character"] = id
			if unlocked:
				sel["character"] = id
			_rebuild())

	# --- средняя колонка: описание и кнопка покупки при необходимости
	var details := UI.panel(content, Rect2(164, 0, 244, 224))
	var ch2 := DB.character(cur_id)
	var cur_unlocked := GameManager.is_char_unlocked(cur_id)
	var dscroll := ScrollContainer.new()
	dscroll.position = Vector2(8, 6)
	dscroll.size = Vector2(228, 178 if not cur_unlocked else 212)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(dscroll)
	var dbox := VBoxContainer.new()
	dbox.custom_minimum_size = Vector2(220, 0)
	dbox.add_theme_constant_override("separation", 4)
	dscroll.add_child(dbox)
	var htitle := UI.label(dbox, "%s — %s · HP: %d" % [String(ch2.get("name", "")), String(ch2.get("role", "")), int(ch2.get("hp", 0))], 10, UI.GOLD, Vector2.ZERO)
	htitle.custom_minimum_size = Vector2(216, 0)
	htitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var text := "Пассивка: %s\n%s\n\nСкилл: %s (КД %.0f сек)\n%s" % [
		String(ch2.get("passive", {}).get("name", "")), String(ch2.get("passive", {}).get("desc", "")),
		String(ch2.get("skill", {}).get("name", "")), float(ch2.get("skill", {}).get("cd", 10.0)),
		String(ch2.get("skill", {}).get("desc", ""))]
	var l := UI.label(dbox, text, 8, UI.TEXT, Vector2.ZERO)
	l.custom_minimum_size = Vector2(216, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ups: Array = ch2.get("upgrades", [])
	var utxt := "Уникальные апгрейды (из сундуков):"
	for up in ups:
		utxt += "\n› %s — %s" % [String(up.get("name", "")), String(up.get("desc", ""))]
	var l2 := UI.label(dbox, utxt, 8, UI.DIM, Vector2.ZERO)
	l2.custom_minimum_size = Vector2(216, 0)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not cur_unlocked:
		var cprice := int(ch2.get("price", 0))
		if String(ch2.get("unlock", "")) != "" or cprice <= 0:
			UI.label(details, "Открывается особым испытанием (Мастерство + победа).", 8, UI.PURPLE, Vector2(8, 194))
		else:
			var buy_btn := UI.primary_button(details, "КУПИТЬ ЗА %d ДУШ" % cprice, 9, Vector2(228, 24))
			buy_btn.position = Vector2(8, 192)
			buy_btn.disabled = int(GameManager.meta.get("souls", 0)) < cprice
			buy_btn.pressed.connect(func() -> void:
				if GameManager.buy_character(cur_id):
					AudioManager.play_sfx("gold")
					sel["character"] = cur_id
					_rebuild()
				else:
					AudioManager.play_sfx("error"))

	# --- правая колонка: большой HD pixel-art портрет персонажа
	var p_frame := UI.panel(content, Rect2(414, 0, 198, 224), UI.PANEL_HI, UI.GOLD_DEEP)
	var p_top := ColorRect.new()
	p_top.color = Color(0.75, 0.62, 0.35, 0.7)
	p_top.position = Vector2(1, 1)
	p_top.size = Vector2(196, 1)
	p_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_frame.add_child(p_top)
	var cls_id := String(ch2.get("cls", "mage"))
	var ptex := Assets.icon("portrait_" + cls_id)
	if ptex == null:
		ptex = Assets.icon(cls_id)
	if ptex != null:
		var portrait := TextureRect.new()
		portrait.texture = ptex
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(11, 8)
		portrait.size = Vector2(176, 176)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_frame.add_child(portrait)
	var pname := UI.label(p_frame, String(ch2.get("name", "")).to_upper(), 10, UI.GOLD, Vector2(6, 188))
	pname.size = Vector2(186, 14)
	pname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var prole := UI.label(p_frame, String(ch2.get("role", "")), 8, UI.DIM, Vector2(6, 203))
	prole.size = Vector2(186, 12)
	prole.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ------------------------------------------------------------------ ОРУЖИЕ
func _build_weapons() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(196, 224)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(190, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var cur_id := String(preview.get("weapon", sel["weapon"]))
	for w in DB.weapons:
		var id := String(w["id"])
		var unlocked := GameManager.is_weapon_unlocked(id)
		var price := int(w.get("price", 0))
		var b_txt := String(w["name"])
		if not unlocked:
			b_txt = "%s (%d)" % [b_txt, price] if String(w.get("unlock", "")) == "" and price > 0 else "%s (условие)" % b_txt
		var b := UI.button(list, b_txt, 9, Vector2(186, 20))
		if id == String(sel["weapon"]):
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 2))
			b.add_theme_color_override("font_color", UI.GOLD)
		elif id == cur_id:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.BORDER_HI, 1))
			b.add_theme_color_override("font_color", UI.TEXT if unlocked else UI.PURPLE)
		elif not unlocked:
			b.add_theme_color_override("font_color", UI.DIM)
		b.pressed.connect(func() -> void:
			preview["weapon"] = id
			if unlocked:
				sel["weapon"] = id
			_rebuild())
	var details := UI.panel(content, Rect2(202, 0, 410, 224))
	var w2 := DB.weapon(cur_id)
	var w_unlocked := GameManager.is_weapon_unlocked(cur_id)
	var wid2 := String(w2.get("id", ""))
	var wtex := Assets.icon("icon_weapon_" + wid2)
	if wtex != null:
		var wico := TextureRect.new()
		wico.texture = wtex
		wico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wico.position = Vector2(8, 6)
		wico.size = Vector2(36, 36)
		wico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(wico)
	var text := "%s\nУрон: %.0f · Скорострельность: %.1f/сек · Магазин: %d · Перезарядка: %.1f сек\nСнарядов: %d · Пробитие: %d · Скорость снаряда: %.0f\n\n%s" % [
		String(w2.get("name", "")), float(w2.get("damage", 0)), float(w2.get("fire_rate", 0)),
		int(w2.get("mag", 0)), float(w2.get("reload", 0)), int(w2.get("projectiles", 1)),
		int(w2.get("pierce", 0)), float(w2.get("proj_speed", 0)), String(w2.get("desc", ""))]
	var l := UI.label(details, text, 9, UI.TEXT, Vector2(50 if wtex != null else 8, 6))
	l.size = Vector2(352 if wtex != null else 394, 88)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var evo_txt := "Уровни 1–8: рост урона, темпа, снарядов и пробития."
	var single_evo: Dictionary = w2.get("evolution", {})
	if not single_evo.is_empty():
		evo_txt += "\n\nЭволюция на 8-м уровне оружия:\n%s" % String(single_evo.get("name", ""))
		evo_txt += "\n%s" % String(single_evo.get("desc", ""))
		var item := String(single_evo.get("item_name", ""))
		if item != "":
			evo_txt += "\nПредмет: %s (сундуки, элиты, мини-боссы)." % item
	else:
		for evo in w2.get("evolutions", []):
			evo_txt += "\n› %s — %s" % [String(evo.get("name", "")), String(evo.get("desc", ""))]
	var l2 := UI.label(details, evo_txt, 8, UI.DIM, Vector2(8, 96))
	l2.custom_minimum_size = Vector2(394, 92 if not w_unlocked else 120)
	l2.size = Vector2(394, 92 if not w_unlocked else 120)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.clip_text = true
	if not w_unlocked:
		var wprice := int(w2.get("price", 0))
		if String(w2.get("unlock", "")) != "" or wprice <= 0:
			UI.label(details, "Открывается особым достижением.", 8, UI.PURPLE, Vector2(8, 194))
		else:
			var buy_w := UI.primary_button(details, "КУПИТЬ ЗА %d ДУШ" % wprice, 9, Vector2(220, 24))
			buy_w.position = Vector2(8, 192)
			buy_w.disabled = int(GameManager.meta.get("souls", 0)) < wprice
			buy_w.pressed.connect(func() -> void:
				if GameManager.buy_weapon(cur_id):
					AudioManager.play_sfx("gold")
					sel["weapon"] = cur_id
					_rebuild()
				else:
					AudioManager.play_sfx("error"))

# ------------------------------------------------------------------ КАРТЫ
func _build_maps() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(288, 200)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(278, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var cur_id := String(preview.get("map", sel["map"]))
	for m in DB.maps:
		var id := String(m["id"])
		if bool(m.get("secret", false)) or String(m.get("unlock", "")) == "secret":
			continue
		var unlocked := GameManager.is_map_unlocked(id)
		var beaten := bool(GameManager.meta.get("beaten_maps", {}).get(id, false))
		var mprice := int(m.get("price", 0))
		var m_txt := String(m["name"])
		if beaten:
			m_txt += " ✔"
		elif not unlocked:
			m_txt += " (%d)" % mprice if mprice > 0 else " (закрыто)"
		var b := UI.button(list, m_txt, 9, Vector2(274, 20))
		if id == String(sel["map"]):
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 2))
			b.add_theme_color_override("font_color", UI.GOLD)
		elif id == cur_id:
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.BORDER_HI, 1))
			b.add_theme_color_override("font_color", UI.TEXT if unlocked else UI.PURPLE)
		elif not unlocked:
			b.add_theme_color_override("font_color", UI.DIM)
		b.pressed.connect(func() -> void:
			preview["map"] = id
			if unlocked:
				sel["map"] = id
			_rebuild())
	var details := UI.panel(content, Rect2(294, 0, 318, 224))
	var m2 := DB.map(cur_id)
	var m_unlocked := GameManager.is_map_unlocked(cur_id)
	var mid2 := String(m2.get("id", "sands"))
	var boss := DB.boss(mid2)
	var mtile := Assets.tile(mid2)
	if mtile != null:
		var tprev := TextureRect.new()
		tprev.texture = mtile
		tprev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tprev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tprev.stretch_mode = TextureRect.STRETCH_SCALE
		tprev.position = Vector2(230, 8)
		tprev.size = Vector2(38, 38)
		tprev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(tprev)
	var btex := Assets.icon("boss_" + mid2)
	if btex == null:
		btex = Assets.icon("boss_champion")
	if btex != null:
		var bprev := TextureRect.new()
		bprev.texture = btex
		bprev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bprev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bprev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bprev.position = Vector2(272, 8)
		bprev.size = Vector2(38, 38)
		bprev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(bprev)
	var title_lbl := UI.label(details, String(m2.get("name", "")), 12, UI.GOLD, Vector2(8, 8))
	title_lbl.custom_minimum_size = Vector2(214, 18)
	title_lbl.size = Vector2(214, 18)
	title_lbl.clip_text = true
	var info_text := "Враги: %d типов\nБосс: %s (HP %d)" % [
		int(m2.get("roster", {}).get("fodder", []).size()) + 3,
		String(boss.get("name", "—")), int(boss.get("hp", 0))]
	var info_lbl := UI.label(details, info_text, 9, UI.DIM, Vector2(8, 28))
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.custom_minimum_size = Vector2(214, 26)
	info_lbl.size = Vector2(214, 26)
	var desc_lbl := UI.label(details, String(m2.get("desc", "")), 9, UI.TEXT, Vector2(8, 58))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(300, 0)
	desc_lbl.size = Vector2(300, 126 if not m_unlocked else 156)
	if not m_unlocked:
		var mprice2 := int(m2.get("price", 0))
		if mprice2 > 0:
			var buy_m := UI.primary_button(details, "ОТКРЫТЬ КАРТУ ЗА %d ДУШ" % mprice2, 9, Vector2(236, 24))
			buy_m.position = Vector2(8, 192)
			buy_m.disabled = int(GameManager.meta.get("souls", 0)) < mprice2
			buy_m.pressed.connect(func() -> void:
				if GameManager.buy_map(cur_id):
					AudioManager.play_sfx("gold")
					sel["map"] = cur_id
					_rebuild()
				else:
					AudioManager.play_sfx("error"))
		else:
			UI.label(details, "Откроется после прохождения предыдущей карты.", 8, UI.PURPLE, Vector2(8, 194))
	# Тьма
	var dlvl := int(sel["darkness"])
	var dk := UI.hbox(content, 6)
	dk.position = Vector2(0, 200)
	UI.label(dk, "%s: %d" % [Loc.t("darkness_level"), dlvl], 10, UI.TEXT)
	var minus := UI.button(dk, "-", 9, Vector2(24, 18))
	minus.pressed.connect(func() -> void:
		sel["darkness"] = maxi(0, int(sel["darkness"]) - 1)
		_rebuild())
	var plus := UI.button(dk, "+", 9, Vector2(24, 18))
	plus.pressed.connect(func() -> void:
		sel["darkness"] = mini(int(GameManager.meta.get("max_darkness", 1)), int(sel["darkness"]) + 1)
		_rebuild())

# ------------------------------------------------------------------ АМУЛЕТЫ
func _build_amulets() -> void:
	var header := UI.panel(content, Rect2(0, 0, 612, 26), UI.PANEL_HI, UI.BORDER)
	UI.label(header, "АМУЛЕТЫ · ЭКИПИРОВАНО %d/8 (ДО 4 УРОВНЕЙ: АТАКА + ЗАЩИТА)" % GameManager.equipped_amulets().size(), 9, UI.GOLD, Vector2(8, 6))
	UI.label(header, "ДУШИ: %d" % int(GameManager.meta.get("souls", 0)), 9, UI.PURPLE, Vector2(510, 6))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 30)
	scroll.size = Vector2(612, 194)
	content.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(594, 0)
	v.add_theme_constant_override("separation", 3)
	scroll.add_child(v)
	for amu in DB.amulets:
		var aid := String(amu["id"])
		var rank := GameManager.amulet_rank(aid)
		var cost := GameManager.amulet_cost(aid)
		var eq := GameManager.amulet_equipped(aid)
		var row := UI.panel(v, Rect2(0, 0, 594, 24), UI.PANEL_HI if eq else UI.PANEL, UI.GOLD if eq else UI.BORDER)
		row.custom_minimum_size = Vector2(594, 24)
		var h := UI.hbox(row, 6)
		h.position = Vector2(4, 3)
		h.size = Vector2(586, 18)
		var itex := Assets.icon("icon_" + aid)
		if itex != null:
			var ico := TextureRect.new()
			ico.texture = itex
			ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ico.custom_minimum_size = Vector2(18, 18)
			ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(ico)
		var l := UI.crisp_label(h, "%s [%s] (%d/5) — %s" % [String(amu["name"]), String(amu["type"]), rank, String(amu.get("desc", ""))], 8, UI.GOLD_BRIGHT if eq else (UI.TEXT if rank > 0 else UI.DIM))
		l.custom_minimum_size = Vector2(368, 16)
		l.clip_text = true
		if cost > 0:
			var upg_btn := UI.button(h, "%s (%d)" % ["Купить" if rank == 0 else "Улучш.", cost], 8, Vector2(106, 18))
			upg_btn.disabled = int(GameManager.meta.get("souls", 0)) < cost
			upg_btn.pressed.connect(func() -> void:
				if GameManager.upgrade_amulet(aid):
					AudioManager.play_sfx("gold")
					if not GameManager.amulet_equipped(aid):
						GameManager.toggle_amulet(aid)
				else:
					AudioManager.play_sfx("error")
				_rebuild())
		else:
			var max_l := UI.crisp_label(h, "МАКС.", 8, UI.GREEN)
			max_l.custom_minimum_size = Vector2(106, 16)
			max_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var eq_btn := UI.button(h, "Снять" if eq else "Надеть", 8, Vector2(74, 18))
		eq_btn.disabled = rank <= 0
		eq_btn.pressed.connect(func() -> void:
			GameManager.toggle_amulet(aid)
			_rebuild())

# ------------------------------------------------------------------ РЕЖИМ / ИСПЫТАНИЯ
func _build_modes() -> void:
	var left := UI.panel(content, Rect2(0, 0, 612, 224))
	var mode_scroll := ScrollContainer.new()
	mode_scroll.position = Vector2(4, 4)
	mode_scroll.size = Vector2(604, 216)
	left.add_child(mode_scroll)
	var mode_body := Control.new()
	mode_body.custom_minimum_size = Vector2(586, 440)
	mode_scroll.add_child(mode_body)
	UI.label(mode_body, Loc.t("mode"), 10, UI.GOLD, Vector2(8, 6))
	var modes := [["standard", Loc.t("mode_standard")], ["quick", Loc.t("mode_quick")], ["endless", Loc.t("mode_endless")], ["coop", "ЛОКАЛЬНЫЙ КООПЕРАТИВ"]]
	var y := 22
	for mo in modes:
		var id := String(mo[0])
		var b := UI.button(mode_body, String(mo[1]), 9, Vector2(270, 20))
		b.position = Vector2(8, y)
		if String(sel["mode"]) == id:
			b.add_theme_stylebox_override("normal", UI.style(Color("#23262e"), UI.GOLD, 2))
		if id == "endless" and not GameManager.is_endless_unlocked():
			b.disabled = true
			b.text += " (закрыто)"
		if id == "coop" and (Progression.tree_level("mastery") < 10 or int(GameManager.meta.get("stats",{}).get("runs",0)) < 20):
			b.disabled = true
			b.text += " (Мастерство 10 + 20 забегов)"
		b.pressed.connect(func() -> void:
			if id == "endless" and not GameManager.is_endless_unlocked():
				return
			sel["mode"] = id
			_rebuild())
		y += 22
	if not GameManager.is_endless_unlocked():
		UI.label(mode_body, Loc.t("locked_endless"), 8, UI.DIM, Vector2(8, y))
		y += 14
	UI.label(mode_body, "Испытания (за бонусные души):", 9, UI.GOLD, Vector2(8, y))
	y += 14
	var trials := [["hell","АД ×2.0: враги сильнее, лечение −50%"], ["speedrun","СПИДРАН ×1.5: 15 минут, ускоренный бой"], ["no_heal","БЕЗ ИСЦЕЛЕНИЯ ×2.0"], ["sniper","СНАЙПЕР ×1.5: только дальний бой"], ["berserk","БЕРСЕРК ×2.0: +урон/+HP"], ["invisible","НЕВИДИМЫЕ ×1.5: видимость 128 px"], ["wave","ЦУНАМИ ×1.5: бесконечные волны"], ["one_life","ОДНА ЖИЗНЬ ×3.0: 1 HP"], ["chaos","ХАОС ×1.5: правило каждые 60 сек"]]
	for tr in trials:
		var tid := String(tr[0])
		var on: bool = (sel["trials"] as Array).has(tid)
		var b := UI.button(mode_body, ("✔ " if on else "✖ ") + String(tr[1]), 8, Vector2(360, 18))
		b.position = Vector2(8, y)
		b.pressed.connect(func() -> void:
			var arr: Array = sel["trials"]
			if arr.has(tid):
				arr.erase(tid)
			else:
				arr.append(tid)
			_rebuild())
		y += 20
	UI.label(mode_body, "Благословение карты:", 9, UI.GOLD, Vector2(8, y))
	y += 14
	var blessings := [["torch", "Факел: +25% обзора"], ["boots", "Сапоги: -50% замедления"], ["ward", "Оберег: -50% урона ивентов"]]
	for bl in blessings:
		var bid := String(bl[0])
		var on2: bool = String(sel["blessing"]) == bid
		var b2 := UI.button(mode_body, ("✔ " if on2 else "✖ ") + String(bl[1]), 8, Vector2(360, 18))
		b2.position = Vector2(8, y)
		b2.pressed.connect(func() -> void:
			sel["blessing"] = "" if on2 else bid
			_rebuild())
		y += 20

func _start_run() -> void:
	if String(sel["map"]) == "void":
		sel["map"] = "sands"
	GameManager.start_run(sel.duplicate())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.goto_menu()
