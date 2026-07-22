-- Data-driven world content for the Flight Map: the 25 largest countries (by
-- land area), the recurring cast of five mission characters, and the five
-- delivery rounds those characters cycle through.
--
-- This is content configuration (spec §19). The Flight Map logic must not
-- hard-code individual countries or characters — everything here is looked up
-- by id through src/core/world.lua.
--
-- Gameplay is an endless delivery cycle in steps of five: each round asks the
-- player to carry five characters to five different drop-off countries, then
-- automatically advances to the next round (looping after the last). Rounds are
-- ordered by difficulty — round 1 targets the five biggest, easiest-to-find
-- countries; round 5 the five smallest of the 25. Every character starts on the
-- OPPOSITE side of the globe from where they must be dropped off (their position
-- is the antipode of the target country, computed in src/core/world.lua), so the
-- player has to search across the whole globe to complete each mission.
--
-- Positions are {latitude, longitude} in degrees. A country's `region` is a
-- great-circle circle (center + angular `radius` in degrees) used both as the
-- drop-off zone and the highlight area; bigger countries get larger radii, which
-- is what makes the early rounds easier. `flag` holds simple stripe colors so the
-- active-mission box can draw a flag without art assets. `iso` is the Natural
-- Earth id-mask code (content/regions.lua) used to fill the real country shape.

