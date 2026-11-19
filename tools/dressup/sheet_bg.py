import sys
from render import doll_svg, png, shapes_svg
from sheet import grid
import backgrounds
SP = sys.argv[1]
paths = []
for i, b in enumerate(backgrounds.all_bgs()):
    o, d = shapes_svg(b['layers'][0]['shapes'], {}, i)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900"><defs>{"".join(d)}</defs>{"".join(o)}</svg>'
    p = f'{SP}/bg{i}.png'; png(svg, p); paths.append(p)
grid(paths, f'{SP}/bgs.png', cols=4, scale=0.3)
