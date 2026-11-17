extends CanvasLayer
## HUD забега + оверлеи: выбор улучшения, пауза, конец раунда, список синергий.

signal choice_made(card: Dictionary)

var game: Node = null
var _last_hp := -1
var _last_max_hp := -1
var root: Control
var hp_lbl: Label
var timer_lbl: Label
var level_lbl: Label
var xp_fill: ColorRect
var xp_back: ColorRect
var name_lbl: Label
var ammo_lbl: Label
var skill_lbl: Label
var fps_lbl: Label
var perks_lbl: Label
var xp_lbl: Label
var hearts: Control
var _heart_slots: Array = []
var ammo_icon: TextureRect
var skill_icon: Control
var skill_tex: TextureRect
var skill_ring: Control
var combo_lbl: Label
var weather_lbl: Label
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label
var toast_box: VBoxContainer
var choice_layer: Control
var choice_title: Label
var choice_hint: Label
var choice_box: HBoxContainer
var pause_layer: Control
var pause_perk_list: VBoxContainer
var pause_perks_count: Label
var pause_stats: VBoxContainer
var end_layer: Control
var syn_layer: Control
var syn_list: VBoxContainer
var current_cards: Array = []
var cheat_console: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()

## Чит-консоль живёт внутри HUD: `~` открывает строку, «wuss menu» — меню.
func _setup_cheat_console() -> void:
	if game == null or cheat_console != null:
		return
	cheat_console = load("res://scripts/ui/cheat_console.gd").new()
	cheat_console.set("game", game)
	add_child(cheat_console)

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- шкала опыта во всю ширину, поверх неё по центру уровень
	xp_back = ColorRect.new()
	xp_back.color = Color("#0b0c10")
	xp_back.position = Vector2(0, 0)
	xp_back.size = Vector2(640, 8)
	xp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xp_back)
	var xp_frame := ColorRect.new()
	xp_frame.color = Color(0.30, 0.31, 0.34, 0.9)
	xp_frame.position = Vector2(0, 8)
	xp_frame.size = Vector2(640, 1)
	xp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xp_frame)
	xp_fill = ColorRect.new()
	xp_fill.color = Color("#8f8158")
	xp_fill.position = Vector2(0, 0)
	xp_fill.size = Vector2(0, 8)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(xp_fill)
	level_lbl = UI.label(root, "УРОВЕНЬ 1", 13, UI.TEXT, Vector2(0, 12))
	level_lbl.size = Vector2(640, 15)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for side in [-1, 1]:
		var seg := ColorRect.new()
		seg.color = Color(0.40, 0.40, 0.44, 0.85)
		seg.size = Vector2(56, 1)
		seg.position = Vector2(320 + (74.0 if side > 0 else -130.0), 19)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(seg)

	# --- слева сверху: сердца здоровья (увеличенные рубиновые сердца)
	hearts = Control.new()
	hearts.position = Vector2(6, 22)
	hearts.size = Vector2(216, 22)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hearts)
	hp_lbl = UI.label(root, "", 10, UI.TEXT, Vector2(226, 26))

	# --- слева под сердцами: патроны в магазине и иконка скилла
	ammo_icon = TextureRect.new()
	ammo_icon.position = Vector2(6, 47)
	ammo_icon.size = Vector2(12, 16)
	ammo_icon.texture = Assets.icon("ui_ammo")
	ammo_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ammo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ammo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ammo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ammo_icon)
	ammo_lbl = UI.label(root, "0/0", 13, UI.GOLD, Vector2(22, 48))

	skill_icon = Control.new()
	skill_icon.position = Vector2(86, 46)
	skill_icon.size = Vector2(18, 18)
	skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_icon)
	skill_tex = TextureRect.new()
	skill_tex.position = Vector2(1, 1)
	skill_tex.size = Vector2(16, 16)
	skill_tex.texture = Assets.icon("ui_skill_ready")
	skill_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skill_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skill_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skill_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_icon.add_child(skill_tex)
	skill_ring = Control.new()
	skill_ring.position = Vector2.ZERO
	skill_ring.size = Vector2(18, 18)
	skill_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_icon.add_child(skill_ring)
	skill_ring.draw.connect(_draw_skill_ring)

	# --- справа сверху: оставшееся время и подпись режима
	timer_lbl = UI.label(root, "30:00", 20, UI.TEXT, Vector2(462, 12))
	timer_lbl.size = Vector2(172, 22)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- золото и души теперь только в меню паузы, на поле их нет
	weather_lbl = UI.label(root, "", 8, UI.ACCENT, Vector2(320, 27))
	weather_lbl.size = Vector2(220, 11)
	weather_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_lbl.visible = false
	combo_lbl = UI.label(root, "", 12, Color("#cbc6ba"), Vector2(564, 40))
	combo_lbl.size = Vector2(70, 16)
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_lbl.visible = false

	# --- босс (строго по центру сверху, не перекрывает арену и спрайт босса)
	boss_box = Control.new()
	boss_box.position = Vector2(170, 34)
	boss_box.size = Vector2(300, 20)
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_box)
	boss_name = UI.label(boss_box, "", 9, Color("#e4c9bd"), Vector2(0, 0))
	boss_name.size = Vector2(300, 11)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boss_back := ColorRect.new()
	boss_back.color = Color("#150e0d")
	boss_back.position = Vector2(0, 12)
	boss_back.size = Vector2(300, 7)
	boss_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(boss_back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color("#9f312a")
	boss_fill.position = Vector2(0, 12)
	boss_fill.size = Vector2(300, 7)
	boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(boss_fill)

	# --- низ: только FPS и мелкие служебные надписи
	fps_lbl = UI.label(root, "", 7, UI.DIM, Vector2(586, 350))
	fps_lbl.size = Vector2(48, 10)
	fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- тосты по центру сверху
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(170, 58)
	toast_box.size = Vector2(300, 60)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

	_apply_outlines(root)
	_build_choice_layer()
	_build_pause_layer()
	_build_end_layer()
	_build_syn_layer()
	EventBus.notify.connect(_on_notify)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.chest_opened.connect(_on_chest)
	EventBus.boss_damaged.connect(update_boss_bar)
	EventBus.upgrade_picked.connect(_on_upgrade_picked)

func setup(g: Node) -> void:
	game = g
	_setup_cheat_console()

# ------------------------------------------------------------------ ОВЕРЛЕИ
func _dim(parent: Control) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.72)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(d)
	return d

