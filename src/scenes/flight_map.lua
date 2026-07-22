local Gamestate = require("vendor.hump.gamestate")
local Fonts = require("src.core.fonts")
local Sphere = require("src.core.sphere")
local Input = require("src.platform.input")
local Audio = require("src.platform.audio")
local Landmass = require("src.core.landmass")
local Continents = require("content.continents")
local GlobeShader = require("src.core.globe_shader")
local GlobeRegions = require("src.core.globe_regions")
local Regions = require("content.regions")
local World = require("src.core.world")
local WorldData = require("content.world")
local Recognition = require("src.core.recognition")
-- local Airport = require("src.ui.airport") -- airport rendering disabled for now
local CharacterView = require("src.ui.character")
local ProgressPanel = require("src.ui.progress_panel")
local MissionState = require("src.core.mission_state")
local MissionBox = require("src.ui.mission_box")
local DropTarget = require("src.ui.drop_target")
local Plane = require("src.ui.plane")
local SaveGameLove = require("src.core.savegame_love")

-- Flight Map: the main playable scene. The player flies a small airplane that
-- stays fixed near the center of the screen while the globe rotates beneath it.
--
-- The globe rotates beneath a fixed airplane. We track a camera latitude/
-- longitude and rebuild the orientation each frame (Sphere.orientationFor), so
-- the world is always exactly upright and map-like with NO drift and no auto-
-- leveling: "up"/"down" change latitude (clamped to a small polar cap so the
-- pole is never a stuck point), "left"/"right" spin longitude around the axis.
local FlightMap = {}

-- Globe target (zoomed-in) and starting (far) positions for the intro animation.
-- GLOBE is mutated each frame during the zoom-in; after that it holds GLOBE_TARGET.
local GLOBE_TARGET = { x = 320, y = 320, radius = 396 }
local GLOBE_START = { x = 320, y = 250, radius = 210 }
local GLOBE = { x = GLOBE_TARGET.x, y = GLOBE_TARGET.y, radius = GLOBE_TARGET.radius }
local ZOOM_DURATION = 4 -- seconds for the opening zoom-in

local MOVE_SPEED = 45 -- degrees per second; constant, no acceleration/inertia
local GRID_STEP = 30 -- degrees between grid lines
local SEGMENTS = 48 -- samples per grid line
-- Angular degrees within which a character is interactable (~105px on screen).
-- Sized so pickup triggers when the sprite visually overlaps the plane.
local CHARACTER_RANGE = 9
-- Drop-off forgiveness: a delivery completes within this multiple of the target
-- country's region radius. >1 makes the late rounds' tiny countries less fiddly
-- to hit, while bigger countries stay proportionally easier (their radius is
-- already larger). Applied only to the completion test, not the drawn region.
local DROPOFF_RADIUS_SCALE = 1.6
local CELEBRATION_TIME = 4 -- seconds the cycle celebration plays before auto-ending (spec §17)
local FACING_STEP_TIME = 0.09 -- seconds per one-tile step when the plane turns

-- Speed curve: the zoomed-in globe makes angular movement cover more pixels,
-- and the effect is strongest at the equator where longitude rings are widest.
-- This factor eases from 60% speed at lat=0 up to 100% at lat=50° and beyond,
-- so equatorial flight feels natural while polar flight keeps full pace.
local function latSpeedFactor(lat)
	local t = math.min(1, math.abs(lat) / 50)
	return 0.6 + 0.4 * t
end

-- The globe turns on a FIXED, upright axis so it always reads like a map/globe
-- (educational clarity). We track a camera latitude/longitude and rebuild the
-- orientation each frame with Sphere.orientationFor, which keeps the north pole
-- toward screen-up. Nothing accumulates, so there is no roll drift and no
-- automatic re-leveling: "up"/"down" change latitude, "left"/"right" spin
-- longitude, and the world is always exactly upright. "up" moves straight up on
-- screen (the front-point meridian is vertical at the globe center), matching
-- the D-pad, with no tilt.
--   * MAX_LAT is a small polar cap: latitude clamps here so the pole singularity
--     is never reached. A vertical push into the cap is redirected into longitude,
--     so flying up glides you *around* the pole along the cap circle instead of
--     stalling. Sits just poleward of all content (~76°N).
local MAX_LAT = 80

