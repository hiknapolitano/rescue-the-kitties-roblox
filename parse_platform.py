import sys
from PIL import Image

img = Image.open('maps/platformMapping.png')
img = img.convert('RGBA')

width, height = img.size
rows = []
for y in range(height):
    row = []
    for x in range(width):
        r, g, b, a = img.getpixel((x, y))
        # If it's mostly black, it's a platform (1)
        if a > 128 and r < 50 and g < 50 and b < 50:
            row.append(1)
        else:
            row.append(0)
    rows.append(row)

lua_table = "return {\n"
for row in rows:
    lua_table += "    {" + ", ".join(str(v) for v in row) + "},\n"
lua_table += "}\n"

with open("src/shared/platformMapping.lua", "w") as f:
    f.write(lua_table)
print("Parsed platform mapping")
