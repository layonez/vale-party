-- Draws mission characters on the Flight Map globe. Characters sit at fixed
-- world positions (content/world.lua) and have a subtle pulsing glow so they
-- read as interactive (spec §10). During free flight all unfinished characters
-- are shown; while a mission is active only the active one remains (the scene
-- decides which to pass in). Characters are drawn only on the visible
-- hemisphere.
--
-- Each character shows its portrait art (character.sprite); the tinted glow
-- behind it still makes it read as an interactive beacon. Images are loaded
-- lazily and cached by path so the module can be required without a live LOVE
-- graphics context (e.g. tests) — the vector fallback below covers that case.
local Sphere = require("src.core.sphere")

local Character = {}

local BODY = 12 -- character radius in pixels (glow + vector fallback)
local SPRITE_SIZE = 64 -- on-screen height of the portrait art (~60% larger for readability on small screens)

-- Off-screen "finder" indicators (spec §10, exploration aid). When a character
-- is not on screen — behind the horizon or projected outside the viewport,
-- since the zoomed globe is larger than the 640×480 canvas — we draw a small
-- portrait at a ring near the screen edge, in the character's screen direction,
-- so the player always has a bearing toward every character to collect. The
-- portrait grows as the plane gets closer (proximity from the projection depth),
-- shrinking to its smallest at the exact opposite side of the globe.
local FINDER_CX, FINDER_CY = 320, 240 -- screen-center the finder ring orbits
local FINDER_ORBIT = 200 -- ring radius; keeps finders inside the 640×480 canvas
local FINDER_MIN = 22 -- portrait height (px) when the character is far (antipode)
local FINDER_MAX = 46 -- portrait height (px) when the character is just off screen
-- A character counts as "on screen" (drawn on the globe) only when it is on the
-- near hemisphere AND its projection sits within this inset of the canvas edge.
local SCREEN_MARGIN = 44

-- Path -> Image cache. Populated on first draw; nil entries mean "tried and the
-- asset was missing", so we fall back to the vector dot without retrying.
local images = {}

local function spriteImage(path)
	if images[path] == nil then
		local ok, img = pcall(love.graphics.newImage, path)
		images[path] = ok and img or false
	end
	return images[path] or nil
end