-- Debug-only auto-drift directions cycled by the dbg_drift key. Each entry is a
-- lat/lon step direction (unit signs); the plane sprite turns to the resulting
-- travel direction in the movement handler.
local DRIFTS = {
	{ dLat = 0, dLon = 1 }, -- east
	{ dLat = 1, dLon = 0 }, -- north
	{ dLat = 0, dLon = -1 }, -- west
	{ dLat = -1, dLon = 0 }, -- south
}

-- Deterministic starfield so the background does not flicker frame to frame.
local function buildStars()
	local stars = {}
	local seed = 1
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, 90 do
		stars[#stars + 1] = { x = rand() * 640, y = rand() * 480, size = 1 + rand() * 1.5 }
	end
	return stars
end

function FlightMap:enter(_, app)
	self.app = app
	self.stars = buildStars()
	-- Textured Natural Earth globe. If the shader or assets fail to
	-- load (e.g. an older GPU), globe stays nil and we fall back to the simplified
	-- vector continents below, so the scene always renders.
	self.globe =
		GlobeShader.new("assets/globe/world_base.png", "assets/globe/country_ids.png", app.log)
	self.globeRegions = GlobeRegions.new("assets/globe/country_ids.png", Regions)
	self.continents = Landmass.build(Continents)
	self.world = World.new(WorldData)
	self.recognition = Recognition.new()
	self.mission = MissionState.new(self.world)
	-- Precompute each country's region outline (great-circle circle) once.
	self.countryOutlines = {}
	-- And its flat id-mask color, so the textured globe can fill the real
	-- country shape (nil for any country missing from the mask -> falls back to
	-- the great-circle outline highlight).
	self.countryColors = {}
	for _, country in ipairs(self.world.countries) do
		local r = country.region
		self.countryOutlines[country.id] =
			Sphere.circlePoints(r.latitude, r.longitude, r.radius, 40)
		if country.iso then
			self.countryColors[country.id] = self.globeRegions:colorForIso(country.iso)
		end
	end
	-- Start in the northern part of the globe, no mission active (spec §3).
	self.start = { lat = 40, lon = 10 }

	-- Restore the saved session if present (spec §20): airplane position, cycle
	-- completion, and active mission. A fresh save just yields the start state.
	local saved = SaveGameLove.load(app.log)
	self.camLat = math.max(-MAX_LAT, math.min(MAX_LAT, saved.lat))
	self.camLon = Sphere.normalizeLon(saved.lon)
	self.orientation = Sphere.orientationFor(self.camLat, self.camLon)
	-- Restore the saved round BEFORE restoring mission progress: completed ids and
	-- the active mission id are looked up against the round's characters/missions,
	-- so the round's cast must be built first. setRound wraps a stale value.
	self.world:setRound(saved.round)
	self.mission:restore(saved.completed, saved.activeMissionId)

	self.time = 0
	self.zoomT = 0
	GLOBE.radius = GLOBE_START.radius
	GLOBE.y = GLOBE_START.y
	self.currentCountryId = nil
	self.nearCharacterId = nil
	self.facing = "s" -- plane faces the viewer by default (spec §4)
	self.targetFacing = "s"
	self.facingTimer = 0
	self.moving = false
	-- Debug-only auto-drift so rotation is observable without holding a key.
	-- 0 = off; other indices pick a direction from DRIFTS.
	self.drift = 0

	-- Spoken greeting on game start (spec §8-style voice hint): "Привет, Валюша!
	-- Давай поможем твоим друзьям добраться до дома!". Quiet fallback so languages
	-- without a recording stay silent rather than beeping on entry.
	Audio.playVoice(self.app.audio, self.app.loc.language, "greeting", true)

	-- Gentle looping background music while playing. Idempotent, so resuming from
	-- pause (a push, not a re-enter) never stacks a second track. The main menu
	-- stops it on entry, which covers every path back out (including pause ->
	-- menu, where this scene's leave never fires because it is not the top state).
	Audio.startMusic(self.app.audio)
end

-- Persist the current session (spec §20): airplane front position, completed
-- characters, and the active mission id.
function FlightMap:save()
	local completed, activeMissionId = self.mission:snapshot()
	SaveGameLove.save({
		lat = self.camLat,
		lon = self.camLon,
		round = self.world:currentRound(),
		completed = completed,
		activeMissionId = activeMissionId,
	}, self.app.log)
end

-- Save on application quit too (gamestate forwards love.quit to the scene).
function FlightMap:quit()
	self:save()
end

-- Read the d-pad into a lat/lon step direction for this frame (unit signs, scaled
-- by MOVE_SPEED*dt in the caller). Conflicting directions resolve consistently
-- (vertical wins). Returns dLat, dLon, or nil when idle.
local function moveDelta(input)
	if input:down("move_up") then
		return 1, 0
	elseif input:down("move_down") then
		return -1, 0
	elseif input:down("move_right") then
		return 0, 1
	elseif input:down("move_left") then
		return 0, -1
	end
	return nil
end

function FlightMap:update(dt)
	local input = self.app.input
	input:update()
	Input.logActions(input, self.app.log)
	Audio.updateVoice(self.app.audio)

	if input:pressed("debug") then
		self.app.toggleDebug()
	end

	-- Opening zoom-in: ease from GLOBE_START to GLOBE_TARGET over ZOOM_DURATION.
	-- Quadratic ease-out (fast start, gentle settle) so it reads as a camera
	-- pulling into the scene rather than a mechanical linear clock.
	if self.zoomT < 1 then
		self.zoomT = math.min(1, self.zoomT + dt / ZOOM_DURATION)
		local ease = self.zoomT * (2 - self.zoomT)
		GLOBE.radius = GLOBE_START.radius + (GLOBE_TARGET.radius - GLOBE_START.radius) * ease
		GLOBE.y = GLOBE_START.y + (GLOBE_TARGET.y - GLOBE_START.y) * ease
	end

	-- Cycle celebration (spec §17): after the fifth mission, flight is paused
	-- and a short celebration plays. It auto-ends after a duration, or A skips
	-- it; then the game advances to the NEXT round — five new characters at new
	-- positions with new drop-off countries — looping endlessly, and free flight
	-- resumes.
	if self.celebrationTime then
		self.time = self.time + dt
		self.celebrationTime = self.celebrationTime - dt
		if self.celebrationTime <= 0 or input:pressed("interact") then
			self.celebrationTime = nil
			self.world:advanceRound()
			self.mission:reset()
			self.recognition = Recognition.new()
			self.recognizedName = nil
			self.app.log("round_advance:" .. self.world:currentRound())
		end
		return
	end

	if input:pressed("pause") then
		self:save()
		Gamestate.push(require("src.scenes.pause"), self.app, self)
		return
	end

	-- Debug-only movement helpers, gated so they never affect real gameplay.
	if self.app.debug then
		if input:pressed("dbg_drift") then
			self.drift = (self.drift + 1) % (#DRIFTS + 1)
		end
		if input:pressed("dbg_reset") then
			self.camLat = self.start.lat
			self.camLon = self.start.lon
			self.orientation = Sphere.orientationFor(self.camLat, self.camLon)
			self.drift = 0
		end
		-- Complete every remaining mission at once, then trigger the celebration,
		-- so the cycle finale is testable without flying all five (spec §17).
		if input:pressed("dbg_finish") then
			for _, character in ipairs(self.world.characters) do
				if not self.mission.completed[character.id] then
					self.mission:accept(character.id)
					self.mission:complete()
				end
			end
			self.celebrationTime = CELEBRATION_TIME
			self.app.log("cycle_celebration")
			Audio.playVoice(self.app.audio, self.app.loc.language, "celebration", true)
		end
	else
		self.drift = 0
	end

	local dLat, dLon = moveDelta(input)
	-- Manual input always wins and cancels any active drift.
	if dLat then
		self.drift = 0
	elseif self.drift > 0 then
		local dir = DRIFTS[self.drift]
		dLat, dLon = dir.dLat, dir.dLon
	end
	if dLat then
		local step = MOVE_SPEED * dt * latSpeedFactor(self.camLat)
		local newLat = self.camLat + dLat * step
		local lonDelta = dLon * step
		-- Glide along the polar cap: latitude clamps at the cap circle, and any
		-- vertical push that would cross it is redirected into longitude, so a pure
		-- up/down press flies you *around* the pole along the cap instead of
		-- stalling. The pole is never reached, so the world stays exactly upright.
		if newLat > MAX_LAT then
			lonDelta = lonDelta + (newLat - MAX_LAT)
			newLat = MAX_LAT
		elseif newLat < -MAX_LAT then
			lonDelta = lonDelta + (-MAX_LAT - newLat)
			newLat = -MAX_LAT
		end
		local latDelta = newLat - self.camLat
		self.camLat = newLat
		self.camLon = Sphere.normalizeLon(self.camLon + lonDelta)
		self.orientation = Sphere.orientationFor(self.camLat, self.camLon)
		-- Face the ACTUAL travel direction, not the pressed key: while gliding
		-- along the cap the motion is longitudinal, so the plane turns to fly along
		-- the circle instead of pointing at the pole it can't reach. The sprite
		-- spins toward this target through the intermediate compass tiles (below).
		local facing
		if lonDelta ~= 0 and math.abs(lonDelta) >= math.abs(latDelta) then
			facing = Plane.facingFor("z", lonDelta > 0 and -1 or 1)
		elseif latDelta ~= 0 then
			facing = Plane.facingFor("y", latDelta > 0 and 1 or -1)
		end
		self.targetFacing = facing or self.targetFacing
	end
	self.moving = dLat ~= nil

	-- Step the drawn facing one tile toward the target at a fixed rate, so a
	-- left->right turn visibly rotates through the diagonal/vertical sprites
	-- instead of snapping (spec §4).
	self.facingTimer = (self.facingTimer or 0) + dt
	while self.facingTimer >= FACING_STEP_TIME do
		self.facingTimer = self.facingTimer - FACING_STEP_TIME
		self.facing = Plane.stepToward(self.facing, self.targetFacing)
	end

	-- Country detection uses the world point beneath the airplane (the tracked
	-- camera lat/lon, which is exactly the view front).
	local lat, lon = self.camLat, self.camLon
	local country = self.world:countryAt(lat, lon)
	self.currentCountryId = country and country.id or nil
	local recognized = self.recognition:update(self.currentCountryId, dt)
	if recognized then
		local named = self.world:country(recognized)
		self.app.log("recognized:" .. recognized)
		-- quiet=true: only the countries that have a recording speak; the rest of
		-- the 25 stay silent instead of beeping every time you fly over them.
		Audio.playVoice(self.app.audio, self.app.loc.language, "voice." .. recognized, true)
		self.recognizedName = self.app.loc:t(named.name_key)
	elseif not self.recognition.recognizedId then
		self.recognizedName = nil
	end

	-- Nearest interactable character beneath the plane (spec §11), used for the
	-- stronger glow and as the A-button acceptance target. With the generous
	-- range, zones can overlap, so pick the closest character rather than the
	-- first one found.
	local previousNear = self.nearCharacterId
	self.nearCharacterId = nil
	local nearest = CHARACTER_RANGE
	for _, character in ipairs(self.mission:visibleCharacters()) do
		local d = World.angularDistance(lat, lon, character.latitude, character.longitude)
		if d <= nearest then
			nearest = d
			self.nearCharacterId = character.id
		end
	end
	-- Play a gentle hover blip when we first move onto a character (edge-triggered
	-- so it does not repeat every frame while lingering over the same one).
	if self.nearCharacterId and self.nearCharacterId ~= previousNear then
		Audio.playHover(self.app.audio)
	end

	-- A is the single interaction button (spec §6). Its effect depends on state:
	-- Auto-pickup: fly close enough to a character and the mission starts
	-- automatically. The character is removed from visibleCharacters() on
	-- acceptance, so nearCharacterId becomes nil next frame — no double-trigger.
	if not self.mission:isActive() and self.nearCharacterId then
		if self.mission:accept(self.nearCharacterId) then
			self.app.log("mission_accept:" .. self.nearCharacterId)
			local accepted = self.mission:activeMission()
			Audio.playVoice(self.app.audio, self.app.loc.language, accepted.id)
		end
	end

	-- Auto-dropoff: fly over the target country and the mission completes
	-- automatically. isActive() turns false after completion, so this fires once.
	-- We test the TARGET's own region directly rather than currentCountryId,
	-- because with 25 countries some regions overlap and countryAt only returns
	-- the first match — a direct test guarantees the drop-off always registers.
	if self.mission:isActive() then
		local mission = self.mission:activeMission()
		local target = self.world:country(mission.target_country_id)
		local tr = target.region
		if World.angularDistance(lat, lon, tr.latitude, tr.longitude) <= tr.radius * DROPOFF_RADIUS_SCALE then
			local doneCharacter = self.mission:complete()
			if doneCharacter then
				self.app.log("mission_complete:" .. doneCharacter)
				if self.mission:allCompleted() then
					self.celebrationTime = CELEBRATION_TIME
					self.app.log("cycle_celebration")
					Audio.queueVoice(self.app.audio, self.app.loc.language, "celebration", true)
				else
					Audio.queueVoice(self.app.audio, self.app.loc.language, "success", true)
				end
			end
		end
	end

	-- B still cancels the active mission manually if needed.
	if input:pressed("back") and self.mission:isActive() then
		if self.mission:cancel() then
			self.app.log("mission_cancel")
			Audio.playFeedback(self.app.audio)
		end
	end

	-- Mission guidance: is the target country's region visible on screen? Use
	-- the region center plus its outline samples, so a partial edge counts too.
	-- With the zoomed globe the sphere extends beyond the 640×480 viewport, so
	-- being on the front hemisphere is not sufficient — we also check screen bounds.
	self.targetVisible = false
	local mission = self.mission:activeMission()
	if mission then
		local target = self.world:country(mission.target_country_id)
		local sx, sy, onFront = Sphere.project(
			self.orientation,
			target.region.latitude,
			target.region.longitude,
			GLOBE.radius,
			GLOBE.x,
			GLOBE.y
		)
		self.targetVisible = onFront and sx >= 0 and sx <= 640 and sy >= 0 and sy <= 480
		if not self.targetVisible then
			for _, p in ipairs(self.countryOutlines[target.id]) do
				local px, py, v =
					Sphere.project(self.orientation, p[1], p[2], GLOBE.radius, GLOBE.x, GLOBE.y)
				if v and px >= 0 and px <= 640 and py >= 0 and py <= 480 then
					self.targetVisible = true
					break
				end
			end
		end
	end

	self.time = self.time + dt
end

local function drawStars(stars)
	love.graphics.setColor(1, 1, 1, 0.85)
	for _, star in ipairs(stars) do
		love.graphics.circle("fill", star.x, star.y, star.size)
	end
end

-- Draw one grid line by sampling world points and projecting them. A break in
-- visibility (point passing behind the horizon) starts a new polyline so lines
-- disappear naturally at the edge instead of streaking across the disc.
local function drawGridLine(points, orientation)
	local run = {}
	local function flush()
		if #run >= 4 then
			love.graphics.line(run)
		end
		run = {}
	end
	for _, p in ipairs(points) do
		local sx, sy, visible =
			Sphere.project(orientation, p[1], p[2], GLOBE.radius, GLOBE.x, GLOBE.y)
		if visible then
			run[#run + 1] = sx
			run[#run + 1] = sy
		else
			flush()
		end
	end
	flush()
end

function FlightMap:drawGlobe()
	local orientation = self.orientation

	if self.globe then
		-- Textured Natural Earth globe with the mission target and the recognized
		-- country filled on their real shapes (via the id mask).
		local mission = self.mission:activeMission()
		local targetId = mission and mission.target_country_id or nil
		local targetColor = targetId and self.countryColors[targetId] or nil
		if targetColor then
			-- Pulse strength tracks the completion-available state: brightest while
			-- the plane is over the target (spec §15).
			local overTarget = self.currentCountryId == targetId
			local pulse = overTarget and (0.7 + 0.3 * math.sin(self.time * 6)) or 0.5
			self.globe:setHighlight(targetColor, pulse)
		else
			self.globe:setHighlight(nil)
		end
		local recognizedId = self.recognition.recognizedId
		local recognizedColor = recognizedId and self.countryColors[recognizedId] or nil
		self.globe:setSecondaryHighlight(recognizedColor)
		self.globe:draw(orientation, GLOBE)
	else
		-- Fallback: flat ocean sphere plus simplified vector continents.
		love.graphics.setColor(0.16, 0.42, 0.7)
		love.graphics.circle("fill", GLOBE.x, GLOBE.y, GLOBE.radius)
		Landmass.draw(self.continents, orientation, GLOBE)
	end

	-- Lat/lon graticule rotating beneath the plane.
	love.graphics.setColor(0.35, 0.62, 0.85, 0.75)
	love.graphics.setLineWidth(1)
	-- Parallels (constant latitude).
	for lat = -60, 60, GRID_STEP do
		local pts = {}
		for i = 0, SEGMENTS do
			pts[#pts + 1] = { lat, -180 + i * 360 / SEGMENTS }
		end
		drawGridLine(pts, orientation)
	end
	-- Meridians (constant longitude).
	for lon = -180, 150, GRID_STEP do
		local pts = {}
		for i = 0, SEGMENTS do
			pts[#pts + 1] = { -90 + i * 180 / SEGMENTS, lon }
		end
		drawGridLine(pts, orientation)
	end

	-- Country emphasis. With the textured globe, the mission target and the
	-- recognized country are filled on their real shapes by the shader (above),
	-- so we skip the great-circle outline rings that only approximate them. The
	-- rings remain the emphasis in the vector fallback.
	if not self.globe then
		self:drawCountries(orientation)
	end
	-- Airport rendering is disabled for now: airports are locked with no logic
	-- behind them yet. Data + src/ui/airport.lua stay for when levels arrive.
	-- Airport.draw(self.world.airports, orientation, GLOBE)
	-- Mission characters visible in the current state (spec §10).
	CharacterView.draw(
		self.mission:visibleCharacters(),
		orientation,
		GLOBE,
		self.time,
		self.nearCharacterId
	)

	-- Horizon rim on top.
	love.graphics.setColor(0.09, 0.24, 0.45)
	love.graphics.setLineWidth(6)
	love.graphics.circle("line", GLOBE.x, GLOBE.y, GLOBE.radius)
end

-- Outline each playable country's region. Highlights, brightest first:
--   * mission target while the plane is over it (completion available, spec §15)
--   * mission target while visible on screen (spec §13)
--   * country currently recognised by dwelling (spec §8)
--   * default subtle outline
function FlightMap:drawCountries(orientation)
	local mission = self.mission:activeMission()
	local targetId = mission and mission.target_country_id or nil
	for _, country in ipairs(self.world.countries) do
		local isTarget = country.id == targetId
		local overTarget = isTarget and self.currentCountryId == country.id
		if overTarget then
			-- Pulsing, strongest highlight: pressing A here completes the mission.
			local pulse = 0.7 + 0.3 * math.sin(self.time * 6)
			love.graphics.setColor(0.5, 1, 0.5, pulse)
			love.graphics.setLineWidth(5)
		elseif isTarget and self.targetVisible then
			love.graphics.setColor(0.5, 1, 0.6, 0.9)
			love.graphics.setLineWidth(4)
		elseif self.recognition.recognizedId == country.id then
			love.graphics.setColor(1, 0.95, 0.5, 0.95)
			love.graphics.setLineWidth(3)
		else
			love.graphics.setColor(0.95, 0.85, 0.4, 0.5)
			love.graphics.setLineWidth(2)
		end
		drawGridLine(self.countryOutlines[country.id], orientation)
	end
end

local function drawAirplane(x, y, facing, time, moving)
	Plane.draw(x, y, facing, time, moving)
end

function FlightMap:drawWorld()
	love.graphics.setColor(0.04, 0.05, 0.12)
	love.graphics.rectangle("fill", 0, 0, 640, 480)
	drawStars(self.stars)
	self:drawGlobe()
	drawAirplane(GLOBE.x, GLOBE.y, self.facing, self.time, self.moving)

	-- Permanent five-slot progress panel at the top (spec §16).
	ProgressPanel.draw(self.world.characters, self.mission:panelStates())

	-- Mission guidance while a mission is active (spec §13, §14).
	local mission = self.mission:activeMission()
	if mission then
		local target = self.world:country(mission.target_country_id)
		-- Drop-off guidance, mirroring the character finders: a bobbing 3D pin at
		-- the country center when it is on screen, or a proximity-scaled arrow on
		-- the edge ring pointing the way when it is off screen.
		local tsx, tsy, tvisible, tdepth = Sphere.project(
			self.orientation,
			target.region.latitude,
			target.region.longitude,
			GLOBE.radius,
			GLOBE.x,
			GLOBE.y
		)
		local centerOnScreen = tvisible and tsx >= 0 and tsx <= 640 and tsy >= 0 and tsy <= 480
		if centerOnScreen then
			DropTarget.drawPin(tsx, tsy, self.time)
		else
			local dx, dy = Sphere.screenDirection(
				self.orientation,
				target.region.latitude,
				target.region.longitude
			)
			DropTarget.drawFinder(dx, dy, tdepth, self.time)
		end
		local character = self.world:character(mission.character_id)
		MissionBox.draw(
			target,
			self.app.loc:t(target.name_key),
			character,
			self.app.loc:t("flight.wants_to_go")
		)
	end

	-- Recognised country name, shown as a learning aid (spec §8) as a strip near
	-- the top edge. Play is fully possible without reading, so this is
	-- supplementary.
	if self.recognizedName then
		love.graphics.setFont(Fonts.get(26))
		local w = 360
		love.graphics.setColor(0.05, 0.1, 0.2, 0.8)
		love.graphics.rectangle("fill", (640 - w) / 2, 8, w, 44, 12)
		love.graphics.setColor(1, 0.97, 0.7)
		love.graphics.printf(self.recognizedName, (640 - w) / 2, 18, w, "center")
	end

	-- Cycle celebration overlay (spec §17): shown after all five are done.
	if self.celebrationTime then
		self:drawCelebration()
	end

	-- TEMP diagnostic HUD (always visible, even with debug off): lets us read the
	-- exact end-of-game state on the device without SSH. Remove once the
	-- end-screen input issue is resolved.
	do
		local m = self.mission
		local am = m:activeMission()
		love.graphics.setFont(Fonts.get(12))
		love.graphics.setColor(0, 0, 0, 0.6)
		love.graphics.rectangle("fill", 4, 452, 632, 24)
		love.graphics.setColor(1, 1, 0.6)
		love.graphics.print(
			string.format(
				"state=%s over=%s target=%s celeb=%s done=%s A=%s",
				m.state,
				self.currentCountryId or "-",
				am and am.target_country_id or "-",
				self.celebrationTime and string.format("%.1f", self.celebrationTime) or "-",
				tostring(m:allCompleted()),
				(self._aFlash or 0) > 0 and "PRESSED" or "-"
			),
			10,
			456
		)
	end

	love.graphics.setFont(Fonts.get(14))
	local driftNames = { "east", "north", "west", "south" }
	local lat, lon = self.camLat, self.camLon
	self.app.drawDebug(
		"flight_map",
		string.format(
			"lat: %.1f\nlon: %.1f\nover: %s\nnear: %s\nstate: %s\ndrift[0]: %s\nreset[9]",
			lat,
			lon,
			self.currentCountryId or "-",
			self.nearCharacterId or "-",
			self.mission.state,
			self.drift > 0 and driftNames[self.drift] or "off"
		)
	)
end

function FlightMap:draw()
	self.app.drawScaled(function()
		self:drawWorld()
	end)
end

-- Cycle celebration overlay: dim the scene, show festive bursts and a message
-- (spec §17). Kept simple and gentle per the child-friendly rules (no flashing).
function FlightMap:drawCelebration()
	love.graphics.setColor(0.03, 0.05, 0.12, 0.7)
	love.graphics.rectangle("fill", 0, 0, 640, 480)

	-- Soft radiating bursts around the center, slowly rotating.
	local colors = { { 1, 0.8, 0.3 }, { 0.5, 0.9, 1 }, { 1, 0.5, 0.6 }, { 0.6, 1, 0.6 } }
	for i = 1, 12 do
		local angle = self.time * 0.8 + i * (math.pi * 2 / 12)
		local r = 120 + 20 * math.sin(self.time * 2 + i)
		local x = 320 + math.cos(angle) * r
		local y = 220 + math.sin(angle) * r
		local c = colors[(i % #colors) + 1]
		love.graphics.setColor(c[1], c[2], c[3], 0.85)
		love.graphics.circle("fill", x, y, 8 + 3 * math.sin(self.time * 3 + i))
	end

	-- Row of five checks to celebrate the completed cycle.
	love.graphics.setColor(0.2, 0.85, 0.35, 1)
	for i = 0, 4 do
		local x = 250 + i * 30
		love.graphics.setLineWidth(4)
		love.graphics.line(x, 220, x + 8, 232, x + 20, 208)
	end

	love.graphics.setFont(Fonts.get(32))
	love.graphics.setColor(1, 0.97, 0.7, 1)
	love.graphics.printf(self.app.loc:t("flight.cycle_complete"), 60, 260, 520, "center")
end

return FlightMap