func _build_choice_layer() -> void:
	choice_layer = Control.new()
	choice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_layer.visible = false
	root.add_child(choice_layer)
	_dim(choice_layer)
	choice_title = UI.label(choice_layer, "", 14, UI.GOLD, Vector2(0, 12))
	choice_title.size = Vector2(640, 18)
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_hint = UI.label(choice_layer, "ЛКМ — выбрать · игра на паузе", 8, UI.MUTED, Vector2(0, 31))
	choice_hint.size = Vector2(640, 12)
	choice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box = HBoxContainer.new()
	choice_box.position = Vector2(10, 46)
	choice_box.size = Vector2(620, 302)
	choice_box.add_theme_constant_override("separation", 6)
	choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_layer.add_child(choice_box)

## Меню паузы: слева хронология взятых перков, справа сводка по забегу.
func _build_pause_layer() -> void:
	pause_layer = Control.new()
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.visible = false
	root.add_child(pause_layer)
	_dim(pause_layer)

	var title := UI.label(pause_layer, Loc.t("paused"), 16, UI.GOLD, Vector2(0, 10))
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := UI.label(pause_layer, "Esc — продолжить · Tab — список взятого", 8, UI.DIM, Vector2(0, 30))
	hint.size = Vector2(640, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- левая колонка: перки по порядку получения
	var left := UI.panel(pause_layer, Rect2(10, 44, 350, 258))
	UI.label(left, "ВЗЯТЫЕ ПЕРКИ ПО ПОРЯДКУ", 9, UI.GOLD, Vector2(8, 6))
	pause_perks_count = UI.label(left, "", 8, UI.DIM, Vector2(200, 6))
	pause_perks_count.size = Vector2(140, 10)
	pause_perks_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 22)
	scroll.size = Vector2(338, 228)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	pause_perk_list = VBoxContainer.new()
	pause_perk_list.custom_minimum_size = Vector2(330, 0)
	pause_perk_list.add_theme_constant_override("separation", 1)
	scroll.add_child(pause_perk_list)

	# --- правая колонка: сводка забега
	var right := UI.panel(pause_layer, Rect2(368, 44, 262, 176))
	UI.label(right, "ЗАБЕГ", 9, UI.GOLD, Vector2(8, 6))
	pause_stats = VBoxContainer.new()
	pause_stats.position = Vector2(8, 22)
	pause_stats.size = Vector2(246, 148)
	pause_stats.add_theme_constant_override("separation", 1)
	right.add_child(pause_stats)

	# --- кнопки
	var buttons := UI.vbox(pause_layer, 6)
	buttons.position = Vector2(368, 228)
	buttons.size = Vector2(262, 74)
	var resume := UI.button(buttons, Loc.t("resume"), 10, Vector2(262, 22))
	resume.pressed.connect(toggle_pause)
	var to_menu := UI.button(buttons, Loc.t("main_menu"), 10, Vector2(262, 22))
	to_menu.pressed.connect(_pause_to_menu)
	var quit := UI.button(buttons, Loc.t("quit"), 10, Vector2(262, 22))
	quit.pressed.connect(func() -> void: get_tree().quit())

	# --- подсказка внизу
	var foot := UI.label(pause_layer, "Пробел — автоприцел · R — перезарядка · ЛКМ — огонь · F12 / P — фоторежим", 7, UI.DIM, Vector2(0, 312))
	foot.size = Vector2(640, 10)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_end_layer() -> void:
	end_layer = Control.new()
	end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.visible = false
	root.add_child(end_layer)
	_dim(end_layer)
	var panel := UI.panel(end_layer, Rect2(150, 60, 340, 240))
	var v := UI.vbox(panel, 4)
	v.position = Vector2(16, 12)
	v.size = Vector2(308, 210)

