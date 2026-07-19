local M = {}
function M.new(log)
	return { log = log, tone = nil }
end
function M.playFeedback(a)
	if not love.audio then
		return
	end
	if not a.tone then
		local rate = 22050
		local sd = love.sound.newSoundData(rate * 0.12, rate, 16, 1)
		for i = 0, sd:getSampleCount() - 1 do
			sd:setSample(
				i,
				math.sin(i / rate * math.pi * 2 * 660) * 0.22 * (1 - i / sd:getSampleCount())
			)
		end
		a.tone = love.audio.newSource(sd)
	end
	a.tone:stop()
	a.tone:play()
end
function M.playVoice(a, lang, id)
	local path = "assets/voice/" .. lang .. "/" .. id .. ".ogg"
	if love.filesystem.getInfo(path) then
		local ok, src = pcall(love.audio.newSource, path, "static")
		if ok then
			src:play()
			return
		end
	end
	M.playFeedback(a)
end
return M
