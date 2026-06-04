## CRTAudio.gd
## Attach to an AudioStreamPlayer node.
## Generates a CRT monitor hum (60Hz buzz + white noise) procedurally.
extends AudioStreamPlayer

@export var hum_volume_db: float = 28.0   # overall volume
@export var hum_frequency: float = 60.0    # 60Hz mains hum
@export var noise_mix: float = 0.12        # how much hiss vs pure tone
@export var harmonic_mix: float = 0.35     # adds 180Hz harmonic for richness

const SAMPLE_RATE = 22050
const BUFFER_SIZE = 512

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _phase2: float = 0.0

func _ready() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	volume_db = hum_volume_db
	play()
	_playback = get_stream_playback()

func _process(_delta: float) -> void:
	_fill_buffer()

func _fill_buffer() -> void:
	var frames = _playback.get_frames_available()
	if frames <= 0:
		return

	var increment  = hum_frequency * TAU / SAMPLE_RATE
	var increment2 = (hum_frequency * 3.0) * TAU / SAMPLE_RATE  # 3rd harmonic

	var frames_array = PackedVector2Array()
	frames_array.resize(frames)

	for i in range(frames):
		_phase  = fmod(_phase  + increment,  TAU)
		_phase2 = fmod(_phase2 + increment2, TAU)

		var hum      = sin(_phase)
		var harmonic = sin(_phase2) * harmonic_mix
		var noise    = randf_range(-1.0, 1.0) * noise_mix
		var sample   = (hum + harmonic + noise) / (1.0 + harmonic_mix + noise_mix)

		frames_array[i] = Vector2(sample, sample)

	_playback.push_frames(frames_array)
