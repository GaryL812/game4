extends Node

const PATH := "user://skyline_save.json"
const COLORS := ["#e7fb78", "#ff936b", "#7bb9ff", "#ee8ac1", "#c3a2f8", "#faf4e5", "#5cdbc3", "#ffd25c"]
const NAMES := ["青柠先锋", "落日橙", "海盐蓝", "莓果粉", "暮光紫", "云朵白", "薄荷绿", "冠军金"]
var data: Dictionary = {"version": 1, "coins": 0, "skin": 0, "owned": [0], "best": 0.0, "records": [], "day": "", "daily": {}}

func _ready() -> void:
	var raw := Platform.storage_get("skyline_save")
	if raw.is_empty() and FileAccess.file_exists(PATH): raw = FileAccess.get_file_as_string(PATH)
	if not raw.is_empty():
		load_json(raw)
	ensure_day()

func load_json(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary: return
	# JSON numeric values are floats. Normalize integers explicitly on reload.
	for key in ["version", "coins", "skin"]:
		if parsed.get(key) is float or parsed.get(key) is int: data[key] = maxi(0, int(parsed[key]))
	data.skin = clampi(int(data.skin), 0, 7)
	if parsed.get("best") is float or parsed.get("best") is int: data.best = maxf(0, float(parsed.best))
	if parsed.get("owned") is Array:
		data.owned = [0]
		for value in parsed.owned:
			if (value is float or value is int) and int(value) >= 1 and int(value) <= 7 and int(value) not in data.owned: data.owned.append(int(value))
	if int(data.skin) not in data.owned: data.skin = 0
	if parsed.get("records") is Array: data.records = parsed.records.slice(0, 10)
	if parsed.get("day") is String: data.day = parsed.day
	if parsed.get("daily") is Dictionary:
		var daily: Dictionary = parsed.daily
		data.daily = {"races": int(daily.get("races", 0)), "coins": int(daily.get("coins", 0)), "boosts": int(daily.get("boosts", 0)), "claimed": daily.get("claimed", [])}

func ensure_day() -> void:
	# Daily tasks use UTC+8 consistently on desktop and WeChat.
	var day := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 28800).substr(0, 10)
	if data.day != day:
		data.day = day
		data.daily = {"races": 0, "coins": 0, "boosts": 0, "claimed": []}

func persist() -> void:
	var raw := JSON.stringify(data)
	Platform.storage_set("skyline_save", raw)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file: file.store_string(raw)

func buy_skin(index: int) -> bool:
	if index < 0 or index >= COLORS.size(): return false
	if index not in data.owned:
		var cost := index * 80
		if data.coins < cost: return false
		data.coins -= cost
		data.owned.append(index)
	data.skin = index
	persist()
	return true

func complete_race(rank: int, seconds: float, collected: int, boost_count: int) -> int:
	ensure_day()
	var reward := 30 + (7 - rank) * 10 + collected
	data.coins += reward
	data.daily.races += 1
	data.daily.coins += collected
	data.daily.boosts += boost_count
	if data.best == 0.0 or seconds < float(data.best): data.best = seconds
	data.records.append({"time": seconds, "rank": rank, "date": data.day})
	data.records.sort_custom(func(a, b): return float(a.time) < float(b.time))
	if data.records.size() > 10: data.records.resize(10)
	persist()
	return reward

func claim_task(index: int) -> bool:
	ensure_day()
	var keys := ["races", "coins", "boosts"]
	var goals := [3, 30, 5]
	if index < 0 or index > 2 or index in data.daily.claimed: return false
	if int(data.daily.get(keys[index], 0)) < goals[index]: return false
	data.daily.claimed.append(index)
	data.coins += [100, 80, 60][index]
	persist()
	return true
