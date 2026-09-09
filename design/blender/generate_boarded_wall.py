"""Rebuild Boarded's original climbing-wall campaign asset in Blender, headless.

Usage: Blender --background --python design/blender/generate_boarded_wall.py
No external textures, add-ons, network downloads or Python packages are needed.
The source image is a visual reference, never embedded or sampled as a texture.
"""
from pathlib import Path
import bpy
import bmesh
import math
import random
import json
from mathutils import Vector
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from climber_ascent import build_climber

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'public/walls/generated'
PREVIEW = ROOT / 'work/asset-previews'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
random.seed(42)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablock in bpy.data.materials:
    bpy.data.materials.remove(datablock)

def linear(c):
    return c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4

def material(name, color, roughness=.78, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = tuple(linear(int(color[i:i+2],16)/255) for i in (0,2,4)) + (1,)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = mat.diffuse_color
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat

M = {
    'chalk': material('Chalk • matte climbing surface', 'D9DDD5'),
    'slate': material('Slate • lower panels', '303B40'),
    'edge': material('Birch • laminated edge', 'A58C65'),
    'wood': material('Birch • rear structure', 'C3A77D'),
    'steel': material('Graphite • powder-coated support', '293338', .68),
    'black': material('Recesses • soft charcoal', '111B20'),
    'metal': material('Hardware • brushed steel', '82928F', .48, .45),
    'mint': material('Resin • send green', '32D583', .64),
    'yellow': material('Resin • golden yellow', 'F6CA40', .67),
    'coral': material('Resin • vermilion', 'F36B50', .67),
    'blue': material('Resin • glacier blue', '55A9DE', .68),
    'cream': material('Resin • warm chalk', 'F2E8D4', .78),
}
meshes = []

def finish(obj, name, mat, smooth=False, bevel=0):
    obj.name = name
    obj.data.materials.append(M[mat])
    if bevel:
        mod = obj.modifiers.new('Small manufactured edge radius', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for p in obj.data.polygons: p.use_smooth = True
    if bevel:
        mod = obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
        mod.weight = 40
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    meshes.append(obj)
    return obj

def cube(name, loc, size, mat, bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj=bpy.context.object
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj,name,mat,bevel=bevel)

def bar(name, a, b, width, depth, mat, bevel=.01):
    a,b = Vector(a),Vector(b)
    obj=cube(name,(a+b)/2,(width,depth,(b-a).length),mat,bevel)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return obj

def mesh(name, verts, faces, mat, smooth=False, bevel=0):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,smooth,bevel)

W,H,KICK = 2.4384,3.6576,.43
TILT=math.radians(14)
U=Vector((1,0,0))
UP=Vector((0,-math.sin(TILT),math.cos(TILT)))
N=Vector((0,-math.cos(TILT),-math.sin(TILT)))

def surface(x,z,offset=0):
    # z is world-space vertical height, not slanted panel length.
    y=-max(0,z-KICK)*math.tan(TILT)
    n=N if z>=KICK else Vector((0,-1,0))
    return Vector((x,y,z))+n*offset

def panel(name, coords, mat, front=0, thickness=.018, bevel=.004):
    normal=N if min(c[1] for c in coords)>=KICK else Vector((0,-1,0))
    verts=[surface(x,z,front) for x,z in coords]
    verts += [v-normal*thickness for v in verts]
    n=len(coords)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,mat,bevel=bevel)

# Thin laminated panel core, with a clean birch perimeter visible in silhouette.
panel('Upper continuous birch core',[(-W/2,KICK),(W/2,KICK),(W/2,H),(-W/2,H)],'edge',-.018,.082,.008)
panel('Vertical kickboard core',[(-W/2,.10),(W/2,.10),(W/2,KICK),(-W/2,KICK)],'edge',-.018,.082,.006)
G=.006
for col in range(3):
    x0=-W/2+col*W/3+G
    x1=-W/2+(col+1)*W/3-G
    boundary=lambda x: .94-.14*x
    b0,b1=boundary(x0),boundary(x1)
    panel(f'Slate lower panel {col+1}',[(x0,KICK+G),(x1,KICK+G),(x1,b1-G),(x0,b0-G)],'slate')
    panel(f'Chalk middle panel {col+1}',[(x0,b0+G),(x1,b1+G),(x1,2.24-G),(x0,2.24-G)],'chalk')
    panel(f'Chalk upper panel {col+1}',[(x0,2.24+G),(x1,2.24+G),(x1,H-G),(x0,H-G)],'chalk')
    panel(f'Slate vertical kick {col+1}',[(x0,.105),(x1,.105),(x1,KICK-G),(x0,KICK-G)],'slate')

