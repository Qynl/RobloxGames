# FLORA: BEYOND THE ORIGINS — review of `feature/flora-game-planning`

Reviewed: branch `feature/flora-game-planning` of `Qynl/AvenorPlanning`
Scope: 1,069 files, ~124,000 words, 78 concept images, 7 JSON data exports
Verdict in one line: **the planning is genuinely better than most funded studios produce; the plan is also 3–8 years of work for a team, and it's missing the two things that decide whether anyone ever plays it.**

---

## 1. What's actually there (counted, not estimated)

| Layer | Count | State |
|---|---:|---|
| Worlds specified | 10 | prose, each with 3 biomes + 3 sub-biomes |
| Regions named | 60 | descriptions, no layouts |
| Plants | 50 | full pages, habitat + clue + ordered ability set |
| Ability sets | 50 | one per plant |
| Ability specs | 162 | **all 162 still contain `TBD`** |
| Creatures | 10 | identity + art cues, no combat data |
| Concept art | 78 images | 54/60 regions have a hero view |
| Data exports | 7 JSON + generator | `generate.mjs` → Luau configs |
| Luau code | **0 lines** | no project, no place, no scripts |
| Plan docs | ~14 system docs + 10 production docs | genuinely strong |

The repository's **own** audit (`GameplanningFreebuff/02_Content_Readiness.md`) already says this honestly: *"The design is broad and unusually well structured. The game does not exist yet."* That self-awareness is the single most valuable thing in the repo, and it's rare.

**What's unusually good, specifically:**

1. **The scan → own → research → unlock split is a real invention.** It separates *acquisition* from *mastery*, which means finding a plant feels permanent, and research can't re-take it. Most collection games have one meter; you have two, and they mean different things.
2. **The rarity ladder has set sizes attached** (Natural 2 → Origin 4+) and a stated balance rule: *"Natural plants must remain useful, and rare plants must not be mandatory for basic progression."* That sentence prevents the most common failure in this genre.
3. **`09_Agent_Task_Packets.md`** is the best document in the repo. Dependency graph, one packet per task, explicit acceptance criteria, and the instruction *"Never say tested when you only compiled or inspected."* That's the discipline most AI-driven projects never get.
4. **The risk register names its own killers.** R1 "the ten-world trap," R5 "the save is the game," R18 crunch. A plan that argues against its own scope is a plan written by someone thinking clearly.
5. **The data pipeline exists.** 7 JSON files + a generator that emits Luau configs means content is data, not hand-copied constants. That's the right architecture on day 4 instead of day 400.

---

## 2. The three things that will actually kill it

Everything below is *not* in the register, or is in the register but under-weighted.

### Kill 1 — Scope, in units of human years

Your own production plan is honest about this: **~11,400–16,400 hours for a two-world launch** ≈ 5.7–8.2 person-years, with an 8-person team over 18 months. The full 10-world vision is **21–31 person-years**.

A solo dev (or solo + AI) at 20 productive hours a week and, optimistically, 2× AI leverage, is still looking at **12–24 months** for the two-world launch plan — and that's with the vertical slice alone taking 12 weeks before a single outside player sees anything.

That doesn't mean the idea is wrong. It means **the launch scope in the repo is a studio launch, and the repo is not a studio yet.** The design can stay huge; the *first release* has to be small enough to finish. See [`6-week-slice.md`](6-week-slice.md) for what "small" means with your actual content.

### Kill 2 — There is no acquisition plan, at all

I grepped the whole repo. "Retention", "D1", "thumbnail" and "CTR" appear in **zero planning documents** (the only hits are plant names and prompt text). There is no document anywhere about:

- how a player finds FLORA on Roblox,
- what the icon and three thumbnails look like,
- what happens in the first 60 seconds,
- why a player comes back on day 2,
- how "10 enormous worlds" is even communicated to a 12-year-old scrolling a phone.

That's fatal in a specific way: **Roblox discovery is a per-user engagement auction.** The home-feed algorithm only promotes games whose *organic* players (from Recommended For You) stay and return. A new game gets one 72–96 hour test window, then a second boost if it clears an engagement threshold. Nothing in a beautiful 18-month plan changes that you get judged on minute 3 of day 1.

And the two decisions that most affect that judgement — the thumbnail and the first 90 seconds — are currently unowned.

### Kill 3 — The research loop is at risk of becoming the chore it says to avoid

The repo says, correctly: *"Do not turn every plant into the same checklist"* and *"Research should feel like exploration and learning, not repetitive chores."*

But the *mechanics* as specified make that hard to honour:

> First scan **grants ownership of the complete ability set**. Further research **unlocks the abilities one by one.**

So the player is told "this whole set is yours" — and then has to do N tasks before they can use 2/3 of what they already own. The reward was given and then taken back as a task list. If the research tasks are lightweight (observe it in wind, see it rain), that's a nice bit of texture. If they're 3 milestones per plant × 50 plants, it's a 150-step checklist between the player and the thing they already earned.

**Fix (pick one):**

- **A. Make research optional depth, not a gate.** First scan unlocks ability 1 immediately. Abilities 2–4 unlock by *using* the plant in the world (cast it 5 times, use it in 3 different biomes, use it during a storm). Learning by doing, no checklist UI, and it teaches mastery at the same time.
- **B. Make each unlock a new verb the world then tests.** Unlock order must map to *escalating situations*, not to arbitrary tasks: ability 2 is required to cross a gap that ability 1 can't. Then research is a key, not a chore, because the world is waiting for it.
- **C. Split the set.** Scan grants the whole set *as collection*, but the player equips a slot budget — so they must choose 3 of 4 abilities. Unlocks add flexibility, not power, and choosing becomes the interesting part.

