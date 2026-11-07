class_name RooftopWorld
extends Node3D

const InkScenery = preload("res://scripts/ink_scenery.gd")
const SwordFX = preload("res://scripts/sword_fx.gd")
const FINISH_GATE_TEXTURE = preload("res://assets/ink_bg/finish_gate.png")

var game
var chunks: Array[Node3D] = []
var loose: Array[Dictionary] = []
var coins_multi: MultiMeshInstance3D
var sparks_multi: MultiMeshInstance3D
var coin_basis: Transform3D
var particles: Array[Dictionary] = []
var materials: Dictionary = {}
var phase := 0.0
var grain: Texture2D = preload("res://assets/textures/paper_grain.png")
var obstacle_nodes: Array[Node3D] = []
var destroyed_obstacles: Dictionary = {}
var sword_fx: Node3D
var finish_gate: Sprite3D

func destroy_obstacle(index: int) -> void:
	if destroyed_obstacles.has(index): return
	destroyed_obstacles[index] = true
	obstacle_nodes[index].visible = false
	sword_fx.splash(obstacle_nodes[index].position)

func reset_combat() -> void:
	destroyed_obstacles.clear()
	sword_fx.clear()
	for entry in loose:
		entry.node.visible = float(entry.z) > game.player.position.z - 15 and float(entry.z) < game.player.position.z + 65

func material_for(key: String) -> ShaderMaterial:
	if materials.has(key): return materials[key]
	var material := ShaderMaterial.new()
	material.shader=preload("res://scripts/ink_world.gdshader")
	material.set_shader_parameter("paper_grain",grain)
	var mode := 3
	if key in ["deck_stone","deck_bridge"]: mode=0
	elif key=="deck_wood": mode=1
	elif key=="deck_eaves": mode=2
	elif key in ["ink_pad","cloud_pad"]: mode=5
	material.set_shader_parameter("surface_mode",mode)
	materials[key]=material
	return material

func model(key: String,pos: Vector3,parent: Node=self) -> Node3D:
	var instance: Node3D=game.models[key].instantiate()
	parent.add_child(instance)
	instance.position=pos
	for mesh_node in instance.find_children("*","MeshInstance3D",true,false):
		mesh_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.material_override=material_for(key)
	return instance

func build(owner_game) -> void:
	game=owner_game
	var decks := ["deck_stone","deck_wood","deck_eaves","deck_bridge"]
	for roof in game.track.roofs:
		var chunk := Node3D.new()
		add_child(chunk)
		chunks.append(chunk)
		chunk.position.z=(float(roof.start)+float(roof.end))*.5
		var index := int(roof.index)
		var key: String=decks[(index+int(roof.branch))%4]
		var deck := model(key,Vector3(roof.x,TrackData.BUILDING_BASE,0),chunk)
		deck.scale=Vector3(float(roof.width)/14.0,1,1)
		deck.scale.z = (float(roof.end)-float(roof.start))/TrackData.SEGMENT_LENGTH
		var span := float(roof.height)-TrackData.BUILDING_BASE
		var cache_key := key+str(span)
		if not materials.has(cache_key):
			var surface: ShaderMaterial=material_for(key).duplicate()
			surface.set_shader_parameter("stretch_platform",true)
			surface.set_shader_parameter("platform_span",span)
			surface.set_shader_parameter("platform_stone",preload("res://assets/textures/ink_stone.webp"))
			materials[cache_key]=surface
		for mesh_node in deck.find_children("*","MeshInstance3D",true,false):
			mesh_node.material_override=materials[cache_key]
			mesh_node.custom_aabb=AABB(Vector3(-8.5,0,-13),Vector3(17,span+2,26))
	for i in game.track.obstacles.size():
		var obstacle: Dictionary=game.track.obstacles[i]
		var key: String=["basket","screen","bell"][i%3]
		var node := model(key,Vector3(obstacle.x,obstacle.y,obstacle.z))
		if float(obstacle.width)>1: node.scale.x=1.6
		obstacle_nodes.append(node)
		loose.append({"node":node,"z":float(obstacle.z),"obstacle":i})
	for i in game.track.boosts.size():
		var pad: Dictionary=game.track.boosts[i]
		var node := model("ink_pad" if i%2==0 else "cloud_pad",Vector3(pad.x,pad.y,pad.z))
		loose.append({"node":node,"z":float(pad.z)})
	coins_multi=create_multimesh("coin",game.track.coins.size(),material_for("coin"))
	var coin_source: Node3D=game.models.coin.instantiate()
	add_child(coin_source)
	coin_basis=coin_source.find_children("*","MeshInstance3D",true,false)[0].global_transform
	coin_source.free()
	var last: Dictionary=game.track.sections[-1][0]
	finish_gate = Sprite3D.new()
	finish_gate.name = "InkFinishGate"
	finish_gate.texture = FINISH_GATE_TEXTURE
	finish_gate.pixel_size = 36.0/FINISH_GATE_TEXTURE.get_width()
	finish_gate.offset = Vector2(0,FINISH_GATE_TEXTURE.get_height()*.235)
	finish_gate.position = Vector3(last.x,last.height,TrackData.FINISH)
	finish_gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	finish_gate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var gate_ink := ShaderMaterial.new()
	gate_ink.shader = preload("res://scripts/finish_gate.gdshader")
	gate_ink.set_shader_parameter("gate_texture",FINISH_GATE_TEXTURE)
	gate_ink.render_priority = -1
	finish_gate.material_override = gate_ink
	add_child(finish_gate)
	var scenery := InkScenery.new()
	add_child(scenery)
	scenery.build()
	var ink := ShaderMaterial.new()
	ink.shader=preload("res://scripts/ink_particles.gdshader")
	ink.set_shader_parameter("paper_grain",grain)
	sparks_multi=create_multimesh("ink_drop",20,ink)
	for i in 20:
		particles.append({"position":Vector3.ZERO,"life":0.0,"duration":.5,"velocity":Vector3.ZERO,"kind":0.0,"size":.4,"seed":float(i)*.13})
	sword_fx = SwordFX.new()
	add_child(sword_fx)

