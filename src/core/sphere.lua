-- Spherical world math for the Flight Map.
--
-- The world is a unit sphere addressed by {lat, lon} in degrees. Rather than
-- tracking a camera latitude/longitude (which makes the poles coordinate
-- singularities — "up" always walks to the same pole and movement stalls
-- there), we store a full 3D orientation: a world->view rotation matrix. The
-- airplane sits at the view front; the player flies by rotating the globe about
-- SCREEN-fixed axes, so "up" traces whichever great circle is currently
-- vertical and passes continuously over any pole without stopping.
--
-- View frame (after applying the orientation to a world vector):
--   +X = out of the screen toward the viewer (the sub-airplane point)
--   +Y = screen right
--   +Z = screen up
-- A world point is visible when its view X >= 0 (near hemisphere).
--
-- All functions here are pure so they can be unit tested without LOVE.
local Sphere = {}

local rad, deg = math.rad, math.deg
local sin, cos, asin, sqrt = math.sin, math.cos, math.asin, math.sqrt
-- math.atan2 was merged into math.atan (two-arg form) in Lua 5.3; LuaJIT keeps
-- atan2. Support both so the pure module runs under the test runner and LOVE.
local atan2 = math.atan2 or math.atan

---Wrap a longitude into the half-open range (-180, 180].
---@param lon number
---@return number
function Sphere.normalizeLon(lon)
	lon = (lon + 180) % 360
	if lon < 0 then
		lon = lon + 360
	end
	return lon - 180
end

---Unit world vector for a lat/lon (degrees). Z is the polar axis.
---@param lat number
---@param lon number
---@return number x
---@return number y
---@return number z
function Sphere.latLonToVec(lat, lon)
	local la, lo = rad(lat), rad(lon)
	local cl = cos(la)
	return cl * cos(lo), cl * sin(lo), sin(la)
end

---Lat/lon (degrees) for a world vector; longitude normalized.
---@param x number
---@param y number
---@param z number
---@return number lat
---@return number lon
function Sphere.vecToLatLon(x, y, z)
	local clamped = math.max(-1, math.min(1, z))
	return deg(asin(clamped)), Sphere.normalizeLon(deg(atan2(y, x)))
end

local function cross(ax, ay, az, bx, by, bz)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function normalize(x, y, z)
	local len = sqrt(x * x + y * y + z * z)
	if len < 1e-9 then
		return 0, 0, 0
	end
	return x / len, y / len, z / len
end

---Build an orientation placing (lat, lon) at the view front with the world
---north pole biased toward screen-up. Returned as nested rows {fwd, right, up}
---so a world vector projects as viewVec = R * worldVec.
---@param lat number
---@param lon number
---@return table orientation
function Sphere.orientationFor(lat, lon)
	local fx, fy, fz = Sphere.latLonToVec(lat, lon)
	-- Up = world north projected onto the plane perpendicular to forward.
	local d = fz -- dot((0,0,1), forward)
	local ux, uy, uz = normalize(0 - d * fx, 0 - d * fy, 1 - d * fz)
	if ux == 0 and uy == 0 and uz == 0 then
		-- Forward is (near) a pole; pick any perpendicular up.
		ux, uy, uz = normalize(cross(fx, fy, fz, 1, 0, 0))
	end
	local rx, ry, rz = cross(ux, uy, uz, fx, fy, fz) -- right = up x forward
	return { { fx, fy, fz }, { rx, ry, rz }, { ux, uy, uz } }
end

-- Multiply view-space rotation S (3x3) by orientation R, returning S*R.
local function mul(s, r)
	local out = {}
	for i = 1, 3 do
		out[i] = {}
		for j = 1, 3 do
			out[i][j] = s[i][1] * r[1][j] + s[i][2] * r[2][j] + s[i][3] * r[3][j]
		end
	end
	return out
end

-- Re-orthonormalize rows (Gram-Schmidt + cross) to shed float drift from many
-- accumulated rotations, keeping the matrix a clean rotation.
local function orthonormalize(r)
	local f = { normalize(r[1][1], r[1][2], r[1][3]) }
	-- right := right - (right.f) f, normalized
	local dr = r[2][1] * f[1] + r[2][2] * f[2] + r[2][3] * f[3]
	local right = { normalize(r[2][1] - dr * f[1], r[2][2] - dr * f[2], r[2][3] - dr * f[3]) }
	local up = { cross(f[1], f[2], f[3], right[1], right[2], right[3]) }
	-- Rows are {forward, right, up}; forward x right = up keeps a right-handed
	-- frame (X x Y = Z), matching orientationFor.
	return { f, right, up }
end

-- View-space rotation about an axis by angle (radians). Axis "y" = screen-right
-- (up/down flight), "z" = screen-up (left/right flight).
local function screenRotation(axis, angle)
	local c, s = cos(angle), sin(angle)
	if axis == "y" then
		return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } }
	elseif axis == "z" then
		return { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } }
	else -- "x" (roll); unused by input but kept for completeness
		return { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } }
	end
end

---Rotate the orientation about a screen-fixed axis. Pre-multiplies so the
---rotation is applied in the current view frame, then re-orthonormalizes.
---@param orientation table
---@param axis string "y" (up/down) | "z" (left/right) | "x" (roll)
---@param angle number radians
---@return table orientation
function Sphere.turn(orientation, axis, angle)
	return orthonormalize(mul(screenRotation(axis, angle), orientation))
end

