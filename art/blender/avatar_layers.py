"""Render every dress-up layer of the avatar from one fixed camera.
usage: python avatar_layers.py -- outdir layer1 layer2 ...   (or 'ALL' / 'preview')
Tinted layers are rendered near-white and ramp-tinted by the app (docs/MODEL_UPGRADE.md step 1):
  <layer>.png    base pass: diffuse shading only, lit with headroom so the colours keep their shape
  G_<layer>.png  gloss pass (tinted layers only): highlights only, screened on top by the app
Layers the app draws as rendered (eyes, face, glints, gold...) get one pass with the original light.
env: SAMPLES (default 48, adaptive), SCALE (render size, default 2 = 1600x2000), GLOSS=0 skips gloss passes"""
import bpy, math, sys, bmesh, os
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUTDIR = ARGS[0] if ARGS else '/home/claude/blend/out'
WANT = ARGS[1:] if len(ARGS) > 1 else ['preview']
SAMPLES = int(os.environ.get('SAMPLES', '48'))
SCALE = int(os.environ.get('SCALE', '2'))
DO_GLOSS = os.environ.get('GLOSS', '1') != '0'
os.makedirs(OUTDIR, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def mat(name, hexcol, rough=0.5, sss=0.0, coat=0.0, emit=0.0, spec=0.4, metal=0.0, trans=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']; col = srgb(hexcol)
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Metallic'].default_value = metal
    if sss:
        b.inputs['Subsurface Weight'].default_value = sss
        b.inputs['Subsurface Radius'].default_value = (0.7, 0.35, 0.3)
        b.inputs['Subsurface Scale'].default_value = 0.12
    if coat:
        b.inputs['Coat Weight'].default_value = coat; b.inputs['Coat Roughness'].default_value = 0.12
    if emit:
        b.inputs['Emission Color'].default_value = (*col, 1); b.inputs['Emission Strength'].default_value = emit
    if trans:
        b.inputs['Transmission Weight'].default_value = trans
    return m

COLL = {}
CUR = ['skin']
def put(o, group=None):
    group = group or CUR[0]
    if group not in COLL:
        c = bpy.data.collections.new(group); sc.collection.children.link(c); COLL[group] = c
    for c in o.users_collection: c.objects.unlink(o)
    COLL[group].objects.link(o); return o

def obj_sphere(loc, scale, rot=(0, 0, 0), seg=40, m=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = scale; bpy.ops.object.shade_smooth()
    if m: o.data.materials.append(m)
    return put(o)

def obj_curve(pts, r, radii=None, m=None):
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    c = bpy.context.object; c.data.dimensions = '3D'; c.data.bevel_depth = r; c.data.bevel_resolution = 6
    c.data.use_fill_caps = True
    sp = c.data.splines[0]; sp.bezier_points.add(len(pts) - 2)
    for i, (bp, p) in enumerate(zip(sp.bezier_points, pts)):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'
        bp.radius = radii[i] if radii else 1.0
    if m: c.data.materials.append(m)
    return put(c)

def fuse(objs, m, voxel, smooth_iters=10, name='fused'):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    o = bpy.context.object; o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    r = o.modifiers.new('rm', 'REMESH'); r.mode = 'VOXEL'; r.voxel_size = voxel
    s = o.modifiers.new('sm', 'SMOOTH'); s.factor = 0.9; s.iterations = smooth_iters
    o.data.materials.clear(); o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return put(o)

def lathe(prof, m, thick=0.03, sy=0.86):
    me = bpy.data.meshes.new('lathe'); bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in prof]
    for i in range(len(vs) - 1): bm.edges.new((vs[i], vs[i + 1]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('lathe', me); sc.collection.objects.link(o)
    s = o.modifiers.new('sc', 'SCREW'); s.steps = 80; s.render_steps = 80
    so = o.modifiers.new('so', 'SOLIDIFY'); so.thickness = thick
    ss = o.modifiers.new('ss', 'SUBSURF'); ss.levels = 2; ss.render_levels = 2
    o.scale = (1, sy, 1); o.data.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    return put(o)

def torus(R, r, loc, m, sy=0.86, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=64, minor_segments=16)
    t = bpy.context.object; t.scale = (1, sy, 1); t.data.materials.append(m); bpy.ops.object.shade_smooth(); return put(t)

def star_mesh(R, r, loc, rot, m, thick=0.07, name='star'):
    me = bpy.data.meshes.new(name); bmx = bmesh.new(); vs = []
    for i in range(10):
        rr = R if i % 2 == 0 else r; an = math.pi / 2 + i * math.pi / 5
        vs.append(bmx.verts.new((rr * math.cos(an), 0, rr * math.sin(an))))
    bmx.faces.new(vs); bmx.to_mesh(me); bmx.free()
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    o.location = loc; o.rotation_euler = rot
    so = o.modifiers.new('so', 'SOLIDIFY'); so.thickness = thick; so.offset = 0
    bv = o.modifiers.new('bv', 'BEVEL'); bv.width = 0.025; bv.segments = 4
    o.data.materials.append(m); return put(o)

# ---------------- materials (near-white = tintable) ----------------
W_SKIN = mat('wskin', '#FFF3EE', 0.45, sss=0.35, coat=0.15)
W_HAIR = mat('whair', '#F7F3F5', 0.34, coat=0.5, spec=0.5, sss=0.1)
W_CLOTH = mat('wcloth', '#FBFAFB', 0.42, coat=0.25, sss=0.05)
W_SHOE = mat('wshoe', '#EDEBED', 0.3, coat=0.6)   # a touch darker: toe tops facing the key light clipped
W_WING = mat('wwing', '#FFFFFF', 0.15, trans=0.55, emit=0.15, coat=0.6)
UNDER = mat('under', '#FFFFFF', 0.6, sss=0.05)
# eyes in greys (tinted later); highlights separate & untinted
G_RIM = mat('grim', '#2A2A2E', 0.2, coat=0.8)
G_IRIS = mat('giris', '#C9C9C9', 0.15, coat=1.0)
G_MID = mat('gmid', '#8E8E8E', 0.2, coat=0.8)
G_DK = mat('gdk', '#575757', 0.2, coat=0.8)
G_PUP = mat('gpup', '#2E2E2E', 0.2, coat=0.8)
G_LIGHT = mat('glight', '#E4E4E4', 0.2, emit=0.1)
WHITE = mat('white', '#FFFFFF', 0.2, emit=0.7)
DARK = mat('dark', '#2E1238', 0.25, coat=0.6)
BLUSH = mat('blush', '#FF8FB4', 0.6, emit=0.2)
BLUSH.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = 0.2
SHINE = mat('shine', '#FFFFFF', 0.3, emit=1.0)
SHINE.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = 0.5
MOUTHM = mat('mouth', '#D9487A', 0.4)
TONGUE = mat('tongue', '#FFA3BC', 0.4)
GOLD = mat('gold', '#FFD36B', 0.28, metal=0.9)
GEMP = mat('gemp', '#FF4F9A', 0.05, coat=1.0)
GEMB = mat('gemb', '#59B8FF', 0.05, coat=1.0)
GEMG = mat('gemg', '#4FD6A8', 0.05, coat=1.0)
F_PINK = mat('fpink', '#FF8DC0', 0.5)
F_LAV = mat('flav', '#B9A4FF', 0.5)
F_YEL = mat('fyel', '#FFE07A', 0.5)
F_MINT = mat('fmint', '#7FE0C4', 0.5)
LEAF = mat('leaf', '#6CD39A', 0.5)
WAND = mat('wand', '#B99CFF', 0.35, coat=0.5)
PAPER = mat('paper', '#FFE9C7', 0.6)
INNER = mat('inner', '#FFC4DA', 0.6)

HZ = 2.28; HX, HY, HZR = 0.96, 0.86, 0.84
def face(x, z, off=0.0):
    t = 1 - (x / HX) ** 2 - ((z - HZ) / HZR) ** 2
    return -HY * math.sqrt(max(t, 0)) - off

# ---------------- skin ----------------
CUR[0] = 'skin'
parts = [obj_sphere((0, -0.02, 1.38), (0.3, 0.24, 0.3)), obj_sphere((0, 0, 1.1), (0.34, 0.27, 0.3)),
         obj_curve([(0, 0, 1.4), (0, 0, 1.62)], 0.11)]
for sx in (-1, 1):
    parts.append(obj_curve([(sx * 0.27, 0, 1.42), (sx * 0.43, -0.06, 1.2), (sx * 0.5, -0.12, 1.02)], 0.085, [1, 0.95, 1.05]))
    parts.append(obj_sphere((sx * 0.51, -0.13, 0.97), (0.11, 0.1, 0.11)))
    parts.append(obj_curve([(sx * 0.15, 0, 0.95), (sx * 0.16, -0.01, 0.55), (sx * 0.16, -0.02, 0.2)], 0.1, [1.1, 0.9, 0.85]))
    parts.append(obj_sphere((sx * 0.165, -0.06, 0.13), (0.12, 0.17, 0.09)))
body = fuse(parts, W_SKIN, 0.018, 8, 'body')
head = fuse([obj_sphere((0, 0, HZ), (HX, HY, HZR), seg=96),
             obj_sphere((-0.42, -0.36, HZ - 0.4), (0.4, 0.36, 0.34), seg=48),
             obj_sphere((0.42, -0.36, HZ - 0.4), (0.4, 0.36, 0.34), seg=48),
             obj_sphere((0, -0.3, HZ - 0.5), (0.5, 0.4, 0.3), seg=48)], W_SKIN, 0.012, 12, 'head')

# ---------------- underwear ----------------
CUR[0] = 'under'
obj_sphere((0, -0.01, 1.2), (0.355, 0.28, 0.27), m=UNDER)
obj_sphere((0, 0, 0.9), (0.33, 0.27, 0.16), m=UNDER)

# ---------------- face helpers ----------------
EZ = HZ - 0.3
def _cz(px, pz, cut, cx, rx):
    if cut is None: return pz
    return max(pz, cut + 0.07 * ((px - cx) / rx) ** 2)
def decal(cx, cz, rx, rz, m, off, rings=8, segs=48, cut=None):
    me = bpy.data.meshes.new('decal'); bm = bmesh.new()
    ctr = bm.verts.new((cx, -2.0, _cz(cx, cz, cut, cx, rx))); ringv = []
    for r in range(1, rings + 1):
        f = r / rings
        ringv.append([bm.verts.new((cx + rx * f * math.cos(2 * math.pi * k / segs), -2.0,
                                    _cz(cx + rx * f * math.cos(2 * math.pi * k / segs), cz + rz * f * math.sin(2 * math.pi * k / segs), cut, cx, rx))) for k in range(segs)])
    for k in range(segs): bm.faces.new((ctr, ringv[0][k], ringv[0][(k + 1) % segs]))
    for r in range(rings - 1):
        for k in range(segs):
            bm.faces.new((ringv[r][k], ringv[r + 1][k], ringv[r + 1][(k + 1) % segs], ringv[r][(k + 1) % segs]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('decal', me); sc.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = True
    sw = o.modifiers.new('sw', 'SHRINKWRAP'); sw.target = head; sw.wrap_method = 'PROJECT'
    sw.use_project_y = True; sw.use_negative_direction = True; sw.use_positive_direction = True; sw.offset = off
    o.data.materials.append(m); return put(o)
def decal_poly(outline, m, off, rings=6):
    """Like decal() but for any closed outline [(x, z), ...] around its centroid."""
    cx = sum(p[0] for p in outline) / len(outline); cz = sum(p[1] for p in outline) / len(outline)
    me = bpy.data.meshes.new('decalp'); bm = bmesh.new(); n = len(outline)
    ctr = bm.verts.new((cx, -2.0, cz))
    ringv = [[bm.verts.new((cx + (px - cx) * r / rings, -2.0, cz + (pz - cz) * r / rings)) for px, pz in outline] for r in range(1, rings + 1)]
    for k in range(n): bm.faces.new((ctr, ringv[0][k], ringv[0][(k + 1) % n]))
    for r in range(rings - 1):
        for k in range(n): bm.faces.new((ringv[r][k], ringv[r + 1][k], ringv[r + 1][(k + 1) % n], ringv[r][(k + 1) % n]))
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('decalp', me); sc.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = True
    sw = o.modifiers.new('sw', 'SHRINKWRAP'); sw.target = head; sw.wrap_method = 'PROJECT'
    sw.use_project_y = True; sw.use_negative_direction = True; sw.use_positive_direction = True; sw.offset = off
    o.data.materials.append(m); return put(o)
def halfdisc(cx, cz, w, h, m, yoff, n=16, up=False):
    me = bpy.data.meshes.new('hd'); bm = bmesh.new(); vs = []
    for i in range(n + 1):
        t = math.pi * i / n
        px = cx - w * math.cos(t); pz = cz - h * math.sin(t) * (-1 if up else 1)
        vs.append(bm.verts.new((px, face(px, pz) + yoff, pz)))
    bm.faces.new(vs); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('hd', me); sc.collection.objects.link(o)
    sm = o.modifiers.new('so', 'SOLIDIFY'); sm.thickness = 0.012
    o.data.materials.append(m); return put(o)

def lid(x, sx, m):
    pts = []
    for ang in (160, 120, 90, 60, 25):
        r = math.radians(ang)
        lx = x + sx * 0.205 * math.cos(r); lz = EZ + 0.225 * math.sin(r) - 0.004
        pts.append((lx, face(lx, lz) - 0.03, lz))
    obj_curve(pts, 0.014, [0.3, 0.85, 1.0, 1.0, 0.6], m=m)
    lx0 = x + sx * 0.19; lz0 = EZ + 0.11
    obj_curve([(lx0, face(lx0, lz0) - 0.03, lz0), (lx0 + sx * 0.06, face(lx0 + sx * 0.06, lz0 + 0.04) - 0.02, lz0 + 0.04)], 0.012, [1.0, 0.2], m=m)

# eyes (tinted) and highlights (untinted)
for sx in (-1, 1):
    x = sx * 0.36
    CUR[0] = 'eyes'
    decal(x, EZ, 0.205, 0.228, G_RIM, 0.004)
    decal(x, EZ - 0.014, 0.186, 0.206, G_IRIS, 0.008)
    decal(x, EZ - 0.014, 0.186, 0.206, G_MID, 0.010, cut=EZ - 0.04)
    decal(x, EZ - 0.014, 0.186, 0.206, G_DK, 0.012, cut=EZ + 0.05)
    decal(x, EZ - 0.01, 0.085, 0.1, G_PUP, 0.014)
    decal(x, EZ - 0.14, 0.1, 0.04, G_LIGHT, 0.016)
    lid(x, sx, G_RIM)
    CUR[0] = 'eyeshine'
    decal(x - sx * 0.065 - 0.005, EZ + 0.06, 0.065, 0.072, WHITE, 0.02)
    decal(x + sx * 0.07, EZ - 0.08, 0.03, 0.03, WHITE, 0.02)
    # happy closed eyes  ^ ^
    CUR[0] = 'happy'
    pts = []
    for ang in (175, 135, 90, 45, 5):
        r = math.radians(ang)
        lx = x + sx * 0.15 * math.cos(r); lz = EZ - 0.03 + 0.1 * math.sin(r)
        pts.append((lx, face(lx, lz) - 0.03, lz))
    obj_curve(pts, 0.026, [0.5, 1.0, 1.1, 1.0, 0.5], m=DARK)
    CUR[0] = 'face'
    for k, f in enumerate((1.0, 0.82, 0.64, 0.46, 0.3)):   # stacked see-through discs = soft blush
        decal(sx * 0.52, EZ - 0.24, 0.15 * f, 0.09 * f, BLUSH, 0.004 + 0.002 * k)
CUR[0] = 'face'
mz = EZ - 0.33
def smile(w, h, n=14):
    top = [(-w + 2 * w * i / n, mz + 0.012 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    bot = [(w * math.cos(math.pi * i / n), mz - h * math.sin(math.pi * i / n)) for i in range(1, n)]
    return top + bot
decal_poly(smile(0.07, 0.065), MOUTHM, 0.006)
decal(0, mz - 0.042, 0.035, 0.018, TONGUE, 0.009)

# ---------------- hair styles (all share one cap) ----------------
def cap(): return obj_sphere((0, 0.2, HZ + 0.2), (0.98, 0.9, 0.9), seg=64)
def bangs_mass(name):
    BG = []
    for (rx, rz, tx, tz, r) in ((-0.66, HZ + 0.6, -0.8, HZ + 0.02, 0.2), (-0.34, HZ + 0.7, -0.46, HZ + 0.12, 0.22), (0.0, HZ + 0.72, -0.1, HZ + 0.15, 0.23),
                                (0.32, HZ + 0.7, 0.26, HZ + 0.13, 0.22), (0.62, HZ + 0.6, 0.66, HZ + 0.03, 0.2)):
        mx = (rx + tx) / 2 + 0.03; mz2 = (rz + tz) / 2
        BG.append(obj_curve([(rx, face(rx, min(rz, HZ + 0.6)) + 0.06, rz), (mx, face(mx, mz2) - 0.1, mz2), (tx, face(tx, tz) - 0.04, tz)], r, [1.0, 0.85, 0.15]))
    return fuse(BG, W_HAIR, 0.014, 4, name)
def side_locks(H, long=False):
    for sx in (-1, 1):
        if long:
            H.append(obj_curve([(sx * 0.72, -0.2, HZ + 0.3), (sx * 0.9, -0.28, HZ - 0.3), (sx * 0.88, -0.3, HZ - 0.95), (sx * 0.78, -0.3, HZ - 1.25)], 0.2, [1.2, 1.05, 0.9, 0.5]))
        else:
            H.append(obj_curve([(sx * 0.72, -0.2, HZ + 0.3), (sx * 0.86, -0.3, HZ - 0.2), (sx * 0.8, -0.38, HZ - 0.62), (sx * 0.64, -0.42, HZ - 0.72)], 0.17, [1.2, 1.0, 0.75, 0.4]))

CUR[0] = 'hair_curls'
H = [cap(), obj_sphere((0, 0.45, HZ - 0.25), (0.92, 0.5, 0.75))]
side_locks(H)
for sx in (-1, 1):
    H.append(obj_sphere((sx * 0.9, 0.15, HZ + 0.42), (0.32, 0.3, 0.32)))
    H.append(obj_curve([(sx * 0.95, 0.15, HZ + 0.4), (sx * 1.38, 0.18, HZ + 0.05), (sx * 1.45, 0.12, HZ - 0.55),
                        (sx * 1.2, 0.05, HZ - 0.95), (sx * 0.95, 0.0, HZ - 0.8), (sx * 1.0, 0.0, HZ - 0.55)], 0.3, [1.0, 1.05, 0.95, 0.75, 0.5, 0.25]))
H.append(obj_curve([(0.05, 0.1, HZ + 0.95), (0.25, 0.05, HZ + 1.15), (0.1, 0.0, HZ + 1.32), (-0.08, 0.02, HZ + 1.2)], 0.12, [1.3, 1.0, 0.6, 0.3]))
fuse(H, W_HAIR, 0.02, 14, 'curls'); bangs_mass('curls_bangs')

CUR[0] = 'hair_long'
H = [cap(), obj_sphere((0, 0.42, HZ - 0.35), (0.98, 0.48, 0.9)), obj_sphere((0, 0.4, HZ - 0.95), (0.9, 0.4, 0.55))]
side_locks(H, long=True)
for sx in (-1, 1):
    H.append(obj_curve([(sx * 0.6, 0.35, HZ - 0.6), (sx * 0.8, 0.3, HZ - 1.15), (sx * 0.62, 0.25, HZ - 1.45)], 0.25, [1.0, 0.8, 0.3]))
H.append(obj_curve([(0.05, 0.1, HZ + 0.95), (0.25, 0.05, HZ + 1.15), (0.1, 0.0, HZ + 1.32), (-0.08, 0.02, HZ + 1.2)], 0.12, [1.3, 1.0, 0.6, 0.3]))
fuse(H, W_HAIR, 0.02, 14, 'long'); bangs_mass('long_bangs')

CUR[0] = 'hair_buns'
H = [cap(), obj_sphere((0, 0.42, HZ - 0.15), (0.9, 0.48, 0.62))]
side_locks(H)
for sx in (-1, 1):
    H.append(obj_sphere((sx * 0.66, 0.12, HZ + 0.78), (0.36, 0.34, 0.36), seg=48))
    H.append(obj_curve([(sx * 0.75, 0.1, HZ + 0.6), (sx * 1.05, 0.1, HZ + 0.2), (sx * 1.1, 0.05, HZ - 0.25)], 0.12, [1.0, 0.8, 0.3]))
fuse(H, W_HAIR, 0.02, 14, 'buns'); bangs_mass('buns_bangs')

CUR[0] = 'hair_pony'
H = [cap(), obj_sphere((0, 0.42, HZ - 0.12), (0.9, 0.48, 0.6))]
side_locks(H)
H.append(torus(0.17, 0.08, (0.35, 0.78, HZ + 0.62), W_HAIR, sy=1.0, rot=(math.radians(70), math.radians(40), 0)))
H.append(obj_curve([(0.3, 0.8, HZ + 0.66), (0.95, 0.75, HZ + 0.95), (1.45, 0.45, HZ + 0.6), (1.62, 0.25, HZ - 0.05),
                    (1.5, 0.15, HZ - 0.55), (1.3, 0.1, HZ - 0.7)], 0.28, [0.75, 1.05, 1.1, 0.9, 0.55, 0.2]))
H.append(obj_curve([(1.5, 0.3, HZ - 0.1), (1.72, 0.2, HZ - 0.45), (1.66, 0.15, HZ - 0.7)], 0.12, [1.0, 0.6, 0.2]))
fuse(H, W_HAIR, 0.02, 14, 'pony'); bangs_mass('pony_bangs')

CUR[0] = 'hair_braids'
H = [cap(), obj_sphere((0, 0.42, HZ - 0.15), (0.9, 0.48, 0.6))]
for sx in (-1, 1):
    H.append(obj_curve([(sx * 0.72, -0.15, HZ + 0.3), (sx * 0.88, -0.2, HZ - 0.15), (sx * 0.82, -0.3, HZ - 0.45)], 0.18, [1.1, 1.0, 0.85]))
    # braid: chain of plump beads that wiggle left/right
    a, b = Vector((sx * 0.82, -0.3, HZ - 0.45)), Vector((sx * 0.6, -0.48, 1.22))
    n = 7
    for i in range(n):
        t = i / (n - 1); p = a.lerp(b, t)
        r = 0.15 - 0.035 * t
        H.append(obj_sphere((p.x + (0.03 if i % 2 else -0.03), p.y, p.z), (r, r * 0.85, r * 0.8), (0, math.radians(25 if i % 2 else -25), 0), seg=24))
    H.append(obj_sphere((b.x, b.y, b.z - 0.08), (0.07, 0.07, 0.06), seg=24))
    H.append(obj_curve([(b.x, b.y, b.z - 0.1), (b.x + sx * 0.03, b.y - 0.02, b.z - 0.22), (b.x - sx * 0.01, b.y, b.z - 0.32)], 0.08, [1.0, 1.1, 0.3]))
fuse(H, W_HAIR, 0.016, 10, 'braids'); bangs_mass('braids_bangs')

# holdout proxy shared by hats (the cap shape)
CUR[0] = 'capproxy'
obj_sphere((0, 0.2, HZ + 0.2), (0.98, 0.9, 0.9), seg=64, m=W_HAIR)

# ---------------- dresses (tintable) ----------------
CUR[0] = 'dress_aline'
lathe([(0.2, 1.56), (0.3, 1.5), (0.33, 1.36), (0.35, 1.18), (0.44, 1.04), (0.6, 0.82), (0.68, 0.7), (0.66, 0.67)], W_CLOTH)
torus(0.66, 0.055, (0, 0, 0.7), W_CLOTH)
torus(0.355, 0.035, (0, 0, 1.16), W_CLOTH)
for sx in (-1, 1): obj_sphere((sx * 0.31, 0, 1.44), (0.16, 0.15, 0.13), m=W_CLOTH)
obj_sphere((-0.08, -0.31, 1.16), (0.09, 0.04, 0.06), (0, math.radians(-25), 0), m=W_CLOTH)
obj_sphere((0.08, -0.31, 1.16), (0.09, 0.04, 0.06), (0, math.radians(25), 0), m=W_CLOTH)
obj_sphere((0, -0.32, 1.16), (0.04, 0.035, 0.04), m=W_CLOTH)

CUR[0] = 'dress_tutu'
lathe([(0.2, 1.56), (0.3, 1.5), (0.33, 1.36), (0.35, 1.18), (0.36, 1.05)], W_CLOTH)
def ruffle(r0, r1, z0, drop, waves, amp, m, sy=0.9, phase=0.0, thick=0.025):
    """Wavy tulle layer: a cone-like skirt whose hem ripples up/down and in/out."""
    me = bpy.data.meshes.new('ruffle'); bmr = bmesh.new()
    N, S = 192, 10; grid = []
    for j in range(S + 1):
        t = j / S; row = []
        for i in range(N):
            th = 2 * math.pi * i / N
            w = math.sin(waves * th + phase)
            rr = r0 + (r1 - r0) * t + amp * 0.6 * t * t * math.cos(waves * th + phase)
            zz = z0 - drop * t + amp * t * t * w
            row.append(bmr.verts.new((rr * math.cos(th), rr * math.sin(th) * sy, zz)))
        grid.append(row)
    for j in range(S):
        for i in range(N):
            bmr.faces.new((grid[j][i], grid[j][(i + 1) % N], grid[j + 1][(i + 1) % N], grid[j + 1][i]))
    bmr.to_mesh(me); bmr.free()
    o = bpy.data.objects.new('ruffle', me); sc.collection.objects.link(o)
    so = o.modifiers.new('so', 'SOLIDIFY'); so.thickness = thick
    ss = o.modifiers.new('ss', 'SUBSURF'); ss.levels = 1; ss.render_levels = 2
    o.data.materials.append(m)
    for pf in me.polygons: pf.use_smooth = True
    return put(o)

ruffle(0.35, 0.84, 1.06, 0.2, 14, 0.06, W_CLOTH, phase=0.0)
ruffle(0.35, 0.78, 1.02, 0.26, 14, 0.06, W_CLOTH, phase=math.pi / 14)
ruffle(0.35, 0.7, 0.99, 0.3, 12, 0.05, W_CLOTH, phase=0.4)
torus(0.36, 0.04, (0, 0, 1.06), W_CLOTH)
for sx in (-1, 1): obj_curve([(sx * 0.18, -0.2, 1.5), (sx * 0.25, -0.05, 1.62), (sx * 0.24, 0.12, 1.5)], 0.03, m=W_CLOTH)
star_mesh(0.09, 0.04, (0, -0.33, 1.3), (0, 0, 0), W_CLOTH, 0.04)

CUR[0] = 'dress_gown'
lathe([(0.2, 1.56), (0.3, 1.5), (0.33, 1.36), (0.35, 1.18), (0.42, 1.0), (0.58, 0.72), (0.74, 0.44), (0.83, 0.25), (0.81, 0.21)], W_CLOTH)
torus(0.82, 0.05, (0, 0, 0.24), W_CLOTH)
torus(0.36, 0.04, (0, 0, 1.16), W_CLOTH)
for sx in (-1, 1): obj_sphere((sx * 0.31, 0, 1.44), (0.15, 0.14, 0.12), m=W_CLOTH)
for k, (zz, rr) in enumerate(((0.95, 0.46), (0.7, 0.6), (0.45, 0.74))):
    for a in range(-2, 3):
        ang = math.radians(-90 + a * 22)
        obj_sphere((rr * math.cos(ang), rr * math.sin(ang) * 0.86 - 0.02, zz), (0.035, 0.02, 0.035), m=W_CLOTH)

CUR[0] = 'dress_puff'
lathe([(0.2, 1.56), (0.3, 1.5), (0.34, 1.36), (0.36, 1.18), (0.5, 1.05), (0.64, 0.92), (0.66, 0.84), (0.58, 0.78), (0.5, 0.77)], W_CLOTH, thick=0.04)
for sx in (-1, 1): obj_sphere((sx * 0.33, 0, 1.44), (0.21, 0.19, 0.17), m=W_CLOTH)
torus(0.36, 0.04, (0, 0, 1.18), W_CLOTH)
for a in range(-3, 4):
    ang = math.radians(-90 + a * 20)
    obj_sphere((0.62 * math.cos(ang), 0.62 * math.sin(ang) * 0.86, 0.86), (0.05, 0.03, 0.05), m=W_CLOTH)


def front_y(r, sy=0.86): return -r * sy - 0.012

CUR[0] = 'dress_pjs'
lathe([(0.2, 1.56), (0.31, 1.5), (0.345, 1.36), (0.365, 1.18), (0.39, 1.0), (0.4, 0.87), (0.38, 0.85)], W_CLOTH, thick=0.035)
torus(0.395, 0.035, (0, 0, 0.87), W_CLOTH)
for sx in (-1, 1):
    obj_sphere((sx * 0.3, 0, 1.45), (0.15, 0.14, 0.12), m=W_CLOTH)
    obj_curve([(sx * 0.27, 0, 1.44), (sx * 0.43, -0.06, 1.2), (sx * 0.485, -0.11, 1.07)], 0.115, [1.0, 1.0, 1.05], m=W_CLOTH)
    torus(0.115, 0.03, (sx * 0.485, -0.11, 1.07), W_CLOTH, sy=1.0, rot=(math.radians(-15), math.radians(sx * 20), 0))
    obj_curve([(sx * 0.15, 0, 1.0), (sx * 0.16, -0.01, 0.6), (sx * 0.16, -0.02, 0.3)], 0.14, [1.15, 1.0, 1.0], m=W_CLOTH)
    torus(0.14, 0.03, (sx * 0.16, -0.02, 0.3), W_CLOTH, sy=1.0)
    obj_sphere((sx * 0.1, -0.27, 1.53), (0.11, 0.03, 0.07), (0, math.radians(sx * 25), 0), m=W_CLOTH)   # collar
obj_sphere((0, 0, 0.98), (0.36, 0.29, 0.14), m=W_CLOTH)
for zz in (1.34, 1.18, 1.03):
    obj_sphere((0, front_y(0.36) - 0.01, zz), (0.035, 0.02, 0.035), m=W_CLOTH)
for (xx, zz, rr) in ((-0.2, 1.3, 0.2), (0.19, 1.12, -0.3), (-0.17, 1.0, 0.4), (0.2, 1.38, 0.1)):
    star_mesh(0.05, 0.022, (xx, front_y(0.36) + 0.03, zz), (0, math.radians(xx * 80), rr), W_CLOTH, 0.02)
for (xx, zz) in ((-0.16, 0.7), (0.17, 0.5), (-0.15, 0.4), (0.16, 0.8)):
    star_mesh(0.045, 0.02, (xx, -0.15, zz), (0, 0, xx), W_CLOTH, 0.02)

CUR[0] = 'dress_swim'
lathe([(0.26, 1.5), (0.315, 1.43), (0.335, 1.3), (0.36, 1.15), (0.365, 1.02), (0.35, 0.92), (0.33, 0.84), (0.22, 0.75), (0.0, 0.71)], W_CLOTH, thick=0.02)
for sx in (-1, 1):
    obj_curve([(sx * 0.16, -0.25, 1.49), (sx * 0.19, -0.06, 1.66), (sx * 0.16, 0.18, 1.5)], 0.028, m=W_CLOTH)
ruffle(0.36, 0.52, 1.0, 0.14, 12, 0.035, W_CLOTH, phase=0.3, thick=0.02)
torus(0.365, 0.03, (0, 0, 1.0), W_CLOTH)
obj_sphere((-0.07, front_y(0.33) - 0.01, 1.4), (0.07, 0.03, 0.045), (0, math.radians(-25), 0), m=W_CLOTH)
obj_sphere((0.07, front_y(0.33) - 0.01, 1.4), (0.07, 0.03, 0.045), (0, math.radians(25), 0), m=W_CLOTH)
obj_sphere((0, front_y(0.33) - 0.02, 1.4), (0.03, 0.025, 0.03), m=W_CLOTH)

CUR[0] = 'dress_skirt'
lathe([(0.2, 1.56), (0.31, 1.5), (0.34, 1.36), (0.36, 1.18), (0.37, 1.08), (0.35, 1.06)], W_CLOTH)
for zz in (1.4, 1.3, 1.2):   # stripes
    torus(0.352 if zz < 1.35 else 0.34, 0.016, (0, 0, zz), W_CLOTH)
for sx in (-1, 1):
    obj_sphere((sx * 0.31, 0, 1.45), (0.17, 0.16, 0.13), m=W_CLOTH)
    obj_sphere((sx * 0.13, -0.24, 1.5), (0.14, 0.03, 0.1), (0, math.radians(sx * 30), 0), m=W_CLOTH)   # sailor collar
obj_sphere((-0.07, -0.31, 1.43), (0.07, 0.03, 0.045), (0, math.radians(-25), 0), m=W_CLOTH)
obj_sphere((0.07, -0.31, 1.43), (0.07, 0.03, 0.045), (0, math.radians(25), 0), m=W_CLOTH)
obj_sphere((0, -0.32, 1.43), (0.03, 0.025, 0.03), m=W_CLOTH)
ruffle(0.37, 0.64, 1.1, 0.4, 22, 0.018, W_CLOTH, phase=0.0, thick=0.03)
torus(0.37, 0.04, (0, 0, 1.09), W_CLOTH)

CUR[0] = 'dress_overalls'
lathe([(0.355, 1.14), (0.37, 1.02), (0.37, 0.92), (0.34, 0.88)], W_CLOTH, thick=0.03)
for sx in (-1, 1):
    obj_curve([(sx * 0.15, 0, 0.98), (sx * 0.16, -0.01, 0.82), (sx * 0.16, -0.012, 0.74)], 0.14, [1.2, 1.0, 1.0], m=W_CLOTH)
    torus(0.14, 0.025, (sx * 0.16, -0.012, 0.74), W_CLOTH, sy=1.0)
    obj_curve([(sx * 0.16, -0.27, 1.42), (sx * 0.19, -0.08, 1.64), (sx * 0.16, 0.2, 1.4)], 0.03, m=W_CLOTH)
    obj_sphere((sx * 0.15, -0.3, 1.41), (0.035, 0.02, 0.035), m=W_CLOTH)
obj_sphere((0, 0, 0.96), (0.37, 0.29, 0.14), m=W_CLOTH)
obj_sphere((0, -0.01, 0.86), (0.3, 0.26, 0.12), m=W_CLOTH)
bpy.ops.mesh.primitive_cube_add(location=(0, -0.24, 1.27), scale=(0.2, 0.06, 0.16))
bib = bpy.context.object; bv = bib.modifiers.new('bv', 'BEVEL'); bv.width = 0.05; bv.segments = 5
bib.data.materials.append(W_CLOTH); put(bib)
bpy.ops.mesh.primitive_cube_add(location=(0, -0.305, 1.26), scale=(0.09, 0.01, 0.07))
pk = bpy.context.object; bv = pk.modifiers.new('bv', 'BEVEL'); bv.width = 0.02; bv.segments = 4
pk.data.materials.append(W_CLOTH); put(pk)

CUR[0] = 'dress_mermaid'
lathe([(0.2, 1.56), (0.3, 1.5), (0.33, 1.36), (0.355, 1.18), (0.37, 1.0), (0.34, 0.75), (0.29, 0.52), (0.28, 0.4)], W_CLOTH)
ruffle(0.28, 0.62, 0.42, 0.34, 9, 0.06, W_CLOTH, phase=0.2, thick=0.03)
ruffle(0.28, 0.5, 0.4, 0.26, 9, 0.05, W_CLOTH, phase=0.55, thick=0.03)
torus(0.37, 0.04, (0, 0, 1.1), W_CLOTH)
for sx in (-1, 1): obj_curve([(sx * 0.18, -0.2, 1.5), (sx * 0.25, -0.05, 1.62), (sx * 0.24, 0.12, 1.5)], 0.03, m=W_CLOTH)
for k, (zz, rr) in enumerate(((0.95, 0.365), (0.82, 0.35), (0.69, 0.33), (0.56, 0.3))):
    for a in range(-3, 4):
        ang = math.radians(-90 + a * 20 + (10 if k % 2 else 0))
        obj_sphere((rr * math.cos(ang), rr * math.sin(ang) * 0.86 - 0.01, zz), (0.045, 0.02, 0.035), m=W_CLOTH)
star_mesh(0.08, 0.035, (0.22, -0.31, 1.12), (0, math.radians(30), 0.3), W_CLOTH, 0.04)

# ---------------- shoes ----------------
CUR[0] = 'shoes_mary'
for sx in (-1, 1):
    obj_sphere((sx * 0.17, -0.08, 0.13), (0.15, 0.22, 0.11), m=W_SHOE)
    obj_curve([(sx * 0.07, -0.14, 0.2), (sx * 0.17, -0.2, 0.25), (sx * 0.27, -0.14, 0.2)], 0.02, m=W_SHOE)
    obj_sphere((sx * 0.17, -0.27, 0.2), (0.04, 0.025, 0.04), m=W_SHOE)
CUR[0] = 'shoes_boots'
for sx in (-1, 1):
    obj_sphere((sx * 0.17, -0.08, 0.13), (0.15, 0.22, 0.12), m=W_SHOE)
    obj_curve([(sx * 0.165, 0, 0.14), (sx * 0.165, 0, 0.46)], 0.125, m=W_SHOE)
    torus(0.13, 0.035, (sx * 0.165, 0, 0.47), W_SHOE, sy=1.0)

CUR[0] = 'shoes_slippers'
for sx in (-1, 1):
    obj_sphere((sx * 0.17, -0.1, 0.14), (0.17, 0.25, 0.13), m=W_SHOE)
    for ex in (-1, 1):
        obj_curve([(sx * 0.17 + ex * 0.06, -0.2, 0.22), (sx * 0.17 + ex * 0.08, -0.22, 0.38), (sx * 0.17 + ex * 0.07, -0.2, 0.45)], 0.04, [1.0, 1.0, 0.5], m=W_SHOE)
    for ex in (-1, 1): obj_sphere((sx * 0.17 + ex * 0.045, -0.33, 0.18), (0.016, 0.01, 0.02), m=DARK)
    obj_sphere((sx * 0.17, -0.35, 0.15), (0.02, 0.012, 0.016), m=BLUSH)
CUR[0] = 'shoes_sandals'
for sx in (-1, 1):
    obj_sphere((sx * 0.17, -0.08, 0.05), (0.15, 0.23, 0.045), m=W_SHOE)
    torus(0.105, 0.025, (sx * 0.165, -0.12, 0.13), W_SHOE, sy=1.25, rot=(math.radians(-60), 0, 0))
    torus(0.105, 0.022, (sx * 0.165, -0.02, 0.2), W_SHOE, sy=1.0, rot=(math.radians(-10), 0, 0))
    obj_sphere((sx * 0.165, -0.24, 0.17), (0.04, 0.025, 0.04), m=W_SHOE)

# ---------------- hats / hair accessories ----------------
CUR[0] = 'hat_crown'
cz = HZ + 1.04
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.36, depth=0.15, location=(0, 0.12, cz))
cr = bpy.context.object; cr.data.materials.append(GOLD); put(cr)
so = cr.modifiers.new('so', 'SOLIDIFY'); so.thickness = 0.03
for i in range(5):
    a = math.radians(-90 + (i - 2) * 38)
    x, y = 0.36 * math.cos(a), 0.12 + 0.36 * math.sin(a)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.1, radius2=0.0, depth=0.3 if i == 2 else 0.24, location=(x, y, cz + (0.2 if i == 2 else 0.17)))
    c = bpy.context.object; c.data.materials.append(GOLD); bpy.ops.object.shade_smooth(); put(c)
    obj_sphere((x, y, cz + (0.36 if i == 2 else 0.3)), (0.04, 0.04, 0.04), m=GOLD)
obj_sphere((0, -0.25, cz), (0.07, 0.035, 0.07), m=GEMP)
for sx in (-1, 1): obj_sphere((sx * 0.23, -0.17, cz), (0.05, 0.03, 0.05), m=GEMB)

CUR[0] = 'hat_bow'
bx, bzz = 0.55, HZ + 0.82
obj_sphere((bx - 0.2, -0.05, bzz + 0.06), (0.24, 0.1, 0.16), (0, math.radians(25), 0), m=W_CLOTH)
obj_sphere((bx + 0.2, -0.05, bzz + 0.06), (0.24, 0.1, 0.16), (0, math.radians(-25), 0), m=W_CLOTH)
obj_curve([(bx - 0.04, -0.1, bzz), (bx - 0.16, -0.12, bzz - 0.25)], 0.05, [1, 0.6], m=W_CLOTH)
obj_curve([(bx + 0.04, -0.1, bzz), (bx + 0.18, -0.12, bzz - 0.22)], 0.05, [1, 0.6], m=W_CLOTH)
obj_sphere((bx, -0.13, bzz + 0.04), (0.09, 0.08, 0.09), m=W_CLOTH)

CUR[0] = 'hat_flowers'
for i, mm in enumerate((F_PINK, F_LAV, F_YEL, F_MINT, F_PINK, F_LAV, F_YEL)):
    a = math.radians(200 + i * 23)
    fx, fz = 0.86 * math.cos(a) * 1.0, HZ + 0.68 + 0.28 * math.sin(a) * 0 + (0.12 if i in (2, 3, 4) else 0)
    fx = -0.78 + i * 0.26; fz = HZ + 0.72 + 0.18 * math.sin(math.pi * i / 6)
    fy = face(max(min(fx, 0.95), -0.95) * 0.95, min(fz, HZ + 0.6)) - 0.12
    for p in range(5):
        pa = 2 * math.pi * p / 5
        obj_sphere((fx + 0.075 * math.cos(pa), fy, fz + 0.075 * math.sin(pa)), (0.06, 0.04, 0.06), m=mm)
    obj_sphere((fx, fy - 0.03, fz), (0.04, 0.03, 0.04), m=F_YEL if mm is not F_YEL else F_PINK)
    obj_sphere((fx + 0.1, fy + 0.02, fz - 0.08), (0.06, 0.02, 0.03), (0, math.radians(30), 0), m=LEAF)

CUR[0] = 'hat_star'
star_mesh(0.17, 0.075, (0.5, face(0.5, HZ + 0.45) - 0.26, HZ + 0.45), (math.radians(-10), math.radians(-15), math.radians(-25)), GOLD)
star_mesh(0.11, 0.05, (-0.62, face(-0.62, HZ + 0.4) - 0.2, HZ + 0.4), (math.radians(-10), math.radians(15), math.radians(20)), GOLD)

CUR[0] = 'hat_ears'
torus(1.0, 0.045, (0, 0.2, HZ + 0.2), W_CLOTH, sy=0.93, rot=(math.radians(-70), 0, 0))   # hugs the hair cap
for sx in (-1, 1):
    obj_curve([(sx * 0.35, 0.05, HZ + 0.95), (sx * 0.45, 0.0, HZ + 1.4), (sx * 0.42, 0.0, HZ + 1.62)], 0.17, [1.0, 1.0, 0.5], m=W_CLOTH)
    obj_curve([(sx * 0.36, -0.13, HZ + 1.08), (sx * 0.44, -0.16, HZ + 1.4), (sx * 0.42, -0.15, HZ + 1.55)], 0.08, [0.9, 0.9, 0.4], m=INNER)

CUR[0] = 'hat_cat'
torus(1.0, 0.045, (0, 0.2, HZ + 0.2), W_CLOTH, sy=0.93, rot=(math.radians(-70), 0, 0))   # hugs the hair cap
for sx in (-1, 1):
    e = obj_curve([(sx * 0.46, 0.05, HZ + 0.95), (sx * 0.55, 0.05, HZ + 1.2), (sx * 0.63, 0.05, HZ + 1.4)], 0.22, [1.0, 0.6, 0.08], m=W_CLOTH); e.scale = (1, 0.5, 1)
    e = obj_curve([(sx * 0.47, -0.2, HZ + 1.0), (sx * 0.55, -0.2, HZ + 1.2), (sx * 0.61, -0.2, HZ + 1.34)], 0.13, [1.0, 0.6, 0.08], m=INNER); e.scale = (1, 0.5, 1)

CUR[0] = 'hat_sunhat'
sh = lathe([(1.3, -0.1), (1.15, -0.02), (0.98, 0.03), (0.95, 0.12), (0.93, 0.32), (0.82, 0.52), (0.5, 0.64), (0.0, 0.66)], W_CLOTH, thick=0.03, sy=0.92)
sh.location = (0, 0.15, HZ + 0.6); sh.rotation_euler = (math.radians(8), 0, 0)
torus(0.955, 0.06, (0, 0.15, HZ + 0.7), W_CLOTH, sy=0.92, rot=(math.radians(8), 0, 0))
for p in range(5):
    pa = 2 * math.pi * p / 5
    obj_sphere((0.62 + 0.08 * math.cos(pa), -0.62, HZ + 0.8 + 0.08 * math.sin(pa)), (0.07, 0.035, 0.07), m=W_CLOTH)
obj_sphere((0.62, -0.66, HZ + 0.8), (0.045, 0.03, 0.045), m=W_CLOTH)

def heart_mesh(sz, loc, rot, m, thick=0.06):
    me = bpy.data.meshes.new('heart'); bmx = bmesh.new(); vs = []
    for i in range(40):
        t = 2 * math.pi * i / 40
        x = 16 * math.sin(t) ** 3; z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        vs.append(bmx.verts.new((x * sz / 16, 0, z * sz / 16)))
    bmx.faces.new(vs); bmx.to_mesh(me); bmx.free()
    o = bpy.data.objects.new('heart', me); sc.collection.objects.link(o)
    o.location = loc; o.rotation_euler = rot
    so = o.modifiers.new('so', 'SOLIDIFY'); so.thickness = thick; so.offset = 0
    bv = o.modifiers.new('bv', 'BEVEL'); bv.width = 0.02; bv.segments = 4
    o.data.materials.append(m); return put(o)
CUR[0] = 'hat_hearts'
heart_mesh(0.16, (0.52, face(0.52, HZ + 0.45) - 0.26, HZ + 0.45), (math.radians(-10), math.radians(-15), math.radians(-20)), GEMP)
heart_mesh(0.11, (-0.62, face(-0.62, HZ + 0.4) - 0.2, HZ + 0.4), (math.radians(-10), math.radians(15), math.radians(18)), GEMP)

# ---------------- wings ----------------
CUR[0] = 'wings_fairy'
for sx in (-1, 1):
    obj_sphere((sx * 1.05, 0.42, 1.8), (0.78, 0.05, 0.5), (0, math.radians(-sx * 30), math.radians(sx * 12)), m=W_WING)
    obj_sphere((sx * 0.95, 0.4, 1.0), (0.55, 0.045, 0.3), (0, math.radians(sx * 28), math.radians(sx * 10)), m=W_WING)

CUR[0] = 'wings_butterfly'
for sx in (-1, 1):
    obj_sphere((sx * 1.1, 0.42, 1.85), (0.68, 0.05, 0.6), (0, math.radians(-sx * 35), 0), m=W_WING)
    obj_sphere((sx * 0.92, 0.4, 1.02), (0.48, 0.045, 0.44), (0, math.radians(sx * 30), 0), m=W_WING)
    for (dx, dz, r) in ((1.35, 2.05, 0.17), (1.05, 1.65, 0.11), (1.05, 0.95, 0.13)):
        obj_sphere((sx * dx, 0.36, dz), (r, 0.02, r), m=W_CLOTH)

# ---------------- held items (right hand at 0.51,-0.13,0.97) ----------------
HAND = Vector((0.51, -0.13, 0.97))
CUR[0] = 'hold_wand'
obj_curve([(0.5, -0.16, 0.92), (0.66, -0.22, 1.42)], 0.03, m=WAND)
star_mesh(0.17, 0.075, (0.69, -0.24, 1.52), (0, 0, math.radians(-12)), GOLD, 0.08)
CUR[0] = 'hold_balloon'
# string swings out in front of the hair (hold layers draw over hair, so keep it truly in front)
obj_curve([(0.52, -0.2, 0.98), (0.95, -0.75, 1.35), (1.22, -0.85, 1.82)], 0.008, m=W_CLOTH)
obj_sphere((1.26, -0.85, 2.1), (0.27, 0.25, 0.32), m=W_CLOTH)
bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.05, radius2=0.0, depth=0.08, location=(1.235, -0.85, 1.79), rotation=(math.radians(180), 0, 0))
c = bpy.context.object; c.data.materials.append(W_CLOTH); put(c)
CUR[0] = 'hold_bouquet'
bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.15, radius2=0.03, depth=0.4, location=(0.54, -0.2, 0.95), rotation=(math.radians(-8), math.radians(-12), 0))
c = bpy.context.object; c.data.materials.append(PAPER); bpy.ops.object.shade_smooth(); put(c)
for (fx, fz, mm) in ((0.46, 1.2, F_PINK), (0.62, 1.22, F_LAV), (0.54, 1.32, F_YEL), (0.5, 1.12, F_MINT), (0.64, 1.1, F_PINK)):
    for p in range(5):
        pa = 2 * math.pi * p / 5
        obj_sphere((fx + 0.055 * math.cos(pa), -0.26, fz + 0.055 * math.sin(pa)), (0.05, 0.035, 0.05), m=mm)
    obj_sphere((fx, -0.29, fz), (0.03, 0.025, 0.03), m=F_YEL if mm is not F_YEL else F_PINK)
CUR[0] = 'hold_purse'
obj_curve([(0.42, -0.2, 0.86), (0.5, -0.22, 1.0), (0.6, -0.2, 0.86)], 0.02, m=W_CLOTH)
obj_sphere((0.51, -0.2, 0.75), (0.2, 0.09, 0.14), m=W_CLOTH)
obj_sphere((0.51, -0.29, 0.77), (0.05, 0.02, 0.05), m=W_CLOTH)

CUR[0] = 'hold_teddy'
BEAR = mat('bear', '#C9925F', 0.7, sss=0.1); BEARL = mat('bearl', '#F1D3B0', 0.7)
obj_sphere((0.62, -0.32, 0.86), (0.17, 0.14, 0.19), m=BEAR)
obj_sphere((0.62, -0.42, 0.84), (0.1, 0.05, 0.11), m=BEARL)
obj_sphere((0.62, -0.34, 1.13), (0.15, 0.13, 0.14), m=BEAR)
for ex in (-1, 1):
    obj_sphere((0.62 + ex * 0.11, -0.32, 1.25), (0.055, 0.04, 0.055), m=BEAR)
    obj_sphere((0.62 + ex * 0.11, -0.355, 1.25), (0.03, 0.02, 0.03), m=BEARL)
    obj_sphere((0.62 + ex * 0.055, -0.46, 1.16), (0.018, 0.01, 0.02), m=DARK)
    obj_sphere((0.62 + ex * 0.1, -0.38, 0.7), (0.06, 0.07, 0.05), m=BEAR)
obj_sphere((0.62, -0.47, 1.09), (0.055, 0.03, 0.04), m=BEARL)
obj_sphere((0.62, -0.5, 1.1), (0.02, 0.012, 0.015), m=DARK)
obj_curve([(0.5, -0.35, 0.95), (0.47, -0.4, 0.86)], 0.05, m=BEAR)
obj_curve([(0.74, -0.35, 0.95), (0.79, -0.4, 0.88)], 0.05, m=BEAR)
for ex in (-1, 1): obj_sphere((0.62 + ex * 0.04, -0.47, 1.0), (0.04, 0.02, 0.025), (0, 0, ex * 0.5), m=GEMP)
CUR[0] = 'hold_icecream'
CONE = mat('cone', '#E9B26B', 0.6)
bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.1, radius2=0.012, depth=0.32, location=(0.53, -0.2, 1.07), rotation=(0, math.radians(4), 0))
c = bpy.context.object; c.rotation_euler = (math.radians(180), math.radians(-4), 0); c.data.materials.append(CONE); bpy.ops.object.shade_smooth(); put(c)
obj_sphere((0.54, -0.2, 1.27), (0.12, 0.11, 0.1), m=F_MINT)
obj_sphere((0.55, -0.2, 1.38), (0.11, 0.1, 0.09), m=F_PINK)
obj_sphere((0.56, -0.21, 1.49), (0.04, 0.04, 0.04), m=mat('cherry', '#E8304A', 0.2, coat=1.0))

# ---------------- head tilt (head-level groups) ----------------
piv = Vector((0, 0, 1.6))
T = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(-5), 4, 'Y') @ Matrix.Translation(-piv)
HAIRS = ['hair_curls', 'hair_long', 'hair_buns', 'hair_pony', 'hair_braids']
TILT = {'eyes', 'eyeshine', 'happy', 'face', 'capproxy', *HAIRS,
        'hat_crown', 'hat_bow', 'hat_flowers', 'hat_star', 'hat_ears', 'hat_cat', 'hat_sunhat', 'hat_hearts'}
head.matrix_world = T @ head.matrix_world
for g in TILT:
    for o in COLL[g].objects:
        o.matrix_world = T @ o.matrix_world

# ---------------- lights / camera ----------------
def light(loc, energy, size, col=(1, 1, 1), target=(0, 0, 1.6)):
    bpy.ops.object.light_add(type='AREA', location=loc)
    l = bpy.context.object; l.data.energy = energy; l.data.size = size; l.data.color = col
    l.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
light((-2.5, -6, 4.0), 520, 5, (1, 0.97, 0.95))
light((3.5, -4, 1.5), 150, 4, (1, 0.9, 0.96))
light((-3.2, 2.5, 3.2), 800, 2.5, (1, 0.82, 0.9))
light((3.2, 2.5, 3.2), 800, 2.5, (1, 0.86, 0.95))
light((0, 3.0, 5.5), 500, 3, (1, 0.95, 1))
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (*srgb('#FFE6F1'), 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.5
bpy.ops.object.camera_add()
cam = bpy.context.object; sc.camera = cam; cam.data.lens = 75
cam.location = (-2.2, -9.4, 2.15)
cam.rotation_euler = (Vector((0, 0, 1.7)) - cam.location).to_track_quat('-Z', 'Y').to_euler()

# ---------------- hair shine (untinted "halo" glints, one layer per style) ----------------
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
def hit(group, target):
    """First point on the visible hair surface along the camera ray through `target`."""
    org = cam.matrix_world.translation; d = (Vector(target) - org).normalized(); best = None
    for o in COLL[group].objects:
        ev = o.evaluated_get(dg); inv = ev.matrix_world.inverted()
        lo = inv @ org; ld = (inv.to_3x3() @ d).normalized()
        ok, loc, nrm, _ = ev.ray_cast(lo, ld)
        if ok:
            w = ev.matrix_world @ loc
            if best is None or (w - org).length < (best - org).length: best = w
    return best
for g in HAIRS:
    CUR[0] = g + '_shine'
    for (a0, a1) in ((-0.84, -0.4), (-0.32, 0.12), (0.2, 0.62)):
        pts = []
        for k in range(7):
            xx = a0 + (a1 - a0) * k / 6
            zz = HZ + 0.36 + 0.1 * (1 - (xx / 0.95) ** 2) - 0.05 * xx
            p = hit(g, (xx, -1.0, zz))
            if p is not None: pts.append(p + (cam.matrix_world.translation - p).normalized() * 0.03)
        if len(pts) >= 3:
            obj_curve([tuple(p) for p in pts], 0.022, [0.2, 0.7, 1.0, 1.0, 1.0, 0.7, 0.2][:len(pts)], m=SHINE)

sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x = 800; sc.render.resolution_y = 1000; sc.render.resolution_percentage = 100 * SCALE
sc.cycles.use_adaptive_sampling = True; sc.cycles.adaptive_threshold = 0.02
sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'; sc.view_settings.exposure = -0.95

# ---------------- render loop ----------------
HOLD = {  # layer -> groups used as holdout (must sit in front of it)
    'under': ['skin'], 'dress_aline': ['skin'], 'dress_tutu': ['skin'], 'dress_gown': ['skin'], 'dress_puff': ['skin'],
    'shoes_mary': ['skin'], 'shoes_boots': ['skin'],
    'hair_curls': ['skin'], 'hair_long': ['skin'], 'hair_buns': ['skin'], 'hair_pony': ['skin'], 'hair_braids': ['skin'],
    **{g + '_shine': [g, 'skin'] for g in ['hair_curls', 'hair_long', 'hair_buns', 'hair_pony', 'hair_braids']},
    'dress_pjs': ['skin'], 'dress_swim': ['skin'], 'dress_skirt': ['skin'], 'dress_overalls': ['skin'], 'dress_mermaid': ['skin'],
    'shoes_slippers': ['skin'], 'shoes_sandals': ['skin'],
    'hat_cat': ['skin', 'capproxy'], 'hat_sunhat': ['skin', 'capproxy'], 'hat_hearts': ['skin'],
    'wings_butterfly': [], 'hold_teddy': [], 'hold_icecream': [],
    'hat_crown': ['skin', 'capproxy'], 'hat_bow': ['skin', 'capproxy'], 'hat_flowers': ['skin', 'capproxy'],
    'hat_star': ['skin'], 'hat_ears': ['skin', 'capproxy'],
    'hold_wand': [], 'hold_balloon': [], 'hold_bouquet': [], 'hold_purse': [],
    'eyes': [], 'eyeshine': [], 'happy': [], 'face': [], 'skin': [], 'wings_fairy': [],
}
ALL = list(HOLD.keys())
def show_only(layer, holds):
    for g, c in COLL.items():
        for o in c.objects:
            o.hide_render = not (g == layer or g in holds)
            o.is_holdout = g in holds and g != layer

def render(path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

# ---------------- passes (docs/MODEL_UPGRADE.md 1.1 and 1.2) ----------------
TINTED = [W_SKIN, W_HAIR, W_CLOTH, W_SHOE, W_WING]
LIGHTS = {tuple(round(v, 2) for v in o.location): o for o in bpy.data.objects if o.type == 'LIGHT'}
BACK_LIGHTS = [o for o in LIGHTS.values() if o.location.y > 0]      # edge lights behind / above the doll
FILL, LEFT_BACK = LIGHTS[(3.5, -4.0, 1.5)], LIGHTS[(-3.2, 2.5, 3.2)]
BG = sc.world.node_tree.nodes['Background']
TODAY = dict(fill=(FILL.data.energy, tuple(FILL.data.color)), left=LEFT_BACK.data.energy,
             world=BG.inputs['Strength'].default_value, exposure=sc.view_settings.exposure)

def lighting(headroom):
    """Tinted layers: weaker cooler fill, dimmer left edge light, less ambient and lower exposure,
    so lit areas land around 0.75 instead of clipping at 1.0. Untinted layers keep the original light."""
    FILL.data.energy, FILL.data.color = (70, (0.92, 0.94, 1.0)) if headroom else TODAY['fill']
    LEFT_BACK.data.energy = 450 if headroom else TODAY['left']
    BG.inputs['Strength'].default_value = 0.3 if headroom else TODAY['world']
    sc.view_settings.exposure = -1.35 if headroom else TODAY['exposure']

def _b(m): return m.node_tree.nodes.get('Principled BSDF')
SAVED = {}
for m in bpy.data.materials:
    b = _b(m)
    if b: SAVED[m.name] = (tuple(b.inputs['Base Color'].default_value), b.inputs['Subsurface Weight'].default_value,
                           b.inputs['Specular IOR Level'].default_value, b.inputs['Coat Weight'].default_value,
                           b.inputs['Emission Strength'].default_value)

def materials(mode):
    """full: as authored. base: tinted materials lose spec and coat (diffuse only).
    gloss: tinted materials keep only spec and coat on black; everything else goes black."""
    for m in bpy.data.materials:
        b = _b(m)
        if not b: continue
        base, sss, spec, coat, emit = SAVED[m.name]; t = m in TINTED
        g = mode == 'gloss'
        b.inputs['Base Color'].default_value = (0, 0, 0, 1) if g else base
        b.inputs['Subsurface Weight'].default_value = 0 if g else sss
        b.inputs['Emission Strength'].default_value = 0 if g else emit
        b.inputs['Specular IOR Level'].default_value = 0 if (mode == 'base' and t) or (g and not t) else spec
        b.inputs['Coat Weight'].default_value = 0 if (mode == 'base' and t) or (g and not t) else coat
    for o in BACK_LIGHTS: o.visible_glossy = mode != 'gloss'    # no bright outline round every item
    sc.world.cycles_visibility.glossy = mode != 'gloss'         # no pink sheen from the sky

def tinted(layer):
    return any(m in TINTED for o in COLL[layer].objects for m in getattr(o.data, 'materials', []) if m)

def render_pass(layer, kind):
    t = tinted(layer)
    materials('gloss' if kind == 'G' else ('base' if t else 'full'))
    lighting(t)
    show_only(layer, HOLD[layer])
    # see-through pieces (blush discs, glints) render grainy at low sample counts
    sc.cycles.samples = max(SAMPLES, 256) if layer == 'face' or layer.endswith('_shine') else SAMPLES
    render(os.path.join(OUTDIR, ('G_' if kind == 'G' else '') + f'{layer}.png'))
    print('DONE', kind, layer, flush=True)

HOLD['capproxy'] = []      # the shared hair cap: process_art.py lets hat contact shadows fall on it
if WANT == ['ALL']: WANT = ALL + ['capproxy']
for L in WANT:
    if L == 'preview':
        materials('full'); lighting(False)
        vis = set(os.environ.get('VIS', 'skin,under,eyes,eyeshine,face,hair_curls,hair_curls_shine,dress_aline,shoes_mary,hat_star').split(','))
        for g, c in COLL.items():
            for o in c.objects:
                o.hide_render = g not in vis; o.is_holdout = False
        render(os.path.join(OUTDIR, 'preview.png'))
        continue
    if L.startswith('G_'):
        render_pass(L[2:], 'G'); continue
    render_pass(L, 'L')
    if DO_GLOSS and tinted(L) and L != 'capproxy':
        render_pass(L, 'G')
