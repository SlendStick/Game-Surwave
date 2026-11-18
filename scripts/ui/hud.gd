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
var dark_overlay: Control
var target_arrows: Control
var dark_badge: Panel
var dark_icon: Control
var dark_lbl: Label
var cheat_banner: Panel
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label
var toast_box: VBoxContainer
var choice_layer: Control
var choice_title: Label
var choice_hint: Label
var choice_box: HBoxContainer
var choice_remove_btn: Button
var choice_remove_panel: Control
var choice_remove_list: VBoxContainer
var pause_layer: Control
var pause_confirm_layer: Control
var pause_confirm_lbl: Label
var pause_confirm_action := ""
var pause_settings_layer: Control
var pause_settings_list: VBoxContainer
var pause_perk_list: VBoxContainer
var pause_perks_count: Label
var pause_stats: VBoxContainer
var end_layer: Control
var syn_layer: Control
var syn_list: VBoxContainer
var current_cards: Array = []
var cheat_console: Node = null
# --- кооп: напарники, чат, эмоции
var party_box: VBoxContainer = null
var chat_box: VBoxContainer = null
var chat_input: LineEdit = null
var flash_lbl: Label = null
var flash_left := 0.0
var emote_wheel: Control = null
var emote_buttons: Array = []
var emote_open := false
var emote_pick := -1
var chat_lines: Array = []
const EMOTES := ["ПРИВЕТ", "ПОМОГИ", "ИДУ", "ОПАСНО", "СПАСИБО", "ХА-ХА"]

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

	# --- экранный слой Тьмы и виньетки (под всем HUD)
	dark_overlay = Control.new()
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_overlay.draw.connect(_draw_darkness_fx)
	root.add_child(dark_overlay)

	# --- стрелочки к сундукам, боссам и мини-боссам
	target_arrows = Control.new()
	target_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	target_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_arrows.draw.connect(_draw_target_arrows)
	root.add_child(target_arrows)

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

	# --- индикатор уровня Тьмы (справа под таймером)
	dark_badge = Panel.new()
	dark_badge.position = Vector2(582, 36)
	dark_badge.size = Vector2(52, 14)
	dark_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_badge.visible = false
	root.add_child(dark_badge)
	dark_icon = Control.new()
	dark_icon.position = Vector2(3, 2)
	dark_icon.size = Vector2(10, 10)
	dark_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_icon.draw.connect(_draw_dark_icon)
	dark_badge.add_child(dark_icon)
	dark_lbl = UI.label(dark_badge, "", 8, UI.TEXT, Vector2(14, 1))
	dark_lbl.size = Vector2(35, 12)
	dark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	combo_lbl = UI.label(root, "", 12, Color("#cbc6ba"), Vector2(564, 52))
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

	# --- низ: плашка предупреждения о читах + FPS
	cheat_banner = Panel.new()
	cheat_banner.position = Vector2(100, 338)
	cheat_banner.size = Vector2(440, 17)
	cheat_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cheat_banner.add_theme_stylebox_override("panel", UI.style(Color(0.22, 0.04, 0.04, 0.92), UI.DANGER, 1, 0))
	cheat_banner.visible = GameManager.cheat_used
	root.add_child(cheat_banner)
	var cheat_lbl := UI.crisp_label(cheat_banner, "⚠ ИСПОЛЬЗОВАНЫ ЧИТЫ — ПРОГРЕСС НЕ БУДЕТ СОХРАНЁН", 8, Color("#ffd4c8"), Vector2(4, 2))
	cheat_lbl.size = Vector2(432, 13)
	cheat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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

	_build_coop_ui()
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
	GameManager.cheat_state_changed.connect(_on_cheat_state_changed)
	_sync_darkness_badge()

# ------------------------------------------------------------------ КООП-ИНТЕРФЕЙС
## Панель напарников, чат, всплывающие сообщения и колесо эмоций (Q).
func _build_coop_ui() -> void:
	party_box = VBoxContainer.new()
	party_box.position = Vector2(6, 44)
	party_box.size = Vector2(168, 60)
	party_box.add_theme_constant_override("separation", 2)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(party_box)

	flash_lbl = UI.label(root, "", 13, Color(1.0, 0.95, 0.8), Vector2(0, 70))
	flash_lbl.size = Vector2(640, 18)
	flash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_lbl.modulate.a = 0.0
	flash_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	chat_box = VBoxContainer.new()
	chat_box.position = Vector2(6, 286)
	chat_box.size = Vector2(320, 62)
	chat_box.add_theme_constant_override("separation", 1)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chat_box)

	chat_input = LineEdit.new()
	chat_input.position = Vector2(150, 330)
	chat_input.size = Vector2(340, 18)
	chat_input.max_length = 120
	chat_input.placeholder_text = "Сообщение…"
	chat_input.add_theme_font_override("font", UI.crisp_font())
	chat_input.add_theme_font_size_override("font_size", 8)
	chat_input.visible = false
	chat_input.text_submitted.connect(_on_chat_submitted)
	root.add_child(chat_input)

	emote_wheel = Control.new()
	emote_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	emote_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emote_wheel.visible = false
	root.add_child(emote_wheel)
	for i in EMOTES.size():
		var ang := -PI * 0.5 + TAU * float(i) / float(EMOTES.size())
		var b := UI.button(emote_wheel, String(EMOTES[i]), 8, Vector2(58, 18))
		b.position = Vector2(320.0 + cos(ang) * 74.0 - 29.0, 172.0 + sin(ang) * 52.0 - 9.0)
		var idx := i
		b.pressed.connect(func() -> void: _pick_emote(idx))
		emote_buttons.append(b)

func _on_chat_submitted(text: String) -> void:
	chat_input.visible = false
	chat_input.release_focus()
	if game != null and game.has_method("send_chat"):
		game.send_chat(text)

## Открыть строку чата (Enter в коопе).
func open_chat() -> void:
	if game == null or not bool(game.get("net_active")):
		return
	chat_input.visible = true
	chat_input.text = ""
	chat_input.grab_focus()

## Строка чата в списке; чужие реплики — другим цветом.
func push_chat(who: String, text: String, mine: bool = false) -> void:
	var col := Color(0.95, 0.88, 0.62) if mine else Color(0.72, 0.9, 1.0)
	var row := UI.label(chat_box, "%s: %s" % [who, text], 8, col)
	row.custom_minimum_size = Vector2(320, 11)
	row.clip_text = true
	chat_lines.append({"node": row, "t": 0.0})
	while chat_lines.size() > 5:
		var first: Dictionary = chat_lines.pop_front()
		var n: Label = first["node"]
		if n != null and is_instance_valid(n):
			n.queue_free()

