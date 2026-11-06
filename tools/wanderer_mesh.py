"""Low-poly reference-inspired wanderer. Geometry is authored in Blender."""
import bpy, math
from mathutils import Vector

def build_wanderer(api):
    box, ellipsoid, cylinder, finish = (api[k] for k in ['box','ellipsoid','cylinder','finish_obj'])
    def mesh(name, verts, faces, color, bone):
        data=bpy.data.meshes.new(name)
        data.from_pydata(verts,[],faces);data.update()
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
        return finish(obj,color,bone)
    def rod(name,a,b,r,color,bone):
        a,b=Vector(a),Vector(b)
        obj=cylinder(name,(a+b)*.5,r,(b-a).length,color,6,bone)
        obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        return obj
    # Dark fitted clothes remain visible through the opening in the mantle.
    ellipsoid('tunic',(0,0,1.02),(.225,.14,.31),'#343b3e','Spine',8,3)
    ellipsoid('face',(0,-.04,1.48),(.155,.15,.18),'#c09677','Head',8,3)
    box('face_shadow',(0,-.18,1.52),(.29,.025,.08),'#292d2e','Head')
    box('mask',(0,-.16,1.41),(.25,.07,.10),'#4c5657','Head')
    for side,x in [('L',-.29),('R',.29)]:
        ellipsoid('sleeve'+side,(x,0,1.02),(.105,.10,.26),'#687173','Arm'+side,6,3)
        box('glove'+side,(x,-.015,.79),(.13,.14,.17),'#292f32','Arm'+side)
        ellipsoid('trouser'+side,(x*.48,0,.39),(.095,.10,.32),'#343c40','Leg'+side,6,3)
        box('boot'+side,(x*.48,-.06,.09),(.19,.31,.18),'#252b30','Leg'+side)
    # Open, flared cloak: alternating facets, with a separate cloth bone.
    angles=[-2.12,-1.59,-1.06,-.53,0,.53,1.06,1.59,2.12]
    verts=[]
    for radius,z in [(.25,1.34),(.39,.90),(.58,.30)]:
        for i,a in enumerate(angles):
            verts.append((math.sin(a)*radius,math.cos(a)*radius+.07,z+(.06*(i%2) if z<.4 else 0)))
    faces=[]
    n=len(angles)
    for row in range(2):
        for i in range(n-1): faces.append((row*n+i,row*n+i+1,(row+1)*n+i+1,(row+1)*n+i))
    cape=mesh('faceted_mantle',verts,faces,'#747d7e','Cape')
    attr=cape.data.color_attributes['Color']
    shades=['#566163','#7b8483','#939b98','#687375']
    for poly in cape.data.polygons:
        for li in poly.loop_indices: attr.data[li].color=api['rgb'](shades[poly.index%len(shades)])
    # The neck row follows the spine; lower rows sway with the cloth bone.
    group=cape.vertex_groups.new(name='Spine');group.add(list(range(n)),1,'REPLACE')
    cape.vertex_groups['Cape'].remove(list(range(n)))
    for sign in [-1,1]:
        mesh('lapel',[(sign*.06,-.16,1.33),(sign*.24,-.10,1.20),(sign*.33,-.09,.59),(sign*.10,-.18,.78)],[(0,1,2,3)],'#9aa19c','Spine')
    box('sash',(0,-.015,.88),(.47,.31,.065),'#753c39','Spine')
    cylinder('scarf',(0,0,1.34),.17,.105,'#9f3537',8,'Spine')
    # A wide, shallow straw hat with a shaded underside.
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.55,radius2=.035,depth=.23,location=(0,0,1.75))
    hat=finish(bpy.context.object,'#b9955e','Head');hat.name='straw_hat'
    attr=hat.data.color_attributes['Color']
    for poly in hat.data.polygons:
        color=api['rgb'](['#b79562','#c2a16b','#9c794e'][poly.index%3])
        for li in poly.loop_indices:attr.data[li].color=color
    verts=[(0,0,1.633)]+[(math.cos(i*math.tau/12)*.55,math.sin(i*math.tau/12)*.55,1.633) for i in range(12)]
    mesh('hat_underside',verts,[(0,1+(i+1)%12,1+i) for i in range(12)],'#39332b','Head')
    mesh('hair',[(0,.11,1.59),(-.18,.16,1.52),(-.25,.28,1.27),(-.08,.18,1.37),(.1,.18,1.49),(.22,.29,1.24)],[(0,1,2,3),(0,3,4),(4,3,5)],'#252c2e','Head')
    # Long red streamers, readable from the game's rear camera.
    for offset in [0,.12]:
        mesh('red_streamer',[(.12+offset,.11,1.34),(.19+offset,.15,1.34),(.46+offset,.35,1.18),(.58+offset,.61,1.05),(.48+offset,.65,1.06),(.38+offset,.38,1.13)],[(0,1,2,5),(5,2,3,4)],'#bb4542','Cape')
    # Diagonal polearm and a broad hooked steel tip.
    rod('polearm_shaft',(.32,-.08,1.12),(.84,-.10,.29),.022,'#3a3130','Weapon')
    rod('red_grip',(.39,-.08,1.00),(.47,-.08,.87),.032,'#9d3336','Weapon')
    outline=[(.77,.36),(.90,.34),(1.17,.10),(.94,.18),(.83,.20)]
    verts=[(x,y,z) for y in [-.13,-.08] for x,z in outline]
    faces=[(0,1,2,3,4),(9,8,7,6,5)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
    mesh('hooked_blade',verts,faces,'#aebbb7','Weapon')
    mesh('blade_edge',[(.90,-.135,.34),(1.17,-.135,.1),(.94,-.135,.18)],[(0,1,2)],'#e2e9dc','Weapon')

def render_preview(api):
    """Render the authored geometry, without editing the reference image."""
    import os
    for obj in bpy.context.scene.objects:
        if obj.type=='ARMATURE':
            for track in obj.animation_data.nla_tracks:track.mute=True
            for bone in obj.pose.bones:
                bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
    bpy.context.view_layer.update()
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.world.color=(.035,.09,.085)
    scene.view_settings.view_transform='Standard'
    bpy.ops.object.camera_add(location=(3.4,-6.0,3.0))
    camera=bpy.context.object;camera.rotation_euler=(Vector((.18,0,.95))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=2.7;scene.camera=camera
    for loc,power,size in [((2,-4,5),450,4),((-3,-1,3),180,3),((0,3,4),300,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=os.path.join(api['ROOT'],'build','wanderer_preview.png')
    bpy.ops.render.render(write_still=True)
    # The .blend opens in a clean rest pose with the eight NLA actions retained.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.shading.color_type='VERTEX'
                area.spaces.active.region_3d.view_location=(.1,0,.95)
                area.spaces.active.region_3d.view_distance=3.2
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(api['ROOT'],'art','runner_wanderer.blend'),compress=True)
