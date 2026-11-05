extends Node3D

const RunnerScript = preload("res://scripts/runner.gd")
const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio.gd")
var track: TrackData
var models: Dictionary = {}
var world: RooftopWorld
var camera: Camera3D
var runners: Array[RoofRunner] = []
var player: RoofRunner
var hud: SkylineHUD
var state := "menu"
var elapsed := 0.0
var countdown := 3.0
var taken_coins: Dictionary = {}
var final_rank := 0
var reward := 0
var doubled := false
var checkpoint_flash := 0.0
var last_checkpoint := 0.0
var dragging := false
var finger := -1
var drag_origin := Vector2.ZERO
var drag_start_x := 0.0
var drag_distance := 0.0
var ad_context := ""
var sample_clock := 0.0
var sample_count := 0
var performance_samples: Array[Dictionary] = []
var capture_path := ""
var capture_clock := 0.0
var benchmark := false
var fall_z := 0.0
var benchmark_save: Dictionary = {}
var audio: SkylineAudio
var slow_samples := 0
var frame_peak_calls := 0
var frame_peak_primitives := 0
var measured_frames := 0

func _ready() -> void:
	adapt_window()
	get_window().size_changed.connect(adapt_window)
	Input.emulate_touch_from_mouse = Platform.bridge == null
	audio = AudioScript.new()
	add_child(audio)
	var keys := ["runner_0", "runner_1", "runner_2", "accessory_cap", "accessory_backpack", "accessory_mohawk", "accessory_crown", "accessory_headphones", "roof_wide", "roof_narrow", "roof_short", "roof_raised", "roof_corner", "roof_slope", "boost", "crate", "wall", "rail", "coin", "finish", "checkpoint", "water_tower", "aircon", "chimney", "crane", "city_block", "shadow", "spark"]
	for key in keys:
		var category := "interactive"
		if key.begins_with("runner_"): category = "characters"
		elif key.begins_with("accessory_"): category = "accessories"
		elif key.begins_with("roof_"): category = "track"
		elif key in ["water_tower", "aircon", "chimney", "crane"]: category = "props"
		elif key == "city_block": category = "background"
		elif key in ["shadow", "spark"]: category = "effects"
		models[key] = load("res://assets/models/%s/%s.glb" % [category, key])
	track = TrackData.new()
	setup_environment()
	world = WorldScript.new()
	add_child(world)
	world.build(self)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HudScript.new()
	canvas.add_child(hud)
	hud.setup(self)
	reset_runners()
	Platform.rewarded.connect(_ad_finished)
	Platform.app_hidden.connect(_pause_on_hide)
	if Platform.low_end: get_viewport().scaling_3d_scale = .75
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg == "--race-preview": start_race(); countdown = 0; state = "race"
		if arg.begins_with("--screen=") and arg.trim_prefix("--screen=") in ["menu", "shop", "daily", "leaderboard"]: state = arg.trim_prefix("--screen=")
		if arg == "--benchmark":
			benchmark = true
			audio.muted = true
			benchmark_save = Save.data.duplicate(true)
			start_race()
			countdown = 0
			state = "race"
			player.ai_skill = .97
	update_camera(1.0)

func adapt_window() -> void:
	var window := get_window()
	var logical := Vector2i(960, 540) if window.size.x > window.size.y else Vector2i(540, 960)
	if window.content_scale_size != logical: window.content_scale_size = logical

func setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_color = Color("8ccbd5")
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("61b5cb")
	sky_material.sky_horizon_color = Color("c0e9df")
	sky_material.ground_horizon_color = Color("9ccfd4")
	sky_material.ground_bottom_color = Color("70b6c8")
	sky_material.sun_angle_max = 0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e9e3")
	env.ambient_light_energy = .8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("8ccbd5")
	env.fog_density = .0055
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color("fff3dc")
	sun.light_energy = .8
	sun.shadow_enabled = false
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 58
	camera.far = 130
	camera.current = true
	add_child(camera)

