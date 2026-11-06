extends Control

const PAPER_GRAIN = preload("res://assets/textures/paper_grain.png")
const PIGMENT = preload("res://samples/ink_study/pigment.gdshader")
const MARK_SHADER = preload("res://samples/ink_study/ink_mark.gdshader")
const COMPOSITE = preload("res://samples/ink_study/paper_composite.gdshader")
const DECK = preload("res://assets/models/track/deck_stone.glb")
const HERO = preload("res://assets/models/characters/runner_wanderer.glb")
const INK_CARD = preload("res://assets/models/effects/ink_drop.glb")
const MODE_NAMES = ["奔跑", "跳跃", "攀爬", "加速"]
const MODE_ARGS = ["run", "jump", "climb", "boost"]
const MODE_PERIODS = [5.2, 2.1, 2.35, 1.9]
const MARK_CAP = 20

enum Mode { RUN, JUMP, CLIMB, BOOST }
enum Mark { TRAIL, DROP, RING }

var paint_view: SubViewport
var hero: Node3D
var animator: AnimationPlayer
var marks_mesh: MultiMesh
var marks: Array[Dictionary] = []
var mark_cursor := 0
var mode := Mode.RUN
var action_time := 0.0
var previous_phase := -1.0
var trail_clock := 0.0
var current_clip := ""
var status: Label
var capture_path := ""
var capture_time := 1.45
var paused := false

func _ready() -> void:
	Engine.max_fps = 60
	get_window().content_scale_size = Vector2i(1280, 800)
	get_window().title = "水墨材质小样"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			var index := MODE_ARGS.find(argument.trim_prefix("--mode="))
			if index >= 0:
				mode = index
		elif argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--at="):
			capture_time = argument.trim_prefix("--at=").to_float()
	build_stage()
	build_controls()
	resized.connect(resize_paint_buffer)
	resize_paint_buffer()
	set_pose(0.0)

func paper_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	if shader != PIGMENT:
		material.set_shader_parameter("paper_grain", PAPER_GRAIN)
	return material

func build_stage() -> void:
	paint_view = SubViewport.new()
	paint_view.own_world_3d = true
	paint_view.transparent_bg = true
	paint_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(paint_view)

	var deck := DECK.instantiate() as Node3D
	paint_view.add_child(deck)
	deck.scale = Vector3(6.8 / 14.0, 1.27 / 8.2, 4.9 / 24.0)
	deck.position.y = -1.27
	var ground := paper_material(PIGMENT)
	ground.set_shader_parameter("ground", true)
	paint_model(deck, ground)

	hero = HERO.instantiate() as Node3D
	paint_view.add_child(hero)
	paint_model(hero, paper_material(PIGMENT))
	animator = hero.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Run", "Climb"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

	var camera := Camera3D.new()
	paint_view.add_child(camera)
	camera.position = Vector3(5.7, 4.1, 7.5)
	camera.look_at(Vector3(0.0, -.30, 0.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.15
	camera.make_current()
	create_mark_pool()

	var picture := TextureRect.new()
	picture.texture = paint_view.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.material = paper_material(COMPOSITE)
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func paint_model(model: Node3D, material: ShaderMaterial) -> void:
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func create_mark_pool() -> void:
	var source := INK_CARD.instantiate()
	var source_mesh := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	marks_mesh = MultiMesh.new()
	marks_mesh.transform_format = MultiMesh.TRANSFORM_3D
	marks_mesh.use_custom_data = true
	marks_mesh.mesh = source_mesh.mesh
	marks_mesh.instance_count = MARK_CAP
	marks_mesh.visible_instance_count = 0
	marks_mesh.custom_aabb = AABB(Vector3(-5, -2, -4), Vector3(10, 5, 8))
	source.free()
	var renderer := MultiMeshInstance3D.new()
	renderer.multimesh = marks_mesh
	renderer.material_override = paper_material(MARK_SHADER)
	paint_view.add_child(renderer)
	for i in MARK_CAP:
		marks.append({"life": 0.0})

func resize_paint_buffer() -> void:
	paint_view.size = Vector2i((size * .85).max(Vector2(2.0, 2.0)))

func build_controls() -> void:
	var title := Label.new()
	title.text = "山海卷"
	title.position = Vector2(42.0, 34.0)
	title.add_theme_font_override("font", preload("res://assets/fonts/ink_bold.ttf"))
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("54453b"))
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "INK STUDY   /   01"
	subtitle.position = Vector2(45.0, 90.0)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("8c6c5a"))
	add_child(subtitle)
	var actions := HBoxContainer.new()
	add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	actions.position = Vector2(43.0, size.y - 65.0)
	actions.offset_top = -65.0
	actions.offset_bottom = -29.0
	actions.add_theme_constant_override("separation", 9)
	for i in MODE_NAMES.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d  %s" % [i + 1, MODE_NAMES[i]]
		button.custom_minimum_size = Vector2(98.0, 34.0)
		button.add_theme_font_override("font", preload("res://assets/fonts/ink.ttf"))
		button.add_theme_color_override("font_color", Color("54453b"))
		button.add_theme_color_override("font_hover_color", Color("855345"))
		var background := StyleBoxFlat.new()
		background.bg_color = Color("eee3cf")
		background.border_color = Color("baaa95")
		background.set_border_width_all(1)
		button.add_theme_stylebox_override("normal", background)
		button.add_theme_stylebox_override("hover", background)
		button.add_theme_stylebox_override("pressed", background)
		button.pressed.connect(select_mode.bind(i))
		actions.add_child(button)
	status = Label.new()
	status.add_theme_color_override("font_color", Color("786451"))
	actions.add_child(status)
	show_mode()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			select_mode(event.keycode - KEY_1)
		elif event.keycode == KEY_SPACE:
			paused = not paused
			animator.speed_scale = 0.0 if paused else 1.0
			show_mode()

