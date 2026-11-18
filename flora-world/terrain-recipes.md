# Terrain recipes — the Luau that replaces box fields

Everything here runs through the Studio MCP:

```jsonc
{ "tool": "execute_luau", "arguments": { "datamodel_type": "Edit", "code": "<the snippet>" } }
```

**Rule:** terrain calls are *bulk* operations. 60 well-placed brushes beat 600 parts, look better, and cost the server nothing because terrain is voxel-based and streamed by the engine.

---

## 0. Setup: clear and verify

```lua
--!strict
local Terrain = workspace.Terrain

-- Wipe a region before rebuilding it (do this in a test place, never on a live world)
Terrain:Clear()
print("terrain cleared, voxel count:", 0)
```

Verify what you built:

```lua
--!strict
local Terrain = workspace.Terrain
local region = Region3.new(Vector3.new(-400, -50, -400), Vector3.new(400, 200, 400))
local materials: { [Enum.Material]: number } = {}
local voxels = Terrain:ReadVoxels(region, 4)
for x = 1, voxels.Size.X do
	for y = 1, voxels.Size.Y do
		for z = 1, voxels.Size.Z do
			local m = voxels[x][y][z]
			if m ~= Enum.Material.Air then
				materials[m] = (materials[m] or 0) + 1
			end
		end
	end
end
local count = 0
for material, n in materials do
	count += 1
	print(material.Name, n)
end
print("DISTINCT MATERIALS:", count)   -- must be >= 6 for a finished region
```

---

## 1. The one helper you actually need

`Terrain:FillBall` and `Terrain:FillBlock` are blunt. Wrapping them in a "shape" function is what lets you sculpt rather than stack.

```lua
--!strict
-- TerrainKit.lua — put in ServerScriptService/Tools, require it from build scripts
local Terrain = workspace.Terrain

local kit = {}

-- A soft mound: one big ball, one smaller on top, one offset, blended
function kit.hill(center: Vector3, radius: number, material: Enum.Material, seed: number?)
	local rng = Random.new(seed or 1)
	Terrain:FillBall(center, radius, material)
	for i = 1, 3 do
		local offset = Vector3.new(
			rng:NextNumber(-radius * 0.45, radius * 0.45),
			rng:NextNumber(-radius * 0.15, radius * 0.25),
			rng:NextNumber(-radius * 0.45, radius * 0.45)
		)
		Terrain:FillBall(center + offset, radius * rng:NextNumber(0.55, 0.8), material)
	end
end

-- A ridge: a chain of balls along a direction, shrinking toward the ends
function kit.ridge(start: Vector3, finish: Vector3, height: number, width: number, material: Enum.Material)
	local steps = math.max(8, math.floor((finish - start).Magnitude / 24))
	for i = 0, steps do
		local t = i / steps
		local p = start:Lerp(finish, t)
		-- taper the ends so the ridge doesn't look like a sausage
		local taper = math.sin(t * math.pi) ^ 0.6
		p = Vector3.new(p.X, start.Y + height * taper * 0.55, p.Z)
		Terrain:FillBall(p, width * (0.55 + 0.45 * taper), material)
	end
end

-- A hollow / basin: subtract a ball from the surface
function kit.hollow(center: Vector3, radius: number)
	Terrain:FillBall(center, radius, Enum.Material.Air)
end

-- A cliff face: fill a block then carve back the front so it isn't a wall
function kit.cliff(base: Vector3, size: Vector3, faceDirection: number, material: Enum.Material, seed: number?)
	local rng = Random.new(seed or 7)
	Terrain:FillBlock(CFrame.new(base + size / 2), size, material)
	-- carve 12 random bites out of the front face for a natural edge
	for i = 1, 12 do
		local bite = Vector3.new(
			base.X + rng:NextNumber(0, size.X),
			base.Y + rng:NextNumber(size.Y * 0.15, size.Y * 0.95),
			base.Z + faceDirection * size.Z * 0.5
		)
		Terrain:FillBall(bite, rng:NextNumber(6, 18), Enum.Material.Air)
	end
end

-- A cave: carve a tunnel between two points
function kit.cave(from: Vector3, to: Vector3, radius: number)
	local steps = math.max(6, math.floor((to - from).Magnitude / 12))
	for i = 0, steps do
		local p = from:Lerp(to, i / steps)
		Terrain:FillBall(p, radius * (0.85 + 0.15 * math.sin(i)), Enum.Material.Air)
	end
end

-- Water in a basin: lower the floor, then fill
function kit.lake(center: Vector3, radius: number, depth: number)
	Terrain:FillBall(center, radius, Enum.Material.Air)
	Terrain:FillBall(Vector3.new(center.X, center.Y - depth * 0.55, center.Z), radius * 0.95, Enum.Material.Ground)
	Terrain:FillBlock(
		CFrame.new(center.X, center.Y - depth * 0.2, center.Z),
		Vector3.new(radius * 1.9, depth * 0.4, radius * 1.9),
		Enum.Material.Water
	)
end

return kit
```

---

## 2. Build the Auralis macro-shape (a real 15-minute build)

This is a working starting shape, not a finished region. Run it, screenshot it, then refine.

