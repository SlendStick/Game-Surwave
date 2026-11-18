extends Node
## Net — сетевая игра Surwave.
## Один и тот же ENet-слой работает и в локальной сети, и через интернет:
## хост открывает порт, остальные подключаются по IP (в LAN адрес виден в списке
## автоматически — хосты объявляют себя UDP-широковещанием).
## Кооп: до 4 игроков, хост считает мир, клиенты присылают своё состояние.

signal lobby_changed
signal notice(text: String)
signal connected_ok
signal connection_failed(reason: String)
signal session_start_requested(config: Dictionary)
signal session_ended(reason: String)
signal snapshot_received(snap: Dictionary)
signal state_received(peer_id: int, state: Dictionary)
signal damage_received(amount: int, from_pos: Vector2)
signal event_received(kind: String, data: Dictionary)

const DEFAULT_PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 4
## 3: снапшот с боссами, кристаллами-душами и id подборов, события чата/эмоций.
const PROTOCOL := 3
const LAN_TAG := "SURWAVE1"
const LAN_TIMEOUT_MS := 4000

var enabled := false
var hosting := false
var in_session := false
var my_name := "Странник"
var last_error := ""
var session_seed := 0
## peer_key (строка) -> {"name", "ready", "character", "weapon", "map", "mode"}
var lobby_players: Dictionary = {}
## ip -> {"name", "port", "players", "seen"}
var lan_hosts: Dictionary = {}
var local_ip := "127.0.0.1"
var local_character := "aldar"
var local_weapon := "revolver"

var _udp := PacketPeerUDP.new()
var _udp_mode := ""
var _broadcast_cd := 0.0
var _host_port := DEFAULT_PORT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	local_ip = _detect_local_ip()
	my_name = String(GameManager.setting("net_name", "")).strip_edges()
	if my_name == "":
		my_name = "Странник"
	var chars: Array = SaveManager.data.get("unlocked_chars", [])
	var weapons: Array = SaveManager.data.get("unlocked_weapons", [])
	local_character = String(chars[0]) if not chars.is_empty() else "aldar"
	local_weapon = String(weapons[0]) if not weapons.is_empty() else "revolver"

func _detect_local_ip() -> String:
	for addr in IP.get_local_addresses():
		var a := String(addr)
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	for addr in IP.get_local_addresses():
		var a := String(addr)
		if not a.contains(":") and a != "127.0.0.1":
			return a
	return "127.0.0.1"

# ------------------------------------------------------------------ СЛУЖЕБНОЕ
func my_id() -> int:
	return multiplayer.get_unique_id()

func is_host() -> bool:
	return enabled and multiplayer.multiplayer_peer != null and multiplayer.is_server()

func is_client() -> bool:
	return enabled and multiplayer.multiplayer_peer != null and not multiplayer.is_server()

func max_players() -> int:
	return MAX_PLAYERS

func peer_count() -> int:
	if not enabled:
		return 0
	return multiplayer.get_peers().size() + 1

func player_name(peer_id: int) -> String:
	var info: Dictionary = lobby_players.get(str(peer_id), {})
	var name_out := String(info.get("name", "Игрок %d" % peer_id))
	return name_out if name_out != "" else "Игрок %d" % peer_id

func _my_info() -> Dictionary:
	return {
		"name": my_name if my_name != "" else "Странник",
		"ready": true,
		"character": local_character,
		"weapon": local_weapon,
	}

## Локальный выбор героя/оружия в лобби — уходит хосту для общего забега.
func set_loadout(char_id: String, weapon_id: String) -> void:
	local_character = char_id
	local_weapon = weapon_id
	if not enabled:
		return
	if is_host():
		lobby_players["1"] = _my_info()
		_broadcast_lobby()
	elif is_client():
		_srv_set_loadout.rpc_id(1, char_id, weapon_id)