func show_mode() -> void:
	status.text = "   %s    ·    SPACE 暂停" % [MODE_ARGS[mode].to_upper()]
	if paused:
		status.text += " Ⅱ"

func select_mode(next: int) -> void:
	mode = next
	action_time = 0.0
	previous_phase = -1.0
	trail_clock = 0.0
	paused = false
	animator.speed_scale = 1.0
	for mark in marks:
		mark.life = 0.0
	show_mode()
	set_pose(0.0)

func play_clip(clip: String, restart: bool) -> void:
	if clip != current_clip or restart:
		animator.play(clip, .08)
		animator.seek(0.0, true)
		current_clip = clip

func set_pose(dt: float) -> void:
	var period: float = MODE_PERIODS[mode]
	var phase := fmod(action_time, period)
	var restarted := phase < previous_phase or previous_phase < 0.0
	trail_clock += dt
	match mode:
		Mode.RUN:
			var angle := phase * TAU / period - 1.15
			hero.position = Vector3(sin(angle) * 1.85, 0.0, cos(angle) * .78)
			hero.rotation.y = atan2(cos(angle) * 1.85, -sin(angle) * .78)
			play_clip("Run", false)
			if trail_clock >= .11:
				trail_clock = 0.0
				emit_trail(false, false)
		Mode.JUMP:
			var travel := clampf(phase / .93, 0.0, 1.0)
			hero.position = Vector3(lerpf(-1.65, 1.20, travel), sin(travel * PI) * 1.15, .44)
			hero.rotation.y = PI * .5
			play_clip("Jump" if phase < .93 else "Land", restarted)
			if restarted:
				emit_drops(Vector3(-1.60, .055, .44), 6, false)
			if previous_phase < .93 and phase >= .93:
				emit_drops(hero.position + Vector3.UP * .06, 7, true)
		Mode.CLIMB:
			var climb := clampf(phase / 1.57, 0.0, 1.0)
			hero.position = Vector3(.49, lerpf(-1.28, .025, climb), lerpf(2.60, 2.20, smoothstep(.8, 1.0, climb)))
			hero.rotation.y = PI
			play_clip("Climb" if phase < 1.57 else "Land", restarted)
			if trail_clock >= .11 and climb < .96:
				trail_clock = 0.0
				emit_trail(true, true)
		Mode.BOOST:
			var travel := clampf(phase / .85, 0.0, 1.0)
			hero.position = Vector3(lerpf(-2.19, 2.03, travel), sin(travel * PI) * .61, .37)
			hero.rotation.y = PI * .5
			play_clip("Flip" if phase < .85 else "Land", restarted)
			if trail_clock >= .055 and phase < .89:
				trail_clock = 0.0
				emit_trail(true, false)
			if previous_phase < .85 and phase >= .85:
				emit_drops(hero.position + Vector3.UP * .06, 6, true)
	previous_phase = phase