## Крупное сообщение по центру («Вы пали», «Возрождение»).
func flash_message(text: String, color: Color = Color(1.0, 0.95, 0.8)) -> void:
	if flash_lbl == null:
		return
	flash_lbl.text = text
	flash_lbl.add_theme_color_override("font_color", color)
	flash_lbl.modulate.a = 1.0
	flash_left = 2.6

func _tick_coop_ui(delta: float) -> void:
	if flash_left > 0.0:
		flash_left -= delta
		if flash_lbl != null:
			flash_lbl.modulate.a = clampf(flash_left / 1.2, 0.0, 1.0)
	for entry in chat_lines:
		entry["t"] = float(entry["t"]) + delta
		var n: Label = entry["node"]
		if n != null and is_instance_valid(n):
			n.modulate.a = clampf((14.0 - float(entry["t"])) / 3.0, 0.0, 1.0)

## Панель напарников: имя, здоровье и их перки (в коопе видно, кто что взял).
func _refresh_party() -> void:
	if party_box == null or game == null:
		return
	var infos: Array = []
	if game.has_method("partner_info"):
		infos = game.partner_info()
	if infos.is_empty():
		if party_box.get_child_count() > 0:
			for ch in party_box.get_children():
				ch.queue_free()
		return
	while party_box.get_child_count() < infos.size():
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(168, 26)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UI.label(holder, "", 8, Color(0.75, 0.93, 1.0), Vector2(0, 0))
		nm.size = Vector2(120, 11)
		var bar_back := ColorRect.new()
		bar_back.color = Color(0.05, 0.05, 0.07, 0.9)
		bar_back.position = Vector2(0, 11)
		bar_back.size = Vector2(74, 6)
		bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bar_back)
		var bar := ColorRect.new()
		bar.color = Color(0.45, 0.9, 1.0)
		bar.position = Vector2(1, 12)
		bar.size = Vector2(72, 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bar)
		var perks := UI.label(holder, "", 7, Color(0.8, 0.78, 0.86), Vector2(0, 17))
		perks.size = Vector2(168, 9)
		perks.clip_text = true
		party_box.add_child(holder)
	for i in party_box.get_child_count():
		var holder: Control = party_box.get_child(i)
		if i >= infos.size():
			holder.visible = false
			continue
		holder.visible = true
		var info: Dictionary = infos[i]
		var frac := clampf(float(info.get("hp", 0)) / maxf(1.0, float(info.get("max", 1))), 0.0, 1.0)
		var nm: Label = holder.get_child(0)
		nm.text = ("☠ " if bool(info.get("dead", false)) else "") + String(info.get("name", "Напарник"))
		var bar: ColorRect = holder.get_child(2)
		bar.size = Vector2(72.0 * frac, 4)
		bar.color = Color(0.45, 0.9, 1.0) if frac > 0.35 else Color(1.0, 0.5, 0.45)
		var perks: Label = holder.get_child(3)
		var names: Array = []
		if game.has_method("partner_perk_names"):
			names = game.partner_perk_names()
		perks.text = " · ".join(names.slice(maxi(0, names.size() - 3)))

## Колесо эмоций (удержание Q). Отпускание отправляет выбранную эмоцию.
func open_emote_wheel() -> void:
	if game == null or not bool(game.get("net_active")) or emote_wheel == null:
		return
	emote_open = true
	emote_pick = -1
	emote_wheel.visible = true
	_hover_emote()

func close_emote_wheel(send: bool) -> void:
	if not emote_open:
		return
	emote_open = false
	emote_wheel.visible = false
	if send and emote_pick >= 0 and emote_pick < EMOTES.size() and game != null and game.has_method("send_emote"):
		game.send_emote(String(EMOTES[emote_pick]))
	emote_pick = -1

func _hover_emote() -> void:
	if emote_wheel == null:
		return
	var m := get_viewport().get_mouse_position()
	var c := Vector2(320, 172)
	var d := m - c
	if d.length() < 14.0:
		emote_pick = -1
	else:
		var ang := fposmod(d.angle() + PI * 0.5, TAU)
		emote_pick = int(floor(ang / (TAU / float(EMOTES.size())))) % EMOTES.size()
	for i in emote_buttons.size():
		var b: Button = emote_buttons[i]
		b.modulate = Color(1.25, 1.15, 0.8) if i == emote_pick else Color(1, 1, 1, 0.9)

func _pick_emote(idx: int) -> void:
	emote_pick = idx
	close_emote_wheel(true)

func _input(event: InputEvent) -> void:
	if game == null or not bool(game.get("net_active")):
		return
	if chat_input != null and chat_input.visible:
		if event.is_action_pressed("pause"):
			chat_input.visible = false
			chat_input.release_focus()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("chat"):
		if (choice_layer != null and choice_layer.visible) or (pause_layer != null and pause_layer.visible) or (end_layer != null and end_layer.visible):
			return
		open_chat()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("emote"):
		open_emote_wheel()
		return
	if event.is_action_released("emote"):
		close_emote_wheel(true)
		return
	if emote_open and event is InputEventMouseMotion:
		_hover_emote()
		return
	if emote_open and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_6:
			_pick_emote(k - KEY_1)
			get_viewport().set_input_as_handled()

func setup(g: Node) -> void:
	game = g
	_setup_cheat_console()
	_sync_darkness_badge()
	if dark_overlay != null:
		dark_overlay.queue_redraw()

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
	choice_title = UI.label(choice_layer, "", 14, UI.GOLD, Vector2(0, 10))
	choice_title.size = Vector2(640, 18)
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_hint = UI.label(choice_layer, "ЛКМ — выбрать · игра на паузе", 8, UI.MUTED, Vector2(0, 29))
	choice_hint.size = Vector2(640, 12)
	choice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box = HBoxContainer.new()
	choice_box.position = Vector2(10, 44)
	choice_box.size = Vector2(620, 282)
	choice_box.add_theme_constant_override("separation", 6)
	choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_layer.add_child(choice_box)

	choice_remove_btn = UI.button(choice_layer, "УБРАТЬ ПЕРК (ЗА УРОВЕНЬ)", 8, Vector2(210, 22))
	choice_remove_btn.position = Vector2(215, 330)
	choice_remove_btn.visible = false
	choice_remove_btn.pressed.connect(_open_choice_remove_panel)

	choice_remove_panel = Control.new()
	choice_remove_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_remove_panel.visible = false
	choice_layer.add_child(choice_remove_panel)
	_dim(choice_remove_panel)
	var rpanel := UI.panel_striped(choice_remove_panel, Rect2(100, 32, 440, 296), UI.DANGER)
	var rtitle := UI.title(rpanel, "УБРАТЬ ПРИОБРЕТЁННЫЙ ПЕРК", 12, Vector2(12, 8), UI.GOLD_BRIGHT)
	rtitle.size = Vector2(416, 18)
	rtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rsub := UI.crisp_label(rpanel, "Убирает 1 уровень выбранного перка в счёт текущего повышения уровня", 8, UI.DIM, Vector2(12, 26))
	rsub.size = Vector2(416, 12)
	rsub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rscroll := ScrollContainer.new()
	rscroll.position = Vector2(12, 42)
	rscroll.size = Vector2(416, 212)
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rpanel.add_child(rscroll)
	choice_remove_list = VBoxContainer.new()
	choice_remove_list.custom_minimum_size = Vector2(404, 0)
	choice_remove_list.add_theme_constant_override("separation", 4)
	rscroll.add_child(choice_remove_list)
	var rcancel := UI.button(rpanel, "ОТМЕНА", 9, Vector2(120, 24))
	rcancel.position = Vector2(160, 262)
	rcancel.pressed.connect(func() -> void: choice_remove_panel.visible = false)

