class_name SuitAudio
extends Node
## Quiet procedural suit/radio sounds, no copyrighted or external recordings.
var ambient: AudioStreamPlayer
var feedback: AudioStreamPlayer
var enabled: bool = true

func _exit_tree() -> void:
	# Stop playback before the audio server disposes its mix-thread references.
	if is_instance_valid(ambient):
		ambient.stop()
		ambient.stream = null
	if is_instance_valid(feedback):
		feedback.stop()
		feedback.stream = null

func _ready() -> void:
	ambient = AudioStreamPlayer.new()
	add_child(ambient)
	feedback = AudioStreamPlayer.new()
	add_child(feedback)
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050 * 6
	var bytes := PackedByteArray()
	bytes.resize(stream.loop_end * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var noise: float = 0.0
	for i in range(stream.loop_end):
		var t := float(i) / 22050
		noise = lerpf(noise, rng.randf_range(-1, 1), 0.08)
		var breath := pow(maxf(0, sin(t * TAU / 6)), 2) * 0.025 * noise
		var hum := sin(t * TAU * 51) * 0.006 + sin(t * TAU * 76) * 0.002
		bytes.encode_s16(i * 2, int((breath + hum) * 32767))
	stream.data = bytes
	ambient.stream = stream
	ambient.play()

func cue(kind: String = "confirm") -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration: float = 0.3 if kind == "unlock" else 0.12
	var samples := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / 22050
		var frequency: float = 520.0 if kind == "confirm" else 780.0
		if kind == "unlock":
			frequency = 440.0 + floor(t * 10) * 220
		if kind == "warning": frequency = 180.0
		var envelope := sin(PI * float(i) / samples) * 0.11
		var value := sin(t * frequency * TAU) * envelope
		bytes.encode_s16(i * 2, int(value * 32767))
	stream.data = bytes
	feedback.stream = stream
	feedback.play()
