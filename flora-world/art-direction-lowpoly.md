# Auralis in low poly — what to keep, what to sacrifice

I looked at the five Auralis images in `05_Presentation/Concept_Art/Worlds/auralis/` (copied to [`_ref/`](_ref/)). Being honest with you first:

> **The concept art is not low poly, and cannot be reproduced as low poly.** It's painterly, soft-shaded, with continuous surfaces, hundreds of grass strands per square metre, layered translucent foliage, and volumetric light. If you match that with meshes you will not ship on a phone, and each region takes a month.

But that's not the real problem. The real problem is that "low poly" *usually* means "faceted, flat, empty" — which is exactly why agent-built worlds look bad. The good news: **almost none of what makes your art look good is polygon count.**

---

## What actually makes those images look good

I broke the five images down. In order of contribution to quality:

| # | What makes it look good | Can you keep it in low poly? |
|---|---|---|
| 1 | **Light and atmosphere** — warm 8.9am sun, haze in the distance, cool shadows, god rays | **Yes, 100%.** It's a `Lighting` record, not geometry. This is your whole `visual_themes.json` |
| 2 | **Palette** — olive/sage greens, warm ochre meadow, pale warm-grey stone, turquoise water, cyan motes | **Yes, 100%.** Free |
| 3 | **Silhouette language** — rounded, weathered, layered, organic. Nothing is a cube | **Yes, if you generate the right meshes** |
| 4 | **Density of small things** — grass strands, flowers, pebbles, vines everywhere | **Yes — this is the cheap one.** Grass tufts at 40 tris × 3,000 instances |
| 5 | **Scale** — distant mountains, towering spires, tiny human | **Yes**, with terrain + a few big landmarks |
| 6 | Surface micro-detail — every rock has strata, every leaf has veins | **No.** This is the part you give up |
| 7 | Continuous soft shading — no visible polygon edges | **No.** You'll get flat-shaded facets |

**So the trade is: keep 1–5, lose 6–7.** That trade is what "stylized low poly" means, and it looks great if you commit to it consistently. What kills it is keeping the low polygon count but losing 1–5 — which is what happened in the agent's build: no light, no palette, cube silhouettes, no ground detail.

---

## The palette to hit (measured from your five images)

Put these in `visual_themes.json` as accent colours and in the generate_mesh prompts. They're the values I read off the art, not invented.

| Role | Hex | Where it appears |
|---|---|---|
| Meadow gold (dry grass) | `#C8A951` | Sunthread Fields foreground, the dominant warm note |
| Meadow highlight | `#D9BE6A` | Sun-caught grass tips |
| Olive green | `#7B8B4F` | Mid-ground slopes |
| Sage green | `#8FA169` | Grass in shade |
| Deep green | `#4F6B3C` | Bushes, tree masses, cave moss |
| Stone warm light | `#B9AA93` | Sunlit cliff faces, spires |
| Stone mid | `#8E8272` | Rock shading, ruin walls |
| Stone cool | `#6E6A61` | Shadowed rock, cave walls |
| Sky haze | `#A9BFD0` | Distant mountains, atmospheric falloff |
| Warm sky | `#F3E3C4` | Horizon glow at 8.9am |
| Water teal | `#4FA9A8` | Glasswater shallows |
| Water deep | `#2E8C8F` | Basin middle |
| Mote cyan | `#63E6D6` | The floating bioluminescent specks — **signature accent** |
| Cave ember | `#F0A03C` | Buried Meadow warm glow, mushrooms |
| Deep shadow | `#3A3F35` | Never pure black |

**The one rule that unifies the art:** every image has **warm light + cool shadows + one cyan accent**. If a build contains those three, it reads as Auralis even at 900 triangles.

---

## The shape language (this is the thing to generate toward)

From the images, the silhouette rules are consistent:

| Element | In your art | Low-poly translation |
|---|---|---|
| **Rocks / cliffs** | Rounded, weathered, stacked in horizontal strata, mossy tops | Chunky rounded masses with **4–6 large flat faces**, not crystals. Bevel every edge. Moss cap on upward faces |
| **Trees** | Rounded broadleaf canopies, thin trunks, wind-bent | 5–7 lumpy spheres merged into one canopy, slight bend, 8-sided trunk |
| **Grass** | Dense fine strands, wind-swept, golden | **Cross-plane tufts**, 2 quads, 40 tris, thousands of them |
| **Spires (Windspire)** | Tall, tapered, layered ledges with vegetation on each ledge | Tapered column of 3–4 stacked chunks, each wider than the last at the base, plants on ledges |
| **Arches / roots** | Thick organic curves, uneven thickness | 8-sided swept tube along a curve, 2–3 bulges |
| **Ruins** | Broken walls, rounded worn blocks | Irregular block shapes with chipped corners, no perfect cubes |
| **Water** | Clear, layered, with visible submerged plants | Terrain water + a **seabed with plants** — the illusion is the bed, not the water |
| **Plants** | Curved, glowing tips, elegant | 6–10 large curved leaves + one glow element. 400–900 tris gets you 90% of it |

