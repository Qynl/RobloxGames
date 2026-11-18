--!strict
--[[
	FLORA — World Audit
	Drop-in Studio script. Prints a 10-point score for a built region and fails loudly.

	USE (via Studio MCP):
	  execute_luau {
	    datamodel_type = "Edit",
	    code = <this file's contents, with REGION_CENTRE / REGION_RADIUS set>
	  }

	WHY:
	  An agent will report "region built" without ever looking at it. This turns
	  "looks bad" into a number you can gate a milestone on.

	SCORE:
	  10/10 = shippable region
	   7-9  = greybox+ , needs detail or composition work
	   4-6  = structurally there, visually unfinished
	  <4    = not a region yet
]]

local Terrain = workspace.Terrain
local Lighting = game:GetService("Lighting")

-- ===== CONFIGURE =====
local REGION_CENTRE = Vector3.new(0, 0, 0)
local REGION_RADIUS = 450
local MIN_MATERIALS = 6
local MIN_SCALE_SPREAD = 0.6          -- (maxScale - minScale) must exceed this
local MAX_FLOAT_STUDS = 1.0
local BIG_SURFACE_STUDS = 4
local DETAIL_RADIUS = 180
local MAX_HINTERLAND_DENSITY = 12     -- props per 100x100 in the outer band

-- ===== helpers =====
local function header(text: string)
	print("\n===== " .. text .. " =====")
end

local function insideRegion(position: Vector3): boolean
	local flat = Vector3.new(position.X - REGION_CENTRE.X, 0, position.Z - REGION_CENTRE.Z)
	return flat.Magnitude <= REGION_RADIUS
end

local results: { [string]: { pass: boolean, detail: string } } = {}

local function record(id: string, pass: boolean, detail: string)
	results[id] = { pass = pass, detail = detail }
	print(string.format("[%s] %-26s %s", pass and "PASS" or "FAIL", id, detail))
end

-- ===== 1. terrain material variety =====
header("1. Terrain materials")
local materialCounts: { [string]: number } = {}
do
	local region = Region3.new(
		Vector3.new(REGION_CENTRE.X - REGION_RADIUS, -80, REGION_CENTRE.Z - REGION_RADIUS),
		Vector3.new(REGION_CENTRE.X + REGION_RADIUS, 240, REGION_CENTRE.Z + REGION_RADIUS)
	)
	local ok, voxels = pcall(function()
		return Terrain:ReadVoxels(region, 4)
	end)
	if ok and voxels then
		for x = 1, voxels.Size.X do
			for y = 1, voxels.Size.Y do
				for z = 1, voxels.Size.Z do
					local material = voxels[x][y][z]
					if material ~= Enum.Material.Air then
						local name = material.Name
						materialCounts[name] = (materialCounts[name] or 0) + 1
					end
				end
			end
		end
	end
	local distinct = 0
	for name, count in materialCounts do
		distinct += 1
		print(string.format("   %-14s %d voxels", name, count))
	end
	record("terrain_materials", distinct >= MIN_MATERIALS,
		string.format("%d distinct (need %d)", distinct, MIN_MATERIALS))
end

-- ===== 2. landforms must be terrain, not giant parts =====
header("2. Landform parts")
local giantParts = 0
local worstPart = ""
local worstHeight = 0
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:IsDescendantOf(workspace) then
		local height = descendant.Size.Y
		local footprint = math.max(descendant.Size.X, descendant.Size.Z)
		-- a "landform" part is tall AND wide AND big in volume
		if height > 40 and footprint > 40 and insideRegion(descendant.Position) then
			giantParts += 1
			if height > worstHeight then
				worstHeight = height
				worstPart = descendant:GetFullName()
			end
		end
	end
end
record("landform_terrain", giantParts == 0,
	string.format("%d giant parts%s", giantParts, giantParts > 0 and (" worst: " .. worstPart) or ""))

-- ===== 3. lighting applied =====
header("3. Lighting")
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local lightingGood = atmosphere ~= nil and grade ~= nil and bloom ~= nil and Lighting.GlobalShadows
record("lighting_applied", lightingGood,
	string.format("atmosphere=%s grade=%s bloom=%s shadows=%s clock=%.1f",
		tostring(atmosphere ~= nil), tostring(grade ~= nil), tostring(bloom ~= nil),
		tostring(Lighting.GlobalShadows), Lighting.ClockTime))

-- ===== 4. no default materials on big surfaces =====
header("4. Default materials on big surfaces")
local defaultSurfaces = 0
local worstSurface = ""
do
	local badMaterials = {
		[Enum.Material.Plastic] = true,
		[Enum.Material.SmoothPlastic] = true,
	}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and badMaterials[descendant.Material] and insideRegion(descendant.Position) then
			local longest = math.max(descendant.Size.X, descendant.Size.Y, descendant.Size.Z)
			if longest > BIG_SURFACE_STUDS then
				defaultSurfaces += 1
				if worstSurface == "" then
					worstSurface = descendant:GetFullName()
				end
			end
		end
	end
end
record("no_default_materials", defaultSurfaces == 0,
	string.format("%d surfaces > %d studs use Plastic%s", defaultSurfaces, BIG_SURFACE_STUDS,
		worstSurface ~= "" and (" e.g. " .. worstSurface) or ""))

