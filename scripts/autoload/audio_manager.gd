extends Node
## AudioManager — шины, качественный многослойный SFX-синтез,
## тематический эмбиент для каждой карты и адаптивная боевая/босс-музыка.

const RATE := 22050
const MUSIC_LEN := 8.0        # длина лупа музыкальных слоёв, сек (2-тактовая фраза)
const AMB_LEN := 5.0          # длина лупа эмбиента карты, сек
const MAX_SFX_VOICES := 16

var music_volume := 0.8
var sfx_volume := 0.8
var _sfx_cache: Dictionary = {}
var _amb_cache: Dictionary = {}
var _music_cache: Dictionary = {}
var _layers: Array[AudioStreamPlayer] = []
var _amb_player: AudioStreamPlayer = null
var _mood_key: String = ""
var _amb_key: String = ""
var _intensity: float = 0.0
var _cur_intensity: float = 0.0
var _boss_active := false
var _cur_boss: float = 0.0
var _music_players_ready := false
var _active_sfx: int = 0
var _menu_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_sfx()
	_ensure_players()

func _process(delta: float) -> void:
	if not _music_players_ready:
		return
	var target_boss := 1.0 if _boss_active else 0.0
	if absf(_cur_intensity - _intensity) > 0.002 or absf(_cur_boss - target_boss) > 0.002 or _layers[0].playing:
		_cur_intensity = move_toward(_cur_intensity, _intensity, delta * 1.4)
		_cur_boss = move_toward(_cur_boss, target_boss, delta * 1.8)
		_apply_layer_volumes()

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
	_set_bus_db("Ambience", music_volume * 0.72)
	_set_bus_db("SFX", sfx_volume)
	_set_bus_db("UI", sfx_volume)

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
		var v := int(clampf(tanh(samples[i] * 1.15), -1.0, 1.0) * 32000.0)
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
		"organ": return 0.65 * sin(phase * TAU) + 0.25 * sin(phase * TAU * 2.0) + 0.12 * sin(phase * TAU * 3.0)
		_: return sin(phase * TAU)

## Слоистый синтез SFX: тон + гармоника + фильтрованный шум + щелчок атаки.
func _sfx_layered(dur: float, f0: float, f1: float, shape: String, decay: float, noise: float = 0.0, vol: float = 0.4, sub_mix: float = 0.0, click: float = 0.0) -> AudioStreamWAV:
	var n := maxi(64, int(dur * RATE))
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var sub_phase := 0.0
	var lp_noise := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 1000.0 + dur * 170.0 + noise * 91.0)
	for i in n:
		var t := float(i) / RATE
		var k := t / maxf(dur, 0.001)
		var atk := minf(1.0, t / 0.004)
		var freq: float = lerpf(f0, f1, pow(k, 0.72))
		phase += freq / RATE
		sub_phase += (freq * 0.5) / RATE
		var env: float = atk * exp(-decay * k) * (1.0 - k * 0.12)
		var s := _osc(phase, shape) * (1.0 - sub_mix) + _osc(sub_phase, "sine") * sub_mix
		if noise > 0.0:
			var raw_n := rng.randf_range(-1.0, 1.0)
			lp_noise = lerpf(lp_noise, raw_n, 0.35)
			s = lerpf(s, lp_noise, noise)
		var out := s * env
		if click > 0.0 and t < 0.014:
			out += rng.randf_range(-1.0, 1.0) * click * (1.0 - t / 0.014)
		samples[i] = out * vol
	return _wav(samples)

## Аккорд / арпеджио для наград, побед и прокачки.
func _chord_sfx(freqs: Array, dur: float, shape: String = "tri", stagger: float = 0.05, vol: float = 0.28) -> AudioStreamWAV:
	var n := maxi(128, int(dur * RATE))
	var samples := PackedFloat32Array()
	samples.resize(n)
	for idx in freqs.size():
		var f := float(freqs[idx])
		var start := int(float(idx) * stagger * RATE)
		var ph := 0.0
		var ph2 := 0.0
		for i in range(start, n):
			var k := float(i - start) / maxf(1.0, float(n - start))
			var atk := minf(1.0, float(i - start) / (0.008 * RATE))
			var env := atk * exp(-3.2 * k)
			ph += f / RATE
			ph2 += (f * 1.003) / RATE
			samples[i] += (_osc(ph, shape) * 0.65 + _osc(ph2, "sine") * 0.35) * env * vol / maxf(1.0, sqrt(float(freqs.size())))
	return _wav(samples)

