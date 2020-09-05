#! ./tact

local term = locatedofile("curses")
local ffi = require("ffi")

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

local function newLayer(width, height) 
	local x1, y1, default = 1, 1, 0
	local cells = ffi.new("int[?]", width * height)

	local function get(x, y)
		x, y = x - x1, y - y1
		if x < 0 or y < 0 or x >= width or y >= height then
			return default
		else
			return cells[x + y * width]
		end
	end

	local function set(x, y, v)
		x, y = x - x1, y - y1
		if x < 0 or y < 0 or x >= width or y >= height then
			return
		end

		cells[x + y * width] = v
	end

	local function recenter(x, y)
		x1, y1 = math.floor(x - width / 2), math.floor(y - height / 2)
	end

	local function fill(v)
		for i = 0, width * height - 1 do
			cells[i] = v
		end
	end
	
	return {
		get = get,
		set = set,
		fill = fill,
		recenter = recenter,
		width = width,
		height = height,
		cells = cells
	}
end

local function newMap(width, height)
	local stepcost = newLayer(width, height)

	local function generate()
	end

	return stepcost
end


local function interaction()
	local map = newMap(50, 50)

	local function render(term)
		term.erase()
		term.clip(0, 0, nil, nil, "square")

		for y = 1, 50 do
			for x = 1, 50 do
				local cell = map.get(x, y)
				term.at(x, y)
				if cell < 0 then
					term.put('#')
				else
					term.put(' ')
				end
			end
		end
	end

	local function focus(term)
		render(term)
		term.getch()
	end

	return {
		focus = focus
	}
end

interaction().focus(term)


--term.erase()
--term.refresh()
--term.endwin()

