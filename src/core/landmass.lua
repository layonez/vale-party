-- Prepares and draws simplified continents on the sphere. Each continent
-- polygon (content/continents.lua) is triangulated once at load and each
-- triangle subdivided a few times, so it renders as a smooth filled blob that
-- follows the planet's curvature. At draw time each small triangle is projected
-- through the current orientation and skipped if it lies behind the horizon,
-- giving a clean silhouette at the disc edge without explicit polygon clipping.
local Sphere = require("src.core.sphere")

local Landmass = {}

-- Midpoint-subdivide a lat/lon triangle `depth` times into a flat list of
-- smaller {lat, lon} triangles. More subdivision = smoother curvature and a
-- cleaner horizon edge, at the cost of more triangles.
local function subdivide(tri, depth, out)
	if depth == 0 then
		out[#out + 1] = tri
		return
	end
	local a, b, c = tri[1], tri[2], tri[3]
	local ab = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 }
	local bc = { (b[1] + c[1]) / 2, (b[2] + c[2]) / 2 }
	local ca = { (c[1] + a[1]) / 2, (c[2] + a[2]) / 2 }
	subdivide({ a, ab, ca }, depth - 1, out)
	subdivide({ ab, b, bc }, depth - 1, out)
	subdivide({ ca, bc, c }, depth - 1, out)
	subdivide({ ab, bc, ca }, depth - 1, out)
end

-- Build the render-ready triangle mesh for every continent. Returns a list of
-- { name, triangles = { {lat,lon}x3, ... } }.
---@param continents table[]
---@param depth integer|nil subdivision depth (default 2)
---@return table[]
function Landmass.build(continents, depth)
	depth = depth or 2
	local built = {}
	for _, continent in ipairs(continents) do
		-- Triangulate the outline in planar lon/lat space; the shapes are simple
		-- polygons so this is stable and only runs once at load.
		local flat = {}
		for _, p in ipairs(continent.points) do
			flat[#flat + 1] = p[2] -- lon as x
			flat[#flat + 1] = p[1] -- lat as y
		end
		local tris = {}
		for _, t in ipairs(love.math.triangulate(flat)) do
			-- triangulate returns {x1,y1,x2,y2,x3,y3}; convert back to {lat,lon}.
			subdivide({
				{ t[2], t[1] },
				{ t[4], t[3] },
				{ t[6], t[5] },
			}, depth, tris)
		end
		built[#built + 1] = { name = continent.name, triangles = tris }
	end
	return built
end

-- Draw all continents for the given orientation. `globe` is { x, y, radius }.
---@param built table[]
---@param orientation table
---@param globe table
function Landmass.draw(built, orientation, globe)
	love.graphics.setColor(0.36, 0.62, 0.34)
	for _, continent in ipairs(built) do
		for _, tri in ipairs(continent.triangles) do
			local x1, y1, v1 =
				Sphere.project(orientation, tri[1][1], tri[1][2], globe.radius, globe.x, globe.y)
			local x2, y2, v2 =
				Sphere.project(orientation, tri[2][1], tri[2][2], globe.radius, globe.x, globe.y)
			local x3, y3, v3 =
				Sphere.project(orientation, tri[3][1], tri[3][2], globe.radius, globe.x, globe.y)
			-- Only draw fully-visible triangles; near the horizon a few drop out,
			-- but dense subdivision keeps the silhouette smooth.
			if v1 and v2 and v3 then
				love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)
			end
		end
	end
end

return Landmass
