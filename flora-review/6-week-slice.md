# The 6-week FLORA slice — the smallest build that proves the game is fun

The repo's own two-world launch plan is ~11,400–16,400 hours. This is the version a small team (or one person with AI + Studio MCP) can actually finish and put in front of strangers.

**Goal of the slice:** prove the *verb*, not the universe.

> A player walks into a strange place, notices a plant doing something alive, scans it, earns a power, and the power opens a route they couldn't take before.

If that sentence is fun, everything else in `01_Worlds/` becomes a content pipeline. If it isn't, you found out in six weeks instead of eighteen months.

---

## Scope: exactly this, nothing else

| Thing | Slice | Full repo |
|---|---|---|
| Worlds | **1** (Auralis) | 10 |
| Regions | **1** main + **1** hidden pocket | 60 |
| Plants | **3** (Driftleaf, Sunspool, Meadowflare) | 50 |
| Abilities | **6** (2 per plant) | 162 |
| Creatures | **1** (Mossback) | 10 |
| Cinematics | **1** discovery beat | many |
| Save | full, session-locked | required |
| UI | scanner, archive, ability bar | large |

Deliberately **excluded:** Myrrwood, water/Pelagora, world rotation, mastery, co-op beyond 2 players, economy, monetization, mobile low-end tier, lore.

---

## The three plants must teach three different things

| Plant | Rarity | Abilities | Teaches the player |
|---|---|---|---|
| **Driftleaf** | Natural | Softfall (slow fall) · Guststep (dash) | Movement is a power, not just walking |
| **Sunspool** | Natural | Sunthread (beam) · Warmth (reveal hidden) | Powers interact with the world, not only combat |
| **Meadowflare** | Distinct | Flare (area burst) · Bloomstep (grow a platform) | Powers change the *level*, not just the player |

That third one matters most. **Bloomstep is the proof that abilities are traversal** — a plant that lets you grow a platform is a plant that gates content, and that's the whole design thesis in one button.

---

## Week by week

### Week 1 — Measure before you build
- Greybox a **400×400 stud** region: one ridge, one hollow, one water edge, one hidden pocket behind a root tunnel.
- Apply your `visual_themes.json` Auralis record via the theme applier (your Packet 02).
- **Measure on a real mid-range phone.** Record: FPS at quality 4, memory, draw calls, streaming behaviour at sprint speed.
- Screenshot at player eye height from 5 fixed cameras; compare to the 6 existing Auralis concept images.

**Exit gate:** a documented FPS number on a real device. If it fails, change the art target *now* — this is the cheapest week you will ever have to discover that.

### Week 2 — Move and feel
- Third-person controller: walk, sprint, jump, camera. Touch + keyboard parity from day one (not retrofitted).
- Streaming enabled, `Atomic` on the region model.
- One landmark visible from spawn. One route to it. One route that's hidden.

**Exit gate:** you can run from spawn to the landmark without hitting a streaming hole, and it feels good at 30 FPS on the phone.

### Week 3 — The scan moment *(the most important week)*
- Specimen anchors in habitat positions (never scattered randomly — your own `01_Worlds` rule).
- Scanner: hold-to-scan, 1.2 s, interruptible, distance-validated server-side.
- First scan → ownership write → archive entry → **the discovery beat**: 1.5 s camera push-in, plant animation, one sound, no menu.
- Save schema v1 + session lease + a migration fixture, because a lost plant is a lost player.

**Exit gate:** scan a plant, close the server, rejoin — the plant is still owned, and the beat still plays for a second player who hasn't seen it.

### Week 4 — Abilities and authority
- Ability runtime: 6 abilities, server-validated (cooldown, ownership, range, state).
- Input layout for keyboard, gamepad, touch.
- Ability 1 unlocks **on scan** (immediate payoff). Ability 2 unlocks **on use in the world** — cast it 5 times, or once during a weather event — not from a checklist.
- VFX/audio placeholders, but *readable* ones: every ability must be identifiable from 40 studs by colour + shape.

**Exit gate:** six abilities usable, all server-authoritative, zero client-trusted cooldowns, and a hacked client firing abilities without ownership is rejected.

### Week 5 — The one encounter + the one gate
- **Mossback encounter:** one creature, three readable behaviours, two telegraphed attacks, one environmental interaction (lure it into the water), a clear win state.
- **The Bloomstep gate:** a gap only crossable by growing a platform with Meadowflare. This is the proof that the loop *closes* — a plant power opens a route to a secret.
- One hidden pocket containing the third plant.

**Exit gate:** a player who only has Driftleaf and Sunspool physically cannot cross the gap — and can *see* that they can't. That's the "come back when you're stronger" hook made visible.

### Week 6 — Prove it on strangers
- Onboarding: no tutorial text. One prompt: "scan the plant."
- 8 external playtesters, **nobody helps them.** Record: time to first scan, time to first ability use, time to first death, first confusion, and whether they ask "what do I do?"
- Fix the top 3 issues.
- Icon + 3 thumbnails + description, captured only from the slice build.
- Performance, security, and save-failure pass (kill the server mid-scan).

**Exit gate — the only gate that matters:**

| Metric | Pass |
|---|---|
| Median time to first scan | **< 90 s** |
| Median time to first ability use | **< 3 min** |
| Players who scan all 3 plants unprompted | **≥ 5 of 8** |
| Players who say "oh, cool" at the discovery beat | **≥ 5 of 8** (record it) |
| Any player lost for > 60 s with nothing to do | **0** |
| Frame rate on mid-range phone | **≥ 30** |
| Data loss across 5 join/leave cycles | **0** |

If you pass all seven, you have a game. Build the second region before the second world.

---

## What you deliberately do NOT build in these 6 weeks

- ❌ Myrrwood, Caldera Reach or any world beyond Auralis
- ❌ The other 47 plants
- ❌ More than 6 abilities
- ❌ Mastery, economy, shop, gamepasses, seasonal events
- ❌ World rotation
- ❌ 4-player co-op (2-player sync is enough to prove replication)
- ❌ Cinematic intros for worlds you haven't built
- ❌ The archive UI beyond a grid of owned plants

Every one of those is in the repo and none of them can be validated until the six-week gate passes.

---

## How this maps to your existing packets

| Your packet | Slice use |
|---|---|
| 01 Bootstrap + generated config | Week 1, unchanged — your pipeline is good |
| 02 Theme applier | Week 1, and it becomes your performance proof |
| 03 Movement/input | Week 2 |
| 04 Scanner | Week 3 — add the discovery beat |
| 05 Save | Week 3 — non-negotiable, run the failure injection now |
| 06 Research | **Rewrite** per the review: unlock-by-doing, not checklists |
| 07 Ability | Week 4, but only 6 abilities and only 3 plants' worth |
| 09 Encounter | Week 5, one creature only |
| 08 Spawn, 10 Loadout, 11 Archive, 15 Hub | Stretch — do these only if weeks 1–5 land early |
| 12 Streaming harness | Week 1 and Week 2, alongside movement |

Note what this does: **your packet list is already almost exactly a 6-week slice.** The only packets you'd defer are 10, 11 and 15, and the only one you'd rewrite is 06. Your plan is closer to shippable than it looks — the problem is that it's wrapped in a ten-world frame.

---

## The decision I'd write down first

> **D-new: FLORA 1.0 is one world, three plants, six abilities, one encounter. Ten worlds is a post-launch content program.**

Put it in `00_Overview/Decisions.md` with today's date. Everything in the 6 weeks above follows from it, and nothing else in the repo has to be deleted — the other nine worlds simply gain a label: **"post-launch backlog."**
