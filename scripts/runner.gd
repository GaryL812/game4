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
var safe_position := Vector3.ZERO
var safe_roof_id := 0
var traversal := "run"
var wall: Dictionary = {}
var wall_side := 0
var wall_time := 0.0
var wall_cooldown := 0.0
var climbs := 0
var side_slides := 0
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
var hero_material: ShaderMaterial

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
		if is_player:
			hero_material=ShaderMaterial.new()
			hero_material.shader=preload("res://scripts/wanderer.gdshader")
			hero_material.set_shader_parameter("paper_grain",preload("res://assets/textures/paper_grain.png"))
			node.material_override=hero_material
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var material := ShaderMaterial.new()
		material.shader=preload("res://scripts/wanderer.gdshader")
		material.set_shader_parameter("reference_palette",false)
		material.set_shader_parameter("body_tint",tint.lerp(Color("606b60"),.73))
		material.set_shader_parameter("paper_grain",preload("res://assets/textures/paper_grain.png"))
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation = players[0]
		for anim_name in animation.get_animation_list():
			if anim_name.ends_with("Run") or anim_name.ends_with("Celebrate") or anim_name.ends_with("Climb") or anim_name.ends_with("SideSlide"):
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
	if is_player and hero_material:
		# Preserve the hat and grey mantle; recolor only the sash and ribbons.
		var accent := Color("b74442") if int(Save.data.skin)==0 else Color(Save.COLORS[int(Save.data.skin)])
		hero_material.set_shader_parameter("accent_color",accent)
		return
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
	boost_left = maxf(0, boost_left-dt)
	stun_left = maxf(0, stun_left-dt)
	invulnerable = maxf(0, invulnerable-dt)
	flip_time = maxf(0, flip_time-dt)
	land_left = maxf(0, land_left-dt)
	wall_cooldown = maxf(0, wall_cooldown-dt)
	if not is_player: update_ai(dt)
	var actual_speed := speed * (1.6 if boost_left > 0 else 1.0) * (.32 if stun_left > 0 else 1.0)
	if not is_player:
		# Far-ahead opponents cruise, without teleporting or disappearing from rankings.
		var lead: float=position.z-game.player.position.z
		actual_speed*=.66 if lead>70 else (.84 if lead>38 else 1.0)
		if grounded and traversal=="run":
			var gap := INF
			for other in game.runners:
				if other==self or other.is_player or other.finished: continue
				var distance: float=other.position.z-position.z
				if distance>0: gap=minf(gap,distance)
			if gap<34: actual_speed=minf(actual_speed,maxf(0,gap-32)/dt)
	if traversal != "run":
		tick_wall(dt, actual_speed)
		update_visual(dt)
		return
	var previous := position
	var floor_roof := track.surface_at(position.x, position.z)
	if grounded:
		if floor_roof.is_empty():
			grounded = false
			vertical_speed = -1
		else:
			position.y = float(floor_roof.height)
			remember_safe(floor_roof)
			if track.edge_ahead(position.x, position.z, maxf(1.1, actual_speed*.14)):
				vertical_speed = 9.1
				grounded = false
				if is_player: game.emit_fx(position,"jump")
	position.x = lerpf(position.x,target_x,1.0-exp(-dt*8))
	position.z += actual_speed*dt
	if not grounded:
		vertical_speed -= 23*dt
		position.y += vertical_speed*dt
		var landing := track.surface_at(position.x,position.z)
		if not landing.is_empty() and vertical_speed <= 0 and previous.y >= float(landing.height)-.08 and position.y <= float(landing.height):
			position.y = float(landing.height)
			vertical_speed = 0
			grounded = true
			land_left = .32
			remember_safe(landing)
			if is_player: game.emit_fx(position,"land")
	if wall_cooldown <= 0:
		var contact := track.wall_contact(previous,position)
		if not contact.is_empty():
			enter_wall(contact)
			update_visual(dt)
			return
	if position.y < -10:
		respawn()
		return
	for i in track.obstacles.size():
		var obstacle := track.obstacles[i]
		if absf(float(obstacle.z)-position.z)<1 and absf(float(obstacle.x)-position.x)<float(obstacle.width)+.3:
			if absf(position.y-float(obstacle.y))<1.05 and not hit_obstacles.has(i) and invulnerable<=0:
				hit_obstacles[i]=true
				stun_left=.65
				if is_player: game.emit_fx(position,"hit")
	for i in track.boosts.size():
		var pad := track.boosts[i]
		if absf(float(pad.z)-position.z)<1.65 and absf(float(pad.x)-position.x)<1.55 and absf(position.y-float(pad.y))<.65 and not used_boosts.has(i):
			used_boosts[i]=true
			boost_left=2.6
			boost_count+=1
			grounded=false
			vertical_speed=11.5
			flip_time=.75
			if is_player: game.emit_fx(position,"boost")
	if is_player: game.collect_coins(self)
	update_visual(dt)
	if position.z >= TrackData.FINISH and grounded:
		finished=true
		finish_time=elapsed
		play("Celebrate")

