local Gamestate = require("vendor.hump.gamestate")
local Fonts = require("src.core.fonts")
local Sphere = require("src.core.sphere")
local Input = require("src.platform.input")
local Audio = require("src.platform.audio")
local Landmass = require("src.core.landmass")
local Continents = require("content.continents")
local World = require("src.core.world")
local WorldData = require("content.world")
local Recognition = require("src.core.recognition")
local Airport = require("src.ui.airport")
local CharacterView = require("src.ui.character")
local ProgressPanel = require("src.ui.progress_panel")
local MissionState = require("src.core.mission_state")
local MissionBox = require("src.ui.mission_box")
local TargetArrow = require("src.ui.target_arrow")
local SaveGameLove = require("src.core.savegame_love")

-- Flight Map: the main playable scene. The player flies a small airplane that
-- stays fixed near the center of the screen while the globe rotates beneath it.
--
-- Movement uses a free 3D orientation (see src/core/sphere.lua) rather than a
-- camera lat/lon. This avoids polar singularities: "up" rotates the globe about
-- the screen's horizontal axis, so you fly straight over a pole and keep going
-- instead of stalling there. The airplane stays pinned at the globe center.
local FlightMap = {}

-- Screen-space placement and size of the globe. The airplane sits at the globe
-- center so it reads as "above" the planet surface.
local GLOBE = {
	x = 320,
	y = 250,
	radius = 210,
}

local MOVE_SPEED = 45 -- degrees per second; constant, no acceleration/inertia
local GRID_STEP = 30 -- degrees between grid lines
local SEGMENTS = 48 -- samples per grid line
local CHARACTER_RANGE = 7 -- angular degrees within which a character is interactable
local CELEBRATION_TIME = 4 -- seconds the cycle celebration plays before auto-ending (spec §17)

