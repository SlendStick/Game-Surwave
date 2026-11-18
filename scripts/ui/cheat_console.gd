extends CanvasLayer
## Чит-консоль. Клавиша `~` (или ё на русской раскладке) открывает строку ввода.
## Команда «wuss menu» открывает меню читов: бессмертие, опыт, спавн врагов и боссов,
## скорость времени, конфигурация персонажа и врагов. Всё рисуется кодом.

const COMMAND := "wuss menu"

var game: Node = null
var root: Control = null
var line: LineEdit = null
var hint: Label = null
var menu: Panel = null
var body: VBoxContainer = null
var was_paused := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- строка ввода
	line = LineEdit.new()
	line.size = Vector2(608, 24)
	line.placeholder_text = "введите команду…"
	line.max_length = 40
	if UI.font() != null:
		line.add_theme_font_override("font", UI.font())
	line.add_theme_font_size_override("font_size", 11)
	line.add_theme_color_override("font_color", UI.GOLD_BRIGHT)
	line.add_theme_color_override("caret_color", UI.GOLD)
	line.add_theme_color_override("font_placeholder_color", UI.MUTED)
	line.add_theme_stylebox_override("normal", UI.stone_box(Color(0.05, 0.05, 0.06, 0.96), UI.BORDER_HI))
	line.add_theme_stylebox_override("focus", UI.stone_box(Color(0.07, 0.07, 0.085, 0.98), UI.GOLD_DEEP))
	line.text_submitted.connect(_submit)
	line.visible = false
	root.add_child(line)

	hint = UI.label(root, "~ — консоль · команда: wuss menu", 8, UI.MUTED, Vector2(0, 0))
	hint.visible = false

	# --- меню читов
	menu = UI.stone(root, Rect2(0, 0, 608, 306), UI.BORDER_HI)
	menu.visible = false
	var title := UI.label(menu, "ЧИТ-МЕНЮ", 14, UI.GOLD_BRIGHT, Vector2(12, 6))
	title.add_theme_constant_override("outline_size", 4)
	UI.label(menu, "изменения действуют до конца забега", 8, UI.MUTED, Vector2(13, 22))
	var close := UI.primary_button(menu, "ЗАКРЫТЬ", 9, Vector2(84, 22))
	close.position = Vector2(508, 8)
	close.pressed.connect(close_all)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 30)
	scroll.size = Vector2(588, 268)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(570, 0)
	body.add_theme_constant_override("separation", 3)
	scroll.add_child(body)

## Строка — снизу по центру, меню — сверху по центру (1280×720 и 1440×900).
func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0:
		vp = Vector2(1280, 720)
	line.position = Vector2(roundf((vp.x - 608.0) * 0.5), roundf(vp.y - 78.0))
	hint.position = Vector2(roundf((vp.x - 608.0) * 0.5) + 2.0, roundf(vp.y - 94.0))
	menu.position = Vector2(roundf((vp.x - 608.0) * 0.5), 16.0)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
		if line.visible or menu.visible:
			close_all()
			get_viewport().set_input_as_handled()
		return
	if key.physical_keycode != KEY_QUOTELEFT:
		return
	if game == null or not game.run_started or game.ended:
		return
	if line.visible or menu.visible:
		close_all()
	else:
		open_line()
	get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ СТРОКА
func open_line() -> void:
	pause_for_cheats()
	GameManager.cheat_open = true
	_layout()
	line.text = ""
	line.visible = true
	hint.visible = true
	line.grab_focus()
	if game != null and game.has_method("sync_pause_state"):
		game.sync_pause_state()

func _submit(text: String) -> void:
	var cmd := text.strip_edges().to_lower()
	if cmd == "":
		return
	GameManager.mark_cheat_used()
	if cmd == COMMAND or cmd == "wussmenu" or cmd == "wuss":
		open_menu()
		return
	hint.text = "неизвестная команда: %s · попробуйте: wuss menu" % text.strip_edges()
	line.text = ""

func pause_for_cheats() -> void:
	was_paused = get_tree().paused
	get_tree().paused = true

