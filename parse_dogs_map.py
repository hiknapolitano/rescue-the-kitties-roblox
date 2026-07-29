import sys
from PIL import Image

try:
    img = Image.open('maps/dogsMapping.png')
    img = img.convert('RGBA')

    color_map = {
        '#300631': 1, # Dog
        '#000000': 2, # Dog barrier
    }

    width, height = img.size
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                row.append(0)
            else:
                hex_val = '#{:02x}{:02x}{:02x}'.format(r, g, b).lower()
                if hex_val in color_map:
                    row.append(color_map[hex_val])
                else:
                    row.append(0) # fallback
        rows.append(row)

    lua_table = "return {\n"
    for row in rows:
        lua_table += "    {" + ", ".join(str(v) for v in row) + "},\n"
    lua_table += "}\n"

    with open("src/shared/dogsMapLayout.lua", "w") as f:
        f.write(lua_table)
    print(f"Parsed dogs mapping ({width}x{height})")
except Exception as e:
    print("Error:", e)