func _build_syn_layer() -> void:
	syn_layer = Control.new()
	syn_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	syn_layer.visible = false
	root.add_child(syn_layer)
	_dim(syn_layer)
	var panel := UI.panel(syn_layer, Rect2(140, 40, 360, 280))
	UI.label(panel, Loc.t("synergies_list"), 12, UI.GOLD, Vector2(12, 8))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 30)
	scroll.size = Vector2(340, 210)
	panel.add_child(scroll)
	syn_list = VBoxContainer.new()
	syn_list.custom_minimum_size = Vector2(330, 0)
	syn_list.add_theme_constant_override("separation", 2)
	scroll.add_child(syn_list)
	var close := UI.button(panel, Loc.t("close"), 9, Vector2(80, 20))
	close.position = Vector2(268, 248)
	close.pressed.connect(func() -> void: syn_layer.visible = false)

# ------------------------------------------------------------------ ВЫБОР
func open_choice(cards: Array, title: String, _kind: String) -> void:
	current_cards = cards
	UI.clear(choice_box)
	choice_title.text = title
	var card_w := 118.0
	if cards.size() <= 3:
		card_w = 186.0
	elif cards.size() == 4:
		card_w = 148.0
	var card_h := 296.0
	for i in cards.size():
		var card: Dictionary = cards[i]
		var kind := String(card.get("kind", "perk"))
		var data: Dictionary = card.get("data", {})
		var cid := String(card.get("id", ""))
		var accent := UI.kind_color(kind)
		var b := UI.card(choice_box, Vector2(card_w, card_h), accent)

		var stripe := ColorRect.new()
		stripe.color = accent
		stripe.position = Vector2(2, 2)
		stripe.size = Vector2(card_w - 4, 2)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(stripe)

		var v := UI.vbox(b, 3)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 6
		v.offset_top = 6
		v.offset_right = -6
		v.offset_bottom = -6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# --- верх карточки: иллюстрация + #N + тип + название
		var illus_tex := _card_illustration(card)
		var illus_h := 48.0 if cards.size() <= 4 else 42.0
		var illus_frame := UI.panel(v, Rect2(0, 0, card_w - 12, illus_h), Color("#0d0e13"), Color(accent.r, accent.g, accent.b, 0.75))
		illus_frame.custom_minimum_size = Vector2(card_w - 12, illus_h)
		illus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if illus_tex != null:
			var itex := TextureRect.new()
			itex.texture = illus_tex
			itex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			itex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			itex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			itex.set_anchors_preset(Control.PRESET_FULL_RECT)
			itex.offset_left = 2
			itex.offset_top = 2
			itex.offset_right = -2
			itex.offset_bottom = -2
			itex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			illus_frame.add_child(itex)

		var hdr := UI.hbox(v, 4)
		hdr.custom_minimum_size = Vector2(card_w - 12, 13)
		hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := UI.crisp_label(hdr, "#%d %s" % [i + 1, UI.kind_name(kind).to_upper()], 8, accent)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var meta_short := _card_tier_badge(card)
		if meta_short != "":
			var mbadge := UI.crisp_label(hdr, meta_short, 8, UI.GOLD_BRIGHT)
			mbadge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			mbadge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var title_lbl := UI.crisp_label(v, String(data.get("name", cid)), 10, Color("#f2ece0"))
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.custom_minimum_size = Vector2(card_w - 12, 22)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var div1 := ColorRect.new()
		div1.color = Color(accent.r, accent.g, accent.b, 0.45)
		div1.custom_minimum_size = Vector2(card_w - 12, 1)
		div1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(div1)

		# --- низ карточки: чёткое описание + ветвь улучшений
		var desc_lbl := UI.crisp_label(v, String(data.get("desc", "")), 8, Color("#cfc9bc"))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(card_w - 12, 34)
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.clip_text = true
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_build_card_branch(v, card, card_w - 12, accent)

		b.pressed.connect(_on_card_pressed.bind(card))
	choice_hint.text = "ЛКМ или клавиши 1–%d · игра на паузе" % cards.size()
	choice_layer.visible = true

## Иллюстрация для карточки выбора (96x48 pixel art).
func _card_illustration(card: Dictionary) -> Texture2D:
	var kind := String(card.get("kind", "perk"))
	var cid := String(card.get("id", ""))
	var tex := Assets.icon("illus_" + cid)
	if tex != null:
		return tex
	if kind == "evolution":
		return Assets.icon("illus_evolution")
	if kind == "specialization":
		return Assets.icon("illus_specialization")
	return _card_icon(card)

func _card_tier_badge(card: Dictionary) -> String:
	var kind := String(card.get("kind", "perk"))
	var data: Dictionary = card.get("data", {})
	var upg: UpgradeSystem = game.player.upg if (game != null and game.player != null) else null
	if kind == "perk":
		var tier := int(data.get("tier", 1))
		var stack := int(upg.taken.get(String(card.get("id", "")), 0)) if upg != null else 0
		return "T%d ×%d" % [tier, stack] if stack > 0 else "T%d" % tier
	if kind == "specialization" and upg != null and upg.specialization_pending > 0:
		return "×%d" % int(upg.spec_mult)
	return ""

