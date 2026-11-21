"""Build the original dappled pony mesh. Requires NumPy, SciPy and scikit-image."""

import math
import struct
from pathlib import Path

import numpy as np
from scipy.interpolate import CubicSpline
from skimage.measure import marching_cubes


OUTPUT = Path(__file__).resolve().parents[2] / 'App/Resources/Games/PonyGrooming/pony.mesh'


def ellipsoid(p, center, axes, tilt=0):
    x, y, z = (a - b for a, b in zip(p, center))
    c, s = math.cos(tilt), math.sin(tilt)
    x, y = c*x + s*y, c*y - s*x
    a, b, c = axes
    return (np.sqrt((x/a)**2 + (y/b)**2 + (z/c)**2) - 1) * min(axes)


def union(a, b, blend):
    if not blend:
        return np.minimum(a, b)
    h = np.maximum(0, blend - np.abs(a - b)) / blend
    return np.minimum(a, b) - h*h*blend*.25


def tube(p, stations, samples=28):
    stations = np.array(stations, dtype=np.float32)
    points = CubicSpline(np.linspace(0, 1, len(stations)), stations)(np.linspace(0, 1, samples))
    out = np.inf
    for a, b in zip(points, points[1:]):
        d = b[:3] - a[:3]
        r = [axis - c for axis, c in zip(p, a)]
        t = np.clip(sum(x*v for x, v in zip(r, d)) / np.dot(d, d), 0, 1)
        distance = np.sqrt(sum((x - t*v)**2 for x, v in zip(r, d)))
        out = np.minimum(out, distance - (a[3] + t*(b[3] - a[3])))
    return out


def legs():
    for side, stagger in ((-.26, -.09), (.27, .08)):
        yield 'fore', .59 + stagger, side
        yield 'hind', -.82 - stagger, side * 1.08


def skin(p):
    shape = ellipsoid(p, (-.18, 1.36, 0), (1.06, .46, .40), -.015)
    # Long lines of the barrel, at the transition between the shoulder and the haunch.
    for center, axes, angle, softness in [
        ((-.93, 1.39, 0), (.43, .44, .38), -.36, .17),
        ((.54, 1.42, 0), (.36, .49, .34), -.33, .20),
        ((.65, 1.76, 0), (.305, .53, .255), -.37, .18),
        ((.89, 2.00, 0), (.232, .37, .203), -.43, .14),
        ((.99, 2.22, 0), (.284, .30, .225), -.52, .12),
        ((1.16, 2.11, 0), (.30, .231, .209), -.67, .11),
        ((1.37, 1.98, 0), (.235, .166, .162), -.65, .075),
        ((1.52, 1.90, 0), (.141, .132, .158), -.34, .065),
        ((1.22, 1.98, 0), (.225, .145, .169), -.43, .08),
    ]:
        shape = union(shape, ellipsoid(p, center, axes, angle), softness)

    for kind, x, z in legs():
        if kind == 'fore':
            line = [(x-.085,1.37,z*.73,.188), (x+.01,1.13,z*.92,.147),
                    (x+.018,.84,z,.116), (x-.018,.52,z,.083), (x+.012,.23,z,.076), (x+.04,.12,z,.098)]
        else:
            line = [(x-.085,1.38,z*.76,.213), (x+.11,1.11,z,.163), (x+.10,.85,z,.116),
                    (x-.135,.56,z,.083), (x-.075,.29,z,.072), (x+.01,.12,z,.092)]
        shape = union(shape, tube(p, line, 22), .11)

    for z in (-.135, .135):
        ear = tube(p, [(.838,2.399,z*.83,.075), (.765,2.56,z*1.44,.068),
                       (.73,2.694,z*1.59,.018)], 22)
        shape = union(shape, ear, .046)
    return shape


def hooves(p):
    out = np.inf
    for kind, x, z in legs():
        x += .084 if kind == 'fore' else .053
        hoof = ellipsoid(p, (x,.091,z), (.132,.135,.119), -.28)
        out = union(out, np.maximum(hoof, .019 - p[1]), 0)
    return out


def horn(p):
    x, y, z = p[0] - 1.04, p[1] - 2.420, p[2]
    axial, across = .38*x + .925*y, .925*x - .38*y
    t = np.clip(axial/.33, 0, 1)
    around = np.arctan2(z, across)
    radius = .068 * (1-t)**.78 + .005
    ridge = .008 * (1-t) * np.power(.5 + .5*np.cos(2*np.pi*3.6*t-around), 5)
    return np.maximum(np.maximum(np.sqrt(across**2+z**2)-radius-ridge, -axial), axial-.33)


def solid_color(rgb):
    return lambda v: np.broadcast_to(rgb, v.shape)


def coat_color(v):
    x, y, z = v.T
    warm = (1 + np.sin(x*5 + y*8 + z*4))*.5
    muzzle = np.clip((x - 1.26)/.39, 0, 1) * np.clip((2.23 - y)/.22, 0, 1)
    legs = np.clip((.66 - y)/.66, 0, 1)
    c = np.column_stack((.96 + warm*.034, .823 + warm*.058, .642 + warm*.085))
    c *= (1 - muzzle*.20 - legs*.135)[:, None]
    # Small, soft rings broken up by position on the coat, mostly on the barrel and haunch.
    rng = np.random.default_rng(4186)
    dapple = np.zeros(len(v))
    for side in (-1, 1):
        for _ in range(60):
            cx = rng.uniform(-1.19,.44)
            cy = rng.uniform(1.17,1.78)
            center = (cx, cy, side * rng.uniform(.24,.48))
            radius = rng.uniform(.033,.081)
            d = np.linalg.norm(v - center, axis=1) / radius
            dapple = np.maximum(dapple, np.exp(-((d-.40)/.50)**2)*rng.uniform(.10,.31))
    c += (1-c)*dapple[:, None]*2.2
    return c


def mesh(field, low, high, pitch, color):
    axes = [np.arange(a, b + pitch, pitch, dtype=np.float32) for a, b in zip(low, high)]
    samples = np.meshgrid(*axes, sparse=True, indexing='ij')
    xyz, faces, normals, _ = marching_cubes(field(samples).astype(np.float32), 0, spacing=(pitch,)*3, allow_degenerate=False)
    xyz += np.asarray(low)
    normals *= -1
    tris = xyz[faces[:1200]]
    cross = np.cross(tris[:,1]-tris[:,0], tris[:,2]-tris[:,0])
    if np.sum(cross*normals[faces[:1200,0]]) < 0:
        faces = faces[:,[0,2,1]]
    return np.column_stack((xyz, normals, color(xyz))).astype('<f4'), faces.astype('<u4')


def build():
    parts = [
        ('coat', skin, (-1.42,.005,-.57), (1.73,2.76,.57), .018, coat_color),
        ('hooves', hooves, (-1.12,.003,-.48), (.94,.23,.48), .013, solid_color((.42,.31,.275))),
        ('horn', horn, (.94,2.38,-.10), (1.22,2.76,.10), .008, solid_color((.95,.67,.31))),
    ]
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open('wb') as f:
        f.write(struct.pack('<4sI', b'PNY1', len(parts)))
        for name, field, low, high, pitch, color in parts:
            vertices, triangles = mesh(field, low, high, pitch, color)
            f.write(struct.pack('<16sII', name.encode('ascii'), len(vertices), triangles.size))
            f.write(vertices.tobytes())
            f.write(triangles.tobytes())
            print(f'{name}: {len(vertices):,} vertices, {len(triangles):,} faces')


if __name__ == '__main__':
    build()
