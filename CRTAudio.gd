## CRTAudio.gd
extends AudioStreamPlayer2D

@export var hum_volume_db: float = -28.0
@export var hum_frequency: float = 60.0
@export var noise_mix: float = 0.12
@export var harmonic_mix: float = 0.35

const SAMPLE_RATE = 22050

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _phase2: float = 0.0
var _ready_to_fill: bool = false

func _ready() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.5
	stream = gen
	volume_db = hum_volume_db
	max_distance = 99999.0   # ← ensures 2D distance never mutes it
	attenuation = 0.0        # ← no distance falloff
	play()

func _process(_delta: float) -> void:
	if not _ready_to_fill:
		_playback = get_stream_playback()
		_ready_to_fill = true
		return
	if _playback == null:
		return
	_fill_buffer()

func _fill_buffer() -> void:
	var frames = _playback.get_frames_available()
	if frames <= 0:
		return

	var inc1 = hum_frequency * TAU / SAMPLE_RATE
	var inc2 = (hum_frequency * 3.0) * TAU / SAMPLE_RATE

	for i in range(frames):
		_phase  = fmod(_phase  + inc1, TAU)
		_phase2 = fmod(_phase2 + inc2, TAU)
		var s = (sin(_phase) + sin(_phase2) * harmonic_mix + randf_range(-1.0, 1.0) * noise_mix)
		s /= (1.0 + harmonic_mix + noise_mix)
		_playback.push_frame(Vector2(s, s))
