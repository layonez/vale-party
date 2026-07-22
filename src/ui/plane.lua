-- The player's airplane sprite. Uses assets/sprites/plane.png, a 3x3 compass
-- sheet (center cell empty) of a kid in a plane facing the 8 directions. The
-- plane stays pinned at screen center (spec §4); we swap which cell is drawn to
-- face the current travel direction, rotating through intermediate facings so
-- the turn reads as a smooth spin rather than a snap. Loaded lazily so the
-- module can be required without a live LOVE graphics context (e.g. tests).
local Plane = {}

local SHEET = "assets/sprites/plane.png"
local CELL = 418 -- each sprite cell is 418x418 (1254 / 3)
local DRAW_SIZE = 108 -- on-screen size of the plane on the 640x480 canvas

-- Compass cell (column, row), 0-based, for each facing.
local CELLS = {
	n = { 1, 0 },
	ne = { 2, 0 },
	e = { 2, 1 },
	se = { 2, 2 },
	s = { 1, 2 },
	sw = { 0, 2 },
	w = { 0, 1 },
	nw = { 0, 0 },
}

-- Clockwise ring order; turning steps one entry at a time along the shortest
-- arc, so a left->right turn passes through nw/n/ne (or sw/s/se), showing all
-- the intermediate sprites instead of snapping.
local RING = { "n", "ne", "e", "se", "s", "sw", "w", "nw" }
local INDEX = {}
for i, name in ipairs(RING) do
	INDEX[name] = i - 1 -- 0-based position on the 8-slot ring
end

-- Map the four movement directions to a facing. Diagonals exist in the sheet
-- but input is 4-directional (spec §6); they appear as pass-through turn frames.
local INPUT_FACING = {
	up = "n",
	down = "s",
	left = "w",
	right = "e",
}

local image, quads

local function ensureLoaded()
	if image then
		return
	end
	image = love.graphics.newImage(SHEET)
	quads = {}
	for name, cell in pairs(CELLS) do
		quads[name] =
			love.graphics.newQuad(cell[1] * CELL, cell[2] * CELL, CELL, CELL, image:getDimensions())
	end
end

-- Resolve the facing for this frame's movement axis. `axis`/`sign` come from the
-- scene's movement (axis "y" = up/down, "z" = left/right); returns a facing key
-- or nil when idle (caller keeps the previous target facing).
---@param axis string|nil "y" | "z"
---@param sign number
---@return string|nil facing
function Plane.facingFor(axis, sign)
	if axis == "y" then
		return sign > 0 and INPUT_FACING.up or INPUT_FACING.down
	elseif axis == "z" then
		-- z-axis turn: positive spins the globe so the plane heads left (west).
		return sign > 0 and INPUT_FACING.left or INPUT_FACING.right
	end
	return nil
end

-- One step of `current` toward `target` along the shortest arc of the compass
-- ring. Returns `current` when already facing the target. Ties (exact opposite,
-- 4 steps away) resolve clockwise, consistently. Pure, for unit testing.
---@param current string
---@param target string
---@return string next
function Plane.stepToward(current, target)
	local from, to = INDEX[current], INDEX[target]
	if not from or not to or from == to then
		return current
	end
	local diff = (to - from) % 8 -- 1..7, clockwise distance
	local step = (diff <= 4) and 1 or -1 -- shortest arc; tie (==4) goes clockwise
	return RING[(from + step) % 8 + 1]
end

-- Gentle "alive" idle animation: a slow vertical bob, a breathing scale pulse,
-- and a small rotational wobble — a touch stronger while flying. Kept slow and
-- low-amplitude per the child-friendly rules (no rapid or flashing motion).
-- Pure (time in, offsets out) so it can be unit tested.
---@param time number seconds
---@param moving boolean whether the plane is currently flying
---@return number dy vertical bob in pixels
---@return number scaleMul scale multiplier around 1.0
---@return number rot rotation in radians
function Plane.animation(time, moving)
	local dy = math.sin(time * 2.2) * 3 -- slow up/down float, +/-3 px
	local scaleMul = 1 + math.sin(time * 1.6) * 0.03 -- breathing, +/-3%
	local wobbleAmp = moving and 0.06 or 0.025 -- radians; more lively in flight
	local rot = math.sin(time * (moving and 5 or 2.6)) * wobbleAmp
	return dy, scaleMul, rot
end

-- Draw the plane centered at (x, y) facing `facing` (defaults to "s"). `time`
-- drives the idle animation; `moving` makes the wobble a bit livelier in flight.
---@param x number
---@param y number
---@param facing string|nil
---@param time number|nil
---@param moving boolean|nil
function Plane.draw(x, y, facing, time, moving)
	ensureLoaded()
	local quad = quads[facing] or quads.s
	local dy, scaleMul, rot = Plane.animation(time or 0, moving or false)
	local scale = (DRAW_SIZE / CELL) * scaleMul
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, quad, x, y + dy, rot, scale, scale, CELL / 2, CELL / 2)
end

return Plane