**The single most important shape rule:** *nothing has a 90° corner.* Bevel everything. A 900-tri beveled rock reads as "art"; a 900-tri box reads as "programmer".

---

## Poly budget per asset class

Targets for a system that holds 30 FPS on a mid-range phone with ~4,000 props visible.

| Asset class | Tris | Instances per region | Notes |
|---|---:|---:|---|
| Grass tuft | **30–60** | 3,000 | The workhorse. Cross-planes, no collision |
| Small flower | 20–40 | 600 | Cross-planes or 5-petal low mesh |
| Pebble | 40–80 | 400 | Also use for path edges |
| Bush | 150–350 | 140 | One merged canopy |
| Small rock | 100–250 | 240 | Beveled, moss cap |
| Large rock | 400–900 | 60 | 4–6 big faces |
| Tree (stylized) | **600–1,200** | 78 | Trunk + 3 merged canopy lobes |
| Hero tree / landmark tree | 1,500–3,000 | 2 | One per region max |
| Cliff chunk (kit) | 1,200–2,500 | 20 | Terrain does the bulk |
| Rock spire (hero) | 2,000–4,000 | 1 | The Windspire |
| Root / arch | 800–1,500 | 4 | Swept tube |
| Ruin piece | 500–1,200 | 8 | Broken blocks |
| **Plant specimen** | **400–900** | 5 | Must read at 20 studs — spend here |
| Creature | 3,000–6,000 | 1–2 | Never visible in dozens |
| Prop (crate, lantern) | 100–400 | 30 | |

**Region total budget:** ~150k tris for the whole Auralis region, of which grass is only ~150k × 0.55 = most of it but at near-zero draw cost if batched. Aim:

| Metric | Target |
|---|---|
| Total scene tris (all visible) | < 250k |
| Triangles visible in one camera frame | < 120k |
| Unique mesh assets per region | 25–35 |
| Draw calls (unique meshes × material) | < 90 |
| Texture memory | < 40 MB |
| Frame time, mid-range phone | < 22 ms (45 FPS) |

---

## How to make low poly look *expensive*

Six cheap tricks, in order of impact:

1. **Flat shading + ambient occlusion.** Turn off `MeshPart.DoubleSided`, use `Enum.RenderFidelity.Automatic`, and bake AO into the texture. Flat shading hides low geometry counts; smooth shading exposes them.
2. **Vertex-colour-ish tinting per instance.** The variance rule from `kitbash.md` (±6% value) is what stops 3,000 tufts reading as one object.
3. **Silhouette over detail.** Spend the polygons on the outline. A tree whose silhouette is interesting at 6 tris looks better than a detailed one that reads as a blob.
4. **Density, not complexity.** 3,000 × 40-tri tufts beats 300 × 400-tri plants, and it's cheaper.
5. **Strong light.** A single warm key with cool ambient makes 10k tris look like 100k. This is why step 1 of the build order is lighting.
6. **Fog/atmosphere masks distance.** Your art has heavy aerial perspective. `Atmosphere.Haze = 1.6` hides your low-poly horizon — the most valuable trick on the list.

---

## What to write in `visual_themes.json`

Add these to the Auralis record so the palette lives in data, not in prompts:

```json
{
  "lowPoly": {
    "styleId": "auralis-stylized-v1",
    "shading": "flat",
    "bevelAll": true,
    "maxTrisPerProp": 1200,
    "palette": {
      "meadowGold": "#C8A951",
      "meadowHighlight": "#D9BE6A",
      "olive": "#7B8B4F",
      "sage": "#8FA169",
      "deepGreen": "#4F6B3C",
      "stoneLight": "#B9AA93",
      "stoneMid": "#8E8272",
      "stoneCool": "#6E6A61",
      "haze": "#A9BFD0",
      "skyWarm": "#F3E3C4",
      "waterTeal": "#4FA9A8",
      "waterDeep": "#2E8C8F",
      "moteCyan": "#63E6D6",
      "caveEmber": "#F0A03C",
      "shadow": "#3A3F35"
    },
    "accentRule": "Every composition: warm key light, cool shadow, exactly one cyan accent."
  }
}
```

Now the palette has one source of truth, and every generate_mesh prompt can reference `styleId` instead of hoping the model remembers.
