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

-- Draw the given characters for the current orientation. `nearId` (optional)
-- is the id of the character the airplane is currently inside the interaction
-- area of, which gets a stronger glow. `globe` is {x, y, radius}.
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
		if visible then
			local alpha = smoothstep(0.02, 0.15, depth)
			drawOne(sx, sy, character.color, time, character.id == nearId, character.sprite, alpha)
		end
	end
end

return Character
