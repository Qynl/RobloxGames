# FLORA: BEYOND THE ORIGINS

This repo is now **one game**: FLORA (full title *FLORA: BEYOND THE ORIGINS*). The earlier batch of five concept ideas and both ideation rounds are deleted.

Third-person exploration adventure. You prepare a loadout, enter a world, find a plant in its habitat, and **scan it** — the scan permanently grants the plant's whole ability set, which you then research and unlock one ability at a time. Abilities carry you through traversal and combat; clues from scanning lead deeper.

**Rarity ladder:** Natural → Unusual → Distinct → Ancient → Forgotten → Relic → Origin (set sizes 2 → 4+, and Natural must stay useful at every tier).

10 worlds × (3 major biomes + 3 hidden sub-biomes). Mornings, haze, moss, and one cyan accent.

---

## What's in here

| Path | What it is |
|---|---|
| [`flora-world/`](flora-world/) | **Start here.** Everything needed to make the world actually look good — art direction, `generate_mesh` prompts and tool usage, quotas, terrain, kitbashing, blueprint, audit script |
| [`flora-review/`](flora-review/) | Honest audit of the FLORA planning repo: scope math, the missing acquisition plan, the research-loop risk, and six ranked changes |
| [`workflow/`](workflow/) | Generic agent kit for the official Roblox Studio MCP — system prompt, MCP call cheatsheet, engineering rules, Luau patterns, QA gates, debugging playbook, GDD template |

---

## Build order

**World first → abilities second → everything else**, at your own pace. No phase gates.

The single most useful rule from `flora-world/`: *almost nothing that makes the concept art look good is polygon count.* Light, palette, silhouette, and density of small things carry the look — which is why the build starts with lighting and biome shape, not with a hero asset.

## Where to start

1. [`flora-world/README.md`](flora-world/README.md) — why agent-built worlds look bad, and the 10-step order that fixes it
2. [`flora-world/art-direction-lowpoly.md`](flora-world/art-direction-lowpoly.md) — what to keep and what to give up from the concept art
3. [`flora-world/generate-mesh-tool.md`](flora-world/generate-mesh-tool.md) — the tool's real parameters, and where generation is the wrong tool
