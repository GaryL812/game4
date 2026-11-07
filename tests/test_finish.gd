extends Node

var checks := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ",message)
	else:
		failed += 1
		push_error("FAIL: "+message)

func _ready() -> void:
	call_deferred("run")

func capture(game, label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.player.paper_visual.update_pose()
	game.update_camera(1)
	game.world.update_view(game.player.position.z,0)
	for i in 4:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/finish_%s.png"%label)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.audio.muted=true
	var saved: Dictionary=Save.data.duplicate(true)
	var last: Dictionary=game.track.sections[-1][0]
	check(game.world.finish_gate is Sprite3D and not game.models.has("finish_scroll"),"finish uses one sprite and the old gate model is not loaded")
	check(game.world.finish_gate.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"gate has no shadow casting")
	check(is_equal_approx(last.end,TrackData.FINISH+TrackData.FINISH_RUNWAY),"the last roof extends 48 meters beyond the finish")
	check(not game.track.surface_at(last.x,TrackData.FINISH+40).is_empty(),"the runway has a real walkable surface")
	var last_deck: Node3D=game.world.chunks[-1].get_child(0)
	check(is_equal_approx(last_deck.scale.z*TrackData.SEGMENT_LENGTH,float(last.end)-float(last.start)),"the rendered runway matches its collision length")
	game.state="race"
	game.elapsed=60
	game.player.position=Vector3(last.x,last.height,TrackData.FINISH-45)
	game.player.position.y=game.track.height_at(game.player.position.x,game.player.position.z)
	game.player.target_x=last.x
	game.player.grounded=true
	game.world.update_view(game.player.position.z,0)
	check(game.world.finish_gate.visible,"large finish gate is visible well before crossing")
	await capture(game,"approach")
	game.player.position=Vector3(last.x,last.height,TrackData.FINISH-15)
	await capture(game,"close")
	game.player.position.z=TrackData.FINISH-.08
	game._physics_process(1.0/60)
	check(game.state=="result" and game.player.finished,"crossing the gate immediately triggers results")
	check(game.player.paper_visual.action=="Run","the player keeps running at the instant of crossing")
	var finish_z: float=game.player.position.z
	var finish_time: float=game.elapsed
	var rank: int=game.final_rank
	var reward: int=game.reward
	var coins: int=Save.data.coins
	game.finish_race()
	check(Save.data.coins==coins,"repeated finish callbacks cannot duplicate the reward")
	for i in 30:
		game._physics_process(1.0/60)
		game._process(1.0/60)
	check(game.player.position.z>finish_z+1,"the player continues forward underneath the result interface")
	check(game.elapsed==finish_time and game.final_rank==rank and game.reward==reward,"runout does not change race time, rank or rewards")
	await capture(game,"runout")
	for i in 120:
		game._physics_process(1.0/60)
		game._process(1.0/60)
	var stopped_z: float=game.player.position.z
	check(is_equal_approx(stopped_z-finish_z,game.player.finish_runout_speed*RoofRunner.FINISH_RUNOUT_TIME*.5),
		"coasting distance follows the smooth deceleration curve")
	check(stopped_z>TrackData.FINISH and stopped_z<float(last.end)-5,"runout stops safely on the extended roof")
	check(game.player.paper_visual.action=="Celebrate","celebration begins after the runout")
	game._physics_process(1)
	check(is_equal_approx(game.player.position.z,stopped_z),"the player stays stopped after decelerating")
	check(game.player.falls==0,"running past the gate does not cause a fall")
	await capture(game,"stopped")
	game.reset_runners()
	check(not game.player.finished and game.player.finish_runout_elapsed==0 and game.player.paper_visual.run_cycle_scale==1,"restarting clears the runout and restores normal animation speed")
	Save.data=saved
	Save.persist()
	print("FINISH_TESTS %d/%d passed"%[checks-failed,checks])
	game.audio.shutdown()
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