func unpause_after_cheats() -> void:
	if game != null and game.has_method("sync_pause_state"):
		game.sync_pause_state()
	else:
		get_tree().paused = was_paused

# ------------------------------------------------------------------ МЕНЮ
func open_menu() -> void:
	GameManager.cheat_open = true
	GameManager.mark_cheat_used()
	pause_for_cheats()
	line.visible = false
	hint.visible = true
	hint.text = "~ — закрыть · изменения действуют сразу"
	menu.visible = true
	_layout()
	line.release_focus()
	_rebuild()
	if game != null and game.has_method("sync_pause_state"):
		game.sync_pause_state()

func close_all() -> void:
	GameManager.cheat_open = false
	line.visible = false
	hint.visible = false
	menu.visible = false
	line.release_focus()
	unpause_after_cheats()

func _rebuild() -> void:
	if body == null or game == null or game.player == null:
		return
	UI.clear(body)
	var p: Player = game.player
	# --- ИГРОК
	_section("ИГРОК")
	_row_toggle("Бессмертие", GameManager.god_mode, func() -> void:
		GameManager.mark_cheat_used()
		GameManager.god_mode = not GameManager.god_mode
		_rebuild())
	_row_buttons("Здоровье %d/%d" % [p.hp, p.max_hp], [
		["лечить", func() -> void: p.heal(p.max_hp); _rebuild()],
		["+1 HP макс.", func() -> void: p.max_hp += 1; p.hp = p.max_hp; _rebuild()],
	])
	_row_toggle("Бесконечные патроны", p.inf_ammo, func() -> void:
		p.inf_ammo = not p.inf_ammo
		if p.inf_ammo:
			p.mag = int(p.S.mag)
		_rebuild())
	_row_buttons("Опыт: ур. %d · %d/%d" % [game.level, game.xp, game.xp_need], [
		["+1000", func() -> void: _give_xp(1000.0)],
		["+10000", func() -> void: _give_xp(10000.0)],
		["+1 ур.", func() -> void: _give_xp(float(game.xp_need))],
	])
	_row_buttons("Урон игрока ×%.0f" % GameManager.cheat_dmg, [
		["÷2", func() -> void: GameManager.cheat_dmg = maxf(0.25, GameManager.cheat_dmg / 2.0); _rebuild()],
		["×2", func() -> void: GameManager.cheat_dmg = minf(1000.0, GameManager.cheat_dmg * 2.0); _rebuild()],
		["×1", func() -> void: GameManager.cheat_dmg = 1.0; _rebuild()],
	])
	_row_buttons("Скорость игрока ×%.1f" % GameManager.cheat_speed, [
		["÷1.5", func() -> void: GameManager.cheat_speed = maxf(0.2, GameManager.cheat_speed / 1.5); _rebuild()],
		["×1.5", func() -> void: GameManager.cheat_speed = minf(10.0, GameManager.cheat_speed * 1.5); _rebuild()],
		["×1", func() -> void: GameManager.cheat_speed = 1.0; _rebuild()],
	])
	# --- КОНФИГУРАЦИЯ ПЕРСОНАЖА
	_section("КОНФИГУРАЦИЯ ПЕРСОНАЖА")
	_row_buttons("Урон оружия %.1f" % float(p.S.damage), [
		["−20%", func() -> void: p.S.damage = maxf(0.1, float(p.S.damage) * 0.8); _rebuild()],
		["+20%", func() -> void: p.S.damage = float(p.S.damage) * 1.2; _rebuild()],
	])
	_row_buttons("Темп стрельбы %.1f/с" % float(p.S.fire_rate), [
		["−20%", func() -> void: p.S.fire_rate = maxf(0.2, float(p.S.fire_rate) * 0.8); _rebuild()],
		["+20%", func() -> void: p.S.fire_rate = float(p.S.fire_rate) * 1.2; _rebuild()],
	])
	_row_buttons("Магазин %d" % int(p.S.mag), [
		["−1", func() -> void: p.S.mag = maxi(1, int(p.S.mag) - 1); p.mag = int(p.S.mag); _rebuild()],
		["+1", func() -> void: p.S.mag = int(p.S.mag) + 1; p.mag = int(p.S.mag); _rebuild()],
		["×2", func() -> void: p.S.mag = int(p.S.mag) * 2; p.mag = int(p.S.mag); _rebuild()],
	])
	_row_buttons("Скорость %.0f · Снарядов %d" % [float(p.S.move_speed), int(p.S.projectiles)], [
		["+снаряд", func() -> void: p.S.projectiles = mini(12, int(p.S.projectiles) + 1); _rebuild()],
		["сброс", func() -> void: p.recalc(); p.hp = p.max_hp; _rebuild()],
	])
	# --- ВРАГИ
	_section("ВРАГИ")
	_row_buttons("Здоровье врагов ×%.2f" % GameManager.cheat_enemy_hp, [
		["÷2", func() -> void: _set_enemy_hp(maxf(0.05, GameManager.cheat_enemy_hp / 2.0))],
		["×2", func() -> void: _set_enemy_hp(minf(100.0, GameManager.cheat_enemy_hp * 2.0))],
		["×1", func() -> void: _set_enemy_hp(1.0)],
	])
	_row_buttons("Урон врагов ×%.2f" % GameManager.cheat_enemy_dmg, [
		["÷2", func() -> void: _set_enemy_dmg(maxf(0.05, GameManager.cheat_enemy_dmg / 2.0))],
		["×2", func() -> void: _set_enemy_dmg(minf(100.0, GameManager.cheat_enemy_dmg * 2.0))],
		["×1", func() -> void: _set_enemy_dmg(1.0)],
	])
	_row_buttons("Скорость врагов ×%.2f" % GameManager.cheat_enemy_speed, [
		["÷2", func() -> void: GameManager.cheat_enemy_speed = maxf(0.0, GameManager.cheat_enemy_speed / 2.0); _rebuild()],
		["×2", func() -> void: GameManager.cheat_enemy_speed = minf(10.0, GameManager.cheat_enemy_speed * 2.0); _rebuild()],
		["×1", func() -> void: GameManager.cheat_enemy_speed = 1.0; _rebuild()],
	])
	_row_toggle("Заморозить врагов", GameManager.cheat_frozen, func() -> void:
		GameManager.cheat_frozen = not GameManager.cheat_frozen
		_rebuild())
	_row_buttons("Живых: %d" % game.enemies.size(), [
		["убить всех", func() -> void: game.cheat_kill_all(); _rebuild()],
		["очистить зону", func() -> void: game.cheat_clear_around(); _rebuild()],
	])
	# --- ВРЕМЯ
	_section("ВРЕМЯ")
	var ts := Engine.time_scale
	var time_row: HBoxContainer = _new_row()
	var tl := UI.label(time_row, "Скорость времени ×%.2f" % ts, 8, UI.TEXT)
	tl.custom_minimum_size = Vector2(180, 16)
	for item in [["0.25", 0.25], ["0.5", 0.5], ["1", 1.0], ["2", 2.0], ["4", 4.0]]:
		var tb := UI.button(time_row, String(item[0]), 8, Vector2(66, 18))
		var val: float = float(item[1])
		tb.pressed.connect(func() -> void: Engine.time_scale = val; _rebuild())
	_row_buttons("Пауза мира", [
		["стоп", func() -> void: Engine.time_scale = 0.02; _rebuild()],
		["продолжить", func() -> void: Engine.time_scale = 1.0; _rebuild()],
	])
	# --- СПАВН ВРАГОВ
	_section("СПАВН ВРАГОВ")
	var row: HBoxContainer = null
	var in_row := 0
	for e in DB.enemies:
		if String(e.get("role", "")) == "miniboss":
			continue
		if row == null or in_row >= 4:
			row = _new_row()
			in_row = 0
		var eid := String(e.get("id", ""))
		var b := UI.button(row, String(e.get("name", eid)), 8, Vector2(136, 18))
		b.pressed.connect(func() -> void: _spawn_enemy(eid))
		in_row += 1
	# --- БОССЫ
	_section("БОССЫ И МИНИ-БОССЫ")
	row = null
	in_row = 0
	for bid in DB.bosses.keys():
		if row == null or in_row >= 3:
			row = _new_row()
			in_row = 0
		var def: Dictionary = DB.bosses[bid]
		var bb := UI.button(row, String(def.get("name", String(bid))), 8, Vector2(184, 18))
		bb.pressed.connect(func() -> void: _spawn_boss(String(bid)))
		in_row += 1
	row = _new_row()
	var sb := UI.button(row, "САТАНАИЛ (секрет)", 8, Vector2(206, 18))
	sb.pressed.connect(func() -> void: _spawn_boss("satanail"))
	var mb := UI.button(row, "мини-босс карты", 8, Vector2(170, 18))
	mb.pressed.connect(func() -> void: game.spawn_miniboss(1))

