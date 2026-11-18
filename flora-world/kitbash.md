# Kitbash — how an agent gets from "primitives" to "a place"

The single biggest jump in visual quality available to an agent is not better code. It's **placing good assets instead of modelling bad ones.** An agent that models a tree produces a brown cylinder with a green sphere. An agent that inserts a Creator Store tree and scatters 200 of them at varied scales produces a forest.

---

## 1. Source, then place

```jsonc
// find candidates
{ "tool": "search_asset", "arguments": {
    "query": "low poly tree pine stylized",
    "assetType": "Model",
    "scope": "CreatorStore",
    "tags": ["nature"]
} }

// insert one to inspect it before scattering
{ "tool": "insert_asset", "arguments": { "assetId": 123456789, "parent": "Workspace.KitSource.Trees" } }

// look at it
{ "tool": "screen_capture", "arguments": { "position": [0, 20, -40], "lookAt": [0, 10, 0] } }

// verify the parts inside
{ "tool": "inspect_instance", "arguments": { "path": "Workspace.KitSource.Trees.AssetName" } }
```

**Inspect before you scatter.** Free/Store models routinely arrive:
- unanchored (they fall over or explode on spawn),
- at the wrong scale (a 2-stud tree or a 200-stud bush),
- with 12,000-triangle meshes (mobile killer),
- with scripts inside (griefing risk — delete them),
- with 40 children when you need one welded mesh.

```lua
--!strict
-- Sanitise a kit asset once, then clone the sanitised version
local function sanitise(model: Model, targetHeight: number)
	local size = model:GetExtentsSize()
	local scale = targetHeight / size.Y
	model:ScaleTo(scale)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false   -- props are decoration; collision is terrain
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()            -- never run third-party code
		end
	end
	model:PivotTo(CFrame.new(0, -500, 0))   -- park it off-world as a source
	print(model.Name, "scale", scale, "children", #model:GetChildren())
end
```

Store sanitised sources in `ServerStorage.Kit` so a rebuild never re-inserts junk.

---

## 2. The scatter function (with the variance that fixes "machine-made")

The reason agent worlds look synthetic is **uniformity**. This one function fixes it, and it's the highest-value 40 lines in this folder.

```lua
--!strict
-- Kitbash.lua
local Kitbash = {}

export type ScatterOptions = {
	count: number,
	radius: number,
	centre: Vector3,
	minScale: number,
	maxScale: number,
	maxTiltDegrees: number,
	maxYawDegrees: number,
	minSpacing: number,
	densityFalloff: boolean?,   -- thinner toward the edge of the radius
	tintVariance: number?,      -- ± fraction on value, default 0.06
	seed: number?,
}

function Kitbash.scatter(source: Model, parent: Instance, opts: ScatterOptions): number
	local rng = Random.new(opts.seed or os.clock() * 1000)
	local placed: { Vector3 } = {}
	local attempts = 0
	local maxAttempts = opts.count * 12
	local tintVariance = opts.tintVariance or 0.06

	while #placed < opts.count and attempts < maxAttempts do
		attempts += 1

		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(0, 1)) * opts.radius
		if opts.densityFalloff then
			distance = rng:NextNumber(0, 1) ^ 0.65 * opts.radius   -- clump toward centre
		end
		local position = opts.centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)

		-- spacing check: no two props closer than minSpacing
		local tooClose = false
		for _, existing in placed do
			if (existing - position).Magnitude < opts.minSpacing then
				tooClose = true
				break
			end
		end
		if tooClose then
			continue
		end

		-- ground them: raycast down so nothing floats
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { parent }
		local hit = workspace:Raycast(position + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
		local y = hit and hit.Position.Y or position.Y

		local clone = source:Clone()
		local scale = rng:NextNumber(opts.minScale, opts.maxScale)
		clone:ScaleTo(scale)

		local tilt = CFrame.Angles(
			math.rad(rng:NextNumber(-opts.maxTiltDegrees, opts.maxTiltDegrees)),
			math.rad(rng:NextNumber(0, opts.maxYawDegrees)),
			math.rad(rng:NextNumber(-opts.maxTiltDegrees, opts.maxTiltDegrees))
		)
		clone:PivotTo(CFrame.new(position.X, y, position.Z) * tilt)
		clone.Parent = parent

		-- tint variance: the difference between a forest and a copy-paste
		local shift = 1 + rng:NextNumber(-tintVariance, tintVariance)
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				local h, s, v = Color3.toHSV(part.Color)
				part.Color = Color3.fromHSV(h, s, math.clamp(v * shift, 0, 1))
			end
		end

		table.insert(placed, position)
	end

	return #placed
end

return Kitbash
```

