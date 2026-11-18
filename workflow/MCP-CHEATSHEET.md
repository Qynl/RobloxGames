# MCP call cheatsheet — exact calls for Roblox work

Copy-paste shapes for the official Studio MCP. Tool names as documented (2026); if your
client shows different names, map by capability. Always confirm state first.

> **Golden rule:** `get_studio_state` before anything that changes mode, and
> `get_console_output` after anything that runs.

---

## 0. Orientation

```jsonc
// always first
{ "tool": "get_studio_state" }
{ "tool": "list_roblox_studios" }                 // don't build in the wrong window
{ "tool": "search_game_tree", "arguments": { "path": "ServerScriptService", "depth": 3 } }
```

`search_game_tree` args you'll use: `path`, `depth`, `type` (e.g. `"Script"`), `keyword`.
Output is a flat JSON array of `{ path, className, ... }` — filter it in your head, not in your prompt.

---

## 1. Read code

```jsonc
{ "tool": "script_read", "arguments": { "path": "ServerScriptService.Services.EconomyService" } }
{ "tool": "script_read", "arguments": { "path": "....EconomyService", "startLine": 40, "endLine": 90 } }
{ "tool": "script_search", "arguments": { "query": "economy" } }        // fuzzy, max 10
{ "tool": "script_grep", "arguments": { "pattern": "Remotes%.\\w+" } }   // max 50 hits
```

**Habit:** `script_read` immediately before `multi_edit`. Never edit from memory — the
file changed last session and you're about to duplicate a helper.

Useful greps before a build:

| Grep | Finds |
|---|---|
| `pcall` | silent failure swallowing |
| `GetAsync` | unsafe DataStore reads |
| `workspace.Gravity` | global gravity hacks |
| `Heartbeat` / `RenderStepped` | loops that might spawn loops |
| `:FireClient` | broadcast where it should be targeted |
| `TODO` / `FIXME` | the previous agent's debt |

---

## 2. Edit code

```jsonc
{
  "tool": "multi_edit",
  "arguments": {
    "datamodel_type": "Edit",
    "edits": [
      {
        "path": "ServerScriptService.Services.EconomyService",
        "edits": [
          { "startLine": 12, "endLine": 18, "newText": "...replacement lines..." }
        ]
      }
    ]
  }
}
```

- Creates the script if the path doesn't exist (that's how you add new modules).
- **Keep one module per call** plus its test case. It makes failures bisectable.
- After editing, `script_read` the changed range back. Yes, really — it catches partial edits.

---

## 3. Build instances (the part agents usually fumble)

```jsonc
{
  "tool": "execute_luau",
  "arguments": {
    "datamodel_type": "Edit",
    "code": "local p = Instance.new('Part')\np.Name='TestPad'\np.Anchored=true\np.Size=Vector3.new(12,1,12)\np.Position=Vector3.new(0,50,0)\np.Parent=workspace\nprint('created', p:GetFullName(), p.Size)"
  }
}
```

Rules that make instance building reliable:

1. **One `execute_luau` per object group**, and `print` the full path of everything created.
2. Always set `Anchored = true` on static geometry. (90% of "my build fell over" is this.)
3. Parent **last** — after size/position/material — to avoid physics settling.
4. Verify immediately:
```jsonc
{ "tool": "inspect_instance", "arguments": { "path": "Workspace.TestPad" } }
```
5. Build from a **table of specs**, not 40 copy-pasted lines. Then the same function builds
   stage 2…48:

```lua
--!strict
local StageSpecs = {
	{ id = "1-1", size = Vector3.new(12, 1, 12), pos = Vector3.new(0, 50, 0), color = Color3.fromRGB(0, 200, 255) },
	{ id = "1-2", size = Vector3.new(12, 1, 12), pos = Vector3.new(0, 50, 40), color = Color3.fromRGB(255, 140, 0) },
}

local folder = Instance.new("Folder")
folder.Name = "Stages"
folder.Parent = workspace

for _, spec in StageSpecs do
	local pad = Instance.new("Part")
	pad.Name = "Start_" .. spec.id
	pad.Anchored = true
	pad.Size = spec.size
	pad.Position = spec.pos
	pad.Color = spec.color
	pad.Material = Enum.Material.Neon
	pad.Parent = folder          -- parent last
	print("built", pad:GetFullName())
end
require(script.Parent.VerifyBuild).assertStageCount(2)   -- your own gate
```

---

## 4. Assets instead of hand-modelling

```jsonc
{ "tool": "search_asset", "arguments": { "query": "supermarket shelf", "assetType": "Model", "scope": "CreatorStore" } }
{ "tool": "insert_asset", "arguments": { "assetId": 123456789, "parent": "Workspace.Map" } }

// AI-generated kit pieces (fast greybox → art)
{ "tool": "generate_mesh", "arguments": { "prompt": "low-poly oil pump jack, teal metal, Roblox style", "format": "rbxm" } }
{ "tool": "generate_procedural_model", "arguments": { "prompt": "wooden crate with planks, 4 studs", "referenceImage": "<uri>" } }
{ "tool": "wait_job_finished", "arguments": { "jobId": "..." } }        // poll this, don't sleep
{ "tool": "generate_material", "arguments": { "prompt": "rusted steel with teal paint" } }
{ "tool": "generate_animation", "arguments": { "prompt": "pump jack arm bobbing slowly", "rig": "Workspace.Kit.Pump.Rig" } }
```

