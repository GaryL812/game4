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
var race_rng := RandomNumberGenerator.new()
var camera_height := 0.0
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
var capture_delay := 3.0
var benchmark := false
var benchmark_save: Dictionary = {}
var audio: SkylineAudio
var slow_samples := 0
var frame_peak_calls := 0
var frame_peak_primitives := 0
var measured_frames := 0
var benchmark_next_log := 10.0
var finish_reveal := 1.0
var camera_shake_left := 0.0

func _ready() -> void:
	Engine.max_fps=60
	race_rng.randomize()
	adapt_window()
	get_window().size_changed.connect(adapt_window)
	Input.emulate_touch_from_mouse = Platform.bridge == null
	audio = AudioScript.new()
	add_child(audio)
	var keys := ["deck_stone","deck_wood","deck_eaves","deck_bridge","basket","screen","bell","ink_pad","cloud_pad","coin","shadow","ink_drop"]
	for key in keys:
		var category := "interactive"
		if key.begins_with("deck_"): category = "track"
		elif key in ["shadow", "ink_drop"]: category = "effects"
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
	var paper := ColorRect.new()
	canvas.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var paper_material := ShaderMaterial.new()
	paper_material.shader=preload("res://scripts/paper_overlay.gdshader")
	paper_material.set_shader_parameter("paper_grain",load("res://assets/textures/paper_grain.png"))
	paper.material=paper_material
	reset_runners()
	Platform.rewarded.connect(_ad_finished)
	Platform.app_hidden.connect(_pause_on_hide)
	if Platform.low_end: get_viewport().scaling_3d_scale = .75
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-delay="): capture_delay=arg.trim_prefix("--capture-delay=").to_float()
		if arg in ["--review-climb", "--review-side"]:
			state="race"
			var roof: Dictionary=track.sections[1][0]
			player.grounded=false
			if arg=="--review-climb": player.position=Vector3(roof.x,float(roof.height)-1.5,float(roof.start)-.4)
			else: player.position=Vector3(float(roof.x)-float(roof.width)*.5-.3,float(roof.height)-1.5,float(roof.start)+7)
			player.target_x=player.position.x
		if arg=="--review-boost":
			state="race"
			var pad: Dictionary=track.boosts[0]
			player.position=Vector3(pad.x,pad.y,float(pad.z)-.2)
			player.target_x=player.position.x
			player.grounded=true
		if arg == "--race-preview": start_race(); countdown = 0; state = "race"
		if arg.begins_with("--screen=") and arg.trim_prefix("--screen=") in ["menu", "shop", "daily", "leaderboard"]: state = arg.trim_prefix("--screen=")
		if arg == "--benchmark":
			benchmark = true
			race_rng.seed = 55213
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
	env.background_color = Color("e9e4d2")
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("e2ddc9")
	sky_material.sky_horizon_color = Color("f1ecd9")
	sky_material.ground_horizon_color = Color("ede8d5")
	sky_material.ground_bottom_color = Color("dcdcca")
	sky_material.sun_angle_max = 0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f1ecdb")
	env.ambient_light_energy = .8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("e9e4d2")
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
	camera.far = 230
	camera.current = true
	add_child(camera)

