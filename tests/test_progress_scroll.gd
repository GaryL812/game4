extends Node

var checks := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ",message)
	else:
		failed += 1
		push_error("FAIL: "+message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.audio.muted = true
	var hud = game.hud
	check(not hud.progress_scroll.visible,"scroll stays hidden on the home screen")
	game.state = "race"
	for resolution in [Vector2i(540,960),Vector2i(960,540)]:
		game.get_window().size = resolution
		game.adapt_window()
		await get_tree().process_frame
		var fixed_right := 0.0
		for progress in [0.0,.5,1.0]:
			game.player.position.z = TrackData.FINISH*progress
			hud.update_progress_scroll(1.0)
			var right: float = hud.scroll_right.global_position.x
			if progress==0:
				fixed_right=right
			check(is_equal_approx(hud.scroll_paper.scale.x,1.0-progress),"paper shrinks with progress %s at %s"%[progress,resolution])
			check(is_equal_approx(right,fixed_right),"fixed roller stays still at %s"%resolution)
			check(hud.scroll_right.visible and hud.scroll_right.size.x>0,"fixed roller remains visible")
			var paper_edge: float = hud.scroll_paper.position.x+hud.scroll_paper.pivot_offset.x
			var roller_center: float = hud.scroll_right.position.x+hud.scroll_right.size.x*.5
			check(absf(paper_edge-roller_center)<2,"paper extends under the roller center to avoid an exposed seam")
			if progress==1:
				check(not hud.scroll_paper.visible and not hud.scroll_left.visible and not hud.scroll_marker.visible,"finish exposes only the fixed roller")
			else:
				var left: float = hud.scroll_paper.position.x+hud.scroll_paper.pivot_offset.x*progress
				check(hud.scroll_marker.position.x>=left and hud.scroll_marker.position.x<=hud.scroll_right.position.x+4,"ink marker stays on the remaining paper")
			check(hud.progress_scroll.position.x>=126 and hud.progress_scroll.position.x+hud.progress_scroll.size.x<=hud.size.x-72,"scroll fits between rank and pause controls")
			game.player.charge_coins=7
			game.player.charge_left=0 if progress==0 else RoofRunner.CHARGE_DURATION*(1.5-progress)
			hud.update_energy_bar(1)
			var energy_ratio: float = 7.0/RoofRunner.CHARGE_COINS if progress==0 else 1.5-progress
			check(is_equal_approx(hud.energy_fill.scale.y,energy_ratio),"vertical ink height follows coin charge or active duration")
			check(hud.energy_fill.pivot_offset.y==hud.energy_fill.size.y,"ink grows upward from its fixed bottom pivot")
			check(hud.energy_bar.global_position.x>hud.size.x*.8 and hud.energy_bar.global_position.y>140,"energy bar sits on the right below the top HUD")
			check(hud.energy_bar.get_child_count()==2,"energy meter consists only of two ink textures, without text or a frame")
			if "--visual" in OS.get_cmdline_user_args():
				game.update_camera(1)
				game.world.update_view(game.player.position.z,0)
				for i in 3:
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
				var label := "portrait" if resolution.x<resolution.y else "landscape"
				get_viewport().get_texture().get_image().save_png("res://build/scroll_%s_%d.png"%[label,roundi(progress*100)])
	hud.reset_progress_scroll()
	game.player.position.z=TrackData.FINISH*.5
	hud.update_progress_scroll(1.0/120)
	var smoothed: float = hud.scroll_display_progress
	var roller_x: float = hud.scroll_roller_motion.position.x
	check(smoothed>0 and smoothed<.5,"large progress changes ease toward the target")
	hud.update_progress_scroll(1.0/120)
	check(hud.scroll_display_progress>smoothed and hud.scroll_roller_motion.position.x>roller_x,
		"roller keeps moving right on render frames between physics updates")
	check(not is_equal_approx(hud.scroll_roller_motion.position.x,roundf(hud.scroll_roller_motion.position.x)),
		"moving roller retains fractional-pixel positions")
	hud.reset_progress_scroll()
	for i in 15: hud.update_progress_scroll(1.0/30)
	var progress_at_30: float = hud.scroll_display_progress
	hud.reset_progress_scroll()
	for i in 60: hud.update_progress_scroll(1.0/120)
	check(is_equal_approx(progress_at_30,hud.scroll_display_progress),"smoothing duration is independent of frame rate")
	game.state="paused"
	smoothed=hud.scroll_display_progress
	game.player.position.z=TrackData.FINISH
	hud.update_progress_scroll(.5)
	check(hud.scroll_display_progress==smoothed,"pause freezes the closing animation")
	var ink_scale: float = hud.energy_fill.scale.y
	game.player.charge_left=0
	game.player.charge_coins=0
	hud.update_energy_bar(.5)
	check(hud.energy_fill.scale.y==ink_scale,"pause freezes the ink fill")
	hud.update_progress_scroll()
	check(hud.progress_scroll.visible and hud.progress_scroll.show_behind_parent,"paused scroll sits below the pause overlay")
	game.state="shop"
	hud.update_progress_scroll()
	check(not hud.progress_scroll.visible,"scroll stays hidden in other menus")
	game.state="race"
	game.reset_runners()
	hud.update_progress_scroll()
	hud.update_energy_bar(0)
	check(hud.scroll_paper.visible and hud.scroll_paper.scale.x==1,"restarting restores the fully opened scroll")
	check(not hud.energy_fill.visible and hud.energy_display==0,"restarting clears the side energy meter")
	print("SCROLL_TESTS %d/%d passed"%[checks-failed,checks])
	game.audio.shutdown()
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
