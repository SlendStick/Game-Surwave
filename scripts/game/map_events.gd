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
		# первое срабатывание — позже, чтобы игрок успел освоиться
		timers.append(float(events[i].get("interval", 60.0)) * 0.7)

func tick(delta: float) -> void:
	for i in events.size():
		timers[i] = float(timers[i]) - delta
		if float(timers[i]) <= 0.0:
			var ev: Dictionary = events[i]
			timers[i] = float(ev.get("interval", 60.0))
			game.run_map_event(ev)
