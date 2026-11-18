# generate_mesh prompt library — Auralis kit

Prompts written to produce **stylized low poly that matches your concept art's silhouettes and palette**, not generic low-poly.

Usage through the Studio MCP (note: **no `format` param** — that was wrong in an earlier draft):

```jsonc
{ "tool": "generate_mesh", "arguments": {
    "prompt": "…prompt from below…",
    "maxTriangles": 300,
    "textures": false,
    "scaleTo": 6,
    "anchor": true,
    "name": "KIT_Rock_Small_A",
    "parent": "Workspace.KitSource.Rocks"
} }
{ "tool": "wait_job_finished", "arguments": { "jobId": "<returned id>" } }
```

Full parameter reference, texture decisions and the `imageAssetId` reference-image workflow: [`generate-mesh-tool.md`](generate-mesh-tool.md).

Then **always** sanitise before scattering:

```lua
--!strict
-- 1. check it: inspect_instance, screen_capture, and count parts/tris
-- 2. sanitise: anchor, no collide, delete scripts, park in ServerStorage.Kit
-- 3. verify size: targetHeight / GetExtentsSize().Y
```
See `kitbash.md` §1 for the sanitise function.

---

## The prompt formula

Every prompt follows this order. Skipping a clause is what produces generic output.

```
[SUBJECT] + [SILHOUETTE] + [TRI BUDGET] + [SHADING] + [PALETTE with hex] +
[ROBLOX GAME ASSET] + [NO list]
```

**Your style block** (paste into every prompt):

> `flat-shaded low-poly stylized game asset, faceted surfaces, soft rounded organic silhouette, no hard 90-degree corners, muted natural palette, warm key light, Roblox game asset`

**Your palette block**:

> `palette: olive #7B8B4F, sage #8FA169, meadow gold #C8A951, warm stone #B9AA93, cool stone #6E6A61, deep green #4F6B3C, accent cyan #63E6D6`

**Set `maxTriangles` for every call** — the prompt can't control poly count, the parameter does. Use the table in [`generate-mesh-tool.md`](generate-mesh-tool.md) §2 (grass is not generated; rock 300, tree 900, plant 800, hero spire 3,500).

**Your NO list** (agents forget this and get photoreal or crystal shapes):

> `no photorealism, no smooth continuous surfaces, no crystal or gem shapes, no sharp thin spikes, no text, no logos, no character, no base, no ground plane, no excessive detail, single object only`

---

## 1. Ground cover — the highest-value assets

These are 55% of your prop count. Cheap, tiny, and they do more for "finished" than anything else.

**Grass tuft (golden meadow)** — 40 tris
> `A small clump of golden meadow grass, 7–9 wind-bent blades fanning from one base point, thin tapered blades with slight curl, flat-shaded low-poly stylized game asset, faceted surfaces, no hard 90-degree corners, palette: meadow gold #C8A951 and highlight #D9BE6A with olive #7B8B4F at the base, Roblox game asset, no photorealism, no smooth continuous surfaces, no text, no base, no ground plane, single object only`

**Grass tuft (olive, shaded variant)** — 40 tris
> `A small clump of olive green grass, 8 short upright blades with varied height and lean, flat-shaded low-poly stylized game asset, faceted, palette: sage #8FA169 and deep green #4F6B3C, soft rounded silhouette, no hard 90-degree corners, Roblox game asset, no photorealism, no text, no base, no ground plane, single object only`

**Small wildflower cluster** — 30 tris
> `A tiny cluster of 5 small wildflowers on thin stems, simple 5-petal blooms, two heights, flat-shaded low-poly stylized game asset, faceted, palette: pale violet #B9A6D6, white #EFE7DA and olive stems #7B8B4F, no hard 90-degree corners, Roblox game asset, no photorealism, no text, no base, no ground plane, single object only`

**Reeds (waterline)** — 45 tris
> `A clump of tall thin lakeside reeds, 9 straight narrow stalks of varied height with a small seed head at the top, flat-shaded low-poly stylized game asset, palette: sage #8FA169 to warm gold #C8A951 tips, Roblox game asset, no photorealism, no text, no base, no ground plane, single object only`

