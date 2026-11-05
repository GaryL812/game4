class_name SkylineHUD
extends Control

const INK := Color("153d49")
const MUTED := Color("63858c")
const LIME := Color("e7fb78")
const PAPER := Color("f5fbf3")
var game
var font: Font
var bold: Font
var buttons: Array[Dictionary] = []
var toast := ""
var toast_left := 0.0
var pulse := 0.0
var styles: Dictionary = {}

func setup(owner_game) -> void:
	game = owner_game
	font = load("res://assets/fonts/skyline.ttf")
	bold = load("res://assets/fonts/skyline_bold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	pulse += dt
	toast_left = maxf(0, toast_left - dt)
	queue_redraw()

func say(message: String) -> void:
	toast = message
	toast_left = 3.0

func card(rect: Rect2, color: Color, radius: float = 20, border: Color = Color.TRANSPARENT) -> void:
	var key := color.to_html() + str(int(radius)) + border.to_html()
	if not styles.has(key):
		var created := StyleBoxFlat.new()
		created.bg_color = color
		created.set_corner_radius_all(int(radius))
		if border.a > 0:
			created.border_color = border
			created.set_border_width_all(1)
		styles[key] = created
	var style: StyleBoxFlat = styles[key]
	draw_style_box(style, rect)

func txt(value: String, pos: Vector2, size_value: int = 20, color: Color = INK) -> void:
	draw_string(bold if size_value >= 30 else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func center(value: String, x: float, y: float, size_value: int, color: Color = INK) -> void:
	var width := (bold if size_value >= 30 else font).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	txt(value, Vector2(x - width * .5, y), size_value, color)

func button(rect: Rect2, label: String, action: String, primary := false, extra: int = -1) -> void:
	card(Rect2(rect.position + Vector2(0, 4), rect.size), Color("0c303b"), 17)
	card(rect, LIME if primary else PAPER, 17)
	center(label, rect.get_center().x, rect.get_center().y + 8, 20)
	buttons.append({"rect": rect, "action": action, "extra": extra})

func coin_pill(x: float, y: float, value: int) -> void:
	card(Rect2(x, y, 108, 40), PAPER, 20)
	draw_circle(Vector2(x + 22, y + 20), 10, Color("ffcc48"))
	center("S", x + 22, y + 25, 12, Color("af7e28"))
	txt(str(value), Vector2(x + 41, y + 27), 18)

func _draw() -> void:
	if game == null or font == null: return
	buttons.clear()
	var w := size.x
	var h := size.y
	var wide := w > h
	match game.state:
		"menu": draw_home(w, h, wide)
		"countdown", "race", "paused", "revive": draw_race(w, h)
		"result": draw_result(w, h)
		"shop": draw_shop(w, h)
		"daily": draw_daily(w, h)
		"leaderboard": draw_board(w, h)
	if game.state == "paused":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, .16, .21, .66))
		var x := w * .5
		card(Rect2(x - 180, h * .5 - 140, 360, 280), PAPER, 28)
		center("歇一口气", x, h * .5 - 80, 32)
		center("屋顶在等你，继续向前", x, h * .5 - 43, 16, MUTED)
		button(Rect2(x - 150, h * .5 - 12, 300, 56), "继续奔跑  →", "resume", true)
		button(Rect2(x - 150, h * .5 + 62, 300, 48), "返回主页", "home")
	if game.state == "revive":
		draw_rect(Rect2(Vector2.ZERO, size), Color(.04, .16, .21, .66))
		card(Rect2(w * .5 - 190, h * .5 - 150, 380, 300), PAPER, 28)
		center("失足也没关系", w*.5, h*.5 - 90, 30)
		center("已回到检查点，选择继续方式", w*.5, h*.5 - 52, 16, MUTED)
		button(Rect2(w*.5 - 163, h*.5 - 18, 326, 54), "从检查点继续", "resume", true)
		button(Rect2(w*.5 - 163, h*.5 + 54, 326, 48), "观看视频 · 原地救援", "revive_ad")
	if toast_left > 0:
		var tw := minf(w - 32, 470)
		card(Rect2((w - tw) * .5, h - 104, tw, 48), INK, 16)
		center(toast, w * .5, h - 73, 16, PAPER)