func _build_sfx() -> void:
	_sfx_cache["shot"] = _sfx_layered(0.11, 780.0, 145.0, "saw", 7.2, 0.32, 0.36, 0.25, 0.45)
	_sfx_cache["shot_heavy"] = _sfx_layered(0.22, 260.0, 52.0, "saw", 4.6, 0.42, 0.48, 0.45, 0.55)
	_sfx_cache["shot_magic"] = _sfx_layered(0.16, 1180.0, 440.0, "organ", 4.8, 0.08, 0.30, 0.20, 0.0)
	_sfx_cache["shot_bow"] = _sfx_layered(0.11, 520.0, 210.0, "tri", 6.5, 0.18, 0.32, 0.15, 0.35)
	_sfx_cache["shot_lightning"] = _sfx_layered(0.16, 1750.0, 320.0, "square", 5.2, 0.52, 0.30, 0.10, 0.40)
	_sfx_cache["reload"] = _sfx_layered(0.12, 340.0, 580.0, "square", 8.5, 0.35, 0.25, 0.0, 0.50)
	_sfx_cache["hit"] = _sfx_layered(0.07, 460.0, 140.0, "tri", 10.5, 0.45, 0.24, 0.30, 0.30)
	_sfx_cache["crit"] = _sfx_layered(0.15, 1320.0, 880.0, "saw", 5.8, 0.20, 0.34, 0.15, 0.45)
	_sfx_cache["kill"] = _sfx_layered(0.14, 280.0, 68.0, "saw", 6.5, 0.40, 0.30, 0.40, 0.25)
	_sfx_cache["hurt"] = _sfx_layered(0.24, 220.0, 58.0, "saw", 3.6, 0.35, 0.46, 0.45, 0.35)
	_sfx_cache["xp"] = _sfx_layered(0.08, 1320.0, 1980.0, "sine", 7.8, 0.0, 0.19, 0.15, 0.0)
	_sfx_cache["gold"] = _chord_sfx([1318.5, 1760.0, 2093.0], 0.20, "tri", 0.04, 0.28)
	_sfx_cache["levelup"] = _chord_sfx([440.0, 554.37, 659.25, 880.0], 0.65, "organ", 0.07, 0.36)
	_sfx_cache["chest"] = _chord_sfx([392.0, 493.88, 587.33, 783.99], 0.55, "tri", 0.06, 0.34)
	_sfx_cache["boss"] = _sfx_layered(1.10, 98.0, 41.0, "saw", 1.3, 0.28, 0.52, 0.55, 0.25)
	_sfx_cache["phase"] = _chord_sfx([146.83, 220.0, 293.66, 349.23], 0.85, "saw", 0.04, 0.42)
	_sfx_cache["ui"] = _sfx_layered(0.045, 840.0, 620.0, "tri", 11.0, 0.05, 0.20, 0.1, 0.18)
	_sfx_cache["error"] = _sfx_layered(0.20, 210.0, 145.0, "saw", 4.2, 0.10, 0.28, 0.3, 0.0)
	_sfx_cache["skill"] = _sfx_layered(0.32, 620.0, 280.0, "organ", 3.2, 0.22, 0.32, 0.25, 0.20)
	_sfx_cache["dash"] = _sfx_layered(0.18, 420.0, 160.0, "sine", 5.5, 0.65, 0.26, 0.0, 0.15)
	_sfx_cache["freeze"] = _sfx_layered(0.24, 1760.0, 2640.0, "sine", 4.8, 0.15, 0.25, 0.0, 0.1)
	_sfx_cache["fire"] = _sfx_layered(0.28, 260.0, 460.0, "saw", 3.8, 0.58, 0.28, 0.25, 0.12)
	_sfx_cache["lightning"] = _sfx_layered(0.28, 2100.0, 260.0, "square", 3.2, 0.62, 0.30, 0.15, 0.45)
	_sfx_cache["smite"] = _chord_sfx([523.25, 783.99, 1046.5], 0.40, "organ", 0.02, 0.34)
	_sfx_cache["secret"] = _chord_sfx([293.66, 440.0, 587.33, 880.0, 1174.6], 0.95, "organ", 0.09, 0.36)
	_sfx_cache["sathan"] = _sfx_layered(1.50, 74.0, 32.0, "saw", 0.85, 0.38, 0.56, 0.60, 0.2)
	_sfx_cache["victory"] = _chord_sfx([392.0, 493.88, 587.33, 783.99, 987.77], 1.05, "organ", 0.08, 0.40)
	_sfx_cache["defeat"] = _chord_sfx([293.66, 261.63, 220.0, 174.61], 1.00, "saw", 0.14, 0.34)

