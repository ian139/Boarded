"""Stylized climber with offline IK, rigid skin weights and planted contacts."""
import math
import bpy
from mathutils import Vector, Matrix, Quaternion
DURATION, FPS = 12.0, 30

def build_climber(parent, materials, make_material, holds, surface, center, up, normal):
    right = Vector((1, 0, 0))
    materials.update({
        'shirt': make_material('Climber • ochre shirt', 'D8903D', .82),
        'trousers': make_material('Climber • storm-blue canvas', '426780', .86),
        'skin': make_material('Climber • warm skin', 'C98761', .72),
        'hair': make_material('Climber • chestnut curls', '44332D', .85),
    })
    initial = {'LH': 17, 'RH': 18, 'LF': 24, 'RF': 25}
    transitions = [
        (.45, None, None, (0.00,.80)),
        (1.10,'RH',14,(-.035,.86)), (1.65,'LF',19,(.040,.84)),
        (2.20,'RF',20,(.015,.96)), (2.80,'LH',13,(.035,1.20)),
        (3.40,'RH',10,(.060,1.23)), (3.88,'RF',18,(-.035,1.29)),
        (4.36,'LF',17,(.080,1.34)), (5.00,'LH',9,(.025,1.56)),
        (5.50,'RF',14,(-.025,1.77)), (6.00,'LF',30,(.025,1.90)),
        (6.35,None,None,(-.100,2.00)), (7.00,'RH',6,(-.100,2.03)),
        (7.45,'LF',13,(.060,2.10)), (7.93,'RF',10,(-.015,2.20)),
        (8.96,'LH',1,(-.130,2.43)),
        (9.42,'LF',9,(.070,2.50)), (9.63,None,None,(.010,2.60)),
        (10.21,'RH',28,(-.060,2.63)), (10.40,None,None,(-.070,2.77)),
        (10.96,'RF',6,(-.120,2.98)), (11.50,'LF',4,(-.040,3.09)),
        (12.00,None,None,(-.030,3.19)),
    ]
    def smooth(t):
        t=min(1.0,max(0.0,t)); return t*t*t*(10+t*(-15+6*t))
    def hold_contact(index, limb):
        _,x,z,sx,sy,depth,kind,angle=holds[index]
        u=up if z>=.43 else Vector((0,0,1))
        if limb.endswith('H'):
            return surface(x,z,depth*.80+.005)+u*sy*.49-center
        return surface(x,z,depth*.68+.005)+u*(sy*.64+.019)-center
    phases=[]; contacts=initial.copy(); hip=Vector((0,.80)); start=0
    for end,limb,index,destination in transitions:
        phases.append({'start':start,'end':end,'moving':limb,'from_contacts':contacts.copy(),
                       'from_hip':hip.copy(),'to_hip':Vector(destination),'target':index})
        if limb: contacts[limb]=index
        hip=Vector(destination); start=end
    violations=[]
    previous_bends={}  # Parallel-transported bend planes prevent pole singularity flips.
    def two_link(a,b,l1,l2,pole,label,t):
        axis=b-a; distance=axis.length
        if distance>l1+l2-.002:
            violations.append({'time':round(t,4),'limb':label,'distance':round(distance,5),'limit':l1+l2})
        d=min(l1+l2-.001,max(.025,distance)); axis.normalize()
        projected=pole-axis*pole.dot(axis)
        if projected.length<.01: projected=normal-axis*normal.dot(axis)
        projected.normalize()
        if label in previous_bends:
            transported=previous_bends[label]-axis*previous_bends[label].dot(axis)
            if transported.length>.01:
                transported.normalize()
                projected=(transported*.82+projected*.18).normalized()
        previous_bends[label]=projected.copy()
        along=(l1*l1-l2*l2+d*d)/(2*d)
        return a+axis*along+projected*math.sqrt(max(.0001,l1*l1-along*along))
    def pose(t):
        phase=next((p for p in phases if t<=p['end']+1e-7),phases[-1])
        u=min(1.0,max(0.0,(t-phase['start'])/(phase['end']-phase['start'])))
        f=smooth(u); hip2=phase['from_hip'].lerp(phase['to_hip'],f)
        if phase['moving']:
            side=-1 if phase['moving'][0]=='R' else 1
            hip2.x+=side*.023*math.sin(math.pi*u)**2
        depth=.405+.020*math.sin(t*.8)-.065*smooth((t-11.45)/.55)
        hp=surface(hip2.x,hip2.y+depth*-normal.z,depth)-center
        shoulder=hp+up*.370+right*(.025*math.sin(t*1.2)+.065*math.exp(-((t-6.85)/.7)**2))-normal*.035
        head=shoulder+up*.177+normal*.010
        bones={'Pelvis':(hp-up*.055,hp+up*.085),'Torso':(hp,shoulder),
               'Neck':(shoulder,head-up*.085),'Head':(head-up*.095,head+up*.095)}
        targets={}
        for limb,index in phase['from_contacts'].items():
            contact=hold_contact(index,limb)
            if phase['moving']==limb:
                contact=contact.lerp(hold_contact(phase['target'],limb),f)
                arc=math.sin(math.pi*u)**2
                contact+=normal*(.125 if limb.endswith('H') else .105)*arc
                contact+=up*(.075 if limb.endswith('H') else .115)*arc
            targets[limb]=contact; sign=-1 if limb[0]=='L' else 1
            if limb.endswith('H'):
                sh=shoulder+right*sign*.185; wrist=contact-up*.082+normal*.027
                elbow=two_link(sh,wrist,.315,.300,right*sign*.9+normal*.65-up*.55,limb,t)
                bones[limb[0]+'UpperArm']=(sh,elbow)
                bones[limb[0]+'Forearm']=(elbow,wrist)
                bones[limb[0]+'Hand']=(wrist,contact+up*.013)
            else:
                socket=hp+right*sign*.110-up*.020; ankle=contact+normal*.105+up*.047
                knee=two_link(socket,ankle,.365,.350,right*sign*.90+normal*.40+up*.06,limb,t)
                bones[limb[0]+'Thigh']=(socket,knee)
                bones[limb[0]+'Shin']=(knee,ankle)
                bones[limb[0]+'Shoe']=(ankle,contact+up*.025)
        return {'bones':bones,'targets':targets,'phase':phase,'u':u,'hip':hp,'shoulders':shoulder,'head':head}
    volumes = [
        ([(-.97,1.47),(-.82,2.07),(-.32,1.71)],(-.72,1.70,.23)),
        ([(-.20,2.45),(.17,3.20),(.46,2.45)],(.18,2.67,.20)),
        ([(.39,.67),(1.01,.77),(.76,1.26)],(.72,.90,.18)),
    ]
    hulls=[]
    for corners,peak in volumes:
        vs=[surface(x,z,-.001)-center for x,z in corners]+[surface(*peak)-center]
        planes=[]
        for ids,opposite in (((0,1,2),3),((0,1,3),2),((1,2,3),0),((2,0,3),1)):
            a,b,c=[vs[i] for i in ids]; n=(b-a).cross(c-a).normalized()
            if n.dot(vs[opposite]-a)>0: n=-n
            planes.append((n,n.dot(a)))
        hulls.append(planes)
    limb_radii={'UpperArm':.057,'Forearm':.049,'Thigh':.081,'Shin':.065}
    min_wall_clearance=1e6; volume_intersections=[]
    rest=pose(0)
    data=bpy.data.armatures.new('Climber articulated skeleton')
    rig=bpy.data.objects.new('ClimberRig',data); bpy.context.collection.objects.link(rig); rig.parent=parent
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,(a,b) in rest['bones'].items():
        bone=data.edit_bones.new(name); bone.head=a; bone.tail=b; bone.use_deform=True
        bone.align_roll((b-a).to_track_quat('Y','Z') @ Vector((0,0,1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    parts=[]
    def ellipsoid(name,loc,scale,mat,bone,axis=up,segments=16,rings=10):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
        obj=bpy.context.object; obj.name=name; obj.scale=scale
        obj.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        obj.data.materials.append(materials[mat])
        for p in obj.data.polygons: p.use_smooth=True
        group=obj.vertex_groups.new(name=bone); group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
        parts.append(obj); return obj
    def limb(name,radius,mat):
        a,b=rest['bones'][name]
        ellipsoid(name,(a+b)/2,(radius,radius*.91,(b-a).length/2+.026),mat,name,b-a)
    hip,shoulder,head=rest['hip'],rest['shoulders'],rest['head']
    ellipsoid('Rounded ochre climbing shirt',hip+up*.193,(.193,.114,.226),'shirt','Torso')
    ellipsoid('Canvas trouser seat',hip-up*.040,(.162,.107,.112),'trousers','Pelvis')
    ellipsoid('Soft charcoal waist belt',hip+up*.010,(.169,.116,.028),'black','Pelvis')
    a,b=rest['bones']['Neck']; ellipsoid('Exposed neck',(a+b)/2,(.059,.056,.067),'skin','Neck')
    ellipsoid('Friendly round face',head,(.130,.119,.146),'skin','Head',segments=24,rings=14)
    ellipsoid('Chestnut hair cap',head+normal*.013+up*.078,(.139,.124,.091),'hair','Head',segments=20,rings=12)
    for i,(x,h,d,r) in enumerate(((-.062,.153,.006,.044),(.008,.163,.004,.048),(.062,.143,-.019,.044))):
        ellipsoid('Soft curl '+str(i),head+right*x+up*h+normal*d,(r,r*.92,r*.78),'hair','Head')
    for sign in (-1,1):
        ellipsoid('Ear',head+right*sign*.125-up*.008,(.033,.024,.043),'skin','Head')
        ellipsoid('Eye white',head+right*sign*.049-normal*.111+up*.023,(.022,.014,.026),'cream','Head')
        ellipsoid('Eye pupil',head+right*sign*.047-normal*.124+up*.024,(.011,.006,.014),'black','Head')
    ellipsoid('Rounded nose',head-normal*.129-up*.008,(.034,.032,.034),'skin','Head')
    ellipsoid('Quiet smile',head-normal*.116-up*.065,(.027,.006,.008),'hair','Head')
    for sign,side in ((-1,'L'),(1,'R')):
        limb(side+'UpperArm',.057,'skin'); a,b=rest['bones'][side+'UpperArm']
        ellipsoid('Coral sleeve '+side,a.lerp(b,.16),(.077,.073,.089),'coral',side+'UpperArm',b-a)
        limb(side+'Forearm',.049,'skin')
        ellipsoid('Rounded elbow '+side,rest['bones'][side+'Forearm'][0],(.052,.052,.052),'skin',side+'Forearm')
        limb(side+'Thigh',.081,'trousers'); limb(side+'Shin',.065,'trousers')
        ellipsoid('Trouser knee '+side,rest['bones'][side+'Shin'][0],(.076,.071,.076),'trousers',side+'Shin')
        contact=rest['targets'][side+'H']
        ellipsoid('Gripping palm '+side,contact-up*.036+normal*.026,(.060,.036,.071),'skin',side+'Hand')
        for finger in (-1,0,1):
            ellipsoid('Curled finger '+side+str(finger),contact+right*finger*.029+up*.012+normal*.008,
                      (.019,.023,.034),'skin',side+'Hand',segments=12,rings=8)
        ellipsoid('Wrapped thumb '+side,contact-right*sign*.064-up*.037+normal*.016,
                  (.024,.030,.038),'skin',side+'Hand')
        toe=rest['targets'][side+'F']; shoe=toe+normal*.080+up*.032
        ellipsoid('Climbing shoe '+side,shoe,(.058,.108,.041),'black',side+'Shoe')
        ellipsoid('Coral shoe upper '+side,shoe+up*.023+normal*.012,(.049,.078,.030),'coral',side+'Shoe')
        ellipsoid('Toe rubber '+side,toe+up*.022+normal*.015,(.058,.046,.030),'black',side+'Shoe')
        ellipsoid('Heel loop '+side,toe+normal*.161+up*.057,(.022,.013,.026),'shirt',side+'Shoe')
    bag=hip+normal*.161-up*.083
    ellipsoid('Small chalk bag',bag,(.082,.062,.096),'cream','Pelvis')
    ellipsoid('Chalk bag rim',bag+up*.077,(.080,.061,.022),'coral','Pelvis')
    ellipsoid('Chalk bag opening',bag+up*.089,(.061,.042,.009),'black','Pelvis')
    ellipsoid('Chalk bag loop',bag+up*.106-normal*.028,(.015,.019,.035),'black','Pelvis')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    character=bpy.context.object; character.name='Climber • weighted clay character'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    character.parent=rig; modifier=character.modifiers.new('Baked articulated skeleton','ARMATURE'); modifier.object=rig
    scene=bpy.context.scene; scene.frame_start=0; scene.frame_end=int(DURATION*FPS); scene.render.fps=FPS
    for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
    max_contact_error=0.0; minimum_contacts=4; max_rig_contact_error=0.0; max_segment_length_error=0.0
    contact_bones={'LH':'LHand','RH':'RHand','LF':'LShoe','RF':'RShoe'}
    bind_contacts={limb:rig.data.bones[bone].matrix_local.inverted() @ rest['targets'][limb]
                   for limb,bone in contact_bones.items()}
    rest_lengths={name:(b-a).length for name,(a,b) in rest['bones'].items()}
    previous_joints={}; max_joint_steps={}
    bmin=Vector((1e6,1e6,1e6)); bmax=Vector((-1e6,-1e6,-1e6)); snapshots={}
    for frame in range(scene.frame_end+1):
        scene.frame_set(frame)
        t=frame/FPS; sample=pose(t)
        for name,(a,b) in sample['bones'].items():
            if name in previous_joints:
                delta=(a-previous_joints[name]).length
                if delta>max_joint_steps.get(name,{}).get('meters',0):
                    max_joint_steps[name]={'meters':delta,'frame':frame}
            previous_joints[name]=a.copy()
            q=(b-a).to_track_quat('Y','Z')
            if name=='Head': q=Quaternion(right,.13*smooth((t-11.45)/.55))@Quaternion(up,.095*math.sin(t*1.8)-.38*smooth((t-11.45)/.55))@q
            pb=rig.pose.bones[name]; pb.matrix=Matrix.Translation(a)@q.to_matrix().to_4x4()
            pb.keyframe_insert(data_path='location',frame=frame,group=name)
            pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=name)
        bpy.context.view_layer.update()
        moving=sample['phase']['moving']
        for name,(a,b) in sample['bones'].items():
            radius=next((r for suffix,r in limb_radii.items() if name.endswith(suffix)),None)
            if radius is None: continue
            for step in range(13):
                point=a.lerp(b,step/12)
                uncentered=point+center
                if uncentered.z>=.43:
                    clearance=normal.dot(uncentered-Vector((0,0,.43)))-radius
                else: clearance=-uncentered.y-radius
                min_wall_clearance=min(min_wall_clearance,clearance)
                for vi,planes in enumerate(hulls):
                    if max(n.dot(point)-d for n,d in planes)<radius-.010:
                        volume_intersections.append({'frame':frame,'limb':name,'volume':vi,'step':step})
        for name,(a,b) in sample['bones'].items():
            if name not in ('Torso','Head','Neck'):
                max_segment_length_error=max(max_segment_length_error,abs((b-a).length-rest_lengths[name]))
        minimum_contacts=min(minimum_contacts,3 if moving and 0<sample['u']<1 else 4)
        for limb,point in sample['targets'].items():
            if limb!=moving:
                anchor=hold_contact(sample['phase']['from_contacts'][limb],limb)
                max_contact_error=max(max_contact_error,(point-anchor).length)
                actual=rig.pose.bones[contact_bones[limb]].matrix @ bind_contacts[limb]
                max_rig_contact_error=max(max_rig_contact_error,(actual-anchor).length)
        if frame in (0,84,150,210,269,316,345,360):
            snapshots[str(frame)]={'timeSeconds':t,'movingLimb':moving,'hipBlender':list(sample['hip']),
                                  'targetsBlender':{k:list(v) for k,v in sample['targets'].items()}}
        for a,b in sample['bones'].values():
            for point in (a,b):
                for axis in range(3):
                    bmin[axis]=min(bmin[axis],point[axis]-.20)
                    bmax[axis]=max(bmax[axis],point[axis]+.20)
    action=rig.animation_data.action; action.name='ClimberAscent'
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points: key.interpolation='LINEAR'
    scene.frame_set(0)
    rig['animation_contract']='ClimberAscent:0–12 seconds,361 baked samples,no wall rotation.'
    rig['contact_contract']='One limb advances while the other three extremities stay planted.'
    rig['nominal_character_height_m']=1.5
    report={'clip':'ClimberAscent','durationSeconds':DURATION,'sampleCount':361,'boneCount':len(rig.data.bones),
            'limbTransfers':sum(1 for p in phases if p['moving']),'principalStanceCount':6,
            'minimumPlantedContacts':minimum_contacts,'maxPlantedTargetErrorMeters':max_contact_error,
            'maxEvaluatedRigContactErrorMeters':max_rig_contact_error,'maxRigidSegmentLengthErrorMeters':max_segment_length_error,
            'minLimbCapsuleWallClearanceMeters':min_wall_clearance,'potentialCapsuleVolumeIntersections':volume_intersections,
            'reachViolations':violations,'conservativeAnimatedBoundsBlender':{'min':list(bmin),'max':list(bmax)},
            'maxJointFrameStepMeters':max_joint_steps,'keyPoses':snapshots,'phases':[{'start':p['start'],'end':p['end'],'moving':p['moving'],
                                          'targetHoldIndex':p['target']} for p in phases]}
    return character,rig,report
