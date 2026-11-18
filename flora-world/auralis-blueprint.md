# Auralis, first region — an actual blueprint

Build this before anything else. Not the whole world: **one region** (~900 × 900 studs) that contains everything the loop needs.

Uses your own `01_Worlds/auralis/README.md` identity (open grasslands, warm light, enormous horizons) and your `visual_themes.json` values. Nothing invented.

---

## 1. The shape

```
                          N
              ┌───────────────────────┐
              │   WINDWARD RIDGE      │   rock, 90 studs, runs E–W
              │   ▲ hero spire (X)    │   ← the thing you see from spawn
              └───────────────────────┘
   ┌──────────────────────────────────────────┐
   │                                          │
 W │   WINDSTEP PRAIRIE (open, windy)         │  E
   │        · Driftleaf anchors on the crest  │
   │                                          │
   │        THE WHISPERING HOLLOW             │  ← bowl, wind tone, mud floor
   │        (sub-biome 1)                     │
   │            · Meadowflare at warm vents   │
   │                                          │
   │   GLASSWATER BASIN (shallow lake)        │
   │        · Sunspool on the sunny shore     │
   └──────────────────────────────────────────┘
                          S    spawn
```

| Zone | Centre (studs) | Radius | Ground | Contents |
|---|---|---|---|---|
| Spawn terrace | `(0, 8, 120)` | 60 | Grass | spawn pad, first sightline to the spire |
| Windstep Prairie | `(0, 6, -60)` | 260 | Grass + LeafyGrass | rolling slopes, Driftleaf crests |
| Windward Ridge | runs `(-320,-190)` → `(320,-150)` | — | Rock | hero spire at `(40, ?, -175)` |
| Whispering Hollow | `(-40, 5, 40)` | 75 | Mud | wind tone, sheltered pocket, vents |
| Glasswater Basin | `(-260, 2, 210)` | 110 | Sand / Mud / Water | shore, reeds, Sunspool |
| Buried Meadow | cave `(150,-18,-120)` → `(240,-8,-60)` | 16 tunnel | Ground | hidden pocket, third plant |

**Scale sanity:** 900 studs is roughly 12 seconds of sprint across. That's small on purpose. A region you can cross in 12 seconds still takes 3 days to make look good; 6 enormous regions will not get made.

---

## 2. The landmark list (build these or it will look like a field)

| # | Landmark | Size | Where | Why it exists |
|---|---|---:|---|---|
| 1 | **The Windward Spire** | 90 studs tall, 24 wide, leaning 8° | `(40, ridge, -175)` | The silhouette. Must be visible from spawn and from the hollow |
| 2 | The Fallen Arch | 34 × 22 × 12 | `(-150, 4, -100)` | Frames the route north; a secondary anchor |
| 3 | The Drowned Well | 12 wide, 6 tall | `(-210, 3, 170)` | Shoreline anchor, hints at the buried meadow |
| 4 | Root Arch (cave mouth) | 18 × 14 | `(150, 2, -120)` | The entrance to the hidden pocket — must read as a way in |
| 5 | The Wind Stones | 5 stones, 6–9 studs | `(-40, 6, 40)` ring around hollow | Explains the wind tone; Meadowflare habitat |

Five named objects. If you can't list five, the region isn't composed — it's scattered.

---

## 3. Prop budget (per zone, so it can't balloon)

| Zone | Trees | Bushes | Rocks | Grass tufts | Flowers | Total props |
|---|---:|---:|---:|---:|---:|---:|
| Spawn terrace | 6 | 10 | 8 | 180 | 40 | ~244 |
| Prairie | 40 | 70 | 45 | 1,400 | 260 | ~1,815 |
| Ridge | 8 | 12 | 90 | 200 | 20 | ~330 |
| Hollow | 14 | 26 | 30 | 420 | 90 | ~580 |
| Basin shore | 10 | 18 | 55 | 700 | 160 | ~943 |
| Buried meadow (cave) | 0 | 6 | 14 | 60 | 30 (glowing) | ~110 |
| **Total** | **78** | **142** | **242** | **2,960** | **600** | **~4,022** |

