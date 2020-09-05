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

local hall_data = {
	{"hall", bg = 7, stamp = "."},
	{"elevator", bg = 7, stamp = "^"}
}

local facility_data = {
	{"living quarters", bg = 4, stamp = "   ` q `   ", beds = 20},
	{"office block", bg = 3, stamp = "   ` o `   ", offices = 20},
	{"laboratory", bg = 3, stamp = "   ` L `   ", research = 20},
	{"infirmary", bg = 4, stamp = "   ` i `   ", beds = 5},
	{"intramural recreation", bg = 4, stamp = "   ` t `   ", training = 20},

	{"radar", bg = 7, stamp = "   ` r `   ", dish = "uplink"},
	{"uplink", bg = 7, stamp = "   ` u `   ", dish = "uplink"},

	{"mainframe", bg = 1, stamp = "   ` m `   ", cpu = 250},
	{"generator", bg = 1, stamp = "   ` g `   ", power_supply = 100}, 
	{"library", bg = 1, stamp = "   ` l `   ", books = 50},
	{"stores", bg = 7, stamp = "    ` g  `  s `    ", volume = 250}
}

local function new_base() 
	-- start without an explicit grid and explore from there
	local facilities = { }
	
	local function newfacility(data, x, y)
		local facility = {
			x = x or 20, y = y or 20, data = data
		}
		facilities[1 + #facilities] = facility
		return facility
	end
	
	local function draw(term, cursor)
		local function drawfacility(facility)
			local x1, y1 = facility.x, facility.y
			local x, y = x1, y1
			local selected = false

			if term ~= nil then
				term.fg(15).bg(facility.data.bg)
			end
			for c in facility.data.stamp:gmatch(".") do
				if c == "`" then
					x, y = x1, y + 1
				else
					if c ~= "~" then
						if term ~= nil then
							term.at(x, y).put(c)
						end
						if cursor ~= nil and x == cursor.x and y == cursor.y then
							selected = true
						end
					end
					x = x + 1
				end
			end
			return selected
		end

		local function drawcursor()
			term.fg(15).bg(0).at(cursor.x-1, cursor.y).put("[").at(cursor.x+1, cursor.y).put("]")
		end

		term.erase()

		for _, facility in pairs(facilities) do
			drawfacility(facility)
		end

		drawcursor()
	end
	
	local function focus(term)
		local cursor = { x = 6, y = 6 }
		
		repeat
			draw(term, cursor)
			local key = term.getch()
			
			local delta = compass[key]
			if delta ~= nil then
				cursor.x = cursor.x + delta[1]
				cursor.y = cursor.y + delta[2]
			else
				if key == '.' then
					newfacility(hall_data[1], cursor.x, cursor.y)
				end
			end
		until key == 'Q'
	end

	newfacility(facility_data[1], 5, 5)
	newfacility(hall_data[1], 8, 6)
	newfacility(facility_data[2], 9, 5)
	newfacility(hall_data[1], 12, 6)
	newfacility(facility_data[3], 13, 5)
	newfacility(hall_data[1], 16, 6)
	newfacility(facility_data[4], 17, 5)

	return {
		focus = focus
	}
end


return new_base

