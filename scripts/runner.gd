class_name RoofRunner
extends Node3D

const GRAVITY := 23.0
const SIDE_JUMP_INSET := .55
const SIDE_WALL_CLEARANCE := .42
const PaperRunner = preload("res://scripts/paper_runner.gd")
const CHARGE_COINS := 15
const CHARGE_DURATION := 5.0
const CHARGE_SPEED_MULTIPLIER := 1.3
const RIVAL_RECOVERY_TIME := 2.0
const FINISH_RUNOUT_TIME := 1.8

var runner_id := 0
var is_player := false
var speed := 11.0
var target_x := 0.0
var vertical_speed := 0.0
var grounded := true
var side_jump_roof: Dictionary = {}
var boost_left := 0.0
var stun_left := 0.0
var invulnerable := 0.0
var finished := false
var finish_time := 0.0
var finish_runout_elapsed := 0.0
var finish_runout_speed := 0.0
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
var paper_visual: PaperRunner
var shadow: Node3D
var hit_obstacles: Dictionary = {}
var used_boosts: Dictionary = {}
var flip_time := 0.0
var land_left := 0.0
var rng := RandomNumberGenerator.new()
var track: TrackData
var game
var attack_left := 0.0
var attack_hit := false
var slash_combo := 0
var slash_boost_left := 0.0
var charge_coins := 0
var charge_left := 0.0
var defeated_left := 0.0

func charge_from_coin() -> void:
	if not is_player or finished or game.state != "race" or charge_left > 0:
		return
	charge_coins += 1
	if charge_coins >= CHARGE_COINS:
		charge_coins = 0
		charge_left = CHARGE_DURATION
		attack()

func tick_charge(dt: float) -> void:
	if charge_left <= 0:
		return
	charge_left = maxf(0, charge_left-dt)
	if charge_left <= .00001:
		cancel_attack()
	elif attack_left <= 0:
		attack()

func receive_slash() -> bool:
	if is_player or finished or defeated_left > 0 or invulnerable > 0:
		return false
	defeated_left = RIVAL_RECOVERY_TIME
	visible = false
	game.world.sword_fx.splash(position)
	return true

func register_slash_hit() -> void:
	slash_combo += 1
	attack_hit = true
	slash_boost_left = minf(charge_left, 2.0 if slash_combo >= 3 else 1.0)
	game.camera_shake_left = .1
	game.audio.cue("hit")

func in_sword_range(target: Vector3, half_width: float) -> bool:
	var distance := target.z-position.z
	return distance >= -.5 and distance <= 3.0 and absf(target.x-position.x) <= half_width and absf(target.y-position.y) <= 1.05

func has_slash_target(max_distance: float = 3.0) -> bool:
	for i in track.obstacles.size():
		if game.world.destroyed_obstacles.has(i): continue
		var obstacle: Dictionary = track.obstacles[i]
		var target := Vector3(obstacle.x,obstacle.y,obstacle.z)
		if target.z >= position.z and target.z-position.z <= max_distance and in_sword_range(target,float(obstacle.width)+.8):
			return true
	for rival in game.runners:
		if rival.is_player or rival.finished or rival.defeated_left>0 or rival.invulnerable>0: continue
		if rival.position.z >= position.z and rival.position.z-position.z <= max_distance and in_sword_range(rival.position,1.3):
			return true
	return false

func attack() -> bool:
	if not is_player or charge_left <= 0 or game.state != "race" or finished or traversal != "run" or stun_left > 0 or attack_left > 0:
		return false
	if not has_slash_target():
		return false
	attack_left = .2
	attack_hit = false
	paper_visual.start_slash()
	# A target entered sideways can already overlap the collision zone.
	if has_slash_target(1.35):
		attack_left = .15
		paper_visual.slash_tween.custom_step(.05)
	return true

func tick_attack(dt: float) -> void:
	if attack_left <= 0: return
	var previous := attack_left
	attack_left = maxf(0, attack_left - dt)
	if attack_left < .00001: attack_left = 0
	# Resolve throughout the downstroke, including a frame that spans the window.
	if previous > .05 and attack_left <= .15:
		for i in track.obstacles.size():
			if game.world.destroyed_obstacles.has(i): continue
			var obstacle := track.obstacles[i]
			if not in_sword_range(Vector3(obstacle.x,obstacle.y,obstacle.z),float(obstacle.width)+.8): continue
			game.world.destroy_obstacle(i)
			register_slash_hit()
		for rival in game.runners:
			if rival.is_player: continue
			if not in_sword_range(rival.position,1.3): continue
			if rival.receive_slash():
				register_slash_hit()
	if paper_visual.slash_tween and paper_visual.slash_tween.is_valid():
		paper_visual.slash_tween.custom_step(dt)
	if previous > .100001 and attack_left <= .100001:
		game.world.sword_fx.show_slash(position, slash_combo >= 3)
	if attack_left <= 0:
		paper_visual.cancel_slash()

