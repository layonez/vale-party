-- Textured globe renderer for the Flight Map.
--
-- Draws an equirectangular world texture onto a sphere with an ORTHOGRAPHIC
-- fragment shader that consumes the SAME orientation matrix used by everything
-- else on the globe (src/core/sphere.lua). Because the shader reproduces
-- Sphere.project's mapping exactly, the existing vector overlays (graticule,
-- country outlines, characters) drawn via Sphere.project land pixel-aligned on
-- top of the textured sphere.
--
-- Design notes tied to the target device (RG35XX Plus, likely GLSL ES 1.00):
--   * The texture must be power-of-two and use wrap "repeat" so bilinear taps
--     at the antimeridian blend the correct adjacent longitudes (no seam).
--   * No mipmaps: the classic longitude seam is a mipmap artifact (atan jumps
--     ~2pi over one pixel -> huge derivative -> coarsest mip -> blurry line).
--   * Orientation is passed as three vec3 uniforms (the {fwd, right, up} rows of
--     sphere.lua's matrix), avoiding mat3 layout ambiguity and transpose()
--     (which GLSL ES 1.00 lacks). world = viewX*fwd + viewY*right + viewZ*up.
--   * Disc math derives (u,v) from the drawn image's texture_coords, not screen
--     pixels, so it survives the app.drawScaled canvas scaling.
--   * newShader is pcall-guarded; on compile failure the caller falls back to
--     the existing CPU vector renderer (Landmass).

local GlobeShader = {}
GlobeShader.__index = GlobeShader

-- GLSL ES 1.00 so a desktop compile catches device-incompatible code early.
-- effect() receives texture_coords in 0..1 across the drawn image (our disc box).
local SHADER_SRC = [[
#pragma language glsl1
// No explicit `precision` qualifier: under GLSL ES 1.00 (WebGL / the RG35XX)
// forcing `precision highp float;` here clashes with LOVE's own shader header,
// which has already resolved the built-in overloads (clamp/mix/...) at its
// default precision -> "overloaded functions must have the same parameter
// precision qualifiers". Letting LOVE set the default compiles on both desktop
// GL and GLSL ES. (Verified: this exact block failed under love.js WebGL.)

// Orientation rows from src/core/sphere.lua: forward (toward viewer), screen
// right, screen up. view = R * world, and R is orthonormal, so
// world = R^T * view = viewX*fwd + viewY*right + viewZ*up.
extern vec3 uFwd;
extern vec3 uRight;
extern vec3 uUp;

// Country highlights, sampled from the id mask (flat colors, so a tiny epsilon
// suffices). Up to two at once: a primary (mission target, pulsing green) and a
// secondary (recognized country, steady yellow). Each *On uniform is 0 when
// unused; each *Color is the country's flat id-mask color (0..1).
extern Image idMap;
extern vec3 uHiColor;
extern float uHiOn;
extern float uHiPulse; // 0..1 fill strength for the primary highlight
extern vec3 uHi2Color;
extern float uHi2On;
extern vec2 uIdTexel; // (1/idW, 1/idH): one id-mask texel in UV units
extern float uBorderW; // border band thickness, in id-mask texels

#define PI 3.141592653589793

bool sameId(vec3 a, vec3 c) {
    return all(lessThan(abs(a - c), vec3(0.01)));
}

// Classify a pixel against a country color `c`, sampling the id mask around
// `uv` at `off` (UV units): 0 = not this country, 1 = interior, 2 = border band
// (an interior pixel with a differently-colored neighbor `off` away — i.e. near
// the real coastline/border). Bigger `off` => thicker border.
float zoneFor(vec3 c, vec2 uv, vec2 off) {
    if (!sameId(Texel(idMap, uv).rgb, c)) {
        return 0.0;
    }
    if (!sameId(Texel(idMap, uv + vec2(off.x, 0.0)).rgb, c)
        || !sameId(Texel(idMap, uv - vec2(off.x, 0.0)).rgb, c)
        || !sameId(Texel(idMap, uv + vec2(0.0, off.y)).rgb, c)
        || !sameId(Texel(idMap, uv - vec2(0.0, off.y)).rgb, c)) {
        return 2.0;
    }
    return 1.0;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 screen_coords) {
    // Disc coordinates in [-1,1]. tc.x -> screen right (viewY), tc.y grows
    // downward so screen up (viewZ) = 1 - 2*tc.y. Matches Sphere.project:
    // sx = cx + R*vy, sy = cy - R*vz.
    float vy = tc.x * 2.0 - 1.0;
    float vz = 1.0 - tc.y * 2.0;
    float r2 = vy * vy + vz * vz;
    if (r2 > 1.0) {
        discard; // outside the globe disc
    }
    float vx = sqrt(1.0 - r2); // near hemisphere, toward viewer

    // Reconstruct the world unit vector under the current orientation.
    vec3 world = vx * uFwd + vy * uRight + vz * uUp;

    // Equirectangular UV. z is the polar axis (lat = asin z), lon = atan(y, x).
    float lat = asin(clamp(world.z, -1.0, 1.0));
    float lon = atan(world.y, world.x);
    vec2 uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);

    vec4 base = Texel(tex, uv);

    // Highlight selected countries: a vivid interior fill plus a thick, bright
    // border traced along the real coastline. Secondary (recognized, yellow) is
    // drawn first so the primary (target, green) wins where they overlap.
    if (uHiOn > 0.5 || uHi2On > 0.5) {
        vec2 boff = uIdTexel * uBorderW;
        if (uHi2On > 0.5) {
            float z = zoneFor(uHi2Color, uv, boff);
            if (z > 1.5) {
                base.rgb = vec3(1.0, 0.78, 0.15); // bright amber border
            } else if (z > 0.5) {
                base.rgb = mix(base.rgb, vec3(1.0, 0.88, 0.35), 0.55);
            }
        }
        if (uHiOn > 0.5) {
            float z = zoneFor(uHiColor, uv, boff);
            if (z > 1.5) {
                // Bright, high-contrast pulsing outline (green -> near-white).
                base.rgb = mix(vec3(0.1, 0.9, 0.25), vec3(0.95, 1.0, 0.85), uHiPulse);
            } else if (z > 0.5) {
                // Strong vivid green fill so the target reads at a glance.
                base.rgb = mix(base.rgb, vec3(0.15, 0.95, 0.35), 0.6 + 0.3 * uHiPulse);
            }
        }
    }

    // Gentle spherical shading: darker toward the limb for a rounded look.
    float shade = 0.55 + 0.45 * vx;
    base.rgb *= shade;

    // Soft anti-aliased rim so the disc edge is not jagged at 640x480.
    float edge = smoothstep(1.0, 0.985, r2);
    return vec4(base.rgb, base.a * edge) * color;
}
]]

