extends Node
## AudioManager — шины, SFX и адаптивная музыка.
## ВАЖНО: аудио-ассетов в проекте нет, поэтому все звуки синтезируются в рантайме
## (процедурный placeholder-синтез). Позже их можно заменить файлами .ogg,
## не меняя интерфейс вызовов play_sfx()/play_music().

const RATE := 22050
const MUSIC_LEN := 4.0        # длина лупа одного слоя, сек

var music_volume := 0.8
var sfx_volume := 0.8
var _sfx_cache: Dictionary = {}
var _layers: Array[AudioStreamPlayer] = []
var _mood_key: String = ""
var _intensity: float = 0.0
var _boss_active := false
var _music_players_ready := false

func _ready() -> void:
	_setup_buses()
	_build_sfx()
	_ensure_players()

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	apply_volumes()

func apply_volumes() -> void:
	_set_bus_db("Music", music_volume)
	_set_bus_db("SFX", sfx_volume)

func _set_bus_db(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))

# ------------------------------------------------------------------ СИНТЕЗ
func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

func _osc(phase: float, shape: String) -> float:
	phase = fposmod(phase, 1.0)
	match shape:
		"sine": return sin(phase * TAU)
		"square": return 1.0 if phase < 0.5 else -1.0
		"saw": return phase * 2.0 - 1.0
		"tri": return 4.0 * absf(phase - 0.5) - 1.0
		_: return sin(phase * TAU)

## Простой тон с огибающей.
func _tone(dur: float, f0: float, f1: float, shape: String, decay: float, noise: float = 0.0, vol: float = 0.5) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 1000.0 + dur * 100.0)
	for i in n:
		var t := float(i) / RATE
		var k := t / maxf(dur, 0.001)
		var freq: float = lerpf(f0, f1, k)
		phase += freq / RATE
		var env: float = exp(-decay * k) * (1.0 - k * 0.15)
		var s := _osc(phase, shape) * env
		if noise > 0.0:
			s = lerpf(s, rng.randf_range(-1.0, 1.0) * env, noise)
		samples[i] = s * vol
	return _wav(samples)

func _build_sfx() -> void:
	_sfx_cache["shot"] = _tone(0.09, 900.0, 220.0, "square", 6.0, 0.25, 0.35)
	_sfx_cache["shot_heavy"] = _tone(0.16, 400.0, 90.0, "saw", 4.5, 0.35, 0.45)
	_sfx_cache["shot_magic"] = _tone(0.14, 1400.0, 500.0, "sine", 5.0, 0.0, 0.30)
	_sfx_cache["reload"] = _tone(0.10, 220.0, 160.0, "square", 8.0, 0.4, 0.25)
	_sfx_cache["hit"] = _tone(0.06, 700.0, 300.0, "square", 10.0, 0.5, 0.22)
	_sfx_cache["kill"] = _tone(0.12, 320.0, 80.0, "saw", 7.0, 0.45, 0.28)
	_sfx_cache["hurt"] = _tone(0.22, 260.0, 70.0, "square", 3.5, 0.3, 0.45)
	_sfx_cache["xp"] = _tone(0.07, 1600.0, 2100.0, "sine", 8.0, 0.0, 0.20)
	_sfx_cache["gold"] = _tone(0.12, 1200.0, 1800.0, "tri", 6.0, 0.0, 0.22)
	_sfx_cache["levelup"] = _tone(0.45, 600.0, 1200.0, "tri", 2.5, 0.0, 0.32)
	_sfx_cache["chest"] = _tone(0.35, 400.0, 900.0, "square", 3.0, 0.15, 0.28)
	_sfx_cache["boss"] = _tone(0.9, 90.0, 45.0, "saw", 1.2, 0.25, 0.5)
	_sfx_cache["ui"] = _tone(0.05, 900.0, 900.0, "square", 10.0, 0.0, 0.20)
	_sfx_cache["error"] = _tone(0.18, 240.0, 180.0, "square", 4.0, 0.0, 0.28)
	_sfx_cache["skill"] = _tone(0.30, 700.0, 300.0, "saw", 3.0, 0.15, 0.30)
	_sfx_cache["freeze"] = _tone(0.20, 1800.0, 2400.0, "sine", 5.0, 0.1, 0.22)
	_sfx_cache["fire"] = _tone(0.25, 300.0, 500.0, "saw", 4.0, 0.55, 0.25)
	_sfx_cache["lightning"] = _tone(0.25, 2000.0, 300.0, "square", 3.0, 0.6, 0.28)
	_sfx_cache["secret"] = _tone(0.7, 300.0, 900.0, "sine", 1.6, 0.1, 0.35)
	_sfx_cache["sathan"] = _tone(1.4, 70.0, 33.0, "saw", 0.8, 0.35, 0.55)

func _ensure_players() -> void:
	if _music_players_ready:
		return
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
		_layers.append(p)
	_music_players_ready = true

## Останавливаем проигрывание при выходе, чтобы буферы не «висели» до конца процесса.
func _exit_tree() -> void:
	_release_audio()

func _release_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()
	_layers.clear()
	_sfx_cache.clear()

func play_sfx(sfx_name: String, pitch: float = 1.0, bus: String = "SFX") -> void:
	if not _sfx_cache.has(sfx_name):
		return
	if sfx_volume <= 0.001:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _sfx_cache[sfx_name]
	p.bus = bus
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.volume_db = -6.0
	add_child(p)
	p.play()
	# привязка к самому плееру: связь умирает вместе с ним, лямбда не нужна
	p.finished.connect(p.queue_free)