func cancel_attack() -> void:
	attack_left = 0
	attack_hit = false
	slash_combo = 0
	slash_boost_left = 0
	charge_left = 0
	paper_visual.cancel_slash()

func setup(id: int, owner_game, skin: int) -> void:
	runner_id = id
	game = owner_game
	track = game.track
	is_player = id == 0
	rng.seed = 1926 + id * 319
	ai_skill = [.0, .58, .65, .75, .82, .9, .97][id]
	speed = TrackData.BASE_SPEED + (id - 3) * .13 if id > 0 else TrackData.BASE_SPEED
	paper_visual = PaperRunner.new()
	paper_visual.name = "PaperRunner"
	paper_visual.phase = fposmod(.15 + .21 * id, 1.0)
	paper_visual.skin_id = skin
	add_child(paper_visual)
	paper_visual.armed = is_player
	shadow = game.models.shadow.instantiate()
	add_child(shadow)
	shadow.position.y = .022
	shadow.scale = Vector3(.82, 1, .61)
	for mesh_node in shadow.find_children("*", "MeshInstance3D", true, false):
		var material := mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
		var wash := material.duplicate() as StandardMaterial3D
		wash.vertex_color_use_as_albedo = false
		wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wash.albedo_color = Color(.23, .22, .18, .33)
		wash.render_priority = -6
		mesh_node.material_override = wash
	var lane := float((id % 3) - 1) * 3.1
	position = Vector3(lane, 0, -float(id / 3) * 2.1)
	target_x = lane
	play("Run")

func apply_skin() -> void:
	paper_visual.set_skin(int(Save.data.skin))

func play(key: String) -> void:
	paper_visual.play(key)

func tick(dt: float, elapsed: float) -> void:
	if defeated_left > 0:
		defeated_left = maxf(0, defeated_left-dt)
		if defeated_left <= .00001:
			defeated_left = 0
			respawn(false)
		return
	if finished:
		tick_finish_runout(dt)
		return
	boost_left = maxf(0, boost_left-dt)
	slash_boost_left = maxf(0, slash_boost_left-dt)
	stun_left = maxf(0, stun_left-dt)
	invulnerable = maxf(0, invulnerable-dt)
	flip_time = maxf(0, flip_time-dt)
	land_left = maxf(0, land_left-dt)
	wall_cooldown = maxf(0, wall_cooldown-dt)
	if is_player: tick_charge(dt)
	if not is_player: update_ai(dt)
	var speed_multiplier := CHARGE_SPEED_MULTIPLIER if charge_left>0 else 1.0
	if slash_boost_left>0: speed_multiplier=maxf(speed_multiplier,1.5)
	if boost_left>0: speed_multiplier=maxf(speed_multiplier,1.6)
	var actual_speed := speed * speed_multiplier * (.32 if stun_left > 0 else 1.0)
	if not is_player:
		# Far-ahead opponents cruise, without teleporting or disappearing from rankings.
		var lead: float=position.z-game.player.position.z
		actual_speed*=.66 if lead>70 else (.84 if lead>38 else 1.0)
		if grounded and traversal=="run":
			var gap := INF
			for other in game.runners:
				if other==self or other.is_player or other.finished or other.defeated_left>0: continue
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
			var launch_speed := 9.1 if track.edge_ahead(position.x, position.z, maxf(1.1, actual_speed*.14)) else 0.0
			if launch_speed > 0.0:
				launch_speed = forward_jump_speed(actual_speed, dt)
			if is_player:
				launch_speed = maxf(launch_speed, prepare_side_jump(floor_roof))
			if launch_speed > 0.0:
				vertical_speed = launch_speed
				grounded = false
				if is_player: game.emit_fx(position,"jump")
	position.x = next_steering_x(dt)
	position.z += actual_speed*dt
	if not grounded:
		vertical_speed -= GRAVITY*dt
		position.y += vertical_speed*dt
		var landing := track.surface_at(position.x,position.z)
		if not landing.is_empty() and vertical_speed <= 0 and previous.y >= float(landing.height)-.08 and position.y <= float(landing.height):
			position.y = float(landing.height)
			vertical_speed = 0
			grounded = true
			side_jump_roof = {}
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
	tick_attack(dt)
	for i in track.obstacles.size():
		if game.world.destroyed_obstacles.has(i): continue
		var obstacle := track.obstacles[i]
		if absf(float(obstacle.z)-position.z)<1 and absf(float(obstacle.x)-position.x)<float(obstacle.width)+.3:
			if absf(position.y-float(obstacle.y))<1.05 and not hit_obstacles.has(i) and invulnerable<=0:
				hit_obstacles[i]=true
				stun_left=.65
				if is_player and charge_left <= 0: cancel_attack()
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
		finish_runout_speed=actual_speed
		boost_left=0
		play("Run")