func create_multimesh(key: String,count: int,material: Material) -> MultiMeshInstance3D:
	var source: Node3D=game.models[key].instantiate()
	var mesh_node: MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
	var instance := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_custom_data=true
	multi.mesh=mesh_node.mesh
	multi.instance_count=count
	multi.visible_instance_count=0
	multi.custom_aabb=AABB(Vector3(-100,-30,-30),Vector3(200,100,1200))
	instance.multimesh=multi
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	source.free()
	return instance

func update_view(z: float,dt: float) -> void:
	phase+=dt
	for i in chunks.size():
		var roof: Dictionary = game.track.roofs[i]
		chunks[i].visible = float(roof.end)>z-27 and float(roof.start)<z+74
	finish_gate.visible = z>TrackData.FINISH-180 and z<TrackData.FINISH+25
	for entry in loose:
		entry.node.visible = not destroyed_obstacles.has(entry.get("obstacle", -1)) and float(entry.z)>z-15 and float(entry.z)<z+65
	if game.state == "race": sword_fx.tick(dt, game.player)
	var visible_coins := 0
	for i in game.track.coins.size():
		var coin: Dictionary=game.track.coins[i]
		if game.taken_coins.has(i) or float(coin.z)<=z-8 or float(coin.z)>=z+48: continue
		var transform := Transform3D(Basis(Vector3.UP,phase*2+i),Vector3(coin.x,coin.y,coin.z))
		coins_multi.multimesh.set_instance_transform(visible_coins,transform*coin_basis)
		visible_coins+=1
	coins_multi.multimesh.visible_instance_count=visible_coins
	var visible_ink := 0
	for p in particles:
		if float(p.life)<=0: continue
		p.life-=dt
		p.position+=p.velocity*dt
		p.velocity.y-=dt*(.6 if float(p.kind)>0 else 7.0)
		if float(p.life)>0:
			var fade := float(p.life)/float(p.duration)
			var scale_value := float(p.size)*(1.0+(1.0-fade)*(3.0 if float(p.kind)>1.5 else 1.2))
			var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),p.position)
			sparks_multi.multimesh.set_instance_transform(visible_ink,transform)
			sparks_multi.multimesh.set_instance_custom_data(visible_ink,Color(p.kind,fade,p.seed,1))
			visible_ink+=1
	sparks_multi.multimesh.visible_instance_count=visible_ink

func burst(pos: Vector3,amount: int,kind: String="jump") -> void:
	if Platform.low_end: return
	var used := 0
	for p in particles:
		if float(p.life)>0: continue
		p.duration=.65 if kind in ["trail","hit"] else .48
		p.life=p.duration
		p.kind=2.0 if kind=="hit" else (1.0 if kind=="trail" else 0.0)
		p.size=.9 if kind=="hit" else (.45 if kind=="trail" else .2+used*.025)
		p.position=pos+Vector3(0,.12,0)
		p.velocity=Vector3(0,.5,-.9) if kind in ["trail","hit"] else Vector3(sin(used*2.4)*2,1.5+used*.1,cos(used*2.4)*2)
		used+=1
		if used>=amount: break