-- Smooth fade: 0 at `a`, 1 at `b`, cubic in between.
local function smoothstep(a, b, x)
	local t = math.max(0, math.min(1, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)
end

-- Draw one character at screen (x, y). `time` drives the glow pulse; `strong`
-- brightens it when the airplane is inside the interaction area (spec §11).
-- `sprite` is the portrait path; when it is missing we draw the simple dot.
-- `alpha` (0..1) scales all drawing opacity for horizon fade.
local function drawOne(x, y, color, time, strong, sprite, alpha)
	alpha = alpha or 1
	local pulse = 0.5 + 0.5 * math.sin(time * 3)
	-- Faster, fuller pulse when hovered so the highlight visibly throbs.
	local hoverPulse = 0.5 + 0.5 * math.sin(time * 6)

	if strong then
		-- Hovered: a bright, layered halo that pulses. Outer soft ring + a
		-- crisper bright rim make the character read as "ready to interact".
		local haloR = SPRITE_SIZE * 0.7 + 6 * hoverPulse
		love.graphics.setColor(color[1], color[2], color[3], (0.35 + 0.2 * hoverPulse) * alpha)
		love.graphics.circle("fill", x, y, haloR)
		love.graphics.setColor(1, 1, 1, (0.55 + 0.35 * hoverPulse) * alpha)
		love.graphics.setLineWidth(2.5)
		love.graphics.circle("line", x, y, haloR)
	else
		-- Idle: the original subtle breathing glow.
		local glow = 0.35 + 0.25 * pulse
		local glowR = BODY + 6 + 3 * pulse
		love.graphics.setColor(color[1], color[2], color[3], glow * 0.5 * alpha)
		love.graphics.circle("fill", x, y, glowR)
	end

	local image = sprite and spriteImage(sprite)
	if image then
		-- Portrait art: sit it so its feet rest near the world point, and scale
		-- to a consistent on-screen size regardless of the source resolution.
		-- Hovered characters get a gentle scale pulse so they "pop" and stay at
		-- full brightness; idle ones are drawn very slightly dimmer for contrast.
		local iw, ih = image:getDimensions()
		local scaleMul = strong and (1.12 + 0.06 * hoverPulse) or 1
		local scale = (SPRITE_SIZE / ih) * scaleMul
		if strong then
			love.graphics.setColor(1, 1, 1, alpha)
		else
			love.graphics.setColor(0.82, 0.82, 0.82, alpha)
		end
		love.graphics.draw(image, x, y, 0, scale, scale, iw / 2, ih / 2)
	else
		-- Vector fallback (no graphics context or missing art): a simple face so
		-- it still reads as a character, not a dot.
		love.graphics.setColor(color[1], color[2], color[3], alpha)
		love.graphics.circle("fill", x, y, BODY)
		love.graphics.setColor(0.12, 0.12, 0.16, alpha)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", x, y, BODY)
		love.graphics.setColor(0.12, 0.12, 0.16, alpha)
		love.graphics.circle("fill", x - 4, y - 2, 1.8)
		love.graphics.circle("fill", x + 4, y - 2, 1.8)
	end
end

-- Portrait height (px) for an off-screen finder given the projection depth
-- `vx` = cos(angular distance from the plane): +1 at the sub-plane point, 0 at
-- the horizon, -1 at the antipode. Grows toward the front (squared easing so it
-- "pops" as you close in) and is smallest at the opposite side. Pure, so the
-- proximity-scaling is unit-tested without a graphics context.
---@param vx number projection depth in [-1, 1]
---@return number height
function Character.finderScale(vx)
	local t = math.max(0, math.min(1, (vx + 1) / 2))
	return FINDER_MIN + (FINDER_MAX - FINDER_MIN) * (t * t)
end

-- Draw an off-screen finder: a small portrait at the edge ring in screen
-- direction (dx, dy) (y down), sized by projection depth `vx`, with a soft glow
-- and a chevron pointing outward toward the character.
local function drawFinder(dx, dy, vx, color, sprite, time)
	if dx == 0 and dy == 0 then
		dx, dy = 0, -1 -- exact antipode: direction is undefined, point it upward
	end
	local x = FINDER_CX + dx * FINDER_ORBIT
	local y = FINDER_CY + dy * FINDER_ORBIT
	local h = Character.finderScale(vx)
	local pulse = 0.5 + 0.5 * math.sin(time * 3)

	-- Soft tinted glow so the beacon reads over ocean and space.
	love.graphics.setColor(color[1], color[2], color[3], 0.3 + 0.15 * pulse)
	love.graphics.circle("fill", x, y, h * 0.7 + 2 * pulse)

	-- Chevron just outside the portrait, pointing the way to fly.
	local ang = math.atan2(dy, dx)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(ang)
	local o = h * 0.72
	love.graphics.setColor(1, 1, 1, 0.9)
	love.graphics.polygon("fill", o + 8, 0, o, 5, o, -5)
	love.graphics.pop()

	local image = sprite and spriteImage(sprite)
	if image then
		local iw, ih = image:getDimensions()
		local scale = h / ih
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(image, x, y, 0, scale, scale, iw / 2, ih / 2)
	else
		love.graphics.setColor(color[1], color[2], color[3], 1)
		love.graphics.circle("fill", x, y, h * 0.4)
		love.graphics.setColor(0.12, 0.12, 0.16, 1)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", x, y, h * 0.4)
	end
end

-- Draw the given characters for the current orientation. `nearId` (optional)
-- is the id of the character the airplane is currently inside the interaction
-- area of, which gets a stronger glow. `globe` is {x, y, radius}. Characters
-- that project on screen are drawn on the globe; the rest get an edge finder
-- (above) so the player always has a direction toward every one.
---@param characters table[]
---@param orientation table
---@param globe table
---@param time number
---@param nearId string|nil
function Character.draw(characters, orientation, globe, time, nearId)
	for _, character in ipairs(characters) do
		local sx, sy, visible, depth = Sphere.project(
			orientation,
			character.latitude,
			character.longitude,
			globe.radius,
			globe.x,
			globe.y
		)
		local onScreen = visible
			and sx >= SCREEN_MARGIN
			and sx <= 640 - SCREEN_MARGIN
			and sy >= SCREEN_MARGIN
			and sy <= 480 - SCREEN_MARGIN
		if onScreen then
			local alpha = smoothstep(0.02, 0.15, depth)
			drawOne(sx, sy, character.color, time, character.id == nearId, character.sprite, alpha)
		else
			local dx, dy = Sphere.screenDirection(orientation, character.latitude, character.longitude)
			drawFinder(dx, dy, depth, character.color, character.sprite, time)
		end
	end
end

return Character
