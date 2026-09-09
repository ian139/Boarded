"""Headless rendered review evidence; no changes to the canonical blend or GLB."""
from pathlib import Path
from array import array
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'work/asset-previews'
OUT.mkdir(parents=True,exist_ok=True)

def sheet(names,filename,columns=2):
    images=[bpy.data.images.load(str(OUT/n),check_existing=False) for n in names]
    w,h=images[0].size; gutter=24; rows=(len(images)+columns-1)//columns
    width=columns*w+(columns-1)*gutter; height=rows*h+(rows-1)*gutter
    pixels=array('f',[0])*(width*height*4)
    for i,img in enumerate(images):
        src=array('f',[0])*(w*h*4); img.pixels.foreach_get(src)
        x=(i%columns)*(w+gutter); y=(rows-1-i//columns)*(h+gutter)
        for row in range(h):
            begin=((y+row)*width+x)*4
            pixels[begin:begin+w*4]=src[row*w*4:(row+1)*w*4]
    result=bpy.data.images.new(filename,width=width,height=height,alpha=True)
    result.pixels.foreach_set(pixels); result.file_format='PNG'; result.filepath_raw=str(OUT/filename)
    result.save()
    for img in images: bpy.data.images.remove(img)
    bpy.data.images.remove(result)

sheet(['climber-start.png','climber-mid.png','climber-reach.png','climber-top.png'],
      'climber-contact-sheet.png')
scene=bpy.context.scene; rig=bpy.data.objects['ClimberRig']; camera=scene.camera
view=Vector((5.9,-10,5.13)).normalized()
scene.render.resolution_x=500;scene.render.resolution_y=600;scene.render.resolution_percentage=100
scene.cycles.samples=24;scene.render.image_settings.file_format='PNG'
for label,anchor,frames in (('elbow',91,(88,90,92,94)),('high-elbow',299,(296,298,300,302))):
    scene.frame_set(anchor)
    target=rig.matrix_world@rig.pose.bones['Torso'].head+Vector((0,-.04,.30))
    camera.location=target+view*12
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=1.65
    names=[]
    for frame in frames:
        scene.frame_set(frame); name=f'climber-{label}-{frame:03d}.png';names.append(name)
        scene.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)
    sheet(names,f'climber-{label}-strip.png',4)
print('Review sheets saved to',OUT)