# Rear framing remains physically credible during the complete turn.
for x in (-1.105,-.405,.405,1.105):
    bar('Rear birch vertical stringer',surface(x,KICK,-.16),surface(x,H-.05,-.16),.083,.13,'wood',.009)
for z in (.53,1.63,2.63,3.56):
    bar('Rear birch transverse rail',surface(-1.15,z,-.23),surface(1.15,z,-.23),.085,.085,'wood',.008)
for x in (-1.0,1.0):
    # Long low runners, and rear legs tied into upper stringers.
    cube('Rounded charcoal outrigger',(x,.23,.055),(.17,1.60,.11),'steel',.035)
    cube('Front rubber shoe',(x,-.50,.020),(.195,.21,.040),'black',.015)
    cube('Rear rubber shoe',(x,.96,.020),(.195,.21,.040),'black',.015)
    bar('Rear support spar',(x,.90,.12),surface(x,3.25,-.25),.11,.11,'steel',.018)
    bar('Lower triangular tie',(x,.89,.16),surface(x,.50,-.23),.075,.075,'steel',.011)
bar('Lower rear cross member',(-1,.84,.24),(1,.84,.24),.07,.07,'steel')
bar('Rear diagonal cross brace A',surface(-1.02,.53,-.283),surface(1.02,2.63,-.283),.04,.025,'steel',.006)
bar('Rear diagonal cross brace B',surface(1.02,.53,-.283),surface(-1.02,2.63,-.283),.04,.025,'steel',.006)

