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
local Player = require("src.entities.player")
local Settings = require("src.core.settings")
local Loc = require("src.core.localization")
local Inter = require("src.entities.interactable")
local Sphere = require("src.core.sphere")
local World = require("src.core.world")
local worldData = require("content.world")
local Recognition = require("src.core.recognition")
local function assertClose(a, b, eps)
	assert(math.abs(a - b) < (eps or 0.0001), tostring(a) .. " ~= " .. tostring(b))
end
test("diagonal movement is normalized", function()
	local x, y = Player.moveVector({ left = false, right = true, up = true, down = false })
	assert(math.abs(math.sqrt(x * x + y * y) - 1) < 0.0001)
end)
test("player cannot leave world bounds", function()
	local p = Player.new(10, 10)
	Player.update(p, { left = true, up = true }, 1, { x = 0, y = 0, w = 640, h = 480 }, {})
	assert(p.x >= p.radius and p.y >= p.radius)
end)
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
test("interaction activates only in range", function()
	local o = Inter.new(100, 100)
	assert(Inter.isNear(o, { x = 150, y = 100 }))
	assert(not Inter.isNear(o, { x = 250, y = 100 }))
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
print(string.format("%d tests, %d failures", total, fail))
os.exit(fail)