---Try to build the renderer. Returns nil (and logs) if the texture or shader
---cannot be loaded, so the caller can fall back to the CPU renderer.
---@param baseTexPath string equirectangular color map (power-of-two 2:1)
---@param idTexPath string|nil equirectangular id mask for highlighting
---@param log fun(msg: string)|nil
---@return table|nil
function GlobeShader.new(baseTexPath, idTexPath, log)
	log = log or function() end
	local self = setmetatable({}, GlobeShader)

	local okShader, shader = pcall(love.graphics.newShader, SHADER_SRC)
	if not okShader then
		log("globe_shader_compile_failed:" .. tostring(shader))
		return nil
	end
	self.shader = shader

	local okTex, tex = pcall(love.graphics.newImage, baseTexPath)
	if not okTex then
		log("globe_texture_load_failed:" .. tostring(tex))
		return nil
	end
	tex:setWrap("repeat", "clamp") -- repeat across longitude fixes the seam
	tex:setFilter("linear", "linear") -- no mipmaps requested
	self.tex = tex

	if idTexPath then
		local okId, idTex = pcall(love.graphics.newImage, idTexPath)
		if okId then
			idTex:setWrap("repeat", "clamp")
			idTex:setFilter("nearest", "nearest") -- flat colors: never blend ids
			self.idTex = idTex
			self.shader:send("idMap", idTex)
			-- One id-mask texel in UV units, so the border trace samples exact
			-- neighbor pixels regardless of mask resolution.
			self.shader:send("uIdTexel", { 1 / idTex:getWidth(), 1 / idTex:getHeight() })
			-- Border band thickness in id-mask texels. Traced along the real
			-- coastline for a bold, high-contrast outline at a 1024x512 mask.
			self.shader:send("uBorderW", 2.0)
		else
			log("globe_idmask_load_failed:" .. tostring(idTex))
		end
	end
	self.shader:send("uHiOn", 0)
	self.shader:send("uHiColor", { -1, -1, -1 })
	self.shader:send("uHiPulse", 0)
	self.shader:send("uHi2On", 0)
	self.shader:send("uHi2Color", { -1, -1, -1 })
	return self
end

---Primary highlight (pulsing green — the mission target). `color` is {r,g,b}
---0..255 from the id mask, or nil to clear. `pulse` is 0..1 fill strength
---(defaults to 1). No-op if there is no id mask.
---@param color table|nil
---@param pulse number|nil
function GlobeShader:setHighlight(color, pulse)
	if not self.idTex then
		return
	end
	if color then
		self.shader:send("uHiColor", { color[1] / 255, color[2] / 255, color[3] / 255 })
		self.shader:send("uHiOn", 1)
		self.shader:send("uHiPulse", pulse or 1)
	else
		self.shader:send("uHiOn", 0)
	end
end

---Secondary highlight (steady yellow — the recognized country). Same args as
---the primary color; nil clears it.
---@param color table|nil
function GlobeShader:setSecondaryHighlight(color)
	if not self.idTex then
		return
	end
	if color then
		self.shader:send("uHi2Color", { color[1] / 255, color[2] / 255, color[3] / 255 })
		self.shader:send("uHi2On", 1)
	else
		self.shader:send("uHi2On", 0)
	end
end

---Draw the textured sphere for the given orientation. `globe` is {x, y, radius}.
---@param orientation table sphere.lua matrix {fwd, right, up}
---@param globe table
function GlobeShader:draw(orientation, globe)
	self.shader:send("uFwd", { orientation[1][1], orientation[1][2], orientation[1][3] })
	self.shader:send("uRight", { orientation[2][1], orientation[2][2], orientation[2][3] })
	self.shader:send("uUp", { orientation[3][1], orientation[3][2], orientation[3][3] })

	love.graphics.setShader(self.shader)
	love.graphics.setColor(1, 1, 1, 1)
	-- Draw the texture as a 2R x 2R quad centered on the globe so the incoming
	-- texture_coords run 0..1 across the disc box (transform-independent).
	local size = 2 * globe.radius
	local sx = size / self.tex:getWidth()
	local sy = size / self.tex:getHeight()
	love.graphics.draw(self.tex, globe.x - globe.radius, globe.y - globe.radius, 0, sx, sy)
	love.graphics.setShader()
end

return GlobeShader
