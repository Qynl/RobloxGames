# Debugging playbook — get out of the guess loop

The rule: **three attempts, then stop and change strategy.** Thrashing burns a day and
produces "fixes" that introduce new bugs. Every failure here has a *decisive* next step.

---

## 0. The 6-line repro (do this before touching code)

```
1. Exact steps:      join → walk to pad → click Buy
2. Expected:         rate 1.00 → 1.55, cash 10000 → 7500
3. Actual:           rate stays 1.00
4. Console:          (paste verbatim, including the stack line)
5. Changed recently: EconomyService.purchase (this session)
6. Reproducible:     yes, 10/10
```
If you can't fill this in, you're debugging a feeling, not a bug.

---

## 1. Triage table — symptom → likely cause → first probe

| Symptom | Most likely cause | First probe |
|---|---|---|
| `attempt to index nil with 'X'` | `WaitForChild` skipped, or a service loaded out of order | print the object + its `:GetFullName()` right before |
| Works in Edit, fails in Play | Client/server split wrong, or script in the wrong container | `get_studio_state`, then check where the script lives |
| Works in Play, fails for player 2 | State stored in a local, not per-player | grep `local data =` in the service |
| Numbers wrong but no error | Logic bug | print inputs at the boundary, then middle, then output |
| Everything resets on rejoin | Data not saved, or saved before mutation | check `DataService.save` call sites + ordering |
| Cash/progress duplicated | Double-fired remote, no mutex | add a `busy[player]` guard, log every entry |
| Falls through the floor | `Anchored=false`, or `CanCollide=false`, or added to a moving model | `inspect_instance` |
| Player stuck / can't move | Humanoid in a bad state, or a `BodyForce` left behind | print `Humanoid:GetState()`, list forces on root |
| Camera stuck upside down | Two systems writing `Camera.CFrame` | grep `Camera.CFrame =` |
| UI invisible on mobile | Fixed `Offset` size, or behind the notch | `screen_capture` at 360×640 |
| Lag that grows over time | Instance leak | count workspace descendants before/after |
| Lag constant and bad from the start | Too many parts, no streaming | part count + streaming props |
| Sound silent | Parented to `SoundService` instead of a part | `inspect_instance` the Sound |
| Purchase charges but nothing granted | `ProcessReceipt` returned Granted before granting | check the order of lines |
| Random flaky failure | Unseeded `Random`, or a race | seed the RNG in tests, add a mutex |

---

## 2. The bisect method (for "it broke and I don't know where")

1. `git` (or `save_place` versions) → identify the last known-good state.
2. If you're in Studio without git: comment out the last change, retest. Binary search the
   *diff*, not the feature.
3. Reduce to the smallest repro with `execute_luau (Edit)` — a 10-line snippet that shows the
   bug. If you can't reproduce it in 10 lines, you don't understand it yet.
4. Fix the snippet first, then port the fix back. This is 10× faster than editing the live
   system and guessing.

```lua
-- execute_luau (Edit): minimal repro of "purchase doesn't change rate"
local Eco = require(game.ReplicatedStorage.Shared.Config.Economy)
print("base rate lvl1", Eco.upgradeRate(1.0, 1))
print("base rate lvl2", Eco.upgradeRate(1.0, 2))   -- if these are equal, the bug is HERE
```

---

## 3. Instrument, don't stare

```lua
--!strict
-- Shared/Util/Log.lua — remove the noise, keep the signal
local Log = {}
local ENABLED = true
local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local MIN = 2

function Log.write(level: string, ...)
	if not ENABLED or (LEVELS[level] or 2) < MIN then
		return
	end
	print(`[{level}]`, ...)
end

function Log.debug(...) Log.write("debug", ...) end
function Log.info(...) Log.write("info", ...) end

-- time a scope and only report if it's slow: catches perf regressions as they appear
function Log.time(label: string, budgetMs: number, fn: () -> ())
	local start = os.clock()
	fn()
	local ms = (os.clock() - start) * 1000
	if ms > budgetMs then
		Log.write("warn", `{label} took {ms:.1f}ms (budget {budgetMs})`)
	end
end

return Log
```

Rule: logs go in **at boundaries** (remote handler entry, service call, DB write), with values.
Never `print("here")`.

