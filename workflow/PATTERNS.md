# Luau patterns — copy these instead of inventing them

Production-shaped snippets for the systems all five games need. All `--!strict`, all
server-authoritative where it matters. Adapt names; keep the structure.

---

## 1. Bootstrap: one entry point, fixed order

```lua
--!strict
-- ServerScriptService/Bootstrap.server.lua
local ServerScriptService = game:GetService("ServerScriptService")

local ORDER = {
	"DataService",
	"PlotService",
	"EconomyService",
	"UpgradeService",
	"RoundService",
}

local services: { [string]: any } = {}

for _, name in ORDER do
	local module = ServerScriptService.Services:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), `missing service: {name}`)
	local ok, err = pcall(function()
		services[name] = require(module)
	end)
	if not ok then
		error(`{name} failed to load: {err}`)
	end
end

-- init in order, then start after all are initialized
for _, name in ORDER do
	local svc = services[name]
	if svc.init then
		svc.init(services)
	end
end
for _, name in ORDER do
	local svc = services[name]
	if svc.start then
		svc.start()
	end
end

print(`[Bootstrap] started {#ORDER} services`)
```

Why: dependency order is explicit, a broken service fails loudly at boot (not 10 minutes
in), and tests can require services without starting the world.

---

## 2. Config as data (balance lives in one place)

```lua
--!strict
-- ReplicatedStorage/Shared/Config/Economy.lua
local Economy = {}

Economy.Tiers = {
	{ id = 1, name = "Raft",    cost = 0,       rate = 1,   unlock = { "pump_1" } },
	{ id = 2, name = "Platform", cost = 2500,   rate = 6,   unlock = { "pump_2", "crew_1" } },
	{ id = 3, name = "Steel",   cost = 18000,  rate = 22,  unlock = { "pump_3", "refinery" } },
	{ id = 4, name = "Deep",    cost = 95000,  rate = 70,  unlock = { "trench_drill" } },
	{ id = 5, name = "Mega",    cost = 480000, rate = 240, unlock = { "pump_4", "helipad" } },
	{ id = 6, name = "Tier6",   cost = 2400000, rate = 900, unlock = { "harvester" } },
}

Economy.upgradeCost = function(base: number, level: number): number
	return math.floor(base * 1.60 * 1.55 ^ math.max(0, level - 1))
end

Economy.upgradeRate = function(base: number, level: number): number
	return base * 1.55 * 1.45 ^ math.max(0, level - 1)
end

return table.freeze(Economy)
```

Test the curves, not the UI:
```lua
{ suite = "economy", case = "tier2_pays_back_under_8min",
  run = function()
    local Eco = require(game.ReplicatedStorage.Shared.Config.Economy)
    local t1, t2 = Eco.Tiers[1], Eco.Tiers[2]
    local seconds = t2.cost / t1.rate
    return seconds < 480, ("%d s to afford tier 2"):format(seconds)
  end }
```

---

## 3. Data service with session lock + migration

```lua
--!strict
-- ServerScriptService/Services/DataService.lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = {}
local store = DataStoreService:GetDataStore("PlayerData_v1")
local LOCK_TTL = 60
local cache: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}

local CURRENT_VERSION = 3

function DataService.defaults()
	return {
		version = CURRENT_VERSION,
		cash = 0,
		tier = 1,
		pumps = {},
		upgrades = {},
		stats = { playSeconds = 0 },
		lastSeen = os.time(),
	}
end

-- migrations run oldest → newest, each one only does one hop
local MIGRATIONS: { [number]: (any) -> any } = {
	[1] = function(d)
		d.stats = d.stats or { playSeconds = 0 }
		return d
	end,
	[2] = function(d)
		d.pumps = d.pumps or {}
		return d
	end,
}

function DataService.migrate(data)
	local v = data.version or 1
	while v < CURRENT_VERSION do
		local fn = MIGRATIONS[v]
		if not fn then
			error(`no migration from version {v}`)
		end
		data = fn(data)
		v += 1
		data.version = v
	end
	for key, value in DataService.defaults() do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

