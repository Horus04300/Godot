extends Node

var voices: Array[AudioStreamPlayer] = []
var enabled = true
var clips: Dictionary = {}
var music: AudioStreamPlayer
var levels = {"master": 0.8, "music": 0.55, "effects": 0.8}
var settings_path = "user://audio_settings.json"
var settings_error = ""
var last_rarity = -1

func _exit_tree() -> void:
	stop_all()
	voices.clear()
	clips.clear()

func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null

func _ready() -> void:
	for kind in ["slash", "hit", "dash", "coin", "reward", "hurt", "skill", "finisher"]:
		clips[kind] = _make_clip(kind)
	for i in 10:
		var player = AudioStreamPlayer.new()
		player.volume_db = -16
		add_child(player)
		voices.append(player)
	for rank in 6:
		clips["rarity%d" % rank] = _make_clip("rarity%d" % rank)
	music = AudioStreamPlayer.new()
	var stream: AudioStreamMP3 = load("res://audio/Sunrise_Over_the_Elder_Grove.mp3")
	if stream == null:
		settings_error = "배경 음악을 읽지 못했습니다."
		push_error(settings_error)
	else:
		stream.loop = true
		music.stream = stream
	add_child(music)
	_apply_levels()

func start_music() -> void:
	if music.stream != null and not music.playing:
		music.play()

func _apply_levels() -> void:
	music.volume_db = linear_to_db(maxf(0.00001, levels.master * levels.music))
	music.stream_paused = not enabled or levels.master == 0 or levels.music == 0
	for voice in voices:
		voice.volume_db = -16 + linear_to_db(maxf(0.00001, levels.master * levels.effects))

func set_level(key: String, value: float) -> void:
	assert(levels.has(key))
	levels[key] = clampf(value, 0, 1)
	_apply_levels()

func set_muted(value: bool) -> void:
	enabled = not value
	_apply_levels()
	if value:
		for voice in voices:
			voice.stop()

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var file = FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		_audio_error("사운드 설정을 읽지 못했습니다.")
		return
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		_audio_error("사운드 설정 파일이 손상되었습니다. 기존 파일을 보존합니다.")
		return
	for key in levels:
		if not parser.data.has(key) or not (parser.data[key] is float or parser.data[key] is int):
			_audio_error("사운드 설정 형식이 올바르지 않습니다.")
			return
		if not is_finite(parser.data[key]) or parser.data[key] < 0 or parser.data[key] > 1:
			_audio_error("사운드 설정 범위가 올바르지 않습니다.")
			return
	if parser.data.has("muted") and not parser.data.muted is bool:
		_audio_error("음소거 설정 형식이 올바르지 않습니다.")
		return
	for key in levels:
		levels[key] = float(parser.data[key])
	enabled = not parser.data.get("muted", false)
	_apply_levels()

func save_settings() -> bool:
	if not settings_error.is_empty():
		return false
	var file = FileAccess.open(settings_path + ".tmp", FileAccess.WRITE)
	if file == null:
		_audio_error("사운드 설정을 저장하지 못했습니다.")
		return false
	var data = levels.duplicate()
	data.muted = not enabled
	file.store_string(JSON.stringify(data))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(settings_path + ".tmp"), ProjectSettings.globalize_path(settings_path)) != OK:
		_audio_error("사운드 설정 파일 교체에 실패했습니다.")
		return false
	return true

func _audio_error(message: String) -> void:
	settings_error = message
	push_error(message)

func play_rarity(rank: int) -> void:
	last_rarity = rank
	play_tone("rarity%d" % rank)

func play_tone(kind: String) -> void:
	if not enabled:
		return
	var player: AudioStreamPlayer
	for voice in voices:
		if not voice.playing:
			player = voice
			break
	if player == null:
		return
	player.stream = clips[kind]
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()

func _make_clip(kind: String) -> AudioStreamWAV:
	var duration = 0.12
	var frequency = 300.0
	match kind:
		"slash": frequency = 170.0
		"hit": frequency = 95.0
		"dash": frequency = 440.0
		"coin": frequency = 980.0
		"reward": frequency = 660.0; duration = 0.25
		"hurt": frequency = 65.0; duration = 0.2
		"skill": frequency = 210.0; duration = 0.3
		"finisher": frequency = 115.0; duration = 0.21
	if kind.begins_with("rarity"):
		var rank = int(kind.trim_prefix("rarity"))
		duration = 0.25 + rank * 0.12
		frequency = 350 + rank * 85
	var samples = int(22050 * duration)
	var data = PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t = float(i) / 22050.0
		var envelope = pow(1.0 - float(i) / samples, 2.0)
		var wave = sin(TAU * frequency * t * (1.0 - t * 1.4))
		if kind.begins_with("rarity"):
			var rank = int(kind.trim_prefix("rarity"))
			var note = floor(t / 0.09)
			wave = sin(TAU * frequency * pow(2, fmod(note, rank + 1) / 12.0 * 3) * t)
			for harmonic in rank:
				wave += sin(TAU * frequency * (1.5 + harmonic * 0.5) * t) * 0.13
		if kind in ["slash", "hit", "finisher", "skill"]:
			var noise = sin(float(i * i) * 12.9898) * 0.35 * exp(-t * 35)
			var body = sin(TAU * 54 * t * exp(-t * 4)) * exp(-t * 18)
			wave = wave * 0.28 + noise + body * 0.42
		data.encode_s16(i * 2, int(clampf(wave * envelope, -1, 1) * 24000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
