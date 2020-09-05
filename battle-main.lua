-- tactical mode:

local ffi = require("ffi")


-- duplicated in strat-main
local compass = {
	h = {-1, 0},
	j = {0, 1},
	k = {0, -1},
	l = {1, 0},
	y = {-1, -1},
	u = {1, -1},
	b = {-1, 1},
	n = {1, 1}
}
local function newmap(w, h)
	ffi.cdef [[
	typedef struct { int glyph; } mapcell;
	]]

	local cells = ffi.new("mapcell[?]", w * h)
	local x1, y1 = 1, 1

	
	local function index(x, y)
		return cells[(x - x1) + (y - y1) * w]
	end

	local map = {
		x1 = x1, y1 = y1, x2 = w + x1 - 1, y2 = h + y1 - 1, cells = cells,
		index = index
	}
	
	for y = 1, h do
		for x = 1, w do
			index(x, y).glyph = string.byte '.'
		end
	end
	
	for i = map.x1, map.x2 do
		index(i, map.y1).glyph = string.byte '#'
		index(i, map.y2).glyph = string.byte '#'
	end

	for i = map.y1, map.y2 do
		index(map.x1, i).glyph = string.byte '#'
		index(map.x2, i).glyph = string.byte '#'
	end

	return map
end

local function updatemap(map)
	--[[for y = map.y1, map.y2 do
		for x = map.x1, map.x2 do
			-- ncurses.mvaddch(y, x, map.index(x, y).glyph)
			local cell = map.index(x, y) 
			if cell.glyph ~= string.byte("#") then
				local west = map.index(x - 1, y)
				if west.glyph == string.byte("#") then 
					cell.glyph = string.byte("A")
				end
			end
		end
	end]]
end

local function drawmap(camera, map) 
	local term, map = camera.term, camera.map
	local termw, termh = term.getsize()
	local shiftx, shifty = math.floor(-camera.x + .5 * termw), math.floor(-camera.y + .5 * termh)
	local y1, y2, x1, x2 = map.y1, map.y2, map.x1, map.x2

	for y = 0, termh do
		for x = 0, termw do
			-- ncurses.mvaddch(y, x, map.index(x, y).glyph)
			if x - shiftx >= x1 and x - shiftx <= x2 and y - shifty >= y1 and y - shifty <= y2 then
				term.fg(15).bg(8).at(x, y).put(map.index(x - shiftx, y - shifty).glyph)
			end
		end
	end
end

local function drawmobs(camera, mobs)
	-- ncurses.mvaddch(mob.y, mob.x, string.byte(mob.glyph))
	local term = camera.term
	local termw, termh = term.getsize()
	local shiftx, shifty = math.floor(-camera.x + .5 * termw), math.floor(-camera.y + .5 * termh)

	for _, mob in pairs(mobs) do
		term.at(shiftx + mob.p.x, shifty + mob.p.y).put(mob.glyph)
	end
end


local function fight(term)
	local function trytomove(mob, dx, dy)
		local x, y = mob.p.x + dx, mob.p.y + dy

		if x < mob.p.map.x1 or y < mob.p.map.y1 or x > mob.p.map.x2 or y > mob.p.map.y2 then
			return false
		else
			local cell = mob.p.map.index(x, y)

			if cell.glyph == string.byte "#" then
				return false
			end

			mob.p.x, mob.p.y = x, y
			return true
		end
	end

	local function playerturn(mob, ch)
		local dir = compass[ch]

		if dir ~= nil then
			return trytomove(mob, dir[1], dir[2])
		else
			return false
		end
	end

	local map = newmap(31, 31)
	local mobs = {{glyph = "@"}, {glyph = "@"}, {glyph = "@"}, {glyph = "@"}}
	local camera = {x = 5, y = 5, map = map, term = term}
	
	mobs[1].p = {x = 5, y = 5, map = map}
	mobs[2].p = {x = 7, y = 5, map = map}
	mobs[3].p = {x = 5, y = 7, map = map}
	mobs[4].p = {x = 7, y = 7, map = map}

	-- time, actor, position, ad infinitum

	term.erase()
	repeat
		updatemap(map)

		term.erase()
		term.clip(0, 0, 25, 25)
		
		local player = mobs[1]
		camera.x, camera.y = player.p.x, player.p.y

		drawmap(camera, map)
		drawmobs(camera, mobs)

		local key, code = term.getch()

		playerturn(player, key)
	until key == 'Q'

	-- local lines, cols = ncurses.LINES, ncurses.COLS
	-- ncurses.endwin()
end

return {
	focus = fight
}

