class_name RooftopWorld
extends Node3D

const InkScenery = preload("res://scripts/ink_scenery.gd")

var game
var chunks: Array[Node3D] = []
var loose: Array[Dictionary] = []
var coins_multi: MultiMeshInstance3D
var sparks_multi: MultiMeshInstance3D
var coin_basis: Transform3D
var particles: Array[Dictionary] = []
var materials: Dictionary = {}
var phase := 0.0
var trail_clock := 0.0
var grain: Texture2D = preload("res://assets/textures/paper_grain.png")

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
		loose.append({"node":node,"z":float(obstacle.z)})
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
	var finish := model("finish_scroll",Vector3(last.x,last.height,TrackData.FINISH))
	loose.append({"node":finish,"z":TrackData.FINISH})
	var scenery := InkScenery.new()
	add_child(scenery)
	scenery.build()
	var ink := ShaderMaterial.new()
	ink.shader=preload("res://scripts/ink_particles.gdshader")
	ink.set_shader_parameter("paper_grain",grain)
	sparks_multi=create_multimesh("ink_drop",20,ink)
	for i in 20:
		particles.append({"position":Vector3.ZERO,"life":0.0,"duration":.5,"velocity":Vector3.ZERO,"kind":0.0,"size":.4,"seed":float(i)*.13})

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
	for chunk in chunks: chunk.visible=chunk.position.z>z-27 and chunk.position.z<z+74
	for entry in loose: entry.node.visible=float(entry.z)>z-15 and float(entry.z)<z+65
	var visible_coins := 0
	for i in game.track.coins.size():
		var coin: Dictionary=game.track.coins[i]
		if game.taken_coins.has(i) or float(coin.z)<=z-8 or float(coin.z)>=z+48: continue
		var transform := Transform3D(Basis(Vector3.UP,phase*2+i),Vector3(coin.x,coin.y,coin.z))
		coins_multi.multimesh.set_instance_transform(visible_coins,transform*coin_basis)
		visible_coins+=1
	coins_multi.multimesh.visible_instance_count=visible_coins
	trail_clock+=dt
	if game.state=="race" and game.player.boost_left>0 and trail_clock>.09:
		trail_clock=0
		burst(game.player.position+Vector3(0,.4,-.5),1,"trail")
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