Guidance:
- **Insert, don't re-model.** Handbuilding a supermarket shelf in Luau is 40 minutes for
  something a Creator Store model does better. Spend the time on the mechanic.
- **Every inserted asset needs a check:** `inspect_instance` it, then `screen_capture`.
  Free models arrive with wrong scale, unanchored parts, and 40k-triangle meshes.
- Record asset ids in `ReplicatedStorage.GDD.Assets` so a later session can find them.

---

## 5. Play, drive, observe

```jsonc
{ "tool": "start_stop_play", "arguments": { "action": "start_play" } }     // or "run_server" / "stop"
{ "tool": "get_console_output" }                                           // read BEFORE acting

{ "tool": "character_navigation", "arguments": { "to": "Workspace.Stages.Start_1_1", "speed": 1 } }
{ "tool": "user_keyboard_input", "arguments": { "actions": [
  { "type": "wait", "ms": 400 },
  { "type": "key_press", "key": "Space" },
  { "type": "wait", "ms": 300 },
  { "type": "key_press", "key": "Q" }
] } }
{ "tool": "user_mouse_input", "arguments": { "actions": [
  { "type": "move_to", "instancePath": "StarterGui.Hud.BuyButton" },
  { "type": "click" }
] } }

{ "tool": "screen_capture" }                                               // current view
{ "tool": "screen_capture", "arguments": { "position": [0, 60, -40], "lookAt": [0, 50, 0] } }
```

**Reading a screenshot properly** — answer these five, not "looks good":
1. What is the **primary silhouette**? Can I name each object from 100 studs?
2. **Scale:** is the player character visible and believable next to the build?
3. **Readability:** from here, do I know where to go next? Point at the pixel.
4. **Palette:** list the colours; flag anything off the art-direction palette.
5. **Broken:** anything floating, intersecting, unlit, inside-out, or z-fighting?

Then: `get_console_output` again. A clean screenshot with a console full of red is a fail.

---

## 6. Assert state at runtime (the real gate)

```jsonc
{
  "tool": "execute_luau",
  "arguments": {
    "datamodel_type": "Server",
    "code": "local eco = require(game.ServerScriptService.Services.EconomyService)\nlocal p = game.Players:GetPlayers()[1]\nprint('cash', eco.getCash(p))\nprint('rate', eco.getRate(p))\nprint('tier', eco.getTier(p))"
  }
}
```

Use `datamodel_type`:
| Value | Context | Use for |
|---|---|---|
| `Edit` | place, not running | building, structural asserts |
| `Server` | live server while playing | authoritative state, game logic |
| `Client` | a playtest client | UI state, camera, input handlers |

**Always print values, never return silently.** The number in the console is your proof.

---

## 7. Multi-client (mandatory for prop hunt / co-op)

1. `start_stop_play` with clients-and-server (2–4 clients).
2. `execute_luau (Client)` on client A to check its HUD; `(Server)` for the truth.
3. Drive A with `user_keyboard_input`; watch B with `screen_capture`.
4. Assert: does B see A's action? (A tag visible on B, a prop morph visible to a hunter.)

If it only works with one client, it doesn't work. This is the #1 gap in AI-built Roblox games.

---

## 8. Tests, then save

```jsonc
{
  "tool": "execute_luau",
  "arguments": {
    "datamodel_type": "Server",
    "code": "local R = require(game.ServerScriptService.Tests.TestRunner)\nlocal all = {}\nfor _, spec in pairs(game.ServerScriptService.Tests.Suites:GetChildren()) do\n  if spec:IsA('ModuleScript') then for _, c in require(spec) do table.insert(all, c) end end\nend\nprint(R.run(all))"
  }
}
```

Accept only:
```
SUMMARY 24/24
```
anything else = not done. Then:

```jsonc
{ "tool": "save_place" }
```

---

## 9. Subagents (when you have them)

```jsonc
{ "tool": "subagent", "arguments": { "type": "playtest", "task": "Run stage 1-1 ten times, report median clear time and every death cause with the hazard name." } }
{ "tool": "subagent", "arguments": { "type": "explore", "task": "Map every RemoteEvent, its sender, and whether the server validates its arguments. Report as a table." } }
```

Use `playtest` for anything that needs repetition (10 runs, 50 rounds) — it saves your context
and produces numbers you can paste.

---

## 10. Common call failures and what they mean

| Error / symptom | Cause | Fix |
|---|---|---|
| `path not found` on `script_read` | Using `/` or the DisplayName | Dot path from a service: `ServerScriptService.Services.X` |
| `multi_edit` created the wrong place | Path typo creates a new script silently | `search_game_tree` first; re-read after writing |
| `execute_luau` says not allowed on this datamodel | Wrong `datamodel_type` for current mode | `get_studio_state`, switch, retry once |
| Play mode stuck on | Previous run didn't stop | `start_stop_play` stop → `get_studio_state` → verify |
| Screenshot is black / old frame | Camera inside geometry or stale viewport | Pass explicit `position`/`lookAt`; wait a beat |
| `user_keyboard_input` does nothing | Focus isn't the game viewport | Click the viewport first (`user_mouse_input`), then keys |
| Console clean but behaviour wrong | An error swallowed by pcall | Grep `pcall`, remove the blanket one, rerun |
| Everything feels slow | Streaming disabled with a huge scene | Enable streaming; `Atomic` on stage/plot models |
