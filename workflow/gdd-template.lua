--!strict
--[[
	GDD template — the spec that lives INSIDE the place.

	How to install (via Studio MCP, once per game):
	  execute_luau (Edit):
	    local src = <paste this file>
	    build ReplicatedStorage/GDD as a Folder with these ModuleScripts.

	Why it lives in the place:
	  - the agent reads it with script_read instead of you re-explaining
	  - the numbers live in ONE module and code requires that module
	  - Progress.* are the only place "done" is recorded
	  - JOURNAL is the handoff between sessions

	Copy each section into its own ModuleScript under ReplicatedStorage/GDD:
	  00_Overview, 01_Mechanics, 02_Milestones, 03_ArtDirection, 04_Data, 05_Assets
]]

-- ===========================================================================
-- 00_Overview  (ModuleScript)
-- ===========================================================================
local Overview = {
	name = "<YourGame>",
	genre = "Obby / speedrun platformer",
	pillars = {
		"A single readable mechanic: flip gravity with Q.",
		"Momentum is kept, so chaining flips is the skill ceiling.",
		"The camera always keeps the player visually upright.",
	},
	targetPlayers = 16,
	sessionMinutes = 15,
	firstMeaningfulActionSeconds = 10,
	firstFiveMinutes = {
		"1-1 spawn pad is 6 studs from the player; walking forward starts the run.",
		"First flip is required at ~12 s and is taught by a ceiling pad with a cyan rim.",
		"First death is a fall, respawn in 0.4 s at the last pad.",
		"First medal (silver) is reachable on attempt 2 for a new player.",
	},
	notInScope = {
		"multiplayer races", "PvP", "pets", "trading", "seasons",
	},
}

-- ===========================================================================
-- 01_Mechanics  (ModuleScript)  — every number the game uses. Code REQUIRES this.
-- ===========================================================================
local Mechanics = {
	flip = {
		cooldown = 0.55,
		speedStep = 0.15,          -- +15% horizontal per flip
		maxSpeedMultiplier = 1.40, -- hard cap
		airControl = 0.80,
		coyoteTime = 0.12,
		inputBuffer = 0.15,
		cameraRollSeconds = 0.18,
		maxFallStuds = 55,
		baseWalkSpeed = 18,
		baseJumpPower = 50,
	},
	stage = {
		minSecondsFirstClear = 40,
		maxSecondsFirstClear = 90,
		goodRunSeconds = 30,
		checkpointEverySeconds = 20,
		maxHardJumpsBetweenCheckpoints = 3,
		medalGoldFactor = 1.15,    -- gold = best run x 1.15
		medalSilverFactor = 1.45,  -- silver = best run x 1.45
		minRunSecondsAccepted = 8, -- server rejects anything faster (anti-cheat)
	},
	ghost = {
		sampleHz = 20,
		maxRunSeconds = 180,
		maxBytes = 120 * 1024,
		rigParts = 6,
		storedRuns = 3,
	},
	economy = {
		boltsPerClear = 10,
		boltsPerSilver = 25,
		boltsPerGold = 60,
		cosmeticShardChanceGolden = 1.0,
	},
	rewards = {
		dailyShardAmount = 1,
		weeklyHardModeTokens = 100,
	},
}

-- ===========================================================================
-- 02_Milestones  (ModuleScript)  — status lives in ReplicatedStorage.GDD.Progress
-- ===========================================================================
local Milestones = {
	{
		id = "M0",
		name = "Skeleton + GDD in place",
		days = 0.5,
		tasks = {
			"Create ReplicatedStorage/GDD with 00–05 modules + Progress + JOURNAL",
			"Create Systems/, Services/, Tests/Suites/",
			"Create Remotes from the spec table",
		},
		acceptance = {
			"execute_luau (Edit) prints the milestone count and each GDD module path",
			"script_read ReplicatedStorage.GDD.01_Mechanics returns cooldown 0.55",
			"Progress.M0 == true only after the two lines above",
		},
	},
	{
		id = "M1",
		name = "The flip",
		days = 3,
		tasks = {
			"Systems/Gravity.lua — pure logic (sign, cooldown, speed multiplier)",
			"Client/GravityController — input → FlipRequest intent",
			"Client/CameraRoll — 180° over cameraRollSeconds",
			"Tests/Suites/GravitySpec.lua — 3 cases",
		},
		acceptance = {
			'Tests print "SUMMARY 3/3"',
			"start_stop_play: pressing Q sets GravitySign = -1 on the server",
			"screen_capture shows the player upright on the ceiling",
			"get_console_output: zero errors and zero warnings",
			"10/10 flips succeed on PC and the mobile button works",
		},
	},
	{
		id = "M2",
		name = "Checkpoints and server timing",
		days = 2,
		tasks = {
			"CheckpointReached validates order + distance + rate limit",
			"beginRun/finishRun with server os.clock and minRunSecondsAccepted reject",
			"Medals awarded against TimeTargets",
		},
		acceptance = {
			'exploit.fast_finish -> rejected and logged (SUMMARY includes it)',
			"a real clear awards the correct medal",
			"a second clear updates the PB, not the medal list",
		},
	},
	{
		id = "M3",
		name = "Persistence and leaderboards",
		days = 2,
		tasks = {
			"DataService with session lock, version, migrate()",
			"OrderedDataStore top 25 with retry and a 60 s cache",
			"BindToClose save",
		},
		acceptance = {
			"rejoin after clearing 3 stages shows all medals + bolts",
			"a second server reads the same board",
			"forced shutdown mid-session loses nothing (5/5 cycles)",
		},
	},
	{
		id = "M4",
		name = "Stage template and worlds 1–2",
		days = 10,
		tasks = {
			"Stage template: start pad, checkpoints, gauntlet, finish pad",
			"World 1 (8 stages) + World 2 (8 stages) built from StageSpecs",
		},
		acceptance = {
			"search_game_tree Workspace.Stages returns exactly 16",
			"an outside tester clears 1-1 → 2-8 without getting stuck",
			"every stage lands 40–90 s first clear (measured, listed)",
		},
	},
	{
		id = "M5",
		name = "Ghosts, cosmetics, shop",
		days = 7,
		tasks = {
			"Ghost record/playback (20 Hz, 6-part rig)",
			"6 trails, 3 flip VFX, purchase + equip",
		},
		acceptance = {
			"racing your own ghost shows both on screen (screen_capture)",
			"a purchased trail is visible on a second client",
			"ghost payload <= 120 KB and playback has no visible stutter",
		},
	},
	{
		id = "M6",
		name = "Full content and polish",
		days = 14,
		tasks = {
			"Worlds 3–6 (32 more stages)",
			"SFX + music per world, mobile pass, icon and thumbnails",
		},
		acceptance = {
			"search_game_tree Workspace.Stages returns exactly 48",
			"3 new testers understand the flip within 10 s of 1-1",
			"perf: client frame < 6 ms on mid-range Android settings",
		},
	},
}

