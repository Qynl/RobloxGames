# Why the agent's world looks bad — and the protocol that fixes it

Your repo already has the right direction: `visual_themes.json` has real Auralis values, `Materials_And_Lighting.md` lists the ten "template game" tells, and you have concept art for the region. **The agent ignores all of it and still builds a box field.** That's not a taste problem. It's six specific mechanical failures, and each one has a fix.

Order of work, at your pace: **world first → abilities second → everything else.** This folder is only about the world.

---

## The six reasons an agent builds an ugly world

### 1. It builds with `Part`s instead of terrain — this is 80% of the ugliness
An agent can compute `Instance.new("Part")`, size and position. It cannot sculpt. So you get cliffs made of scaled cubes, hills made of stacked blocks, and a horizon of right angles. Every Roblox map that looks "programmer-made" looks that way for exactly this reason.

**Fix:** terrain is scriptable too, and a handful of `FillBall`/`FillBlock` calls with the right materials beats 400 parts. See [`terrain-recipes.md`](terrain-recipes.md).

### 2. It never sources assets — so it can only produce geometry it can invent
The world doesn't look bad because the layout is wrong; it looks bad because **there are no trees, no foliage, no rock meshes, no props.** An agent that models from scratch produces primitives. An agent that *places* good models looks like an artist.

**Fix:** `search_asset` → `insert_asset` → `generate_mesh` for the kit. Then assembly rules. See [`kitbash.md`](kitbash.md). **Do not model. Kitbash.**

### 3. It places things on a grid, at uniform scale, with one tint
The human eye reads "made by a machine" from repetition long before it reads "low poly". Your own doc lists this as tell #8 and it is the second-biggest offender.

**Fix:** a scale-and-rotation variance rule and cluster logic with numbers. Also in `kitbash.md`.

### 4. It builds the whole region before applying light — or never applies light at all
Terrain with default lighting is grey soup. Your `Materials_And_Lighting.md` already says fixing lighting "takes under an hour and changes more than a week of prop modelling" — and it's still the step agents skip because it isn't geometry.

**Fix:** lighting is **step 1**, not step 12. Apply the Auralis record *before* the first prop, then re-check after every build layer.

### 5. It has no composition — objects are scattered "naturally" which means randomly
Real environments have rhythm: a big landmark, a medium anchor, small detail, empty space, then repeat. Random scatter reads as noise. Composition is a rule you can write down, and an agent can follow rules.

**Fix:** the **3-5-1 rule** and the sightline rule in [`kitbash.md`](kitbash.md).

### 6. It never looks at what it built
It cannot see. It reports "the region is built" having never taken a screenshot, and you're the one who discovers it's ugly. This is the failure that makes the other five survive.

**Fix:** a mandatory screenshot gate from fixed cameras, plus an automated "looks bad" audit that prints a score. See [`looks-bad-audit.md`](looks-bad-audit.md) and [`world-audit.lua`](world-audit.lua).

---

## The build order that produces a good-looking world

Do not let the agent improvise the order. This is the order, and each step has a gate.

| # | Step | Gate before moving on |
|---|---|---|
| 1 | **Light the void.** Apply the Auralis record: `Future` lighting, Atmosphere, ColorCorrection, Bloom, clouds, sun angle 8.9 | `screen_capture` of an empty baseplate already looks like Auralis's *morning*, not Roblox |
| 2 | **Terrain macro-shape.** One ridge, one hollow, one water edge, flat meadow. Terrain only — 40–80 `FillBall`/`FillBlock` calls, no parts | Silhouette readable from 300 studs. Shadows show the ridge |
| 3 | **Terrain materials.** 6 materials minimum in patches, not one colour everywhere | Count distinct terrain materials ≥ 6 |
| 4 | **Landmarks.** One 60–120 stud hero landmark visible from spawn, plus 2 secondary anchors | From spawn, you can name the landmark and the route to it |
| 5 | **Kitbash layer 1 — big.** Cliffs, arches, big rocks, tree trunks | Nothing floating, nothing intersecting, scale believable next to a character |
| 6 | **Kitbash layer 2 — medium.** Trees, bushes, ruin pieces, ground clutter | Prop density check: 1 prop per ~180 stud² in detail zones, 1 per ~900 in travel corridors |
| 7 | **Kitbash layer 3 — small.** Grass tufts, flowers, pebbles, fallen leaves | At eye height there is no visible bare terrain within 20 studs |
| 8 | **Playable route pass.** Spawn → landmark → hollow → hidden pocket | You can walk it without hitting a streaming hole or a dead end |
| 9 | **Specimen anchors.** Plant habitat spots, placed by habitat logic, not scattered | Each of the 3 plants is in a plausible habitat, visible from a route |
| 10 | **Final pass.** Re-check lighting, fog, ambient sound, screenshot the 5 fixed cameras | `world-audit.lua` scores ≥ 9/10 and the 5 screenshots match the concept art palette |