Notes that matter:
- **2,960 grass tufts** is correct and cheap — they're tiny meshes and they do more for "finished" than anything else on this list.
- **78 trees** across 900×900 studs is a sparse, breezy meadow, which is exactly Auralis. A forest would be 400+.
- Rocks cluster **on slopes and at the ridge base**, never evenly.
- The cave gets almost nothing but the glowing flowers, and that's what makes it feel different.

---

## 4. Build checklist, in order (each line is a gate)

```
[ ] 1  Apply Auralis lighting record. Screenshot empty baseplate. → looks like morning?
[ ] 2  Terrain: base plateau + ridge + hollow + basin + cave. Screenshot aerial. → silhouette?
[ ] 3  Six terrain materials painted by height/slope. → ReadVoxels says >= 6?
[ ] 4  Hero spire + 4 landmarks placed (terrain + one mesh each). → visible from spawn?
[ ] 5  Insert kit: 4 trees, 3 bushes, 5 rocks, 2 root arches, 2 grass, 2 flowers, 2 ruins
[ ] 6  Scatter layer 1 (trees, big rocks) with variance. → scale 0.7–1.6, tilt ±10°?
[ ] 7  Scatter layer 2 (bushes, medium rocks) with clustering. → gaps between clusters?
[ ] 8  Scatter layer 3 (grass tufts, flowers, pebbles). → no bare ground within 20 studs?
[ ] 9  Path decals: spawn → prairie → hollow → basin
[ ] 10 Walk the route. Screenshot the 5 audit cameras. Run world-audit.lua.
[ ] 11 Place 3 plant anchors by habitat. Screenshot each.
[ ] 12 Re-run audit. → 10/10 and 5 screenshots you'd show someone
```

---

## 5. The three plant anchors (habitat logic, not scatter)

| Plant | Habitat | Exact placement rule | Why it reads as real |
|---|---|---|---|
| **Driftleaf** | Ridge crest, wind-exposed | On the ridge top where the slope faces the prevailing wind, in patches of 6–12, never in the hollow | The player sees them leaning before a gust — the discovery clue *is* the placement |
| **Sunspool** | Open sunny meadow / basin shore | In full sun, 8–20 studs from the waterline, clustered, with clear sky above | Seed-heads follow the sun; a shaded one looks wrong, which teaches the rule |
| **Meadowflare** | The hollow's warm vents | Within 14 studs of a vent, on the mud, in groups of 3–5 | Heat-loving plant next to heat source = ecology the player can *infer* |

**The rule:** if a player could guess where a plant lives before seeing it, the placement is doing narrative work. If they can't, it's wallpaper.

---

## 6. What this region deliberately excludes

- ❌ The other 4 Auralis plants (build them after the abilities exist)
- ❌ Creatures and encounters (next phase)
- ❌ The full 900×900 "enormous" scale — this is a first region, not the world
- ❌ Weather events, world rotation, cinematic intros
- ❌ Any ability or scan code (world first, at your pace)

---

## 7. Time estimate, honestly

| Step | One person, no AI | One person + Studio MCP agent |
|---|---:|---:|
| 1–3 Lighting + terrain + materials | 4 h | 1.5 h |
| 4 Landmarks | 6 h | 3 h |
| 5 Kit sourcing + sanitising | 5 h | 2 h |
| 6–8 Scatter + detail | 10 h | 3 h |
| 9–10 Paths, route, audit | 4 h | 2 h |
| 11–12 Anchors + final pass | 4 h | 2 h |
| **Total** | **~33 h** | **~13.5 h** |

The agent doesn't save time on *deciding* the landmark list or judging the screenshots. It saves time on the 4,000 placement decisions — which is exactly where it was losing you quality, because it was inventing geometry instead of placing it.
