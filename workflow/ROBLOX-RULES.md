# Roblox engineering rules — the ones that actually bite

Everything here is a rule that, when broken, produces the specific bug you'll spend a day on.
Read this once before building; skim the table before a milestone.

---

## 1. Server vs client (the exploit layer)

**Rule:** the client is an adversary with a nice UI. It sends *intent*; the server decides *results*.

| Never trust | Instead |
|---|---|
| `elapsed` time from the client | `os.clock()` diff on the server, started at run start |
| "I finished the stage" | server checks checkpoint order + minimum duration |
| `CFrame` / position | server reads `HumanoidRootPart.Position`; distance checks on interaction |
| "I have 5000 cash" | server owns cash in a table; client only renders |
| "I harvested this crop" | server checks `plantedAt + growTime` |
| "I hit that prop" | server raycast + distance + LOS |
| "I own that cosmetic" | `DataService` ownership check on equip and on use |

```lua
--!strict
-- The pattern for every remote. Copy it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local lastCall: { [Player]: number } = {}

local function rateLimited(player: Player, minInterval: number): boolean
	local now = os.clock()
	local last = lastCall[player] or 0
	if now - last < minInterval then
		return true
	end
	lastCall[player] = now
	return false
end

Remotes.Purchase.OnServerEvent:Connect(function(player, padId)
	if typeof(padId) ~= "string" or #padId > 40 then
		return -- bad type: drop silently, do not error loudly
	end
	if rateLimited(player, 0.1) then
		return
	end
	local ok, err = pcall(function()
		EconomyService.purchase(player, padId)   -- all validation lives in here
	end)
	if not ok then
		warn(`[Purchase] {player.Name}: {err}`)  -- log, never swallow silently
	end
end)
```

**Distance validation, always:**
```lua
local function nearEnough(player: Player, target: BasePart, maxStuds: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return (root.Position - target.Position).Magnitude <= maxStuds
end
```

---

## 2. Character control (where AI builds break constantly)

### 2.1 Movement
```lua
local hum = character:WaitForChild("Humanoid")
hum.WalkSpeed = 18
hum.JumpPower = 50
hum.UseJumpPower = true          -- JumpHeight is ignored unless this is false
```
- Modify speed **server-side**. A client change is reverted or ignored and causes "my speed resets" bugs.
- Never scale the Humanoid for size. Use a separate hitbox `Part` and keep the Humanoid honest.

### 2.2 Gravity flip (per-player, never global)
```lua
--!strict
-- Server: per-character gravity reversal via force, not workspace.Gravity
local function applyGravity(root: BasePart, sign: number)
	local existing = root:FindFirstChild("GravityForce")
	if existing then
		existing:Destroy()
	end
	local force = Instance.new("VectorForce")
	force.Name = "GravityForce"
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	-- counter standard gravity, then add reversed gravity
	force.Force = Vector3.new(0, (196.2 * 2) * sign, 0) * root.AssemblyMass
	force.ApplyAtCenterOfMass = true
	force.Attachment0 = root:FindFirstChild("RootAttachment") :: Attachment
	force.Parent = root
end
```
Attach a `RootAttachment` to the root part first. `workspace.Gravity` is global — changing it
flips every player on the server and is a classic AI bug.

### 2.3 Camera roll (any gravity / orientation gimmick)
```lua
--!strict
-- Client: rotate the camera so the player always looks upright
local TweenService = game:GetService("TweenService")
local camera = workspace.CurrentCamera

local function rollCamera(flipped: boolean)
	local up = flipped and Vector3.new(0, -1, 0) or Vector3.new(0, 1, 0)
	local target = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + camera.CFrame.LookVector)
		* CFrame.Angles(0, 0, flipped and math.pi or 0)
	TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + camera.CFrame.LookVector, up)
end
```
Fighting the default camera script: set `player.CameraMode`, use `Camera.CFrame` only in
`RenderStepped` inside a `BindToRenderStep` at a priority **after** the camera module
(`Enum.RenderPriority.Camera.Value + 1`), or it gets overwritten every frame.

### 2.4 Movement onto surfaces
- `Humanoid:MoveTo(pos)` returns nothing useful; watch `Humanoid.MoveToFinished:Wait()` with a timeout.
- For NPC/entity movement use waypoints, never per-frame `MoveTo`.