func reset_runners() -> void:
	finger = -1
	for racer in runners:
		remove_child(racer)
		racer.queue_free()
	runners.clear()
	for i in 7:
		var racer := RunnerScript.new()
		add_child(racer)
		racer.setup(i, self, models["runner_%d" % (i % 3)], Color(Save.COLORS[(i+1) % 8]))
		runners.append(racer)
	player = runners[0]
	taken_coins.clear()

func start_race() -> void:
	audio.start()
	reset_runners()
	elapsed = 0
	countdown = 3
	reward = 0
	final_rank = 0
	doubled = false
	last_checkpoint = 0
	performance_samples.clear()
	frame_peak_calls = 0
	frame_peak_primitives = 0
	measured_frames = 0
	state = "countdown"

func _physics_process(dt: float) -> void:
	checkpoint_flash = maxf(0, checkpoint_flash - dt)
	if state == "countdown":
		countdown -= dt
		if countdown <= 0: state = "race"
	elif state == "race":
		elapsed += dt
		if benchmark: player.update_ai(dt)
		var direction := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		if direction != 0: player.target_x = clampf(player.target_x + direction * dt * 10, -7.8, 7.8)
		for racer in runners: racer.tick(dt, elapsed)
		if player.checkpoint > last_checkpoint:
			last_checkpoint = player.checkpoint
			checkpoint_flash = 1.7
		if player.finished: finish_race()
	if state != "paused": world.update_view(player.position.z, dt)
	for racer in runners:
		racer.visible = absf(racer.position.z - player.position.z) < 70
		if racer.animation: racer.animation.speed_scale = 0 if state in ["paused", "revive"] else 1
	update_camera(dt)