```lua
--!strict
local Kit = require(game.ServerScriptService.Tools.TerrainKit)
local Terrain = workspace.Terrain

Terrain:Clear()

-- base meadow: one big flat-ish plateau
Terrain:FillBlock(
	CFrame.new(0, -12, 0),
	Vector3.new(900, 24, 900),
	Enum.Material.Grass
)

-- the ridge that gives the world its silhouette (runs east-west, north side)
Kit.ridge(Vector3.new(-320, 10, -190), Vector3.new(320, 10, -150), 90, 55, Enum.Material.Rock)

-- a secondary rise behind the landmark
Kit.hill(Vector3.new(210, 4, -230), 70, Enum.Material.Rock, 11)

-- the hollow (wind bowl), centre of the map
Kit.hollow(Vector3.new(-40, 8, 40), 75)

-- water edge on the south-west
Kit.lake(Vector3.new(-260, 2, 210), 110, 26)

-- the buried meadow: a cave under the east rise
Kit.cave(Vector3.new(150, -18, -120), Vector3.new(240, -8, -60), 16)

-- soften every hard edge the fills left behind
for i = 1, 60 do
	local rng = Random.new(i * 31)
	local p = Vector3.new(rng:NextNumber(-380, 380), rng:NextNumber(-30, 60), rng:NextNumber(-380, 380))
	Terrain:FillBall(p, rng:NextNumber(4, 14), Enum.Material.Grass)
end

print("macro shape built")
```

**Then immediately:** `screen_capture` from `(0, 90, 380)` looking at `(0, 20, 0)`.
If the silhouette isn't readable in that shot, the shape is wrong — not the props. Fix the shape.

---

## 3. Materials — the 6-material pass

Never leave a region on one colour. Paint by **height and slope**, which is how real ground works.

```lua
--!strict
local Terrain = workspace.Terrain
local THEME = require(game.ReplicatedStorage.Shared.Config.VisualThemes).auralis

-- theme.terrain is [[material, hex], ...] from visual_themes.json
for _, entry in THEME.terrain do
	Terrain:SetMaterialColor(Enum.Material[entry.material], Color3.fromHex(entry.color))
	print("painted", entry.material, entry.color)
end

-- patch pass: lay down 6 material zones with overlapping balls
local PATCHES = {
	{ center = Vector3.new(0, 6, 0),     r = 260, material = Enum.Material.Grass },
	{ center = Vector3.new(-260, 2, 210), r = 150, material = Enum.Material.Sand },   -- shoreline
	{ center = Vector3.new(-260, -8, 210), r = 120, material = Enum.Material.Mud },   -- lake bed
	{ center = Vector3.new(-40, 5, 40),  r = 90,  material = Enum.Material.Mud },     -- hollow floor
	{ center = Vector3.new(-320, 30, -170), r = 120, material = Enum.Material.Rock }, -- ridge face
	{ center = Vector3.new(120, 3, 120), r = 140, material = Enum.Material.LeafyGrass },
}

for _, p in PATCHES do
	Terrain:FillBall(p.center, p.r, p.material)
	print("patch", p.material.Name, p.center)
end
```

**Check:** the `ReadVoxels` verifier from §0 must print `DISTINCT MATERIALS: >= 6`.

---

## 4. What "don't do this" looks like

```lua
-- ❌ THE AGENT DEFAULT — this is why it looks bad
for i = 1, 400 do
	local rock = Instance.new("Part")
	rock.Size = Vector3.new(math.random(8, 20), math.random(8, 20), math.random(8, 20))
	rock.Position = Vector3.new(math.random(-400, 400), 0, math.random(-400, 400))
	rock.Material = Enum.Material.Slate
	rock.Color = Color3.fromRGB(120, 120, 120)   -- one tint for all
	rock.Anchored = true
	rock.Parent = workspace
end
```

Why it fails, in order of damage:
1. **Cubes have flat tops and 90° edges.** Rock in nature has none. The eye reads "block" instantly.
2. **One colour for all 400.** No variance = a texture-less mass.
3. **`math.random` everywhere with no logic.** Real terrain accumulates *near* features (slopes, water, wind), never uniformly across a square.
4. **400 parts** costs more than a terrain shape and looks worse.
5. **No silhouette.** From a distance, a cube field reads as a flat plane with noise.

The terrain version of the same idea:

```lua
-- ✅ terrain rocks read as landscape
local Kit = require(game.ServerScriptService.Tools.TerrainKit)
Kit.ridge(Vector3.new(-320, 10, -190), Vector3.new(320, 10, -150), 90, 55, Enum.Material.Rock)
for i = 1, 18 do
	local rng = Random.new(i)
	-- boulders hug the ridge base, not the whole map
	local x = rng:NextNumber(-300, 300)
	local z = -170 + rng:NextNumber(-40, 40)
	Kit.hill(Vector3.new(x, 8, z), rng:NextNumber(8, 22), Enum.Material.Rock, i)
end
```

Then the *props* on top are sourced assets (see `kitbash.md`), not invented geometry.

---

## 5. Performance notes for terrain

| Rule | Number | Why |
|---|---|---|
| Total terrain voxels | keep the playable region under ~2M voxels | the engine streams it; more means mobile stutter |
| Water | one basin, not five ponds | water rendering is the most expensive terrain feature |
| Cave depth | ≤ 60 studs below surface | deeper caves need extra streaming and rare lighting |
| Terrain seams | overlap fills by 6+ studs | gaps between fills become visible holes at distance |
| `Terrain:Clear()` | only in test places | it destroys the whole world instantly |

## 6. Terrain + server

Terrain edits from a **client** do not replicate. Build scripts run on the server (`datamodel_type: "Edit"` in the MCP), which is correct — but never let a player's client sculpt terrain at runtime in FLORA; that's how you get griefed worlds. If scanning needs to "grow" something, do it with a model swap, not terrain.