---

## 3. DataStore (the #1 cause of 1-star reviews)

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local store = DataStoreService:GetDataStore("PlayerData_v1")
local SESSION_TTL = 60

local function withRetry<T>(fn: () -> T): (boolean, T | string)
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataStore] attempt {attempt} failed: {result}`)
		task.wait(2 ^ attempt) -- 2, 4, 8, 16 s backoff
	end
	return false, "exhausted"
end

function DataService.load(player: Player)
	local key = `player_{player.UserId}`
	local ok, result = withRetry(function()
		return store:UpdateAsync(key, function(old)
			old = old or DataService.defaults()
			if old.lockOwner and old.lockOwner ~= player.UserId then
				if os.time() - (old.lockTime or 0) < SESSION_TTL then
					return nil   -- another server still holds it; don't clobber
				end
			end
			old.lockOwner = player.UserId
			old.lockTime = os.time()
			old.version = DataService.migrate(old)
			return old
		end)
	end)
	if not ok then
		-- Fall back to in-memory only and TELL the player. Never pretend it saved.
		warn(`[Data] {player.Name} running unsaved: {result}`)
	end
end
```

Non-negotiables:
1. **`UpdateAsync`, not `GetAsync` + `SetAsync`.** Read-modify-write in one atomic call.
2. **Session lock** with a TTL takeover (60 s). Without it, two servers fight and wipe the player.
3. **`version` + `migrate()`** from day one. You will change the schema.
4. **`BindToClose`** save, plus a 60 s autosave, plus save on leave. Never save on every purchase.
5. **`pcall` every call and retry with backoff.** DataStore throttles, and throttling looks like data loss.
6. **Only JSON-safe data.** No Instances, no `Vector3` (convert to `{x,y,z}`), no mixed-key tables.
7. **Budget:** ~60 writes/min per key, 4 MB per key. Never store a ghost replay of 2 MB × 20 players.

---

## 4. Remotes and replication

| Do | Don't |
|---|---|
| Server creates `RemoteEvent`s (client `WaitForChild`) | Client creates them (races, nil on first join) |
| Attributes for state that many clients read (cash, heat, phase) | One remote per tick per player |
| `FireClient` for personal data | `FireAllClients` for something only one player can see |
| Type-check every argument (`typeof`) | `assert` that throws on a hacked client (log spam) |
| One `RemoteFunction` per query, with a server-side timeout | `InvokeClient` (blocks and is unsafe — never use it) |

Grep before you ship: `FireAllClients` (should be intentional), `InvokeClient` (should be zero),
`OnClientInvoke` (rare), and every `OnServerEvent` with no validation above it.

---

## 5. Performance (what a Roblox server can actually take)

| Budget | Target | Smell |
|---|---|---|
| Server heartbeat | < 5 ms with target players | per-part loops, per-crop `task.wait` |
| Client frame | < 7 ms mid-range Android | > 15k parts visible, 60 textures, no streaming |
| Parts per stage/plot | < 900 / < 1,200 | each prop as 12 parts |
| Remote payload | < 4 KB/s per player | sending a table every frame |
| DataStore writes | ≤ 1/key/60 s | saving on every purchase |
| NPC count | ≤ 8 active with simple AI | pathfinding for every NPC every frame |

Rules:
- **`StreamingEnabled`** for anything bigger than one room. `StreamingMinRadius = 512`,
  `StreamingTargetRadius = 1024`. `ModelStreamingMode = Atomic` on stage/plot models.
- **Attributes over Values over remotes** for replicated state.
- **`task.wait()` at 1 s** for economies; **5 Hz** for gameplay sims (heat); **20 Hz max** for
  anything replicated.
- **`Debris`/pooling** for projectiles and floaters. Don't `Instance.new` in a `RenderStepped`.
- **`workspace:GetPartBoundsInRadius`** instead of iterating all parts for proximity checks.
- MicroProfiler for real profiles; the crude heartbeat sampler in `workflow/README.md` for a quick check.

---

## 6. UI that survives mobile (≈60% of your players)

