"""Run with Blender --background --python tools/create_assets.py.
Generate the procedural assets and export the authored hero. Coordinates are converted by glTF.
"""
import bpy, math, json, os, sys
from mathutils import Vector
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT,'tools'))
from wanderer_mesh import build_wanderer, render_preview
from ink_scene_assets import generate_ink_assets
from build_ink_stick_runner import export_runner
OUT = os.path.join(ROOT, 'assets', 'models')
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(ROOT, 'art'), exist_ok=True)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.context.preferences.filepaths.save_version = 0
manifest = []
palette = {'roof':'#c4ece4','edge':'#459c9e','building':'#36828b','dark':'#173c4a',
 'white':'#f4fbf4','gold':'#ffce45','orange':'#f48c5c','blue':'#5598ba','pink':'#f183a5'}
def rgb(value):
    value = palette.get(value, value).lstrip('#')
    return tuple((int(value[i:i+2],16)/255.0)**2.2 for i in (0,2,4))+(1,)
mat = bpy.data.materials.new('VertexPalette')
mat.use_nodes = True
mat.node_tree.nodes.clear()
shader = mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
output = mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
mat.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
shader.inputs['Roughness'].default_value = .85
vc = mat.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Color'
mat.node_tree.links.new(vc.outputs['Color'],shader.inputs['Base Color'])
def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def finish_obj(o, color, bone=None):
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.clear(); o.data.materials.append(mat)
    colors = o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for c in colors.data: c.color = rgb(color)
    if bone:
        group = o.vertex_groups.new(name=bone); group.add(list(range(len(o.data.vertices))),1,'REPLACE')
    return o
def box(name, loc, scale, color, bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    return finish_obj(o,color,bone)
def ellipsoid(name, loc, scale, color, bone=None, segments=8, rings=3):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    return finish_obj(o,color,bone)
def cylinder(name, loc, radius, depth, color, vertices=8, bone=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object; o.name=name
    return finish_obj(o,color,bone)
def join_meshes(name):
    bpy.ops.object.select_all(action='DESELECT')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]; bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.context.scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o
def export(name, category, animated=False):
    mesh=join_meshes(name)
    mesh.data.calc_loop_triangles(); tris=len(mesh.data.loop_triangles)
    folder=os.path.join(OUT,category);os.makedirs(folder,exist_ok=True)
    path=os.path.join(folder,name+'.glb')
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',export_yup=True,
        export_animations=animated,export_animation_mode='NLA_TRACKS',
        export_skins=animated,export_all_influences=False,export_apply=False,
        export_materials='EXPORT',export_cameras=False,export_lights=False)
    manifest.append({'name':name,'category':category,'triangles':tris,'bytes':os.path.getsize(path)})
    try:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art',name+'.blend'),compress=True)
    except RuntimeError:
        # Windows thumbnailing / an open Blender window may hold a source file.
        # Keep that file intact and save the regenerated source alongside it.
        alternative=os.path.join(ROOT,'art',name+'_generated.blend')
        bpy.ops.wm.save_as_mainfile(filepath=alternative,compress=True)
        print('SOURCE_IN_USE_SAVED_ALONGSIDE',name,alternative)
    for old in [os.path.join(OUT,name+'.glb'),os.path.join(OUT,name+'.glb.import')]:
        if os.path.isfile(old):os.unlink(old)