func draw_home(w: float, h: float, wide: bool) -> void:
	var margin := 28.0
	for line in 300:
		draw_line(Vector2(0, line), Vector2(w, line), Color(.88, .96, .91, .72 * (1.0 - float(line) / 300)), 1)
	card(Rect2(margin, 26, 134, 30), INK, 15)
	center("ROOFTOP / 01", margin + 67, 47, 12, LIME)
	coin_pill(w - 136, 23, int(Save.data.coins))
	button(Rect2(w - 193, 23, 42, 40), "静" if game.audio.muted else "♪", "sound")
	txt("SKYLINE", Vector2(margin - 2, 124), 57)
	txt("RUSH", Vector2(margin - 2, 182), 57)
	txt("云端飞奔", Vector2(margin + 2, 218), 24)
	txt("把城市，变成你的游乐场。", Vector2(margin + 3, 249), 14, MUTED)
	var cw := minf(484, w - 56)
	var y := h - 302 if not wide else 274.0
	if wide: cw = minf(400, w * .48)
	card(Rect2(margin, y, cw, 106), Color(.96, .99, .96, .95), 22)
	txt("01", Vector2(margin + 18, y + 45), 30)
	txt("薄荷天际线", Vector2(margin + 78, y + 35), 21)
	txt("7人竞速   /   自动跳跃   /   约90秒", Vector2(margin + 79, y + 62), 13, MUTED)
	for i in 3: draw_circle(Vector2(margin + 83 + i * 13, y + 83), 3, INK if i == 0 else Color("c6d6c9"))
	button(Rect2(margin, y + 124, cw, 60), "开始飞奔     →", "start", true)
	if not wide:
		var bw := (cw - 20) / 3
		button(Rect2(margin, y + 204, bw, 48), "衣橱", "shop")
		button(Rect2(margin + bw + 10, y + 204, bw, 48), "每日挑战", "daily")
		button(Rect2(margin + 2 * (bw + 10), y + 204, bw, 48), "排行榜", "board")
		center("左右滑动或点按 · 跳跃交给我们", w * .5, h - 20, 13, MUTED)
	else:
		button(Rect2(w - 180, 34, 150, 44), "衣橱", "shop")
		button(Rect2(w - 180, 94, 150, 44), "每日挑战", "daily")
		button(Rect2(w - 180, 154, 150, 44), "排行榜", "board")

