package.path = "./?.lua;./?/init.lua;" .. package.path
local total, fail = 0, 0
local function test(name, fn)
	total = total + 1
	local ok, err = pcall(fn)
	if ok then
		print("ok - " .. name)
	else
		fail = fail + 1
		print("not ok - " .. name .. " - " .. tostring(err))
	end
end
local function assertEq(a, b)
	assert(a == b, tostring(a) .. " ~= " .. tostring(b))
end
local Settings = require("src.core.settings")
local Loc = require("src.core.localization")
local Sphere = require("src.core.sphere")
local World = require("src.core.world")
local worldData = require("content.world")
local Recognition = require("src.core.recognition")
local MissionState = require("src.core.mission_state")
local SaveGame = require("src.core.savegame")
local Plane = require("src.ui.plane")
local function assertClose(a, b, eps)
	assert(math.abs(a - b) < (eps or 0.0001), tostring(a) .. " ~= " .. tostring(b))
end
test("malformed settings fall back", function()
	local s = Settings.decode("not lua")
	assertEq(s.language, "ru")
	assertEq(s.fullscreen, false)
end)
test("missing German falls back to Russian", function()
	local l = Loc.new("de")
	assertEq(l:t("missing.key"), "missing.key")
	assertEq(l:t("menu.start"), "Start")
end)
test("switching language updates menu labels", function()
	local l = Loc.new("ru")
	assertEq(l:t("menu.start"), "Старт")
	l:setLanguage("de")
	assertEq(l:t("menu.start"), "Start")
end)
test("longitude wraps continuously", function()
	assertClose(Sphere.normalizeLon(190), -170)
	assertClose(Sphere.normalizeLon(-190), 170)
	-- +180 and -180 are the same meridian; the function returns the -180 form.
	assertClose(Sphere.normalizeLon(180), -180)
	assertClose(Sphere.normalizeLon(0), 0)
end)
test("lat/lon round-trips through the world vector", function()
	local x, y, z = Sphere.latLonToVec(30, 45)
	local lat, lon = Sphere.vecToLatLon(x, y, z)
	assertClose(lat, 30)
	assertClose(lon, 45)
end)
test("orientation places its target point at the view front", function()
	local o = Sphere.orientationFor(40, 10)
	local lat, lon = Sphere.front(o)
	assertClose(lat, 40)
	assertClose(lon, 10)
end)
test("the front point projects to the globe center and is visible", function()
	local o = Sphere.orientationFor(30, 45)
	local sx, sy, visible = Sphere.project(o, 30, 45, 200, 320, 240)
	assertClose(sx, 320)
	assertClose(sy, 240)
	assert(visible)
end)
test("the antipode of the front is hidden behind the horizon", function()
	local o = Sphere.orientationFor(30, 45)
	local _, _, visible = Sphere.project(o, -30, -135, 200, 320, 240)
	assert(not visible)
end)
test("flying up over the pole stays continuous (no stall at the pole)", function()
	-- Start near the north pole and turn 20 deg 'up' (screen y axis). The front
	-- must pass the pole and continue onto the far meridian, not stop at lat 90.
	local o = Sphere.orientationFor(80, 0)
	o = Sphere.turn(o, "y", math.rad(20))
	local lat, lon = Sphere.front(o)
	assertClose(lat, 80)
	assertClose(math.abs(lon), 180, 0.001)
end)
test("turning up by 90 deg lands exactly on the pole without error", function()
	local o = Sphere.orientationFor(0, 0)
	o = Sphere.turn(o, "y", math.rad(90))
	local lat = Sphere.front(o)
	assertClose(lat, 90)
end)
test("orientation stays orthonormal after many turns", function()
	local o = Sphere.orientationFor(10, 20)
	for _ = 1, 500 do
		o = Sphere.turn(o, "y", math.rad(7))
		o = Sphere.turn(o, "z", math.rad(-5))
	end
	-- Front vector must remain unit length (rows stay normalized).
	local r = o[1]
	assertClose(math.sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3]), 1, 0.0001)