## Читаемая визуальная ветвь улучшений в нижней половине карточки (T1 -> T2a / T2b -> T3).
func _build_card_branch(parent: Control, card: Dictionary, width: float, accent: Color) -> void:
	var wrap := UI.panel(parent, Rect2(0, 0, width, 134), Color("#0b0c11"), Color(0.32, 0.34, 0.40, 0.85))
	wrap.custom_minimum_size = Vector2(width, 134)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind := String(card.get("kind", "perk"))
	var data: Dictionary = card.get("data", {})
	var cid := String(card.get("id", ""))
	var upg: UpgradeSystem = game.player.upg if (game != null and game.player != null) else null

	if kind == "perk":
		var tree_id := String(data.get("tree", ""))
		var tree: Dictionary = DB.tree_by_id.get(tree_id, {})
		var nodes: Array = tree.get("nodes", [])
		var tname := String(tree.get("name", tree_id))
		var hdr := UI.crisp_label(wrap, "ВЕТВЬ: " + tname.to_upper(), 8, UI.GOLD_BRIGHT, Vector2(5, 4))
		hdr.size = Vector2(width - 10, 12)
		hdr.clip_text = true
		hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if nodes.size() >= 4:
			var graph := Control.new()
			graph.position = Vector2(4, 18)
			graph.size = Vector2(width - 8, 112)
			graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(graph)
			var gw := width - 8.0
			var box_h := 23.0
			var rows := [
				{"id": String(nodes[0]), "tier": "T1", "x": 2.0, "y": 2.0, "w": gw - 4.0},
				{"id": String(nodes[1]), "tier": "T2", "x": 12.0, "y": 29.0, "w": gw - 14.0},
				{"id": String(nodes[2]), "tier": "T2", "x": 12.0, "y": 56.0, "w": gw - 14.0},
				{"id": String(nodes[3]), "tier": "T3", "x": 22.0, "y": 83.0, "w": gw - 24.0},
			]
			graph.draw.connect(func() -> void:
				var line_col := Color(accent.r, accent.g, accent.b, 0.72)
				# Вертикальная ветка от T1 к T2a/T2b и далее к T3
				graph.draw_line(Vector2(6.0, 25.0), Vector2(6.0, 67.5), line_col, 1.5)
				graph.draw_line(Vector2(6.0, 40.5), Vector2(12.0, 40.5), line_col, 1.5)
				graph.draw_line(Vector2(6.0, 67.5), Vector2(12.0, 67.5), line_col, 1.5)
				graph.draw_line(Vector2(16.0, 79.0), Vector2(16.0, 94.5), line_col, 1.5)
				graph.draw_line(Vector2(16.0, 94.5), Vector2(22.0, 94.5), line_col, 1.5))
			for row_d in rows:
				var nid := String(row_d["id"])
				var rx := float(row_d["x"])
				var ry := float(row_d["y"])
				var rw := float(row_d["w"])
				var pdata: Dictionary = DB.perk(nid)
				var taken_cnt := int(upg.taken.get(nid, 0)) if upg != null else 0
				var is_cur := nid == cid
				var bg := Color("#2b2312") if is_cur else (Color("#132619") if taken_cnt > 0 else Color("#12141b"))
				var bd := UI.GOLD_BRIGHT if is_cur else (Color("#79b86c") if taken_cnt > 0 else Color("#3b3f4c"))
				var nb := Panel.new()
				nb.position = Vector2(rx, ry)
				nb.size = Vector2(rw, box_h)
				nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				nb.add_theme_stylebox_override("panel", UI.style(bg, bd, 1, 0))
				graph.add_child(nb)
				var short_name := String(pdata.get("name", nid))
				var tc := Color("#ffe599") if is_cur else (Color("#9ae08c") if taken_cnt > 0 else Color("#dcd7cb"))
				var nl := UI.crisp_label(nb, "%s · %s" % [String(row_d["tier"]), short_name], 8, tc, Vector2(4, 3))
				nl.size = Vector2(rw - 8, box_h - 6)
				nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				nl.clip_text = true
				nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# Для синергий, печатей, эволюций, спецов и апгрейдов
	var hdr2 := UI.crisp_label(wrap, "ЭФФЕКТ И УСЛОВИЯ", 8, UI.GOLD_BRIGHT, Vector2(6, 5))
	hdr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_txt := _card_meta(card)
	var req_txt := _card_requires(data)
	if req_txt != "":
		body_txt += "\n\n" + req_txt
	var blbl := UI.crisp_label(wrap, body_txt, 8, Color("#e4dfd3"), Vector2(6, 22))
	blbl.size = Vector2(width - 12, 106)
	blbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Выбор карточки с клавиатуры (1–5).
func _input_choice_hotkey(event: InputEvent) -> bool:
	if not choice_layer.visible:
		return false
	for i in mini(current_cards.size(), 5):
		var key := KEY_1 + i
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == key:
			_on_card_pressed(current_cards[i])
			return true
	return false

## Иконка карточки выбора (перк, синергия, печать, эволюция, апгрейд).
func _card_icon(card: Dictionary) -> Texture2D:
	var kind := String(card.get("kind", "perk"))
	var data: Dictionary = card.get("data", {})
	var cid := String(card.get("id", ""))
	match kind:
		"perk":
			return Assets.icon("icon_tree_" + String(data.get("tree", "")))
		"synergy", "seal":
			return Assets.icon("icon_" + cid)
		"evolution":
			if game != null and game.player != null:
				return Assets.icon("icon_weapon_" + String(game.player.weapon.get("id", "")))
		"char_upgrade":
			if game != null and game.player != null:
				return Assets.icon(String(game.player.char_data.get("cls", "")))
		"specialization":
			return Assets.icon("ui_crest")
	return null

