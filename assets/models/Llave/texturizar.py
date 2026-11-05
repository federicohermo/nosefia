"""Texturiza la UV existente; ejecutar desde la raíz con Blender en background."""
import bpy
import numpy as np
from pathlib import Path
from mathutils import Vector, noise

ROOT = Path.cwd()
DEST = ROOT / 'assets/models/Llave'
OUT = ROOT / 'build/llave'
obj = bpy.data.objects['Llave']
mesh = obj.data
N = 256
mesh.calc_loop_triangles()
base = np.zeros((N, N, 4), dtype=np.float32)
orm = np.zeros_like(base)
mask = np.zeros((N, N), dtype=bool)
uv = mesh.uv_layers['UVMap']
for tri in mesh.loop_triangles:
    coords = np.array([uv.data[i].uv[:] for i in tri.loops]) * N
    pts = np.array([mesh.vertices[i].co[:] for i in tri.vertices])
    lo = np.maximum(np.floor(coords.min(axis=0)).astype(int), 0)
    hi = np.minimum(np.ceil(coords.max(axis=0)).astype(int), N-1)
    a,b,c = coords
    denom = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(denom)<1e-10: continue
    # Las caras inclinadas son los biseles modelados, no las costuras UV.
    nz = abs(tri.normal.z)
    bevel = 1.0 if 0.15 < nz < 0.95 and mesh.polygons[tri.polygon_index].area < 0.000008 else 0.0
    for y in range(lo[1],hi[1]+1):
        for x in range(lo[0],hi[0]+1):
            p = (x+.5,y+.5)
            w0=((b[1]-c[1])*(p[0]-c[0])+(c[0]-b[0])*(p[1]-c[1]))/denom
            w1=((c[1]-a[1])*(p[0]-c[0])+(a[0]-c[0])*(p[1]-c[1]))/denom
            w2=1-w0-w1
            if min(w0,w1,w2)<-1e-5: continue
            v=Vector(w0*pts[0]+w1*pts[1]+w2*pts[2])
            cloud=noise.noise_vector(v*650)[0]
            fine=noise.noise_vector(v*17000)[1]
            rust=max(0,min(1,(cloud+fine*.35-.24)*2.0))*(1-bevel*.90)
            wear=bevel*(.65+.25*fine)
            iron=np.array([.36,.37,.38])*(1+fine*.12)
            oxide=np.array([.29,.16,.075])*(1+fine*.4)
            color=iron*(1-rust)+oxide*rust
            color=color*(1-wear)+np.array([.55,.56,.55])*wear
            base[y,x]=[*color,1]
            orm[y,x]=[1, np.clip(.53+rust*.32-wear*.29+fine*.09,.22,.92), .93*(1-rust)+.08*rust,1]
            mask[y,x]=True
# Margen de ocho texeles para filtrado y mipmaps, sin cambiar UV.
for _ in range(8):
    old=mask.copy()
    for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
        src=np.roll(old,(dy,dx),(0,1))
        take=src & ~mask
        for data in (base,orm): data[take]=np.roll(data,(dy,dx),(0,1))[take]
        mask[take]=True
base[~mask]=[.12,.13,.14,1]
orm[~mask]=[1,.6,.9,1]

def save(name,data,srgb):
    if name in bpy.data.images: bpy.data.images.remove(bpy.data.images[name])
    img=bpy.data.images.new(name,width=N,height=N,alpha=False)
    img.colorspace_settings.name='sRGB' if srgb else 'Non-Color'
    img.pixels.foreach_set(data.ravel())
    img.filepath_raw=str(DEST/(name+'.png'))
    img.file_format='PNG'
    img.save()
    img.filepath='//'+name+'.png'
    return img

mat=bpy.data.materials['metal_llave']
mat.use_nodes=True
nodes=mat.node_tree.nodes
nodes.clear()
links=mat.node_tree.links
shader=nodes.new('ShaderNodeBsdfPrincipled')
output=nodes.new('ShaderNodeOutputMaterial')
links.new(shader.outputs['BSDF'],output.inputs['Surface'])
tex=nodes.new('ShaderNodeTexImage'); tex.image=save('llave_base_color',base,True)
tex.location=(-500,200)
links.new(tex.outputs['Color'],shader.inputs['Base Color'])
packed=nodes.new('ShaderNodeTexImage'); packed.image=save('llave_orm',orm,False)
packed.location=(-500,-100)
split=nodes.new('ShaderNodeSeparateColor'); split.location=(-250,-100)
links.new(packed.outputs['Color'],split.inputs['Color'])
links.new(split.outputs['Green'],shader.inputs['Roughness'])
links.new(split.outputs['Blue'],shader.inputs['Metallic'])
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'llave.blend'))
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=str(DEST/'llave.glb'),export_format='GLB',use_selection=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')