end)
test("world looks up entities by id", function()
	local w = World.new(worldData)
	assertEq(w:country("brazil").id, "brazil")
	assertEq(w:airport("brazil_airport").country_id, "brazil")
	assertEq(w:mission("mission_1").target_country_id, "brazil")
	assertEq(w:character("character_1").mission_id, "mission_1")
	assertEq(w:country("nope"), nil)
end)
test("angular distance is zero at a point and 180 at its antipode", function()
	assertClose(World.angularDistance(10, 20, 10, 20), 0)
	assertClose(World.angularDistance(0, 0, 0, 180), 180)
end)
test("countryAt detects the country beneath a point and nil in open ocean", function()
	local w = World.new(worldData)
	local brazil = w:country("brazil")
	-- Exactly over Brazil's region center.
	assertEq(w:countryAt(brazil.region.latitude, brazil.region.longitude).id, "brazil")
	-- Middle of the Pacific: no playable country.
	assertEq(w:countryAt(0, -160), nil)
end)
test("country regions do not overlap", function()
	local w = World.new(worldData)
	for i = 1, #w.countries do
		for j = i + 1, #w.countries do
			local a, b = w.countries[i].region, w.countries[j].region
			local d = World.angularDistance(a.latitude, a.longitude, b.latitude, b.longitude)
			assert(
				d > a.radius + b.radius,
				w.countries[i].id .. " overlaps " .. w.countries[j].id .. " (gap " .. d .. ")"
			)
		end
	end
end)
test("data integrity: five characters, and every reference resolves", function()
	local w = World.new(worldData)
	assertEq(#w.characters, 5)
	assertEq(#w.missions, 5)
	for _, m in ipairs(w.missions) do
		assert(w:country(m.target_country_id), "mission target missing: " .. m.target_country_id)
		assert(w:character(m.character_id), "mission character missing: " .. m.character_id)
	end
	for _, c in ipairs(w.characters) do
		assert(w:mission(c.mission_id), "character mission missing: " .. c.mission_id)
	end
	for _, c in ipairs(w.countries) do
		assert(w:airport(c.airport_id), "country airport missing: " .. c.airport_id)
	end
end)
test("circle points all sit at the given angular radius from the center", function()
	local pts = Sphere.circlePoints(20, 40, 10, 24)
	for _, p in ipairs(pts) do
		assertClose(World.angularDistance(20, 40, p[1], p[2]), 10, 0.001)
	end
end)
test("screen direction points right for a target due east and is visible", function()
	local o = Sphere.orientationFor(0, 0)
	local dx, dy, visible = Sphere.screenDirection(o, 0, 45)
	assert(visible)
	assert(dx > 0.9, "expected mostly-rightward dx, got " .. dx)
	assertClose(dy, 0, 0.001)
end)
test("screen direction still aims toward a target behind the horizon", function()
	local o = Sphere.orientationFor(0, 0)
	-- Target at lon 135 is on the far hemisphere but still to the east/right.
	local dx, _, visible = Sphere.screenDirection(o, 0, 135)
	assert(not visible)
	assert(dx > 0, "arrow should still point rightward toward an eastern target")
end)
test("recognition fires once after the dwell time, not before", function()
	local r = Recognition.new(1.0)
	assertEq(r:update("brazil", 0.5), nil) -- not yet
	assertEq(r:update("brazil", 0.4), nil) -- 0.9s, still short
	assertEq(r:update("brazil", 0.2), "brazil") -- crosses 1.0s -> recognised
	assertEq(r:update("brazil", 0.5), nil) -- stays inside, does not re-fire
end)
test("recognition resets when leaving and can re-recognise on return", function()
	local r = Recognition.new(1.0)
	assertEq(r:update("brazil", 1.0), "brazil")
	assertEq(r:update(nil, 0.5), nil) -- left to open ocean
	assertEq(r.recognizedId, nil)
	assertEq(r:update("brazil", 1.0), "brazil") -- re-enter, recognise again
end)
test("recognition dwell resets when switching countries directly", function()
	local r = Recognition.new(1.0)
	assertEq(r:update("brazil", 0.8), nil)
	assertEq(r:update("germany", 0.8), nil) -- switched; timer restarted, not 1.6
	assertEq(r:update("germany", 0.3), "germany") -- 1.1s over germany
end)
test("mission starts in free flight with nothing active or completed", function()
	local m = MissionState.new(World.new(worldData))
	assertEq(m.state, MissionState.FREE_FLIGHT)
	assertEq(m:isActive(), false)
	assertEq(#m:visibleCharacters(), 5) -- all five available
	assertEq(m:panelStates().character_1, "available")
end)
test("accepting a mission activates it and hides all characters", function()
	local m = MissionState.new(World.new(worldData))
	assertEq(m:accept("character_1"), true)
	assertEq(m.state, MissionState.MISSION_ACTIVE)
	assertEq(m:activeMission().id, "mission_1")
	assertEq(#m:visibleCharacters(), 0) -- all characters leave the globe (spec §11)
	assertEq(m:panelStates().character_1, "active")
	assertEq(m:accept("character_2"), false) -- only one mission at a time
end)
test("cancelling a mission returns to free flight without completing it", function()
	local m = MissionState.new(World.new(worldData))
	m:accept("character_1")
	assertEq(m:cancel(), true)
	assertEq(m.state, MissionState.FREE_FLIGHT)
	assertEq(m.completed.character_1, nil)
	assertEq(#m:visibleCharacters(), 5) -- all restored
end)
test("completing a mission marks the character done and removes it from globe", function()
	local m = MissionState.new(World.new(worldData))
	m:accept("character_1")
	assertEq(m:complete(), "character_1")
	assertEq(m.state, MissionState.FREE_FLIGHT)
	assertEq(m.completed.character_1, true)
	assertEq(m:panelStates().character_1, "completed")
	assertEq(#m:visibleCharacters(), 4) -- completed character stays hidden
	assertEq(m:accept("character_1"), false) -- cannot re-accept a completed one
end)
test("completing all five missions is detected, and reset restores the cycle", function()
	local w = World.new(worldData)
	local m = MissionState.new(w)
	for _, c in ipairs(w.characters) do
		m:accept(c.id)
		m:complete()
	end
	assertEq(m:allCompleted(), true)
	m:reset()
	assertEq(m:allCompleted(), false)
	assertEq(#m:visibleCharacters(), 5)
end)
test("mission snapshot and restore round-trip preserves progress", function()
	local w = World.new(worldData)
	local m = MissionState.new(w)
	m:accept("character_1")
	m:complete() -- character_1 done
	m:accept("character_2") -- character_2 active
	local completed, activeId = m:snapshot()
	assertEq(#completed, 1)
	assertEq(completed[1], "character_1")
	assertEq(activeId, "mission_2")

	local m2 = MissionState.new(w)
	m2:restore(completed, activeId)
	assertEq(m2.completed.character_1, true)
	assertEq(m2.activeMissionId, "mission_2")
	assertEq(m2.state, MissionState.MISSION_ACTIVE)
end)
test("restore ignores unknown ids and stale active missions", function()
	local w = World.new(worldData)
	local m = MissionState.new(w)
	-- Unknown completed id dropped; active mission whose character is already
	-- completed is not restored as active.
	m:restore({ "character_1", "ghost" }, "mission_1")
	assertEq(m.completed.character_1, true)
	assertEq(m.completed.ghost, nil)
	assertEq(m:isActive(), false)
end)
test("savegame decode tolerates garbage and falls back to fresh", function()
	local s = SaveGame.decode("not a table")
	assertEq(s.lat, 40)
	assertEq(s.lon, 10)
	assertEq(#s.completed, 0)
	assertEq(s.activeMissionId, nil)
end)
test("savegame encode/decode round-trips position, completion, and mission", function()
	local original = {
		lat = -12.5,
		lon = 47,
		completed = { "character_1", "character_3" },
		activeMissionId = "mission_2",
	}
	local restored = SaveGame.decode(SaveGame.encode(original))
	assertClose(restored.lat, -12.5)
	assertClose(restored.lon, 47)
	assertEq(#restored.completed, 2)
	assertEq(restored.completed[1], "character_1")
	assertEq(restored.completed[2], "character_3")
	assertEq(restored.activeMissionId, "mission_2")
end)
test("savegame normalize clamps bad latitude and drops non-string ids", function()
	local s = SaveGame.normalize({ lat = 999, lon = "x", completed = { "ok", 5, true } })
	assertEq(s.lat, 40) -- out-of-range latitude rejected -> default
	assertEq(s.lon, 10) -- non-number longitude rejected -> default
	assertEq(#s.completed, 1)
	assertEq(s.completed[1], "ok")
end)
test("plane facing steps one tile toward the target, not snapping", function()
	-- west -> east must pass through a diagonal/vertical tile, not jump directly.
	local step1 = Plane.stepToward("w", "e")
	assert(step1 == "nw" or step1 == "sw", "first step should be a diagonal, got " .. step1)
	assert(step1 ~= "e", "must not snap straight to the target")
end)
test("plane facing reaches the target over several steps along shortest arc", function()
	local f = "w"
	for _ = 1, 8 do
		f = Plane.stepToward(f, "e")
		if f == "e" then
			break
		end
	end
	assertEq(f, "e")
end)
test("plane facing takes the shortest arc (n -> e goes clockwise via ne)", function()
	assertEq(Plane.stepToward("n", "e"), "ne")
	assertEq(Plane.stepToward("n", "w"), "nw") -- counter-clockwise is shorter here
end)
test("plane facing holds when already at the target", function()
	assertEq(Plane.stepToward("e", "e"), "e")
end)
print(string.format("%d tests, %d failures", total, fail))
os.exit(fail)
