-- On-screen touch controls for the web/mobile build (a D-pad + a single A
-- button). Desktop and the handheld use real keys/gamepad and never construct
-- this; it is created only when App decides the platform is touch-driven.
--
-- Everything is laid out and hit-tested in the game's 640x480 virtual space, the
-- same coordinates App.canvas uses, so App.drawScaled can draw the overlay onto
-- the canvas and the letterbox math that maps a real screen touch back to that
-- space is shared with App.drawScaled. Pure aside from :draw and the screen->
-- virtual conversion, so the layout and the down/pressed state machine are unit
-- tested.
local Touch = {}
Touch.__index = Touch

-- Button geometry in virtual (640x480) coordinates. The D-pad sits bottom-left
-- and the A button bottom-right, both within thumb reach and clear of the HUD.
local S = 52 -- d-pad square side
local function rect(action, x, y)
	return { action = action, shape = "rect", x = x, y = y, w = S, h = S }
end

---@param w integer virtual width (App.W)
---@param h integer virtual height (App.H)
---@return table
function Touch.new(w, h)
	local self = setmetatable({}, Touch)
	self.W, self.H = w, h
	-- Clear of the HUD: the progress panel hugs the left edge (x<=68) and the
	-- active-mission box sits bottom-right (x>=378, y>=376). So the D-pad sits just
	-- right of the panel, and the A button rides above the mission box.
	local cx, cy = 156, h - 94 -- d-pad cross centre
	local ax, ay = w - 72, h - 164 -- A button centre (above the mission box)
	self.buttons = {
		rect("move_up", cx - S / 2, cy - S - S / 2),
		rect("move_down", cx - S / 2, cy + S / 2),
		rect("move_left", cx - S - S / 2, cy - S / 2),
		rect("move_right", cx + S / 2, cy - S / 2),
		{ action = "interact", shape = "circle", cx = ax, cy = ay, r = 48 },
	}
	self.pointers = {} -- pointer id -> action currently held (or nil)
	self.downNow = {} -- action -> true while held this frame
	self.pressed = {} -- action -> true only on the frame it went down
	self.touchSeen = false -- once a real touch arrives, ignore emulated mouse
	return self
end

-- Which button (if any) contains a virtual-space point. A circle for the A
-- button, rectangles for the d-pad; regions do not overlap so first match wins.
---@return string|nil action
function Touch:hitTest(vx, vy)
	for _, b in ipairs(self.buttons) do
		if b.shape == "circle" then
			local dx, dy = vx - b.cx, vy - b.cy
			if dx * dx + dy * dy <= b.r * b.r then
				return b.action
			end
		elseif vx >= b.x and vx <= b.x + b.w and vy >= b.y and vy <= b.y + b.h then
			return b.action
		end
	end
	return nil
end

-- Convert a real screen point to virtual (640x480) coordinates using the same
-- letterbox scale/offset as App.drawScaled, so a touch lands on the button drawn
-- under the finger regardless of window size.
function Touch:toVirtual(sx, sy)
	local ww, wh = love.graphics.getDimensions()
	local scale = math.min(ww / self.W, wh / self.H)
	local ox = (ww - self.W * scale) / 2
	local oy = (wh - self.H * scale) / 2
	return (sx - ox) / scale, (sy - oy) / scale
end

-- Pointer lifecycle. press/move/release take real screen coordinates; the *At
-- variants take virtual coordinates and hold the pure logic (unit tested).
function Touch:pressAt(id, vx, vy)
	self.pointers[id] = self:hitTest(vx, vy)
end
function Touch:moveAt(id, vx, vy)
	-- Only track a pointer that began on a button; sliding across the d-pad then
	-- updates which direction it holds (and off the pad clears it).
	if self.pointers[id] ~= nil then
		self.pointers[id] = self:hitTest(vx, vy)
	end
end
function Touch:press(id, sx, sy)
	if id ~= "mouse" then
		self.touchSeen = true
	end
	self:pressAt(id, self:toVirtual(sx, sy))
end
function Touch:move(id, sx, sy)
	self:moveAt(id, self:toVirtual(sx, sy))
end
function Touch:release(id)
	self.pointers[id] = nil
end

-- Recompute held/edge state from the current pointers. Called once per frame by
-- the input proxy, right after baton updates, so touch and key edges align.
function Touch:update()
	local prev = self.downNow
	local now = {}
	for _, action in pairs(self.pointers) do
		if action then
			now[action] = true
		end
	end
	local pressed = {}
	for action in pairs(now) do
		if not prev[action] then
			pressed[action] = true
		end
	end
	self.downNow = now
	self.pressed = pressed
end

---@param action string
---@return boolean
function Touch:down(action)
	return self.downNow[action] == true
end

---@param action string
---@return boolean
function Touch:isPressed(action)
	return self.pressed[action] == true
end

-- Draw the controls onto the (virtual-space) canvas. Semi-transparent so they
-- never dominate the scene; a held button brightens for feedback.
function Touch:draw()
	local held = self.downNow
	for _, b in ipairs(self.buttons) do
		local on = held[b.action]
		love.graphics.setColor(1, 1, 1, on and 0.6 or 0.36)
		if b.shape == "circle" then
			love.graphics.circle("fill", b.cx, b.cy, b.r)
			love.graphics.setColor(0.1, 0.15, 0.25, on and 0.95 or 0.7)
			love.graphics.circle("line", b.cx, b.cy, b.r)
			love.graphics.printf("A", b.cx - b.r, b.cy - 12, b.r * 2, "center")
		else
			love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8, 8)
			love.graphics.setColor(0.1, 0.15, 0.25, on and 0.95 or 0.7)
			love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 8, 8)
			Touch.drawArrow(b.action, b.x + b.w / 2, b.y + b.h / 2)
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
end

-- A small filled triangle pointing in the d-pad direction, centred on (x, y).
function Touch.drawArrow(action, x, y)
	local a = 12
	local pts
	if action == "move_up" then
		pts = { x, y - a, x - a, y + a, x + a, y + a }
	elseif action == "move_down" then
		pts = { x, y + a, x - a, y - a, x + a, y - a }
	elseif action == "move_left" then
		pts = { x - a, y, x + a, y - a, x + a, y + a }
	else -- move_right
		pts = { x + a, y, x - a, y - a, x - a, y + a }
	end
	love.graphics.polygon("fill", pts)
end

return Touch