func emit_trail(dense: bool, on_wall: bool) -> void:
	var basis := Basis(Vector3.RIGHT, PI * .5) if on_wall else Basis(Vector3.UP, hero.rotation.y)
	var location := hero.position
	if on_wall:
		location.z = 2.472
		location.y -= .11
	else:
		location -= hero.transform.basis.z * .24
		location.y = .018
		location += hero.transform.basis.x * (.12 if mark_cursor % 2 == 0 else -.12)
	var footprint := Vector3(.60 if dense else .31, 1.0, 1.52 if dense else .83)
	add_mark(Mark.TRAIL, location, basis, footprint, .97, .77 if dense else .50)

func emit_drops(origin: Vector3, count: int, landing: bool) -> void:
	for i in count:
		var angle := float(i) * TAU / count + .4
		var direction := Vector3(cos(angle), 0, sin(angle))
		var motion := direction * (1.15 + (i % 3) * .27)
		motion.y = .8 + (i % 4) * .34
		var size_value := .085 + (i % 4) * .036
		var start := origin + direction * (.25 + (i % 3) * .085)
		add_mark(Mark.DROP, start, Basis.IDENTITY, Vector3.ONE * size_value, .52 + i * .024, .91, motion)
	if landing:
		add_mark(Mark.RING, origin * Vector3(1, 0, 1) + Vector3.UP * .025, Basis.IDENTITY, Vector3(1.02, 1.0, 1.02), .75, .62)

func add_mark(kind: int, location: Vector3, basis: Basis, footprint: Vector3, life: float, strength: float, velocity := Vector3.ZERO) -> void:
	var mark := marks[mark_cursor]
	mark.kind = kind
	mark.position = location
	mark.basis = basis
	mark.footprint = footprint
	mark.life = life
	mark.duration = life
	mark.strength = strength
	mark.velocity = velocity
	mark.seed = fposmod(float(mark_cursor) * .617 + action_time * .37, 1.0)
	mark_cursor = (mark_cursor + 1) % MARK_CAP

func update_marks(dt: float) -> void:
	var active := 0
	for mark in marks:
		if mark.life <= 0.0:
			continue
		mark.life = maxf(0.0, mark.life - dt)
		if mark.life <= 0.0:
			continue
		mark.position += mark.velocity * dt
		if mark.kind == Mark.DROP:
			mark.velocity.y -= dt * 3.7
		var remaining := float(mark.life) / float(mark.duration)
		var expansion := lerpf(1.0, 2.45 if mark.kind == Mark.RING else 1.22, 1.0 - remaining)
		var basis: Basis = mark.basis * Basis.from_scale(mark.footprint * expansion)
		marks_mesh.set_instance_transform(active, Transform3D(basis, mark.position))
		marks_mesh.set_instance_custom_data(active, Color(float(mark.kind) / 3.0, remaining, mark.seed, mark.strength))
		active += 1
	marks_mesh.visible_instance_count = active

func _process(dt: float) -> void:
	if paused:
		return
	action_time += dt
	set_pose(dt)
	update_marks(dt)
	if not capture_path.is_empty() and action_time >= capture_time:
		set_process(false)
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(capture_path)
		print("INK_STUDY_CAPTURE ", MODE_ARGS[mode], " marks=", marks_mesh.visible_instance_count,
			" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit(0 if result == OK else 1)