**Pebble cluster** — 70 tris
> `A small cluster of 5 weathered pebbles of different sizes, rounded chunky forms with 4–6 large flat faces each, flat-shaded low-poly stylized game asset, palette: warm stone #B9AA93 and cool stone #6E6A61, soft rounded silhouette, no hard 90-degree corners, Roblox game asset, no photorealism, no crystal shapes, no text, no base, single object only`

---

## 2. Rocks and cliffs — the shape language that matters most

Your art's rocks are **rounded and layered with moss caps**, never crystalline. If the model gives you shards, reject and re-prompt.

**Small rock** — 180 tris
> `A single weathered boulder about 2 meters wide, rounded chunky mass with 5 large flat faceted faces, slightly flattened top with a thin moss cap, flat-shaded low-poly stylized game asset, palette: warm stone #B9AA93 lit faces, cool stone #6E6A61 shadow faces, moss #7B8B4F on the top surface, soft rounded silhouette, no sharp spikes, no crystals, no hard 90-degree corners, no ground plane, no base, single object only`

**Rock outcrop (cluster)** — 500 tris
> `A rock outcrop of 3–4 stacked boulders of different sizes merging at the base, layered horizontal strata feel, rounded weathered forms with large flat facets, thin moss patches on upward faces, flat-shaded low-poly stylized game asset, palette warm stone #B9AA93, mid #8E8272, cool #6E6A61, moss #7B8B4F, no crystals, no sharp edges, no hard 90-degree corners, no ground plane, single object only`

**Cliff chunk (modular kit piece)** — 1,800 tris
> `A modular cliff face section, 12 meters wide and 14 tall, layered sedimentary bands, rounded weathered edges with 2 large overhangs, flat-shaded low-poly stylized game asset, chunky rock planes with visible flat facets, thin moss and small vines on ledges and top, palette: warm stone #B9AA93 to cool stone #6E6A61 strata, deep green #4F6B3C moss, no crystals, no sharp spikes, no hard 90-degree corners, no ground plane, no base, single object only`

**Rock spire (hero landmark — "Windspire")** — 3,200 tris
> `A tall slender rock spire 30 meters high, tapered column of 4 stacked irregular chunks each slightly offset, wider ledges at three heights with moss and small plants growing on them, one side sheared flat, weathered horizontal strata, flat-shaded low-poly stylized game asset, palette: warm stone #B9AA93 sunlit, cool #6E6A61 shadow, moss #7B8B4F on ledges, no crystals, no sharp thin spikes, no hard 90-degree corners, no ground plane, no base, single object only`

**Wind-carved arch** — 900 tris
> `A natural stone arch 10 meters wide, thick uneven limbs of weathered rock meeting at the top, rounded chunky forms, moss on the upper surfaces, one broken notch, flat-shaded low-poly stylized game asset, palette warm stone #B9AA93 and cool #6E6A61 with moss #7B8B4F, no crystals, no hard 90-degree corners, no ground plane, single object only`

---

## 3. Trees and foliage — your art's canopies are rounded and lumpy

**Stylized broadleaf tree** — 900 tris
> `A stylized broadleaf tree 8 meters tall with a rounded lumpy canopy made of 5 merged irregular lobes, thin slightly bent trunk that splits into 3 branches, wind-bent toward one side, flat-shaded low-poly stylized game asset, canopy in olive #7B8B4F and deep green #4F6B3C with sage #8FA169 highlights, trunk in warm brown #6B5A44, soft rounded organic silhouette, no hard 90-degree corners, no photorealism, no visible leaves in detail, no ground plane, no base, single object only`

**Young / small tree** — 500 tris
> `A small young tree 4 meters tall, narrow trunk, 3 compact rounded canopy lobes, slight wind lean, flat-shaded low-poly stylized game asset, palette olive #7B8B4F, sage #8FA169, trunk #6B5A44, soft rounded silhouette, no hard 90-degree corners, no ground plane, single object only`

