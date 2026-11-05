class_name SkylineAudio
extends Node
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var clips: Dictionary = {}
var cursor := 0
var muted := false

func _ready() -> void:
	muted = DisplayServer.get_name() == "headless"
	for key in ["coin", "jump", "boost", "hit", "finish"]:
		clips[key] = load("res://assets/audio/%s.mp3" % key)
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	var loop: AudioStreamMP3 = load("res://assets/audio/city_loop.mp3")
	loop.loop = true
	music.stream = loop
	music.volume_db = -22
	add_child(music)

func start() -> void:
	if not music.playing and not muted: music.play()

func toggle() -> void:
	muted = not muted
	music.stream_paused = muted
	if not muted: start()

func cue(key: String) -> void:
	if muted or not clips.has(key): return
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = clips[key]
	voice.play()

func shutdown() -> void:
	if music:
		music.stop()
		music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	clips.clear()

func _exit_tree() -> void:
	shutdown()
