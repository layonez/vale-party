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
		-- Remember what is playing so updateVoice can (a) start the arrival-announcement
		-- cooldown when a "voice.<country>" line ends and (b) tell an interruptible
		-- ambient announcement from a directly-played line. Playing directly always
		-- takes over the channel, so this is never an ambient announcement until the
		-- ambient path flags it below.
		a.currentVoiceId = id
		a.announcing = false
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

-- Seconds that must pass after a country announcement finishes before another
-- may start, so flying across many small countries doesn't machine-gun their
-- names (requested behaviour). Applies only to ambient arrival announcements.
local ANNOUNCE_COOLDOWN = 4

-- Queue a high-priority spoken line to play as soon as the voice channel is free.
-- Queued lines play in order (FIFO), so a chain like the character's drop-off
-- thanks followed by the cycle celebration plays back-to-back without either
-- being cut off. Speech always takes precedence over ambient announcements
-- (see M.announce): a queued line preempts an announcement mid-word.
function M.queueVoice(a, lang, id, quiet)
	if not love.audio then
		return
	end
	a.voiceQueue = a.voiceQueue or {}
	a.voiceQueue[#a.voiceQueue + 1] = { lang = lang, id = id, quiet = quiet }
end

-- Request a low-priority ambient country announcement ("это <страна>!"). Unlike
-- queueVoice this never interrupts and is never guaranteed: it plays only when no
-- speech is playing or queued AND the post-announcement cooldown has elapsed, and
-- it is preempted the instant any speech is queued. Latest request wins (only the
-- most recently flown-over country matters), so a single pending slot is enough —
-- which also means a country is announced at most once per fly-over, never twice.
function M.announce(a, lang, id)
	if not love.audio then
		return
	end
	a.announcePending = { lang = lang, id = id }
end

-- Drop any pending/played ambient announcement state (e.g. on a round change) so a
-- stale country name can't bleed into the next round. Leaves queued speech alone.
function M.clearAnnouncement(a)
	a.announcePending = nil
	a.announcing = false
end

-- Poll the voice channel; call once per frame from the scene update with the
-- frame dt. Enforces speech-over-announcement priority and the announcement
-- cooldown, and starts the next line whenever the channel frees up.
function M.updateVoice(a, dt)
	dt = dt or 0
	local playing = a.voice and a.voice:isPlaying()

	-- A country announcement (ambient or a directly-played "voice.*" line) that has
	-- just ended starts the cooldown before the next announcement may play.
	if a.currentVoiceId and not playing then
		if string.sub(a.currentVoiceId, 1, 6) == "voice." then
			a.announceCooldown = ANNOUNCE_COOLDOWN
		end
		a.currentVoiceId = nil
		a.announcing = false
	end
	if a.announceCooldown and a.announceCooldown > 0 then
		a.announceCooldown = math.max(0, a.announceCooldown - dt)
	end

	local speechWaiting = a.voiceQueue and #a.voiceQueue > 0

	if playing then
		-- Speech takes precedence: a waiting line preempts an ambient announcement
		-- (and only an ambient one — never another spoken line). Otherwise let the
		-- current line finish before starting anything new.
		if a.announcing and speechWaiting then
			a.voice:stop()
			a.announcing = false
			a.announceCooldown = ANNOUNCE_COOLDOWN
		else
			return
		end
	end

	-- Priority 1: queued speech (drop-off thanks, cycle celebration, …).
	if speechWaiting then
		local p = table.remove(a.voiceQueue, 1)
		M.playVoice(a, p.lang, p.id, p.quiet)
		return
	end

	-- Priority 2: ambient country announcement, only once the cooldown has elapsed.
	if a.announcePending and (not a.announceCooldown or a.announceCooldown <= 0) then
		local p = a.announcePending
		a.announcePending = nil
		-- quiet: countries without a recording stay silent instead of beeping.
		if M.playVoice(a, p.lang, p.id, true) then
			a.announcing = true
		end
	end
end

return M