@rpc("any_peer", "call_remote", "reliable")
func _srv_set_loadout(char_id: String, weapon_id: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 0 or not lobby_players.has(str(id)):
		return
	var entry: Dictionary = lobby_players[str(id)]
	entry["character"] = char_id
	entry["weapon"] = weapon_id
	lobby_players[str(id)] = entry
	_broadcast_lobby()

## Загрузки для старта забега: peer -> [герой, оружие].
func loadout_table() -> Dictionary:
	var out: Dictionary = {}
	for key in lobby_players.keys():
		var entry: Dictionary = lobby_players[key]
		out[String(key)] = [String(entry.get("character", "aldar")), String(entry.get("weapon", "revolver"))]
	return out

## Адрес для друзей: «ip:порт» (то, что нужно ввести в поле «IP хоста»).
func address_text() -> String:
	return "%s:%d" % [local_ip, default_port()]

## Порт по умолчанию из настроек.
func default_port() -> int:
	return int(GameManager.setting("net_port", DEFAULT_PORT))

# ------------------------------------------------------------------ ХОСТ / КЛИЕНТ
## Открыть сервер. Возвращает пустую строку при успехе, иначе текст ошибки.
func host_game(port: int = -1) -> String:
	shutdown()
	var p := port if port > 0 else default_port()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "Не удалось открыть порт %d (занят или закрыт)" % p
		return last_error
	multiplayer.multiplayer_peer = peer
	enabled = true
	hosting = true
	in_session = false
	_host_port = p
	lobby_players = {"1": _my_info()}
	_start_discovery(p)
	lobby_changed.emit()
	notice.emit("Сервер запущен на порту %d" % p)
	return ""

## Подключиться к хосту по IP (LAN или глобальная сеть).
func join_game(ip: String, port: int = -1) -> String:
	shutdown()
	var addr := ip.strip_edges()
	if addr == "":
		last_error = "Укажите IP-адрес хоста"
		return last_error
	var p := port if port > 0 else default_port()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, p)
	if err != OK:
		last_error = "Не удалось создать подключение к %s:%d" % [addr, p]
		return last_error
	multiplayer.multiplayer_peer = peer
	enabled = true
	hosting = false
	in_session = false
	_host_port = p
	lobby_players = {}
	GameManager.set_setting("net_last_ip", addr)
	notice.emit("Подключаемся к %s:%d…" % [addr, p])
	return ""

func shutdown() -> void:
	stop_discovery()
	_stop_lan_listen()
	var had := enabled
	enabled = false
	hosting = false
	in_session = false
	lobby_players.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if had:
		lobby_changed.emit()

func leave_session(reason: String = "Сессия завершена") -> void:
	var was := enabled
	shutdown()
	if was:
		session_ended.emit(reason)

# ------------------------------------------------------------------ СОБЫТИЯ СЕТИ
func _on_peer_connected(_id: int) -> void:
	lobby_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	lobby_players.erase(str(id))
	if is_host():
		_broadcast_lobby()
	else:
		lobby_changed.emit()

func _on_connected_to_server() -> void:
	connected_ok.emit()
	_register_player.rpc_id(1, my_name, PROTOCOL)
	# Свой герой и оружие — сразу, иначе хост покажет чужие умолчания.
	_srv_set_loadout.rpc_id(1, local_character, local_weapon)

func _on_connection_failed() -> void:
	last_error = "Хост не отвечает. Проверьте IP, порт и сеть."
	enabled = false
	hosting = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	connection_failed.emit(last_error)

func _on_server_disconnected() -> void:
	leave_session("Соединение с хостом потеряно")