## Подпись карточки: дерево, тир и число уже взятых стаков.
func _card_meta(card: Dictionary) -> String:
	var kind := String(card.get("kind", "perk"))
	var data: Dictionary = card.get("data", {})
	var upg: UpgradeSystem = game.player.upg if (game != null and game.player != null) else null
	match kind:
		"perk":
			var tree_id := String(data.get("tree", ""))
			var tree_name := String(DB.tree_by_id.get(tree_id, {}).get("name", tree_id))
			var tier := int(data.get("tier", 1))
			var stack := int(upg.taken.get(String(card.get("id", "")), 0)) if upg != null else 0
			var out := "%s · T%d" % [tree_name, tier]
			if stack > 0:
				out += " · взят ×%d" % stack
			return out
		"synergy":
			return "Синергия · все условия выполнены"
		"char_upgrade":
			return "Уникальный апгрейд персонажа"
		"seal":
			return "Древняя печать"
		"specialization":
			if upg != null and upg.specialization_pending > 0:
				return "Специализация · ×%d следующему перку" % int(upg.spec_mult)
			return "Специализация"
		"evolution":
			return "Эволюция оружия"
	return ""

## Строка требований: для синергии — какие перки уже собраны.
func _card_requires(data: Dictionary) -> String:
	var reqs: Array = data.get("requires", [])
	if reqs.is_empty():
		return ""
	var names: Array = []
	for rid in reqs:
		var perk := DB.perk(String(rid))
		names.append(String(perk.get("name", rid)))
	if names.is_empty():
		return ""
	return "Нужно: " + ", ".join(names)

func _on_card_pressed(card: Dictionary) -> void:
	choice_layer.visible = false
	AudioManager.play_sfx("ui", 1.2)
	choice_made.emit(card)

func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_refresh(delta)

func _refresh(delta: float) -> void:
	var p: Player = game.player
	if weather_lbl != null:
		var w: Dictionary = game.weather if game != null else {}
		if w.is_empty():
			weather_lbl.visible = false
		else:
			weather_lbl.visible = true
			weather_lbl.text = "%s · %d с" % [String(w.get("title", "")), int(ceilf(float(w.get("left", 0.0))))]
			weather_lbl.add_theme_color_override("font_color", UI.ACCENT if float(w.get("left", 0.0)) > 3.0 else UI.DANGER)
	var corner := String(GameManager.setting("hud_vitals", "corner")) == "corner"
	# в режиме «над игроком» верхние сердца и патроны скрыты
	if hearts != null:
		hearts.visible = corner
	if ammo_icon != null:
		ammo_icon.visible = corner
	hp_lbl.visible = corner
	ammo_lbl.visible = corner
	if int(_last_hp) != p.hp or int(_last_max_hp) != p.max_hp:
		_last_hp = p.hp
		_last_max_hp = p.max_hp
		_sync_hearts(p)
	hp_lbl.text = "%d/%d" % [maxi(p.hp, 0), p.max_hp]
	if p.shield_charges > 0:
		hp_lbl.text += " ★"
	# патроны: при перезарядке счётчик и иконка становятся белыми
	ammo_lbl.text = "%d/%d" % [p.mag, int(p.S.mag)]
	ammo_lbl.add_theme_color_override("font_color", Color("#ffffff") if p.reloading else UI.GOLD)
	if ammo_icon != null:
		ammo_icon.modulate = Color(1.4, 1.4, 1.4, 1.0) if p.reloading else Color.WHITE
	if skill_tex != null:
		var cd_total := maxf(0.1, float(p.skill_data.get("cd", 10.0)))
		var frac := clampf(1.0 - p.skill_cd_left / cd_total, 0.0, 1.0)
		skill_tex.modulate = Color(1, 1, 1, 1.0 if frac >= 1.0 else 0.40)
	if skill_ring != null:
		skill_ring.queue_redraw()
	level_lbl.text = "УРОВЕНЬ %d" % game.level
	var xp_frac := clampf(float(game.xp) / maxf(1.0, float(game.xp_need)), 0.0, 1.0)
	xp_fill.size = Vector2(640.0 * xp_frac, 8)
	if game.mode == "endless":
		timer_lbl.text = UI.fmt_time(game.elapsed)
	else:
		timer_lbl.text = UI.fmt_time(maxf(0.0, float(game.wave_mgr.duration) - float(game.elapsed)))
	fps_lbl.text = "%s %d" % [Loc.t("fps"), Engine.get_frames_per_second()]
	if boss_box != null:
		var has_live_boss: bool = game != null and game.boss_enemy != null and is_instance_valid(game.boss_enemy) and bool(game.boss_enemy.active) and not bool(game.boss_enemy.dead) and float(game.boss_enemy.hp) > 0.0
		boss_box.visible = has_live_boss
		if has_live_boss:
			var b: Enemy = game.boss_enemy
			var bname := String(b.boss_def.get("name", "БОСС"))
			var ph_lbl := " · САТАН" if game.megaphase else (" · ФАЗА %d" % (b.phase + 1))
			boss_name.text = ("ФИНАЛЬНЫЙ БОСС: " if b.is_final else "БОСС: ") + bname + ph_lbl
			var bfrac := clampf(b.hp / maxf(1.0, b.max_hp), 0.0, 1.0)
			boss_fill.size = Vector2(300.0 * bfrac, 7)

