-- Simplified continent outlines for the Flight Map background. These are rough,
-- recognisable blobs placed in approximately the right world location — pure
-- geographic reference, not interactive (playable countries come later and are
-- drawn on top). Each entry is a simple (non-self-intersecting) polygon of
-- {latitude, longitude} vertices in degrees, ordered around the outline.
--
-- Shapes are intentionally coarse; the renderer subdivides and projects them
-- onto the sphere, so only the topology and approximate placement matter here.
return {
	{
		name = "north_america",
		points = {
			{ 60, -135 },
			{ 68, -95 },
			{ 60, -65 },
			{ 45, -65 },
			{ 30, -80 },
			{ 25, -100 },
			{ 32, -118 },
			{ 48, -125 },
		},
	},
	{
		name = "south_america",
		points = {
			{ 10, -75 },
			{ 5, -50 },
			{ -20, -40 },
			{ -40, -62 },
			{ -52, -70 },
			{ -30, -70 },
			{ -10, -78 },
		},
	},
	{
		name = "europe",
		points = {
			{ 60, -8 },
			{ 62, 30 },
			{ 45, 40 },
			{ 40, 25 },
			{ 43, -8 },
			{ 50, -5 },
		},
	},
	{
		name = "africa",
		points = {
			{ 35, -5 },
			{ 32, 30 },
			{ 10, 42 },
			{ -10, 40 },
			{ -34, 20 },
			{ -30, 15 },
			{ -5, 8 },
			{ 15, -15 },
			{ 30, -10 },
		},
	},
	{
		name = "asia",
		points = {
			{ 70, 50 },
			{ 72, 140 },
			{ 55, 140 },
			{ 40, 120 },
			{ 25, 95 },
			{ 35, 60 },
			{ 50, 45 },
		},
	},
	{
		name = "australia",
		points = {
			{ -12, 132 },
			{ -18, 145 },
			{ -38, 148 },
			{ -35, 130 },
			{ -30, 115 },
			{ -18, 118 },
		},
	},
}