func _ensure_players() -> void:
	if not _music_players_ready:
		for i in 4:
			var p := AudioStreamPlayer.new()
			p.bus = "Music"
			p.volume_db = -60.0
			add_child(p)
			_layers.append(p)
		_music_players_ready = true
	if _amb_player == null:
		_amb_player = AudioStreamPlayer.new()
		_amb_player.bus = "Ambience"
		_amb_player.volume_db = -20.0
		add_child(_amb_player)

func _exit_tree() -> void:
	_release_audio()

func _release_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.queue_free()
	_layers.clear()
	_amb_player = null
	_sfx_cache.clear()
	_amb_cache.clear()
	_music_cache.clear()

func play_sfx(sfx_name: String, pitch: float = 1.0, bus: String = "SFX") -> void:
	if not _sfx_cache.has(sfx_name):
		return
	if sfx_volume <= 0.001:
		return
	if _active_sfx >= MAX_SFX_VOICES and not (sfx_name in ["levelup", "boss", "phase", "victory", "defeat", "hurt"]):
		return
	_active_sfx += 1
	var p := AudioStreamPlayer.new()
	p.stream = _sfx_cache[sfx_name]
	p.bus = bus
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.volume_db = -5.5
	add_child(p)
	p.play()
	p.finished.connect(func() -> void:
		_active_sfx = maxi(0, _active_sfx - 1)
		if is_instance_valid(p):
			p.queue_free())

# ------------------------------------------------------------------ ЭМБИЕНТ КАРТ
## Проработанный процедурный эмбиент по характеру каждой из 13 карт.
func play_ambience(map_id: String) -> void:
	_ensure_players()
	if map_id == "":
		stop_ambience()
		return
	if map_id == _amb_key and _amb_player.playing:
		return
	_amb_key = map_id
	if not _amb_cache.has(map_id):
		_amb_cache[map_id] = _make_ambience(map_id)
	_amb_player.stream = _amb_cache[map_id]
	_amb_player.volume_db = -17.0
	_amb_player.play()

func stop_ambience() -> void:
	if _amb_player != null:
		_amb_player.stop()
	_amb_key = ""