## Дуга восстановления способности поверх пиксель-арт иконки.
func _draw_skill_ring() -> void:
	if skill_ring == null or game == null or game.player == null:
		return
	var p: Player = game.player
	var cd_total := maxf(0.1, float(p.skill_data.get("cd", 10.0)))
	var frac := clampf(1.0 - p.skill_cd_left / cd_total, 0.0, 1.0)
	var c := Vector2(9, 9)
	var pulse := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.004)
	if frac >= 1.0:
		skill_ring.draw_arc(c, 8.2, 0.0, TAU, 28, Color(0.65, 0.88, 1.0, 0.55 + 0.35 * pulse), 1.4)
	else:
		skill_ring.draw_arc(c, 7.6, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, Color(0.50, 0.82, 1.0, 0.9), 1.8)

## Сердца здоровья: крупные пиксель-арт рубиновые сердца через TextureRect.
func _sync_hearts(pl: Player) -> void:
	if hearts == null or pl == null:
		return
	var total: int = clampi(pl.max_hp, 1, 20)
	var sz := clampf(minf(20.0, 208.0 / float(total) - 1.5), 11.0, 20.0)
	var step := sz + 2.0
	var full_t := Assets.icon("ui_heart_full")
	var empty_t := Assets.icon("ui_heart_empty")
	while _heart_slots.size() < total:
		var tr := TextureRect.new()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hearts.add_child(tr)
		_heart_slots.append(tr)
	for i in _heart_slots.size():
		var tr: TextureRect = _heart_slots[i]
		if i >= total:
			tr.visible = false
			continue
		tr.visible = true
		tr.position = Vector2(step * float(i), 1.0)
		tr.size = Vector2(sz, sz)
		tr.texture = full_t if i < pl.hp else empty_t
		tr.modulate = Color(1.15, 0.85, 0.85) if (i < pl.hp and pl.hp <= 2) else Color.WHITE

# ------------------------------------------------------------------ ПАУЗА / КОНЕЦ
func toggle_pause() -> void:
	if end_layer.visible:
		return
	var now := not pause_layer.visible
	pause_layer.visible = now
	get_tree().paused = now
	if now:
		_refresh_pause_menu()
		AudioManager.play_sfx("ui", 0.9)

