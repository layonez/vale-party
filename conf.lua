function love.conf(t)
	t.identity = "valya-adventure"
	-- 11.4 matches the bundled aarch64 handheld runtime (Cebion/love2d_aarch64)
	-- and the love.js web build; desktop LOVE 11.5 runs 11.4 projects fine.
	t.version = "11.4"
	t.window.title = "Valya Adventure"
	t.window.width = 960
	t.window.height = 720
	t.window.resizable = true
	t.window.minwidth = 640
	t.window.minheight = 480
end