---World lat/lon currently at the view front (beneath the airplane).
---@param orientation table
---@return number lat
---@return number lon
function Sphere.front(orientation)
	-- Front world vector maps to view (1,0,0) => it is row 1 of R.
	local r = orientation[1]
	return Sphere.vecToLatLon(r[1], r[2], r[3])
end

---Project a world lat/lon to the screen under an orientation.
---@param orientation table
---@param lat number
---@param lon number
---@param radius number globe radius in pixels
---@param cx number screen x of the globe center
---@param cy number screen y of the globe center
---@return number sx
---@return number sy
---@return boolean visible false when behind the horizon
function Sphere.project(orientation, lat, lon, radius, cx, cy)
	local x, y, z = Sphere.latLonToVec(lat, lon)
	local r = orientation
	local vx = r[1][1] * x + r[1][2] * y + r[1][3] * z -- depth (toward viewer)
	local vy = r[2][1] * x + r[2][2] * y + r[2][3] * z -- screen right
	local vz = r[3][1] * x + r[3][2] * y + r[3][3] * z -- screen up
	return cx + radius * vy, cy - radius * vz, vx >= 0, vx
end

---Sample a small circle on the sphere: the set of points at angular distance
---`angRadius` (degrees) from a center lat/lon. Returns `segments+1` {lat, lon}
---points closing the loop, for drawing country regions/highlights.
---@param centerLat number
---@param centerLon number
---@param angRadius number angular radius in degrees
---@param segments integer number of segments around the circle
---@return table points list of {lat, lon}
function Sphere.circlePoints(centerLat, centerLon, angRadius, segments)
	-- Build a local frame at the center: forward toward the center, plus two
	-- perpendicular axes to sweep the circle around.
	local cx, cy, cz = Sphere.latLonToVec(centerLat, centerLon)
	-- Pick any vector not parallel to the center to derive the tangent axes.
	local ux, uy, uz = normalize(cross(cx, cy, cz, 0, 0, 1))
	if ux == 0 and uy == 0 and uz == 0 then
		ux, uy, uz = normalize(cross(cx, cy, cz, 1, 0, 0))
	end
	local vx, vy, vz = cross(cx, cy, cz, ux, uy, uz) -- second tangent axis
	local ca, sa = cos(rad(angRadius)), sin(rad(angRadius))
	local points = {}
	for i = 0, segments do
		local t = 2 * math.pi * i / segments
		local ct, st = cos(t), sin(t)
		-- point = center*cos(r) + (u*cos t + v*sin t)*sin(r)
		local px = cx * ca + (ux * ct + vx * st) * sa
		local py = cy * ca + (uy * ct + vy * st) * sa
		local pz = cz * ca + (uz * ct + vz * st) * sa
		local lat, lon = Sphere.vecToLatLon(px, py, pz)
		points[#points + 1] = { lat, lon }
	end
	return points
end

local function normalize2(x, y)
	local len = sqrt(x * x + y * y)
	if len < 1e-9 then
		return 0, 0
	end
	return x / len, y / len
end

---Screen-space direction from the globe center toward a world point, as a unit
---vector in screen coordinates (y grows downward). Works even when the point is
---behind the horizon: the (right, up) view components still give the azimuth to
---turn toward, which is what the target arrow needs (spec §13). Returns dx, dy,
---and whether the point is on the visible hemisphere.
---@param orientation table
---@param lat number
---@param lon number
---@return number dx
---@return number dy
---@return boolean visible
function Sphere.screenDirection(orientation, lat, lon)
	local x, y, z = Sphere.latLonToVec(lat, lon)
	local r = orientation
	local vx = r[1][1] * x + r[1][2] * y + r[1][3] * z -- depth
	local vy = r[2][1] * x + r[2][2] * y + r[2][3] * z -- screen right
	local vz = r[3][1] * x + r[3][2] * y + r[3][3] * z -- screen up
	local dx, dy = normalize2(vy, -vz) -- screen y grows downward
	return dx, dy, vx >= 0
end

---Gently roll the orientation so the world north pole projects toward screen-up,
---shedding the roll drift ("tumbling") that accumulates when turns about
---different screen axes compose. The correction is rate-limited to `maxStep`
---radians and fades to zero as the view front nears a pole (where screen "up" is
---undefined), so flying straight over a pole stays smooth instead of snapping.
---The forward (sub-airplane) point is unchanged. Pure, for unit testing.
---@param orientation table {fwd, right, up}
---@param maxStep number max roll correction this call, radians (>= 0)
---@return table orientation
function Sphere.relevel(orientation, maxStep)
	local r = orientation
	-- World north (0,0,1) in view space is column 3 of R: its screen-right and
	-- screen-up components. m is their magnitude = cos(front latitude): it shrinks
	-- to 0 at a pole, which fades the correction out there.
	local vr = r[2][3] -- screen-right component of north
	local vu = r[3][3] -- screen-up component of north
	local m = sqrt(vr * vr + vu * vu)
	if m < 1e-6 then
		return orientation -- at a pole: no meaningful "up" to level toward
	end
	-- Angle of north's screen projection away from straight up; a roll about the
	-- forward axis by this angle brings north back to vertical.
	local err = atan2(vr, vu)
	local step = err
	if step > maxStep then
		step = maxStep
	elseif step < -maxStep then
		step = -maxStep
	end
	step = step * m
	if step == 0 then
		return orientation
	end
	return orthonormalize(mul(screenRotation("x", step), orientation))
end

return Sphere
