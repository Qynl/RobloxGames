# Using the `generate_mesh` tool properly

`generate_mesh` is in the official Studio MCP. It generates a **textured 3D mesh from a text prompt** — and it takes parameters that decide whether you get a beautiful Auralis rock or a smooth blobby lump. Most agents pass only `prompt` and get the default (10,000 triangles, AI texture), which is why generated assets look wrong next to concept art.

---

## 1. The real parameters

| Param | What it does | Use it for |
|---|---|---|
| `prompt` | The description | Always — but see the formula in `mesh-prompts.md` |
| **`maxTriangles`** | Caps the triangle count. **Lower = more faceted = more low-poly.** Default ~10,000 | **This is your most important lever.** Set it per asset class (table below) |
| **`textures`** | Generate textures on/off. Off = bare geometry | **Off for anything you'll tint yourself.** On only for hero assets |
| `size` | Suggested size as `"x, y, z"` | Approximate proportions |
| **`scaleTo`** | Scale so the longest side is N studs | **Exact world size** — use this, not `size` |
| `position` | `"0, 10, 0"` | Placement |
| `parent` | Where it goes (defaults to Workspace) | Point at your kit folder |
| `anchor` | Anchor every part | **Keep on** — unanchored generated props fall over |
| **`imageAssetId`** | **Conditions generation on an image** | **Your concept art.** See §4 — this is the killer feature |
| `groups` | Custom part names, e.g. `["body", "lid"]` | Props that need separate moving parts |
| `schema` | How to split the result (default `Body1`) | Keep single-body for scatter props |
| `name` | Name for the model | Name it `_KIT_` prefixed so it's findable |
| `studioId` | Target Studio instance | Multi-window safety |

**Three parameters do 90% of the work: `maxTriangles`, `textures`, and `imageAssetId`.**

---

## 2. `maxTriangles` per asset class

Roblox caps a mesh around 10–20k triangles. That's a ceiling, not a target — props that appear 3,000 times must be far cheaper.

| Asset | `maxTriangles` | Why |
|---|---:|---|
| Grass tuft | **don't generate** | See §5 — crosses of quads beat anything generated |
| Small flower | **don't generate** | Same |
| Pebble | 120 | Below ~100 it turns to mush |
| Small rock | **300** | Facets read as intentional |
| Rock outcrop | 700 | Needs the layered silhouette |
| Bush | 500 | Lumpy silhouette matters more than detail |
| Tree | **900** | Trunk + 5 merged canopy lobes |
| Hero tree | 2,500 | One or two in the region |
| Cliff kit piece | 2,200 | Big, seen up close |
| **Windspire (hero)** | **3,500** | The landmark — let it have polygons |
| Root arch | 1,400 | Curves need some density |
| Ruin wall / tower | 1,000 / 1,600 | Chipped edges cost tris |
| **Plant specimen** | **800** | Must read at 20 studs — spend here |
| Creature (Mossback) | 5,000 | Only one on screen |
| Prop (crate, lantern) | 350 | |

**Rule of thumb:** if it appears more than 100 times, keep it under 500. If it appears once, 3,000 is fine. The tri budget is per *scene*, not per *asset*.

**Warning:** going too low backfires. Below ~150 triangles, generated meshes lose their silhouette and turn into unreadable blobs. If you need something at 60 tris (grass), generate a *cluster* at 500 and don't — see §5.

---

## 3. The call shapes

### One asset, correct params

```jsonc
{
  "tool": "generate_mesh",
  "arguments": {
    "prompt": "A single weathered boulder, rounded chunky mass with 5 large flat faceted faces, flattened top with a thin moss cap, flat-shaded low-poly stylized game asset, palette warm stone #B9AA93 lit faces / cool stone #6E6A61 shadow faces / moss #7B8B4F on top, soft rounded silhouette, no sharp spikes, no crystals, no hard 90-degree corners, no ground plane, no base, single object only",
    "maxTriangles": 300,
    "textures": false,
    "scaleTo": 6,
    "anchor": true,
    "name": "KIT_Rock_Small_A",
    "parent": "Workspace.KitSource.Rocks"
  }
}
```

### Then wait, then verify

```jsonc
{ "tool": "wait_job_finished", "arguments": { "jobId": "<id from the generate call>" } }
```

```jsonc
{ "tool": "inspect_instance", "arguments": { "path": "Workspace.KitSource.Rocks.KIT_Rock_Small_A" } }
{ "tool": "screen_capture", "arguments": { "position": [8, 6, 14], "lookAt": [0, 3, 0] } }
```

