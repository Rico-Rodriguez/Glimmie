import bpy, math, sys
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def mat(name, col, rough=0.45, sss=0.0, emit=0.0, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Roughness'].default_value = rough
    if sss:
        b.inputs['Subsurface Weight'].default_value = sss
        b.inputs['Subsurface Radius'].default_value = (0.4, 0.25, 0.3)
        b.inputs['Subsurface Scale'].default_value = 0.15
    if coat:
        b.inputs['Coat Weight'].default_value = coat
        b.inputs['Coat Roughness'].default_value = 0.05
    if emit:
        b.inputs['Emission Color'].default_value = (*col, 1)
        b.inputs['Emission Strength'].default_value = emit
    return m

def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def sphere(name, loc, scale, m, seg=64):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.shade_smooth(); o.data.materials.append(m); return o

body_col = srgb('#FBF8FB')
LAYER = sys.argv[-1]
BODY = mat('body', body_col, 0.5, sss=0.25)
BELLY = mat('belly', srgb('#FFF8F2'), 0.55, sss=0.2)
EYE = mat('eye', srgb('#2B2350'), 0.08, coat=1.0)
WHITE = mat('white', (1, 1, 1), 0.3, emit=0.6)
BLUSH = mat('blush', srgb('#FF8FB1'), 0.6)
STAR = mat('star', srgb('#FFD25F'), 0.25, coat=0.6)
WING = mat('wing', srgb('#FFFFFF'), 0.35, sss=0.3)
MOUTH = mat('mouth', srgb('#B8405E'), 0.4)

# body (ellipsoid) and helper to sit things on its surface
A,B,C,CZ=1.0,0.9,0.9,1.0
b = sphere('body', (0, 0, CZ), (A, B, C), BODY)
def front(x,z,off=0.0):
    t=1-(x/A)**2-((z-CZ)/C)**2
    return -B*math.sqrt(max(t,0.0))-off
sphere('belly', (0, front(0,0.72)+0.2, 0.72), (0.56, 0.24, 0.42), BELLY)
for x in (-0.6, 0.6):
    sphere('ear', (x, 0.05, 1.72), (0.28, 0.24, 0.28), BODY)
    sphere('earin', (x, -0.15, 1.74), (0.15, 0.07, 0.15), BLUSH)
for x in (-0.42, 0.42):
    sphere('foot', (x, -0.3, 0.13), (0.3, 0.3, 0.15), BODY)
for x in (-0.34, 0.34):
    z=1.12; y=front(x,z)
    sphere('eye', (x, y+0.03, z), (0.15, 0.07, 0.19), EYE)
    sphere('hl', (x+0.05, y-0.035, z+0.08), (0.055, 0.03, 0.055), WHITE)
    sphere('hl2', (x-0.05, y-0.03, z-0.08), (0.026, 0.02, 0.026), WHITE)
    bx=x*1.6; bz=0.92
    sphere('blush', (bx, front(bx,bz)+0.03, bz), (0.14, 0.04, 0.08), BLUSH)
mz=0.9
sphere('mouth', (0, front(0,mz)+0.02, mz), (0.085, 0.03, 0.06), MOUTH)
sphere('tongue', (0, front(0,mz-0.025)-0.005, mz-0.025), (0.045, 0.02, 0.025), BLUSH)
# antenna
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 1.84))
a = bpy.context.object; a.data.dimensions='3D'; a.data.bevel_depth = 0.035; a.data.materials.append(BODY)
p = a.data.splines[0].bezier_points
p[0].co = (0, 0, 0); p[0].handle_left=(0,0,-0.1); p[0].handle_right = (-0.12, 0, 0.18)
p[1].co = (0.1, 0, 0.45); p[1].handle_left = (-0.05, 0, 0.32); p[1].handle_right = (0.2, 0, 0.55)
# star mesh
import bmesh
me=bpy.data.meshes.new('star'); bm=bmesh.new(); vs=[]
for i in range(10):
    r=0.27 if i%2==0 else 0.12; ang=math.pi/2+i*math.pi/5
    vs.append(bm.verts.new((r*math.cos(ang),0,r*math.sin(ang))))
bm.faces.new(vs); bm.to_mesh(me); bm.free()
st=bpy.data.objects.new('star',me); bpy.context.collection.objects.link(st); st.location=(0.12,0,2.38)
sol=st.modifiers.new('so','SOLIDIFY'); sol.thickness=0.1; sol.offset=0
bev=st.modifiers.new('bv','BEVEL'); bev.width=0.03; bev.segments=4
st.data.materials.append(STAR)
for x, r in ((-1.0, 28), (1.0, -28)):
    w = sphere('wing', (x, 0.35, 1.25), (0.4, 0.07, 0.26), WING)
    w.rotation_euler = (0, math.radians(r), math.radians(-18 if x < 0 else 18))
sphere('tail', (0.8, 0.5, 0.55), (0.17, 0.17, 0.17), BODY)

FACE_MATS = {'belly','eye','white','blush','star','wing','mouth'}
# ground + backdrop
# lights
def light(kind, loc, energy, size, col=(1, 1, 1)):
    bpy.ops.object.light_add(type=kind, location=loc)
    l = bpy.context.object; l.data.energy = energy; l.data.color = col
    if kind == 'AREA': l.data.size = size
    l.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
light('AREA', (-3, -4, 5), 900, 4)
light('AREA', (4, -2, 3), 300, 3, (1, 0.85, 0.95))
light('AREA', (0, 3, 4), 400, 3, (0.85, 0.9, 1))
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('#FFF0F6'), 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

# camera
bpy.ops.object.camera_add(location=(0, -7.5, 1.6))
cam = bpy.context.object; sc.camera = cam
cam.location=(0,-7.5,2.2); cam.rotation_euler = (math.radians(82), 0, 0); cam.data.lens = 72

sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 32
sc.cycles.use_denoising = True
sc.render.resolution_x = 600; sc.render.resolution_y = 600; sc.render.film_transparent = True
sc.render.image_settings.color_mode='RGBA'
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'; sc.view_settings.exposure = -0.8
def matname(o):
    return o.data.materials[0].name if (o.type in ('MESH','CURVE') and o.data.materials) else ''
for o in bpy.data.objects:
    if o.type not in ('MESH','CURVE'): continue
    isface = matname(o) in FACE_MATS
    if LAYER == 'body':
        o.hide_render = False; o.is_holdout = isface and matname(o) in ('belly','eye','white','blush','mouth','star')
        if matname(o) == 'wing': o.hide_render = True
    else:
        o.hide_render = False; o.is_holdout = not isface
        if matname(o) == 'wing': o.is_holdout = False
sc.render.filepath = f'art/renders/glim_{LAYER}.png'
bpy.ops.render.render(write_still=True)
print('DONE')