func reset_runners() -> void:
	finger = -1
	for racer in runners:
		remove_child(racer)
		racer.queue_free()
	runners.clear()
	var rival_skins: Array = []
	for i in 7:
		var racer := RunnerScript.new()
		add_child(racer)
		var skin: int = Save.data.skin
		if i > 0:
			# Draw without replacement within each pass through the skin pool.
			if rival_skins.is_empty():
				rival_skins = Save.RIVAL_SKINS.duplicate()
				rival_skins.shuffle()
			skin = rival_skins.pop_back()
		racer.setup(i, self, skin)
		runners.append(racer)
	player = runners[0]
	for i in runners.size():
		var racer := runners[i]
		var stage: int=[0,0,1,3,4,6,7][i]
		var routes: Array=track.sections[stage]
		var roof: Dictionary=routes[race_rng.randi_range(0,routes.size()-1)]
		var z := race_rng.randf_range(-4.5,-2.0) if i==0 else float(roof.start)+race_rng.randf_range(11,17)
		if i==1: z=race_rng.randf_range(3,7)
		if i==2: z=race_rng.randf_range(38,42)
		var half := float(roof.width)*.5-.9
		var x := float(roof.x)+race_rng.randf_range(-minf(half,4.5),minf(half,4.5))
		racer.position = Vector3(x,float(roof.height),z)
		racer.target_x = racer.position.x
		racer.remember_safe(roof)
	taken_coins.clear()
	hud.reset_progress_scroll()
	hud.reset_energy_bar()
	world.reset_combat()
	camera_shake_left = 0
	camera.h_offset = 0
	camera.v_offset = 0
	update_runner_visibility()

func start_race() -> void:
	audio.start()
	reset_runners()
	elapsed = 0
	countdown = 3
	reward = 0
	final_rank = 0
	doubled = false
	performance_samples.clear()
	frame_peak_calls = 0
	frame_peak_primitives = 0
	measured_frames = 0
	state = "countdown"

func _physics_process(dt: float) -> void:
	if state == "countdown":
		countdown -= dt
		if countdown <= 0: state = "race"
	elif state == "race":
		elapsed += dt
		if benchmark and elapsed>=benchmark_next_log:
			print("BENCHMARK_PROGRESS ",elapsed," z=",player.position.z," mode=",player.traversal)
			benchmark_next_log+=10
		if benchmark and elapsed>140:
			push_error("Benchmark exceeded 140s: "+str(player.position))
			get_tree().quit(1)
		if benchmark: player.update_ai(dt)
		var direction := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		if direction != 0: player.target_x = clampf(player.target_x + screen_horizontal(direction) * dt * 10, -10, 10)
		for racer in runners: racer.tick(dt, elapsed)
		if player.finished: finish_race()
	elif state == "result":
		for racer in runners:
			if racer.finished: racer.tick(dt,elapsed)
	if state != "paused": world.update_view(player.position.z, dt)
	update_runner_visibility()
	update_camera(dt)

func update_runner_visibility() -> void:
	world.sword_fx.set_frozen(state != "race")
	# Keep two nearby rivals on screen. The others remain physically farther away,
	# simulating their actual progress outside the drawing window.
	var first: RoofRunner=null
	var second: RoofRunner=null
	var first_distance := INF
	var second_distance := INF
	for racer in runners:
		if racer.is_player or racer.defeated_left > 0: continue
		var delta := racer.position.z-player.position.z
		if delta < -10 or delta > 52: continue
		var distance := absf(delta)
		if distance<first_distance:
			second=first
			second_distance=first_distance
			first=racer
			first_distance=distance
		elif distance<second_distance:
			second=racer
			second_distance=distance
	for racer in runners:
		racer.visible=racer.is_player or racer==first or racer==second
		racer.paper_visual.paused = state == "paused"

func _process(dt: float) -> void:
	if state=="result": finish_reveal=minf(1,finish_reveal+dt*1.6)
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
		if capture_clock > capture_delay:
			var output_path := capture_path
			capture_path=""
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_path)
			print("RENDER_METRICS ", JSON.stringify({"fps": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}))
			print("CAPTURE_OK ", output_path)
			audio.shutdown()
			await get_tree().create_timer(.08).timeout
			get_tree().quit()

