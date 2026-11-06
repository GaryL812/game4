"""Blender-authored Jiangnan / ink-wash modular scenery, no external mesh assets."""
import bpy, math, os, random

def generate_ink_assets(api):
    box, cylinder, finish, clear, export = (api[k] for k in ['box','cylinder','finish_obj','clear','export'])
    paper='#e6ddc3'; stone='#bfc3b1'; ink='#343e3b'; timber='#82745b'; brass='#b39b62'
    def mesh(name, verts, faces, color):
        data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
        return finish(obj,color)
    def roof(name,cx,cy,z,width,depth):
        # Hip roof with raised eaves, authored as a single 24-triangle surface.
        x=width*.5;y=depth*.5
        rings=[[(cx-x,cy-y,z+.17),(cx+x,cy-y,z+.17),(cx+x,cy+y,z+.17),(cx-x,cy+y,z+.17)],
               [(cx-x*.72,cy-y*.72,z),(cx+x*.72,cy-y*.72,z),(cx+x*.72,cy+y*.72,z),(cx-x*.72,cy+y*.72,z)],
               [(cx-x*.28,cy-y*.28,z+.8),(cx+x*.28,cy-y*.28,z+.8),(cx+x*.28,cy+y*.28,z+.8),(cx-x*.28,cy+y*.28,z+.8)]]
        verts=sum(rings,[]);faces=[]
        for row in range(2):
            for i in range(4):faces.append((row*4+i,row*4+(i+1)%4,(row+1)*4+(i+1)%4,(row+1)*4+i))
        faces.append((8,9,10,11))
        mesh(name,verts,faces,ink)
        box('ridge',(cx,cy,z+.82),(width*.7,.13,.11),ink)
    for name in ['deck_stone','deck_wood','deck_eaves','deck_bridge']:
        clear()
        box('cliff',(0,0,4),(14,24,8),stone)
        box('surface',(0,0,8.10),(14,24,.20),paper if name!='deck_wood' else '#b3a07c')
        if name=='deck_stone':
            for x in [-7,7]:box('stone_lip',(x,0,8.16),(.12,24,.08),ink)
        elif name=='deck_wood':
            for x in [-7,7]:
                box('handrail',(x,0,8.8),(.10,24,.10),timber)
                for y in [-10,0,10]:box('rail_post',(x,y,8.5),(.12,.12,.75),timber)
        elif name=='deck_eaves':
            for sign in [-1,1]:
                mesh('swept_eave',[(sign*6.8,-12,7.8),(sign*6.8,12,7.8),(sign*7.9,12,7.3),(sign*8.25,12,7.65),(sign*8.25,-12,7.65),(sign*7.9,-12,7.3)],[(0,1,2,5),(5,2,3,4)],ink)
            for y in [-12,12]:box('ridge_edge',(0,y,8.13),(14,.12,.08),ink)
        else:
            for x in [-7,7]:
                box('bridge_rail',(x,0,8.9),(.14,24,.14),stone)
                for y in [-10,0,10]:box('bridge_post',(x,y,8.57),(.22,.22,1),ink)
                # Dark arch inset under the bridge, low-poly painted stonework.
                verts=[(x*1.002,-7,0),(x*1.002,-7,4),(x*1.002,-4,6),(x*1.002,4,6),(x*1.002,7,4),(x*1.002,7,0)]
                mesh('arch_wash',verts,[(0,1,2,3,4,5)],'#808e80')
        export(name,'track')
    clear()
    # A tapered bamboo basket with dark hoops and an open-looking rim.
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.52,radius2=.67,depth=1.15,location=(0,0,.575))
    finish(bpy.context.object,'#a2956d')
    for z,r in [(.12,.55),(.95,.65),(1.16,.69)]:
        vertices=[(math.cos(i*math.tau/8)*r,math.sin(i*math.tau/8)*r,z+d) for d in [-.03,.03] for i in range(8)]
        mesh('woven_hoop',vertices,[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],'#5f6751')
    mesh('basket_opening',[(math.cos(i*math.tau/8)*.56,math.sin(i*math.tau/8)*.56,1.20) for i in range(8)],[tuple(range(8))],'#424d42')
    export('basket','interactive')
    clear()
    for x in [-.70,.70]:box('screen_post',(x,0,.78),(.10,.13,1.56),timber)
    box('rice_paper',(0,0,.84),(1.33,.07,1.25),paper)
    for z in [.21,1.46]:box('screen_frame',(0,0,z),(1.48,.13,.09),ink)
    for x in [-.45,0,.45]:mesh('ink_bamboo',[(x-.017,-.047,.33),(x+.017,-.047,.33),(x+.017,-.047,1.26),(x-.017,-.047,1.26)],[(0,1,2,3)],'#6a7763')
    for x in [-.45,0,.45]:
        mesh('painted_leaf',[(x,-.06,1.14),(x+.28,-.06,1.28),(x+.08,-.06,.98)],[(0,1,2)],'#526651')
    export('screen','interactive')
    clear()
    for x in [-.62,.62]:box('bell_frame',(x,0,.75),(.11,.14,1.5),timber)
    box('bell_beam',(0,0,1.53),(1.45,.18,.15),ink)
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.40,radius2=.27,depth=.65,location=(0,0,1.02));finish(bpy.context.object,brass)
    vertices=[(math.cos(i*math.tau/8)*.43,math.sin(i*math.tau/8)*.43,.69+d) for d in [-.04,.04] for i in range(8)]
    mesh('bell_rim',vertices,[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],'#7f744b')
    cylinder('bell_clapper',(0,0,.59),.09,.20,ink,6)
    box('red_tassel',(0,-.01,.39),(.045,.05,.24),'#a9483a')
    export('bell','interactive')
    for name,color in [('ink_pad','#8f957b'),('cloud_pad','#c0ac73')]:
        clear();box('board',(0,0,.20),(2.7,3.5,.35),color);bpy.context.object.rotation_euler.x=-.14
        for y in [-.9,0,.9]:
            for sign in [-1,1]:
                o=box('brush_arrow',(sign*.35,y,.52),(.91,.11,.025),ink);o.rotation_euler.z=sign*.65
        if name=='cloud_pad':
            for x in [-1.14,1.14]:box('gold_edge',(x,0,.44),(.055,3.1,.05),brass)
            for sign in [-1,1]:
                points=[]
                for j in range(10):
                    a=j*math.pi*1.65/9
                    for radius in [.23,.29]:points.append((sign*.65+math.cos(a)*radius,.25+math.sin(a)*radius,.55))
                mesh('cloud_curl',points,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(9)],paper)
        export(name,'interactive')
    clear()
    # Paper scroll gateway: fine pillars and curled roof, no modern checkerboard.
    for x in [-6,6]:box('gate_column',(x,0,2),(.24,.28,4),timber)
    box('hanging_scroll',(0,0,3.73),(5,.10,1.0),paper)
    for x in [-2.55,2.55]:cylinder('scroll_roller',(x,0,3.73),.09,1.15,ink,6)
    roof('gate_eaves',0,0,4.25,13,1.7)
    box('seal',(0,-.07,3.74),(.6,.025,.62),'#a24436')
    export('finish_scroll','interactive')
    for name,levels in [('pavilion',1),('pagoda',3)]:
        clear();box('stone_base',(0,0,.17),(3.8,3.8,.34),stone)
        for level in range(levels):
            z=.34+level*1.8
            size=3.3-level*.42
            for x in [-size*.35,size*.35]:
                for y in [-size*.35,size*.35]:box('wood_column',(x,y,z+.8),(.12,.12,1.6),timber)
            roof('curled_roof',0,0,z+1.5,size+1,size+1)
        export(name,'props')
    clear()
    for stem in range(3):
        x=(stem-1)*.45;y=stem*.11;h=3.8+stem*.6
        cylinder('bamboo',(x,y,h*.5),.045,h,'#52634b',5)
        for z in [1.0,1.9,2.8]:
            vertices=[(x+math.cos(i*math.tau/4)*.06,y+math.sin(i*math.tau/4)*.06,z+d) for d in [-.03,.03] for i in range(4)]
            mesh('node',vertices,[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)],'#263b32')
            for sign in [-1,1]:
                mesh('bamboo_leaf',[(x,y,z+.1),(x+sign*.95,y+.04,z+.55),(x+sign*.5,y-.02,z+.08)],[(0,1,2)],ink)
    export('bamboo','props')
    clear()
    # Broad silhouettes with several ridges, low-opacity base baked into colors.
    rng=random.Random(1206)
    n=25
    points=[(-18+i*1.5,0,0) for i in range(n)]
    for i in range(n):
        x=-18+i*1.5
        h=3+10*math.exp(-((x+9)/5)**2)+17*math.exp(-((x-2)/3.8)**2)+11*math.exp(-((x-11)/4.2)**2)+rng.random()*.9
        points.append((x,.15,h))
    obj=mesh('mountain_ridge',points,[(i,i+1,i+1+n,i+n) for i in range(n-1)],'#7f8d7c')
    attr=obj.data.color_attributes['Color']
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            v=obj.data.loops[li].vertex_index
            attr.data[li].color=api['rgb']('#e5e2ce' if v<n else ['#859180','#6d7c70','#9caa96'][v%3])
    export('mountain_ridge','background')
    for name in ['ink_drop','mist_card']:
        clear();bpy.ops.mesh.primitive_plane_add(size=1)
        finish(bpy.context.object,ink if name=='ink_drop' else paper)
        export(name,'effects')
    # One 128² repeatable monochrome grain map for the entire material family.
    folder=os.path.join(api['ROOT'],'assets','textures');os.makedirs(folder,exist_ok=True)
    rng=random.Random(3086);n=128;pixels=[]
    fibers=[rng.uniform(-.045,.045) for _ in range(n)]
    for y in range(n):
        for x in range(n):
            v=max(.05,min(.95,.51+rng.gauss(0,.11)+fibers[y]+.035*math.sin(x*.39+y*.12)))
            pixels.extend((v,v,v,1))
    img=bpy.data.images.new('PaperFiber128',width=n,height=n)
    img.pixels=pixels;img.filepath_raw=os.path.join(folder,'paper_grain.png');img.file_format='PNG';img.save()