## Меню паузы: готическая сводка билда и характеристик забега.
func _build_pause_layer() -> void:
	pause_layer = Control.new()
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.visible = false
	root.add_child(pause_layer)
	_dim(pause_layer)

	var header := UI.panel_striped(pause_layer, Rect2(14, 10, 612, 34), UI.GOLD)
	var crest := TextureRect.new()
	crest.texture = Assets.icon("ui_crest")
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.position = Vector2(10, 6)
	crest.size = Vector2(22, 22)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(crest)
	var title := UI.title(header, Loc.t("paused"), 15, Vector2(38, 4), UI.GOLD_BRIGHT)
	title.size = Vector2(200, 22)
	var hint := UI.crisp_label(header, "Esc — продолжить · Tab — древо билда · F12 / P — фото", 8, UI.DIM, Vector2(246, 11))
	hint.size = Vector2(354, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- левая колонка: хроника билда с иконками
	var left := UI.panel_striped(pause_layer, Rect2(14, 48, 346, 268), UI.ACCENT)
	UI.crisp_label(left, "ХРОНИКА БИЛДА", 9, UI.GOLD_BRIGHT, Vector2(10, 8))
	pause_perks_count = UI.crisp_label(left, "", 8, UI.DIM, Vector2(190, 9))
	pause_perks_count.size = Vector2(146, 12)
	pause_perks_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 25)
	scroll.size = Vector2(330, 235)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	pause_perk_list = VBoxContainer.new()
	pause_perk_list.custom_minimum_size = Vector2(322, 0)
	pause_perk_list.add_theme_constant_override("separation", 3)
	scroll.add_child(pause_perk_list)

	# --- правая колонка: сводка забега + кнопки
	var right := UI.panel_striped(pause_layer, Rect2(368, 48, 258, 174), UI.GOLD_DEEP)
	UI.crisp_label(right, "СВОДКА ЗАБЕГА", 9, UI.GOLD_BRIGHT, Vector2(10, 6))
	pause_stats = VBoxContainer.new()
	pause_stats.position = Vector2(10, 21)
	pause_stats.size = Vector2(238, 148)
	pause_stats.clip_contents = true
	pause_stats.add_theme_constant_override("separation", 0)
	right.add_child(pause_stats)

	var buttons := UI.vbox(pause_layer, 2)
	buttons.position = Vector2(368, 226)
	buttons.size = Vector2(258, 92)
	var resume := UI.primary_button(buttons, Loc.t("resume"), 9, Vector2(258, 18))
	resume.pressed.connect(toggle_pause)
	var settings_btn := UI.button(buttons, Loc.t("settings"), 8, Vector2(258, 16))
	settings_btn.pressed.connect(_open_pause_settings)
	var restart := UI.button(buttons, Loc.t("restart"), 8, Vector2(258, 16))
	restart.pressed.connect(func() -> void: _open_pause_confirm("restart", "Начать забег заново? Весь текущий прогресс раунда будет сброшен."))
	var to_menu := UI.button(buttons, Loc.t("main_menu"), 8, Vector2(258, 16))
	to_menu.pressed.connect(func() -> void: _open_pause_confirm("menu", "Выйти в главное меню? Текущий забег не будет сохранён."))
	var quit := UI.button(buttons, Loc.t("quit"), 8, Vector2(258, 16))
	quit.pressed.connect(func() -> void: _open_pause_confirm("quit", "Выйти из игры?"))

	var foot := UI.crisp_label(pause_layer, "Пробел — автоприцел · R — перезарядка · ПКМ/Q — способность · 1–5 — выбор карты", 7, UI.MUTED, Vector2(0, 322))
	foot.size = Vector2(640, 12)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- модальное окно настроек в паузе
	pause_settings_layer = Control.new()
	pause_settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_settings_layer.visible = false
	pause_layer.add_child(pause_settings_layer)
	_dim(pause_settings_layer)
	var spanel := UI.panel_striped(pause_settings_layer, Rect2(140, 44, 360, 272), UI.GOLD)
	var stitle := UI.title(spanel, Loc.t("settings"), 14, Vector2(12, 8), UI.GOLD_BRIGHT)
	stitle.size = Vector2(336, 20)
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_settings_list = UI.vbox(spanel, 6)
	pause_settings_list.position = Vector2(18, 36)
	pause_settings_list.size = Vector2(324, 196)
	var sback := UI.primary_button(spanel, Loc.t("back"), 9, Vector2(120, 24))
	sback.position = Vector2(120, 238)
	sback.pressed.connect(func() -> void: pause_settings_layer.visible = false)

	# --- модальное подтверждение для "Рестарт" / "Главное меню" / "Выйти"
	pause_confirm_layer = Control.new()
	pause_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_confirm_layer.visible = false
	pause_layer.add_child(pause_confirm_layer)
	_dim(pause_confirm_layer)
	var cpanel := UI.panel_striped(pause_confirm_layer, Rect2(170, 118, 300, 124), UI.GOLD)
	var ctitle := UI.title(cpanel, "ПОДТВЕРЖДЕНИЕ", 13, Vector2(12, 10), UI.GOLD_BRIGHT)
	ctitle.size = Vector2(276, 18)
	ctitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_confirm_lbl = UI.crisp_label(cpanel, "", 9, UI.TEXT, Vector2(16, 36))
	pause_confirm_lbl.size = Vector2(268, 44)
	pause_confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_confirm_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var crow := UI.hbox(cpanel, 10)
	crow.position = Vector2(40, 88)
	crow.size = Vector2(220, 24)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes_btn := UI.primary_button(crow, "ДА", 9, Vector2(100, 24))
	yes_btn.pressed.connect(_confirm_pause_action)
	var no_btn := UI.button(crow, "ОТМЕНА", 9, Vector2(100, 24))
	no_btn.pressed.connect(func() -> void: pause_confirm_layer.visible = false)

