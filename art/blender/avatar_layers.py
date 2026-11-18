"""Render every dress-up layer of the avatar from one fixed camera.
usage: python layers.py -- outdir layer1 layer2 ...   (or 'ALL' / 'preview')
Tinted layers are rendered in near-white so the app can colour them by multiply."""
import bpy, math, sys, bmesh, os
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUTDIR = ARGS[0] if ARGS else '/home/claude/blend/out'
WANT = ARGS[1:] if len(ARGS) > 1 else ['preview']
SAMPLES = int(os.environ.get('SAMPLES', '40'))
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
W_HAIR = mat('whair', '#F7F3F5', 0.42, coat=0.25, spec=0.45, sss=0.1)
W_CLOTH = mat('wcloth', '#FBFAFB', 0.42, coat=0.25, sss=0.05)
W_SHOE = mat('wshoe', '#FBFAFB', 0.3, coat=0.6)
W_WING = mat('wwing', '#FFFFFF', 0.15, trans=0.55, emit=0.15, coat=0.6)
UNDER = mat('under', '#FFFFFF', 0.6, sss=0.05)
# eyes in greys (tinted later); highlights separate & untinted
G_RIM = mat('grim', '#2A2A2E', 0.2, coat=0.8)
G_IRIS = mat('giris', '#C9C9C9', 0.15, coat=1.0)
G_MID = mat('gmid', '#8E8E8E', 0.2, coat=0.8)
G_DK = mat('gdk', '#575757', 0.2, coat=0.8)
G_PUP = mat('gpup', '#2E2E2E', 0.2, coat=0.8)
G_LIGHT = mat('glight', '#FFFFFF', 0.2, emit=0.35)
WHITE = mat('white', '#FFFFFF', 0.2, emit=0.7)
DARK = mat('dark', '#2E1238', 0.25, coat=0.6)
BLUSH = mat('blush', '#FF7FA8', 0.6, emit=0.25)
MOUTHM = mat('mouth', '#C2275B', 0.4)
TONGUE = mat('tongue', '#FF8DA6', 0.4)
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

HZ = 2.28; HX, HY, HZR = 0.98, 0.86, 0.8
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
head = obj_sphere((0, 0, HZ), (HX, HY, HZR), seg=96, m=W_SKIN); head.name = 'head'

# ---------------- underwear ----------------
CUR[0] = 'under'
obj_sphere((0, -0.01, 1.2), (0.355, 0.28, 0.27), m=UNDER)
obj_sphere((0, 0, 0.9), (0.33, 0.27, 0.16), m=UNDER)

# ---------------- face helpers ----------------
EZ = HZ - 0.27
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
        lx = x + sx * 0.245 * math.cos(r); lz = EZ + 0.27 * math.sin(r) - 0.004
        pts.append((lx, face(lx, lz) - 0.03, lz))
    obj_curve(pts, 0.018, [0.3, 0.9, 1.0, 1.0, 0.6], m=m)
    for k, (dx, dz) in enumerate(((0.08, 0.05), (0.06, -0.01))):
        lx0 = x + sx * (0.22 - k * 0.03); lz0 = EZ + 0.13 - k * 0.07
        obj_curve([(lx0, face(lx0, lz0) - 0.03, lz0), (lx0 + sx * dx, face(lx0 + sx * dx, lz0 + dz) - 0.02, lz0 + dz)], 0.014, [1.0, 0.2], m=m)

# eyes (tinted) and highlights (untinted)
for sx in (-1, 1):
    x = sx * 0.37
    CUR[0] = 'eyes'
    decal(x, EZ, 0.245, 0.275, G_RIM, 0.004)
    decal(x, EZ - 0.018, 0.222, 0.248, G_IRIS, 0.008)
    decal(x, EZ - 0.018, 0.222, 0.248, G_MID, 0.010, cut=EZ - 0.05)
    decal(x, EZ - 0.018, 0.222, 0.248, G_DK, 0.012, cut=EZ + 0.06)
    decal(x, EZ, 0.1, 0.12, G_PUP, 0.014)
    decal(x, EZ - 0.16, 0.16, 0.08, G_LIGHT, 0.016)
    lid(x, sx, G_RIM)
    CUR[0] = 'eyeshine'
    decal(x - 0.085, EZ + 0.07, 0.085, 0.095, WHITE, 0.02)
    decal(x + 0.08, EZ + 0.1, 0.04, 0.045, WHITE, 0.02)
    decal(x + 0.07, EZ - 0.1, 0.035, 0.035, WHITE, 0.022)
    # happy closed eyes  ^ ^
    CUR[0] = 'happy'
    pts = []
    for ang in (175, 135, 90, 45, 5):
        r = math.radians(ang)
        lx = x + sx * 0.17 * math.cos(r); lz = EZ - 0.04 + 0.12 * math.sin(r)
        pts.append((lx, face(lx, lz) - 0.03, lz))
    obj_curve(pts, 0.03, [0.5, 1.0, 1.1, 1.0, 0.5], m=DARK)
    CUR[0] = 'face'
    decal(sx * 0.5, EZ - 0.25, 0.12, 0.07, BLUSH, 0.004)