**Bush** — 260 tris
> `A low rounded bush 1.5 meters wide, 4 merged lumpy lobes with an uneven top, a few visible stems at the base, flat-shaded low-poly stylized game asset, palette deep green #4F6B3C with sage #8FA169 and olive #7B8B4F highlights, soft rounded organic silhouette, no hard 90-degree corners, no flowers, no ground plane, no base, single object only`

**Root arch (cave entrance)** — 1,200 tris
> `A massive ancient tree root arching out of the ground 12 meters wide, thick uneven organic limbs, bark ridges, moss along the top, small vines hanging, an opening beneath it, flat-shaded low-poly stylized game asset, palette warm brown #6B5A44, deep green #4F6B3C moss, flat faceted surfaces, no hard 90-degree corners, no ground plane, single object only`

**Hanging vines** — 120 tris
> `A curtain of 6 hanging vines of different lengths, thin uneven strands with a few small leaves, flat-shaded low-poly stylized game asset, palette deep green #4F6B3C and sage #8FA169, no hard 90-degree corners, no ground plane, single object only`

---

## 4. Ruins — worn, chipped, never perfect cubes

**Broken wall section** — 700 tris
> `A crumbling stone wall section 6 meters wide and 3 tall, chipped irregular blocks missing at the top edge, worn rounded edges, cracks, moss and small plants in the crevices, flat-shaded low-poly stylized game asset, palette warm stone #B9AA93, mid #8E8272, cool #6E6A61, moss #7B8B4F, no perfect cube shapes, no hard 90-degree corners, no ground plane, single object only`

**Ruined watchtower** — 1,600 tris
> `A ruined circular stone watchtower 9 meters tall, broken open at the top with an irregular jagged rim, one collapsed doorway, weathered bands, moss and vines, flat-shaded low-poly stylized game asset, palette warm stone #B9AA93 and cool #6E6A61 with moss #4F6B3C, chunky faceted stones, no perfect cylinder, no hard 90-degree corners, no ground plane, single object only`

**Stone steps / path edge** — 300 tris
> `A short flight of 4 weathered stone steps, uneven worn treads, chipped corners, moss at the edges, flat-shaded low-poly stylized game asset, palette warm stone #B9AA93 and mid #8E8272 with moss #7B8B4F, no perfect cubes, no hard 90-degree corners, no ground plane, single object only`

---

## 5. Plants — spend your polygons here

These are the game. A plant must read as *itself* at 20 studs.

**Driftleaf** (Natural — broad pale leaves, silver undersides, tilts before wind) — 700 tris
> `A low wind-loving plant with 7 broad thin leaves fanning outward and upward from a small base, leaves slightly curled at the tips, pale sage green tops #A9BF8F and silvery pale undersides #DCE4DA, thin dark stems, a little wind-bent asymmetry, flat-shaded low-poly stylized game asset, elegant simple silhouette, no hard 90-degree corners, no photorealism, no flower, no ground plane, no base, single object only`

**Sunspool** (Natural — seed heads follow the sun) — 650 tris
> `A sun-following plant with a spiral arrangement of 9 narrow leaves around a tall thin stem topped with a small round golden seed head ringed by short bracts, pale warm gold #D9BE6A head, olive #7B8B4F and sage #8FA169 leaves, flat-shaded low-poly stylized game asset, clear spiral silhouette, no hard 90-degree corners, no photorealism, no ground plane, single object only`

**Meadowflare** (Distinct — grows at warm vents, glowing tips) — 800 tris
> `A heat-loving plant with 6 thick curved leaves rising from a dark rosette, tips softly glowing warm amber #F0A03C, leaves deep olive #4F6B3C fading to amber at the ends, one small ember-like bud in the centre, flat-shaded low-poly stylized game asset, glowing accent only on the tips, no hard 90-degree corners, no photorealism, no ground plane, single object only`

**Cave glow flower** (Buried Meadow accent) — 300 tris
> `A small cave flower with 5 broad pale petals around a bright cyan centre, thin stem, one or two leaves, soft cyan glow at the centre #63E6D6, petals pale cream #EFE7DA, flat-shaded low-poly stylized game asset, simple elegant silhouette, no hard 90-degree corners, no ground plane, single object only`