func draw_race(w: float, h: float) -> void:
	var player = game.player
	if not game.camera.is_position_behind(player.position):
		var marker: Vector2 = game.camera.unproject_position(player.position + Vector3(0, 2.2, 0))
		card(Rect2(marker.x - 22, marker.y - 26, 44, 23), LIME, 8)
		center("YOU", marker.x, marker.y - 10, 12)
	card(Rect2(22, 26, 104, 92), INK, 20)
	txt("RANK", Vector2(40, 51), 12, LIME)
	txt("%02d" % game.player_rank(), Vector2(38, 97), 39, PAPER)
	txt("/ 7", Vector2(91, 95), 13, Color("8fb3b9"))
	card(Rect2(140, 28, w - 230, 58), PAPER, 18)
	txt("薄荷天际线", Vector2(155, 51), 13)
	var progress := clampf(player.position.z / TrackData.FINISH, 0, 1)
	card(Rect2(155, 62, w - 263, 7), Color("d9e5da"), 4)
	card(Rect2(155, 62, maxf(7, (w - 263) * progress), 7), INK, 4)
	button(Rect2(w - 72, 28, 50, 50), "Ⅱ", "pause")
	txt("%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60], Vector2(145, 113), 17)
	coin_pill(w - 133, 98, player.collected)
	# A compact field of seven progress markers.
	var bar_y := 143.0
	for racer in game.runners:
		var x := 28 + clampf(racer.position.z / TrackData.FINISH, 0, 1) * (w - 56)
		draw_circle(Vector2(x, bar_y), 5 if racer.is_player else 3, LIME if racer.is_player else Color("54848e"))
	if player.boost_left > 0:
		card(Rect2(w * .5 - 90, h * .61, 180, 40), LIME, 20)
		center("极速飞跃  ×1.6", w * .5, h * .61 + 26, 17)
	if game.elapsed < 8:
		card(Rect2(w * .5 - 155, h - 110, 310, 48), Color(.06, .22, .27, .88), 24)
		center("←  左右滑动，寻找黄色跳板  →", w * .5, h - 79, 16, PAPER)
	center("‹", 42, h - 30, 38, Color(.08, .24, .28, .5))
	center("›", w - 42, h - 30, 38, Color(.08, .24, .28, .5))
	if game.state == "countdown":
		var text_value := str(maxi(1, ceili(game.countdown)))
		center(text_value, w * .5, h * .43, 100, PAPER)
		center("准备，向城市出发", w * .5, h * .43 + 45, 20)
	if game.checkpoint_flash > 0:
		center("✓  检查点已保存", w * .5, h * .34, 22, INK)

func panel_header(w: float, title_value: String, eyebrow: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(.88, .95, .91, .96))
	button(Rect2(26, 28, 64, 44), "←", "home")
	coin_pill(w - 136, 30, int(Save.data.coins))
	txt(eyebrow, Vector2(28, 118), 13, MUTED)
	txt(title_value, Vector2(26, 165), 36)

func draw_shop(w: float, h: float) -> void:
	panel_header(w, "换个心情，再出发", "THE RUNNER'S WARDROBE")
	var cols := 2 if w < 700 else 4
	var cw := (w - 56 - (cols - 1) * 14) / cols
	var ch := minf(157, (h - 224) / ceilf(8.0 / cols) - 12)
	for i in 8:
		var x := 28 + (i % cols) * (cw + 14)
		var y := 194 + int(i / cols) * (ch + 12)
		card(Rect2(x, y, cw, ch), PAPER, 20, INK if int(Save.data.skin) == i else Color.TRANSPARENT)
		draw_circle(Vector2(x + 30, y + 32), 13, Color(Save.COLORS[i]))
		txt(Save.NAMES[i], Vector2(x + 52, y + 39), 17)
		var label := "使用中" if int(Save.data.skin) == i else ("穿上" if i in Save.data.owned else "%d 金币解锁" % (i * 80))
		button(Rect2(x + 12, y + ch - 61, cw - 24, 43), label, "skin", int(Save.data.skin) == i, i)

func draw_daily(w: float, h: float) -> void:
	Save.ensure_day()
	panel_header(w, "每天，都有小目标", "DAILY CHALLENGES / " + str(Save.data.day))
	var labels := ["完成 3 场屋顶竞速", "在赛道收集 30 枚金币", "踩中 5 次加速跳板"]
	var keys := ["races", "coins", "boosts"]
	var goals := [3, 30, 5]
	for i in 3:
		if w > h:
			var cw := (w - 84) / 3
			var x := 28 + i * (cw + 14)
			card(Rect2(x, 214, cw, 220), PAPER, 22)
			txt("0%d" % (i+1), Vector2(x+20, 254), 30)
			txt(labels[i], Vector2(x+20, 300), 17)
			var count := mini(int(Save.data.daily.get(keys[i], 0)), goals[i])
			txt("%d / %d   ·   +%d 金币" % [count, goals[i], [100,80,60][i]], Vector2(x+20, 336), 15, MUTED)
			button(Rect2(x+20, 367, cw-40, 46), "已领取" if i in Save.data.daily.claimed else "领取奖励", "claim", count == goals[i], i)
			continue
		var y := 204 + i * minf(170, (h - 250) / 3)
		card(Rect2(28, y, w - 56, 142), PAPER, 22)
		txt(labels[i], Vector2(48, y + 37), 20)
		var count := mini(int(Save.data.daily.get(keys[i], 0)), goals[i])
		txt("%d / %d   ·   奖励 %d 金币" % [count, goals[i], [100,80,60][i]], Vector2(48, y + 67), 14, MUTED)
		button(Rect2(w - 174, y + 83, 126, 42), "已领取" if i in Save.data.daily.claimed else "领取奖励", "claim", count == goals[i], i)
		card(Rect2(48, y + 101, w - 244, 8), Color("dce7db"), 4)
		card(Rect2(48, y + 101, maxf(8, (w - 244) * float(count) / goals[i]), 8), INK, 4)

func draw_board(w: float, h: float) -> void:
	panel_header(w, "每一次，超越自己", "PERSONAL BEST / 本机纪录")
	button(Rect2(28, 189, w - 56, 49), "查看微信好友排行", "friends", true)
	if Save.data.records.is_empty(): center("还没有纪录，去完成第一场吧", w * .5, 320, 18, MUTED)
	for i in mini(mini(8, maxi(0, int((h-264) / 66))), Save.data.records.size()):
		var record: Dictionary = Save.data.records[i]
		var y := 264 + i * 66
		card(Rect2(28, y, w - 56, 56), PAPER, 14)
		txt("%02d" % (i+1), Vector2(46, y+36), 23)
		txt("%.2f 秒" % float(record.time), Vector2(110, y+35), 21)
		txt("第%d名" % int(record.rank), Vector2(w - 113, y+34), 17, MUTED)

func draw_result(w: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(.05, .19, .24, .66))
	if w > h:
		var panel_w := minf(850, w - 48)
		var left := (w - panel_w) * .5
		card(Rect2(left, 30, panel_w, h-60), PAPER, 28)
		center("RACE COMPLETE", left+panel_w*.26, 86, 14, MUTED)
		center("%02d" % game.final_rank, left+panel_w*.26, 193, 90)
		center("第 %d 名 / 7" % game.final_rank, left+panel_w*.26, 236, 24)
		center("%.2f 秒" % game.elapsed, left+panel_w*.26, 294, 25)
		center("本局获得 +%d 金币" % game.reward, left+panel_w*.26, 344, 22)
		var x := left + panel_w*.53
		var bw := panel_w*.43
		button(Rect2(x, 102, bw, 58), "再来一局 →", "start", true)
		button(Rect2(x, 184, bw, 50), "双倍奖励已领取" if game.doubled else "观看视频 · 双倍金币", "double")
		button(Rect2(x, 258, bw, 50), "分享战绩", "share")
		button(Rect2(x, 332, bw, 50), "返回主页", "home")
		return
	var cx := w * .5
	var pw := minf(440, w - 48)
	var ph := minf(638, h - 40)
	var top := (h - ph) * .5
	card(Rect2(cx - pw * .5, top, pw, ph), PAPER, 30)
	center("RACE COMPLETE", cx, top + 42, 13, MUTED)
	center("%02d" % game.final_rank, cx, top + 135, 85)
	center("第 %d 名 / 7" % game.final_rank, cx, top + 170, 21)
	center("漂亮的飞跃！" if game.final_rank <= 3 else "下一次，再快一点。", cx, top + 211, 26)
	center("%.2f 秒     ·     拾取 %d 金币" % [game.elapsed, game.player.collected], cx, top + 250, 17, MUTED)
	card(Rect2(cx - pw*.5 + 24, top + 275, pw - 48, 71), Color("e6efdd"), 18)
	center("本局获得    + %d 金币" % game.reward, cx, top + 320, 24)
	var y := top + 367
	button(Rect2(cx - pw*.5 + 24, y, pw - 48, 56), "再来一局     →", "start", true)
	button(Rect2(cx - pw*.5 + 24, y + 72, pw - 48, 48), "观看视频 · 双倍金币" if not game.doubled else "双倍奖励已领取", "double")
	button(Rect2(cx - pw*.5 + 24, y + 135, (pw - 60)*.5, 48), "返回主页", "home")
	button(Rect2(cx + 6, y + 135, (pw - 60)*.5, 48), "分享战绩", "share")
	if ph > 610: center("每一步，都离天际更近。", cx, top + ph - 28, 14, MUTED)

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed: return
	for entry in buttons:
		if entry.rect.has_point(event.position):
			game.ui_action(entry.action, entry.extra)
			get_viewport().set_input_as_handled()
			return
	if game.state not in ["race", "countdown"]: get_viewport().set_input_as_handled()