-- The 25 largest countries by land area, ranked biggest → smallest. The rounds
-- below slice this ranking into five difficulty tiers, so the list order also
-- encodes difficulty.
local countries = {
	-- Round 1 — the five biggest (easiest to find, most forgiving drop zones).
	{
		id = "russia",
		name_key = "country.russia",
		iso = "RU",
		flag = { { 1, 1, 1 }, { 0.1, 0.2, 0.7 }, { 0.8, 0.1, 0.1 } },
		latitude = 61,
		longitude = 90,
		region = { latitude = 61, longitude = 90, radius = 16 },
	},
	{
		id = "canada",
		name_key = "country.canada",
		iso = "CA",
		flag = { { 0.8, 0.1, 0.15 }, { 1, 1, 1 }, { 0.8, 0.1, 0.15 } },
		latitude = 58,
		longitude = -100,
		region = { latitude = 58, longitude = -100, radius = 15 },
	},
	{
		id = "usa",
		name_key = "country.usa",
		iso = "US",
		flag = { { 0.1, 0.2, 0.5 }, { 1, 1, 1 }, { 0.8, 0.1, 0.2 } },
		latitude = 39,
		longitude = -98,
		region = { latitude = 39, longitude = -98, radius = 14 },
	},
	{
		id = "china",
		name_key = "country.china",
		iso = "CN",
		flag = { { 0.8, 0.1, 0.1 }, { 1, 0.85, 0.0 }, { 0.8, 0.1, 0.1 } },
		-- Centered a little south of the geographic middle and sized so its circle
		-- clears Mongolia's center just to the north (they border), keeping the
		-- recognition label correct for both.
		latitude = 34,
		longitude = 103,
		region = { latitude = 34, longitude = 103, radius = 10 },
	},
	{
		id = "brazil",
		name_key = "country.brazil",
		iso = "BR",
		flag = { { 0.0, 0.6, 0.3 }, { 1.0, 0.8, 0.0 }, { 0.1, 0.2, 0.6 } },
		latitude = -10,
		longitude = -52,
		region = { latitude = -10, longitude = -52, radius = 15 },
	},

	-- Round 2.
	{
		id = "australia",
		name_key = "country.australia",
		iso = "AU",
		flag = { { 0.1, 0.2, 0.5 }, { 1, 1, 1 }, { 0.8, 0.1, 0.2 } },
		latitude = -25,
		longitude = 133,
		region = { latitude = -25, longitude = 133, radius = 14 },
	},
	{
		id = "india",
		name_key = "country.india",
		iso = "IN",
		flag = { { 1.0, 0.6, 0.2 }, { 1, 1, 1 }, { 0.2, 0.6, 0.3 } },
		latitude = 22,
		longitude = 79,
		region = { latitude = 22, longitude = 79, radius = 11 },
	},
	{
		id = "argentina",
		name_key = "country.argentina",
		iso = "AR",
		flag = { { 0.5, 0.7, 0.9 }, { 1, 1, 1 }, { 0.5, 0.7, 0.9 } },
		latitude = -35,
		longitude = -65,
		region = { latitude = -35, longitude = -65, radius = 12 },
	},
	{
		id = "kazakhstan",
		name_key = "country.kazakhstan",
		iso = "KZ",
		flag = { { 0.2, 0.6, 0.8 }, { 1, 0.85, 0.0 }, { 0.2, 0.6, 0.8 } },
		latitude = 48,
		longitude = 67,
		region = { latitude = 48, longitude = 67, radius = 11 },
	},
	{
		id = "algeria",
		name_key = "country.algeria",
		iso = "DZ",
		flag = { { 0.0, 0.5, 0.3 }, { 1, 1, 1 }, { 0.8, 0.1, 0.1 } },
		latitude = 28,
		longitude = 3,
		region = { latitude = 28, longitude = 3, radius = 10 },
	},

	-- Round 3.
	{
		id = "dr_congo",
		name_key = "country.dr_congo",
		iso = "CD",
		flag = { { 0.2, 0.5, 0.9 }, { 1, 0.85, 0.0 }, { 0.8, 0.1, 0.1 } },
		latitude = -2,
		longitude = 23,
		region = { latitude = -2, longitude = 23, radius = 9 },
	},
	{
		id = "saudi_arabia",
		name_key = "country.saudi_arabia",
		iso = "SA",
		flag = { { 0.0, 0.45, 0.25 }, { 0.0, 0.55, 0.3 }, { 1, 1, 1 } },
		latitude = 24,
		longitude = 45,
		region = { latitude = 24, longitude = 45, radius = 9 },
	},
	{
		id = "mexico",
		name_key = "country.mexico",
		iso = "MX",
		flag = { { 0.0, 0.5, 0.3 }, { 1, 1, 1 }, { 0.8, 0.1, 0.15 } },
		latitude = 23,
		longitude = -102,
		region = { latitude = 23, longitude = -102, radius = 9 },
	},
	{
		id = "indonesia",
		name_key = "country.indonesia",
		iso = "ID",
		flag = { { 0.85, 0.1, 0.15 }, { 1, 1, 1 }, { 0.85, 0.1, 0.15 } },
		latitude = -2,
		longitude = 118,
		region = { latitude = -2, longitude = 118, radius = 10 },
	},
	{
		id = "sudan",
		name_key = "country.sudan",
		iso = "SD",
		flag = { { 0.8, 0.1, 0.1 }, { 1, 1, 1 }, { 0.1, 0.1, 0.1 } },
		latitude = 15,
		longitude = 30,
		region = { latitude = 15, longitude = 30, radius = 8 },
	},

	-- Round 4.
	{
		id = "libya",
		name_key = "country.libya",
		iso = "LY",
		flag = { { 0.8, 0.1, 0.1 }, { 0.1, 0.1, 0.1 }, { 0.0, 0.5, 0.25 } },
		latitude = 27,
		longitude = 17,
		region = { latitude = 27, longitude = 17, radius = 8 },
	},
	{
		id = "iran",
		name_key = "country.iran",
		iso = "IR",
		flag = { { 0.1, 0.6, 0.3 }, { 1, 1, 1 }, { 0.8, 0.1, 0.1 } },
		latitude = 32,
		longitude = 53,
		region = { latitude = 32, longitude = 53, radius = 8 },
	},
	{
		id = "mongolia",
		name_key = "country.mongolia",
		iso = "MN",
		flag = { { 0.8, 0.1, 0.15 }, { 0.1, 0.2, 0.6 }, { 0.8, 0.1, 0.15 } },
		latitude = 46,
		longitude = 104,
		region = { latitude = 46, longitude = 104, radius = 8 },
	},
	{
		id = "peru",
		name_key = "country.peru",
		iso = "PE",
		flag = { { 0.8, 0.1, 0.15 }, { 1, 1, 1 }, { 0.8, 0.1, 0.15 } },
		latitude = -10,
		longitude = -75,
		region = { latitude = -10, longitude = -75, radius = 8 },
	},
	{
		id = "chad",
		name_key = "country.chad",
		iso = "TD",
		flag = { { 0.1, 0.2, 0.7 }, { 1, 0.85, 0.0 }, { 0.8, 0.1, 0.1 } },
		latitude = 15,
		longitude = 19,
		region = { latitude = 15, longitude = 19, radius = 7 },
	},

	-- Round 5 — the five smallest of the 25 (tightest drop zones, hardest to hit).
	{
		id = "niger",
		name_key = "country.niger",
		iso = "NE",
		flag = { { 1, 0.5, 0.1 }, { 1, 1, 1 }, { 0.1, 0.6, 0.3 } },
		latitude = 17,
		longitude = 9,
		region = { latitude = 17, longitude = 9, radius = 7 },
	},
	{
		id = "angola",
		name_key = "country.angola",
		iso = "AO",
		flag = { { 0.8, 0.1, 0.1 }, { 0.1, 0.1, 0.1 }, { 1, 0.85, 0.0 } },
		latitude = -12,
		longitude = 18,
		region = { latitude = -12, longitude = 18, radius = 7 },
	},
	{
		id = "mali",
		name_key = "country.mali",
		iso = "ML",
		flag = { { 0.1, 0.6, 0.3 }, { 1, 0.85, 0.0 }, { 0.8, 0.1, 0.1 } },
		latitude = 18,
		longitude = -2,
		region = { latitude = 18, longitude = -2, radius = 7 },
	},
	{
		id = "south_africa",
		name_key = "country.south_africa",
		iso = "ZA",
		flag = { { 0.0, 0.5, 0.3 }, { 1, 1, 1 }, { 0.1, 0.2, 0.6 } },
		latitude = -29,
		longitude = 24,
		region = { latitude = -29, longitude = 24, radius = 7 },
	},
	{
		id = "colombia",
		name_key = "country.colombia",
		iso = "CO",
		flag = { { 1, 0.85, 0.0 }, { 0.1, 0.2, 0.6 }, { 0.8, 0.1, 0.15 } },
		latitude = 4,
		longitude = -73,
		region = { latitude = 4, longitude = -73, radius = 6 },
	},
}

