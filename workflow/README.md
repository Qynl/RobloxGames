# Building these games with the real Roblox Studio MCP

![The loop](mcp-loop.png)

This is the part that fixes "the AI says it's done and it isn't".

The official Studio MCP isn't a text generator that guesses at Roblox APIs — it's a **set of hands inside Studio**. It can read the game tree, write script source, run Luau in the live DataModel, start play mode, walk your character around, and take a screenshot of what it built. That means a build can be *closed-loop*: write → run → observe → fix → prove.

Most AI failures in Roblox look like this:

| What the AI did | Why it feels "trash" |
|---|---|
| Wrote 900 lines of Luau in one shot | Never parsed it, never ran it, 4 typos and a nil index |
| Said "the tycoon system is complete" | No `get_console_output`, no playtest, no numbers |
| Built a model by describing a hierarchy | Never took a `screen_capture`, so it can't see it's floating 40 studs off |
| Guessed API signatures from memory | `Humanoid:MoveTo` vs `MoveToFinished` vs wrong enum — plausible, wrong |
| Changed 6 things at once, one broke | No way to bisect, so it "fixes" by adding more guesses |

Every one of those is solved by a **verification gate**, not by a better prompt.

---

## 1. What the tools actually are

These are the real tool names from the official Studio MCP (as of 2026). If your client shows different names, map them by capability, not by string.

### Read / inspect
| Tool | What it does | Use it for |
|---|---|---|
| `search_game_tree` | Instance hierarchy as flat JSON, filterable by path/type/keyword/depth | "what exists right now" before touching anything |
| `inspect_instance` | All readable properties + attributes + children summary | verifying a build: sizes, positions, `Anchored`, `CanCollide` |
| `script_read` | Read a script by dot path, optional line range | re-reading before editing, never edit blind |
| `script_search` | Fuzzy find scripts by name (max 10) | find the module you forgot the path of |
| `script_grep` | Grep across all script sources (max 50 matches) | "where is this remote fired?" |
| `get_studio_state` | Play state + which DataModel types are available | **always before** `start_stop_play` |
| `get_console_output` | Studio output log | **the only acceptable proof a run was clean** |
| `list_roblox_studios` | Connected Studio windows + place ids | multi-place / multi-window safety |
| `http_get` | Fetches allowed Roblox docs pages | checking an API instead of guessing it |
| `skill` | Pulls a skill pack (debugging, device sim, docs search) | before a hard subsystem |

### Write / change
| Tool | What it does | Rules |
|---|---|---|
| `multi_edit` | Multiple edits in one call; **creates a script if the path doesn't exist**. Needs `datamodel_type: Edit` | keep each call to one module + its test |
| `execute_luau` | Runs Luau in Studio, returns result or error. `datamodel_type: Edit \| Client \| Server` | the workhorse: builds hierarchies, asserts, measures |
| `insert_asset` | Insert by asset id (model, mesh, image, audio, animation) | for kitbash props, not for core logic |
| `search_asset` | Search Creator Store + your inventory | find a tree/locker/door kit instead of hand-modeling |
| `generate_mesh` / `generate_procedural_model` / `generate_material` / `generate_animation` / `generate_avatar` | AI asset generation | concept → greybox assets fast; `wait_job_finished` to poll |
| `upload_image` / `store_image` | Upload from URL / local file, returns asset id | icons, decals, thumbnails |
| `save_place` | Save as a new place version (no dialogs) | **milestone gate**, after tests pass |

### Play / observe
| Tool | What it does | Use it for |
|---|---|---|
| `start_stop_play` | Start/stop playtest or run server | the A in the loop |
| `screen_capture` | Viewport screenshot, optional camera position/look-at | *see* the result — non-negotiable for anything visual |
| `character_navigation` | Move the player to a position/instance, speed multiplier | reach the point you need to test |
| `user_keyboard_input` / `user_mouse_input` | Key/mouse sequences, waits, UI targeting | actually play the game: press `Q`, click the buy button |
| `subagent` | `explore` (investigate) and `playtest` (run scenarios, verify outcomes) | delegate a whole test pass |

