# The "looks bad" audit — making quality measurable

You cannot review what you cannot see, and an agent will never look unprompted. This is the cheapest quality system in the whole repo: **five fixed cameras, ten checks, one score.**

---

## 1. The five fixed cameras

Place these once per region. Every build step re-shoots from the same five spots so you can compare before/after.

```lua
--!strict
-- ServerScriptService/Tools/AuditCameras.lua
return {
	{ name = "spawn_eye",      position = Vector3.new(0, 8, 120),     lookAt = Vector3.new(0, 12, -60) },
	{ name = "route_mid",      position = Vector3.new(-120, 10, 20),  lookAt = Vector3.new(60, 14, -120) },
	{ name = "landmark_far",   position = Vector3.new(240, 26, 200),  lookAt = Vector3.new(0, 30, -120) },
	{ name = "hollow_inside",  position = Vector3.new(-40, 6, 60),   lookAt = Vector3.new(-110, 10, 20) },
	{ name = "aerial_overview",position = Vector3.new(0, 300, 420),  lookAt = Vector3.new(0, 20, 0) },
}
```

```jsonc
{ "tool": "screen_capture", "arguments": { "position": [0, 8, 120], "lookAt": [0, 12, -60] } }
```

**Shoot all five every time.** One camera lies: a close-up hides bad composition, an aerial hides bad ground detail. Five cameras catch everything.

**Comparison rule:** keep the five shots from step 2 (macro terrain) in a folder. If step 7 (small detail) doesn't visibly improve shots 1 and 2, you spent effort in the wrong place.

---

## 2. The ten checks (each is pass/fail with a number)

| # | Check | Pass | How to verify |
|---|---|---|---|
| 1 | Terrain materials | **≥ 6 distinct** | `ReadVoxels` count from `terrain-recipes.md` §0 |
| 2 | Landform made of terrain, not parts | **0 parts > 40 studs tall** that are landscape | `search_game_tree` then filter `Part` by size |
| 3 | Lighting applied | Atmosphere + ColorCorrection + Bloom exist; `ClockTime` ≈ 8.9 | `inspect_instance Lighting` |
| 4 | No default materials on big surfaces | **0** surfaces > 4 studs with Plastic/SmoothPlastic | script in `world-audit.lua` |
| 5 | Nothing floating | **0** props whose bottom is > 1 stud off the ground | `world-audit.lua` raycast |
| 6 | Scale variance | prop scale range **≥ 0.7–1.4** | `world-audit.lua` |
| 7 | Composition | 1 hero + 2 secondary anchors visible in `landmark_far` | screenshot |
| 8 | Density falloff | detail zone ≥ 40/100², hinterland ≤ 12/100² | `world-audit.lua` |
| 9 | Readability | route from spawn identifiable in `spawn_eye` **without** UI | screenshot, ask a stranger |
| 10 | Palette match | dominant colours within the Auralis palette | compare to concept art |

**Score = checks passed.** Below 7 the region is a greybox, whatever the file count says. Report the number, not a feeling.

---

## 3. Comparing to the concept art (do this properly)

You have 6 Auralis concept images. Comparing "does it look like the art" by eye is useless. Do this instead:

1. Open the concept image and the `landmark_far` screenshot side by side.
2. Write down the **three dominant colours** in each (rough hex is fine).
3. Write down the **one silhouette feature** in each (e.g. "a leaning spire with a notch").
4. Answer three questions:
   - Does the build have the same **value structure** (dark foreground / bright distance, or the reverse)?
   - Does the build have **one** dominant silhouette like the art, or several competing ones?
   - Is the palette **warmer, cooler, or the same**? Note the difference.

**The most common mismatch is not colour — it's emptiness.** Concept art is dense because an artist painted 400 brushstrokes. The build has 12 trees. When comparing, ask "how much *stuff* is in the frame per square stud" and match that, not just the hue.

---

## 4. The 60-second human test

Do this after every milestone, with someone who hasn't seen the build:

| Ask | Good answer | Bad answer |
|---|---|---|
| "What is this place?" | "A windy meadow with a big rock spire" | "A test level" |
| "Where would you go?" | points at the route | "Um, anywhere?" |
| "Does it look finished?" | "Yeah" | "It looks like a prototype" |
| "Would you screenshot this?" | "Maybe from up there" | "No" |

If a stranger can't name the place in one sentence, **the region has no identity yet** — the props are fine, the composition isn't. Go back to step 4 (landmarks).

---

## 5. What "good" actually looks like at each step

This is the reference so neither you nor the agent argues about taste.

| Step | It should look like | It must not look like |
|---|---|---|
| 1 Lighting | Golden morning, soft long shadows, blue-grey haze in the distance | Grey, flat, hard black shadows |
| 2 Macro terrain | Ridge and hollow readable as lumps; a horizon line that isn't a straight edge | A flat plane |
| 3 Materials | Green meadow, tan shore, grey rock faces, brown hollow floor | One green everywhere |
| 4 Landmarks | One big thing pulling the eye, two smaller ones framing it | Random lumps of equal size |
| 5 Kitbash big | Rocks and trees that read as silhouettes from 100 studs | Cubes, or nothing |
| 6 Medium props | Groves and outcrops with gaps between them | Evenly-spaced wallpaper |
| 7 Small detail | The ground near your feet is textured and broken up | A bare green plane |
| 8 Route | You can walk from A to B and see something new every 15 seconds | A straight corridor or a maze |
| 9 Anchors | Plants in plausible habitats | Plants scattered randomly |
| 10 Final | Five screenshots you'd put in a store page | Five screenshots you'd apologise for |

---

## 6. The one thing to remember

An agent that **places good assets on good terrain with applied lighting and varied scale** will beat a hand-modelled world 9 times out of 10 — and it can do it in an afternoon. An agent that **models from primitives** will produce the same ugly box field every time, no matter how good the plan is.

The audit exists to make the difference visible before a player sees it.