**The rule that makes this work:** steps 2, 4 and 7 each end with a *screenshot you look at*. Not a report. A picture.

---

## The "it looks bad but I can't say why" triage

Run this in order — it finds the actual cause in about 3 minutes.

| What you see | Actual cause | Fix |
|---|---|---|
| Flat, no shape, everything lit evenly | No terrain relief + GlobalShadows off or sun overhead | Steps 1–2 |
| Grey/dark, muddy colours | Lighting not applied, or `Voxel` technology | Step 1; check `Lighting.Technology = Future` |
| Looks like lego | Parts used for landforms | Step 2 — replace with terrain |
| Empty and lifeless | No kitbash layer 1–3 | Steps 5–7 |
| "Made by a robot" | Uniform scale/rotation/tint | `kitbash.md` variance rules |
| Blurry / hard to read at distance | No landmark hierarchy, no fog falloff | Step 4 + atmosphere |
| Fine at eye height, terrible from above | No macro composition — only detail | Step 4 first, then detail |
| Everything the same green | One terrain material | Step 3, and `Terrain:SetMaterialColor` per material |
| Water looks like flat glass | No wave size/transparency/reflectance from theme | Apply the `water` record |
| You can see the map edge | No horizon treatment | Terrain beyond 800 studs, fog, or a distant backdrop |

---

## What to tell the agent (one paragraph, paste it)

> Build the world in this order and stop at each gate: (1) apply the Auralis lighting record and screenshot an empty baseplate; (2) sculpt the macro terrain with `FillBall`/`FillBlock` only — no parts for landforms; (3) apply at least six terrain materials in patches; (4) place one hero landmark visible from spawn and two secondary anchors; (5) source and insert a kit with `search_asset`/`insert_asset` — do not model trees or rocks from primitives; (6) fill in medium props with scale variance 0.7–1.6 and rotation variance ±25°; (7) add small ground detail until no bare terrain is visible within 20 studs at eye height; (8) walk the route; (9) place specimen anchors by habitat logic. After every step, `screen_capture` from the five fixed cameras in `looks-bad-audit.md` and describe three concrete things you see. Then run `world-audit.lua` and paste the score. You may not report a step as done without the screenshot and the audit numbers.

---

## Files in this folder

| File | What it's for |
|---|---|
| [`AGENT-WORLD-RULES.md`](AGENT-WORLD-RULES.md) | Paste-in system prompt: build order, hard bans, gates, report format |
| [`terrain-recipes.md`](terrain-recipes.md) | Real Luau for ridges, hollows, cliffs, water, caves — with the "don't do this" version |
| [`kitbash.md`](kitbash.md) | Sourcing assets, kit rules, 3-5-1 composition, variance numbers, density budget |
| [`looks-bad-audit.md`](looks-bad-audit.md) | The 5 fixed cameras, the scoring rubric, and how to compare against concept art |
| [`world-audit.lua`](world-audit.lua) | Drop-in Studio script that prints a 10-point world score and fails loudly |
| [`auralis-blueprint.md`](auralis-blueprint.md) | The actual first region: dimensions, zones, landmark list, prop budget, build checklist |
| [`art-direction-lowpoly.md`](art-direction-lowpoly.md) | **Your art is painterly, not low-poly.** What to keep, what to sacrifice, the palette measured off your 5 images, shape language, poly budgets, and 6 tricks that make low poly look expensive |
| [`mesh-prompts.md`](mesh-prompts.md) | **generate_mesh prompt library** — 25+ prompts for the Auralis kit, your style/palette/NO blocks, the mesh quality gate, and the generation order |
| [`generation-limits.md`](generation-limits.md) | **Quotas** — what Roblox actually publishes (only procedural models: 50/rolling 24 h), the unpublished `generate_mesh` cap, a 5-day 46-call kit plan that fits, 7 rules to stay inside it, and a `GenLog` instrument |
| [`generate-mesh-tool.md`](generate-mesh-tool.md) | **The tool, used properly** — every real parameter (`maxTriangles`, `textures`, `imageAssetId`, `scaleTo`…), tri budget per asset class, texture-vs-flat-colour decisions, the reference-image workflow from your own concept art, and where generation is the wrong tool |

All of it uses *your* Auralis values from `visual_themes.json` — morning light 8.9, atmosphere density 0.3, six terrain materials, water `#5fb3c4` — so it stays consistent with the repo instead of inventing a second art direction.

The five Auralis concept images I worked from are copied into [`_ref/`](_ref/) so the palette and shape rules can be checked against the source: the world panorama, Sunthread Fields meadow, Windspire pillars, Glasswater Basin, and the Buried Meadow cavern.