Whichever you pick, write it into `04_Systems/Scanning_Research/README.md`, because right now the two documents disagree in spirit even if they agree in letter.

---

## 3. Six design changes I'd make, ranked by cost-to-impact

| # | Change | Cost | Why |
|---|---|---|---|
| 1 | **Seed 2 high-rarity plants in the starter world as secrets** | **Near zero** | Your rarest plants currently live in worlds 3–10, so a brand-new player's entire first week is Natural/Unusual. In this genre the *story* is "I found a Relic in the beginner zone." Put one Forgotten-tier plant in Auralis behind an observation puzzle, and one Relic behind a weather event. Now day-1 has a jackpot moment. Nobody has to build a new world for it. |
| 2 | **Let ability unlocks happen in-world, not in menus** | Low | Trigger unlocks on a world action (see Kill 3, option A). Kills the checklist feel, keeps the loop inside the game. |
| 3 | **Add a "first 90 seconds" spec as a hard requirement** | Low | Currently the first playable moment is: spawn → walk → find a plant. That's a 3-minute silence. You need one *visible weird plant event* within 20 seconds of spawning (a plant reacting to the player, a gust, a glow). This is the cheapest retention win available. |
| 4 | **Replace "stylized realism" with "stylized, readable"** | **Negative cost (saves money)** | Stylized realism is the most expensive art target on Roblox: real lighting, PBR materials, dense foliage, all fighting a mobile GPU. Your own R4 risk is exactly this. A harder *silhouette* and simpler materials reads better on a phone thumbnail and costs a third as much. Keep the palettes from the 78 concepts; drop the realism bar. |
| 5 | **Cut the ability count for 1.0 from 162 to ~18** | Saves ~3 months | 2 worlds × 5 plants × 2 abilities = 20, and 162 is a 5-year content backlog. Your plan already caps launch at 30 — go further. Fewer, better abilities are also *more* readable in combat. |
| 6 | **Greybox one region in week 2, on a phone, before anything else** | Low | Your Phase 0 exit gate is a 400×400 test region. Good. Do it before the tooling, before the data pipeline, before the second world. It's the only measurement that can save you from the mobile risk, and it's cheap now and expensive later. |

---

## 4. What's missing that I'd add to the repo

| Missing document | Why it matters | Where it belongs |
|---|---|---|
| **Acquisition & first-session spec** | Icon, 3 thumbnails, title, description, first 60 s, day-2 hook, launch-week plan | `08_Marketing/` — doesn't exist |
| **Combat target model** | Health, damage, telegraph timing, defeat rules, encounter durations | `04_Systems/Combat/` flags this as TBD; it blocks the vertical slice |
| **Ability role pass** | 66 abilities have no confirmed role; you cannot implement a runtime for a flavour label | flagged as R2/D5 — do it before any ability code |
| **A "what a solo/small team can ship" variant** | The 8-FTE plan is unbuildable alone, and the repo has no smaller path | `06_Production/` — see next file |
| **Performance acceptance numbers per device** | "30 FPS on mid-range phone" needs a device list, settings matrix and a pass/fail protocol | `07_Technical/` has budgets; needs the test protocol |
| **Live-ops/event plan post-launch** | Your R15 says no rotation at 1.0 — then what brings people back in month 2? | `06_Production/` |

---

## 5. The honest strategic read

**Do not build FLORA as written.** Not because it's bad — because the plan's own numbers say it's a 6-to-30-person-year product, and if you start at the top of the ambition you will spend eighteen months on world four while world one still has no encounter, no save migration and no phone proof. That's R1, in your own words.

**Do build FLORA's *core verb*.** The verb is: *creep through a strange landscape, notice something alive doing something unexpected, scan it, and gain a power that changes how you move.* That verb is shippable in 6–8 weeks in one region with 3 plants and 6 abilities — and if it's fun there, everything else in this repository becomes a content pipeline instead of a hope.

The repo is a better design document than most games ship with. What it needs now is not more design. It needs:
1. one region nobody can walk through without screenshotting it,
2. one plant whose scan moment makes a player say "oh *that's* what this game is,"
3. one measured frame on a real phone,
4. and a thumbnail.

Everything else in these 1,069 files is content waiting for those four things to be true.

---

## 6. Where my `workflow/` kit fits

Your `plan/AI_MASTER_INSTRUCTIONS.md` and `09_Agent_Task_Packets.md` already encode most of the discipline I'd push for — labelling CONFIRMED/PROPOSED/OPEN, "never say tested when you only inspected," one packet at a time, required completion report. It's better than what most repos have.

The two things mine adds that yours doesn't:

1. **A verification loop that a Studio-MCP agent can actually execute** — `execute_luau` asserts, `start_stop_play`, `get_console_output` must be empty, `screen_capture` + 3 visible facts, then `save_place`. Your packets end at "Studio playtest for script errors"; mine end at "here is the number and here is the screenshot."
2. **A playtest gate on the *engaged* material**, not just the engineering: does a player who has never seen FLORA find a plant, scan it, and unlock an ability without help. That's the packet your repo most needs and doesn't have.

If you want, I'll write FLORA-flavoured versions of those packets that follow your naming and your CONFIRMED/PROPOSED/OPEN rules, so they drop straight into `GameplanningFreebuff/09_Agent_Task_Packets.md` without fighting it.