func _process(dt: float) -> void:
	if state == "race":
		if elapsed > 2:
			frame_peak_calls = maxi(frame_peak_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			frame_peak_primitives = maxi(frame_peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			measured_frames += 1
		sample_clock += dt
		if sample_clock > 1 and elapsed > 2:
			sample_clock = 0
			performance_samples.append({"time": snappedf(elapsed, .01), "fps": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			slow_samples = slow_samples + 1 if Engine.get_frames_per_second() < 29 else 0
			if slow_samples >= 3 and not Platform.low_end:
				Platform.low_end = true
				get_viewport().scaling_3d_scale = .7
	if not capture_path.is_empty():
		capture_clock += dt
		if capture_clock > 3:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
			print("RENDER_METRICS ", JSON.stringify({"fps": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}))
			print("CAPTURE_OK ", capture_path)
			get_tree().quit()
			capture_path = ""

func update_camera(dt: float) -> void:
	var z := player.position.z
	var menu_view := state in ["menu", "shop", "daily", "leaderboard"]
	var desired := Vector3(14, 18, -22) if menu_view else Vector3(player.position.x * .3, 15.5, z - 18)
	var target := Vector3(0, 0, 8) if menu_view else Vector3(player.position.x * .25, .7, z + 12)
	camera.position = camera.position.lerp(desired, 1 - exp(-dt * 6))
	camera.look_at(target)
	camera.fov = lerpf(camera.fov, 64.0 if player.boost_left > 0 else 58.0, minf(1, dt * 4))

func collect_coins(racer: RoofRunner) -> void:
	for i in track.coins.size():
		if taken_coins.has(i): continue
		var coin := track.coins[i]
		if absf(racer.position.z - float(coin.z)) < 1 and absf(racer.position.x - float(coin.x)) < 1.0 and racer.position.y > -.5 and racer.position.y < 2:
			taken_coins[i] = true
			racer.collected += 1
			audio.cue("coin")
			world.burst(Vector3(coin.x, 1, coin.z), 3)

func emit_fx(pos: Vector3, kind: String) -> void:
	world.burst(pos, 12 if kind in ["boost", "hit"] else 5)
	audio.cue(kind)
	if kind == "hit": hud.say("碰到障碍了，寻找空隙继续跑")

func on_player_fall() -> void:
	finger = -1
	state = "revive"

func player_rank() -> int:
	if final_rank > 0: return final_rank
	var rank := 1
	for racer in runners:
		if racer == player: continue
		if racer.finished or racer.position.z > player.position.z: rank += 1
	return rank

func finish_race() -> void:
	final_rank = player_rank()
	reward = Save.complete_race(final_rank, elapsed, player.collected, player.boost_count)
	Platform.submit_score(elapsed)
	world.burst(player.position, 20)
	audio.cue("finish")
	state = "result"
	var file := FileAccess.open("user://performance_last_race.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(performance_samples, "\t"))
	if benchmark:
		var orientation := "landscape" if get_viewport().get_visible_rect().size.x > get_viewport().get_visible_rect().size.y else "portrait"
		var report := FileAccess.open("res://build/performance_%s.json" % orientation, FileAccess.WRITE)
		if report: report.store_string(JSON.stringify({"renderer": "Compatibility / OpenGL", "hardware": RenderingServer.get_video_adapter_name(), "viewport": {"width": get_viewport().get_visible_rect().size.x, "height": get_viewport().get_visible_rect().size.y}, "race_seconds": elapsed, "rank": final_rank, "measured_frames": measured_frames, "frame_peak_draw_calls": frame_peak_calls, "frame_peak_primitives": frame_peak_primitives, "samples": performance_samples}, "\t"))
		capture_path = "res://build/result_%s.png" % orientation
		capture_clock = 0
		Save.data = benchmark_save
		Save.persist()

func ui_action(action: String, extra := -1) -> void:
	match action:
		"start": start_race()
		"sound": audio.toggle()
		"pause":
			if state == "race": state = "paused"
		"resume":
			finger = -1
			state = "race"
		"home":
			Platform.hide_friend_board()
			state = "menu"
			reset_runners()
		"shop": state = "shop"
		"daily": state = "daily"
		"board": state = "leaderboard"
		"skin":
			if Save.buy_skin(extra): player.apply_skin()
			else: hud.say("金币不足，去屋顶跑一场吧")
		"claim":
			hud.say("奖励已存入钱包" if Save.claim_task(extra) else "完成挑战后即可领取，每天限领一次")
		"friends":
			if not Platform.show_friend_board(): hud.say("好友排行需在微信小游戏内查看")
		"double":
			if doubled: return
			ad_context = "double"
			Platform.request_ad()
		"revive_ad":
			ad_context = "revive"
			Platform.request_ad()
		"share":
			Platform.share_result(final_rank, elapsed)
			if Platform.bridge == null: hud.say("微信版本可分享本局战绩")

func _ad_finished(completed: bool) -> void:
	if not completed:
		hud.say("广告未配置或未完整观看，未发放奖励")
		return
	if ad_context == "double" and state == "result" and not doubled:
		doubled = true
		Save.data.coins += reward
		Save.persist()
		hud.say("双倍奖励已存入钱包")
	elif ad_context == "revive" and state == "revive":
		var safe_z := fall_z
		if not track.platform_at(0, safe_z):
			safe_z = (floorf((safe_z + 8) / TrackData.STRIDE) + 1) * TrackData.STRIDE - 6
		player.position = Vector3(0, 0, minf(safe_z, TrackData.FINISH - 3))
		player.target_x = 0
		player.invulnerable = 2
		state = "race"

func _pause_on_hide() -> void:
	finger = -1
	if state == "race": state = "paused"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if state == "race": state = "paused"
		elif state == "paused": state = "race"
	if state != "race": return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			drag_origin = event.position
			drag_start_x = player.target_x
			drag_distance = 0
		elif not event.pressed and event.index == finger:
			if drag_distance < 12:
				player.target_x = clampf(player.target_x + (-3.5 if event.position.x < get_viewport().get_visible_rect().size.x * .5 else 3.5), -7.8, 7.8)
			finger = -1
	elif event is InputEventScreenDrag and event.index == finger:
		var delta: float = event.position.x - drag_origin.x
		drag_distance = maxf(drag_distance, absf(delta))
		player.target_x = clampf(drag_start_x + delta / get_viewport().get_visible_rect().size.x * 18, -7.8, 7.8)
