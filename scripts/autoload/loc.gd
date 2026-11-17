extends Node
## Loc — локализация RU/EN. Весь интерфейсный текст берётся отсюда,
## текст из данных — через pick() (ключи name/name_en и т.п.).

var lang: String = "ru"

const STRINGS := {
"ru": {
	"play": "ИГРАТЬ", "shops": "МАГАЗИНЫ", "album": "АЛЬБОМ", "achievements": "ДОСТИЖЕНИЯ",
	"settings": "НАСТРОЙКИ", "quit": "ВЫХОД", "back": "НАЗАД", "start": "НАЧАТЬ",
	"mode": "Режим", "character": "Персонаж", "weapon": "Оружие", "map": "Карта", "darkness": "Тьма",
	"amulets": "Амулеты", "no_amulet": "слот пуст", "locked": "ЗАКРЫТО", "buy": "КУПИТЬ",
	"bought": "Куплено", "equipped": "Экипировано", "souls": "души", "gold": "золото",
	"hp": "HP", "level": "Ур.", "time": "Время", "xp": "Опыт", "kills": "Убийства",
	"damage_dealt": "Нанесено урона", "damage_taken": "Получено урона", "restart": "Повтор",
	"main_menu": "Главное меню", "continue_endless": "Продолжить (бесконечный)",
	"paused": "ПАУЗА", "resume": "Продолжить", "victory": "ПОБЕДА", "defeat": "ПОРАЖЕНИЕ",
	"choose_upgrade": "ВЫБЕРИТЕ УЛУЧШЕНИЕ", "chest": "СУНДУК", "specialization": "СПЕЦИАЛИЗАЦИЯ",
	"seal": "ДРЕВНЯЯ ПЕЧАТЬ", "synergy": "СИНЕРГИЯ", "perk": "ПЕРК", "char_upgrade": "УНИКАЛЬНЫЙ АПГРЕЙД",
	"new_level": "НОВЫЙ УРОВЕНЬ", "boss": "БОСС", "dawn": "Рассвет близко...",
	"reload": "ПЕРЕЗАРЯДКА", "skill": "СКИЛЛ", "mag": "Магазин",
	"empty_slot": "пусто", "close": "Закрыть", "music": "Музыка", "sfx": "Звуки",
	"lang": "Язык", "shake": "Тряска экрана", "on": "вкл", "off": "выкл",
	"locked_endless": "Победите Мордрета в Проклятых Руинах",
	"need_souls": "Недостаточно душ", "unlocked_txt": "Открыто",
	"album_enemies": "Существа", "album_bosses": "Боссы", "album_chars": "Персонажи",
	"album_weapons": "Оружие", "not_met": "???", "run_stats": "Итоги забега",
	"secret_map": "???", "select": "Выбрать", "tap_to_start": "Нажмите ЛКМ по карточке",
	"reset_save": "Сбросить прогресс", "confirm_reset": "Точно сбросить?",
	"controls": "WASD — движение · ЛКМ — огонь · R — перезарядка · ПКМ/Shift — скилл · Esc — пауза · Tab — синергии",
	"mode_standard": "Стандартный (30 мин)", "mode_quick": "Быстрый (10 мин)", "mode_endless": "Бесконечный",
	"darkness_level": "Уровень Тьмы", "win_condition": "Выжить 30 минут и убить босса",
	"revive_used": "Связь Душ спасла вас", "soul_picked": "+1 макс. HP",
	"auto_pick": "Автовыбор (тест)", "spec_active": "Следующий перк x3",
	"shops_chars": "Персонажи", "shops_weapons": "Оружие", "shops_amulets": "Амулеты",
	"rank": "Ранг", "cost": "Цена", "upgrade_rank": "Улучшить",
	"achievements_empty": "Достижения открываются за победы, секреты и испытания.",
	"stats_kills": "Всего убийств", "stats_runs": "Забегов", "stats_wins": "Побед",
	"boss_hp": "HP босса", "miniboss": "МИНИ-БОСС", "elite": "ЭЛИТА",
	"sathan_warn": "МЕГАФАЗА: САТАН", "pentagram_enter": "Вы вошли в ПУСТОТУ", "pentagram_appear": "Появилась пентаграмма! Войдите (E)",
	"grotgar_nohit": "Пентаграмма появилась! Войдите в неё (E).",
	"summons": "Призывы", "synergies_list": "Синергии", "no_synergies": "Пока нет синергий",
	"reload_needed": "Нажмите R", "wave": "Волна", "enemies": "Врагов",
	"fps": "FPS", "god_mode": "Бессмертие (тест)",
},
"en": {
	"play": "PLAY", "shops": "SHOPS", "album": "ALBUM", "achievements": "ACHIEVEMENTS",
	"settings": "SETTINGS", "quit": "QUIT", "back": "BACK", "start": "START",
	"mode": "Mode", "character": "Character", "weapon": "Weapon", "map": "Map", "darkness": "Darkness",
	"amulets": "Amulets", "no_amulet": "empty slot", "locked": "LOCKED", "buy": "BUY",
	"bought": "Owned", "equipped": "Equipped", "souls": "souls", "gold": "gold",
	"hp": "HP", "level": "Lv.", "time": "Time", "xp": "XP", "kills": "Kills",
	"damage_dealt": "Damage dealt", "damage_taken": "Damage taken", "restart": "Retry",
	"main_menu": "Main menu", "continue_endless": "Continue (endless)",
	"paused": "PAUSED", "resume": "Resume", "victory": "VICTORY", "defeat": "DEFEAT",
	"choose_upgrade": "CHOOSE AN UPGRADE", "chest": "CHEST", "specialization": "SPECIALIZATION",
	"seal": "ANCIENT SEAL", "synergy": "SYNERGY", "perk": "PERK", "char_upgrade": "CHARACTER UPGRADE",
	"new_level": "NEW LEVEL", "boss": "BOSS", "dawn": "Dawn is near...",
	"reload": "RELOAD", "skill": "SKILL", "mag": "Mag",
	"empty_slot": "empty", "close": "Close", "music": "Music", "sfx": "SFX",
	"lang": "Language", "shake": "Screen shake", "on": "on", "off": "off",
	"locked_endless": "Defeat Mordret in the Cursed Ruins",
	"need_souls": "Not enough souls", "unlocked_txt": "Unlocked",
	"album_enemies": "Creatures", "album_bosses": "Bosses", "album_chars": "Characters",
	"album_weapons": "Weapons", "not_met": "???", "run_stats": "Run summary",
	"secret_map": "???", "select": "Select", "tap_to_start": "Click a card",
	"reset_save": "Reset progress", "confirm_reset": "Really reset?",
	"controls": "WASD — move · LMB — fire · R — reload · RMB/Shift — skill · Esc — pause · Tab — synergies",
	"mode_standard": "Standard (30 min)", "mode_quick": "Quick (10 min)", "mode_endless": "Endless",
	"darkness_level": "Darkness level", "win_condition": "Survive 30 minutes and kill the boss",
	"revive_used": "Soulbond saved you", "soul_picked": "+1 max HP",
	"auto_pick": "Auto-pick (test)", "spec_active": "Next perk x3",
	"shops_chars": "Characters", "shops_weapons": "Weapons", "shops_amulets": "Amulets",
	"rank": "Rank", "cost": "Cost", "upgrade_rank": "Upgrade",
	"achievements_empty": "Achievements unlock through victories, secrets and trials.",
	"stats_kills": "Total kills", "stats_runs": "Runs", "stats_wins": "Wins",
	"boss_hp": "Boss HP", "miniboss": "MINI-BOSS", "elite": "ELITE",
	"sathan_warn": "MEGAPHASE: SATHAN", "pentagram_enter": "You entered the VOID", "pentagram_appear": "A pentagram appeared! Enter (E)",
	"grotgar_nohit": "A pentagram appeared! Enter it (E).",
	"summons": "Summons", "synergies_list": "Synergies", "no_synergies": "No synergies yet",
	"reload_needed": "Press R", "wave": "Wave", "enemies": "Enemies",
	"fps": "FPS", "god_mode": "God mode (test)",
},
}

func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS["ru"])
	return String(table.get(key, key))

## Достаёт локализованное поле из словаря данных: name / name_en.
func pick(data: Dictionary, field: String = "name") -> String:
	if lang == "en":
		var en_key := field + "_en"
		if data.has(en_key) and String(data[en_key]) != "":
			return String(data[en_key])
	return String(data.get(field, ""))

func set_lang(new_lang: String) -> void:
	lang = new_lang if STRINGS.has(new_lang) else "ru"
	TranslationServer.set_locale(lang)
