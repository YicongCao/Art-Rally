"""Original Art Rally meshes. Run: blender --background --python scripts/generate_vehicles.py
All dimensions are metres; body origin matches the physics chassis, forward is Godot -Z.
Wheels remain runtime physics-driven meshes. No external brands or art assets.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
def xyz(p): return (p[0],-p[2],p[1])
def material(name,c):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.48
    return m
def mesh(name,vs,fs,mat):
    me=bpy.data.meshes.new(name);me.from_pydata([xyz(v) for v in vs],[],fs);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
    return o
def box(name,pos,size,mat,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(pos));o=bpy.context.object;o.name=name
    o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Small edge highlights','BEVEL');mod.width=bevel;mod.segments=1
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o
def quad(name,vs,mat):return mesh(name,vs,[(0,1,2,3)],mat)
def beam(name,a,b,width,mat):
    va,vb=Vector(xyz(a)),Vector(xyz(b));bpy.ops.mesh.primitive_cube_add(size=1,location=(va+vb)/2);o=bpy.context.object;o.name=name;o.dimensions=(width,width,(vb-va).length);o.rotation_euler=(vb-va).to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat);return o
for ident,width,length,wb,roof,front,rear,number,col,accent in [
    ('F160',1.65,3.65,2.35,1.04,-.48,1.40,'16',(.88,.83,.66),(.02,.39,.36)),
    ('R200',1.76,4.15,2.50,.76,-.10,.85,'27',(.68,.055,.025),(.94,.85,.65)),
    ('A240',1.88,4.20,2.60,.91,-.57,.92,'44',(.025,.095,.40),(.95,.57,.035))]:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    paint=material(ident+' paint',col);trim=material(ident+' accent',accent);dark=material('Charcoal rubber',(.025,.035,.04));glass=material('Smoky blue glass',(.035,.075,.10));cream=material('Ivory',(.88,.85,.72));red=material('BrakeLamp',(.6,.025,.015));lamp=material('Headlamp',(.92,.82,.53));steel=material('Brushed trim',(.34,.39,.38))
    half=width/2;end=length/2
    # Continuous body surfaces and genuine wheel openings; no solid slab across tires.
    box('Upper body', (0,.20,0),(width,.24,length-.14),paint,.045)
    box('Sill floor',(0,-.13,0),(width-.2,.11,length-.22),dark)
    box('Front valance',(0,-.04,-end+.10),(width-.08,.24,.16),paint)
    box('Rear valance',(0,-.04,end-.10),(width-.08,.24,.16),paint)
    for side in [-1,1]:
        contour=[(-end+.10,-.18)]
        for axle in [-wb/2,wb/2]:
            contour.append((axle-.43,-.18))
            for j in range(13):
                a=math.pi-j*math.pi/12;contour.append((axle+.44*math.cos(a),-.34+.49*math.sin(a)))
        contour.append((end-.10,-.18))
        for j in range(len(contour)-1):
            a,b=contour[j:j+2]
            quad('Wheel opening body',[(side*half,a[1],a[0]),(side*half,b[1],b[0]),(side*half,.32,b[0]),(side*half,.32,a[0])],paint)
        for axle in [-wb/2,wb/2]:
            for j in range(12):
                a,b=j*math.pi/12,(j+1)*math.pi/12
                vs=[(side*(half+.025),-.34+r*math.sin(t),axle+r*math.cos(t)) for r,t in [(.45,a),(.45,b),(.51,b),(.51,a)]]
                quad('Flared arch',vs,paint if ident=='A240' else dark)
        box('Mirror',(side*(half+.09),.48,front-.15),(.17,.11,.23),trim)
        box('Door handle',(side*(half+.006),.28,.48),(.025,.035,.16),steel,.003)
        box('Mud flap',(side*(half-.08),-.39,wb/2+.40),(.22,.36,.025),dark,0)
    # Sloped glass with original pillars; roofs differ in height, length and rear silhouette.
    rw=half-.18; base_front=front-.42; base_rear=rear+(.49 if ident=='R200' else .17)
    quad('Windscreen',[(-half+.06,.33,base_front),(half-.06,.33,base_front),(rw,roof-.04,front),(-rw,roof-.04,front)],glass)
    quad('Rear glass',[(-rw,roof-.04,rear),(rw,roof-.04,rear),(half-.06,.33,base_rear),(-half+.06,.33,base_rear)],glass)
    box('Roof',(0,roof,(front+rear)/2),(rw*2+.07,.075,rear-front+.08),trim if ident=='F160' else paint,.025)
    for side in [-1,1]:
        quad('Side glass',[(side*(half-.04),.34,base_front+.06),(side*rw,roof-.055,front+.04),(side*rw,roof-.055,rear-.04),(side*(half-.04),.34,base_rear-.06)],glass)
        for a,b in [((side*(half-.025),.32,base_front),(side*rw,roof,front)),((side*(half-.025),.32,base_rear),(side*rw,roof,rear))]:beam('Pillar',a,b,.055,paint)
        for z in ([.35,.85] if ident=='A240' else [.44]):beam('Door pillar',(side*(half-.03),.32,z),(side*rw,roof-.015,z),.045,paint)
        box('Waist stripe',(side*(half+.009),.15,0),(.016,.09,length-.2),trim,0)
        # Race number plate and converted editable text, facing out on each door.
        plate=box('Number plate',(side*(half+.02),.02,.12),(.018,.24,.42),cream,0)
        bpy.ops.object.text_add(location=xyz((side*(half+.032),.025,.12)));t=bpy.context.object;t.name='Race number '+number;t.data.body=number;t.data.align_x='CENTER';t.data.align_y='CENTER';t.data.size=.225;t.data.extrude=.001;t.data.materials.append(dark)
        t.rotation_euler=(math.pi/2,0,side*math.pi/2)
        bpy.ops.object.convert(target='MESH')
        if ident=='F160':
            quad('Diagonal teal block',[(side*(half+.012),-.11,-.85),(side*(half+.012),.13,-.56),(side*(half+.012),.13,-.14),(side*(half+.012),-.11,-.44)],trim)
    box('Front bumper',(0,-.12,-end),(width+.03,.13,.13),dark)
    box('Rear bumper',(0,-.12,end),(width+.03,.13,.13),dark)
    box('Grille',(0,.115,-end+.015),(.65,.105,.035),dark,0)
    for side in [-1,1]:
        if ident=='R200':
            for dx in [-.11,.11]:
                bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.095,depth=.025,location=xyz((side*.57+dx,.17,-end-.005)),rotation=(math.pi/2,0,0));bpy.context.object.name='Round headlamp';bpy.context.object.data.materials.append(lamp)
        else:box('Square headlamp',(side*.58,.18,-end+.007),(.30,.16,.04),lamp,.008)
        size=(.11,.29,.035) if ident=='F160' else ((.53,.065,.035) if ident=='R200' else (.48,.12,.035))
        box('BrakeLamp',(side*(half-.17),.20,end-.009),size,red,.006)
    if ident=='R200':
        for x in [-.16,.16]:
            box('Hood racing stripe',(x,.326,(-end+base_front)/2),(.14,.008,base_front+end-.08),trim,0)
            box('Roof racing stripe',(x,roof+.041,(front+rear)/2),(.14,.008,rear-front),trim,0)
            box('Trunk racing stripe',(x,.326,(base_rear+end)/2),(.14,.008,end-base_rear-.02),trim,0)
        box('Ducktail',(0,.38,end-.15),(width-.1,.17,.18),paint,.025)
    elif ident=='F160':box('Roof spoiler',(0,roof+.035,rear+.10),(width-.18,.065,.22),trim,.012)
    else:
        box('Hood intake',(0,.38,-1.15),(.46,.13,.38),paint,.02);box('Intake mouth',(0,.38,-1.35),(.35,.075,.016),dark,0)
        for x in [-.58,.58]:box('Wing support',(x,.53,end-.27),(.065,.48,.10),dark,.005)
        box('Rear wing',(0,.79,end-.25),(width+.14,.075,.35),paint,.018)
        for side in [-1,1]:box('Gold endplate',(side*(half+.09),.78,end-.25),(.035,.25,.39),trim,.005)
    # Shared roll-cage language, distinct exterior proportions.
    beam('Aerial',(half-.15,roof, rear-.1),(half-.15,roof+.37,rear+.04),.009,dark)
    box('Rear plate',(0,.02,end+.02),(.37,.10,.02),cream,.004)
    bpy.context.scene['original_design']='Art Rally / '+ident+'; runtime wheels and cockpit; no external assets'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/vehicles'/f'{ident}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/vehicles'/f'{ident}.glb'),export_format='GLB',export_apply=True,export_yup=True)
print('Generated F160, R200, A240 editable sources and GLB bodies')