# ------------------------------------------------------------------ ДЕЙСТВИЯ
func _give_xp(amount: float) -> void:
	# закрываем меню, чтобы карточки выбора уровня были видны
	close_all()
	game.add_xp(amount)

func _spawn_enemy(id: String) -> void:
	var pos: Vector2 = game.cheat_spawn_point()
	var e: Enemy = game.spawn_enemy(id, pos)
	hint.text = ("%s: %s" % ["заспавнен", String(DB.enemy(id).get("name", id))]) if e != null else "лимит врагов — не удалось"

## Множитель HP врагов — сразу для живых и для будущих спавнов.
func _set_enemy_hp(mult: float) -> void:
	var ratio: float = mult / maxf(0.0001, GameManager.cheat_enemy_hp)
	for e in game.enemies:
		if e != null and e.active and not e.dead:
			e.max_hp = maxf(1.0, float(e.max_hp) * ratio)
			e.hp = clampf(float(e.hp) * ratio, 0.0, float(e.max_hp))
	GameManager.cheat_enemy_hp = mult
	_rebuild()

## Множитель урона врагов — сразу для живых и для будущих спавнов.
func _set_enemy_dmg(mult: float) -> void:
	var ratio: float = mult / maxf(0.0001, GameManager.cheat_enemy_dmg)
	for e in game.enemies:
		if e != null and e.active and not e.dead:
			e.damage = maxi(1, int(round(float(e.damage) * ratio)))
	GameManager.cheat_enemy_dmg = mult
	_rebuild()