**Glowing cave mushroom** — 260 tris
> `A small glowing mushroom, rounded irregular cap with a wavy edge, thick short stem, warm ember glow #F0A03C on the underside, cap warm ochre #C8A951, flat-shaded low-poly stylized game asset, soft rounded silhouette, no hard 90-degree corners, no ground plane, single object only`

---

## 6. Creature — Mossback (one only, for later)

**Mossback** — 4,500 tris
> `A large gentle quadruped creature about 3 meters long, low and heavy body with a domed mossy shell of layered plates, short thick legs, a blunt rounded head with two small eyes, moss and small plants growing on its back, flat-shaded low-poly stylized game asset, palette: moss #7B8B4F and deep green #4F6B3C on the shell, warm stone grey-green #8E8272 hide, warm brown #6B5A44 hooves, soft rounded silhouette, readable from 50 meters, no photorealism, no fur detail, no hard 90-degree corners, no ground plane, single object only`

---

## 7. Quality gate for every generated mesh

Run this checklist **before** it goes into the world. Reject and re-prompt rather than "fixing" it.

```lua
--!strict
-- MeshGate.lua — call after insert, before sanitise
local MAX_TRIS = { grass = 60, flower = 40, pebble = 80, bush = 350, smallRock = 250,
	largeRock = 900, tree = 1200, heroTree = 3000, cliff = 2500, spire = 4000,
	rootArch = 1500, ruin = 1200, plant = 900, creature = 6000 }

local function auditMesh(model: Model, class: string, targetHeight: number)
	local partCount, meshCount, tris = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			partCount += 1
			if d:IsA("MeshPart") then
				meshCount += 1
				tris += d.MeshPart? and 0 or 0   -- use your own tri estimate or asset info
			end
		end
	end
	local size = model:GetExtentsSize()
	local heightOk = math.abs(size.Y - targetHeight) / targetHeight < 0.25
	local ratio = math.max(size.X, size.Z) / math.max(size.Y, 0.01)

	print(string.format("%s: parts=%d meshes=%d height=%.1f (target %.1f) footprint/height=%.2f",
		model.Name, partCount, meshCount, size.Y, targetHeight, ratio))
	print("  heightOk:", heightOk)
	print("  budgetOk:", tris <= (MAX_TRIS[class] or 1200))
	print("  ratioOk:", ratio > 0.35 and ratio < 6, "-- rejects flat pancakes and needles")
end
```

**Reject a mesh if any of these is true:**

| Condition | Why it fails | Re-prompt with |
|---|---|---|
| More than 2 parts, not merged | Draw calls explode when scattered 3,000× | "single merged mesh, one object only" |
| A 90° corner visible | Reads as programmer-made | "rounded weathered edges, bevel all edges" |
| Crystal/shard shapes | Doesn't match your art's rock language | "rounded chunky boulder, no crystals, no spikes" |
| Height wrong by > 25% | Scale mismatches the whole region | add explicit dimensions |
| Flat pancake or needle ratio | Silhouette unreadable | add "chunky proportions, roughly as wide as tall" |
| Smooth shading | Exposes low tri count, looks plastic | "flat-shaded, faceted surfaces" |
| Any texture with detail noise | Fights the palette, costs memory | "flat colours, no texture detail" |
| Script inside | Security risk | delete |

---

## 8. The generation order (do it in this order, it saves rework)

1. **Grass tuft + flower + pebble** (3 assets) → scatter 1,000 and screenshot. If the *ground* doesn't already look better, stop — the palette or the lighting is wrong, and nothing else will fix it.
2. **Small rock + bush** (2) → scatter in clusters → screenshot.
3. **Tree** (1) → place 8 → screenshot the silhouette at 100 studs.
4. **Cliff chunk** (1) → build one ridge face → screenshot.
5. **Root arch + cave flower + cave mushroom** → the hidden pocket.
6. **The three plants** → the thing players actually come for.
7. **Spire + ruins** → the landmarks, last, because they depend on the palette being settled.

**Do not generate the creature or the hero spire first.** They're the most fun to prompt and the least informative — you'll spend an afternoon on a dragon-shaped rock and still not know if the meadow reads.