func _build_end_layer() -> void:
	end_layer = Control.new()
	end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.visible = false
	root.add_child(end_layer)
	_dim(end_layer)
	UI.panel_striped(end_layer, Rect2(88, 28, 464, 304), UI.GOLD)

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
func open_choice(cards: Array, title: String, kind_name: String) -> void:
	current_cards = cards
	UI.clear(choice_box)
	choice_title.text = title
	if choice_remove_panel != null:
		choice_remove_panel.visible = false
	var can_remove: bool = kind_name == "perk" and game != null and game.player != null and not game.player.upg.taken.is_empty()
	if choice_remove_btn != null:
		choice_remove_btn.visible = can_remove
		choice_remove_btn.text = "УБРАТЬ ПЕРК (ЗА УРОВЕНЬ) · %d" % game.player.upg.taken.size() if can_remove else "УБРАТЬ ПЕРК (ЗА УРОВЕНЬ)"
	var card_w := 118.0
	if cards.size() <= 3:
		card_w = 186.0
	elif cards.size() == 4:
		card_w = 148.0
	var card_h := 278.0 if can_remove else 296.0
	choice_box.size = Vector2(620, card_h + 4.0)
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
	var data: Dictionary = card.get("data", {})
	var cid := String(card.get("id", ""))
	var tex := Assets.icon("illus_" + cid)
	if tex != null:
		return tex
	if kind == "evolution":
		return Assets.icon("illus_evolution")
	if kind == "specialization":
		var pid := String(data.get("perk_id", ""))
		if pid != "":
			var ptex := Assets.icon("illus_" + pid)
			if ptex != null:
				return ptex
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
	if kind == "specialization":
		var tname := String(data.get("tree_name", ""))
		if tname != "":
			return "%s · ×3" % tname
		return "T%d · ×3" % int(data.get("tier", 1))
	return ""

func _format_spec_mods(mods: Dictionary) -> String:
	if mods.is_empty():
		return ""
	const STAT_NAMES := {
		"dmg": "урон", "fire_rate": "скорострельность", "proj_speed": "скорость пуль",
		"reload": "перезарядка", "move_speed": "скорость бега", "pickup": "радиус сбора",
		"vision": "обзор", "knockback": "отбрасывание", "size": "размер",
		"summon_dmg": "урон призыва", "summon_speed": "скорость призыва", "xp": "опыт",
		"hp": "макс. HP", "mag": "патроны в обойме", "proj": "снарядов",
		"pierce": "пробитие", "bounce": "рикошет", "summon_count": "призывов",
		"dodge": "уклонение", "crit": "шанс крита", "armor_pierce": "пробитие брони",
		"shock_dmg": "урон молнии", "shock_radius": "радиус молнии",
		"burn_mult": "урон горения", "burn_dur": "длительность горения",
		"freeze_chance": "шанс заморозки", "curse_chance": "шанс проклятия",
		"spread": "разброс",
	}
	var lines: Array = []
	for k in mods.keys():
		var key := String(k)
		var v := float(mods[k])
		var label_name := String(STAT_NAMES.get(key, key))
		if key in ["hp", "mag", "proj", "pierce", "bounce", "summon_count", "shock_dmg", "spread"]:
			var sign := "+" if v >= 0.0 else ""
			lines.append("%s%d %s" % [sign, int(round(v)), label_name])
		else:
			var pct := int(round(v * 100.0))
			var sign2 := "+" if pct >= 0 else ""
			lines.append("%s%d%% %s" % [sign2, pct, label_name])
	return "\n".join(lines)

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
	var hdr2_txt := "ЭФФЕКТ И УСЛОВИЯ"
	if kind == "specialization":
		hdr2_txt = "МАСТЕРСТВО: " + String(data.get("tree_name", "ВЕТВЬ")).to_upper()
	var hdr2 := UI.crisp_label(wrap, hdr2_txt, 8, UI.GOLD_BRIGHT, Vector2(6, 5))
	hdr2.size = Vector2(width - 12, 12)
	hdr2.clip_text = true
	hdr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_txt := _card_meta(card)
	if kind == "specialization":
		var mod_lines := _format_spec_mods(data.get("mods", {}))
		var p_flags: Dictionary = data.get("flags", {})
		var parts: Array = []
		if mod_lines != "":
			parts.append(mod_lines)
		if not p_flags.is_empty():
			var pid := String(data.get("perk_id", ""))
			var pdata: Dictionary = DB.perk(pid)
			var pdesc := String(pdata.get("desc", ""))
			if pdesc != "":
				parts.append("Дар: " + pdesc)
		parts.append("Следующий перк: ×3 эффект")
		body_txt = "\n".join(parts)
	else:
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
			var tree_id := String(data.get("tree", ""))
			if tree_id != "":
				var t_ico := Assets.icon("icon_tree_" + tree_id)
				if t_ico != null:
					return t_ico
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
			var tname := String(data.get("tree_name", ""))
			if tname != "":
				return "Специализация · %s" % tname
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
	_tick_coop_ui(delta)
	if game == null or game.player == null:
		return
	if bool(game.get("net_active")):
		_refresh_party()
	_refresh(delta)
	if target_arrows != null:
		target_arrows.queue_redraw()

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
	ammo_lbl.visible = corner
	if int(_last_hp) != p.hp or int(_last_max_hp) != p.max_hp:
		_last_hp = p.hp
		_last_max_hp = p.max_hp
		_sync_hearts(p)
	hp_lbl.text = "★" if p.shield_charges > 0 else ""
	hp_lbl.visible = corner and p.shield_charges > 0
	if cheat_banner != null:
		cheat_banner.visible = GameManager.cheat_used
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
	# Кооп: пауза общая, ей управляет хост (клиент не морозит мир сам).
	if game != null and bool(game.get("net_active")):
		game.net_toggle_pause()
		AudioManager.play_sfx("ui", 0.9)
		return
	if game != null and game.photo_mode:
		game.set_photo_mode(false)
		if not pause_layer.visible:
			pause_layer.visible = true
			game.sync_pause_state()
			_refresh_pause_menu()
			AudioManager.play_sfx("ui", 0.9)
		return
	if pause_confirm_layer != null and pause_confirm_layer.visible:
		pause_confirm_layer.visible = false
		return
	if pause_settings_layer != null and pause_settings_layer.visible:
		pause_settings_layer.visible = false
		return
	var now := not pause_layer.visible
	pause_layer.visible = now
	if game != null and game.has_method("sync_pause_state"):
		game.sync_pause_state()
	else:
		get_tree().paused = now
	if now:
		_refresh_pause_menu()
		AudioManager.play_sfx("ui", 0.9)