```lua
--!strict
-- Scale with the viewport, never hardcode pixels
local frame = script.Parent.Frame
frame.Size = UDim2.fromScale(0.3, 0.12)
frame.Position = UDim2.fromScale(0.5, 0.92)
frame.AnchorPoint = Vector2.new(0.5, 1)

-- Touch-friendly targets
local button = frame.BuyButton :: TextButton
button.Size = UDim2.fromScale(0.9, 0.55)
-- 44 px ≈ 1 inch minimum; on mobile that's about 0.1 of a 640-px-wide screen
```

- Use `UIScale` + `UIAspectRatioConstraint`; test at **360×640** and on a tablet.
- `Enum.ScreenInsets` / `GuiService:GetGuiInset()` — never draw under the notch or the top bar.
- Don't rely on hover; on mobile there's none.
- Put the *primary* action in the **bottom-right** thumb zone.
- Every HUD must survive a 4:3 tablet and a 21:9 phone. Check with `screen_capture` at both.

---

## 7. Asset and sound discipline

- **Ids live in one module** (`Assets.lua`), never inline `rbxassetid://` in 40 files.
- Preload sounds/images you need in the first 10 s (`ContentProvider:PreloadAsync`).
- Free models: `inspect_instance` them. Then check `Anchored`, part count, and scale. Most arrive
  wrong and one unanchored part ruins a map.
- Audio: `SoundService.RespectFilteringEnabled` on; parent sounds to the object so 3D works.
- Texture/mesh budget: ask "can this be a decal instead?"

---

## 8. Monetization rules (platform + ethics)

- `MarketplaceService:PromptGamePassPurchase` / `PromptProductPurchase` — **the client may prompt,
  the server must grant** (in `ProcessReceipt`). Never grant from a client signal.
- `ProcessReceipt` must be idempotent: record the `PurchaseId` before granting; return
  `Enum.ProductPurchaseDecision.PurchaseGranted` only after the grant is saved.
- Disclose odds for any paid random item, in-game, matching the code exactly.
- No pay-to-win in competitive modes; the docs specify what not to sell per genre.

```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local granted: { [string]: boolean } = {}

MarketplaceService.ProcessReceipt = function(receipt)
	if granted[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = game.Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = pcall(function()
		DataService.grantProduct(player, receipt.ProductId)
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet   -- Roblox retries
	end
	granted[receipt.PurchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

---

## 9. Project hygiene

```
ReplicatedStorage
  Shared/        Config, Util, Remotes      -- no logic that touches DataStore
  Assets/        models, sounds, images     -- referenced by id from Config
ServerScriptService
  Bootstrap.server.lua                      -- starts services in a fixed order
  Services/      one ModuleScript per domain
  Systems/       pure logic, unit-testable  -- the stuff your tests target
  Tests/         TestRunner + Suites/
StarterPlayer
  StarterPlayerScripts/Client/              -- controllers, one per concern
  StarterGui/                               -- one ScreenGui per feature
```

- **Bootstrap pattern:** one entry script requires services in order. No hidden `require` chains.
- **`--!strict`** on new modules. It catches the nil-index class of bug at edit time.
- **Logger module** with levels; no stray `print` in shipped code.
- **`.gitignore`/versioning:** if you use Rojo, commit `default.project.json` + `src/`. If you're
  Studio-only, `save_place` per milestone is your history.

---

## 10. Things that look right and are wrong

| Looks right | Actually |
|---|---|
| `workspace.Gravity = -196.2` | Flips **every** player. Use per-character forces |
| `humanoid.WalkSpeed = 40` on the client | Reverted/ignored; set it on the server |
| `GetAsync` then `SetAsync` | Race that wipes data on two servers |
| `RemoteEvent:FireAllClients(data)` for cash | Every player sees everyone's numbers; also a leak vector |
| `task.wait()` inside `Heartbeat` | Doubles the loop count every frame |
| `pcall` around everything with no logging | Bugs vanish from the console |
| `Instance.new` in `RenderStepped` | GC churn and frame spikes |
| `Model:GetChildren()[1]` | Order is unstable; use `FindFirstChild("Name")` |
| Scaling the Humanoid for prop hunt | Hitbox and animation break; use a hitbox part |
| `Sound` parented to `SoundService` | No 3D falloff; parent it to the part |
| 900 `Part`s for a wall | Use one `MeshPart` or a texture |
| `wait()` | Deprecated alias; use `task.wait()` |
