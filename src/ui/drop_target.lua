-- Drop-off guidance for the active mission (spec §13). Mirrors the character
-- finders (src/ui/character.lua): while carrying a character the player is shown
-- where to deliver it —
--   * the target country's center is ON screen -> a bobbing 3D pin points down
--     at the exact center, so "land here" is unmistakable;
--   * the center is OFF screen (behind the horizon, or outside the zoomed
--     globe's viewport) -> a directional arrow sits on a ring near the screen
--     edge, pointing the way and growing as the plane closes in.
-- The green theme matches the completion feedback ("this is the good place").
local DropTarget = {}

-- Edge-arrow ring, shared geometry with the character finders so the two guides
-- read as one system.
local RING_CX, RING_CY = 320, 240
local RING_ORBIT = 200
local ARROW_MIN = 24 -- arrow length (px) when the target is far (near antipode)
local ARROW_MAX = 42 -- arrow length (px) when the target is just off screen

local GREEN = { 0.35, 0.95, 0.5 } -- bright front/left face
local GREEN_MID = { 0.2, 0.62, 0.32 } -- right face (turned away from the light)
local GREEN_DARK = { 0.04, 0.28, 0.12 } -- extruded back face + outline

-- Arrow size for an off-screen target given projection depth `vx` = cos(angular
-- distance): +1 at the sub-plane point, -1 at the antipode. Grows toward the
-- front (squared easing) so it "pops" as the plane approaches. Pure, so it is
-- unit-tested without a graphics context.
---@param vx number projection depth in [-1, 1]
---@return number size
function DropTarget.finderScale(vx)
	local t = math.max(0, math.min(1, (vx + 1) / 2))
	return ARROW_MIN + (ARROW_MAX - ARROW_MIN) * (t * t)
end

-- Off-screen directional arrow: a chevron on the ring in screen direction
-- (dx, dy) (y down), sized by proximity `vx`, over a dark halo so it reads over
-- ocean and space.
---@param dx number
---@param dy number
---@param vx number projection depth in [-1, 1]
---@param time number
function DropTarget.drawFinder(dx, dy, vx, time)
	if dx == 0 and dy == 0 then
		dx, dy = 0, -1 -- exact antipode: direction undefined, point upward
	end
	local x = RING_CX + dx * RING_ORBIT
	local y = RING_CY + dy * RING_ORBIT
	local size = DropTarget.finderScale(vx)
	local pulse = 0.5 + 0.5 * math.sin(time * 4)
	local angle = math.atan2(dy, dx)

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
	-- Dark contrast halo.
	love.graphics.setColor(0.05, 0.08, 0.06, 0.85)
	love.graphics.circle("fill", 0, 0, size * 0.95)
	-- Bright green chevron pointing along +x (outward toward the target).
	local tip, back, half = size, -size * 0.6, size * 0.8
	love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], 0.85 + 0.15 * pulse)
	love.graphics.polygon("fill", tip, 0, back, half, back * 0.4, 0, back, -half)
	love.graphics.setColor(0.05, 0.2, 0.08, 1)
	love.graphics.setLineWidth(3)
	love.graphics.polygon("line", tip, 0, back, half, back * 0.4, 0, back, -half)
	love.graphics.pop()
end

-- On-screen "drop here" marker: a bobbing, slightly leaning 3D pin whose tip
-- points down at the country center (x, y). Built from an extruded back face and
-- faceted left/right front faces (a fold down the middle) so it reads as solid,
-- with a top highlight for light-from-above. It hovers and leans with a gentle
-- sway, and its ground shadow shrinks and fades as the pin rises, selling the
-- height. The tip stays anchored on the center while the body leans (rotation is
-- about the tip).
---@param x number screen x of the country center
---@param y number screen y of the country center
---@param time number
function DropTarget.drawPin(x, y, time)
	-- Faster, higher hover than before.
	local t = 0.5 + 0.5 * math.sin(time * 4.5) -- 0..1
	local lift = 5 + 13 * t -- 5..18 px above the center
	local tipY = y - lift
	-- A static lean plus a small sway, so it looks hand-placed rather than rigid.
	local angle = -0.26 + 0.06 * math.sin(time * 2.5) -- radians (~-15° ± 3.4°)

	local halfW = 13 -- arrowhead half-width
	local head = 16 -- arrowhead height
	local shaftW, shaftLen = 8, 20

	-- Ground shadow at the true center (does not bob). Shrinks + fades as the pin
	-- rises, so height reads clearly.
	local sh = 1 - 0.45 * t
	love.graphics.setColor(0, 0, 0, 0.30 - 0.15 * t)
	love.graphics.ellipse("fill", x, y + 2, 12 * sh, 5 * sh)

	love.graphics.push()
	love.graphics.translate(x, tipY)
	love.graphics.rotate(angle)
	-- Local space: tip at origin (0,0), body extends upward (-y).
	local top = -(head + shaftLen)

	-- Extruded back face, offset down-right, for thickness.
	local function silhouette(ox, oy)
		love.graphics.polygon("fill", ox, oy, ox - halfW, oy - head, ox + halfW, oy - head)
		love.graphics.rectangle("fill", ox - shaftW / 2, oy - head - shaftLen, shaftW, shaftLen)
	end
	love.graphics.setColor(GREEN_DARK[1], GREEN_DARK[2], GREEN_DARK[3], 1)
	silhouette(2.5, 3)

	-- Faceted front: left half bright, right half mid — a fold down the center.
	-- Head.
	love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], 1)
	love.graphics.polygon("fill", 0, 0, -halfW, -head, 0, -head)
	love.graphics.setColor(GREEN_MID[1], GREEN_MID[2], GREEN_MID[3], 1)
	love.graphics.polygon("fill", 0, 0, halfW, -head, 0, -head)
	-- Shaft.
	love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], 1)
	love.graphics.rectangle("fill", -shaftW / 2, -head - shaftLen, shaftW / 2, shaftLen)
	love.graphics.setColor(GREEN_MID[1], GREEN_MID[2], GREEN_MID[3], 1)
	love.graphics.rectangle("fill", 0, -head - shaftLen, shaftW / 2, shaftLen)

	-- Top highlight so the light reads from above.
	love.graphics.setColor(1, 1, 1, 0.55)
	love.graphics.rectangle("fill", -shaftW / 2, top, shaftW, 4)

	-- Crisp outline around the whole silhouette.
	love.graphics.setColor(GREEN_DARK[1], GREEN_DARK[2], GREEN_DARK[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.polygon("line", 0, 0, -halfW, -head, halfW, -head)
	love.graphics.rectangle("line", -shaftW / 2, -head - shaftLen, shaftW, shaftLen)
	love.graphics.pop()
end

return DropTarget