## Заполняет меню паузы: хронология перков и сводка по забегу.
func _refresh_pause_menu() -> void:
	if game == null or game.player == null:
		return
	UI.clear(pause_perk_list)
	var log: Array = game.player.upg.log
	var idx := 0
	for entry in log:
		idx += 1
		var kind := String(entry.get("kind", ""))
		var id := String(entry.get("id", ""))
		var data: Dictionary = _find_entry_data(kind, id)
		var nm := String(data.get("name", id))
		var mult := float(entry.get("mult", 1.0))
		var suffix := ""
		if mult > 1.0:
			suffix = " ×%d" % int(mult)
		var row := UI.label(pause_perk_list, "%2d. [%s] %s%s" % [idx, UI.kind_name(kind), nm, suffix], 8, UI.kind_color(kind))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(326, 0)
	if log.is_empty():
		UI.label(pause_perk_list, "Пока ничего не выбрано", 9, UI.DIM)
	var upg: UpgradeSystem = game.player.upg
	pause_perks_count.text = "всего %d" % log.size()

	UI.clear(pause_stats)
	var map_name := String(game.map_data.get("name", ""))
	var char_name := String(game.player.char_data.get("name", ""))
	var weapon_name := String(game.player.weapon.get("name", ""))
	var mode_names := {"standard": "Стандартный 30 мин", "quick": "Быстрый 10 мин", "endless": "Бесконечный", "coop": "Кооператив"}
	var mode_name := String(mode_names.get(String(game.mode), String(game.mode)))
	var total_time := float(game.elapsed)
	if game.mode != "endless":
		total_time = maxf(0.0, float(game.wave_mgr.duration) - float(game.elapsed))
	var rows := [
		["Карта", map_name],
		["Персонаж", char_name],
		["Оружие", "%s · ур. %d" % [weapon_name, game.player.weapon_level]],
		["Режим", mode_name],
		["Осталось", UI.fmt_time(total_time) if game.mode != "endless" else UI.fmt_time(float(game.elapsed))],
		["Уровень", str(game.level)],
		["Убийства", str(game.kills)],
		["Урон нанесён", str(int(game.damage_dealt))],
		["Урон получен", str(int(game.damage_taken))],
		["Золото", str(game.gold)],
		["Души", str(int(game.souls))],
		["Осколки", str(int(SaveManager.data.get("crystals", 0)))],
		["Перки", "%d · синергий %d" % [upg.taken.size(), upg.taken_synergies.size()]],
		["Тьма", str(int(GameManager.run_config.get("darkness", 1)))],
	]
	for pair in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(246, 9)
		var a := UI.label(row, String(pair[0]), 8, UI.DIM)
		a.custom_minimum_size = Vector2(96, 0)
		var b := UI.label(row, String(pair[1]), 8, UI.TEXT)
		b.custom_minimum_size = Vector2(140, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pause_stats.add_child(row)

## Ищет данные карточки по виду и id (для названия в списке паузы).
func _find_entry_data(kind: String, id: String) -> Dictionary:
	match kind:
		"perk":
			return DB.perk(id)
		"synergy":
			for syn in DB.synergies:
				if String(syn.get("id", "")) == id:
					return syn
		"seal":
			return DB.seal_by_id.get(id, {})
		"specialization":
			return DB.spec_by_id.get(id, {})
		"evolution":
			if game != null and game.player != null:
				var ev: Dictionary = game.player.upg.weapon_evolution
				if String(ev.get("id", "")) == id:
					return ev
		"char_upgrade":
			if game != null and game.player != null:
				for up in DB.character(String(game.player.char_data.get("id", ""))).get("upgrades", []):
					if String(up.get("id", "")) == id:
						return up
	return {}

## Выход из забега через паузу: сначала снимаем паузу.
func _pause_to_menu() -> void:
	get_tree().paused = false
	pause_layer.visible = false
	GameManager.goto_menu()

func show_end(results: Dictionary, win: bool, secret_win: bool) -> void:
	pause_layer.visible = false
	choice_layer.visible = false
	syn_layer.visible = false
	get_tree().paused = false
	end_layer.visible = true
	var panel: Panel = end_layer.get_child(1)
	UI.clear(panel)
	var title_txt := Loc.t("victory") if win else Loc.t("defeat")
	var accent := UI.GOLD if win else UI.DANGER
	if secret_win:
		title_txt = "СЕКРЕТНАЯ ПОБЕДА"
	# цветная полоса сверху панели
	var stripe := ColorRect.new()
	stripe.color = Color(accent.r, accent.g, accent.b, 0.85)
	stripe.position = Vector2(1, 1)
	stripe.size = Vector2(panel.size.x - 2, 2)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stripe)
	var title := UI.label(panel, title_txt, 20, accent, Vector2(18, 12))
	title.size = Vector2(panel.size.x - 36, 22)
	UI.label(panel, "итоги забега", 8, UI.MUTED, Vector2(19, 34))
	var lines := [
		[Loc.t("time"), UI.fmt_time(float(results.get("time", 0.0)))],
		[Loc.t("kills"), str(int(results.get("kills", 0)))],
		[Loc.t("damage_dealt"), str(int(results.get("damage_dealt", 0)))],
		[Loc.t("damage_taken"), str(int(results.get("damage_taken", 0)))],
		[Loc.t("level"), str(int(results.get("level", 1)))],
		[Loc.t("gold"), str(int(results.get("gold", 0)))],
		[Loc.t("souls"), str(int(results.get("souls", 0)))],
	]
	var y := 52
	for pair in lines:
		var row := HBoxContainer.new()
		row.position = Vector2(18, y)
		row.size = Vector2(panel.size.x - 36, 10)
		var a := UI.label(row, String(pair[0]), 9, UI.DIM)
		a.custom_minimum_size = Vector2(170, 0)
		var b := UI.label(row, String(pair[1]), 9, UI.TEXT)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.custom_minimum_size = Vector2(130, 0)
		panel.add_child(row)
		y += 14
	var buttons := UI.vbox(panel, 5)
	buttons.position = Vector2(18, y + 8)
	buttons.size = Vector2(panel.size.x - 36, 80)
	var retry := UI.primary_button(buttons, Loc.t("restart"), 10, Vector2(panel.size.x - 36, 24))
	retry.pressed.connect(func() -> void: GameManager.start_run(GameManager.run_config.duplicate()))
	var menu := UI.button(buttons, Loc.t("main_menu"), 10, Vector2(panel.size.x - 36, 22))
	menu.pressed.connect(func() -> void: GameManager.goto_menu())
	if GameManager.is_endless_unlocked() and not win:
		var endless := UI.button(buttons, Loc.t("continue_endless"), 9, Vector2(panel.size.x - 36, 22))
		endless.pressed.connect(_continue_endless)

func _continue_endless() -> void:
	var cfg: Dictionary = GameManager.run_config.duplicate()
	cfg["mode"] = "endless"
	GameManager.start_run(cfg)

func _toggle_synergies() -> void:
	if syn_layer.visible:
		syn_layer.visible = false
		return
	UI.clear(syn_list)
	if game == null or game.player == null:
		return
	var upg: UpgradeSystem = game.player.upg
	var shown := 0
	for entry in upg.log:
		var kind := String(entry.get("kind", ""))
		var id := String(entry.get("id", ""))
		var data: Dictionary = {}
		match kind:
			"perk": data = DB.perk(id)
			"char_upgrade":
				for up in DB.character(String(game.player.char_data.get("id", ""))).get("upgrades", []):
					if String(up["id"]) == id:
						data = up
			"seal": data = DB.seal_by_id.get(id, {})
			"specialization": data = DB.spec_by_id.get(id, {})
			"synergy":
				for syn in DB.synergies:
					if String(syn["id"]) == id:
						data = syn
		if data.is_empty():
			continue
		var row := UI.label(syn_list, "› [%s] %s — %s" % [UI.kind_name(kind), String(data.get("name", id)), String(data.get("desc", ""))], 8, UI.kind_color(kind))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(330, 0)
		shown += 1
	if shown == 0:
		UI.label(syn_list, Loc.t("no_synergies"), 9, UI.DIM)
	syn_layer.visible = true

