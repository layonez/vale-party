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

-- A soft, short "blip" played when the plane first moves over a character
-- (spec §11 hover feedback). Higher and quieter than playFeedback so it reads
-- as a gentle "here!" cue rather than a confirmation.
function M.playHover(a)
	if not love.audio then
		return
	end
	if not a.hover then
		local rate = 22050
		local sd = love.sound.newSoundData(math.floor(rate * 0.08), rate, 16, 1)
		local n = sd:getSampleCount()
		for i = 0, n - 1 do
			-- Quick rise then decay so it chirps rather than beeps.
			local env = math.min(1, i / (n * 0.15)) * (1 - i / n)
			sd:setSample(i, math.sin(i / rate * math.pi * 2 * 990) * 0.14 * env)
		end
		a.hover = love.audio.newSource(sd)
	end
	a.hover:stop()
	a.hover:play()
end

-- Spoken hint for a pre-recorded phrase (spec §8, §11): loads
-- assets/voice/<lang>/<id>.ogg, caching each source so it only reads from disk
-- once. All voices share a single channel (a.voice): starting one stops the
-- previous so lines never talk over each other. Falls back to the confirmation
-- beep when the file is missing, so play never depends on the audio being there.
--
-- When quiet is true and the file is missing, it stays silent instead of
-- beeping (for additive cues like the greeting, which have no voice in every
-- language); otherwise a missing file falls back to the confirmation beep.
--
-- Returns true when a real voice line played, false when it fell back/stayed silent.
function M.playVoice(a, lang, id, quiet)
	if not love.audio then
		return false
	end
	a.voiceCache = a.voiceCache or {}
	local key = lang .. "/" .. id
	local src = a.voiceCache[key]
	if src == nil then
		local path = "assets/voice/" .. lang .. "/" .. id .. ".ogg"
		if love.filesystem.getInfo(path) then
			local ok, loaded = pcall(love.audio.newSource, path, "static")
			src = ok and loaded or false
		else
			src = false
		end
		a.voiceCache[key] = src
	end
	if src then
		if a.voice then
			a.voice:stop()
		end
		src:stop()
		src:play()
		a.voice = src
		return true
	end
	if quiet then
		return false
	end
	M.playFeedback(a)
	return false
end

-- Looping background music for gameplay (spec §8-style ambience). Streamed (not
-- loaded whole into memory) and kept quiet so the voice hints always read over
-- it. Idempotent: calling it again while music is already playing is a no-op, so
-- re-entering the Flight Map does not stack a second track. Silently does
-- nothing when the file is missing, so the game never depends on it.
function M.startMusic(a)
	if not love.audio then
		return
	end
	if not a.music then
		local path = "assets/music.ogg"
		if not love.filesystem.getInfo(path) then
			return
		end
		local ok, src = pcall(love.audio.newSource, path, "stream")
		if not ok then
			return
		end
		src:setLooping(true)
		src:setVolume(0.25)
		a.music = src
	end
	if not a.music:isPlaying() then
		a.music:play()
	end
end

-- Stop the background music (e.g. returning to the menu).
function M.stopMusic(a)
	if a.music then
		a.music:stop()
	end
end

-- Queue a voice line to play as soon as the current voice channel goes silent.
-- If something is already queued the new request replaces it (latest wins).
-- Use this for secondary cues (drop-off confirmation) so they never interrupt
-- a higher-priority announcement already in progress.
function M.queueVoice(a, lang, id, quiet)
	if not love.audio then
		return
	end
	a.voicePending = { lang = lang, id = id, quiet = quiet }
end

-- Poll the voice channel; call once per frame from the scene update. Plays the
-- queued line as soon as the current voice source goes silent.
function M.updateVoice(a)
	if not a.voicePending then
		return
	end
	if a.voice and a.voice:isPlaying() then
		return
	end
	local p = a.voicePending
	a.voicePending = nil
	M.playVoice(a, p.lang, p.id, p.quiet)
end

return M
