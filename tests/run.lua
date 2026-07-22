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
local GlobeRegions = require("src.core.globe_regions")
local Character = require("src.ui.character")
local DropTarget = require("src.ui.drop_target")
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
test("relevel rolls a tilted globe back so north projects straight up", function()
	-- Start upright, roll it 30 deg off vertical. Releveling is proportional (it
	-- fades near the poles), so it converges toward north-up over several frames.
	local o = Sphere.orientationFor(20, 40)
	o = Sphere.turn(o, "x", math.rad(30))
	for _ = 1, 200 do
		o = Sphere.relevel(o, math.rad(2))
	end
	-- North's screen-right component (row2 . north = o[2][3]) should be ~0, and
	-- its screen-up component (o[3][3]) positive: north points up on screen.
	assertClose(o[2][3], 0, 0.001)
	assert(o[3][3] > 0, "north should project upward after releveling")
	-- The sub-airplane point (front) must be unchanged by releveling.
	local lat, lon = Sphere.front(o)
	assertClose(lat, 20, 0.001)
	assertClose(lon, 40, 0.001)
end)
test("relevel is a no-op at a pole and leaves the front point put", function()
	-- Front exactly on the north pole: no meaningful screen "up" to level toward,
	-- so relevel must not error or move the front point.
	local o = Sphere.orientationFor(90, 0)
	o = Sphere.relevel(o, math.rad(45))
	local lat = Sphere.front(o)
	assertClose(lat, 90, 0.001)
end)
test("world looks up entities by id", function()
	local w = World.new(worldData)
	assertEq(w:country("brazil").id, "brazil")
	-- Round 1 targets the five biggest countries; slot 1 is Russia.
	assertEq(w:mission("mission_1").target_country_id, "russia")
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
test("every country's own center resolves to that country", function()
	-- With 25 countries some regions touch, so global non-overlap no longer
	-- holds; drop-off tests the target region directly (flight_map) rather than
	-- relying on countryAt. The invariant we DO keep is that each country's
	-- center reads as itself, so recognition and highlighting stay correct.
	local w = World.new(worldData)
	for _, c in ipairs(w.countries) do
		local at = w:countryAt(c.region.latitude, c.region.longitude)
		assert(at and at.id == c.id, c.id .. " center resolved to " .. tostring(at and at.id))
	end
end)
test("data integrity: five characters/missions per round, every reference resolves", function()
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
end)
test("each character is placed at the antipode of its drop-off country", function()
	local w = World.new(worldData)
	for _, c in ipairs(w.characters) do
		local target = w:country(w:mission(c.mission_id).target_country_id)
		-- Antipode is exactly 180 degrees away on the globe.
		assertClose(
			World.angularDistance(c.latitude, c.longitude, target.latitude, target.longitude),
			180,
			0.001
		)
	end
end)
test("there are five rounds covering all 25 countries exactly once", function()
	local w = World.new(worldData)
	assertEq(w:roundCount(), 5)
	assertEq(#w.countries, 25)
	local seen = {}
	for round = 1, w:roundCount() do
		w:setRound(round)
		assertEq(#w.missions, 5)
		for _, m in ipairs(w.missions) do
			assert(
				not seen[m.target_country_id],
				"country reused across rounds: " .. m.target_country_id
			)
			seen[m.target_country_id] = true
		end
	end
	local count = 0
	for _ in pairs(seen) do
		count = count + 1
	end
	assertEq(count, 25)
end)
test("advancing rounds cycles targets and loops after the last", function()
	local w = World.new(worldData)
	assertEq(w:currentRound(), 1)
	assertEq(w:mission("mission_1").target_country_id, "russia")
	w:advanceRound()
	assertEq(w:currentRound(), 2)
	assertEq(w:mission("mission_1").target_country_id, "australia")
	-- Advance past the last round: it wraps back to round 1.
	w:setRound(w:roundCount())
	w:advanceRound()
	assertEq(w:currentRound(), 1)
	assertEq(w:mission("mission_1").target_country_id, "russia")
end)
test("setRound wraps an out-of-range saved round into a valid one", function()
	local w = World.new(worldData)
	w:setRound(99) -- stale/oversized save
	assert(w:currentRound() >= 1 and w:currentRound() <= w:roundCount())
	w:setRound(0)
	assert(w:currentRound() >= 1 and w:currentRound() <= w:roundCount())
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
test("savegame encode/decode round-trips position, round, completion, and mission", function()
	local original = {
		lat = -12.5,
		lon = 47,
		round = 3,
		completed = { "character_1", "character_3" },
		activeMissionId = "mission_2",
	}
	local restored = SaveGame.decode(SaveGame.encode(original))
	assertClose(restored.lat, -12.5)
	assertClose(restored.lon, 47)
	assertEq(restored.round, 3)
	assertEq(#restored.completed, 2)
	assertEq(restored.completed[1], "character_1")
	assertEq(restored.completed[2], "character_3")
	assertEq(restored.activeMissionId, "mission_2")
end)
test("savegame defaults round to 1 when missing or invalid", function()
	assertEq(SaveGame.decode("not a table").round, 1)
	assertEq(SaveGame.normalize({ round = 0 }).round, 1)
	assertEq(SaveGame.normalize({ round = "x" }).round, 1)
	assertEq(SaveGame.normalize({ round = 4 }).round, 4)
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
test("off-screen character finder grows toward the plane, smallest at the antipode", function()
	-- depth vx: +1 at the sub-plane point, 0 at the horizon, -1 at the antipode.
	local near = Character.finderScale(1)
	local mid = Character.finderScale(0)
	local far = Character.finderScale(-1)
	assert(near > mid and mid > far, "finder must shrink with distance: " .. near .. "," .. mid .. "," .. far)
	-- Clamps outside [-1, 1] so a tiny float overshoot never explodes the size.
	assertEq(Character.finderScale(5), Character.finderScale(1))
	assertEq(Character.finderScale(-5), Character.finderScale(-1))
end)
test("drop-off finder arrow grows toward the target, smallest at the antipode", function()
	local near = DropTarget.finderScale(1)
	local mid = DropTarget.finderScale(0)
	local far = DropTarget.finderScale(-1)
	assert(near > mid and mid > far, "drop arrow must shrink with distance")
	assertEq(DropTarget.finderScale(9), DropTarget.finderScale(1)) -- clamped
	assertEq(DropTarget.finderScale(-9), DropTarget.finderScale(-1))
end)
test("plane idle animation stays small and lively while moving", function()
	-- Amplitudes stay gentle (child-friendly: no big or flashing motion).
	local maxBob, maxScale = 0, 0
	for i = 0, 200 do
		local t = i * 0.05
		local dy, scaleMul = Plane.animation(t, false)
		maxBob = math.max(maxBob, math.abs(dy))
		maxScale = math.max(maxScale, math.abs(scaleMul - 1))
	end
	assert(maxBob <= 3.001, "bob should stay within ~3px, got " .. maxBob)
	assert(maxScale <= 0.031, "scale pulse should stay within ~3%, got " .. maxScale)
	-- Wobble is larger in flight than at rest.
	local _, _, restRot = Plane.animation(0.3, false)
	local _, _, flyRot = Plane.animation(0.3, true)
	assert(math.abs(flyRot) > math.abs(restRot), "flying should wobble more than idle")
end)
-- GlobeRegions: renderer-independent country lookup from the ID mask. Uses a
-- tiny fake ImageData so the lat/lon -> pixel -> color -> id math runs headless
-- (the real PNG is validated separately under LOVE). Two 3x3 "countries" laid
-- out on an equirect grid plus black ocean.
local function fakeImageData(pixels, w, h)
	return {
		getWidth = function()
			return w
		end,
		getHeight = function()
			return h
		end,
		-- pixels keyed "x,y" -> {r,g,b} in 0..255; default black (ocean).
		getPixel = function(_, x, y)
			local c = pixels[x .. "," .. y] or { 0, 0, 0 }
			return c[1] / 255, c[2] / 255, c[3] / 255
		end,
	}
end
test("globe regions maps lat/lon through the mask to a country id, nil over ocean", function()
	local w, h = 8, 4
	-- Place a red pixel at the column/row Munich(48.14,11.58) lands on and a
	-- green pixel where Yerevan(40.18,44.51) lands; everything else is ocean.
	local function pixelFor(lat, lon)
		local u = (lon + 180) / 360
		local v = (90 - lat) / 180
		return math.floor(u * w), math.floor(v * h)
	end
	local mx, my = pixelFor(48.14, 11.58)
	local yx, yy = pixelFor(40.18, 44.51)
	local pixels = {}
	pixels[mx .. "," .. my] = { 48, 120, 30 } -- germany color
	pixels[yx .. "," .. yy] = { 156, 30, 30 } -- armenia color
	local regions = {
		byColor = {
			["48,120,30"] = { id = "germany" },
			["156,30,30"] = { id = "armenia" },
		},
		list = {},
	}
	local gr = GlobeRegions.fromImageData(fakeImageData(pixels, w, h), regions)
	assertEq(gr:countryAt(48.14, 11.58), "germany") -- Munich
	assertEq(gr:countryAt(40.18, 44.51), "armenia") -- Yerevan
	assertEq(gr:countryAt(0, -30), nil) -- central Atlantic -> ocean
end)
test("globe regions rounds 0..1 float pixels and wraps the dateline", function()
	local w, h = 8, 4
	-- Longitude 190 must wrap to -170 and sample the same column as -170.
	local gr = GlobeRegions.fromImageData(fakeImageData({}, w, h), { byColor = {}, list = {} })
	local a1 = { gr:pixelFor(0, 190) }
	local a2 = { gr:pixelFor(0, -170) }
	assertEq(a1[1], a2[1])
	assertEq(a1[2], a2[2])
	-- Clamp: extreme latitude stays inside the image bounds.
	local px, py = gr:pixelFor(90, 0)
	assert(py >= 0 and py <= h - 1, "py out of bounds: " .. py)
	assert(px >= 0 and px <= w - 1, "px out of bounds: " .. px)
end)
test("every country and narration cue has a Russian voice asset", function()
	-- Guards against drift between content/world.lua and assets/voice/ru: the
	-- flight map plays voice.<country> on flyover, mission.<country> on pickup and
	-- thanks.<country> on drop-off, so each of the 25 countries needs all three.
	local function exists(path)
		local f = io.open(path, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	for _, country in ipairs(worldData.countries) do
		for _, prefix in ipairs({ "voice", "mission", "thanks" }) do
			local path = "assets/voice/ru/" .. prefix .. "." .. country.id .. ".ogg"
			assert(exists(path), "missing voice asset: " .. path)
		end
	end
	for _, id in ipairs({ "greeting", "celebration" }) do
		assert(exists("assets/voice/ru/" .. id .. ".ogg"), "missing narration asset: " .. id .. ".ogg")
	end
end)
test("voice: gratitude plays fully before the country announcement, which has a cooldown", function()
	-- Minimal LÖVE audio mock: a source tracks only whether it is "playing";
	-- finishing a line is simulated by flipping that flag off.
	local prevLove = love
	love = {
		audio = {
			newSource = function()
				local s = { playing = false }
				function s:play()
					self.playing = true
				end
				function s:stop()
					self.playing = false
				end
				function s:isPlaying()
					return self.playing
				end
				return s
			end,
		},
		filesystem = {
			getInfo = function()
				return { type = "file" }
			end,
		},
	}
	local Audio = require("src.platform.audio")
	local a = Audio.new(function() end)
	local function finish(id)
		a.voiceCache["ru/" .. id].playing = false
	end
	local function nowPlaying()
		return (a.voice and a.voice:isPlaying()) and a.currentVoiceId or nil
	end

	-- Drop-off: the thank-you is queued (speech) and the destination is announced
	-- (ambient) on the same frame. Speech wins — the thank-you plays first.
	Audio.queueVoice(a, "ru", "thanks.brazil", true)
	Audio.announce(a, "ru", "voice.brazil")
	Audio.updateVoice(a, 0)
	assertEq(nowPlaying(), "thanks.brazil")
	-- While it plays, the announcement waits and never interrupts it.
	Audio.updateVoice(a, 0.5)
	assertEq(nowPlaying(), "thanks.brazil")
	-- Only once the thank-you ends does the country announcement play.
	finish("thanks.brazil")
	Audio.updateVoice(a, 0)
	assertEq(nowPlaying(), "voice.brazil")

	-- Cooldown: a second country cannot be announced until 4s after the first ends.
	finish("voice.brazil")
	Audio.announce(a, "ru", "voice.argentina")
	Audio.updateVoice(a, 0) -- observes the end, starts the cooldown
	assertEq(nowPlaying(), nil)
	Audio.updateVoice(a, 3.0)
	assertEq(nowPlaying(), nil)
	Audio.updateVoice(a, 1.5) -- 4s elapsed
	assertEq(nowPlaying(), "voice.argentina")

	-- Speech preempts an ambient announcement already in progress.
	Audio.queueVoice(a, "ru", "thanks.argentina", true)
	Audio.updateVoice(a, 0)
	assertEq(nowPlaying(), "thanks.argentina")

	love = prevLove
end)
print(string.format("%d tests, %d failures", total, fail))
os.exit(fail)