def character(name, variant=0):
    clear()
    if variant==3:
        build_wanderer(globals())
    else:
        # Bone-pivoted, rigid-weighted rounded geometry: <500 triangles total.
        ellipsoid('head',(0,0,1.57),(.22,.20,.23),'white','Head')
        ellipsoid('torso',(0,0,1.06),(.24,.16,.34),'white','Spine')
        box('visor',(0,-.178,1.60),(.27,.045,.065),'dark','Head')
        for side,x in [('L',-.29),('R',.29)]:
            ellipsoid('arm'+side,(x,0,1.01),(.085,.085,.29),'white','Arm'+side,6,3)
            ellipsoid('leg'+side,(x*.48,0,.39),(.105,.115,.34),'white','Leg'+side,6,3)
            box('shoe'+side,(x*.48,-.06,.075),(.22,.35,.15),'dark','Leg'+side)
        if variant==1: box('headband',(0,0,1.70),(.46,.42,.065),'gold','Head')
        if variant==2: box('chest',(0,-.16,1.1),(.31,.035,.18),'dark','Spine')
    mesh=join_meshes(name)
    arm_data=bpy.data.armatures.new('RunnerRig'); rig=bpy.data.objects.new('RunnerRig',arm_data)
    bpy.context.collection.objects.link(rig); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    defs={'Root':((0,0,0),(0,0,.25),None),'Spine':((0,0,.85),(0,0,1.35),'Root'),
      'Head':((0,0,1.35),(0,0,1.8),'Spine'),
      'ArmL':((-.29,0,1.27),(-.29,0,.72),'Spine'),'ArmR':((.29,0,1.27),(.29,0,.72),'Spine'),
      'LegL':((-.14,0,.72),(-.14,0,.05),'Root'),'LegR':((.14,0,.72),(.14,0,.05),'Root')}
    if variant==3:
        defs['Cape']=((0,.07,1.34),(0,.3,.45),'Spine')
        defs['Weapon']=((.32,-.08,1.12),(.7,-.1,.5),'Spine')
    for n,(h,t,p) in defs.items():
        b=arm_data.edit_bones.new(n);b.head=h;b.tail=t
        if p:b.parent=arm_data.edit_bones[p]
    bpy.ops.object.mode_set(mode='OBJECT')
    mod=mesh.modifiers.new('Skin','ARMATURE');mod.object=rig;mesh.parent=rig
    rig.animation_data_create()
    for anim,frames in [('Run',24),('Jump',24),('Land',12),('Flip',18),('Hit',18),('Celebrate',36),('Climb',24),('SideSlide',24)]:
        action=bpy.data.actions.new(anim);rig.animation_data.action=action
        for f in sorted(set(list(range(1,frames+1,3))+[frames])):
            t=(f-1)/(frames-1);wave=math.sin(t*math.tau)
            for p in rig.pose.bones:p.rotation_mode='XYZ';p.rotation_euler=(0,0,0);p.location=(0,0,0)
            if anim=='Run':
                rig.pose.bones['ArmL'].rotation_euler.x=wave*.8
                rig.pose.bones['ArmR'].rotation_euler.x=-wave*.8
                rig.pose.bones['LegL'].rotation_euler.x=-wave*.8
                rig.pose.bones['LegR'].rotation_euler.x=wave*.8
                rig.pose.bones['Root'].location.z=abs(wave)*.07
            elif anim=='Jump':
                rig.pose.bones['ArmL'].rotation_euler.x=-1.1;rig.pose.bones['ArmR'].rotation_euler.x=-1.1
                rig.pose.bones['LegL'].rotation_euler.x=.7;rig.pose.bones['LegR'].rotation_euler.x=-.5
            elif anim=='Flip':
                angle=-t*math.tau
                rig.pose.bones['Root'].rotation_euler.x=angle
                rig.pose.bones['Root'].location.y=.9*math.sin(angle)
                rig.pose.bones['Root'].location.z=.9*(1-math.cos(angle))
            elif anim=='Hit':rig.pose.bones['Spine'].rotation_euler.x=-.35*math.sin(t*math.pi)
            elif anim=='Land':rig.pose.bones['Root'].location.z=-.16*math.sin(t*math.pi)
            elif anim=='Celebrate':
                rig.pose.bones['ArmL'].rotation_euler.z=-2.5
                rig.pose.bones['ArmR'].rotation_euler.z=2.5
                rig.pose.bones['Root'].location.z=abs(wave)*.18
            elif anim=='Climb':
                rig.pose.bones['ArmL'].rotation_euler.x=-2.6+wave*.4
                rig.pose.bones['ArmR'].rotation_euler.x=-2.6-wave*.4
                rig.pose.bones['LegL'].rotation_euler.x=.7+wave*.35
                rig.pose.bones['LegR'].rotation_euler.x=.7-wave*.35
                rig.pose.bones['Spine'].rotation_euler.x=.12
            elif anim=='SideSlide':
                rig.pose.bones['Root'].location.z=-.3
                rig.pose.bones['Spine'].rotation_euler.x=-.45
                rig.pose.bones['LegL'].rotation_euler.x=-1.2
                rig.pose.bones['LegR'].rotation_euler.x=.7
                rig.pose.bones['ArmL'].rotation_euler.z=-1.1
                rig.pose.bones['ArmR'].rotation_euler.x=-1.3
            if variant==3:
                rig.pose.bones['Cape'].rotation_euler.x=.12*wave if anim=='Run' else (.18 if anim in ['Jump','Flip'] else 0)
                rig.pose.bones['Cape'].rotation_euler.y=.07*wave
                rig.pose.bones['Weapon'].rotation_euler.x=.65 if anim=='Climb' else .06*wave
                if anim=='Run':
                    rig.pose.bones['ArmR'].rotation_euler.x=-.2
            for p in rig.pose.bones:
                p.keyframe_insert(data_path='rotation_euler',frame=f)
                p.keyframe_insert(data_path='location',frame=f)
        track=rig.animation_data.nla_tracks.new();track.name=anim
        track.strips.new(anim,1,action)
        rig.animation_data.action=None
    bpy.context.scene.frame_set(1)
    export(name,'characters',True)
