# Generation limits, and how to build a region inside them

## What Roblox actually publishes

| Tool | Published limit | Reset behaviour | Source |
|---|---|---|---|
| **`generate_mesh`** | **None published.** No documented count | Not documented | Assistant docs list no number |
| **`generate_procedural_model`** | **50 per rolling 24 hours** | **Rolls continuously** — each request stops counting 24 h after you made it. There is no midnight reset | The only numbered cap in the docs |
| Assistant chat messages | No number published | Studio shows a **% of daily allowance used** in `Settings > Usage`, with a countdown ("Resets in 11 hours") | Studio UI, not docs |
| Code Assist (script suggestions) | Daily cap, **no number given** | Next day | Docs |
| Segmentation | Up to **8 parts** per generated model; `/segment_mesh` takes **5 names** per run (re-run for more) | Not a usage limit | Docs |
| `maxTriangles` | Default **10,000**; you can lower it | n/a | Docs |
| Mesh triangle ceiling | ~**20,000** per mesh; textures capped **1024×1024** | n/a | Platform limit |
| **`GenerateModelAsync` (in-experience 4D gen)** | **10 requests/min per experience**, scaling with concurrent users | Per-minute, not daily | DevForum Feb 2026 |
| Animation generation | Reportedly **4 generations per minute** per account | Per-minute | Third-party report, not docs |

**Two different things, don't mix them up:**

- **Authoring-time** (`generate_mesh` in Studio / MCP) — what you'll use to build the kit. Limit unpublished.
- **Runtime** (`GenerateModelAsync` inside a live game) — 10 req/min per experience. This is for player-generated content, not for building your world. **Do not use it to make props at runtime** — it's metered per minute and it's not how you populate a region.

---

## The uncomfortable part for an agent loop

Because the `generate_mesh` cap is **unpublished**, an agent that fires 200 prompts will not get a useful error early — it'll get silence or a generic failure at an unpredictable point, and then it will either stall or start "fixing" the problem by regenerating things, burning whatever allowance remains.

Two things follow:

1. **Measure your own limit, once.** Log every call with a timestamp. The first time it fails, you know your number and your window. It may differ by account tier and will change over time.
2. **Assume it is small — between roughly 30 and 100 per day.** Plan the kit so a day of generation produces a *finished, reusable* kit, not a half-finished one.

---

## What that means for the Auralis kit

Your kit needs **25–35 unique assets**. With retries, that's plausibly 40–70 calls.

| Day | Generate | Calls (incl. 1 retry each) |
|---|---|---:|
| **Day 1** — ground read | grass variants (procedural, **0 calls**), 2 flowers, pebble, small rock, bush | ~8 |
| **Day 2** — verticality | tree, young tree, cliff chunk ×2, outcrop | ~10 |
| **Day 3** — underground | root arch, vines, cave flower, cave mushroom | ~8 |
| **Day 4** — landmarks | Windspire, ruin wall, ruin tower, steps, arch | ~12 |
| **Day 5** — the game | Driftleaf, Sunspool, Meadowflare | ~8 |
| **Total** | **~30 assets** | **~46 calls** |

That fits inside a 50/day window — **if you don't waste calls.** Day 4 is the risky one.

**Grass and flowers cost zero calls** because you build them procedurally. That's not a coincidence — it's why §5 of `generate-mesh-tool.md` says don't generate them. They're also 55% of your instance count.

---

## Seven rules that keep you inside the quota

