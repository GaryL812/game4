class_name RooftopWorld
extends Node3D

var game
var chunks: Array[Node3D] = []
var loose: Array[Dictionary] = []
var coins_multi: MultiMeshInstance3D
var sparks_multi: MultiMeshInstance3D
var coin_basis: Transform3D
var particles: Array[Dictionary] = []
var phase := 0.0

func model(key: String, pos: Vector3, parent: Node = self) -> Node3D:
	var instance: Node3D = game.models[key].instantiate()
	parent.add_child(instance)
	instance.position = pos
	for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_node.mesh.get_surface_count():
			var material = mesh_node.mesh.surface_get_material(surface)
			if material is StandardMaterial3D: material.vertex_color_use_as_albedo = true
	return instance

func build(owner_game) -> void:
	game = owner_game
	for r in game.track.roofs:
		var chunk := Node3D.new()
		add_child(chunk)
		chunks.append(chunk)
		chunk.position.z = (float(r.start) + float(r.end)) * .5
		model("roof_narrow" if float(r.width) == 10 else "roof_wide", Vector3(0, -8.2, 0), chunk)
		var i := int(r.index)
		if i % 3 == 0: model("water_tower", Vector3(5.3, .03, 6), chunk)
		if i % 3 == 1: model("aircon", Vector3(-5.6, .03, 4), chunk)
		if i % 4 == 2: model("chimney", Vector3(5.7, .03, -6), chunk)
		# Sparse background columns, merged vertex colors and no textures.
		for side in [-1, 1]:
			var city := model("city_block", Vector3(side * (16.0 + (i % 3) * 5), -18.0, 8), chunk)
			city.scale = Vector3(1.5 + (i % 3) * .3, 1.4 + (i % 4) * .7, 1.8)
		if i % 7 == 2: model("crane", Vector3(-20, -2, 6), chunk)
	for o in game.track.obstacles:
		var node := model(o.kind, Vector3(o.x, 0, o.z))
		loose.append({"node": node, "z": float(o.z)})
	for o in game.track.boosts:
		var node := model("boost", Vector3(o.x, 0, o.z))
		loose.append({"node": node, "z": float(o.z)})
	coins_multi = create_multimesh("coin", game.track.coins.size())
	var coin_source: Node3D = game.models.coin.instantiate()
	add_child(coin_source)
	coin_basis = coin_source.find_children("*", "MeshInstance3D", true, false)[0].global_transform
	coin_source.free()
	for z in game.track.checkpoints:
		var node := model("checkpoint", Vector3(0, 0, z))
		loose.append({"node": node, "z": z})
	var finish := model("finish", Vector3(0, 0, TrackData.FINISH))
	loose.append({"node": finish, "z": TrackData.FINISH})
	# Fixed pool: no instantiation or freeing during a race.
	sparks_multi = create_multimesh("spark", 20)
	for i in 20:
		particles.append({"position": Vector3.ZERO, "life": 0.0, "velocity": Vector3.ZERO})

func create_multimesh(key: String, count: int) -> MultiMeshInstance3D:
	var source: Node3D = game.models[key].instantiate()
	var mesh_node: MeshInstance3D = source.find_children("*", "MeshInstance3D", true, false)[0]
	mesh_node.mesh.surface_get_material(0).vertex_color_use_as_albedo = true
	var instance := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh_node.mesh
	multi.instance_count = count
	multi.visible_instance_count = 0
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	source.free()
	return instance

func update_view(z: float, dt: float) -> void:
	phase += dt
	for chunk in chunks:
		chunk.visible = chunk.position.z > z - 35 and chunk.position.z < z + 82
	for entry in loose:
		entry.node.visible = float(entry.z) > z - 15 and float(entry.z) < z + 72
	var visible_coins := 0
	for i in game.track.coins.size():
		var coin: Dictionary = game.track.coins[i]
		if game.taken_coins.has(i) or float(coin.z) <= z - 8 or float(coin.z) >= z + 65: continue
		var transform := Transform3D(Basis(Vector3.UP, phase * 2 + i), Vector3(coin.x, 1.0, coin.z))
		coins_multi.multimesh.set_instance_transform(visible_coins, transform * coin_basis)
		visible_coins += 1
	coins_multi.multimesh.visible_instance_count = visible_coins
	var visible_sparks := 0
	for p in particles:
		if float(p.life) <= 0: continue
		p.life -= dt
		p.position += p.velocity * dt
		p.velocity.y -= dt * 8
		if float(p.life) > 0:
			var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(.1, float(p.life) * 2)), p.position)
			sparks_multi.multimesh.set_instance_transform(visible_sparks, transform)
			visible_sparks += 1
	sparks_multi.multimesh.visible_instance_count = visible_sparks

func burst(pos: Vector3, amount: int) -> void:
	if Platform.low_end: return
	var used := 0
	for p in particles:
		if float(p.life) > 0: continue
		p.life = .45
		p.position = pos + Vector3(0, .15, 0)
		p.velocity = Vector3(sin(used * 2.4) * 3, 2 + used * .12, cos(used * 2.4) * 3)
		used += 1
		if used >= amount: break