```lua
-- then count and check before you accept it
local function check(model)
	local parts, meshes, tris = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("MeshPart") then
				meshes += 1
				tris += #d.MeshId > 0 and (d:GetAttribute("TriCount") or 0) or 0
			end
		end
	end
	local size = model:GetExtentsSize()
	print(("parts=%d meshes=%d size=(%.1f, %.1f, %.1f)"):format(parts, meshes, size.X, size.Y, size.Z))
	print("  single-mesh?", parts == 1)
	print("  height right?", math.abs(size.Y - 6) / 6 < 0.3)
end
check(workspace.KitSource.Rocks.KIT_Rock_Small_A)
```

### Batch generation (with pacing)

Generated assets take time. Generate in small batches, poll, verify, then move on — don't fire 25 prompts at once and lose track.

```lua
--!strict
-- Run in the agent's head, not as code: this is the loop it should follow
local BATCH = {
	{ name = "KIT_Rock_Small_A",   tris = 300,  scale = 6,  parent = "Rocks" },
	{ name = "KIT_Rock_Small_B",   tris = 300,  scale = 9,  parent = "Rocks" },
	{ name = "KIT_Rock_Outcrop",   tris = 700,  scale = 14, parent = "Rocks" },
	{ name = "KIT_Bush_A",         tris = 500,  scale = 5,  parent = "Foliage" },
	{ name = "KIT_Tree_Broadleaf", tris = 900,  scale = 16, parent = "Trees" },
}
-- for each: generate_mesh -> wait_job_finished -> inspect -> screen_capture -> accept or re-prompt
```

**Acceptance per asset (all four must be true):**
1. **One MeshPart** (not 6 parts — ones scattered 200× multiply draw calls)
2. Height within 25% of target
3. Silhouette matches the shape language in `art-direction-lowpoly.md` (rounded, no crystals, no 90° corners)
4. Renders without a visible seam or hole in `screen_capture`

If it fails → **re-prompt with a more explicit silhouette clause**, don't try to fix geometry by hand. Generated meshes are not editable in a practical way.

---

## 4. The feature most people miss: `imageAssetId`

`generate_mesh` can be **conditioned on an image**. That means you can point it at *your own concept art* and get meshes in that exact style — the single biggest quality jump available to you.

### Workflow

```jsonc
// 1. upload a crop of a concept image (e.g. the Sunthread meadow, cropped to just foliage)
{ "tool": "store_image", "arguments": { "path": "C:/art/sunthread_grass_crop.png" } }
// → returns an image uri

{ "tool": "upload_image", "arguments": { "urls": ["<that uri>"] } }
// → returns { "<uri>": <assetId> }

// 2. generate conditioned on it
{ "tool": "generate_mesh", "arguments": {
    "prompt": "a stylized low-poly bush matching the reference foliage colours and rounded lumpy silhouette, single merged object, no ground plane",
    "imageAssetId": 1234567890,
    "maxTriangles": 500,
    "textures": false,
    "scaleTo": 5,
    "name": "KIT_Bush_Ref_A"
} }
```

**What to crop for reference images** (from your existing art):

| Crop source | Use it to generate | Why it works |
|---|---|---|
| `auralis_Sunthread_Fields...jpg` — foliage in the lower-left | bushes, grass clusters, flowers | exact colour and softness |
| `auralis_Landmarks_Windspire_Pillars...jpg` — the central spire | rock spires, cliff chunks | exact strata and silhouette |
| `auralis_Glasswater_Basin...jpg` — the turquoise water + submerged plants | water plants, reeds | palette match for waterline props |
| `auralis_Buried_Meadow_Root_Cavern...jpg` — the root tangle | root arches, vines, cave props | the only reference for organic cave forms |
| `auralis_World_Panorama...jpg` — tree masses | trees | consistent canopy shape |

**Important:** crop **one object per image**. A crop containing a whole landscape conditions the mesh toward mush. Tight crops of a single tree, a single rock, a single bush work dramatically better.

**Also:** a reference image with text OR a prompt with text — the docs note `/generate_mesh` accepts either a text prompt or an image, not both in one request in Assistant. Through MCP try prompt + `imageAssetId` together, and if the tool rejects it, send the image alone with the style baked into the image choice.

---

## 5. Where `generate_mesh` is the wrong tool

Be honest with yourself before spending an hour on prompts that can't succeed.

