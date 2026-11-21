extends Node
## Autoload "Sfx": sound effects and music. Every sound is synthesized by tools/gen_audio.py.
## play()      UI / global sounds
## play_at()   world sounds: louder near the camera, silent under fog or far away
## Volumes are stored in user://settings.cfg.

const SOUNDS := ["click", "select", "order", "error", "sword1", "sword2", "sword3", "hit1", "hit2", "bow", "arrow_hit",
	"fire_cast", "explosion", "catapult", "roar", "chop1", "chop2", "mine1", "mine2", "mana", "hammer1", "hammer2",
	"death1", "death2", "collapse", "complete", "ready", "research", "alert", "levelup", "age_up", "cast", "frost",
	"heal", "shrine", "victory", "defeat"]
const POOL := 20
const MAX_PER_WINDOW := {"sword": 3, "hit": 3, "arrow_hit": 3, "bow": 3, "chop": 2, "mine": 2, "hammer": 2, "death": 3, "explosion": 3}

var streams := {}
var pool: Array = []
var next := 0
var music: AudioStreamPlayer
var recent := {}
var music_vol := 0.6
var sfx_vol := 0.8
var muted := false
var game: Game = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for n in SOUNDS:
		var path := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	if ResourceLoader.exists("res://sounds/music.ogg"):
		var m: AudioStreamOggVorbis = load("res://sounds/music.ogg")
		m.loop = true
		music.stream = m
	add_child(music)
	_load_settings()
	_apply_volumes()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("no_click"):
		n.pressed.connect(play.bind("click", -6.0))


func _variant(n: String) -> String:
	if streams.has(n):
		return n
	var opts: Array = []
	for i in range(1, 5):
		if streams.has(n + str(i)):
			opts.append(n + str(i))
	return "" if opts.is_empty() else opts[randi() % opts.size()]


func _throttled(n: String) -> bool:
	var lim: int = MAX_PER_WINDOW.get(n, 4)
	var now := Time.get_ticks_msec()
	var arr: Array = recent.get(n, [])
	arr = arr.filter(func(t): return now - t < 160)
	if arr.size() >= lim:
		recent[n] = arr
		return true
	arr.append(now)
	recent[n] = arr
	return false


func play(n: String, vol_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if muted or sfx_vol <= 0.001:
		return
	var key := _variant(n)
	if key == "" or _throttled(n):
		return
	var p: AudioStreamPlayer = pool[next]
	next = (next + 1) % POOL
	p.stream = streams[key]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## World sound at a 3D position, attenuated by distance to what the camera is looking at.
func play_at(n: String, pos: Vector3, vol_db: float = 0.0) -> void:
	if game == null or not is_instance_valid(game) or game.cam == null:
		return
	var p2 := Vector2(pos.x, pos.z)
	if not game.fog_visible(p2):
		return
	var f := game.cam.focus
	var d := Vector2(f.x, f.z).distance_to(p2)
	var reach := game.cam.dist * 1.1 + 8.0
	if d > reach:
		return
	var att := 1.0 - d / reach
	var zoom := clampf(34.0 / game.cam.dist, 0.55, 1.2)
	play(n, vol_db + linear_to_db(maxf(att * zoom, 0.05)))


func play_music() -> void:
	if music.stream and not music.playing:
		music.play()


# ---------------------------------------------------------------- volume settings
func set_volumes(m: float, s: float) -> void:
	music_vol = m
	sfx_vol = s
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_vol, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music_vol <= 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_vol, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx_vol <= 0.001)


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		music_vol = cf.get_value("audio", "music", music_vol)
		sfx_vol = cf.get_value("audio", "sfx", sfx_vol)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.save("user://settings.cfg")


func _on_slider(v: float, which: String) -> void:
	if which == "music":
		set_volumes(v, sfx_vol)
	else:
		set_volumes(music_vol, v)
		play("click")


## Builds a pair of labelled volume sliders (used in the pause menu and the title screen).
func volume_controls() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	for pair in [["Music", "music"], ["Effects", "sfx"]]:
		var l := Label.new()
		l.text = pair[0]
		grid.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(180, 32)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value = music_vol if pair[1] == "music" else sfx_vol
		s.focus_mode = Control.FOCUS_NONE
		var which: String = pair[1]
		s.value_changed.connect(_on_slider.bind(which))
		grid.add_child(s)
	return grid
