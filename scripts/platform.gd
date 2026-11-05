extends Node
## Calls our bridge only in a mini-game. Desktop stays fully playable.
signal rewarded(completed: bool)
signal app_hidden
var bridge = null
var callback
var waiting := false
var low_end := false

func _ready() -> void:
	if OS.has_feature("web"):
		bridge = JavaScriptBridge.get_interface("SkylinePlatform")
		if bridge != null:
			callback = JavaScriptBridge.create_callback(_on_bridge_event)
			bridge.setCallback(callback)
			low_end = bool(bridge.isLowEnd())

func storage_get(key: String) -> String:
	if bridge != null: return str(bridge.getStorage(key))
	return ""

func storage_set(key: String, value: String) -> void:
	if bridge != null: bridge.setStorage(key, value)

func request_ad() -> void:
	if waiting: return
	if bridge == null or not bool(bridge.hasRewardAd()):
		rewarded.emit(false)
		return
	waiting = true
	bridge.showRewardAd()

func _on_bridge_event(args: Array) -> void:
	if args.is_empty(): return
	match str(args[0]):
		"ad":
			waiting = false
			rewarded.emit(args.size() > 1 and bool(args[1]))
		"hide": app_hidden.emit()

func share_result(rank: int, seconds: float) -> void:
	if bridge != null: bridge.share("云端飞奔 · 第%d名，%.1f秒！来屋顶追上我" % [rank, seconds])

func submit_score(seconds: float) -> void:
	if bridge != null: bridge.submitScore(int(seconds * 1000.0))

func show_friend_board() -> bool:
	if bridge == null: return false
	bridge.showFriends()
	return true

func hide_friend_board() -> void:
	if bridge != null: bridge.hideFriends()