1. **Generate a kit, not a world.** Never generate an asset to place it once. Every mesh must be designed for 10+ placements, or it belongs in terrain/parts.
2. **The manifest is sacred.** Asset ids live in `ServerStorage.Kit` and a manifest JSON. A rebuild **reuses ids** and makes **zero** generation calls. Regenerating on every rebuild is the #1 quota killer and it also silently changes the look between builds.
3. **Reference-crop before generating, not after.** `imageAssetId` with a tight crop gives you the right silhouette on the first try. Two blind text retries cost the same as one good conditioned call and produce worse art.
4. **Never regenerate to fix scale or orientation.** Set `scaleTo` on the call. If it's wrong afterwards, fix it in Luau (`ScaleTo`, `PivotTo`) — free.
5. **Never regenerate to change colour.** `textures: false` + tint in Luau. Free, and it's how you get per-instance variance anyway.
6. **Batch by asset class, verify by screenshot.** 5 calls → wait → capture → judge. Not 25 calls → hope.
7. **Spend the last calls of the day on hero assets.** If you run out, the stone kit being done matters far more than the creature.

---

## When you hit the limit: your options

| Option | Reality |
|---|---|
| **Wait for the rolling window** | Procedural models free up one at a time, 24 h after each call. Meshes: no published reset, so treat it as "tomorrow" |
| **Check `Settings > Usage`** | Shows % of daily allowance used and a reset countdown — the only real visibility you have |
| **Do the non-generation work** | Terrain, lighting, scatter scripts, kitbash, habitat anchors, the audit. **This is most of the build** and costs nothing. Genuinely the right move |
| **Bring your own API key** | Anthropic / OpenAI / Google keys in Assistant settings. Roblox does **not** document whether this lifts generation limits — assume it does not for `/generate_mesh` |
| **"Get more usage" toggle** | Off by default. Spends Robux automatically; has its own daily Robux cap (500 was preset in one report). **Turn this on deliberately or not at all** — an agent loop with this enabled will spend your Robux without asking |
| **`generate_procedural_model`** | Has its own separate 50/24 h budget. Useful for architecture and functional props (doors, lids) where `generate_mesh` is weaker anyway |

**The trap to avoid:** an agent hitting a limit and "retrying with variations." Ten near-identical prompts that all fail cost ten more calls. If a generation fails, **stop and change the approach**, don't re-roll.

---

## Instrument it, so you're not guessing

Drop this next to your build loop:

```lua
--!strict
-- GenLog.lua — run in Studio; agent calls GenLog.record(...) after each generate_mesh
local HttpService = game:GetService("HttpService")
local LOG = script.Parent:WaitForChild("GenLogData") :: StringValue
local HISTORY: { { t: number, name: string, tris: number, class: string, ok: boolean } } = {}

local GenLog = {}

function GenLog.record(name: string, class: string, tris: number, ok: boolean)
	table.insert(HISTORY, { t = os.time(), name = name, tris = tris, class = class, ok = ok })
end

function GenLog.report(): string
	local day = 24 * 60 * 60
	local now = os.time()
	local last24, ok24, failed = 0, 0, 0
	for _, e in HISTORY do
		if now - e.t < day then
			last24 += 1
			if e.ok then ok24 += 1 else failed += 1 end
		end
	end
	local byClass: { [string]: number } = {}
	for _, e in HISTORY do
		if now - e.t < day then
			byClass[e.class] = (byClass[e.class] or 0) + 1
		end
	end
	local lines = { ("GENERATION: %d calls in last 24h (%d ok, %d failed)"):format(last24, ok24, failed) }
	for class, n in byClass do
		table.insert(lines, ("  %-12s %d"):format(class, n))
	end
	if failed / math.max(last24, 1) > 0.3 then
		table.insert(lines, "  WARNING: >30% failure rate — stop re-rolling, rewrite the prompt")
	end
	return table.concat(lines, "\n")
end

LOG.Value = HttpService:JSONEncode(HISTORY)
return GenLog
```

Run `GenLog.report()` before each batch. When `failed` climbs, that's the limiter talking, not the prompt.

---

## The one-line summary

**Only `generate_procedural_model` has a published number (50 / rolling 24 h). `generate_mesh` has none — so budget for ~30–100/day, design every asset for reuse, keep the manifest so rebuilds cost zero calls, and spend generation days only on things that can't be built from terrain, parts, or tints.**