function DataService.load(player: Player)
	local ok, result = pcall(function()
		return store:UpdateAsync(key(player), function(old)
			old = DataService.migrate(old or DataService.defaults())
			if old.lockOwner and old.lockOwner ~= player.UserId and os.time() - (old.lockTime or 0) < LOCK_TTL then
				return nil
			end
			old.lockOwner = player.UserId
			old.lockTime = os.time()
			return old
		end)
	end)
	if not ok or result == nil then
		warn(`[Data] {player.Name}: falling back to memory ({result})`)
		cache[player] = DataService.defaults()
		return cache[player]
	end
	cache[player] = result
	return result
end

function DataService.get(player: Player)
	return cache[player]
end

function DataService.save(player: Player, release: boolean?)
	local data = cache[player]
	if not data then
		return
	end
	data.lastSeen = os.time()
	data.lockTime = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			local out = table.clone(data)
			if release then
				out.lockOwner = nil
			end
			return out
		end)
	end)
	if not ok then
		warn(`[Data] save failed for {player.Name}: {err}`)
	end
end

Players.PlayerRemoving:Connect(function(player)
	DataService.save(player, true)
	cache[player] = nil
end)

game:BindToClose(function()
	for player in cache do
		DataService.save(player, true)
	end
	task.wait(2)
end)

return DataService
```

**Autosave loop** (one, not one per player):
```lua
task.spawn(function()
	while true do
		task.wait(60)
		for player in cache do
			DataService.save(player)
		end
	end
end)
```

---

## 4. Rate limiter + validated remotes

```lua
--!strict
-- ReplicatedStorage/Shared/Remotes.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}
local spec = {
	"RequestPurchase",   -- C→S (padId)
	"CheckpointReached", -- C→S (id)
	"StageFinished",     -- C→S (stageId)
	"RequestGhost",      -- C→S (stageId)
	"EquipCosmetic",     -- C→S (id)
	"PhaseChanged",      -- S→C
	"GhostData",         -- S→C
}

function Remotes.setup()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in spec do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name) :: RemoteEvent
end

return Remotes
```

```lua
--!strict
-- Shared/Util/RateLimit.lua
local RateLimit = {}
local buckets: { [string]: number } = {}

function RateLimit.allow(id: string, minInterval: number): boolean
	local now = os.clock()
	local last = buckets[id]
	if last and now - last < minInterval then
		return false
	end
	buckets[id] = now
	return true
end

