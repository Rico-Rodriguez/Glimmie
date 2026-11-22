"""Build the original dappled pony mesh. Requires NumPy, SciPy and scikit-image."""

import math
import struct
from pathlib import Path

import numpy as np
from scipy.interpolate import CubicSpline
from scipy.ndimage import gaussian_filter
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
        length2 = np.dot(d, d)
        rate = b[3] - a[3]
        projection = sum(x*v for x, v in zip(r, d)) / length2
        normal2 = np.maximum(0, sum(x*x for x in r) - projection*projection*length2)
        shift = rate * np.sqrt(normal2 / max(length2*(length2-rate*rate), 1e-10))
        t = np.clip(projection + shift, 0, 1)
        distance = np.sqrt(sum((x - t*v)**2 for x, v in zip(r, d)))
        out = np.minimum(out, distance - (a[3] + t*(b[3] - a[3])))
    return out


def legs():
    for side, fore, hind in ((-.25, .43, -.94), (.28, .68, -.73)):
        yield 'fore', fore, side
        yield 'hind', hind, side * 1.07


def skin(p):
    shape = ellipsoid(p, (-.19, 1.38, 0), (1.05, .462, .411), -.027)
    for center, axes, angle, softness in [
        ((-.95, 1.44, 0), (.425, .455, .391), -.31, .18),
        ((.52, 1.43, 0), (.39, .47, .35), -.32, .21),
        ((.63, 1.71, 0), (.31, .51, .263), -.36, .18),
        ((.86, 2.00, 0), (.242, .38, .211), -.41, .14),
        ((.99, 2.21, 0), (.276, .292, .224), -.42, .13),
        ((1.075, 2.094, 0), (.267, .252, .211), -.46, .14),
        ((1.32, 1.963, 0), (.246, .159, .162), -.60, .09),
        ((1.496, 1.86, 0), (.132, .134, .158), -.32, .075),
        ((1.197, 1.939, 0), (.208, .136, .173), -.46, .09),
    ]:
        shape = union(shape, ellipsoid(p, center, axes, angle), softness)

    for kind, x, z in legs():
        if kind == 'fore':
            line = [(x-.10,1.40,z*.73,.206), (x+.005,1.16,z*.92,.153),
                    (x+.024,.89,z,.104), (x+.014,.65,z,.092), (x+.003,.44,z,.072),
                    (x+.017,.245,z,.079), (x+.047,.135,z,.090)]
        else:
            line = [(x-.068,1.42,z*.76,.225), (x+.10,1.18,z*.91,.181),
                    (x+.157,.975,z,.124), (x+.053,.775,z,.104), (x-.082,.604,z,.091),
                    (x-.041,.365,z,.071), (x+.016,.212,z,.076), (x+.048,.133,z,.087)]
        shape = union(shape, tube(p, line, 22), .11)
        # The feathering widens toward the coronet and overlaps the hoof like real hair.
        for i in range(6):
            theta = i * math.tau / 6
            dz, dx = math.sin(theta), math.cos(theta)
            feather = ellipsoid(p, (x+.036+dx*.054, .172+(i%2)*.016, z+dz*.056),
                                (.053, .096, .051), -.25)
            shape = union(shape, feather, .026)

    for side in (-1, 1):
        z = side * .135
        tilt = .022 if side < 0 else 0
        ear = ellipsoid(p, (.802-tilt, 2.533, z*1.35), (.058, .151, .072), .34)
        shape = union(shape, ear, .07)
        inner = ellipsoid(p, (.837-tilt, 2.55, z*1.4), (.029, .111, .049), .34)
        shape = -union(-shape, inner, .018)
        nostril = ellipsoid(p, (1.582, 1.893, side*.121), (.043, .026, .029), -.37)
        shape = -union(-shape, nostril, .013)
    return shape