**Why each number matters:**

| Parameter | Value | Effect if omitted |
|---|---|---|
| `minScale`/`maxScale` | **0.7–1.6** | every tree identical → wallpaper |
| `maxYawDegrees` | **360** | rows of trees facing the same way |
| `maxTiltDegrees` | **8–14** | nothing in nature stands perfectly upright |
| `minSpacing` | 0.55 × prop width | props intersect, look like a single blob |
| `densityFalloff` | on for groves | even density reads as a grid |
| `tintVariance` | **0.06** | one colour for 200 props = a flat mass |
| raycast grounding | always | floating props are the #1 tell of an unlooked-at build |

---

## 3. The 3-5-1 composition rule

Scatter alone is noise. Composition is the difference between "a field" and "a place". Every 100 studs of a region should read:

```
1 HERO thing     — 60–120 studs, visible from far away, unique
5 MEDIUM things  — 15–40 studs, a recurring motif (rocks, arches, dead trees)
many SMALL things — 1–6 studs, clutter, always in clusters of 6–20, never alone
```

Applied to Auralis:

| Layer | Count for a 900×900 region | Examples |
|---|---:|---|
| Hero | **1** | The Windward Spire (a leaning rock tower, 90 studs) |
| Secondary anchors | **2** | The fallen arch; the drowned well |
| Medium clusters | **14–18 clusters** | rock outcrops, tree groves, root arches |
| Small clusters | **80–120 clusters** | grass tufts (8–15 each), pebbles, flowers |
| Empty space | **~40% of the area** | real landscapes have gaps; fills read as clutter |

**The counter-intuitive rule: leave space empty.** Agents fill every square metre because "more content" feels productive. Emptiness is what makes the hero landmark read.

---

## 4. Density budget (so it doesn't melt a phone)

| Zone | Props per 100×100 studs | Tri budget |
|---|---:|---:|
| Detail zone (near spawn, along the main route) | 55–80 | 60k |
| Travel corridor | 18–30 | 25k |
| Hinterland (visible, not visited) | 6–12 | 10k |
| Beyond the playable edge | 0–4, large scale only | 5k |

Say it out loud as a rule: **density falls with distance from the route.** Agents scatter evenly because that's the simplest loop; that's also why their worlds stutter and look uniform at the same time.

```lua
--!strict
-- Verify your own budget before you report done
local function auditDensity(parent: Instance, centre: Vector3, radius: number)
	local count = 0
	local tris = 0
	for _, d in parent:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
			if d:IsA("MeshPart") then
				tris += d.MeshPart? and 0 or 0   -- replace with your own tri estimate
			end
		end
	end
	local area = math.pi * radius * radius
	print(("props %d in %.0f studs^2 = %.2f per 100x100"):format(count, area, count / area * 10000))
end
```

---

## 5. When there is no good asset

Three fallbacks, in order of quality:

1. **`generate_mesh`** — "low-poly stylised pine tree, 3 variants, flat shading, Roblox proportions". Then inspect and sanitise.
2. **`generate_procedural_model`** — for structured props (fences, crates, ruins) where primitives are acceptable because the *object* is angular.
3. **Terrain** — for anything natural and large. A rock can be terrain. A cliff must be.

**Never** fall back to "a tree made of 2 parts" — that's the visual signature you're trying to remove.

---

## 6. The Auralis kit list (what to source)

| Category | Count | Notes |
|---|---:|---|
| Tree trunks / pines | 4 sources | scale 0.7–1.6, yaw full, tilt ±10° |
| Broadleaf trees | 3 sources | cluster in LeafyGrass patches |
| Bushes | 3 sources | 6–14 per cluster, spacing 3–6 studs |
| Rock outcrops | 5 sources | cluster along the ridge base and slopes |
| Cliff/boulder meshes | 4 sources | hero landmark uses one unique mesh |
| Root arches | 2 sources | the entrance to the buried meadow |
| Grass tufts | 2 sources | the ground-detail workhorse; thousands is fine if tiny |
| Flowers / reeds | 4 sources | near water and meadow, sparse |
| Ruin pieces | 4 sources | the drowned well, the fallen arch |
| Ground decals (paths) | 2–3 | painted dirt paths matter more than you think |

**Ten to fourteen sourced assets** produce a better-looking region than any amount of hand-modelling. That's the whole trick.
