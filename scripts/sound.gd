extends Node

var voices: Array[AudioStreamPlayer] = []
var enabled = true
var clips: Dictionary = {}

func _exit_tree() -> void:
	stop_all()
	voices.clear()
	clips.clear()

func stop_all() -> void:
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
	var samples = int(22050 * duration)
	var data = PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t = float(i) / 22050.0
		var envelope = pow(1.0 - float(i) / samples, 2.0)
		var wave = sin(TAU * frequency * t * (1.0 - t * 1.4))
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