def disk(name, pos, normal, radius, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    obj=bpy.context.object
    obj.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler()
    return finish(obj,name,mat,smooth=False)

# Bolt grid is geometry instead of a texture, preserving crisp holes at all angles.
for row in range(16):
    z=.20+row*.211
    for col in range(11):
        x=-1.075+col*.215
        n=N if z>=KICK else Vector((0,-1,0))
        disk('Recessed T-nut',surface(x,z,.001),n,.0085,.002,'black',10)
for x in (-1.105,1.105):
    for z in (.60,1.63,2.63,3.48):
        rear_depth = -.273 if z in (1.63,2.63) else -.2285
        disk('Rear frame bolt',surface(x,z,rear_depth),-N,.016,.007,'metal',12)

def hold(name,x,z,sx,sy,depth,color,kind='dome',angle=0,phase=0):
    """Small custom radial sculpture. Cups have actual recessed concave grip bowls."""
    origin=surface(x,z,-.001)
    normal=N if z>=KICK else Vector((0,-1,0))
    up=UP if z>=KICK else Vector((0,0,1))
    ca,sa=math.cos(angle),math.sin(angle)
    ax=U*ca+up*sa
    ay=-U*sa+up*ca
    verts=[]
    rings=[]
    if kind=='cup':
        # Outside, rounded lip, inside wall, and recessed dish floor.
        profile=[(1.0,0), (1.04,.22),(.96,.60),(.80,.93),(.64,.95),(.51,.69),(.39,.24),(.13,.17)]
    elif kind=='pinch':
        profile=[(1,0),(1.04,.16),(.87,.61),(.48,.94),(.12,1)]
    elif kind=='jug':
        profile=[(1,0),(1.03,.2),(.94,.52),(.80,.90),(.63,1),(.44,.78),(.10,.67)]
    else:
        profile=[(1,0),(1.02,.23),(.86,.62),(.51,.91),(.12,1)]
    SEG=24
    for r,h in profile:
        ids=[]
        for j in range(SEG):
            a=2*math.pi*j/SEG
            wave=1+.095*math.sin(3*a+phase)+.038*math.cos(5*a-phase)
            # Small asymmetry and off-center crest make each resin form tactile.
            px=math.cos(a)*r*wave*sx+sx*.10*h
            py=math.sin(a)*r*wave*sy+sy*.14*h
            lip=(.90+.10*math.sin(a+.4)) if kind in ('cup','jug') else 1
            p=origin+ax*px+ay*py+normal*depth*h*lip
            ids.append(len(verts)); verts.append(p)
        rings.append(ids)
    faces=[tuple(reversed(rings[0]))]
    for i in range(len(rings)-1):
        for j in range(SEG):
            faces.append((rings[i][j],rings[i][(j+1)%SEG],rings[i+1][(j+1)%SEG],rings[i+1][j]))
    faces.append(tuple(rings[-1]))
    obj=mesh(name,verts,faces,color,True)
    # Sculpt smoothness uses a single evaluated subdivision, baked into glTF.
    mod=obj.modifiers.new('Rounded resin sculpture','SUBSURF')
    mod.levels=1
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # A subtle small Allen bolt communicates scale without noisy lettering.
    h=.18 if kind=='cup' else (.69 if kind=='jug' else 1)
    p=origin+ax*sx*.10*h+ay*sy*.14*h+normal*(depth*h+.003)
    disk('Hold recessed hex socket',p,normal,.008,.003,'black',6)
    return obj

# Three low-profile, asymmetric triangular climbing volumes.
def volume(name,points,peak):
    verts=[surface(x,z,-.001) for x,z in points]+[surface(*peak)]
    faces=[(0,2,1),(0,1,3),(1,2,3),(2,0,3)]
    return mesh(name,verts,faces,'steel',bevel=.012)
volume('Left graphite tetrahedral volume',[(-.97,1.47),(-.82,2.07),(-.32,1.71)],(-.72,1.70,.23))
volume('High graphite blade',[(-.20,2.45),(.17,3.20),(.46,2.45)],(.18,2.67,.20))
volume('Lower right graphite volume',[(.39,.67),(1.01,.77),(.76,1.26)],(.72,.90,.18))

# 31 holds: five deliberately legible resin families, ranging from jugs to feet.
# Coordinates are authored by hand; they are promotional artwork, not route data.
HOLDS=[
 ('mint',-.85,3.25,.23,.13,.15,'jug',-.40),
 ('yellow',-.33,3.34,.14,.17,.13,'cup',.30),
 ('coral',.73,3.27,.20,.125,.15,'jug',.40),
 ('blue',1.00,2.90,.095,.12,.085,'pinch',-.35),
 ('blue',-.68,2.81,.13,.12,.13,'cup',-.15),
 ('coral',-.26,2.92,.07,.11,.07,'pinch',.40),
 ('mint',.52,2.84,.075,.105,.065,'dome',.10),
 ('yellow',.88,2.45,.22,.18,.15,'cup',-.45),
 ('coral',-.98,2.41,.075,.125,.065,'pinch',-.30),
 ('yellow',-.43,2.35,.12,.085,.08,'jug',.05),
 ('mint',.10,2.13,.20,.14,.16,'jug',-.30),
 ('blue',.58,2.03,.13,.095,.12,'jug',.35),
 ('cream',1.00,1.81,.075,.07,.065,'dome',.15),
 ('coral',-.32,1.80,.115,.14,.12,'cup',-.50),
 ('yellow',.15,1.63,.09,.065,.07,'pinch',.20),
 ('mint',.80,1.53,.105,.10,.09,'jug',.30),
 ('blue',-.89,1.18,.19,.14,.15,'cup',.45),
 ('coral',-.39,1.23,.105,.10,.075,'jug',-.20),
 ('yellow',.30,1.12,.155,.13,.14,'cup',-.30),
 ('mint',-.06,.87,.10,.08,.085,'jug',.35),
 ('blue',.20,.58,.08,.055,.06,'pinch',.1),
 ('coral',-.69,.70,.095,.06,.065,'jug',-.35),
 ('cream',.98,.48,.065,.045,.04,'dome',.15),
 ('yellow',-.97,.26,.08,.045,.045,'pinch',.10),
 ('mint',-.38,.26,.065,.05,.048,'dome',-.15),
 ('coral',.39,.27,.065,.047,.048,'pinch',.10),
 ('blue',.86,.24,.085,.04,.05,'jug',.10),
 ('yellow',-1.00,2.01,.042,.04,.045,'dome',0),
 ('mint',-.04,3.48,.05,.047,.05,'dome',0),
 ('coral',1.03,2.20,.044,.055,.05,'pinch',-.10),
 ('blue',-.58,1.48,.055,.042,.05,'pinch',.40),
]
for i,(color,x,z,sx,sy,depth,kind,angle) in enumerate(HOLDS):
    hold(f'{i+1:02d} • {color} sculpted {kind}',x,z,sx,sy,depth,color,kind,angle,i*.9)

# Give the poster and model the same stable, centered root in exported coordinates.
bpy.context.view_layer.update()
allpoints=[obj.matrix_world @ Vector(v) for obj in meshes for v in obj.bound_box]
bmin=Vector(tuple(min(v[i] for v in allpoints) for i in range(3)))
bmax=Vector(tuple(max(v[i] for v in allpoints) for i in range(3)))
center=(bmin+bmax)/2
for obj in meshes: obj.location-=center

# Join by material after modeling: 12 material primitives / draw calls total.
joined=[]
material_groups = {
    key: [obj for obj in meshes if obj.data.materials[0] == mat]
    for key, mat in M.items()
}
for key,group in material_groups.items():
    if not group: continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in group: obj.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=f'Wall_{key}'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    joined.append(obj)

pivot=bpy.data.objects.new('BoardedWall',None)
bpy.context.collection.objects.link(pivot)
for obj in joined: obj.parent=pivot
pivot['description']='Original playful climbing wall, inferred from supplied gym photo; decorative campaign artwork.'
pivot['face_width_m']=W
pivot['nominal_height_m']=H
pivot['face_height_m']=H-.10
pivot['overhang_degrees']=14
pivot['hold_count']=len(HOLDS)
pivot['front']='glTF +Z; glTF +Y up'
pivot['scroll_animation']='ClimberAscent, 12 seconds; wall root remains static for runtime auto-rotation.'
scene=bpy.context.scene
character,rig,climb_report=build_climber(pivot,M,material,HOLDS,surface,center,UP,N)
(PREVIEW/'climber-contact-report.json').write_text(json.dumps(climb_report,indent=2)+'\n')
(ROOT/'design/blender/climber-contact-report.json').write_text(json.dumps(climb_report,indent=2)+'\n')
scene.frame_set(0)

# Export the static wall root plus the animated skin. No cameras or lights.
bpy.ops.object.select_all(action='DESELECT')
for obj in joined+[character,rig,pivot]: obj.select_set(True)
bpy.context.view_layer.objects.active=pivot
bpy.ops.export_scene.gltf(
    filepath=str(OUT/'boarded-wall.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name='ClimberAscent',
    export_force_sampling=True,export_frame_range=True,export_frame_step=1,
    export_normals=True,export_tangents=False,export_texcoords=False,
    export_materials='EXPORT',export_extras=True,export_cameras=False,export_lights=False,
)

def aim(obj,target=(0,0,0)):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

# Broad softboxes, neutral-warm key, gentle cool edge; no HDRI or texture payload.
world=bpy.data.worlds.new('Soft neutral studio')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.52,.56,.61,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.32
scene.world=world
def area(name,loc,power,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.location=loc; aim(obj)
area('Large warm key',(-3.5,-4.5,6),750,4.0,(1,.90,.79))
area('Cool soft fill',(4,-2,2),420,4.0,(.78,.88,1))
area('Clean rear rim',(1.5,3,4.5),950,3.0,(.91,.96,1))
camera_data=bpy.data.cameras.new('Campaign orthographic portrait')
camera=bpy.data.objects.new('Campaign orthographic portrait',camera_data)
bpy.context.collection.objects.link(camera)
camera.location=(5.9,-10,5.2)
aim(camera,(0,0,.07))
camera_data.type='ORTHO'; camera_data.ortho_scale=4.70
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.cycles.max_bounces=6
scene.render.resolution_x=1200;scene.render.resolution_y=1440;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.filepath=str(PREVIEW/'boarded-wall-hero.png')
scene.camera.data.lens=55
scene.unit_settings.system='METRIC'
scene.unit_settings.length_unit='METERS'

triangles=sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in joined+[character])
stats={
 'asset':'boarded-wall.glb','faceWidthMeters':W,'nominalHeightMeters':H,'faceHeightMeters':H-.10,
 'overhangDegrees':14,'holdCount':len(HOLDS),'meshCount':len(joined)+1,
 'materialCount':len(M),'primitiveCount':len(joined)+len(character.data.materials),'triangles':triangles,'glbBytes':(OUT/'boarded-wall.glb').stat().st_size,
 'boundsMetersBlender':list(bmax-bmin),'gltfConvention':'+Y up, +Z front, centered origin',
 'animation':{'name':'ClimberAscent','durationSeconds':12,'boneCount':len(rig.data.bones),'sampleCount':361,'interpolation':'LINEAR'},
 'climber':{'heightMeters':1.5,'limbTransfers':18,'minimumPlantedContacts':3,'animatedBoundsBlender':climb_report['conservativeAnimatedBoundsBlender']},
}
(PREVIEW/'asset-stats.json').write_text(json.dumps(stats,indent=2)+'\n')
(ROOT/'design/blender/asset-stats.json').write_text(json.dumps(stats,indent=2)+'\n')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'design/blender/boarded-wall.blend'))
bpy.ops.render.render(write_still=True)
# Pillow is not needed for conversion: Blender writes alpha-preserving WebP.
img=bpy.data.images['Render Result']
scene.render.image_settings.file_format='WEBP';scene.render.image_settings.quality=90
img.save_render(str(OUT/'boarded-wall-poster.webp'),scene=scene)
scene.render.image_settings.file_format='PNG'
scene.render.resolution_x=700;scene.render.resolution_y=840
scene.cycles.samples=24
for label,frame in (('start',0),('mid',180),('reach',290),('top',360)):
    scene.frame_set(frame)
    scene.render.filepath=str(PREVIEW/f'climber-{label}.png')
    bpy.ops.render.render(write_still=True)
print('ASSET_STATS '+json.dumps(stats))
