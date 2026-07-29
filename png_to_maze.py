import sys
import os
import glob
import random
import math

try:
    from PIL import Image
except ImportError:
    print("Please install Pillow by running: pip install Pillow")
    sys.exit(1)

def color_distance(c1, c2):
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))

def parse_maze(image_path):
    img = Image.open(image_path).convert('RGBA')
    w, h = img.size
    grid = [[0 for _ in range(w)] for _ in range(h)]
    
    color_map = {
        (32, 156, 96): 6,    # Safe base
        (0, 0, 0): 1,        # Wall
        (255, 255, 255): 0,  # Path (fallback)
        (0, 98, 255): 3,     # Kitty
        (226, 227, 0): 2,    # Tree
        (229, 255, 0): 2,    # Tree
        (195, 0, 255): 7,    # Shop
    }
    
    kitties = []
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                grid[y][x] = 0
                continue
                
            pixel = (r, g, b)
            best_color = 0
            best_dist = float('inf')
            for c, val in color_map.items():
                dist = color_distance(pixel, c)
                if dist < best_dist:
                    best_dist = dist
                    best_color = val
            
            grid[y][x] = best_color
            if best_color == 3:
                kitties.append((x, y))
                
    if len(kitties) >= 3:
        chosen_kitties = random.sample(kitties, 3)
    else:
        chosen_kitties = kitties
        
    for kx, ky in chosen_kitties:
        placed = False
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if 0 <= ky+dy < h and 0 <= kx+dx < w:
                    if grid[ky+dy][kx+dx] == 0:
                        grid[ky+dy][kx+dx] = 4
                        placed = True
                        break
            if placed: break

    placed_exit = False
    for y in range(h-1, -1, -1):
        for x in range(w-1, -1, -1):
            if grid[y][x] == 0:
                grid[y][x] = 5
                placed_exit = True
                break
        if placed_exit: break

    return grid

def generate_maps_module():
    maps_dir = "maps"
    output_file = "src/shared/Maps.lua"
    
    if not os.path.exists(maps_dir):
        print(f"Directory {maps_dir} does not exist.")
        sys.exit(1)
        
    png_files = glob.glob(os.path.join(maps_dir, "*.png"))
    if not png_files:
        print(f"No PNG files found in {maps_dir}.")
        sys.exit(1)
        
    lua_str = "local Maps = {}\n\n"
    
    for png in png_files:
        filename = os.path.basename(png)
        map_name = os.path.splitext(filename)[0]
        
        grid = parse_maze(png)
        h = len(grid)
        
        lua_str += f"Maps['{map_name}'] = {{\n"
        for y in range(h):
            row_str = "    {" + ", ".join(str(cell) for cell in grid[y]) + "},"
            lua_str += row_str + "\n"
        lua_str += "}\n\n"
        
    lua_str += "return Maps\n"
    
    with open(output_file, "w") as f:
        f.write(lua_str)
        
    print(f"Successfully generated {output_file} from {len(png_files)} map(s)!")

if __name__ == "__main__":
    generate_maps_module()