for v in range(3):character('runner_'+str(v),v)
character('runner_wanderer',3)
for name in ['cap','backpack','mohawk','crown','headphones']:
    clear()
    if name=='cap':
        ellipsoid('cap',(0,0,.09),(.25,.23,.14),'gold');box('brim',(0,-.21,.04),(.43,.27,.05),'gold')
    elif name=='backpack':box(name,(0,0,.2),(.36,.2,.42),'orange')
    elif name=='mohawk':
        for y in [-.12,0,.12]:box('crest',(0,y,.13),(.1,.12,.26),'pink')
    elif name=='crown':
        cylinder('ring',(0,0,.05),.25,.1,'gold')
        for x in [-.17,0,.17]:box('point',(x,-.17,.15),(.07,.07,.24),'gold')
    else:
        box('band',(0,0,.28),(.5,.09,.06),'dark')
        for x in [-.25,.25]:box('ear',(x,0,.13),(.09,.22,.25),'gold')
    export('accessory_'+name,'accessories')
for name,width,length,height in [('roof_wide',14,24,8),('roof_narrow',10,24,8),('roof_short',14,16,8),('roof_raised',14,24,9),('roof_corner',18,18,8)]:
    clear();box('building',(0,0,height/2),(width,length,height),'building')
    box('roof',(0,0,height+.10),(width+.3,length+.3,.2),'roof')
    for x in [-width/2,width/2]:box('trim',(x,0,height+.23),(.18,length,.16),'edge')
    for x in [-width/2-.01,width/2+.01]:
        for z in [4]:box('facade',(x,0,z),(.04,length*.85,.13),'edge')
    export(name,'track')
clear()
box('roof',(0,0,.25),(14,16,.5),'roof')
bpy.context.object.rotation_euler.x=.08
export('roof_slope','track')
clear()
box('ramp',(0,0,.24),(2.7,3.5,.45),'gold');bpy.context.object.rotation_euler.x=-.14
for y in [-.9,0,.9]:
    for sign in [-1,1]:
        o=box('chevron',(sign*.36,y,.55),(.9,.14,.03),'white');o.rotation_euler.z=sign*.6
export('boost','interactive')
clear();box('crate',(0,0,.65),(1.45,1.45,1.3),'orange')
for z in [.2,1.08]:box('brace',(0,-.74,z),(1.5,.06,.12),'gold')
export('crate','interactive')
clear();box('wall',(0,0,.9),(3.6,.75,1.8),'blue');box('cap',(0,0,1.85),(3.75,.9,.15),'white');export('wall','interactive')
clear()
for x in [-1.3,1.3]:box('post',(x,0,.6),(.13,.14,1.2),'dark')
box('rail',(0,0,1.16),(2.8,.15,.15),'orange');export('rail','interactive')
clear();cylinder('coin',(0,0,.42),.42,.13,'gold',8);bpy.context.object.rotation_euler.x=math.pi/2;export('coin','interactive')
clear()
for x in [-6,6]:box('pillar',(x,0,2),(0.36,.45,4),'gold')
box('banner',(0,0,3.9),(12.5,.5,.85),'dark')
for x in range(-6,7):box('tile',(x,0,3.9),(.5,.54,.7),'white' if x%2 else 'gold')
export('finish','interactive')
clear()
for x in [-6,6]:box('marker',(x,0,1),(.25,.3,2),'gold')
export('checkpoint','interactive')
clear()
for x in [-.65,.65]:
    for y in [-.65,.65]:box('leg',(x,y,.65),(.12,.12,1.3),'dark')
cylinder('tank',(0,0,1.9),.95,1.4,'blue',10)
bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=1.08,radius2=0,depth=.55,location=(0,0,2.85));finish_obj(bpy.context.object,'dark')
export('water_tower','props')
clear();box('unit',(0,0,.38),(1.5,1.1,.76),'white');cylinder('fan',(0,0,.8),.4,.05,'dark',8);export('aircon','props')
clear();box('shaft',(0,0,.7),(.8,.8,1.4),'orange');box('top',(0,0,1.4),(1,1,.2),'white');export('chimney','props')
clear();box('tower',(0,0,6),(.4,.4,12),'gold');box('arm',(0,0,11),(12,.35,.35),'gold');box('cable',(4,0,8),(.05,.05,6),'dark');export('crane','props')
clear();box('tower',(0,0,4),(5,5,8),'blue');export('city_block','background')
clear()
bpy.ops.mesh.primitive_circle_add(vertices=12,radius=.46,fill_type='NGON');finish_obj(bpy.context.object,'dark');export('shadow','effects')
clear();box('spark',(0,0,.035),(.07,.07,.07),'gold');export('spark','effects')
generate_ink_assets(globals())
manifest.insert(4,export_runner(ROOT))
with open(os.path.join(ROOT,'art','asset_manifest.json'),'w',encoding='utf8') as f:json.dump(manifest,f,ensure_ascii=False,indent=2)
print('ASSET_BUILD_OK',len(manifest),'models',sum(x['triangles'] for x in manifest),'unique triangles')

# Keep the model source and ship a direct Blender render for visual review.
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art','runner_wanderer.blend'))
render_preview(globals())