# ------------------------------------------------------------------ МУЗЫКА
var _scales := {
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"major": [0, 2, 4, 5, 7, 9, 11],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"hijaz": [0, 1, 4, 5, 7, 8, 11],
	"harmonic": [0, 2, 3, 5, 7, 8, 11],
}

func _midi_freq(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

## Генерирует 4 слоя для настроения карты: ambient / tension / combat / boss.
func play_music(mood: Dictionary, boss_layer_only: bool = false) -> void:
	_ensure_players()
	var key := JSON.stringify(mood)
	_boss_active = boss_layer_only
	if key == _mood_key:
		_apply_layer_volumes()
		return
	_mood_key = key
	var root := int(mood.get("root", 48))
	var scale_name := String(mood.get("scale", "minor"))
	var scale: Array = _scales.get(scale_name, _scales["minor"])
	var tempo := float(mood.get("tempo", 80))
	for i in 4:
		_layers[i].stream = _make_layer(i, root, scale, tempo)
		_layers[i].play()
	_apply_layer_volumes()

func _make_layer(layer: int, root: int, scale: Array, tempo: float) -> AudioStreamWAV:
	var n := int(MUSIC_LEN * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var beat := 60.0 / maxf(tempo, 30.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 + layer * 771 + root * 31
	var notes: Array = []
	match layer:
		0: # ambient — длинный пэд
			for step in 2:
				notes.append({"t": step * MUSIC_LEN * 0.5, "len": MUSIC_LEN * 0.5, "note": root + scale[(step * 2) % scale.size()], "vol": 0.16, "shape": "sine"})
		1: # tension — пульс
			var steps := int(MUSIC_LEN / (beat * 0.5))
			for s in steps:
				var deg: int = scale[(s / 2) % scale.size()]
				notes.append({"t": s * beat * 0.5, "len": beat * 0.45, "note": root + 12 + deg, "vol": 0.10, "shape": "tri"})
		2: # combat — арпеджио + ритм
			var steps2 := int(MUSIC_LEN / (beat * 0.25))
			for s in steps2:
				var deg2: int = scale[(s * 2) % scale.size()]
				notes.append({"t": s * beat * 0.25, "len": beat * 0.22, "note": root + 12 + deg2 + (12 if s % 8 == 0 else 0), "vol": 0.09, "shape": "saw"})
				if s % 4 == 0:
					notes.append({"t": s * beat * 0.25, "len": 0.09, "note": root - 12, "vol": 0.16, "shape": "sine", "noise": 0.5})
		3: # boss — низкий напор
			var steps3 := int(MUSIC_LEN / (beat * 0.5))
			for s in steps3:
				notes.append({"t": s * beat * 0.5, "len": beat * 0.5, "note": root - 12 + (0 if s % 2 == 0 else scale[4]), "vol": 0.13, "shape": "square", "noise": 0.08})
				if s % 4 == 0:
					notes.append({"t": s * beat * 0.5, "len": 0.14, "note": 30, "vol": 0.20, "shape": "sine", "noise": 0.6})
	for note in notes:
		var start := int(float(note["t"]) * RATE)
		var length := int(float(note["len"]) * RATE)
		var freq := _midi_freq(int(note["note"]))
		var shape := String(note.get("shape", "sine"))
		var vol := float(note.get("vol", 0.1))
		var noise_mix := float(note.get("noise", 0.0))
		var phase := 0.0
		for i in length:
			var idx := start + i
			if idx >= n:
				break
			var k := float(i) / maxf(float(length), 1.0)
			var env: float = sin(PI * clampf(k, 0.0, 1.0)) if k < 1.0 else 0.0
			phase += freq / RATE
			var s := _osc(phase, shape) * env * vol
			if noise_mix > 0.0:
				s = lerpf(s, rng.randf_range(-1.0, 1.0) * env * vol, noise_mix)
			samples[idx] += s
	# мягкое ограничение и сглаживание стыка лупа
	for i in n:
		samples[i] = clampf(samples[i], -0.9, 0.9)
	var fade := int(0.01 * RATE)
	for i in fade:
		var a := float(i) / fade
		samples[i] *= a
		samples[n - 1 - i] *= a
	return _wav(samples, true)

func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	_apply_layer_volumes()

func set_boss_layer(active: bool) -> void:
	_boss_active = active
	_apply_layer_volumes()

## Громкость слоёв: ambient всегда, tension при >20 врагов, combat при >50, boss заменяет всё.
func _apply_layer_volumes() -> void:
	if not _music_players_ready:
		return
	var ambient := lerpf(-18.0, -30.0, _intensity)
	var tension := lerpf(-60.0, -14.0, clampf(_intensity * 1.6, 0.0, 1.0))
	var combat := -60.0
	if _intensity > 0.5:
		combat = lerpf(-60.0, -10.0, clampf((_intensity - 0.5) * 2.0, 0.0, 1.0))
	var boss := -60.0
	if _boss_active:
		ambient = -60.0
		tension = -60.0
		combat = -60.0
		boss = -8.0
	_layers[0].volume_db = ambient
	_layers[1].volume_db = tension
	_layers[2].volume_db = combat
	_layers[3].volume_db = boss

func stop_music() -> void:
	for p in _layers:
		p.stop()
	_mood_key = ""

func apply_settings(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	apply_volumes()