-- ===========================================================================
-- 03_ArtDirection  (ModuleScript)
-- ===========================================================================
local ArtDirection = {
	palette = {
		cyan = Color3.fromRGB(57, 224, 255),
		orange = Color3.fromRGB(255, 138, 60),
		purple = Color3.fromRGB(150, 90, 255),
		ink = Color3.fromRGB(10, 17, 40),
		white = Color3.fromRGB(240, 248, 255),
	},
	materials = {
		platform = Enum.Material.SmoothPlastic,
		neonTrim = Enum.Material.Neon,
		hazard = Enum.Material.Neon,
	},
	silhouetteRules = {
		"Ceiling landing pads always have a cyan neon rim.",
		"Kill hazards are always orange neon, never cyan.",
		"Checkpoints are green rings; finishes are white with a beam.",
		"No stage is readable only by colour — every hazard also has a shape cue.",
	},
	lighting = {
		technology = Enum.Technology.Future,
		clockTime = 17.5,
		brightness = 2.2,
		ambient = Color3.fromRGB(70, 60, 110),
	},
	ui = {
		font = Enum.Font.GothamBlack,
		radius = UDim.new(0, 8),
		accent = Color3.fromRGB(57, 224, 255),
	},
}

-- ===========================================================================
-- 04_Data  (ModuleScript)  — schema + migration contract
-- ===========================================================================
local Data = {
	version = 1,
	schema = {
		version = "number",
		bolts = "number",
		stages = "{ [string]: { cleared: boolean, bestTime: number?, silver: boolean, gold: boolean, attempts: number } }",
		cosmetics = "{ owned: {string}, equipped: {string} }",
		stats = "{ totalDeaths: number, totalFlips: number, playSeconds: number }",
	},
	rules = {
		"UpdateAsync only; never GetAsync then SetAsync",
		"session lock with 60 s TTL takeover",
		"every DataStore call wrapped in pcall with exponential backoff",
		"BindToClose save + 60 s autosave + save on leave",
		"store only JSON-safe values (no Instances, no Vector3)",
	},
}

-- ===========================================================================
-- 05_Assets  (ModuleScript)  — asset ids live here, nowhere else
-- ===========================================================================
local Assets = {
	sounds = {
		flip = 0,
		land = 0,
		checkpoint = 0,
		death = 0,
		medal = 0,
		click = 0,
		purchase = 0,
	},
	images = {
		icon = 0,
		thumbnailA = 0,
		thumbnailB = 0,
	},
	meshes = {
		ghostRig = 0,
	},
}

-- ===========================================================================
-- Progress structure (created by execute_luau, not a module)
-- ===========================================================================
--[[
	ReplicatedStorage/GDD/Progress  (Configuration)
		M0..M6      BoolValue  — true only after acceptance passes
		CURRENT     StringValue = "M2"
		LAST_VERIFIED StringValue = "2026-11-17T18:20Z"

	ReplicatedStorage/GDD/JOURNAL  (Folder)
		2026-11-17_M1  StringValue:
			"date: 2026-11-17 | M1 | verified: SUMMARY 3/3, console clean,
			 visible: upright on ceiling | gap: mobile button 2 px too small
			 | next: M2 checkpoint validation"
]]

return {
	Overview = Overview,
	Mechanics = Mechanics,
	Milestones = Milestones,
	ArtDirection = ArtDirection,
	Data = Data,
	Assets = Assets,
}
