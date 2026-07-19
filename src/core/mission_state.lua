-- Tracks mission-cycle progress for the Flight Map: which characters are
-- completed, which mission (if any) is active, and the high-level game state
-- (spec §17, §18). Pure logic (no LOVE), so it is unit tested. The scene owns
-- one instance and drives rendering + transitions from it.
local MissionState = {}
MissionState.__index = MissionState

-- High-level states (spec §18). MISSION_COMPLETION and CYCLE_CELEBRATION are
-- short transitions handled by the scene; the ones tracked here directly are
-- FREE_FLIGHT and MISSION_ACTIVE.
MissionState.FREE_FLIGHT = "FREE_FLIGHT"
MissionState.MISSION_ACTIVE = "MISSION_ACTIVE"

---@param world table the World instance (for looking up missions/characters)
---@return table
function MissionState.new(world)
	local self = setmetatable({}, MissionState)
	self.world = world
	self:reset()
	return self
end

-- Reset the cycle: nothing completed, no active mission, free flight (spec §17).
function MissionState:reset()
	self.completed = {} -- character id -> true when its mission is done
	self.activeMissionId = nil
	self.state = MissionState.FREE_FLIGHT
end

-- Restore from a save: a list of completed character ids and an optional active
-- mission id (spec §20). Unknown ids are ignored so a stale save never wedges
-- the cycle. An active mission whose character is already completed is dropped.
---@param completedIds string[]
---@param activeMissionId string|nil
function MissionState:restore(completedIds, activeMissionId)
	self:reset()
	for _, id in ipairs(completedIds or {}) do
		if self.world:character(id) then
			self.completed[id] = true
		end
	end
	if activeMissionId then
		local mission = self.world:mission(activeMissionId)
		if mission and not self.completed[mission.character_id] then
			self.activeMissionId = activeMissionId
			self.state = MissionState.MISSION_ACTIVE
		end
	end
end

-- Snapshot for saving: the completed character ids and the active mission id.
---@return string[] completedIds
---@return string|nil activeMissionId
function MissionState:snapshot()
	local ids = {}
	for _, character in ipairs(self.world.characters) do
		if self.completed[character.id] then
			ids[#ids + 1] = character.id
		end
	end
	return ids, self.activeMissionId
end

---@return boolean
function MissionState:isActive()
	return self.activeMissionId ~= nil
end

---@return table|nil mission
function MissionState:activeMission()
	return self.activeMissionId and self.world:mission(self.activeMissionId) or nil
end

-- Accept a character's mission (spec §11). No-op if a mission is already active
-- or the character is already completed. Returns true if accepted.
---@param characterId string
---@return boolean accepted
function MissionState:accept(characterId)
	if self:isActive() or self.completed[characterId] then
		return false
	end
	local character = self.world:character(characterId)
	if not character then
		return false
	end
	self.activeMissionId = character.mission_id
	self.state = MissionState.MISSION_ACTIVE
	return true
end

-- Cancel the active mission (spec §6 B button). Returns to free flight; the
-- mission is NOT marked completed. Returns true if a mission was cancelled.
---@return boolean cancelled
function MissionState:cancel()
	if not self:isActive() then
		return false
	end
	self.activeMissionId = nil
	self.state = MissionState.FREE_FLIGHT
	return true
end

-- Complete the active mission (spec §15). Marks its character completed and
-- returns to free flight. Returns the completed character id, or nil.
---@return string|nil completedCharacterId
function MissionState:complete()
	local mission = self:activeMission()
	if not mission then
		return nil
	end
	self.completed[mission.character_id] = true
	self.activeMissionId = nil
	self.state = MissionState.FREE_FLIGHT
	return mission.character_id
end

---@return boolean true when every character's mission is completed (spec §17)
function MissionState:allCompleted()
	for _, character in ipairs(self.world.characters) do
		if not self.completed[character.id] then
			return false
		end
	end
	return true
end

-- Characters visible on the globe right now: during a mission only the active
-- character; in free flight all not-yet-completed characters (spec §10, §11).
---@return table[]
function MissionState:visibleCharacters()
	local visible = {}
	local activeMission = self:activeMission()
	for _, character in ipairs(self.world.characters) do
		if activeMission then
			if character.id == activeMission.character_id then
				visible[#visible + 1] = character
			end
		elseif not self.completed[character.id] then
			visible[#visible + 1] = character
		end
	end
	return visible
end

-- Panel state per character id for the progress panel (spec §16):
-- "completed" | "active" | "available".
---@return table<string,string>
function MissionState:panelStates()
	local states = {}
	local activeMission = self:activeMission()
	for _, character in ipairs(self.world.characters) do
		if self.completed[character.id] then
			states[character.id] = "completed"
		elseif activeMission and activeMission.character_id == character.id then
			states[character.id] = "active"
		else
			states[character.id] = "available"
		end
	end
	return states
end

return MissionState