---

## 4. Per-system debugging recipes

### 4.1 Remotes "not firing"
```lua
-- Server
Remotes.get("RequestPurchase").OnServerEvent:Connect(function(player, padId)
	Log.info("purchase request", player.Name, typeof(padId), tostring(padId))
	-- ...
end)
```
```lua
-- Client: prove the send happens
Log.info("firing purchase", padId, Remotes.get("RequestPurchase"))
```
If the server never sees it: the remote is created on both sides (duplicate), the client is
firing a different instance, or the client script is in `ServerScriptService` by mistake.
`script_grep "OnServerEvent"` and confirm exactly one handler per event.

### 4.2 Data "not saving"
```lua
-- Server, after load
Log.info("loaded", player.Name, "cash", data.cash, "version", data.version)
-- Server, 5 s after a change, before the periodic save
Log.info("memory state", DataService.get(player).cash)
-- Server, after save
Log.info("saved", player.Name)
```
Then rejoin and compare. If memory is right and the rejoin value is old: the save is failing
(look for the warn) or you're saving a stale copy (`table.clone` too early).

### 4.3 Character physics bugs
```lua
-- Server
local char = player.Character
local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
Log.info("state", char.Humanoid:GetState().Name)
Log.info("vel", root.AssemblyLinearVelocity)
Log.info("forces", #root:GetChildren())
for _, c in root:GetChildren() do
	if c:IsA("BodyForce") or c:IsA("VectorForce") or c:IsA("Attachment") then
		Log.info("  ", c.ClassName, c.Name)
	end
end
```
Dangling forces are the #1 cause of "player is floating/stuck" after a gravity or knockback
system. Every force you create must be destroyed on respawn.

### 4.4 Performance regression
```lua
-- Server: find the biggest heartbeat consumer by timing sections
Log.time("economy tick", 2, function() EconomyService.tick() end)
Log.time("round tick", 2, function() RoundService.tick() end)
```
Client side: MicroProfiler, look for `Render` spikes from `Instance.new` or a `Highlight`
created per frame.

### 4.5 Exploit-shaped bug ("someone has infinite cash")
1. Reproduce with a script, not by hand.
2. `script_grep "pcall"` — a swallowed error on a purchase path is usually the cause.
3. Grep every `OnServerEvent`: is there a path that skips validation?
4. Add the failing case to `Tests/Suites` as `exploit.*`, then fix.

---

## 5. The 3-attempt rule

```
Attempt 1: the obvious fix. Re-run. Paste console.
Attempt 2: the second hypothesis. Re-run. Paste console.
Attempt 3: the reduced repro. Re-run. Paste console.
STOP.
```
Then:
1. Write the failure in `GDD.JOURNAL` with the exact error.
2. Propose **two** approaches with one tradeoff each (e.g. "server raycast per hit [costs
   ~0.3 ms/hit, exact] vs. hitbox part + `Touched` [cheap, can be spoofed]").
3. Wait for the human's call, or pick the one that keeps server authority.

Why this matters: unguided retries are how a small bug becomes a refactor. The 3-attempt cap
is the cheapest productivity tool in this whole repo.

---

## 6. Debug-first checklist before you ask for help

- [ ] Reproduced 3× in a row, with a fixed method
- [ ] Console output pasted verbatim (including the stack line)
- [ ] Identified which side (client/server) the failure is on
- [ ] Printed the actual values at the failure boundary
- [ ] Reduced it to < 20 lines or a single action
- [ ] Checked `search_game_tree` that the object you're touching exists *there* and not just
      "somewhere"
- [ ] Confirmed `get_studio_state` — you're actually in play mode, and not testing Edit

If you can't tick those, the next message will waste both sides' time.

---

## 7. Failure log format (keep it in GDD.JOURNAL)

```
2026-11-17 · M2 · 22m
BUG: purchase succeeds twice on fast double-click
CAUSE: no mutex; OnServerEvent handled twice before the first save tick
FIX: per-player busy flag cleared in a task.defer
EVIDENCE: exploit.double_buy now SUMMARY 1/1; console clean
LESSON: every remote with a side effect needs an in-flight guard
```
That last line is what stops the same class of bug coming back in the next feature.
