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
var content: Control
var summary: Label
var tab_buttons: Array = []

func _ready() -> void:
	tab = int(OS.get_environment("SURW_TAB")) if OS.get_environment("SURW_TAB") != "" else 0
	_build()
	AudioManager.play_music({"root": 50, "scale": "minor", "tempo": 64, "wave": "lute"})
	AudioManager.set_intensity(0.0)

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

	# --- вкладки-«таблетки»
	var tabs: Array = [Loc.t("character"), Loc.t("weapon"), Loc.t("map"), Loc.t("mode")]
	var x := 14
	for i in tabs.size():
		var b := UI.button(self, String(tabs[i]).to_upper(), 9, Vector2(120, 22))
		b.position = Vector2(x, 48)
		var idx := i
		b.pressed.connect(func() -> void:
			tab = idx
			_rebuild())
		tab_buttons.append(b)
		x += 124

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
		3: _build_modes()
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
	for ch in DB.characters:
		var id := String(ch["id"])
		var unlocked := GameManager.is_char_unlocked(id)
		var b := UI.button(list, String(ch["name"]), 9, Vector2(148, 20))
		b.disabled = not unlocked
		if not unlocked:
			b.text = "%s (закрыто)" % String(ch["name"])
			if int(ch.get("price", 0)) > 0:
				b.text = "%s (%d)" % [String(ch["name"]), int(ch.get("price", 0))]
		if id == String(sel["character"]):
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 2))
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func() -> void:
			if unlocked:
				sel["character"] = id
				_rebuild()
			else:
				AudioManager.play_sfx("error"))

	# --- средняя колонка: описание и характеристики
	var details := UI.panel(content, Rect2(164, 0, 244, 224))
	var dscroll := ScrollContainer.new()
	dscroll.position = Vector2(8, 6)
	dscroll.size = Vector2(228, 212)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(dscroll)
	var dbox := VBoxContainer.new()
	dbox.custom_minimum_size = Vector2(220, 0)
	dbox.add_theme_constant_override("separation", 4)
	dscroll.add_child(dbox)
	var ch2 := DB.character(String(sel["character"]))
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
	scroll.size = Vector2(196, 244)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(190, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	for w in DB.weapons:
		var id := String(w["id"])
		var unlocked := GameManager.is_weapon_unlocked(id)
		var b := UI.button(list, String(w["name"]), 9, Vector2(186, 20))
		b.disabled = not unlocked
		if not unlocked:
			b.text = "%s (закрыто) %d" % [String(w["name"]), int(w.get("price", 0))]
		if id == String(sel["weapon"]):
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 2))
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func() -> void:
			if unlocked:
				sel["weapon"] = id
				_rebuild()
			else:
				AudioManager.play_sfx("error"))
	var details := UI.panel(content, Rect2(202, 0, 426, 244))
	var dscroll := ScrollContainer.new()
	dscroll.position = Vector2(0, 0)
	dscroll.size = Vector2(426, 244)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(dscroll)
	var dbox := VBoxContainer.new()
	dbox.custom_minimum_size = Vector2(410, 0)
	dbox.add_theme_constant_override("separation", 4)
	dscroll.add_child(dbox)
	var w2 := DB.weapon(String(sel["weapon"]))
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
	l.size = Vector2(368 if wtex != null else 410, 90)
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
	var l2 := UI.label(details, evo_txt, 8, UI.DIM, Vector2(8, 100))
	l2.custom_minimum_size = Vector2(400, 150)
	l2.size = Vector2(400, 150)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.clip_text = true

