-- Data-driven world content for the Flight Map: playable countries, their
-- airports, mission characters, and the missions those characters give.
--
-- This is content configuration (spec §19). The Flight Map logic must not
-- hard-code individual countries or characters — everything here is looked up
-- by id through src/core/world.lua.
--
-- Positions are {latitude, longitude} in degrees. A country's `region` is a
-- great-circle circle (center + angular `radius` in degrees) used for the
-- detection area; it may be slightly larger than the drawn shape (spec §7).
-- `flag` holds simple stripe colors so flags can be drawn without art assets;
-- `flag_asset` is kept for a future real-art swap.

local countries = {
	{
		id = "germany",
		name_key = "country.germany",
		iso = "DE", -- Natural Earth id-mask code (src/core/globe_regions.lua)
		flag = { { 0.1, 0.1, 0.1 }, { 0.8, 0.1, 0.1 }, { 1.0, 0.8, 0.0 } },
		flag_asset = "flags/germany.png",
		latitude = 51,
		longitude = 10,
		region = { latitude = 51, longitude = 10, radius = 9 },
		airport_id = "germany_airport",
	},
	{
		id = "russia",
		name_key = "country.russia",
		iso = "RU",
		flag = { { 1, 1, 1 }, { 0.1, 0.2, 0.7 }, { 0.8, 0.1, 0.1 } },
		flag_asset = "flags/russia.png",
		latitude = 60,
		longitude = 90,
		region = { latitude = 60, longitude = 90, radius = 16 },
		airport_id = "russia_airport",
	},
	{
		id = "india",
		name_key = "country.india",
		iso = "IN",
		flag = { { 1.0, 0.6, 0.2 }, { 1, 1, 1 }, { 0.2, 0.6, 0.3 } },
		flag_asset = "flags/india.png",
		latitude = 22,
		longitude = 79,
		region = { latitude = 22, longitude = 79, radius = 11 },
		airport_id = "india_airport",
	},
	{
		id = "japan",
		name_key = "country.japan",
		iso = "JP",
		flag = { { 1, 1, 1 }, { 0.85, 0.1, 0.2 }, { 1, 1, 1 } },
		flag_asset = "flags/japan.png",
		latitude = 36,
		longitude = 138,
		region = { latitude = 36, longitude = 138, radius = 9 },
		airport_id = "japan_airport",
	},
	{
		id = "brazil",
		name_key = "country.brazil",
		iso = "BR",
		flag = { { 0.0, 0.6, 0.3 }, { 1.0, 0.8, 0.0 }, { 0.1, 0.2, 0.6 } },
		flag_asset = "flags/brazil.png",
		latitude = -10,
		longitude = -52,
		region = { latitude = -10, longitude = -52, radius = 15 },
		airport_id = "brazil_airport",
	},
	{
		id = "usa",
		name_key = "country.usa",
		iso = "US",
		flag = { { 0.1, 0.2, 0.5 }, { 1, 1, 1 }, { 0.8, 0.1, 0.2 } },
		flag_asset = "flags/usa.png",
		latitude = 39,
		longitude = -98,
		region = { latitude = 39, longitude = -98, radius = 15 },
		airport_id = "usa_airport",
	},
	{
		id = "australia",
		name_key = "country.australia",
		iso = "AU",
		flag = { { 0.1, 0.2, 0.5 }, { 1, 1, 1 }, { 0.8, 0.1, 0.2 } },
		flag_asset = "flags/australia.png",
		latitude = -25,
		longitude = 133,
		region = { latitude = -25, longitude = 133, radius = 14 },
		airport_id = "australia_airport",
	},
	{
		id = "egypt",
		name_key = "country.egypt",
		iso = "EG",
		flag = { { 0.8, 0.1, 0.1 }, { 1, 1, 1 }, { 0.1, 0.1, 0.1 } },
		flag_asset = "flags/egypt.png",
		latitude = 27,
		longitude = 30,
		region = { latitude = 27, longitude = 30, radius = 9 },
		airport_id = "egypt_airport",
	},
}

-- One airport per country, all locked in the MVP (spec §9). level_id is unused
-- now but recorded so unlocking later needs no data-shape change.
local airports = {
	{
		id = "germany_airport",
		country_id = "germany",
		latitude = 52,
		longitude = 13,
		state = "locked",
		level_id = "germany_level",
	},
	{
		id = "russia_airport",
		country_id = "russia",
		latitude = 56,
		longitude = 38,
		state = "locked",
		level_id = "russia_level",
	},
	{
		id = "india_airport",
		country_id = "india",
		latitude = 29,
		longitude = 77,
		state = "locked",
		level_id = "india_level",
	},
	{
		id = "japan_airport",
		country_id = "japan",
		latitude = 36,
		longitude = 140,
		state = "locked",
		level_id = "japan_level",
	},
	{
		id = "brazil_airport",
		country_id = "brazil",
		latitude = -16,
		longitude = -48,
		state = "locked",
		level_id = "brazil_level",
	},
	{
		id = "usa_airport",
		country_id = "usa",
		latitude = 39,
		longitude = -77,
		state = "locked",
		level_id = "usa_level",
	},
	{
		id = "australia_airport",
		country_id = "australia",
		latitude = -34,
		longitude = 151,
		state = "locked",
		level_id = "australia_level",
	},
	{
		id = "egypt_airport",
		country_id = "egypt",
		latitude = 30,
		longitude = 31,
		state = "locked",
		level_id = "egypt_level",
	},
}

-- Exactly five mission characters at fixed positions (spec §10). They sit in
-- varied spots (land, water, ice, air) so the player discovers them exploring.
local characters = {
	{
		id = "character_1",
		color = { 0.95, 0.5, 0.3 },
		latitude = 20,
		longitude = -30,
		mission_id = "mission_1",
	},
	{
		id = "character_2",
		color = { 0.4, 0.8, 0.9 },
		latitude = 65,
		longitude = 15,
		mission_id = "mission_2",
	},
	{
		id = "character_3",
		color = { 0.7, 0.5, 0.9 },
		latitude = 5,
		longitude = 60,
		mission_id = "mission_3",
	},
	{
		id = "character_4",
		color = { 0.9, 0.8, 0.3 },
		latitude = -20,
		longitude = 90,
		mission_id = "mission_4",
	},
	{
		id = "character_5",
		color = { 0.5, 0.9, 0.5 },
		latitude = 30,
		longitude = -140,
		mission_id = "mission_5",
	},
}

-- Each character always gives the same mission, targeting a playable country
-- (spec §12). Five characters -> five of the eight countries are targets.
local missions = {
	{ id = "mission_1", character_id = "character_1", target_country_id = "brazil" },
	{ id = "mission_2", character_id = "character_2", target_country_id = "germany" },
	{ id = "mission_3", character_id = "character_3", target_country_id = "india" },
	{ id = "mission_4", character_id = "character_4", target_country_id = "australia" },
	{ id = "mission_5", character_id = "character_5", target_country_id = "japan" },
}

return {
	countries = countries,
	airports = airports,
	characters = characters,
	missions = missions,
}