CUR[0] = 'face'
mz = EZ - 0.36
halfdisc(0, mz, 0.085, 0.075, MOUTHM, -0.02)
halfdisc(0, mz - 0.042, 0.045, 0.03, TONGUE, -0.03)

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
lathe([(0.2, 1.56), (0.3, 1.5), (0.33, 1.36), (0.35, 1.18), (0.42, 1.0), (0.58, 0.72), (0.76, 0.38), (0.86, 0.12), (0.84, 0.08)], W_CLOTH)
torus(0.85, 0.05, (0, 0, 0.11), W_CLOTH)
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
torus(0.92, 0.045, (0, 0.15, HZ + 0.55), W_CLOTH, sy=0.9, rot=(math.radians(-70), 0, 0))
for sx in (-1, 1):
    obj_curve([(sx * 0.35, 0.05, HZ + 0.95), (sx * 0.45, 0.0, HZ + 1.4), (sx * 0.42, 0.0, HZ + 1.62)], 0.17, [1.0, 1.0, 0.5], m=W_CLOTH)
    obj_curve([(sx * 0.36, -0.13, HZ + 1.08), (sx * 0.44, -0.16, HZ + 1.4), (sx * 0.42, -0.15, HZ + 1.55)], 0.08, [0.9, 0.9, 0.4], m=INNER)

# ---------------- wings ----------------
CUR[0] = 'wings_fairy'
for sx in (-1, 1):
    obj_sphere((sx * 0.6, 0.38, 1.5), (0.52, 0.05, 0.36), (0, math.radians(-sx * 30), math.radians(sx * 12)), m=W_WING)
    obj_sphere((sx * 0.48, 0.36, 1.02), (0.32, 0.045, 0.22), (0, math.radians(sx * 28), math.radians(sx * 10)), m=W_WING)

# ---------------- held items (right hand at 0.51,-0.13,0.97) ----------------
HAND = Vector((0.51, -0.13, 0.97))
CUR[0] = 'hold_wand'
obj_curve([(0.5, -0.16, 0.92), (0.66, -0.22, 1.42)], 0.03, m=WAND)
star_mesh(0.17, 0.075, (0.69, -0.24, 1.52), (0, 0, math.radians(-12)), GOLD, 0.08)
CUR[0] = 'hold_balloon'
obj_curve([(0.52, -0.14, 0.98), (0.7, -0.1, 1.5), (0.82, -0.05, 1.98)], 0.008, m=W_CLOTH)
obj_sphere((0.86, -0.05, 2.25), (0.27, 0.25, 0.32), m=W_CLOTH)
bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.05, radius2=0.0, depth=0.08, location=(0.83, -0.05, 1.94), rotation=(math.radians(180), 0, 0))
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

# ---------------- head tilt (head-level groups) ----------------
piv = Vector((0, 0, 1.6))
T = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(-5), 4, 'Y') @ Matrix.Translation(-piv)
TILT = {'eyes', 'eyeshine', 'happy', 'face', 'hair_curls', 'hair_long', 'hair_buns', 'capproxy',
        'hat_crown', 'hat_bow', 'hat_flowers', 'hat_star', 'hat_ears'}
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
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x = 800; sc.render.resolution_y = 1000
sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'Medium High Contrast'; sc.view_settings.exposure = -0.95

# ---------------- render loop ----------------
HOLD = {  # layer -> groups used as holdout (must sit in front of it)
    'under': ['skin'], 'dress_aline': ['skin'], 'dress_tutu': ['skin'], 'dress_gown': ['skin'], 'dress_puff': ['skin'],
    'shoes_mary': ['skin'], 'shoes_boots': ['skin'],
    'hair_curls': ['skin'], 'hair_long': ['skin'], 'hair_buns': ['skin'],
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

if WANT == ['ALL']: WANT = ALL
for L in WANT:
    if L == 'preview':
        vis = {'skin', 'under', 'eyes', 'eyeshine', 'face', 'hair_curls', 'dress_aline', 'shoes_mary', 'hat_star'}
        for g, c in COLL.items():
            for o in c.objects:
                o.hide_render = g not in vis; o.is_holdout = False
        render(os.path.join(OUTDIR, 'preview.png'))
    else:
        show_only(L, HOLD[L])
        render(os.path.join(OUTDIR, f'{L}.png'))
    print('DONE', L, flush=True)
