import random

W = 40
H = 40
grid = [[1 for _ in range(W)] for _ in range(H)]

# Carve rooms
rooms = []
# Lobby
for y in range(2, 7):
    for x in range(2, 7):
        grid[y][x] = 0
grid[4][4] = 6 # Spawn
rooms.append((4,4))

for _ in range(15):
    rw = random.randint(3, 7)
    rh = random.randint(3, 7)
    rx = random.randint(2, W - rw - 2)
    ry = random.randint(2, H - rh - 2)
    for y in range(ry, ry + rh):
        for x in range(rx, rx + rw):
            grid[y][x] = 0
    rooms.append((rx + rw//2, ry + rh//2))

# Connect rooms with corridors
for i in range(len(rooms)-1):
    x1, y1 = rooms[i]
    x2, y2 = rooms[i+1]
    
    # Carve L-shape
    if random.choice([True, False]):
        # Horizontal then vertical
        for x in range(min(x1, x2), max(x1, x2) + 1):
            grid[y1][x] = 0
            if y1+1 < H: grid[y1+1][x] = 0 # 2-wide
        for y in range(min(y1, y2), max(y1, y2) + 1):
            grid[y][x2] = 0
            if x2+1 < W: grid[y][x2+1] = 0
    else:
        for y in range(min(y1, y2), max(y1, y2) + 1):
            grid[y][x1] = 0
            if x1+1 < W: grid[y][x1+1] = 0
        for x in range(min(x1, x2), max(x1, x2) + 1):
            grid[y2][x] = 0
            if y2+1 < H: grid[y2+1][x] = 0

# Add extra random corridors
for _ in range(10):
    x = random.randint(2, W-3)
    y = random.randint(2, H-3)
    length = random.randint(5, 15)
    if random.choice([True, False]):
        for i in range(length):
            if x+i < W-1: grid[y][x+i] = 0
    else:
        for i in range(length):
            if y+i < H-1: grid[y+i][x] = 0

# Place 9 cats (3), 3 dogs (4), 1 exit (5), and 15 trees (2)
empty = [(x,y) for y in range(2, H-2) for x in range(2, W-2) if grid[y][x] == 0]
random.shuffle(empty)

for _ in range(9):
    cx, cy = empty.pop()
    grid[cy][cx] = 3
for _ in range(3):
    dx, dy = empty.pop()
    grid[dy][dx] = 4
ex, ey = empty.pop()
grid[ey][ex] = 5
for _ in range(15):
    tx, ty = empty.pop()
    grid[ty][tx] = 2

lua_str = "local layout = {\n"
for y in range(H):
    row_str = "    {" + ", ".join(str(cell) for cell in grid[y]) + "},"
    lua_str += row_str + "\n"
lua_str += "}"
with open("layout.lua", "w") as f:
    f.write(lua_str)