function RateLimit.clear(player: Player)
	local prefix = `{player.UserId}:`
	for k in buckets do
		if string.sub(k, 1, #prefix) == prefix then
			buckets[k] = nil
		end
	end
end

return RateLimit
```

---

## 5. Pure logic module (testable) + thin glue

```lua
--!strict
-- ServerScriptService/Systems/Gravity.lua      ← PURE. No Instances. Fully unit-testable.
local Gravity = {}
Gravity.__index = Gravity

local COOLDOWN = 0.55
local MAX_SPEED_MULT = 1.40
local SPEED_STEP = 0.15

export type Self = {
	sign: number,
	speedMultiplier: number,
	lastFlip: number,
}

function Gravity.new(sign: number): Self
	return setmetatable({ sign = sign, speedMultiplier = 1.0, lastFlip = -math.huge }, Gravity)
end

function Gravity.flip(self: Self, now: number): boolean
	if now - self.lastFlip < COOLDOWN then
		return false
	end
	self.sign *= -1
	self.lastFlip = now
	self.speedMultiplier = math.min(self.speedMultiplier + SPEED_STEP, MAX_SPEED_MULT)
	return true
end

function Gravity.reset(self: Self)
	self.sign = 1
	self.speedMultiplier = 1.0
end

return Gravity
```

Then the Roblox glue is 15 lines and hard to get wrong:
```lua
-- Server: applies the pure result to physics
local Gravity = require(script.Parent.Systems.Gravity)
local state = Gravity.new(1)

Remotes.FlipRequest.OnServerEvent:Connect(function(player)
	if not RateLimit.allow(`{player.UserId}:flip`, 0.05) then return end
	local ok = Gravity.flip(state, os.clock())
	if not ok then return end
	applyGravity(player.Character.HumanoidRootPart, state.sign)
	player.Character:SetAttribute("GravitySign", state.sign)
end)
```

**The lesson:** AI agents get timing/physics wrong far more often than arithmetic. Put every
number in a pure module, unit-test the numbers, and keep the engine glue boring.

---

## 6. Timestamp growth (no per-crop loops)

```lua
--!strict
-- ServerScriptService/Systems/Garden.lua
local Garden = {}

export type Plot = {
	seedTier: number?,
	plantedAt: number?,      -- os.time()
	growTime: number?,
	mutationSeed: number?,   -- decided at plant time; never re-rolled
	waters: number,
}

function Garden.isReady(plot: Plot, now: number): boolean
	if not plot.plantedAt or not plot.growTime then
		return false
	end
	return now >= plot.plantedAt + plot.growTime
end

function Garden.progress(plot: Plot, now: number): number
	if not plot.plantedAt or not plot.growTime or plot.growTime == 0 then
		return 0
	end
	return math.clamp((now - plot.plantedAt) / plot.growTime, 0, 1)
end

return Garden
```

One 2 s loop checks all plots of all players; the client animates from `plantedAt`
replicated as an attribute. Zero timers per crop, correct across restarts, offline growth free.

---

## 7. Server-authoritative run timer (obbys)

```lua
--!strict
local runs: { [Player]: { stageId: string, startClock: number, checkpoint: number } } = {}

local MIN_DURATION = 8 -- reject impossible runs

function ProgressService.beginRun(player, stageId)
	runs[player] = { stageId = stageId, startClock = os.clock(), checkpoint = 0 }
end

function ProgressService.finishRun(player, claimedStage: string)
	local run = runs[player]
	if not run or run.stageId ~= claimedStage then
		return false, "no matching run"
	end
	local elapsed = os.clock() - run.startClock
	if elapsed < MIN_DURATION then
		warn(`[AntiCheat] {player.Name} finished {claimedStage} in {elapsed:.2f}s — rejected`)
		return false, "too fast"
	end
	runs[player] = nil
	return true, elapsed          -- the SERVER's number goes on the board
end
```

The client's `elapsed` is for its own HUD only. Never read it for a leaderboard.

---

## 8. OrderedDataStore leaderboard with retry

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local board = DataStoreService:GetOrderedDataStore("StageTimes_v1")

local function submit(key: string, timeMs: number): boolean
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			board:SetAsync(key, timeMs)
		end)
		if ok then
			return true
		end
		warn(`[Board] {key} attempt {attempt}: {err}`)
		task.wait(2 ^ attempt)
	end
	return false
end

local function top(prefix: string, count: number)
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, count)   -- false = ascending = fastest first
	end)
	if not ok or not pages then
		return {}
	end
	local items = pages:GetCurrentPage()
	local out = {}
	for _, entry in items do
		if string.sub(entry.key, 1, #prefix) == prefix then
			table.insert(out, { playerId = entry.key, timeMs = entry.value })
		end
	end
	return out
end
```

Notes:
- `OrderedDataStore` is **eventually consistent**; show "updated a few seconds ago" in the UI.
- Cache the top page in a server module for 60 s. Never call `GetSortedAsync` per player join.
- Write with player-id keys, resolve names client-side via `Players:GetNameFromUserIdAsync`
  (rate-limited — cache it).

---

## 9. Round / phase state machine

```lua
--!strict
local RoundService = {}
local phases = {
	Lobby = 20, Hide = 25, Hunt = 180, LastChance = 30, Results = 12,
}
local NEXT = { Lobby = "Hide", Hide = "Hunt", Hunt = "LastChance", LastChance = "Results", Results = "Lobby" }

local current: string = "Lobby"
local phaseEndsAt: number = 0

local function setPhase(phase: string)
	current = phase
	phaseEndsAt = os.clock() + phases[phase]
	Remotes.get("PhaseChanged"):FireAllClients(phase, phaseEndsAt)
	print(`[Round] -> {phase} for {phases[phase]}s`)
end

function RoundService.start()
	task.spawn(function()
		while true do
			setPhase("Lobby")
			task.wait(phases.Lobby)
			setPhase("Hide")
			task.wait(phases.Hide)
			setPhase("Hunt")
			-- hunt ends early if a team is wiped
			local deadline = os.clock() + phases.Hunt
			while os.clock() < deadline and not RoundService.teamWiped() do
				task.wait(0.5)
			end
			setPhase("LastChance")
			task.wait(phases.LastChance)
			setPhase("Results")
			task.wait(phases.Results)
		end
	end)
end

function RoundService.phase(): string
	return current
end

function RoundService.timeLeft(): number
	return math.max(0, phaseEndsAt - os.clock())
end

return RoundService
```

The client renders from `(phase, phaseEndsAt)` and never transitions anything.

---

## 10. Heat/proximity sim at a fixed low rate

```lua
--!strict
local RunService = game:GetService("RunService")
local HEAT_PER_SEC, DECAY_PER_SEC, MOVE_THRESHOLD = 25, 8, 1.5

local props: { [Player]: { character: Model, heat: number, rate: number } } = {}

RunService.Heartbeat:Connect(function(dt)
	-- one loop for all props; dt-based so it stays correct if the server hitches
	for player, p in props do
		local root = p.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local moving = root.AssemblyLinearVelocity.Magnitude > MOVE_THRESHOLD
			p.heat = math.clamp(p.heat + (moving and p.rate or -DECAY_PER_SEC) * dt, 0, 100)
			player:SetAttribute("Heat", math.floor(p.heat))
		end
	end
end)
```

Use `dt`, not a fixed increment — a hitch otherwise makes heat jump. Attributes replicate once
per change, which is far cheaper than a remote per tick.

---

## 11. Entity state machine (horror)

```lua
--!strict
type State = "Dormant" | "Patrol" | "Suspicious" | "Search" | "Chase" | "Retreat"

local timings = {
	Dormant = 60, Patrol = math.huge, Suspicious = 3, Search = 8, Chase = 15, Retreat = 10,
}

local function canAggro(player: Player): boolean
	local lastEscape = player:GetAttribute("LastEscapeAt") or 0
	return os.clock() - lastEscape > 25           -- no double jeopardy
end

local function evaluate(entity, target: Player?): State
	if not target then
		return "Patrol"
	end
	local distance = (entity.pos - target.Root.Position).Magnitude
	local sees = entity:hasLineOfSight(target.Root.Position)
	if sees and distance < 25 and canAggro(target) then
		return "Chase"
	end
	if sees and distance < 30 then
		return "Suspicious"
	end
	return "Search"
end
```

Keep it a table of pure predicates + a `MoveTo` node walker. That combination is testable
(`evaluate` returns a state you can assert) and doesn't touch the pathfinder per frame.

---

## 12. Testing patterns

```lua
--!strict
-- Testing a remote without a real client: call the handler directly
local handler = require(game.ServerScriptService.Services.UpgradeService)

{ suite = "purchase", case = "double_click_buys_once",
  run = function()
    local player = game.Players:GetPlayers()[1]
    handler.reset(player)
    handler.purchase(player, "pump_2")
    local afterFirst = handler.cash(player)
    handler.purchase(player, "pump_2")        -- immediate second click
    local afterSecond = handler.cash(player)
    return afterFirst == afterSecond, ("cash {afterFirst} vs {afterSecond}"):format()
  end }
```

**Simulation tests for anything with odds** (run them, never eyeball):
```lua
{ suite = "mutations", case = "odds_within_0_2pp",
  run = function()
    local Mutations = require(game.ReplicatedStorage.Shared.Config.Mutations)
    local counts, N = {}, 100_000
    for _ = 1, N do
      local m = Mutations.roll(Random.new(1234))
      counts[m.id] = (counts[m.id] or 0) + 1
    end
    local worst, worstId = 0, ""
    for _, m in Mutations.List do
      local observed = (counts[m.id] or 0) / N * 100
      local delta = math.abs(observed - m.chance)
      if delta > worst then
        worst, worstId = delta, m.id
      end
    end
    return worst < 0.2, `{worstId} off by {worst:.3f}pp`
  end }
```

Note the fixed `Random.new(1234)` seed: **deterministic tests are the difference between a test
suite and a nuisance.** If a test flakes, it gets deleted by the next agent.

---

## 13. Number formatting (every tycoon needs it)

```lua
--!strict
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local function formatNumber(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local index = math.min(#SUFFIXES, math.floor(math.log10(n) / 3) + 1)
	local scaled = n / 10 ^ ((index - 1) * 3)
	return `{scaled:.1f}{SUFFIXES[index]}`
end

return formatNumber
```
Test it: `999 → "999"`, `1000 → "1.0K"`, `1250000 → "1.3M"`. Formatting bugs are the most
visible bugs in a tycoon, and they're trivially testable — so test them.
