import sys
import math
from PIL import Image

def hex_to_rgb(hx):
    hx = hx.lstrip('#')
    return tuple(int(hx[i:i+2], 16) for i in (0, 2, 4))

def color_distance(c1, c2):
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))

img = Image.open('maps/complexMapV2.png')
img = img.convert('RGBA')

color_map = {
    '#000000': 1, # Wall
    '#596f13': 6, # SZ1
    '#064545': 8, # SZ2
    '#00ffff': 3, # Cat Spawn
    '#0056ff': 10, # Blue Door
    '#679bff': 11, # Blue Key
    '#fbff00': 12, # Yellow Door
    '#fdff6b': 13, # Yellow Key
    '#ff0000': 14, # Red Door
    '#ff5858': 15, # Red Key
    '#a100ff': 16, # Purple Door
    '#cf7cff': 17, # Purple Key
    '#00ff07': 18, # Green Door
    '#92ff95': 19, # Green Key
    '#8e0058': 20, # Final Door
    '#906c3b': 21, # FireTree
    '#687836': 22, # Shop
    '#5e431e': 23, # Tree
    '#919485': 24, # LavaObby
    '#585a4e': 25, # JustLava
    '#0d0056': 26, # WaterTile
    '#b4aed2': 27, # Boat
    '#ab6275': 28, # SpikeTile
}

# Convert color_map to RGB
rgb_map = {hex_to_rgb(k): v for k, v in color_map.items()}

width, height = img.size
rows = []
for y in range(height):
    row = []
    for x in range(width):
        r, g, b, a = img.getpixel((x, y))
        if a < 128:
            row.append(0)
        else:
            pixel = (r, g, b)
            if pixel in rgb_map:
                row.append(rgb_map[pixel])
            else:
                row.append(0)
    rows.append(row)

lua_table = "return {\n"
for row in rows:
    lua_table += "    {" + ", ".join(str(v) for v in row) + "},\n"
lua_table += "}\n"

with open("src/shared/complexMapLayout.lua", "w") as f:
    f.write(lua_table)
print(f"Parsed complex map V2 ({width}x{height})")