func update_camera(dt: float) -> void:
	var z := player.position.z
	var menu_view := state in ["menu", "shop", "daily", "leaderboard"]
	var roof_y := track.height_at(player.position.x,z)
	if not is_finite(roof_y): roof_y = player.safe_position.y
	var desired_y := maxf(roof_y,player.position.y-1.5)
	camera_height=lerpf(camera_height,desired_y,1-exp(-dt*3.2))
	var follow_x := player.position.x*.6
	if player.traversal=="side_slide": follow_x=player.position.x+player.wall_side*4.5
	var landscape := get_window().content_scale_size.x > get_window().content_scale_size.y
	var camera_lift := 5.9 if landscape else 7.0
	var follow_distance := 9.4 if landscape else 11.5
	var desired := Vector3(follow_x, camera_height + camera_lift, z - follow_distance)
	var target := Vector3(player.position.x * .45, camera_height + 2.45, z + 13.0)
	if menu_view:
		desired = Vector3(1.7, camera_height + camera_lift + .8, -16.0)
		target = Vector3(-.6, camera_height + 2.5, 16.0)
	camera.position = camera.position.lerp(desired, 1 - exp(-dt * 6))
	camera.look_at(target)
	camera.fov = lerpf(camera.fov, 64.0 if player.charge_left > 0 or player.boost_left > 0 or player.slash_boost_left > 0 else 58.0, minf(1, dt * 4))
	if state != "paused": camera_shake_left = maxf(0, camera_shake_left - dt)
	var shake := .065 * camera_shake_left / .1
	camera.h_offset = sin(camera_shake_left * 360) * shake
	camera.v_offset = cos(camera_shake_left * 290) * shake * .65

func collect_coins(racer: RoofRunner) -> void:
	for i in track.coins.size():
		if taken_coins.has(i): continue
		var coin := track.coins[i]
		if absf(racer.position.z - float(coin.z)) < 1 and absf(racer.position.x - float(coin.x)) < 1.0 and absf(racer.position.y-(float(coin.y)-1.0)) < 1.5:
			taken_coins[i] = true
			racer.collected += 1
			racer.charge_from_coin()
			audio.cue("coin")
			world.burst(Vector3(coin.x, coin.y, coin.z), 3,"coin")

func emit_fx(pos: Vector3, kind: String) -> void:
	if kind in ["jump", "land", "boost"]:
		world.sword_fx.footfall(pos, kind, player)
	else:
		world.burst(pos, 2 if kind == "hit" else 5, kind)
	audio.cue(kind)

func on_player_fall() -> void:
	finger = -1
	# Recovery is immediate and keeps the race running.

func player_rank() -> int:
	if final_rank > 0: return final_rank
	var rank := 1
	for racer in runners:
		if racer == player: continue
		if racer.finished or racer.position.z > player.position.z: rank += 1
	return rank

func finish_race() -> void:
	if state == "result": return
	player.cancel_attack()
	world.sword_fx.clear()
	final_rank = player_rank()
	reward = Save.complete_race(final_rank, elapsed, player.collected, player.boost_count)
	Platform.submit_score(elapsed)
	world.burst(player.position, 20)
	audio.cue("finish")
	state = "result"
	finish_reveal=0
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

func _pause_on_hide() -> void:
	finger = -1
	if state == "race": state = "paused"

func screen_horizontal(offset: float) -> float:
	# Running toward +Z makes screen-right point toward negative world X.
	return offset * signf(camera.global_basis.x.x)

func _unhandled_input(event: InputEvent) -> void:
	if benchmark: return
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
				var direction := -1 if event.position.x < get_viewport().get_visible_rect().size.x*.5 else 1
				var current_lane := clampi(roundi(player.target_x/6.0)+1,0,2)
				player.target_x=TrackData.LANES[clampi(current_lane+int(screen_horizontal(direction)),0,2)]
			finger = -1
	elif event is InputEventScreenDrag and event.index == finger:
		var delta: float = event.position.x - drag_origin.x
		drag_distance = maxf(drag_distance, absf(delta))
		player.target_x = clampf(drag_start_x + screen_horizontal(delta) / get_viewport().get_visible_rect().size.x * 20, -10, 10)