func tick_finish_runout(dt: float) -> void:
	var previous := finish_runout_elapsed
	finish_runout_elapsed = minf(FINISH_RUNOUT_TIME,previous+dt)
	# Integrate the deceleration so distance is identical at different frame rates.
	var distance := finish_runout_speed*((finish_runout_elapsed-previous)
		-(finish_runout_elapsed*finish_runout_elapsed-previous*previous)/(2.0*FINISH_RUNOUT_TIME))
	position.z += distance
	var floor_height := track.height_at(position.x,position.z)
	if is_finite(floor_height): position.y=floor_height
	paper_visual.boosted=false
	paper_visual.run_cycle_scale=maxf(.15,1.0-finish_runout_elapsed/FINISH_RUNOUT_TIME)
	play("Celebrate" if finish_runout_elapsed>=FINISH_RUNOUT_TIME else "Run")

func forward_jump_speed(actual_speed: float, dt: float) -> float:
	var next_section := track.section_index(position.z) + 1
	if actual_speed <= 0.0 or next_section >= track.sections.size():
		return 9.1
	var next_start := float(track.sections[next_section][0].start)
	var travel_time := (next_start - .34 - position.z) / actual_speed
	var landing_x := lerpf(position.x, target_x, 1.0-exp(-travel_time*8.0))
	var next_roof := track.surface_at(landing_x, next_start)
	if next_roof.is_empty():
		return 9.1
	# Reach the short climbing band on high transitions, even at lower AI speeds.
	var required_rise := float(next_roof.height) - TrackData.MAX_CLIMB_DEPTH + .25 - position.y
	return maxf(9.1, required_rise/travel_time + GRAVITY*(travel_time+dt)*.5)

func prepare_side_jump(roof: Dictionary) -> float:
	var destination := track.side_jump_destination(roof, target_x)
	if destination.is_empty():
		return 0.0
	side_jump_roof = destination
	var direction := signf(float(destination.x) - float(roof.x))
	var near_edge := float(destination.x) - direction * float(destination.width) * .5
	if (target_x - near_edge) * direction < 0.0:
		target_x = near_edge + direction * SIDE_JUMP_INSET
	var rise := float(destination.height) - float(roof.height)
	return sqrt(2.0 * GRAVITY * maxf(1.12, rise + .75))

func next_steering_x(dt: float) -> float:
	var blend := 1.0 - exp(-dt * 8.0)
	if side_jump_roof.is_empty():
		return lerpf(position.x, target_x, blend)
	var center := float(side_jump_roof.x)
	var half_width := float(side_jump_roof.width) * .5
	var inset := minf(SIDE_JUMP_INSET, half_width)
	var aim := clampf(target_x, center - half_width + inset, center + half_width - inset)
	var proposed := lerpf(position.x, aim, blend)
	var next_y := position.y + (vertical_speed - GRAVITY * dt) * dt
	if absf(position.x - center) > half_width and next_y < float(side_jump_roof.height) - .08:
		# Keep the runner just outside the wall until the feet clear its lip.
		var limit := center - signf(center - position.x) * (half_width + SIDE_WALL_CLEARANCE)
		proposed = minf(proposed, limit) if position.x < center else maxf(proposed, limit)
	return proposed

func remember_safe(roof: Dictionary) -> void:
	safe_roof_id = int(roof.id)
	var half := float(roof.width)*.5-.9
	safe_position = Vector3(clampf(position.x,float(roof.x)-half,float(roof.x)+half),float(roof.height),clampf(position.z-3.0,float(roof.start)+1.5,float(roof.end)-3.0))

func enter_wall(contact: Dictionary) -> void:
	if is_player and attack_left > 0:
		if not attack_hit: slash_combo = 0
		attack_left = 0
		paper_visual.cancel_slash()
	wall=contact.roof
	side_jump_roof = {}
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
	if shadow.visible: shadow.position.y=float(roof.height)+.022-position.y
	paper_visual.rotation.z=lerpf(paper_visual.rotation.z,wall_side*.42 if traversal=="side_slide" else clampf((position.x-target_x)*.1,-.18,.18),minf(1,dt*8))
	paper_visual.vertical_speed = vertical_speed
	paper_visual.boosted = charge_left > 0 or boost_left > 0 or slash_boost_left > 0
	paper_visual.wall_side = wall_side
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
		for obstacle_id in track.obstacles.size():
			if game.world.destroyed_obstacles.has(obstacle_id): continue
			var obstacle := track.obstacles[obstacle_id]
			var distance := float(obstacle.z)-position.z
			if distance>0 and distance<14 and absf(float(obstacle.x)-lane)<1.6: score-=4*ai_skill
		for pad in track.boosts:
			var distance := float(pad.z)-position.z
			if distance>0 and distance<22 and absf(float(pad.x)-lane)<1.8: score+=3*ai_skill
		if score>best_score:
			best_score=score
			best_lane=lane
	target_x=best_lane

func respawn(count_fall: bool = true) -> void:
	if is_player: cancel_attack()
	position=safe_position
	target_x=position.x
	vertical_speed=0
	grounded=true
	side_jump_roof = {}
	stun_left=0
	invulnerable=1.25
	boost_left=0
	flip_time=0
	traversal="run"
	wall={}
	wall_cooldown=.35
	if count_fall: falls+=1
	if is_player: game.on_player_fall()