| Asset | Why generation fails | Do this instead |
|---|---|---|
| **Grass tufts** | Needs ~40 tris and a perfect cross-plane. Generated geometry at that budget is mush, and grass is 3,000 instances | **Build procedurally**: 2 crossed quads + a grass texture, or a 6-triangle blade fan |
| **Ground/terrain** | Generation is for objects | `Terrain:FillBall` (see `terrain-recipes.md`) |
| **Architecture / walls** | Needs exact dimensions and clean joins | Parts + your kit pieces, or `generate_procedural_model` |
| **Anything with repeated exact parts** (fences, railings, stairs) | Generated meshes wobble | Parts, or a small handmade mesh |
| **Anything that must tile** | No UV control | Handmade or Store asset |
| **Large-scale landscape features** | Too big for one mesh | Terrain |
| **Rigs / animated creatures** | `generate_mesh` is static props | `generate_avatar` or a rigged Store asset |

**The rule:** generated meshes are for *organic single objects* — rocks, trees, bushes, plants, roots, ruins, props. Everything structural or repeated should be terrain, parts, or a procedural model.

---

## 6. Textures: the decision that makes or breaks the look

`textures: false` gives you **bare geometry** with a single flat colour you control. `textures: true` gives an AI texture (and Roblox caps textures at 1024×1024).

| Asset | Textures | Why |
|---|---|---|
| Grass, flowers, small rocks, bushes (scattered 100s of times) | **false** + tint per instance | Cheaper, and per-instance tint variance does the work |
| Trees (78 instances) | **false** + tint | 78 × 1K textures is memory you don't have |
| Cliff pieces (20) | **false** | Faceted flat colour + lighting reads better than a muddy AI texture |
| **Hero spire, hero tree, ruins (once each)** | **true**, Quality mode | Worth the memory; they're seen up close |
| **Plants (5 total)** | **true** | These are the game — detail is the reward |
| Creature | **true** | One on screen |

**Why not texture everything:** AI textures carry baked lighting and colour that **fights your measured palette** (`#C8A951` meadow gold, `#B9AA93` warm stone). Flat colour + your light record + per-instance tint keeps every asset inside the palette. It's also the difference between a 40 MB and a 400 MB memory budget on mobile.

If you do want texture on a scattered asset, use **`generate_material`** instead — it makes a material variant you apply to flat geometry, which costs far less than a unique texture per mesh.

---

## 7. After generation: the sanitise pass (mandatory)

Generated meshes arrive with problems that only show up after you scatter 200 of them.

```lua
--!strict
-- Sanitise.lua — run on every accepted generated asset
local function sanitise(model: Model, targetHeight: number, collisionFidelity: Enum.CollisionFidelity?)
	-- 1. exact size
	local size = model:GetExtentsSize()
	model:ScaleTo(targetHeight / size.Y)

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- 2. collision: props are decoration; terrain does the colliding
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			-- 3. render fidelity: automatic = LOD swapping, big win on mobile
			d.RenderFidelity = Enum.RenderFidelity.Automatic
			-- 4. collision geometry, if it ever needs collision
			if collisionFidelity and d:IsA("MeshPart") then
				d.CollisionFidelity = collisionFidelity
			end
			-- 5. cast shadow off on tiny props: shadows are the #1 mobile cost
			if targetHeight < 3 then
				d.CastShadow = false
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			-- 6. never run code from a generated asset
			d:Destroy()
		elseif d:IsA("SurfaceAppearance") then
			-- 7. keep only if you generated textures on purpose
			print("SurfaceAppearance present on", model.Name)
		end
	end

	model:PivotTo(CFrame.new(0, -800, 0))   -- park off-world as a source
	print("sanitised", model.Name, "height", targetHeight)
end

return sanitise
```

**Plus two things you can't script:**
- **Check the underside.** Generated meshes often have holes where the model "assumed" a ground plane. Look at it from below with `screen_capture`.
- **Check it at scatter scale.** A rock that looks great alone at 8 studs may look like a bug at 3 studs among 200 others. Place 20 before you place 200.

---

## 8. The working loop, in order

```
1. Pick the asset class from the budget table → get its maxTriangles
2. Crop a reference from your concept art (if it's a hero asset)
3. generate_mesh with: rich prompt + maxTriangles + textures decision + scaleTo + name + parent
4. wait_job_finished
5. inspect_instance → one MeshPart? correct size?
6. screen_capture from two angles, including below
7. Accept → sanitise → park in ServerStorage.Kit
   Reject → re-prompt with a more explicit silhouette clause (max 2 retries)
8. Scatter 20 → screenshot → then scatter the full count
9. Add to the kit manifest (name, asset id, tris, height, class)
10. Run world-audit.lua after the whole kit is in
```

**The single most useful habit:** keep a kit manifest. When the agent re-runs a build, it should *reuse* the manifest's asset ids, never regenerate. Regenerated assets look different from the previous batch and your world quietly loses consistency — which is exactly the "why does it look worse than yesterday" problem.
