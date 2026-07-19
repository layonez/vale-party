-- Tracks which playable country the airplane is over and when it becomes
-- "recognised". The player must linger above a country for a short dwell time
-- (spec §8) before its name shows; recognition fires once per visit and does
-- not repeat while the airplane stays inside. Leaving and re-entering allows
-- recognition again. Pure logic (no LOVE), so it is unit tested.
local Recognition = {}
Recognition.__index = Recognition

local DWELL = 0.1 -- seconds over a country before it is recognised (spec §8)

---@param dwell number|nil override dwell seconds (for tests/tuning)
---@return table
function Recognition.new(dwell)
	return setmetatable({
		dwell = dwell or DWELL,
		currentId = nil, -- country id currently beneath the plane, or nil
		timer = 0, -- accumulated dwell over currentId
		recognizedId = nil, -- id already recognised this visit (debounce)
	}, Recognition)
end

-- Advance the tracker. `countryId` is the id beneath the plane this frame (nil
-- over ocean). Returns the country id if it becomes recognised THIS frame,
-- otherwise nil. `recognizedId` stays set until the plane leaves, so callers
-- can render the name/highlight for as long as `self.recognizedId` is set.
---@param countryId string|nil
---@param dt number
---@return string|nil justRecognized
function Recognition:update(countryId, dt)
	if countryId ~= self.currentId then
		-- Entered a different country (or open ocean): restart dwell + debounce.
		-- The entering frame's dt still counts toward the new country's dwell.
		self.currentId = countryId
		self.timer = 0
		self.recognizedId = nil
	end

	if countryId == nil then
		return nil
	end

	if self.recognizedId == countryId then
		-- Already recognised this visit; hold the state, do not re-fire.
		return nil
	end

	self.timer = self.timer + dt
	if self.timer >= self.dwell then
		self.recognizedId = countryId
		return countryId
	end
	return nil
end

return Recognition