-- The recurring cast: five characters that reappear every round. Appearance is
-- fixed per slot (portrait art + glow tint); only their position and delivery
-- target change from round to round. `sprite` is the portrait drawn on the globe
-- and in the progress panel; `color` tints the pulsing beacon glow behind it.
local character_slots = {
	{ color = { 0.95, 0.5, 0.3 }, sprite = "assets/sprites/1.png" },
	{ color = { 0.4, 0.8, 0.9 }, sprite = "assets/sprites/2.png" },
	{ color = { 0.7, 0.5, 0.9 }, sprite = "assets/sprites/3.png" },
	{ color = { 0.9, 0.8, 0.3 }, sprite = "assets/sprites/4.png" },
	{ color = { 0.5, 0.9, 0.5 }, sprite = "assets/sprites/5.png" },
}

-- Five rounds of five drop-off countries, ordered by difficulty (biggest →
-- smallest). Each round lists exactly five country ids, one per character slot;
-- src/core/world.lua turns each into a mission and places the matching character
-- at the antipode of that country. Every one of the 25 countries appears exactly
-- once across the five rounds. Completing a round advances to the next; the last
-- loops back to the first, so play never ends (spec §17, extended to a cycle of
-- rounds rather than a single repeating set).
local rounds = {
	{ "russia", "canada", "usa", "china", "brazil" },
	{ "australia", "india", "argentina", "kazakhstan", "algeria" },
	{ "dr_congo", "saudi_arabia", "mexico", "indonesia", "sudan" },
	{ "libya", "iran", "mongolia", "peru", "chad" },
	{ "niger", "angola", "mali", "south_africa", "colombia" },
}

return {
	countries = countries,
	character_slots = character_slots,
	rounds = rounds,
}
