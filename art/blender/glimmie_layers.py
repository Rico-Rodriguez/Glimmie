import bpy, math, sys
from mathutils import Vector, Matrix

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


# ---------------- accessories (each its own layer, same camera; LAYER = 'acc_<name>') ----------------
import bmesh
ACC = {}
def acc(name, o):
    ACC.setdefault(name, []).append(o); return o
GOLD = mat('gold', srgb('#FFD36B'), 0.28); GOLD.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value = 0.9
PINK = mat('accpink', srgb('#FF7FB8'), 0.4, coat=0.5)
GEM = mat('gem', srgb('#59B8FF'), 0.05, coat=1.0)
PET = mat('petal', srgb('#FFB3D6'), 0.5); MID = mat('mid', srgb('#FFE07A'), 0.5)
STRIPE_A = mat('sa', srgb('#8FD3FF'), 0.45, coat=0.4); STRIPE_B = mat('sb', srgb('#FFFFFF'), 0.45, coat=0.4)
GLASS = mat('glass', srgb('#FF5FA2'), 0.2, coat=0.8); LENS = mat('lens', srgb('#FFD1E6'), 0.1, emit=0.2)
LENS.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = 0.45
# bow on the right ear
for sx in (-1, 1):
    o = sphere('accbow', (0.62 + sx * 0.15, -0.28, 1.6 + 0.02), (0.16, 0.07, 0.11), PINK); o.rotation_euler = (0, math.radians(-sx * 25), 0); acc('bow', o)
acc('bow', sphere('accknot', (0.62, -0.33, 1.6), (0.06, 0.05, 0.06), PINK))
# little crown, tilted on the left of the head
bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.22, depth=0.12, location=(-0.32, -0.05, 1.86), rotation=(0, math.radians(-18), 0))
cr = bpy.context.object; cr.data.materials.append(GOLD); acc('crown', cr)
for i in range(5):
    a = math.radians(-90 + (i - 2) * 36); x0, y0 = 0.22 * math.cos(a), -0.05 + 0.22 * math.sin(a)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.06, radius2=0.0, depth=0.16, location=(-0.32 + x0, y0, 1.98))
    c = bpy.context.object; c.data.materials.append(GOLD); bpy.ops.object.shade_smooth(); acc('crown', c)
acc('crown', sphere('accgem', (-0.32, -0.28, 1.87), (0.045, 0.025, 0.045), GEM, 24))
for o in ACC['crown']:
    o.location = Vector((-0.32, -0.05, 1.86)) + (Matrix.Rotation(math.radians(18), 3, 'Y') @ (o.location - Vector((-0.32, -0.05, 1.86))))
    if o.name.startswith('Cone'): o.rotation_euler = (0, math.radians(18), 0)
# flower on the left ear
for p in range(5):
    pa = 2 * math.pi * p / 5
    acc('flower', sphere('accpet', (-0.6 + 0.1 * math.cos(pa), -0.3, 1.74 + 0.1 * math.sin(pa)), (0.08, 0.04, 0.08), PET, 24))
acc('flower', sphere('accmid', (-0.6, -0.34, 1.74), (0.05, 0.03, 0.05), MID, 24))
# striped party hat, tilted left
for k in range(4):
    z0 = k * 0.1
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.24 - k * 0.06, radius2=0.24 - (k + 1) * 0.06 + 0.001, depth=0.1, location=(0, 0, z0 + 0.05))
    c = bpy.context.object; c.data.materials.append(STRIPE_A if k % 2 == 0 else STRIPE_B); bpy.ops.object.shade_smooth(); acc('partyhat', c)
acc('partyhat', sphere('pom', (0, 0, 0.42), (0.06, 0.06, 0.06), PINK, 24))
for o in ACC['partyhat']:
    M = Matrix.Translation((-0.3, -0.02, 1.78)) @ Matrix.Rotation(math.radians(-20), 4, 'Y')
    o.matrix_world = M @ o.matrix_world
# heart glasses over the eyes
def heart(sz, loc, m, name):
    me = bpy.data.meshes.new(name); bmx = bmesh.new(); vs = []
    for i in range(36):
        t = 2 * math.pi * i / 36
        x = 16 * math.sin(t) ** 3; z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        vs.append(bmx.verts.new((x * sz / 16, 0, z * sz / 16)))
    bmx.faces.new(vs); bmx.to_mesh(me); bmx.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); o.location = loc
    so = o.modifiers.new('so', 'SOLIDIFY'); so.thickness = 0.03; so.offset = 0
    o.data.materials.append(m); return o
for x in (-0.34, 0.34):
    y = front(x, 1.12) - 0.09
    acc('glasses', heart(0.2, (x, y, 1.13), LENS, 'lens'))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.19, minor_radius=0.025, location=(x, y - 0.01, 1.12), rotation=(math.radians(90), 0, 0))
    r = bpy.context.object; r.scale = (1, 1, 0.95); r.data.materials.append(GLASS); bpy.ops.object.shade_smooth(); acc('glasses', r)
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.02, depth=0.3, location=(0, front(0, 1.14) - 0.1, 1.16), rotation=(0, math.radians(90), 0))
br = bpy.context.object; br.data.materials.append(GLASS); acc('glasses', br)
# grow each accessory about its anchor so it reads at sticker size
for name, (anchor, k, lift) in {'bow': ((0.55, -0.3, 1.62), 1.9, (-0.05, -0.05, 0.08)), 'crown': ((-0.32, -0.05, 1.86), 1.7, (0.0, 0.0, 0.06)),
                                'flower': ((-0.6, -0.3, 1.74), 1.8, (0, -0.04, 0)), 'partyhat': ((-0.3, -0.02, 1.78), 1.7, (-0.05, 0, 0.0))}.items():
    M = Matrix.Translation(Vector(anchor) + Vector(lift)) @ Matrix.Scale(k, 4) @ Matrix.Translation(-Vector(anchor))
    for o in ACC[name]: o.matrix_world = M @ o.matrix_world
ACC_OBJS = {o.name for v in ACC.values() for o in v}

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
    if LAYER.startswith('acc_'):   # accessory alone; the Glimmie itself is a holdout so it tucks behind ears etc.
        mine = o.name in {x.name for x in ACC[LAYER[4:]]}
        o.hide_render = (o.name in ACC_OBJS and not mine) or matname(o) == 'wing'
        o.is_holdout = not mine
        continue
    if o.name in ACC_OBJS: o.hide_render = True; continue
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