# ------------------------------------------------------------------ ЛОББИ
@rpc("any_peer", "call_remote", "reliable")
func _register_player(pname: String, protocol: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 0:
		return
	if protocol != PROTOCOL:
		_notify_one.rpc_id(id, "Версии игры не совпадают — обновите Surwave")
		return
	if lobby_players.size() >= MAX_PLAYERS:
		_notify_one.rpc_id(id, "На сервере уже максимум игроков")
		return
	lobby_players[str(id)] = {
		"name": pname if pname != "" else "Игрок %d" % id,
		"ready": true,
		"character": "aldar",
		"weapon": "revolver",
	}
	_broadcast_lobby()
	notice.emit("%s подключился" % player_name(id))

func _broadcast_lobby() -> void:
	if not is_host():
		return
	var payload := lobby_players.duplicate(true)
	_receive_lobby.rpc(payload)
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _receive_lobby(list: Dictionary) -> void:
	lobby_players = list
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _notify_one(text: String) -> void:
	notice.emit(text)

func set_my_name(value: String) -> void:
	my_name = value.strip_edges()
	GameManager.set_setting("net_name", my_name)
	if is_host():
		lobby_players["1"] = _my_info()
		_broadcast_lobby()
	elif is_client():
		_register_player.rpc_id(1, my_name, PROTOCOL)

## Хост запускает забег: конфиг уходит всем, каждый игрок сам грузит сцену.
func start_session(config: Dictionary) -> void:
	if not is_host():
		return
	var cfg := config.duplicate(true)
	cfg["network"] = true
	cfg["host"] = true
	cfg["seed"] = int(cfg.get("seed", randi() % 999983 + 1))
	cfg["players"] = lobby_players.size()
	session_seed = int(cfg["seed"])
	in_session = true
	_begin_session.rpc(cfg)
	session_start_requested.emit(cfg)
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _begin_session(config: Dictionary) -> void:
	var cfg := config.duplicate(true)
	cfg["network"] = true
	cfg["host"] = false
	session_seed = int(cfg.get("seed", 0))
	in_session = true
	session_start_requested.emit(cfg)

func config_from_host() -> Dictionary:
	return {"network": true, "host": is_host(), "seed": session_seed}

# ------------------------------------------------------------------ ИГРОВОЙ ОБМЕН
## Клиент → хост: состояние своего игрока (20 Гц).
func send_player_state(state: Dictionary) -> void:
	if not is_client():
		return
	_srv_player_state.rpc_id(1, state)

## Хост → остальные: состояния игроков (20 Гц).
func broadcast_states(states: Dictionary) -> void:
	if not is_host():
		return
	_cli_states.rpc(states)

## Хост → клиенты: снимок мира (12 Гц).
func broadcast_snapshot(snap: Dictionary) -> void:
	if not is_host():
		return
	_cli_snapshot.rpc(snap)

## Клиент → хост: «я попал по врагу».
func request_damage(net_id: int, amount: float, source: String) -> void:
	if not is_client():
		return
	_srv_request_damage.rpc_id(1, net_id, amount, source)

## Хост → клиент: урон по его игроку.
func send_player_damage(peer_id: int, amount: int, from_pos: Vector2) -> void:
	if not is_host() or peer_id <= 1:
		return
	_cli_player_damage.rpc_id(peer_id, amount, from_pos)

## Хост → клиенты: короткое событие (звук, сообщение, смерть босса).
func send_event(kind: String, data: Dictionary) -> void:
	if not is_host():
		return
	_cli_event.rpc(kind, data)

## Любой игрок → всем: эмоции, чат, взятый перк, просьба о возрождении.
## Клиент отправляет хосту, хост рассылает дальше — так сохраняется порядок.
func send_event_any(kind: String, data: Dictionary) -> void:
	if not enabled:
		return
	if is_host():
		send_event(kind, data)
	else:
		_srv_event.rpc_id(1, kind, data)

@rpc("any_peer", "call_remote", "reliable")
func _srv_event(kind: String, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 0:
		return
	var payload: Dictionary = data.duplicate(true)
	payload["peer"] = id
	_cli_event.rpc(kind, payload)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_player_state(state: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	state_received.emit(id, state)

@rpc("authority", "call_remote", "unreliable_ordered")
func _cli_states(states: Dictionary) -> void:
	for key in states.keys():
		var peer_id := int(key)
		var state: Dictionary = states[key]
		state_received.emit(peer_id, state)

@rpc("authority", "call_remote", "unreliable")
func _cli_snapshot(snap: Dictionary) -> void:
	snapshot_received.emit(snap)

@rpc("any_peer", "call_remote", "reliable")
func _srv_request_damage(net_id: int, amount: float, source: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	event_received.emit("request_damage", {"peer": id, "net_id": net_id, "amount": amount, "source": source})

@rpc("authority", "call_remote", "reliable")
func _cli_player_damage(amount: int, from_pos: Vector2) -> void:
	damage_received.emit(amount, from_pos)

@rpc("authority", "call_remote", "reliable")
func _cli_event(kind: String, data: Dictionary) -> void:
	event_received.emit(kind, data)

# ------------------------------------------------------------------ LAN-ОБНАРУЖЕНИЕ
func _start_discovery(port: int) -> void:
	_stop_lan_listen()
	_udp.close()
	var err := _udp.bind(DISCOVERY_PORT)
	if err != OK:
		return
	_udp.set_broadcast_enabled(true)
	_udp_mode = "host"
	_broadcast_cd = 0.0
	_announce(port)

func stop_discovery() -> void:
	if _udp_mode == "host":
		_udp.close()
		_udp_mode = ""

## Клиент слушает объявления хостов в локальной сети.
func start_lan_listen() -> void:
	if _udp_mode == "host":
		return
	_udp.close()
	var err := _udp.bind(DISCOVERY_PORT)
	if err != OK:
		lan_hosts.clear()
		_udp_mode = "listen"
		return
	_udp_mode = "listen"

func _stop_lan_listen() -> void:
	if _udp_mode == "listen":
		_udp.close()
		_udp_mode = ""

func lan_list() -> Array:
	var now := Time.get_ticks_msec()
	var out: Array = []
	for ip in lan_hosts.keys():
		var entry: Dictionary = lan_hosts[ip]
		if now - int(entry.get("seen", 0)) > LAN_TIMEOUT_MS:
			lan_hosts.erase(ip)
			continue
		out.append(entry)
	return out

func _announce(port: int) -> void:
	var payload := "%s|%d|%s|%d|%d" % [LAN_TAG, port, my_name, lobby_players.size(), MAX_PLAYERS]
	_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_udp.put_packet(payload.to_utf8_buffer())

func _process(delta: float) -> void:
	if _udp_mode == "host":
		_broadcast_cd -= delta
		if _broadcast_cd <= 0.0:
			_broadcast_cd = 1.0
			_announce(_host_port)
		return
	if _udp_mode != "listen":
		return
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var text := packet.get_string_from_utf8()
		var parts := text.split("|")
		if parts.size() < 3 or String(parts[0]) != LAN_TAG:
			continue
		var ip := _udp.get_packet_ip()
		if ip == "" or ip == "0.0.0.0":
			continue
		lan_hosts[ip] = {
			"ip": ip,
			"port": int(String(parts[1])),
			"name": String(parts[2]),
			"players": int(String(parts[3])) if parts.size() > 3 else 1,
			"max": int(String(parts[4])) if parts.size() > 4 else MAX_PLAYERS,
			"seen": Time.get_ticks_msec(),
		}
		lobby_changed.emit()