### Housekeeping
`save_place`, `list_roblox_studios`, `submit_feedback` (file a bug when a tool can't do something).

---

## 2. The loop, in the exact order that works

```
1  get_studio_state                 → are we stopped? which datamodel types?
2  search_game_tree                 → what's there NOW (never assume)
3  read the spec                    → GDD in the place (see §3) + the milestone file
4  multi_edit (one module)          → smallest change that satisfies the milestone slice
5  execute_luau (Edit)              → syntax/structure gate: assert the instance tree is right
6  start_stop_play                  → enter play mode
7  get_console_output               → ZERO errors, or back to 4
8  character_navigation + inputs    → perform the actual player action
9  execute_luau (Server)            → assert state: cash changed, checkpoint registered, heat rose
10 screen_capture                   → look at it; compare against the concept art
11 get_console_output again         → still zero errors
12 start_stop_play (stop)
13 save_place                       → only now is the milestone allowed to be "done"
```

**Why steps 5 and 9 are separate:** 5 proves the *place* is correct while stopped. 9 proves the *runtime* is correct while playing. Most AI builds only ever do 4 (write text) and then claim 6–12 happened.

---

## 3. Put the spec *inside* the place

Agents lose context between sessions. Fix that by making the design doc a first-class part of the DataModel, then telling the agent to read it from there instead of from your chat.

Recommended structure:

```
ReplicatedStorage
└── GDD                          (Folder)
    ├── 00_Overview              (ModuleScript returning a table: genre, players, pillars)
    ├── 01_Mechanics             (ModuleScript: every number in the doc, as a table)
    ├── 02_Milestones            (ModuleScript: { {id, name, tasks, acceptance}, ... })
    ├── 03_ArtDirection          (ModuleScript: palette, materials, silhouette rules)
    ├── Progress                 (Configuration)
    │   ├── M0 (BoolValue)  M1 (BoolValue)  ...   -- flipped only after acceptance passes
    │   └── CURRENT (StringValue) = "M2"
    └── JOURNAL                  (Folder of StringValues, one per session:
                                  date, what changed, what failed, next step)
```

Why this works:
- `script_read("ReplicatedStorage.GDD.01_Mechanics")` is **cheap context** and always current.
- `Progress` attributes are the agent's memory of what's actually shipped — it can't "forget" it already did persistence.
- `JOURNAL` gives you a forensic trail when something regresses, and gives the next session a starting point.

**Rule:** the numbers live in *one* module (`01_Mechanics`). Game code reads that module. If the agent changes a value in code instead of the module, that's a review rejection — it's how balancing drifts.

---

## 4. The verification harness (the actual anti-slop mechanism)

Never let the agent verify by reading its own code. Give it a **test runner in the place** and require its output.

### 4.1 `ServerScriptService/Tests/TestRunner` (ModuleScript)

```lua
--!strict
-- Deterministic test runner. Output format is contractual:
--   PASS <suite>.<case>  <detail>
--   FAIL <suite>.<case>  <reason>
--   SUMMARY <passed>/<total>
local TestRunner = {}

local results = { passed = 0, failed = 0, lines = {} }

local function record(pass: boolean, suite: string, case: string, detail: string)
	if pass then
		results.passed += 1
		table.insert(results.lines, string.format("PASS %s.%s  %s", suite, case, detail))
	else
		results.failed += 1
		table.insert(results.lines, string.format("FAIL %s.%s  %s", suite, case, detail))
	end
end

export type Case = { suite: string, case: string, run: () -> (boolean, string) }

function TestRunner.run(cases: { Case }): string
	table.clear(results.lines)
	results.passed, results.failed = 0, 0
	for _, c in cases do
		local ok, passOrErr, detail = pcall(c.run)
		if not ok then
			record(false, c.suite, c.case, "ERROR: " .. tostring(passOrErr))
		else
			record(passOrErr == true, c.suite, c.case, tostring(detail or ""))
		end
	end
	local summary = string.format("SUMMARY %d/%d", results.passed, results.passed + results.failed)
	table.insert(results.lines, summary)
	return table.concat(results.lines, "\n")
end

return TestRunner
```

### 4.2 A real test suite for a gravity system

```lua
--!strict
-- ServerScriptService/Tests/Suites/GravitySpec (ModuleScript)
local Gravity = require(game.ServerScriptService.Systems.Gravity)  -- pure logic module

return {
	{
		suite = "gravity", case = "flip_toggles_sign",
		run = function()
			local g = Gravity.new(1)          -- initial sign +1 (normal)
			g:flip(0.0)
			local a = g.sign
			g:flip(1.0)                        -- before cooldown, must be ignored
			return a == -1 and g.sign == -1, ("sign=%d"):format(g.sign)
		end,
	},
	{
		suite = "gravity", case = "cooldown_055s",
		run = function()
			local g = Gravity.new(1)
			g:flip(0.0)
			g:flip(0.54)
			local blocked = g.sign == -1
			g:flip(0.56)
			return blocked and g.sign == 1, "cooldown enforced"
		end,
	},
	{
		suite = "gravity", case = "speed_cap_40pct",
		run = function()
			local g = Gravity.new(1)
			for i = 0, 20 do g:flip(i * 1.0) end
			return g.speedMultiplier <= 1.40 + 1e-6,
				("mult=%.3f"):format(g.speedMultiplier)
		end,
	},
}
```

**The key design move:** put the *math* in pure modules (`Systems/Gravity`, `Systems/Economy`) that can be unit-tested without a character, and keep the Roblox glue thin. AI agents get physics timing wrong constantly; they get arithmetic wrong much less often. If the numbers are testable, "done" becomes provable.

### 4.3 How to invoke it through MCP

```
execute_luau {
  datamodel_type: "Server",   // while in play mode; use "Edit" for pure-logic suites
  code: "
    local Runner = require(game.ServerScriptService.Tests.TestRunner)
    local GravitySpec = require(game.ServerScriptService.Tests.Suites.GravitySpec)
    print(Runner.run(GravitySpec))
  "
}
```

Then require: **`SUMMARY n/n` with `failed == 0`**, pasted in the response. No exceptions.

---

## 5. Verification recipes per game type

### 5.1 Anything visual — the "did you actually build it" check
```
1 search_game_tree { path: "Workspace.Stages" }            -- exists?
2 inspect_instance  { path: "Workspace.Stages.W1S1.Finish" } -- anchored? size? position?
3 screen_capture { camera: { at spawn, look at finish } }   -- LOOK AT THE IMAGE
4 compare to the concept art: silhouette, palette, readable path forward
```
Then state three concrete visible facts: *"finish pad is 12 studs past the last platform; the ceiling landing zone is marked with a cyan strip; nothing floats above the skybox."* If the agent can't produce three visible facts, it didn't look.

### 5.2 Tycoon / economy — assert the numbers, not the vibe
```
execute_luau (Server) {
  -- force a deterministic state, then measure
  local plot = game.ServerScriptService.PlotService.getPlot(player)
  plot:setCash(10000)
  local rateBefore = plot:getRate()
  assert(plot:purchase("pump_2"), "purchase should succeed")
  local rateAfter = plot:getRate()
  print(("rate %0.2f -> %0.2f"):format(rateBefore, rateAfter))
  print("cash", plot:getCash())
}
```
Accept only if `rateAfter > rateBefore` by the documented amount **and** `cash == 10000 - cost` exactly. Those are the two numbers in the spec, so there is nothing to argue about.

### 5.3 Obby / movement — play it, don't describe it
```
start_stop_play (play)
character_navigation { to: "Workspace.Stages.W1S1.Start", speed: 1 }
user_keyboard_input { actions: [ {type:"key_press", key:"Space"}, {type:"wait", ms:300}, {type:"key_press", key:"Q"} ] }
execute_luau (Server) { print("gravitySign", workspace:GetAttribute("PlayerGravitySign")) }
screen_capture {}
get_console_output {}
start_stop_play (stop)
```
Accept only if the screenshot shows the player on the ceiling **and** the console is empty. A flip that works in code but leaves you staring at an upside-down world is still a fail.

### 5.4 Multiplayer systems — two clients or it doesn't count
For prop hunt / horror / co-op, one test client is worthless. Use the Studio "clients and server" mode, then:
- Start playtest with 2+ clients.
- Drive client A with `user_keyboard_input`, and assert server state with `execute_luau (Server)`.
- Then assert client B *saw* it (a `screen_capture` from B, or a `Client` datamodel assert).
This is where "works on my machine" AI builds die. Make it a milestone gate, not an afterthought.

### 5.5 Performance — measure, then refuse
```
execute_luau (Server) {
  -- crude but honest: sample heartbeat over 3 s with 20 bots
  local t0 = os.clock(); local n = 0
  task.spawn(function() while os.clock() - t0 < 3 do n += 1; task.wait() end end)
  task.wait(3.2)
  print(string.format("server ticks in 3s: %d", n))   -- health check, not a profiler
}
```
Better: use the built-in MicroProfiler for a real budget. But even this crude number catches the classic AI bug of a `RunService.Heartbeat` loop that spawns another loop.

---

## 6. The milestone contract (paste this into your prompt)

```
WORKING AGREEMENT — read before every milestone.

1. Read ReplicatedStorage.GDD.02_Milestones and the milestone I name. Do not
   implement anything outside it. If something else is broken, write it in
   ReplicatedStorage.GDD.JOURNAL and continue.
2. One module per multi_edit call, plus its test case in Tests/Suites.
3. After writing code you must, in this order:
   a. execute_luau (Edit) asserting the instance tree you claim to have made
   b. start_stop_play → get_console_output → must be ZERO errors
   c. perform the player action with character_navigation / user_*_input
   d. execute_luau (Server) asserting the state numbers in the spec
   e. screen_capture and tell me 3 concrete visible facts about it
   f. get_console_output again → still zero errors
   g. start_stop_play (stop) → save_place
4. Report: what changed (paths), the PASS/FAIL summary lines, the three visible
   facts, and any number that missed the spec by more than 5%.
5. You may not use the words "should", "likely", "probably" about behaviour.
   Run it or don't claim it.
6. If a tool call fails twice, stop and report the exact error. Do not thrash.
7. Only flip Progress.<Milestone> to true after 3–7 all pass. Then append a
   JOURNAL entry: date, files, summary result, next step.
```

Why point 5 matters: models narrate success. Banning hedging language removes the escape hatch that lets them narrate instead of test.

---

## 7. Red flags in the agent's own report

Check for these; each one means "not actually done".

| Red flag in the reply | What it means | What to say |
|---|---|---|
| No `get_console_output` output | Never ran anything | "Run it and paste the console." |
| "I've created the system" with no paths | Probably one file, probably broken | "List every instance path you created and `inspect_instance` one." |
| No `screen_capture` on visual work | Hasn't seen it | "Screenshot from the spawn looking at the goal." |
| Test summary missing `SUMMARY` line | Tests don't run / were skipped | "Paste the literal SUMMARY line." |
| Changed 5 files for a 1-line feature | Scope creep | Revert to the milestone's file list |
| Uses an API you've never seen | Hallucinated signature | "`http_get` the class page and confirm the property name." |
| "Works now" after a fix with no re-test | Fixed by guessing | "Re-run the failing case only." |
| Silent `pcall` everywhere | Errors hidden instead of handled | "Remove silent pcall; let the error surface in the console." |

---

## 8. Session hygiene

- **One Studio window per task.** Check `list_roblox_studios`; two windows with the same place name is how work gets lost.
- **`save_place` before every milestone** and after every green run. Version history is your undo.
- **Fresh session = re-read the GDD + JOURNAL**, not a summary written by the previous agent (it will be flattering and wrong).
- **Keep the place small enough to test fast.** A 40-minute playtest per change means nobody iterates. Greybox first, art second.
- **Never let the agent "polish" an untested system.** Polish on a broken base hides the break.
- **Freeze scope with numbers.** If the milestone says 8 stages, "about 8" is 8. Count them with `search_game_tree`.

---

## 9. What to do when it's genuinely stuck

1. Ask for the **exact tool call and the exact error** (`code`, not prose).
2. `http_get` the API page and have it quote the signature.
3. Reduce to the smallest repro: `execute_luau (Edit)` a 10-line snippet that shows the bug.
4. If it's a physics/interaction bug, ask for **two** screenshots — before and after — plus the numbers.
5. If it's still stuck after 3 attempts, tell it to stop, write a JOURNAL entry, and propose two alternative approaches with a tradeoff each. Then *you* pick.

That's cheaper than a 4th round of "try this instead" guesses, which is exactly the loop you said you were tired of.

---

## 10. Copy-paste prompt kit

See [`PROMPTS.md`](PROMPTS.md) for the session-start prompt, per-milestone prompt, "prove it" prompt, debugging prompt, and the one-shot "review my whole game against the GDD" audit prompt.
