# music.gd
extends AudioStreamPlayer2D

@export var music_stream: AudioStream = null
@export var default_volume_db: float = -16.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	volume_db = default_volume_db
	
	if music_stream:
		stream = music_stream
		_force_loop()
	
	play_music()  # Auto start


func _force_loop() -> void:
	if not stream:
		print("⚠️ No music stream assigned!")
		return
		
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		print("✅ OGG loop enabled")
	elif stream is AudioStreamWAV:
		var wav = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = 0
		print("✅ WAV loop enabled")
	elif stream is AudioStreamMP3:
		stream.loop = true
		print("✅ MP3 loop enabled")


func play_music(new_stream: AudioStream = null) -> void:
	if new_stream:
		stream = new_stream
		_force_loop()
	
	if stream and not playing:
		play()
		print("🎵 Music started playing")
	else:
		print("⚠️ Music failed to play - check stream assignment")


func stop_music() -> void:
	stop()
