extends Node

var voices: Array[AudioStreamPlayer] = []
var enabled = true

func _exit_tree() -> void:
	stop_all()
	voices.clear()

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

func _ready() -> void:
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
	var duration = 0.09
	var frequency = 300.0
	match kind:
		"slash": frequency = 170.0
		"hit": frequency = 95.0
		"dash": frequency = 440.0
		"coin": frequency = 980.0
		"reward": frequency = 660.0; duration = 0.25
		"hurt": frequency = 65.0; duration = 0.2
		"skill": frequency = 210.0; duration = 0.3
	var samples = int(22050 * duration)
	var data = PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t = float(i) / 22050.0
		var envelope = pow(1.0 - float(i) / samples, 2.0)
		var wave = sin(TAU * frequency * t * (1.0 - t * 1.4))
		if kind == "slash" or kind == "hit":
			wave = wave * 0.45 + sin(float(i * i) * 12.9898) * 0.3
		data.encode_s16(i * 2, int(wave * envelope * 20000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	player.stream = stream
	player.play()