func _open_choice_remove_panel() -> void:
	if choice_remove_panel == null or choice_remove_list == null or game == null or game.player == null:
		return
	UI.clear(choice_remove_list)
	var upg: UpgradeSystem = game.player.upg
	for pid_v in upg.taken.keys():
		var pid := String(pid_v)
		var stacks := int(upg.taken.get(pid, 0))
		if stacks <= 0:
			continue
		var data: Dictionary = DB.perk(pid)
		var tier := int(data.get("tier", 1))
		var row := UI.panel(choice_remove_list, Rect2(0, 0, 396, 36), Color("#101218"), UI.BORDER)
		row.custom_minimum_size = Vector2(396, 36)
		var ico := Assets.icon("icon_tree_" + String(data.get("tree", "")))
		if ico != null:
			var tr := TextureRect.new()
			tr.texture = ico
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(6, 8)
			tr.size = Vector2(20, 20)
			row.add_child(tr)
		var nm := UI.crisp_label(row, "%s (T%d · ×%d)" % [String(data.get("name", pid)), tier, stacks], 9, UI.GOLD_BRIGHT, Vector2(32, 3))
		nm.size = Vector2(276, 13)
		var ds := UI.crisp_label(row, String(data.get("desc", "")), 7, UI.DIM, Vector2(32, 17))
		ds.size = Vector2(276, 15)
		ds.clip_text = true
		var rem_btn := UI.button(row, "УБРАТЬ", 8, Vector2(76, 22))
		rem_btn.position = Vector2(314, 7)
		rem_btn.pressed.connect(func() -> void:
			choice_remove_panel.visible = false
			AudioManager.play_sfx("ui", 0.75)
			game.remove_perk_for_level(pid, false))
	choice_remove_panel.visible = true
	AudioManager.play_sfx("ui", 0.95)

func _open_pause_settings() -> void:
	if pause_settings_layer == null or pause_settings_list == null:
		return
	_rebuild_pause_settings()
	pause_settings_layer.visible = true
	AudioManager.play_sfx("ui", 0.95)

func _rebuild_pause_settings() -> void:
	UI.clear(pause_settings_list)
	_ps_slider("Громкость музыки", float(GameManager.setting("music", 0.8)), func(v: float) -> void:
		GameManager.set_setting("music", v)
		AudioManager.apply_settings(v, float(GameManager.setting("sfx", 0.8))))
	_ps_slider("Громкость эффектов", float(GameManager.setting("sfx", 0.8)), func(v: float) -> void:
		GameManager.set_setting("sfx", v)
		AudioManager.apply_settings(float(GameManager.setting("music", 0.8)), v))
	_ps_toggle("Тряска экрана", bool(GameManager.setting("shake", true)), func() -> void:
		GameManager.set_setting("shake", not bool(GameManager.setting("shake", true)))
		_rebuild_pause_settings())
	_ps_toggle("Пост-эффекты", bool(GameManager.setting("post_fx", true)), func() -> void:
		GameManager.set_setting("post_fx", not bool(GameManager.setting("post_fx", true)))
		_rebuild_pause_settings())
	_ps_toggle("Слоу-мо боссов", bool(GameManager.setting("slowmo", true)), func() -> void:
		GameManager.set_setting("slowmo", not bool(GameManager.setting("slowmo", true)))
		_rebuild_pause_settings())
	var cur_vitals := String(GameManager.setting("hud_vitals", "corner"))
	_ps_choice("HP и патроны", "Слева сверху" if cur_vitals == "corner" else "Над героем", func() -> void:
		GameManager.set_setting("hud_vitals", "player" if cur_vitals == "corner" else "corner")
		_rebuild_pause_settings())
	var cur_lang := String(GameManager.setting("lang", "ru"))
	_ps_choice("Язык / Language", cur_lang.to_upper(), func() -> void:
		GameManager.set_setting("lang", "en" if cur_lang == "ru" else "ru")
		_rebuild_pause_settings())

func _ps_slider(label_txt: String, val: float, cb: Callable) -> void:
	var row := UI.hbox(pause_settings_list, 8)
	row.custom_minimum_size = Vector2(324, 22)
	var lbl := UI.crisp_label(row, label_txt, 8, UI.TEXT)
	lbl.custom_minimum_size = Vector2(148, 18)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = val
	sl.custom_minimum_size = Vector2(130, 18)
	row.add_child(sl)
	var pct := UI.crisp_label(row, "%d%%" % int(round(val * 100.0)), 8, UI.GOLD_BRIGHT)
	pct.custom_minimum_size = Vector2(34, 18)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sl.value_changed.connect(func(nv: float) -> void:
		pct.text = "%d%%" % int(round(nv * 100.0))
		cb.call(nv))

func _ps_toggle(label_txt: String, on: bool, cb: Callable) -> void:
	_ps_choice(label_txt, "ВКЛ" if on else "ВЫКЛ", cb)