func _spawn_boss(id: String) -> void:
	var ok: bool = game.cheat_spawn_boss(id)
	hint.text = "босс вызван" if ok else "не удалось вызвать босса"

# ------------------------------------------------------------------ ЭЛЕМЕНТЫ
func _section(title: String) -> void:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	body.add_child(pad)
	var l := UI.label(body, title, 9, UI.GOLD, Vector2.ZERO)
	l.custom_minimum_size = Vector2(0, 12)
	var sep := UI.hbox(body, 0)
	sep.custom_minimum_size = Vector2(0, 2)
	var bar := ColorRect.new()
	bar.color = Color(UI.BORDER_HI.r, UI.BORDER_HI.g, UI.BORDER_HI.b, 0.5)
	bar.custom_minimum_size = Vector2(548, 1)
	sep.add_child(bar)

func _new_row() -> HBoxContainer:
	var h := UI.hbox(body, 4)
	h.custom_minimum_size = Vector2(0, 18)
	return h

func _row_buttons(title: String, buttons: Array) -> void:
	var h := _new_row()
	var l := UI.label(h, title, 8, UI.TEXT)
	l.custom_minimum_size = Vector2(238, 16)
	for item in buttons:
		var b := UI.button(h, String(item[0]), 8, Vector2(84, 18))
		b.pressed.connect(item[1])

func _row_toggle(title: String, state: bool, action: Callable) -> void:
	var h := _new_row()
	var l := UI.label(h, title, 8, UI.TEXT)
	l.custom_minimum_size = Vector2(238, 16)
	var b := UI.button(h, "включено" if state else "выключено", 8, Vector2(96, 18))
	if state:
		b.add_theme_color_override("font_color", UI.GOLD_BRIGHT)
		b.add_theme_stylebox_override("normal", UI.stone_box(Color(0.16, 0.14, 0.09, 0.9), UI.GOLD_DEEP))
	b.pressed.connect(action)