func remember_safe(roof: Dictionary) -> void:
	safe_roof_id = int(roof.id)
	var half := float(roof.width)*.5-.9
	safe_position = Vector3(clampf(position.x,float(roof.x)-half,float(roof.x)+half),float(roof.height),clampf(position.z-3.0,float(roof.start)+1.5,float(roof.end)-3.0))

func enter_wall(contact: Dictionary) -> void:
	wall=contact.roof
	grounded=false
	vertical_speed=0
	flip_time=0
	if contact.face=="front":
		traversal="climb"
		climbs+=1
		position.z=float(wall.start)-.34
		position.x=clampf(position.x,float(wall.x)-float(wall.width)*.5+.35,float(wall.x)+float(wall.width)*.5-.35)
	else:
		traversal="side_slide"
		side_slides+=1
		wall_side=int(contact.side)
		wall_time=1.15
		position.x=float(wall.x)+wall_side*(float(wall.width)*.5+.32)

func tick_wall(dt: float, actual_speed: float) -> void:
	if traversal=="climb":
		var left := float(wall.x)-float(wall.width)*.5+.35
		var right := float(wall.x)+float(wall.width)*.5-.35
		position.x=clampf(lerpf(position.x,target_x,dt*4),left,right)
		position.y=move_toward(position.y,float(wall.height),dt*3.5)
		if position.y >= float(wall.height)-.01:
			position.y=float(wall.height)
			position.z=float(wall.start)+.85
			traversal="run"
			grounded=true
			vertical_speed=0
			wall_cooldown=.2
			land_left=.18
			remember_safe(wall)
			wall={}
	else:
		wall_time-=dt
		position.z+=actual_speed*.72*dt
		position.y-=1.2*dt
		# Steering back over the lip is allowed when the feet are above it.
		if wall_time<=0 or position.z>float(wall.end)+.25 or position.y < TrackData.BUILDING_BASE+1:
			traversal="run"
			vertical_speed=-2
			wall_cooldown=.35
			wall={}

func update_visual(dt: float) -> void:
	var roof := track.surface_at(position.x,position.z)
	shadow.visible = not roof.is_empty() and position.y >= float(roof.get("height",0))-.1 and traversal=="run"
	if shadow.visible: shadow.position.y=float(roof.height)+.035-position.y
	visual.rotation.z=lerpf(visual.rotation.z,wall_side*.42 if traversal=="side_slide" else clampf((position.x-target_x)*.1,-.18,.18),minf(1,dt*8))
	if traversal=="climb": play("Climb")
	elif traversal=="side_slide": play("SideSlide")
	elif stun_left>0: play("Hit")
	elif flip_time>0: play("Flip")
	elif not grounded: play("Jump")
	elif land_left>0: play("Land")
	else: play("Run")

func update_ai(dt: float) -> void:
	ai_clock-=dt
	if ai_clock>0 or traversal!="run" or not grounded: return
	ai_clock=.3+rng.randf()*.35
	var best_lane := target_x
	var best_score := -1000.0
	var choices := track.lanes_ahead(position.z)
	var current_roof := track.surface_at(position.x,position.z)
	# Select a branch on a broad junction, then commit until the merge.
	if not current_roof.is_empty() and float(current_roof.width)<6:
		choices.assign([float(current_roof.x)])
	for lane in choices:
		var score := rng.randf()*(1-ai_skill)*2-absf(lane-position.x)*.18
		for obstacle in track.obstacles:
			var distance := float(obstacle.z)-position.z
			if distance>0 and distance<14 and absf(float(obstacle.x)-lane)<1.6: score-=4*ai_skill
		for pad in track.boosts:
			var distance := float(pad.z)-position.z
			if distance>0 and distance<22 and absf(float(pad.x)-lane)<1.8: score+=3*ai_skill
		if score>best_score:
			best_score=score
			best_lane=lane
	target_x=best_lane

func respawn() -> void:
	position=safe_position
	target_x=position.x
	vertical_speed=0
	grounded=true
	stun_left=0
	invulnerable=1.25
	boost_left=0
	flip_time=0
	traversal="run"
	wall={}
	wall_cooldown=.35
	falls+=1
	if is_player: game.on_player_fall()