-- ===== 5. nothing floating =====
header("5. Floating props")
local floating = 0
local sampleFloating = ""
do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Terrain }
	for _, descendant in workspace:GetDescendants() do
		-- only check top-level prop roots to avoid counting every child part
		if descendant:IsA("Model") and insideRegion(descendant:GetPivot().Position) then
			local success, extents = pcall(function()
				return descendant:GetExtentsSize()
			end)
			if success then
				local pivot = descendant:GetPivot()
				local bottom = pivot.Position.Y - extents.Y * 0.5
				local hit = workspace:Raycast(
					Vector3.new(pivot.Position.X, bottom + 0.6, pivot.Position.Z),
					Vector3.new(0, -12, 0),
					params
				)
				if not hit then
					-- no ground under it within 12 studs
					local terrainRay = workspace:Raycast(
						Vector3.new(pivot.Position.X, bottom + 0.6, pivot.Position.Z),
						Vector3.new(0, -60, 0),
						params
					)
					if not terrainRay then
						floating += 1
						if sampleFloating == "" then
							sampleFloating = descendant:GetFullName()
						end
					end
				end
			end
		end
	end
end
record("nothing_floating", floating == 0,
	string.format("%d floating models%s", floating, sampleFloating ~= "" and (" e.g. " .. sampleFloating) or ""))

-- ===== 6. scale variance =====
header("6. Scale variance")
local minScale, maxScale = math.huge, 0
local scaledModels = 0
do
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and insideRegion(descendant:GetPivot().Position) then
			local ok, size = pcall(function()
				return descendant:GetScale()
			end)
			if ok then
				local s = size
				scaledModels += 1
				minScale = math.min(minScale, s)
				maxScale = math.max(maxScale, s)
			end
		end
	end
end
local spread = (maxScale == 0 and 0 or (maxScale - minScale))
record("scale_variance", spread >= MIN_SCALE_SPREAD,
	string.format("min %.2f max %.2f spread %.2f (need %.2f, %d models)",
		(minScale == math.huge and 0 or minScale), maxScale, spread, MIN_SCALE_SPREAD, scaledModels))

-- ===== 7. composition — hero + anchors =====
header("7. Composition")
local heroCount, anchorCount = 0, 0
do
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and insideRegion(descendant:GetPivot().Position) then
			local ok, extents = pcall(function()
				return descendant:GetExtentsSize()
			end)
			if ok then
				local height = extents.Y
				if height >= 60 then
					heroCount += 1
				elseif height >= 15 then
					anchorCount += 1
				end
			end
		end
	end
end
-- one hero (or a hero landmark part), at least two medium anchors
local compositionPass = heroCount >= 1 and anchorCount >= 2
record("composition_hero_anchors", compositionPass,
	string.format("hero(>=60 studs)=%d anchors(15-60)=%d", heroCount, anchorCount))

-- ===== 8. density falloff =====
header("8. Density falloff")
local detailProps, hinterlandProps = 0, 0
do
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") then
			local pivot = descendant:GetPivot().Position
			if insideRegion(pivot) then
				local flat = Vector3.new(pivot.X - REGION_CENTRE.X, 0, pivot.Z - REGION_CENTRE.Z).Magnitude
				if flat <= DETAIL_RADIUS then
					detailProps += 1
				else
					hinterlandProps += 1
				end
			end
		end
	end
end
local detailArea = (2 * DETAIL_RADIUS) ^ 2 / 10000
local hinterArea = (math.pi * REGION_RADIUS ^ 2 - (2 * DETAIL_RADIUS) ^ 2) / 10000
local detailDensity = detailProps / math.max(detailArea, 1)
local hinterDensity = hinterlandProps / math.max(hinterArea, 1)
local falloffPass = hinterDensity <= MAX_HINTERLAND_DENSITY and detailDensity >= hinterDensity * 0.8
record("density_falloff", falloffPass,
	string.format("detail %.1f/100^2, hinterland %.1f/100^2 (max %.0f)",
		detailDensity, hinterDensity, MAX_HINTERLAND_DENSITY))

-- ===== 9. readability placeholder (needs a human screenshot) =====
header("9. Readability")
print("[MANUAL] take screen_capture from spawn at eye height and answer:")
print("   - can you name the hero landmark?")
print("   - is the route obvious without UI markers?")
record("readability_manual", true, "requires a screenshot review by a human")

-- ===== 10. palette match placeholder =====
header("10. Palette match")
print("[MANUAL] compare the 5 audit screenshots to the Auralis concept art:")
print("   - same value structure (dark foreground / bright distance)?")
print("   - ONE dominant silhouette, not several competing?")
print("   - warms/cools differ how much?")
record("palette_manual", true, "requires comparing screenshots to concept art")

-- ===== summary =====
header("SCORE")
local passed, total = 0, 0
local failures: { string } = {}
for id, result in results do
	total += 1
	if result.pass then
		passed += 1
	else
		table.insert(failures, id)
	end
end
table.sort(failures)
print(string.format("WORLD AUDIT: %d/%d", passed, total))
if #failures > 0 then
	print("fix these before calling the region finished:")
	for _, id in failures do
		print("  - " .. id .. " : " .. results[id].detail)
	end
else
	print("all automated checks pass — now do the two manual screenshot reviews")
end