func _make_ambience(map_id: String) -> AudioStreamWAV:
	var n := int(AMB_LEN * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + map_id.hash()
	# Параметры характера карты: ветер, гул, переливы/капли/треск
	var cfg := {
		"sands":     {"wind": 0.24, "whistle": 540.0, "rumble": 58.0, "rumble_amt": 0.08, "chime": 0.0, "drip": 0.0, "hum": 0.0},
		"tundra":    {"wind": 0.28, "whistle": 760.0, "rumble": 64.0, "rumble_amt": 0.07, "chime": 1320.0, "drip": 0.0, "hum": 0.0},
		"peak":      {"wind": 0.16, "whistle": 420.0, "rumble": 44.0, "rumble_amt": 0.22, "chime": 0.0, "drip": 0.0, "hum": 0.0},
		"abyss":     {"wind": 0.10, "whistle": 290.0, "rumble": 50.0, "rumble_amt": 0.14, "chime": 880.0, "drip": 0.25, "hum": 0.0},
		"forest":    {"wind": 0.15, "whistle": 360.0, "rumble": 72.0, "rumble_amt": 0.05, "chime": 1046.0, "drip": 0.12, "hum": 0.0},
		"rift":      {"wind": 0.14, "whistle": 620.0, "rumble": 48.0, "rumble_amt": 0.15, "chime": 988.0, "drip": 0.0, "hum": 135.0},
		"graveyard": {"wind": 0.20, "whistle": 310.0, "rumble": 55.0, "rumble_amt": 0.10, "chime": 440.0, "drip": 0.10, "hum": 0.0},
		"hive":      {"wind": 0.10, "whistle": 240.0, "rumble": 62.0, "rumble_amt": 0.12, "chime": 0.0, "drip": 0.15, "hum": 168.0},
		"bloodmoon": {"wind": 0.18, "whistle": 390.0, "rumble": 46.0, "rumble_amt": 0.18, "chime": 587.0, "drip": 0.0, "hum": 92.0},
		"chaos":     {"wind": 0.18, "whistle": 680.0, "rumble": 52.0, "rumble_amt": 0.16, "chime": 1175.0, "drip": 0.0, "hum": 195.0},
		"temple":    {"wind": 0.11, "whistle": 340.0, "rumble": 58.0, "rumble_amt": 0.13, "chime": 659.0, "drip": 0.18, "hum": 110.0},
		"throne":    {"wind": 0.20, "whistle": 460.0, "rumble": 42.0, "rumble_amt": 0.24, "chime": 0.0, "drip": 0.0, "hum": 82.0},
		"void":      {"wind": 0.12, "whistle": 260.0, "rumble": 38.0, "rumble_amt": 0.22, "chime": 740.0, "drip": 0.0, "hum": 74.0},
	}
	var c: Dictionary = cfg.get(map_id, cfg["sands"])
	var wind_amt := float(c["wind"])
	var whistle_f := float(c["whistle"])
	var rumble_f := float(c["rumble"])
	var rumble_amt := float(c["rumble_amt"])
	var chime_f := float(c["chime"])
	var hum_f := float(c["hum"])
	var drip_amt := float(c["drip"])

	var lp := 0.0
	var bp_prev := 0.0
	var ph_wh := 0.0
	var ph_rm := 0.0
	var ph_hm := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, 0.045)
		var gust := 0.55 + 0.45 * sin(TAU * t / AMB_LEN * 2.0 + 0.4)
		var air := (lp * 0.7 + (lp - bp_prev) * 1.4) * wind_amt * gust
		bp_prev = lp

		ph_wh += (whistle_f * (1.0 + 0.06 * sin(TAU * t / AMB_LEN))) / RATE
		var wh := sin(ph_wh * TAU) * 0.035 * wind_amt * gust

		ph_rm += rumble_f / RATE
		var rm := (sin(ph_rm * TAU) * 0.7 + sin(ph_rm * TAU * 1.5) * 0.3) * rumble_amt

		var hm := 0.0
		if hum_f > 0.0:
			ph_hm += (hum_f * (1.0 + 0.03 * sin(TAU * t * 3.0))) / RATE
			hm = (_osc(ph_hm, "saw") * 0.4 + _osc(ph_hm * 1.01, "sine") * 0.6) * 0.08
		samples[i] = air + wh + rm + hm

	# Редкие кристальные переливы / капли / далёкий колокол
	if chime_f > 0.0:
		for k in 3:
			var start := int((0.6 + float(k) * 1.55) * AMB_LEN / 5.0 * RATE)
			var f := chime_f * (1.0 if k % 2 == 0 else 1.25)
			var ph := 0.0
			for i in int(0.8 * RATE):
				if start + i >= n:
					break
				var kk := float(i) / (0.8 * RATE)
				ph += f / RATE
				samples[start + i] += sin(ph * TAU) * exp(-4.0 * kk) * 0.06
	if drip_amt > 0.0:
		for k in 4:
			var start2 := int((0.4 + float(k) * 1.15) * RATE)
			var ph2 := 0.0
			for i in int(0.14 * RATE):
				if start2 + i >= n:
					break
				var kk2 := float(i) / (0.14 * RATE)
				ph2 += lerpf(650.0, 1250.0, kk2) / RATE
				samples[start2 + i] += sin(ph2 * TAU) * exp(-6.0 * kk2) * drip_amt * 0.14

	var fade := int(0.08 * RATE)
	for i in fade:
		var a := float(i) / float(fade)
		samples[i] *= a
		samples[n - 1 - i] *= a
	return _wav(samples, true)

