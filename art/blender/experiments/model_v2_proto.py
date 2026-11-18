"""Prototype of the model upgrade in docs/MODEL_UPGRADE.md.

It loads art/blender/avatar_layers.py, applies the spec's changes as text patches
(so the original stays the source of truth until an art PR adopts them), and renders
two kinds of image per layer:

  <layer>.png    base pass: diffuse only; tinted layers get the new light with headroom (tint them with a ramp)
  G_<layer>.png  gloss pass: specular and coat only (tint it with the light tone halfway to white, draw it with screen blend)

The contact shadows are not rendered here: tools/compose_layers.py makes them from each
item's outline (spec 1.4).

usage:
  python model_v2_proto.py -- OUTDIR [options] LAYER [G:LAYER] ...
options:
  --scale 2              render at 2x (1600x2000)
  --samples 32           Cycles samples (default 32)
  --border x0 x1 y0 y1   render only this region (0..1, y from the bottom), keeping the full canvas
  --original             skip the patches (renders exactly what avatar_layers.py renders)
  --ring 0.5             add the experimental ring band to the hair's gloss pass at this strength (see 3.2)
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'avatar_layers.py')

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = args.pop(0)
SCALE, SAMPLES, BORDER, ORIGINAL, RING_STRENGTH, WANT = 1, 32, None, False, 0.0, []
while args:
    a = args.pop(0)
    if a == '--scale': SCALE = int(args.pop(0))
    elif a == '--samples': SAMPLES = int(args.pop(0))
    elif a == '--border': BORDER = [float(args.pop(0)) for _ in range(4)]
    elif a == '--original': ORIGINAL = True
    elif a == '--ring': RING_STRENGTH = float(args.pop(0))
    else: WANT.append(a)

src = open(SRC).read()
src = src[:src.index("if WANT == ['ALL']")]          # keep the scene, drop the render loop


def patch(old, new):
    global src
    assert src.count(old) == 1, f'patch anchor not found exactly once: {old[:60]!r}'
    src = src.replace(old, new)


if not ORIGINAL:
    # 2.1 Cheeks: one smooth head with soft bulges, instead of 4 fused spheres that leave creases
    #     under the eyes and notches in the outline. Every vertex moves along its own normal, read
    #     before anything moves (reading normals while moving vertices crumples the surface).
    # 2.2 face() then finds the real surface with a ray, so lids and the closed eyes sit on the
    #     cheeks instead of inside them.
    patch("head = fuse([obj_sphere((0, 0, HZ), (HX, HY, HZR), seg=96),\n"
          "             obj_sphere((-0.42, -0.36, HZ - 0.4), (0.4, 0.36, 0.34), seg=48),\n"
          "             obj_sphere((0.42, -0.36, HZ - 0.4), (0.4, 0.36, 0.34), seg=48),\n"
          "             obj_sphere((0, -0.3, HZ - 0.5), (0.5, 0.4, 0.3), seg=48)], W_SKIN, 0.012, 12, 'head')",
          "head = obj_sphere((0, 0, HZ), (HX, HY, HZR), seg=128, m=W_SKIN); head.name = 'head'\n"
          "bpy.ops.object.select_all(action='DESELECT'); head.select_set(True); bpy.context.view_layer.objects.active = head\n"
          "bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)\n"
          "BUMPS = (((-0.5, -0.5, -0.52), 0.1, 0.25), ((0.5, -0.5, -0.52), 0.1, 0.25),       # cheeks, under the blush\n"
          "         ((-0.78, -0.3, -0.5), 0.1, 0.3), ((0.78, -0.3, -0.5), 0.1, 0.3),         # cheeks out (chubby outline)\n"
          "         ((0.0, -0.48, -0.7), 0.025, 0.25))                                         # chin\n"
          "_n = len(head.data.vertices); _co = [0.0] * (3 * _n); _nr = [0.0] * (3 * _n)\n"
          "head.data.vertices.foreach_get('co', _co); head.data.vertices.foreach_get('normal', _nr)\n"
          "for _i in range(0, 3 * _n, 3):\n"
          "    _x, _y, _z = _co[_i:_i + 3]\n"
          "    _d = sum(a * math.exp(-((_x - c[0]) ** 2 + (_y - c[1]) ** 2 + (_z - c[2]) ** 2) / (s * s)) for c, a, s in BUMPS)\n"
          "    _co[_i:_i + 3] = (_x + _nr[_i] * _d, _y + _nr[_i + 1] * _d, _z + _nr[_i + 2] * _d)\n"
          "head.data.vertices.foreach_set('co', _co); head.data.update(); bpy.context.view_layer.update()\n"
          "def face(x, z, off=0.0):\n"
          "    ok, loc, _, _ = head.ray_cast(Vector((x, -3.0, z - HZ)), Vector((0, 1, 0)))\n"
          "    if not ok:\n"
          "        t = 1 - (x / HX) ** 2 - ((z - HZ) / HZR) ** 2\n"
          "        return -HY * math.sqrt(max(t, 0)) - off\n"
          "    return loc.y - off")
    # 2.3 Lash: a soft rounded flick instead of a spike.
    patch("0.012, [1.0, 0.2], m=m)", "0.016, [1.0, 0.75], m=m)")
    # 2.4 Blush: one decal that fades out (soft_blush below) instead of 5 stacked see-through discs,
    #     which render grainy because each disc's transparency is sampled.
    patch("for k, f in enumerate((1.0, 0.82, 0.64, 0.46, 0.3)):   # stacked see-through discs = soft blush\n"
          "        decal(sx * 0.52, EZ - 0.24, 0.15 * f, 0.09 * f, BLUSH, 0.004 + 0.002 * k)",
          "decal(sx * 0.52, EZ - 0.24, 0.17, 0.1, BLUSH, 0.004)")
    # 3.1 Bangs: soft rounded clump tips instead of sharp teeth.
    patch("r, [1.0, 0.85, 0.15]))", "r, [1.0, 0.78, 0.26]))")

sys.argv = [sys.argv[0], '--', OUT, 'none']
g = {'__name__': 'avatar_layers'}
exec(compile(src, SRC, 'exec'), g)
bpy, sc, COLL, HOLD, show_only, render = (g[k] for k in ('bpy', 'sc', 'COLL', 'HOLD', 'show_only', 'render'))
HOLD.setdefault('capproxy', [])     # the cap every hairstyle shares: compose_layers.py keeps hat shadows on it
sc.cycles.samples = SAMPLES
sc.render.resolution_percentage = 100 * SCALE
if BORDER:
    sc.render.use_border = True; sc.render.use_crop_to_border = False
    sc.render.border_min_x, sc.render.border_max_x, sc.render.border_min_y, sc.render.border_max_y = BORDER

TINTED = [g[k] for k in ('W_SKIN', 'W_HAIR', 'W_CLOTH', 'W_SHOE', 'W_WING')]
Vector = g['Vector']
LIGHTS = {tuple(round(v, 2) for v in o.location): o for o in bpy.data.objects if o.type == 'LIGHT'}
# the two lights behind the doll and the one above it: they light the edges
BACK_LIGHTS = [o for o in LIGHTS.values() if o.location.y > 0]
FILL, LEFT_BACK = LIGHTS[(3.5, -4.0, 1.5)], LIGHTS[(-3.2, 2.5, 3.2)]
BG = sc.world.node_tree.nodes['Background']
TODAY = dict(fill=(FILL.data.energy, tuple(FILL.data.color)), left=LEFT_BACK.data.energy,
             world=BG.inputs['Strength'].default_value, exposure=sc.view_settings.exposure)


def lighting(new):
    """1.1 Light with headroom, for the layers the app tints with a ramp: a weaker, cooler fill, less
    ambient, a dimmer left edge light (its crescent down the side of the head and hair clipped), and a
    lower exposure, so lit areas land below 1.0 instead of clipping. Layers drawn as rendered (eyes,
    face, shine, gold, flowers) keep today's light, or they would just come out darker."""
    FILL.data.energy, FILL.data.color = (70, (0.92, 0.94, 1.0)) if new else TODAY['fill']
    LEFT_BACK.data.energy = 450 if new else TODAY['left']
    BG.inputs['Strength'].default_value = 0.3 if new else TODAY['world']
    sc.view_settings.exposure = -1.35 if new else TODAY['exposure']