-- Debug-only auto-drift directions cycled by the dbg_drift key. Each entry is a
-- screen-axis turn {axis, sign}: "y" = up/down flight, "z" = left/right flight.
local DRIFTS = {
	{ "z", -1 }, -- east (globe spins so terrain moves left)
	{ "y", 1 }, -- north
	{ "z", 1 }, -- west
	{ "y", -1 }, -- south
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
	self.continents = Landmass.build(Continents)
	self.world = World.new(WorldData)
	self.recognition = Recognition.new()
	self.mission = MissionState.new(self.world)
	-- Precompute each country's region outline (great-circle circle) once.
	self.countryOutlines = {}
	for _, country in ipairs(self.world.countries) do
		local r = country.region
		self.countryOutlines[country.id] =
			Sphere.circlePoints(r.latitude, r.longitude, r.radius, 40)
	end
	-- Start in the northern part of the globe, no mission active (spec §3).
	self.start = { lat = 40, lon = 10 }

	-- Restore the saved session if present (spec §20): airplane position, cycle
	-- completion, and active mission. A fresh save just yields the start state.
	local saved = SaveGameLove.load(app.log)
	self.orientation = Sphere.orientationFor(saved.lat, saved.lon)
	self.mission:restore(saved.completed, saved.activeMissionId)

	self.time = 0
	self.currentCountryId = nil
	self.nearCharacterId = nil
	-- Debug-only auto-drift so rotation is observable without holding a key.
	-- 0 = off; other indices pick a direction from DRIFTS.
	self.drift = 0
end

-- Persist the current session (spec §20): airplane front position, completed
-- characters, and the active mission id.
function FlightMap:save()
	local lat, lon = Sphere.front(self.orientation)
	local completed, activeMissionId = self.mission:snapshot()
	SaveGameLove.save({
		lat = lat,
		lon = lon,
		completed = completed,
		activeMissionId = activeMissionId,
	}, self.app.log)
end

-- Save on application quit too (gamestate forwards love.quit to the scene).
function FlightMap:quit()
	self:save()
end

-- Read the d-pad into a screen-axis turn for this frame. Conflicting directions
-- resolve consistently (vertical wins) and there is no diagonal requirement.
-- Returns an axis ("y"/"z") and signed angle in radians, or nil when idle.
local function turnDelta(input, dt)
	local step = math.rad(MOVE_SPEED * dt)
	if input:down("move_up") then
		return "y", step
	elseif input:down("move_down") then
		return "y", -step
	elseif input:down("move_right") then
		return "z", -step
	elseif input:down("move_left") then
		return "z", step
	end
	return nil
end

function FlightMap:update(dt)
	local input = self.app.input
	input:update()
	Input.logActions(input, self.app.log)

	if input:pressed("debug") then
		self.app.toggleDebug()
	end

	-- Cycle celebration (spec §17): after the fifth mission, flight is paused
	-- and a short celebration plays. It auto-ends after a duration, or A skips
	-- it; then the cycle resets and free flight resumes.
	if self.celebrationTime then
		self.time = self.time + dt
		self.celebrationTime = self.celebrationTime - dt
		if self.celebrationTime <= 0 or input:pressed("interact") then
			self.celebrationTime = nil
			self.mission:reset()
			self.recognition = Recognition.new()
			self.recognizedName = nil
			self.app.log("cycle_reset")
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
			self.orientation = Sphere.orientationFor(self.start.lat, self.start.lon)
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
		end
	else
		self.drift = 0
	end

	local axis, angle = turnDelta(input, dt)
	-- Manual input always wins and cancels any active drift.
	if axis then
		self.drift = 0
	elseif self.drift > 0 then
		local dir = DRIFTS[self.drift]
		axis, angle = dir[1], dir[2] * math.rad(MOVE_SPEED * dt)
	end
	if axis then
		self.orientation = Sphere.turn(self.orientation, axis, angle)
	end

	-- Country detection uses the world point beneath the airplane (view front).
	local lat, lon = Sphere.front(self.orientation)
	local country = self.world:countryAt(lat, lon)
	self.currentCountryId = country and country.id or nil
	local recognized = self.recognition:update(self.currentCountryId, dt)
	if recognized then
		local named = self.world:country(recognized)
		self.app.log("recognized:" .. recognized)
		Audio.playVoice(self.app.audio, self.app.loc.language, "voice." .. recognized)
		self.recognizedName = self.app.loc:t(named.name_key)
	elseif not self.recognition.recognizedId then
		self.recognizedName = nil
	end

	-- Nearest interactable character beneath the plane (spec §11), used for the
	-- stronger glow and as the A-button acceptance target.
	self.nearCharacterId = nil
	for _, character in ipairs(self.mission:visibleCharacters()) do
		local d = World.angularDistance(lat, lon, character.latitude, character.longitude)
		if d <= CHARACTER_RANGE then
			self.nearCharacterId = character.id
			break
		end
	end

	-- A is the single interaction button (spec §6). Its effect depends on state:
	-- accept a nearby character's mission in free flight, or complete the active
	-- mission when over the target country. Edge-triggered, so holding A does not
	-- re-trigger.
	if input:pressed("interact") then
		if self.mission:isActive() then
			local mission = self.mission:activeMission()
			if self.currentCountryId == mission.target_country_id then
				local doneCharacter = self.mission:complete()
				if doneCharacter then
					self.app.log("mission_complete:" .. doneCharacter)
					Audio.playFeedback(self.app.audio)
					-- Fifth completion starts the cycle celebration (spec §17).
					if self.mission:allCompleted() then
						self.celebrationTime = CELEBRATION_TIME
						self.app.log("cycle_celebration")
					end
				end
			end
		elseif self.nearCharacterId then
			if self.mission:accept(self.nearCharacterId) then
				self.app.log("mission_accept:" .. self.nearCharacterId)
				Audio.playFeedback(self.app.audio)
			end
		end
	end

	-- B cancels the active mission (spec §6): back to free flight, mission not
	-- completed, all unfinished characters restored.
	if input:pressed("back") and self.mission:isActive() then
		if self.mission:cancel() then
			self.app.log("mission_cancel")
			Audio.playFeedback(self.app.audio)
		end
	end

	-- Mission guidance: is the target country's region visible on screen? Use
	-- the region center plus its outline samples, so a partial edge counts too.
	self.targetVisible = false
	local mission = self.mission:activeMission()
	if mission then
		local target = self.world:country(mission.target_country_id)
		local _, _, centerVisible = Sphere.project(
			self.orientation,
			target.region.latitude,
			target.region.longitude,
			GLOBE.radius,
			GLOBE.x,
			GLOBE.y
		)
		self.targetVisible = centerVisible
		if not self.targetVisible then
			for _, p in ipairs(self.countryOutlines[target.id]) do
				local _, _, v =
					Sphere.project(self.orientation, p[1], p[2], GLOBE.radius, GLOBE.x, GLOBE.y)
				if v then
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

	-- Ocean sphere with a soft rim so the curvature and horizon read clearly.
	love.graphics.setColor(0.16, 0.42, 0.7)
	love.graphics.circle("fill", GLOBE.x, GLOBE.y, GLOBE.radius)

	-- Simplified continents for geographic reference (non-interactive).
	Landmass.draw(self.continents, orientation, GLOBE)

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

	self:drawCountries(orientation)
	-- Airports sit inside their countries; all locked in the MVP (spec §9).
	Airport.draw(self.world.airports, orientation, GLOBE)
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

local function drawAirplane(x, y)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.setColor(1, 0.95, 0.4)
	love.graphics.polygon("fill", 0, -18, 12, 14, 0, 8, -12, 14)
	love.graphics.setColor(0.2, 0.2, 0.25)
	love.graphics.setLineWidth(3)
	love.graphics.polygon("line", 0, -18, 12, 14, 0, 8, -12, 14)
	love.graphics.pop()
end

function FlightMap:drawWorld()
	love.graphics.setColor(0.04, 0.05, 0.12)
	love.graphics.rectangle("fill", 0, 0, 640, 480)
	drawStars(self.stars)
	self:drawGlobe()
	drawAirplane(GLOBE.x, GLOBE.y)

	-- Permanent five-slot progress panel at the top (spec §16).
	ProgressPanel.draw(self.world.characters, self.mission:panelStates())

	-- Mission guidance while a mission is active (spec §13, §14).
	local mission = self.mission:activeMission()
	if mission then
		local target = self.world:country(mission.target_country_id)
		-- Arrow points toward the target while it is behind the horizon; it
		-- disappears once any part of the target is visible (highlight takes over).
		if not self.targetVisible then
			local dx, dy = Sphere.screenDirection(
				self.orientation,
				target.region.latitude,
				target.region.longitude
			)
			TargetArrow.draw(dx, dy)
		end
		MissionBox.draw(target, self.app.loc:t(target.name_key))
	end

	-- Recognised country name, shown as a learning aid (spec §8). Play is fully
	-- possible without reading, so this is supplementary.
	if self.recognizedName then
		love.graphics.setFont(Fonts.get(26))
		local w = 360
		love.graphics.setColor(0.05, 0.1, 0.2, 0.8)
		love.graphics.rectangle("fill", (640 - w) / 2, 400, w, 48, 14)
		love.graphics.setColor(1, 0.97, 0.7)
		love.graphics.printf(self.recognizedName, (640 - w) / 2, 412, w, "center")
	end

	-- Cycle celebration overlay (spec §17): shown after all five are done.
	if self.celebrationTime then
		self:drawCelebration()
	end

	love.graphics.setFont(Fonts.get(14))
	local driftNames = { "east", "north", "west", "south" }
	local lat, lon = Sphere.front(self.orientation)
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