# ------------------------------------------------------------------ МУЗЫКА
var _scales := {
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"major": [0, 2, 4, 5, 7, 9, 11],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"hijaz": [0, 1, 4, 5, 7, 8, 11],
	"harmonic": [0, 2, 3, 5, 7, 8, 11],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"locrian": [0, 1, 3, 5, 6, 8, 10],
	"whole_tone": [0, 2, 4, 6, 8, 10],
}

func _midi_freq(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

## Выделенная тема главного меню: тёплый тёмно-фэнтези лютневый/струнный мотив,
## полностью глушит эмбиент и боевые слои карт, чтобы музыка никогда не накладывалась.
func play_menu_music() -> void:
	_ensure_players()
	stop_ambience()
	_intensity = 0.0
	_cur_intensity = 0.0
	_boss_active = false
	_cur_boss = 0.0
	_menu_mode = true
	if _mood_key == "__menu__" and _layers[0].playing:
		for i in range(1, 4):
			if _layers[i].playing:
				_layers[i].stop()
		_apply_layer_volumes()
		return
	for p in _layers:
		p.stop()
	_mood_key = "__menu__"
	if not _music_cache.has("__menu__"):
		_music_cache["__menu__"] = [_make_menu_theme()]
	var streams: Array = _music_cache["__menu__"]
	_layers[0].stream = streams[0]
	_layers[0].play()
	_apply_layer_volumes()

func _make_menu_theme() -> AudioStreamWAV:
	var dur := 12.0
	var n := int(dur * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	# Аккордовая прогрессия в D minor (i -> VI -> III -> VII -> iv -> i -> V -> i)
	var root := 50 # D3
	var chords := [
		[0, 3, 7, 12],    # Dm
		[-4, 0, 3, 8],    # Bb
		[-9, -5, -2, 3],  # F
		[-2, 2, 5, 10],   # C
		[5, 8, 12, 17],   # Gm
		[0, 3, 7, 12],    # Dm
		[7, 11, 14, 19],  # A
		[0, 3, 7, 12],    # Dm
	]
	var bar := dur / float(chords.size()) # 1.5 сек на такт
	var notes: Array = []
	var melody_offsets := [12, 15, 14, 12, 10, 12, 19, 15, 17, 15, 14, 10, 12, 14, 11, 12]
	for b in chords.size():
		var t0 := float(b) * bar
		var ch: Array = chords[b]
		# Глубокий струнный бас + тёплая квинта
		notes.append({"t": t0, "len": bar * 0.98, "note": root + int(ch[0]) - 12, "vol": 0.14, "shape": "tri", "env": "pad", "lp": 0.18})
		notes.append({"t": t0, "len": bar * 0.98, "note": root + int(ch[2]), "vol": 0.08, "shape": "sine", "env": "pad", "lp": 0.25})
		# Перебор лютни / арфы (6 нот на такт)
		for step in 6:
			var nt: int = ch[step % ch.size()]
			var oct := 12 if step >= 4 else 0
			notes.append({"t": t0 + float(step) * (bar / 6.0), "len": 0.72, "note": root + nt + oct, "vol": 0.11, "shape": "tri", "env": "pluck", "lp": 0.35})
		# Выразительная ведущая мелодия (2 ноты на такт)
		var m1: int = melody_offsets[(b * 2) % melody_offsets.size()]
		var m2: int = melody_offsets[(b * 2 + 1) % melody_offsets.size()]
		notes.append({"t": t0 + bar * 0.05, "len": bar * 0.55, "note": root + m1 + 12, "vol": 0.095, "shape": "organ", "env": "bow", "lp": 0.28})
		notes.append({"t": t0 + bar * 0.55, "len": bar * 0.45, "note": root + m2 + 12, "vol": 0.085, "shape": "sine", "env": "bow", "lp": 0.32})
		# Редкий хрустальный колокольчик в начале фраз
		if b % 2 == 0:
			notes.append({"t": t0, "len": 1.15, "note": root + int(ch[2]) + 24, "vol": 0.045, "shape": "sine", "env": "pluck", "lp": 0.45})
	_render_notes(samples, n, notes, 7771)
	var fade := int(0.05 * RATE)
	for i in fade:
		var a := float(i) / float(fade)
		samples[i] *= a
		samples[n - 1 - i] *= a
	return _wav(samples, true)

## Генерирует 4 адаптивных музыкальных слоя для настроения карты: ambient / tension / combat / boss.
func play_music(mood: Dictionary, boss_layer_only: bool = false) -> void:
	_ensure_players()
	if bool(mood.get("menu", false)):
		play_menu_music()
		return
	var key := JSON.stringify(mood)
	_boss_active = boss_layer_only
	if key == _mood_key and not _menu_mode and _layers[0].playing:
		_apply_layer_volumes()
		return
	_menu_mode = false
	_cur_intensity = _intensity
	_cur_boss = 1.0 if _boss_active else 0.0
	for p in _layers:
		p.stop()
	_mood_key = key
	if not _music_cache.has(key):
		var root := int(mood.get("root", 48))
		var scale_name := String(mood.get("scale", "minor"))
		var scale: Array = _scales.get(scale_name, _scales["minor"])
		var tempo := float(mood.get("tempo", 80))
		var wave := String(mood.get("wave", "organ"))
		var arr: Array = []
		for i in 4:
			arr.append(_make_layer(i, root, scale, tempo, wave))
		_music_cache[key] = arr
	var cached: Array = _music_cache[key]
	for i in 4:
		_layers[i].stream = cached[i]
		_layers[i].play()
	_apply_layer_volumes()

func _wave_profile(wave: String) -> Dictionary:
	match wave:
		"oud", "lute": return {"lead": "tri", "pad": "organ", "env": "pluck", "lp": 0.34}
		"ice", "crystal": return {"lead": "sine", "pad": "sine", "env": "pluck", "lp": 0.48}
		"flute": return {"lead": "sine", "pad": "tri", "env": "bow", "lp": 0.30}
		"organ", "choir": return {"lead": "organ", "pad": "organ", "env": "pad", "lp": 0.24}
		"lava", "brass": return {"lead": "saw", "pad": "organ", "env": "bow", "lp": 0.22}
		"noise", "swarm", "glitch", "dissonant": return {"lead": "saw", "pad": "square", "env": "pluck", "lp": 0.26}
		_: return {"lead": "tri", "pad": "organ", "env": "bow", "lp": 0.28}

func _render_notes(samples: PackedFloat32Array, n: int, notes: Array, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for note in notes:
		var start := int(float(note["t"]) * RATE)
		var length := int(float(note["len"]) * RATE)
		if length <= 8:
			continue
		var freq := _midi_freq(int(note["note"]))
		var shape := String(note.get("shape", "sine"))
		var vol := float(note.get("vol", 0.1))
		var noise_mix := float(note.get("noise", 0.0))
		var env_mode := String(note.get("env", "bow"))
		var lp_cut := clampf(float(note.get("lp", 0.32)), 0.08, 0.95)
		var phase := 0.0
		var phase2 := 0.0
		var lp := 0.0
		for i in length:
			var idx := start + i
			if idx >= n:
				break
			var k := float(i) / maxf(float(length), 1.0)
			var env := 1.0
			match env_mode:
				"pluck":
					var atk := minf(1.0, k * 45.0)
					env = atk * exp(-3.6 * k) * (1.0 - pow(k, 4.0))
				"pad":
					var atk_p := minf(1.0, k * 4.5)
					var rel_p := minf(1.0, (1.0 - k) * 4.5)
					env = atk_p * rel_p
				_:
					var atk_b := minf(1.0, k * 14.0)
					var rel_b := minf(1.0, (1.0 - k) * 6.0)
					env = atk_b * rel_b
			phase += freq / RATE
			phase2 += (freq * 1.0035) / RATE
			var raw := (_osc(phase, shape) * 0.72 + _osc(phase2, shape) * 0.28)
			if noise_mix > 0.0:
				raw = lerpf(raw, rng.randf_range(-1.0, 1.0), noise_mix)
			lp = lerpf(lp, raw, lp_cut)
			samples[idx] += lp * env * vol
	for i in n:
		samples[i] = clampf(tanh(samples[i] * 1.05), -0.92, 0.92)

func _make_layer(layer: int, root: int, scale: Array, tempo: float, wave: String = "organ") -> AudioStreamWAV:
	var n := int(MUSIC_LEN * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var beat := 60.0 / maxf(tempo, 36.0)
	var prof := _wave_profile(wave)
	var lead_sh := String(prof["lead"])
	var pad_sh := String(prof["pad"])
	var lp_cut := float(prof["lp"])
	var prog := [0, 5, 2, 4] # 4-тактная прогрессия (каждая по 2.0 сек)
	var notes: Array = []
	match layer:
		0: # ambient — тёплая 4-аккордная подложка + спокойный перебор темы карты
			for bar in 4:
				var deg: int = scale[prog[bar] % scale.size()]
				var third: int = scale[(prog[bar] + 2) % scale.size()]
				var fifth: int = scale[(prog[bar] + 4) % scale.size()]
				var t0 := float(bar) * 2.0
				notes.append({"t": t0, "len": 1.98, "note": root + deg - 12, "vol": 0.13, "shape": "sine", "env": "pad", "lp": 0.20})
				notes.append({"t": t0, "len": 1.98, "note": root + deg, "vol": 0.10, "shape": pad_sh, "env": "pad", "lp": lp_cut * 0.85})
				notes.append({"t": t0, "len": 1.98, "note": root + fifth, "vol": 0.075, "shape": "sine", "env": "pad", "lp": 0.25})
				# Тематический мотив карты на 4 шага в такте
				var motif := [deg, third, fifth, third + 12]
				for k in 4:
					notes.append({"t": t0 + float(k) * 0.5, "len": 0.65, "note": root + 12 + int(motif[k]), "vol": 0.075, "shape": lead_sh, "env": String(prof["env"]), "lp": lp_cut})
		1: # tension — ритмичный басовый пульс + минорные акценты и тихий хэт
			var steps := int(MUSIC_LEN / (beat * 0.5))
			for s in steps:
				var bar := mini(3, int((float(s) * beat * 0.5) / 2.0))
				var base_deg: int = scale[prog[bar] % scale.size()]
				var deg2: int = scale[(prog[bar] + (s % 3) * 2) % scale.size()]
				notes.append({"t": s * beat * 0.5, "len": beat * 0.44, "note": root + 12 + deg2, "vol": 0.095, "shape": lead_sh, "env": "pluck", "lp": lp_cut})
				if s % 2 == 0:
					notes.append({"t": s * beat * 0.5, "len": beat * 0.50, "note": root - 12 + base_deg, "vol": 0.13, "shape": "tri", "env": "pluck", "lp": 0.22})
				if s % 2 == 1:
					notes.append({"t": s * beat * 0.5, "len": 0.045, "note": 76, "vol": 0.05, "shape": "sine", "noise": 0.9, "env": "pluck", "lp": 0.45})
		2: # combat — энергичное арпеджио по прогрессии + чёткий грув
			var steps2 := int(MUSIC_LEN / (beat * 0.25))
			var arp := [0, 2, 4, 2, 5, 4, 2, 1]
			for s in steps2:
				var bar2 := mini(3, int((float(s) * beat * 0.25) / 2.0))
				var root_deg: int = scale[prog[bar2] % scale.size()]
				var deg3: int = scale[(prog[bar2] + arp[s % arp.size()]) % scale.size()]
				var oct := 12 if (s % 4 != 3) else 24
				notes.append({"t": s * beat * 0.25, "len": beat * 0.24, "note": root + oct + deg3, "vol": 0.10, "shape": lead_sh, "env": "pluck", "lp": lp_cut + 0.08})
				if s % 4 == 0:
					notes.append({"t": s * beat * 0.25, "len": 0.13, "note": root - 24 + (root_deg % 5), "vol": 0.21, "shape": "sine", "noise": 0.30, "env": "pluck", "lp": 0.35})
				elif s % 4 == 2:
					notes.append({"t": s * beat * 0.25, "len": 0.08, "note": 62, "vol": 0.10, "shape": "tri", "noise": 0.80, "env": "pluck", "lp": 0.45})
		3: # boss — эпичная напряжённая босс-тема: двойная бочка, хоровой аккорд, лид-рифф
			var steps3 := int(MUSIC_LEN / (beat * 0.25))
			var riff := [0, 0, 4, 3, 2, 4, 5, 4]
			for s in steps3:
				var bar3 := mini(3, int((float(s) * beat * 0.25) / 2.0))
				var deg4: int = scale[(prog[bar3] + riff[(s / 2) % riff.size()]) % scale.size()]
				if s % 4 == 0:
					notes.append({"t": s * beat * 0.25, "len": beat * 0.95, "note": root - 12 + deg4, "vol": 0.13, "shape": "saw", "env": "bow", "lp": 0.24})
					notes.append({"t": s * beat * 0.25, "len": beat * 0.95, "note": root + deg4 + 7, "vol": 0.095, "shape": "organ", "env": "pad", "lp": 0.28})
				if s % 2 == 0:
					notes.append({"t": s * beat * 0.25, "len": beat * 0.42, "note": root + 12 + scale[(prog[bar3] + s + 1) % scale.size()], "vol": 0.095, "shape": "saw", "env": "pluck", "lp": 0.32})
				if s % 2 == 0:
					notes.append({"t": s * beat * 0.25, "len": 0.14, "note": 34, "vol": 0.23, "shape": "sine", "noise": 0.40, "env": "pluck", "lp": 0.35})
				if s % 8 == 4:
					notes.append({"t": s * beat * 0.25, "len": 0.11, "note": 65, "vol": 0.14, "shape": "saw", "noise": 0.82, "env": "pluck", "lp": 0.40})

	_render_notes(samples, n, notes, 12345 + layer * 771 + root * 31)
	var fade := int(0.03 * RATE)
	for i in fade:
		var a := float(i) / float(fade)
		samples[i] *= a
		samples[n - 1 - i] *= a
	return _wav(samples, true)

func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)

func set_boss_layer(active: bool) -> void:
	_boss_active = active

## Плавный баланс слоёв: ambient -> tension -> combat (от числа врагов) -> boss (при боссе) + приглушение на паузе.
func _apply_layer_volumes() -> void:
	if not _music_players_ready:
		return
	var pause_duck := -6.5 if (get_tree() != null and get_tree().paused and not _menu_mode) else 0.0
	if _menu_mode:
		_layers[0].volume_db = linear_to_db(0.32)
		for i in range(1, 4):
			_layers[i].volume_db = linear_to_db(0.0005)
		return
	var normal_mix := 1.0 - _cur_boss
	var ambient_lin := lerpf(0.24, 0.09, _cur_intensity) * normal_mix
	var tension_lin := clampf(_cur_intensity * 1.4, 0.0, 1.0) * 0.28 * normal_mix
	var combat_lin := clampf((_cur_intensity - 0.35) / 0.65, 0.0, 1.0) * 0.36 * normal_mix
	var boss_lin := _cur_boss * 0.44
	_layers[0].volume_db = linear_to_db(maxf(0.0005, ambient_lin)) + pause_duck
	_layers[1].volume_db = linear_to_db(maxf(0.0005, tension_lin)) + pause_duck
	_layers[2].volume_db = linear_to_db(maxf(0.0005, combat_lin)) + pause_duck
	_layers[3].volume_db = linear_to_db(maxf(0.0005, boss_lin)) + pause_duck
	if _amb_player != null:
		var amb_lin := lerpf(0.20, 0.09, _cur_intensity) * (1.0 - _cur_boss * 0.55)
		_amb_player.volume_db = linear_to_db(maxf(0.0005, amb_lin)) + pause_duck

func stop_music() -> void:
	for p in _layers:
		p.stop()
	stop_ambience()
	_mood_key = ""
	_menu_mode = false
	_intensity = 0.0
	_cur_intensity = 0.0
	_boss_active = false
	_cur_boss = 0.0

func apply_settings(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	apply_volumes()