def hooves(p):
    out = np.inf
    for kind, x, z in legs():
        x += .064 if kind == 'fore' else .062
        dx, y, dz = p[0] - x, p[1], p[2] - z
        taper = 1 + (.091 - y) * 1.8
        toe = (dx + (y - .085) * .27) / (.114 * taper)
        flank = dz / (.095 * taper)
        rise = (y - .086) / .091
        hoof = (np.power(abs(toe)**2.6 + abs(flank)**2.6 + abs(rise)**3, 1/2.6) - 1) * .091
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
    warm = (.5 + np.sin(x*3.3 + y*5 + z*2.5)*.26 + np.sin(x*12-y*8+z*17)*.068)
    fine = (np.sin(x*117 + y*26 + z*109) + np.sin(x*157 - y*47 + z*143))*.011
    muzzle = np.clip((x - 1.29)/.28, 0, 1) * np.clip((2.13 - y)/.18, 0, 1)
    c = np.column_stack((.88 + warm*.111, .684 + warm*.145, .506 + warm*.183))
    c += fine[:, None]
    c += (np.array((.49,.36,.29))-c) * muzzle[:, None] * .71
    stockings = np.clip((.50-y)/.29, 0, 1)
    c += (np.array((.996,.922,.780))-c) * stockings[:, None] * .89
    side = np.abs(z)
    lip_y = 1.805 + (1.53 - x) * .30
    lip = np.exp(-((lip_y-y)/.012)**2) * np.exp(-((x-1.51)/.125)**4)
    lip *= np.clip((side-.076)*15, 0, 1)
    inner_ear = np.exp(-((x-.842)/.034)**2 - ((y-2.552)/.071)**2)
    inner_ear *= np.clip((side-.125)*18, 0, 1)
    c *= (1-lip*.31)[:, None]
    c += (np.array((.76,.49,.43))-c)*inner_ear[:, None]*.82
    blaze = np.exp(-(z/.091)**2) * np.clip((x-.94)*7,0,1) * np.clip((y-1.96)*8,0,1)
    c += (np.array((1.,.95,.84))-c) * blaze[:, None] * .61
    eye = np.exp(-((x-1.066)/.11)**2 - ((y-2.235)/.07)**2) * np.clip((side-.14)*12,0,1)
    c -= eye[:, None] * (.07,.084,.076)
    throat = np.exp(-((x-.82)/.21)**2 - ((y-1.72)/.38)**2) * np.clip((.23-side)*3,0,1)
    underside = np.clip((1.32-y)*4, 0, 1) * np.exp(-((x+.26)/.62)**4) * (1-stockings)
    c -= (throat * .82 + underside * .37)[:, None] * (.089,.105,.112)
    feather_streaks = (np.sin(x*181 + y*14 + z*223)*.6 + np.sin(x*261-z*95)*.4) * stockings
    c += feather_streaks[:, None] * (.013,.017,.025)
    # Small, soft rings broken up by position on the coat, mostly on the barrel and haunch.
    rng = np.random.default_rng(4186)
    dapple = np.zeros(len(v))
    for side in (-1, 1):
        for _ in range(60):
            cx = rng.uniform(-1.19,.44)
            cy = rng.uniform(1.17,1.78)
            center = (cx, cy, side * rng.uniform(.24,.48))
            radius = rng.uniform(.032,.082)
            d = np.linalg.norm((v - center)*(.83, 1.06, .91), axis=1) / radius
            d += np.sin(x*59+y*38+z*29)*.17
            dapple = np.maximum(dapple, np.exp(-((d-.40)/.50)**2)*rng.uniform(.11,.37))
    c += (1-c)*dapple[:, None]*1.58
    return np.clip(c, 0, 1)


def hoof_color(v):
    x, y, z = v.T
    lines = .025 * np.sin(x*74 + y*6 + z*86) + .015 * np.sin(y*89 + x*9)
    return np.column_stack((.47+lines, .36+lines, .292+lines))


def mesh(field, low, high, pitch, color):
    axes = [np.arange(a, b + pitch, pitch, dtype=np.float32) for a, b in zip(low, high)]
    samples = np.meshgrid(*axes, sparse=True, indexing='ij')
    values = gaussian_filter(field(samples).astype(np.float32), sigma=.65)
    xyz, faces, normals, _ = marching_cubes(values, 0, spacing=(pitch,)*3, allow_degenerate=False)
    xyz += np.asarray(low)
    normals *= -1
    tris = xyz[faces[:1200]]
    cross = np.cross(tris[:,1]-tris[:,0], tris[:,2]-tris[:,0])
    if np.sum(cross*normals[faces[:1200,0]]) < 0:
        faces = faces[:,[0,2,1]]
    return np.column_stack((xyz, normals, color(xyz))).astype('<f4'), faces.astype('<u4')


def build():
    parts = [
        ('coat', skin, (-1.44,.005,-.57), (1.72,2.76,.57), .016, coat_color),
        ('hooves', hooves, (-1.14,.003,-.48), (.99,.22,.48), .010, hoof_color),
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
