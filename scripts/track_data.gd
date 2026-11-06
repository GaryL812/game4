class_name TrackData
extends RefCounted

const SEGMENT_LENGTH := 24.0
const GAP := 4.5
const STRIDE := SEGMENT_LENGTH + GAP
const COUNT := 34
const FINISH := (COUNT - 1) * STRIDE + 12.0
const BASE_SPEED := 11.0
const LANES := [-6.0, 0.0, 6.0]
const BUILDING_BASE := -16.0
var roofs: Array[Dictionary] = []
var sections: Array[Array] = []
var obstacles: Array[Dictionary] = []
var boosts: Array[Dictionary] = []
var coins: Array[Dictionary] = []

func _init() -> void:
	for i in COUNT:
		var start := i * STRIDE - 8.0
		var heights := [0.0, 2.4, 5.0, 1.0, 4.2, 6.4, 2.0, -.8, 3.6, 1.2]
		var height: float = heights[i % heights.size()]
		var split := i % 6 in [2, 3, 4] and i < COUNT - 2
		var section: Array = []
		for branch in (3 if split else 1):
			var x := float(branch-1)*6.0 if split else sin(i * .7) * 1.0
			var width := 4.6 if split else 17.6
			var y := height + (float([0.0,1.6,3.0][(branch+i)%3]) if split else 0.0)
			var roof := {"id": roofs.size(), "start": start, "end": start + SEGMENT_LENGTH, "x": x, "width": width, "height": y, "index": i, "branch": branch}
			roofs.append(roof)
			section.append(roof)
			if i > 0 and i < COUNT - 1:
				var crate := split or i%3!=0
				var offset := 1.55 if split else 1.8
				obstacles.append({"x": x + (offset if (i+branch)%2 == 0 else -offset), "y": y, "z": start + 10, "kind": "crate" if crate else "rail", "width": .85 if crate else 1.4})
			if (i+branch)%2 == 1 and i < COUNT-1:
				boosts.append({"x": x, "y": y, "z": start + 18})
			for j in 3:
				coins.append({"x": x, "y": y + 1.0, "z": start + 5 + j*2.7})
		sections.append(section)

func section_index(z: float) -> int:
	return clampi(int(floor((z + 8.0) / STRIDE)), 0, COUNT - 1)

func surface_at(x: float, z: float) -> Dictionary:
	for roof in sections[section_index(z)]:
		if z >= float(roof.start) and z <= float(roof.end) and absf(x-float(roof.x)) <= float(roof.width)*.5:
			return roof
	return {}

func height_at(x: float, z: float) -> float:
	var roof := surface_at(x, z)
	return float(roof.height) if not roof.is_empty() else -INF

func platform_at(x: float, z: float) -> bool:
	return not surface_at(x,z).is_empty()

func edge_ahead(x: float, z: float, distance: float) -> bool:
	return platform_at(x, z) and not platform_at(x, z + distance)

func lanes_ahead(z: float) -> Array[float]:
	var result: Array[float] = []
	var index := section_index(z)
	if z > float(sections[index][0].end)-8 and index < COUNT-1: index += 1
	for roof in sections[index]:
		result.append(float(roof.x))
		if float(roof.width) > 10:
			result.append(float(roof.x)-4.0)
			result.append(float(roof.x)+4.0)
	return result

func wall_contact(from: Vector3, to: Vector3) -> Dictionary:
	# Swept front/side faces. Heights and collision use the same authored roofs.
	for index in range(maxi(0, section_index(from.z)-1), mini(COUNT, section_index(to.z)+2)):
		for roof in sections[index]:
			var top := float(roof.height)
			if to.y >= top-.12 or to.y+1.8 < BUILDING_BASE: continue
			var left := float(roof.x)-float(roof.width)*.5
			var right := float(roof.x)+float(roof.width)*.5
			var front := float(roof.start)-.34
			if from.z <= front and to.z >= front and to.x > left-.15 and to.x < right+.15:
				return {"roof": roof, "face": "front", "side": 0}
			if to.z > float(roof.start) and to.z < float(roof.end):
				if (from.x <= left and to.x >= left-.38) or (absf(to.x-left)<.38 and from.y >= to.y):
					return {"roof": roof, "face": "side", "side": -1}
				if (from.x >= right and to.x <= right+.38) or (absf(to.x-right)<.38 and from.y >= to.y):
					return {"roof": roof, "face": "side", "side": 1}
	return {}