def bsdf(m): return m.node_tree.nodes['Principled BSDF']


def soft_blush():
    """Blush fades out from its center instead of ending in a hard edge."""
    m = g['BLUSH']; nt = m.node_tree; N = nt.nodes; Lk = nt.links
    bsdf(m).inputs['Alpha'].default_value = 1.0     # the falloff below sets the opacity now
    tc = N.new('ShaderNodeTexCoord')
    sub = N.new('ShaderNodeVectorMath'); sub.operation = 'SUBTRACT'; sub.inputs[1].default_value = (0.5, 0.5, 0.5)
    mul = N.new('ShaderNodeVectorMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = (2, 0, 2)
    ln = N.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
    mr = N.new('ShaderNodeMapRange'); mr.interpolation_type = 'SMOOTHERSTEP'
    mr.inputs['From Min'].default_value = 0.15; mr.inputs['From Max'].default_value = 1.0
    mr.inputs['To Min'].default_value = 0.55; mr.inputs['To Max'].default_value = 0.0
    tr = N.new('ShaderNodeBsdfTransparent'); mix = N.new('ShaderNodeMixShader')
    out = N['Material Output']
    Lk.new(tc.outputs['Generated'], sub.inputs[0]); Lk.new(sub.outputs[0], mul.inputs[0])
    Lk.new(mul.outputs[0], ln.inputs[0]); Lk.new(ln.outputs['Value'], mr.inputs['Value'])
    Lk.new(mr.outputs['Result'], mix.inputs['Fac'])
    Lk.new(tr.outputs[0], mix.inputs[1]); Lk.new(bsdf(m).outputs[0], mix.inputs[2])
    Lk.new(mix.outputs[0], out.inputs['Surface'])


def hair_ring(rotation=0.0, aniso=0.85, rough=0.3, coat=0.12):
    """Gloss stretched around the head, so the highlight reads as one band (the 'angel ring')."""
    m = g['W_HAIR']; N = m.node_tree.nodes; b = bsdf(m)
    t = N.new('ShaderNodeTangent'); t.direction_type = 'RADIAL'; t.axis = 'Z'
    m.node_tree.links.new(t.outputs['Tangent'], b.inputs['Tangent'])
    b.inputs['Anisotropic'].default_value = aniso
    b.inputs['Anisotropic Rotation'].default_value = rotation
    b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = 0.6
    b.inputs['Coat Weight'].default_value = coat     # a sharp coat would add round glints on top of the band


def ring_band(center=0.5, width=0.2):
    """Experimental 'angel ring': light wherever the hair faces a little upward as seen from the camera
    (the up part of its camera-space normal near `center`), faded toward the outline, in the gloss pass
    only. It does make a ring, but on today's voxel-remeshed hair it also shows the remesh's small waves
    as stripes, so it is off unless --ring is given (spec 3.2)."""
    m = g['W_HAIR']; nt = m.node_tree; N = nt.nodes; Lk = nt.links
    geo = N.new('ShaderNodeNewGeometry')
    vt = N.new('ShaderNodeVectorTransform'); vt.vector_type = 'NORMAL'; vt.convert_from = 'WORLD'; vt.convert_to = 'CAMERA'
    sep = N.new('ShaderNodeSeparateXYZ')
    band = N.new('ShaderNodeValToRGB'); band.color_ramp.interpolation = 'EASE'; els = band.color_ramp.elements
    els[0].position, els[0].color = center - width, (0, 0, 0, 1)
    els[1].position, els[1].color = center + width, (0, 0, 0, 1)
    for x in (center - width * 0.3, center + width * 0.3): els.new(x).color = (1, 1, 1, 1)
    lw = N.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.35
    face_on = N.new('ShaderNodeMath'); face_on.operation = 'SUBTRACT'; face_on.inputs[0].default_value = 1.0
    mul = N.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    em = N.new('ShaderNodeEmission'); em.inputs['Strength'].default_value = 0.0
    add = N.new('ShaderNodeAddShader')
    Lk.new(geo.outputs['Normal'], vt.inputs['Vector']); Lk.new(vt.outputs['Vector'], sep.inputs['Vector'])
    Lk.new(sep.outputs['Y'], band.inputs['Fac'])
    Lk.new(lw.outputs['Facing'], face_on.inputs[1])
    Lk.new(band.outputs['Color'], mul.inputs[0]); Lk.new(face_on.outputs['Value'], mul.inputs[1])
    Lk.new(mul.outputs['Value'], em.inputs['Color'])
    Lk.new(bsdf(m).outputs['BSDF'], add.inputs[0]); Lk.new(em.outputs['Emission'], add.inputs[1])
    Lk.new(add.outputs['Shader'], N['Material Output'].inputs['Surface'])
    return em


RING = None
if not ORIGINAL:
    soft_blush()
    hair_ring()
    if RING_STRENGTH: RING = ring_band()

saved = {}


def save_materials():
    for m in TINTED:
        b = bsdf(m)
        saved[m.name] = (tuple(b.inputs['Base Color'].default_value), b.inputs['Subsurface Weight'].default_value,
                         b.inputs['Specular IOR Level'].default_value, b.inputs['Coat Weight'].default_value,
                         b.inputs['Emission Strength'].default_value)


def materials(mode):
    for m in TINTED:
        b = bsdf(m); base, sss, spec, coat, emit = saved[m.name]
        b.inputs['Base Color'].default_value = (0, 0, 0, 1) if mode == 'gloss' else base
        b.inputs['Subsurface Weight'].default_value = 0 if mode == 'gloss' else sss
        b.inputs['Emission Strength'].default_value = 0 if mode == 'gloss' else emit
        b.inputs['Specular IOR Level'].default_value = 0 if mode == 'base' else spec
        b.inputs['Coat Weight'].default_value = 0 if mode == 'base' else coat
    # In the gloss pass the edge lights would draw a bright outline round every item, which reads
    # as a cut-out halo once it is screened on. They still light the base pass.
    for o in BACK_LIGHTS: o.visible_glossy = mode != 'gloss'
    sc.world.cycles_visibility.glossy = mode != 'gloss'     # only the lights make highlights, not the pink sky
    if RING: RING.inputs['Strength'].default_value = RING_STRENGTH if mode == 'gloss' else 0.0


def tinted(layer):
    return any(m in TINTED for o in COLL[layer].objects for m in getattr(o.data, 'materials', []))


def render_layer(w, out=OUT):
    kind, layer = w.split(':') if ':' in w else ('L', w)
    materials('full' if ORIGINAL else ('gloss' if kind == 'G' else 'base'))
    lighting(tinted(layer) and not ORIGINAL)
    show_only(layer, HOLD[layer])
    # see-through pieces (blush, shine) need many samples, or their transparency renders grainy
    sc.cycles.samples = max(SAMPLES, 256) if (layer == 'face' or layer.endswith('_shine')) and not ORIGINAL else SAMPLES
    render(os.path.join(out, ('G_' if kind == 'G' else '') + f'{layer}.png'))
    print('DONE', w, flush=True)


save_materials()
for w in WANT:
    render_layer(w)
