class_name MapEvents
extends RefCounted
## Ивенты карты: метеоры, лавины, бури, лава, пентаграммы и т.п.
## Каждое событие просто вызывает соответствующий обработчик в Game.

var game: Node = null
var events: Array = []
var timers: Array = []
var modifiers: Dictionary = {}

func setup(g: Node, map_data: Dictionary) -> void:
	game = g
	events = map_data.get("events", [])
	modifiers = map_data.get("mods", {})
	timers.clear()
	for i in events.size():
		# Первое срабатывание и последующие интервалы случайно разбросаны около 1 минуты (~44–76 с)
		var base := clampf(float(events[i].get("interval", 60.0)), 45.0, 75.0)
		timers.append(randf_range(base * 0.38, base * 1.05))

func tick(delta: float) -> void:
	for i in events.size():
		timers[i] = float(timers[i]) - delta
		if float(timers[i]) <= 0.0:
			var ev: Dictionary = events[i]
			var base := clampf(float(ev.get("interval", 60.0)), 45.0, 75.0)
			timers[i] = randf_range(base * 0.74, base * 1.26)
			game.run_map_event(ev)