# ------------------------------------------------------------------ КАРТЫ
func _build_maps() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(320, 244)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(310, 0)
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	for m in DB.maps:
		var id := String(m["id"])
		if bool(m.get("secret", false)):
			continue
		var unlocked := GameManager.is_map_unlocked(id)
		var beaten := bool(GameManager.meta.get("beaten_maps", {}).get(id, false))
		var b := UI.button(list, "%s%s" % [String(m["name"]), " ✔" if beaten else ("" if unlocked else " (закрыто)")], 9, Vector2(306, 20))
		b.disabled = not unlocked
		if id == String(sel["map"]):
			b.add_theme_stylebox_override("normal", UI.style(UI.PANEL_HI, UI.GOLD, 2))
			b.add_theme_color_override("font_color", UI.GOLD)
		b.pressed.connect(func() -> void:
			if unlocked:
				sel["map"] = id
				_rebuild())
	var details := UI.panel(content, Rect2(326, 0, 302, 244))
	var m2 := DB.map(String(sel["map"]))
	var mid2 := String(m2.get("id", "sands"))
	var boss := DB.boss(mid2)
	var mtile := Assets.tile(mid2)
	if mtile != null:
		var tprev := TextureRect.new()
		tprev.texture = mtile
		tprev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tprev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tprev.stretch_mode = TextureRect.STRETCH_SCALE
		tprev.position = Vector2(214, 8)
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
		bprev.position = Vector2(256, 8)
		bprev.size = Vector2(38, 38)
		bprev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(bprev)
	var text := "%s\n\n%s\n\nВраги: %d типов\nБосс: %s (HP %d)\n\nИвенты:\n" % [
		String(m2.get("name", "")), String(m2.get("desc", "")),
		int(m2.get("roster", {}).get("fodder", []).size()) + 3,
		String(boss.get("name", "—")), int(boss.get("hp", 0))]
	for e in m2.get("events", []):
		text += "› %s (каждые %.0f сек)\n" % [EVENT_NAMES.get(String(e.get("kind", "")), String(e.get("kind", ""))), float(e.get("interval", 60.0))]
	var l := UI.label(details, text, 9, UI.TEXT, Vector2(8, 6))
	l.size = Vector2(204, 220)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Тьма
	var dk := UI.hbox(content, 6)
	dk.position = Vector2(0, 248)
	UI.label(dk, "%s: %d" % [Loc.t("darkness_level"), int(sel["darkness"])], 10, UI.TEXT)
	var minus := UI.button(dk, "-", 9, Vector2(24, 18))
	minus.pressed.connect(func() -> void:
		sel["darkness"] = maxi(1, int(sel["darkness"]) - 1)
		_rebuild())
	var plus := UI.button(dk, "+", 9, Vector2(24, 18))
	plus.pressed.connect(func() -> void:
		sel["darkness"] = mini(int(GameManager.meta.get("max_darkness", 1)), int(sel["darkness"]) + 1)
		_rebuild())

# ------------------------------------------------------------------ РЕЖИМ / АМУЛЕТЫ
func _build_modes() -> void:
	var left := UI.panel(content, Rect2(0, 0, 306, 244))
	var mode_scroll := ScrollContainer.new()
	mode_scroll.position = Vector2(4,4); mode_scroll.size = Vector2(298,236); left.add_child(mode_scroll)
	var mode_body := Control.new(); mode_body.custom_minimum_size = Vector2(282,450); mode_scroll.add_child(mode_body)
	UI.label(mode_body, Loc.t("mode"), 10, UI.GOLD, Vector2(8, 6))
	var modes := [["standard", Loc.t("mode_standard")], ["quick", Loc.t("mode_quick")], ["endless", Loc.t("mode_endless")], ["coop", "ЛОКАЛЬНЫЙ КООПЕРАТИВ"]]
	var y := 22
	for mo in modes:
		var id := String(mo[0])
		var b := UI.button(mode_body, String(mo[1]), 9, Vector2(170, 20))
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
		var b := UI.button(mode_body, ("✔ " if on else "✖ ") + String(tr[1]), 8, Vector2(288, 18))
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
		var b2 := UI.button(mode_body, ("✔ " if on2 else "✖ ") + String(bl[1]), 8, Vector2(288, 18))
		b2.position = Vector2(8, y)
		b2.pressed.connect(func() -> void:
			sel["blessing"] = "" if on2 else bid
			_rebuild())
		y += 20
	# амулеты
	var right := UI.panel(content, Rect2(312, 0, 316, 244))
	UI.label(right, "%s (экипировано %d/8)" % [Loc.t("amulets"), GameManager.equipped_amulets().size()], 10, UI.GOLD, Vector2(8, 6))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 22)
	scroll.size = Vector2(304, 214)
	right.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(296, 0)
	v.add_theme_constant_override("separation", 2)
	scroll.add_child(v)
	for amu in DB.amulets:
		var aid := String(amu["id"])
		var rank := GameManager.amulet_rank(aid)
		var eq := GameManager.amulet_equipped(aid)
		var h := UI.hbox(v, 4)
		var l := UI.label(h, "%s (%d/5)" % [String(amu["name"]), rank], 8, UI.TEXT if rank > 0 else UI.DIM)
		l.custom_minimum_size = Vector2(150, 14)
		var b := UI.button(h, "снять" if eq else "надеть", 8, Vector2(60, 16))
		b.disabled = rank <= 0
		b.pressed.connect(func() -> void:
			GameManager.toggle_amulet(aid)
			_rebuild())
	if GameManager.equipped_amulets().is_empty():
		UI.label(v, "Амулеты покупаются в магазине за души.", 8, UI.DIM)

func _start_run() -> void:
	if String(sel["map"]) == "void":
		sel["map"] = "sands"
	GameManager.start_run(sel.duplicate())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.goto_menu()