# ------------------------------------------------------------------ СОБЫТИЯ
## Подтверждения о полученных перках не выводятся: по просьбе игрока
## всплывающие надписи поверх игры убраны. Список взятого — по клавише Tab.
func _on_upgrade_picked(_id: String, _kind: String) -> void:
	pass

func _on_notify(text: String) -> void:
	if text == "":
		return
	var l := UI.label(toast_box, text, 9, UI.TEXT)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 1.0))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(280, 0)
	# Таймер — дочерний узел HUD: умирает вместе с ним, поэтому лямбда
	# не может «выстрелить» в уже удалённую надпись после смены сцены.
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())
	timer.timeout.connect(timer.queue_free)
	timer.start()

func _on_boss_spawned(boss_name_txt: String, hp: float, is_final: bool) -> void:
	if game == null or game.boss_enemy == null or not is_instance_valid(game.boss_enemy) or not game.boss_enemy.active or game.boss_enemy.dead:
		boss_box.visible = false
		return
	boss_box.visible = hp > 0.0
	boss_name.text = ("ФИНАЛЬНЫЙ БОСС: " if is_final else "БОСС: ") + boss_name_txt + " · ФАЗА 1"
	boss_fill.size = Vector2(300, 7)

func _on_boss_defeated(_boss_name_txt: String) -> void:
	boss_box.visible = false

func _on_chest(kind: String) -> void:
	_on_notify("%s %s" % [Loc.t("chest"), kind])

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	if GameManager.cheat_open:
		return
	if _input_choice_hotkey(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		# Esc ставит бой на паузу в любой момент, кроме экранов выбора и конца забега
		if not end_layer.visible and not choice_layer.visible:
			toggle_pause()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("synergies"):
		# список взятого доступен и на паузе, но не поверх экрана выбора
		if not end_layer.visible and not choice_layer.visible:
			_toggle_synergies()
			get_viewport().set_input_as_handled()

func update_combo(value: int) -> void:
	if combo_lbl == null: return
	combo_lbl.visible = value >= 2
	combo_lbl.text = "×%d" % value if value >= 2 else ""
	if value >= 20: combo_lbl.add_theme_color_override("font_color", Color("#8f3524"))
	elif value >= 15: combo_lbl.add_theme_color_override("font_color", Color("#8f4a24"))
	elif value >= 10: combo_lbl.add_theme_color_override("font_color", Color("#95805a"))
	elif value >= 5: combo_lbl.add_theme_color_override("font_color", Color("#b8ac8b"))
	else: combo_lbl.add_theme_color_override("font_color", Color("#928d80"))

func update_boss_bar(hp: float, hp_max: float) -> void:
	if boss_box == null:
		return
	var has_live_boss: bool = game != null and game.boss_enemy != null and is_instance_valid(game.boss_enemy) and bool(game.boss_enemy.active) and not bool(game.boss_enemy.dead)
	boss_box.visible = has_live_boss and hp > 0.0
	if not boss_box.visible:
		return
	var frac := clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
	boss_fill.size = Vector2(300.0 * frac, 7)

## Служебная проверка раскладки: возвращает прямоугольники всех подписей HUD
## с учётом реальной ширины текста. Используется тестом SURW_HUD_TEST.
func layout_report() -> Array:
	var out: Array = []
	if root == null:
		return out
	var font: Font = ThemeDB.fallback_font
	for node in _all_children(root):
		if node is Label:
			var l: Label = node
			if l.text.strip_edges() == "":
				continue
			var fs := l.get_theme_font_size("font_size")
			var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var box: Vector2 = l.size
			var pos: Vector2 = l.global_position
			# учитываем выравнивание: проверяем реальные границы текста, а не весь Label
			match l.horizontal_alignment:
				HORIZONTAL_ALIGNMENT_RIGHT:
					pos.x += maxf(0.0, box.x - w)
				HORIZONTAL_ALIGNMENT_CENTER:
					pos.x += maxf(0.0, (box.x - w) * 0.5)
			out.append({"name": l.name + ":" + l.text.substr(0, 24), "rect": Rect2(pos, Vector2(w, float(fs) + 2.0))})
		elif node is Panel:
			var pn: Panel = node
			out.append({"name": pn.name + ":panel", "rect": Rect2(pn.global_position, pn.size)})
	return out

func _all_children(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		out.append(child)
		out.append_array(_all_children(child))
	return out

## Контур текста: HUD больше не использует панели, поэтому надписи должны
## читаться и на светлой земле, и на тёмных областях карты.
func _apply_outlines(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var l: Label = child
			l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 1.0))
			l.add_theme_constant_override("outline_size", 4)
		elif child is Panel:
			continue
		else:
			_apply_outlines(child)