func _ps_choice(label_txt: String, val_txt: String, cb: Callable) -> void:
	var row := UI.hbox(pause_settings_list, 8)
	row.custom_minimum_size = Vector2(324, 22)
	var lbl := UI.crisp_label(row, label_txt, 8, UI.TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn := UI.button(row, val_txt, 8, Vector2(116, 20))
	btn.pressed.connect(cb)

func _open_pause_confirm(action_id: String, msg: String) -> void:
	pause_confirm_action = action_id
	if pause_confirm_lbl != null:
		pause_confirm_lbl.text = msg
	if pause_confirm_layer != null:
		pause_confirm_layer.visible = true
	AudioManager.play_sfx("ui", 0.95)

func _confirm_pause_action() -> void:
	if pause_confirm_layer != null:
		pause_confirm_layer.visible = false
	match pause_confirm_action:
		"restart":
			get_tree().paused = false
			pause_layer.visible = false
			GameManager.start_run(GameManager.run_config.duplicate())
		"menu":
			_pause_to_menu()
		"quit":
			get_tree().quit()

## Заполняет меню паузы: хронология перков с иконками и сводка по забегу.
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
		var suffix := " ×%d" % int(mult) if mult > 1.0 else ""
		var col := UI.kind_color(kind)

		var lbl := UI.crisp_label(pause_perk_list, "%2d. [%s] %s%s" % [idx, UI.kind_name(kind), nm, suffix], 8, col)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(318, 16)
		lbl.add_theme_stylebox_override("normal", UI.style(Color(0.08, 0.085, 0.11, 0.85), Color(col.r, col.g, col.b, 0.35), 1, 0))
		var ico := _card_icon({"kind": kind, "id": id, "data": data})
		if ico != null:
			var tr := TextureRect.new()
			tr.texture = ico
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(262 if kind == "perk" else 300, 1)
			tr.size = Vector2(14, 14)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.add_child(tr)
		if kind == "perk" and int(game.player.upg.taken.get(id, 0)) > 0:
			var rem := UI.button(lbl, "-1 ур.", 7, Vector2(38, 14))
			rem.position = Vector2(280, 1)
			rem.disabled = game.level <= 1
			rem.tooltip_text = "Убрать перк за 1 уровень"
			rem.pressed.connect(func() -> void:
				if game.remove_perk_for_level(id, true):
					_refresh_pause_menu()
					AudioManager.play_sfx("ui", 0.75))
	if log.is_empty():
		UI.crisp_label(pause_perk_list, "Пока ничего не выбрано — повышайте уровень!", 8, UI.DIM)
	var upg: UpgradeSystem = game.player.upg
	pause_perks_count.text = "всего %d · синергий %d" % [log.size(), upg.taken_synergies.size()]

	UI.clear(pause_stats)
	var map_name := String(game.map_data.get("name", ""))
	var char_name := String(game.player.char_data.get("name", ""))
	var weapon_name := String(game.player.weapon.get("name", ""))
	var mode_names := {"standard": "Стандарт 30м", "quick": "Быстрый 10м", "endless": "Бесконечный", "coop": "Кооп"}
	var mode_name := String(mode_names.get(String(game.mode), String(game.mode)))
	var total_time := float(game.elapsed)
	if game.mode != "endless":
		total_time = maxf(0.0, float(game.wave_mgr.duration) - float(game.elapsed))
	var rows := [
		["Карта", map_name],
		["Герой", char_name],
		["Оружие", "%s · ур. %d" % [weapon_name, game.player.weapon_level]],
		["Режим", mode_name],
		["Время" if game.mode == "endless" else "Осталось", UI.fmt_time(total_time)],
		["Уровень", str(game.level)],
		["Убийства", str(game.kills)],
		["Урон / Крит", "%.0f · %d%%" % [game.player.current_damage(), int(round(float(game.player.S.crit) * 100.0))]],
		["Нанесено", str(int(game.damage_dealt))],
		["Получено", str(int(game.damage_taken))],
		["Золото / Души", "%d / %d" % [game.gold, int(game.souls)]],
		["Перки / Тьма", "%d · Т%d" % [upg.taken.size(), int(GameManager.run_config.get("darkness", 1))]],
	]
	for pair in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(238, 11)
		var a := UI.crisp_label(row, String(pair[0]), 7, UI.DIM)
		a.custom_minimum_size = Vector2(92, 0)
		var b := UI.crisp_label(row, String(pair[1]), 7, UI.TEXT)
		b.custom_minimum_size = Vector2(142, 0)
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
	AudioManager.stop_ambience()
	AudioManager.set_boss_layer(false)
	AudioManager.play_sfx("victory" if win else "defeat", 1.0)
	var panel: Panel = end_layer.get_child(1)
	UI.clear(panel)
	var title_txt := Loc.t("victory") if win else Loc.t("defeat")
	var sub_txt := "Владыка Тьмы повержен — рассвет наступил" if win else "Тьма поглотила странника..."
	var accent := UI.GOLD_BRIGHT if win else UI.DANGER
	if secret_win:
		title_txt = "ТАЙНАЯ ПОБЕДА"
		sub_txt = "Сам САТАНАИЛ пал в бездне Пустоты!"
		accent = Color("#d89bff")
	panel.set("accent", accent.darkened(0.25))
	panel.queue_redraw()

	# Верхняя цветная кайма и готический заголовок
	var stripe := ColorRect.new()
	stripe.color = Color(accent.r, accent.g, accent.b, 0.92)
	stripe.position = Vector2(3, 3)
	stripe.size = Vector2(panel.size.x - 6, 3)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stripe)

	# Портрет героя, герб и иконка оружия
	var hero_cls := String(game.player.char_data.get("cls", "paladin")) if (game != null and game.player != null) else "paladin"
	var w_id := String(game.player.weapon.get("id", "revolver")) if (game != null and game.player != null) else "revolver"
	var htex := Assets.icon("portrait_" + hero_cls)
	if htex == null:
		htex = Assets.icon(hero_cls)
	if htex != null:
		var hp_box := Panel.new()
		hp_box.position = Vector2(20, 14)
		hp_box.size = Vector2(46, 46)
		hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_box.add_theme_stylebox_override("panel", UI.style(Color("#0c0d12"), accent, 1, 0))
		panel.add_child(hp_box)
		var htr := TextureRect.new()
		htr.texture = htex
		htr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		htr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		htr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		htr.position = Vector2(3, 3)
		htr.size = Vector2(40, 40)
		htr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_box.add_child(htr)
	var wtex := Assets.icon("icon_weapon_" + w_id)
	if wtex != null:
		var wtr := TextureRect.new()
		wtr.texture = wtex
		wtr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wtr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wtr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wtr.position = Vector2(panel.size.x - 58, 16)
		wtr.size = Vector2(36, 36)
		wtr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(wtr)

	var title := UI.title(panel, title_txt, 22, Vector2(76, 12), accent)
	title.size = Vector2(panel.size.x - 144, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.crisp_label(panel, sub_txt, 8, UI.DIM, Vector2(76, 42))
	sub.size = Vector2(panel.size.x - 144, 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.divider(panel, Vector2(24, 64), panel.size.x - 48, accent.darkened(0.2))

	# Двухколоночная таблица итогов забега
	var map_name := String(game.map_data.get("name", "")) if (game != null and game.map_data is Dictionary) else ""
	var char_name := String(game.player.char_data.get("name", "")) if (game != null and game.player != null) else ""
	var perk_cnt := int(game.player.upg.taken.size()) if (game != null and game.player != null) else 0
	var syn_cnt := int(game.player.upg.taken_synergies.size()) if (game != null and game.player != null) else 0
	var left_lines := [
		["Карта", map_name],
		["Герой", char_name],
		[Loc.t("time"), UI.fmt_time(float(results.get("time", 0.0)))],
		[Loc.t("level"), str(int(results.get("level", 1)))],
		["Перки / Синергии", "%d / %d" % [perk_cnt, syn_cnt]],
	]
	var right_lines := [
		[Loc.t("kills"), str(int(results.get("kills", 0)))],
		[Loc.t("damage_dealt"), str(int(results.get("damage_dealt", 0)))],
		[Loc.t("damage_taken"), str(int(results.get("damage_taken", 0)))],
		[Loc.t("gold"), "+%d" % int(results.get("gold", 0))],
		[Loc.t("souls"), "+%d" % int(results.get("souls", 0))],
	]
	for col_idx in 2:
		var col_data: Array = left_lines if col_idx == 0 else right_lines
		var cx := 20.0 if col_idx == 0 else 238.0
		var box := UI.panel(panel, Rect2(cx, 78, 206, 128), Color("#0b0c11"), Color(0.28, 0.30, 0.36, 0.85))
		var cy := 10.0
		for pair in col_data:
			var a := UI.crisp_label(box, String(pair[0]), 8, UI.DIM, Vector2(10, cy))
			a.size = Vector2(96, 16)
			var val_col := UI.GOLD_BRIGHT if String(pair[0]) in [Loc.t("gold"), Loc.t("souls")] else UI.TEXT
			var b := UI.crisp_label(box, String(pair[1]), 9, val_col, Vector2(106, cy))
			b.size = Vector2(90, 16)
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cy += 22.0

	# Полоса иконок собранных синергий (если есть)
	if game != null and game.player != null and not game.player.upg.taken_synergies.is_empty():
		var sx := 24.0
		UI.crisp_label(panel, "СИНЕРГИИ:", 8, UI.GOLD, Vector2(22, 214))
		sx = 94.0
		for sid in game.player.upg.taken_synergies:
			var stex := Assets.icon("icon_" + String(sid))
			if stex != null:
				var str_ic := TextureRect.new()
				str_ic.texture = stex
				str_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				str_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				str_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				str_ic.position = Vector2(sx, 211)
				str_ic.size = Vector2(16, 16)
				panel.add_child(str_ic)
				sx += 20.0
				if sx > 420.0:
					break

	# Кнопки действий
	if bool(results.get("cheats_used", false)):
		var cw := UI.crisp_label(panel, "⚠ ЧИТЫ ИСПОЛЬЗОВАНЫ — ПРОГРЕСС НЕ СОХРАНЁН", 8, UI.DANGER, Vector2(20, 224))
		cw.size = Vector2(panel.size.x - 40, 14)
		cw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := UI.hbox(panel, 8)
	buttons.position = Vector2(20, 240)
	buttons.size = Vector2(panel.size.x - 40, 44)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := UI.primary_button(buttons, Loc.t("restart"), 10, Vector2(142, 28))
	retry.pressed.connect(func() -> void: GameManager.start_run(GameManager.run_config.duplicate()))
	if GameManager.is_endless_unlocked() and not win:
		var endless := UI.button(buttons, Loc.t("continue_endless"), 9, Vector2(150, 28))
		endless.pressed.connect(_continue_endless)
	var menu := UI.button(buttons, Loc.t("main_menu"), 10, Vector2(118, 28))
	menu.pressed.connect(func() -> void: GameManager.goto_menu())

func _continue_endless() -> void:
	var cfg: Dictionary = GameManager.run_config.duplicate()
	cfg["mode"] = "endless"
	GameManager.start_run(cfg)

func _toggle_synergies() -> void:
	if syn_layer.visible:
		syn_layer.visible = false
		if game != null and game.has_method("sync_pause_state"):
			game.sync_pause_state()
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
	if game != null and game.has_method("sync_pause_state"):
		game.sync_pause_state()

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
		if event.is_action_pressed("pause"):
			if cheat_console != null and cheat_console.has_method("close_all"):
				cheat_console.close_all()
			toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if _input_choice_hotkey(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if choice_remove_panel != null and choice_remove_panel.visible and not pause_layer.visible:
			choice_remove_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		# Esc ставит игру на паузу при любом открытом окне (кроме экрана конца забега)
		if not end_layer.visible:
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

func _on_cheat_state_changed(used: bool) -> void:
	if cheat_banner != null:
		cheat_banner.visible = used

func _darkness_tier_color(lvl: int) -> Color:
	if lvl >= 13:
		return UI.GOLD_BRIGHT
	if lvl >= 10:
		return Color("#e0525a")
	if lvl >= 7:
		return Color("#b8353b")
	if lvl >= 4:
		return Color("#9d64f0")
	return Color("#919aa5")

func _sync_darkness_badge() -> void:
	if dark_badge == null:
		return
	var lvl := int(GameManager.run_config.get("darkness", 1))
	if lvl <= 0:
		dark_badge.visible = false
		return
	dark_badge.visible = true
	var tier_col := _darkness_tier_color(lvl)
	var bg := Color(0.04, 0.03, 0.025, 0.88) if lvl >= 13 else (Color(0.27, 0.06, 0.08, 0.88) if lvl >= 10 else Color(0.05, 0.05, 0.07, 0.78))
	var border := UI.GOLD if lvl >= 13 else tier_col.darkened(0.15)
	dark_badge.add_theme_stylebox_override("panel", UI.style(bg, border, 1, 0))
	dark_lbl.text = "Т×%d" % lvl
	dark_lbl.add_theme_color_override("font_color", tier_col)
	if dark_icon != null:
		dark_icon.queue_redraw()

func _draw_dark_icon() -> void:
	if dark_icon == null:
		return
	var lvl := int(GameManager.run_config.get("darkness", 1))
	var c := _darkness_tier_color(lvl)
	dark_icon.draw_circle(Vector2(5, 5), 4.0, c)
	dark_icon.draw_circle(Vector2(6.8, 4.3), 3.0, Color(0.05, 0.05, 0.07, 1.0))

func _draw_darkness_fx() -> void:
	if dark_overlay == null:
		return
	var lvl := int(GameManager.run_config.get("darkness", 1))
	if lvl <= 0:
		return
	var w := dark_overlay.size.x
	var h := dark_overlay.size.y
	if w < 2.0:
		w = 640.0
		h = 360.0
	var base_alpha := minf(float(lvl) * 0.012, 0.18)
	dark_overlay.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.03, base_alpha))
	var vig_strength := minf(float(lvl) * 0.028, 0.36)
	for i in 8:
		var f := float(i) / 8.0
		var band := 5.0
		var a := vig_strength * (1.0 - f) * 0.32
		var vc := Color(0.01, 0.005, 0.02, a)
		dark_overlay.draw_rect(Rect2(0, float(i) * band, w, band), vc)
		dark_overlay.draw_rect(Rect2(0, h - float(i + 1) * band, w, band), vc)
		dark_overlay.draw_rect(Rect2(float(i) * band, 0, band, h), vc)
		dark_overlay.draw_rect(Rect2(w - float(i + 1) * band, 0, band, h), vc)

## Стрелки-указатели на сундуки, боссов и мини-боссов (за экраном или в тумане).
func _draw_target_arrows() -> void:
	if target_arrows == null or game == null or game.player == null or game.ended or game.photo_mode:
		return
	var cam_center: Vector2 = game.camera.get_screen_center_position() if game.camera != null else game.player.global_position
	var zoom_v: float = game.camera.zoom.x if game.camera != null else 1.35
	var center_screen := Vector2(320.0, 180.0)
	var p_screen: Vector2 = (game.player.global_position - cam_center) * zoom_v + center_screen
	var safe := Rect2(22.0, 50.0, 596.0, 286.0)
	var vis_r: float = game.current_vision_radius() if game.has_method("current_vision_radius") else 190.0
	var font := UI.font()
	var pulse := 0.72 + 0.28 * sin(float(Time.get_ticks_msec()) * 0.006)

	var targets: Array = []
	for e in game.enemies:
		if e == null or not is_instance_valid(e) or not e.active or e.dead:
			continue
		if e.boss:
			targets.append({"pos": e.global_position, "col": Color("#ff3a30"), "rim": Color("#ffd700"), "tag": "БОСС", "sz": 9.0})
		elif String(e.role) == "miniboss":
			targets.append({"pos": e.global_position, "col": Color("#c96bff"), "rim": Color("#ffe39a"), "tag": "М-БОСС", "sz": 7.5})
	for p in game.pickups:
		if p == null or not is_instance_valid(p) or not p.active:
			continue
		if String(p.kind) == "chest":
			targets.append({"pos": p.global_position, "col": Color("#ffd24c", pulse), "rim": Color("#fff5c8"), "tag": "СУНДУК", "sz": 7.5})

	for t in targets:
		var wpos: Vector2 = t["pos"]
		var spos: Vector2 = (wpos - cam_center) * zoom_v + center_screen
		var offscreen := not Rect2(14.0, 40.0, 612.0, 304.0).has_point(spos)
		var out_of_vision := wpos.distance_to(game.player.global_position) > vis_r * 0.94
		if not offscreen and not out_of_vision:
			continue
		var origin := center_screen if offscreen else p_screen
		var diff := spos - origin
		if diff.length() < 4.0:
			continue
		var dir := diff.normalized()
		var anchor := spos
		if offscreen:
			# Пересечение луча из центра экрана с безопасной рамкой HUD
			var tx := 1e9
			var ty := 1e9
			if absf(dir.x) > 0.0001:
				tx = ((safe.end.x if dir.x > 0.0 else safe.position.x) - origin.x) / dir.x
			if absf(dir.y) > 0.0001:
				ty = ((safe.end.y if dir.y > 0.0 else safe.position.y) - origin.y) / dir.y
			anchor = origin + dir * minf(tx, ty)
		else:
			# Цель в пределах экрана, но скрыта в тумане — ставим стрелку на границе обзора
			var edge_r := maxf(36.0, vis_r * zoom_v * 0.82)
			anchor = origin + dir * minf(diff.length() - 10.0, edge_r)
		anchor.x = clampf(anchor.x, safe.position.x, safe.end.x)
		anchor.y = clampf(anchor.y, safe.position.y, safe.end.y)

		var sz: float = float(t["sz"])
		var perp := Vector2(-dir.y, dir.x)
		var tip := anchor + dir * (sz * 1.15)
		var left_pt := anchor - dir * (sz * 0.75) + perp * (sz * 0.78)
		var right_pt := anchor - dir * (sz * 0.75) - perp * (sz * 0.78)
		var notch := anchor - dir * (sz * 0.35)
		var col: Color = t["col"]
		var rim: Color = t["rim"]
		target_arrows.draw_colored_polygon(PackedVector2Array([tip, left_pt, notch, right_pt]), col)
		target_arrows.draw_polyline(PackedVector2Array([tip, left_pt, notch, right_pt, tip]), rim, 1.3)
		if font != null:
			var tag_pos := anchor - dir * (sz * 1.8) + Vector2(-18.0, 3.0)
			tag_pos.x = clampf(tag_pos.x, 12.0, 588.0)
			tag_pos.y = clampf(tag_pos.y, 44.0, 344.0)
			target_arrows.draw_string(font, tag_pos + Vector2(1, 1), String(t["tag"]), HORIZONTAL_ALIGNMENT_CENTER, 36, 7, Color(0, 0, 0, 0.85))
			target_arrows.draw_string(font, tag_pos, String(t["tag"]), HORIZONTAL_ALIGNMENT_CENTER, 36, 7, rim)

	# --- прицел: свой, пиксельный, в стиле игры
	if bool(GameManager.setting("crosshair", true)) and not game.photo_mode:
		var mp := get_viewport().get_mouse_position()
		if Rect2(0, 0, 640, 360).has_point(mp):
			var cc := Color(0.86, 0.82, 0.66, 0.85)
			var gap := 3.0
			var ln := 4.0
			target_arrows.draw_line(mp + Vector2(gap, 0), mp + Vector2(gap + ln, 0), cc, 1.0, true)
			target_arrows.draw_line(mp - Vector2(gap, 0), mp - Vector2(gap + ln, 0), cc, 1.0, true)
			target_arrows.draw_line(mp + Vector2(0, gap), mp + Vector2(0, gap + ln), cc, 1.0, true)
			target_arrows.draw_line(mp - Vector2(0, gap), mp - Vector2(0, gap + ln), cc, 1.0, true)
			target_arrows.draw_rect(Rect2(mp - Vector2(1, 1), Vector2(2, 2)), Color(0.95, 0.72, 0.28, 0.9))

	# --- сетевой кооп: подпись режима и стрелки к напарникам
	if game.net_active and game.net_proxies != null and not game.net_proxies.is_empty():
		var net_font := UI.crisp_font()
		var title := "СЕТЬ · %d" % (game.net_proxies.size() + 1)
		target_arrows.draw_string(net_font, Vector2(520.0, 26.0), title, HORIZONTAL_ALIGNMENT_CENTER, 96, 8, Color(0.55, 0.92, 1.0, 0.75))
		for np in game.net_proxies:
			if np == null or not is_instance_valid(np) or np.dead:
				continue
			var npos: Vector2 = (np.global_position - cam_center) * zoom_v + center_screen
			if Rect2(6.0, 34.0, 628.0, 314.0).has_point(npos):
				continue
			var ndir := (npos - center_screen).normalized()
			var nanchor := center_screen + ndir * 168.0
			var ntip := nanchor + ndir * 9.0
			var nperp := Vector2(-ndir.y, ndir.x)
			target_arrows.draw_colored_polygon(
				PackedVector2Array([ntip, nanchor - ndir * 6.0 + nperp * 5.0, nanchor - ndir * 6.0 - nperp * 5.0]),
				Color(0.35, 0.85, 1.0, 0.9))
			var nname := String(np.display_name).substr(0, 10)
			target_arrows.draw_string(net_font, nanchor - ndir * 16.0 + Vector2(-20.0, 3.0), nname,
				HORIZONTAL_ALIGNMENT_CENTER, 44, 7, Color(0.7, 0.95, 1.0, 0.8))
