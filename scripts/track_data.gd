class_name TrackData
extends RefCounted

const SEGMENT_LENGTH := 24.0
const GAP := 4.5
const STRIDE := SEGMENT_LENGTH + GAP
const COUNT := 34
const FINISH := (COUNT - 1) * STRIDE + 18.0
const BASE_SPEED := 11.0
const LANES := [-4.2, 0.0, 4.2]
var roofs: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var boosts: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var checkpoints: Array[float] = [0.0]

func _init() -> void:
	for i in COUNT:
		var start := i * STRIDE - 8.0
		var width := 10.0 if i % 7 == 5 else 14.0
		roofs.append({"start": start, "end": start + SEGMENT_LENGTH, "width": width, "index": i})
		if i > 0 and i % 6 == 0:
			checkpoints.append(start + 3.0)
		if i > 0 and i < COUNT - 1:
			var lane := (i * 7 + 1) % 3
			obstacles.append({"x": LANES[lane], "z": start + 9.0, "kind": "wall" if i % 4 == 0 else "crate", "width": 1.9 if i % 4 == 0 else .85})
			if i % 3 == 0:
				obstacles.append({"x": LANES[(lane + 1) % 3], "z": start + 14.0, "kind": "rail", "width": 1.6})
		if i % 2 == 1:
			boosts.append({"x": LANES[(i + 1) % 3], "z": start + 18.0})
		for j in 4:
			coins.append({"x": LANES[(i + 2) % 3], "z": start + 5.0 + j * 2.5})

func platform_at(x: float, z: float) -> bool:
	var i := clampi(int(floor((z + 8.0) / STRIDE)), 0, COUNT - 1)
	var r := roofs[i]
	return z >= float(r.start) and z <= float(r.end) and absf(x) <= float(r.width) * .5

func edge_ahead(x: float, z: float, distance: float) -> bool:
	return platform_at(x, z) and not platform_at(x, z + distance)

func checkpoint_at(z: float) -> float:
	var value := 0.0
	for point in checkpoints:
		if z >= point: value = point
	return value
