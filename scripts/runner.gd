class_name RoofRunner
extends Node3D

var runner_id := 0
var is_player := false
var speed := 11.0
var target_x := 0.0
var vertical_speed := 0.0
var grounded := true
var boost_left := 0.0
var stun_left := 0.0
var invulnerable := 0.0
var finished := false
var finish_time := 0.0
var checkpoint := 0.0
var collected := 0
var boost_count := 0
var falls := 0
var ai_clock := 0.0
var ai_skill := 0.8
var animation: AnimationPlayer
var visual: Node3D
var shadow: Node3D
var accessory: Node3D
var hit_obstacles: Dictionary = {}
var used_boosts: Dictionary = {}
var last_anim := ""
var flip_time := 0.0
var land_left := 0.0
var rng := RandomNumberGenerator.new()
var track: TrackData
var game

func setup(id: int, owner_game, model: PackedScene, tint: Color) -> void:
	runner_id = id
	game = owner_game
	track = game.track
	is_player = id == 0
	rng.seed = 1926 + id * 319
	ai_skill = [.0, .58, .65, .75, .82, .9, .97][id]
	speed = TrackData.BASE_SPEED + (id - 3) * .13 if id > 0 else TrackData.BASE_SPEED
	visual = model.instantiate()
	add_child(visual)
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = tint
		material.roughness = .9
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation = players[0]
		for anim_name in animation.get_animation_list():
			if anim_name.ends_with("Run") or anim_name.ends_with("Celebrate"):
				animation.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	shadow = game.models.shadow.instantiate()
	add_child(shadow)
	shadow.position.y = .035
	shadow.scale = Vector3(1.1, 1, .72)
	for mesh_node in shadow.find_children("*", "MeshInstance3D", true, false):
		mesh_node.mesh.surface_get_material(0).vertex_color_use_as_albedo = true
	var lane := float((id % 3) - 1) * 3.1
	position = Vector3(lane, 0, -float(id / 3) * 2.1)
	target_x = lane
	if is_player: apply_skin()
	play("Run")

func apply_skin() -> void:
	if accessory:
		accessory.queue_free()
		accessory = null
	var skin := int(Save.data.skin)
	var tint := Color(Save.COLORS[skin])
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		node.material_override.albedo_color = tint
	if skin >= 3:
		var keys := ["accessory_cap", "accessory_backpack", "accessory_mohawk", "accessory_headphones", "accessory_crown"]
		accessory = game.models[keys[skin - 3]].instantiate()
		visual.add_child(accessory)
		accessory.position = Vector3(0, 1.78, 0) if skin != 4 else Vector3(0, 1.04, -.2)

func play(key: String) -> void:
	if animation == null or last_anim == key: return
	for name_value in animation.get_animation_list():
		if name_value.ends_with(key):
			animation.play(name_value, .1)
			last_anim = key
			return

func tick(dt: float, elapsed: float) -> void:
	if finished:
		play("Celebrate")
		return
	boost_left = maxf(0, boost_left - dt)
	stun_left = maxf(0, stun_left - dt)
	invulnerable = maxf(0, invulnerable - dt)
	flip_time = maxf(0, flip_time - dt)
	land_left = maxf(0, land_left - dt)
	if not is_player: update_ai(dt)
	var actual_speed := speed * (1.6 if boost_left > 0 else 1.0) * (.32 if stun_left > 0 else 1.0)
	position.x = lerpf(position.x, target_x, 1.0 - exp(-dt * 8.0))
	# Sample the authored platform footprint. Equivalent to a downward ray,
	# without static bodies or a physics query for every AI every tick.
	if grounded and track.edge_ahead(position.x, position.z, maxf(1.1, actual_speed * .14)):
		vertical_speed = 8.8
		grounded = false
		if is_player: game.emit_fx(position, "jump")
	var previous_y := position.y
	position.z += actual_speed * dt
	if not grounded:
		vertical_speed -= 23.0 * dt
		position.y += vertical_speed * dt
		if vertical_speed <= 0 and previous_y >= -.25 and position.y <= 0 and track.platform_at(position.x, position.z):
			position.y = 0
			vertical_speed = 0
			grounded = true
			land_left = .32
			if is_player: game.emit_fx(position, "land")
	elif not track.platform_at(position.x, position.z):
		grounded = false
		vertical_speed = -1
	if position.y < -7.0:
		if is_player: game.fall_z = position.z
		respawn()
		return
	checkpoint = maxf(checkpoint, track.checkpoint_at(position.z))
	for i in track.obstacles.size():
		var obstacle := track.obstacles[i]
		if absf(float(obstacle.z) - position.z) < 1.0 and absf(float(obstacle.x) - position.x) < float(obstacle.width) + .3:
			if position.y < 1.05 and not hit_obstacles.has(i) and invulnerable <= 0:
				hit_obstacles[i] = true
				stun_left = .85
				if is_player: game.emit_fx(position, "hit")
	for i in track.boosts.size():
		var pad := track.boosts[i]
		if absf(float(pad.z) - position.z) < 1.65 and absf(float(pad.x) - position.x) < 1.55 and position.y < .6 and not used_boosts.has(i):
			used_boosts[i] = true
			boost_left = 2.6
			boost_count += 1
			grounded = false
			vertical_speed = 10.7
			flip_time = .75
			if is_player: game.emit_fx(position, "boost")
	if is_player:
		game.collect_coins(self)
	shadow.visible = track.platform_at(position.x, position.z)
	shadow.position.y = .035 - position.y
	visual.rotation.z = lerpf(visual.rotation.z, clampf((position.x - target_x) * .1, -.18, .18), dt * 7)
	if stun_left > 0: play("Hit")
	elif flip_time > 0: play("Flip")
	elif not grounded: play("Jump")
	elif land_left > 0: play("Land")
	else: play("Run")
	if position.z >= TrackData.FINISH:
		finished = true
		finish_time = elapsed
		play("Celebrate")

func update_ai(dt: float) -> void:
	ai_clock -= dt
	if ai_clock > 0: return
	ai_clock = .4 + rng.randf() * .45
	var best_lane := target_x
	var best_score := -100.0
	for lane in TrackData.LANES:
		var score := rng.randf() * (1.0 - ai_skill) * 3.0 - absf(lane - position.x) * .05
		for obstacle in track.obstacles:
			var distance := float(obstacle.z) - position.z
			if distance > 0 and distance < 14.0 and absf(float(obstacle.x) - lane) < 2:
				score -= 5 * ai_skill
		for pad in track.boosts:
			var distance := float(pad.z) - position.z
			if distance > 0 and distance < 18 and absf(float(pad.x) - lane) < 2:
				score += 4 * ai_skill
		if score > best_score:
			best_score = score
			best_lane = lane
	target_x = best_lane

func respawn() -> void:
	position = Vector3(0, 0, checkpoint)
	target_x = 0
	vertical_speed = 0
	grounded = true
	stun_left = .55
	invulnerable = 1.7
	boost_left = 0
	falls += 1
	if is_player: game.on_player_fall()
