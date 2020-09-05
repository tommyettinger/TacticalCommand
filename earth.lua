local ffi = require("ffi")

--[==[ ffi.cdef [[
	typedef struct {double x, y, z;} vector3;
	typedef struct {int face; double u, v;} vector3;
]] ]==]

-- create a ball!

local earth_source = {
	stars = "data/heasarc_sao_reduced_6.tdat",
	water = "data/water-cube.bmp",
	scene = "data/scene-cube.bin"
}


-- original data comes from:
-- http://www.ssa.gov/oact/babynames/limits.html
-- http://www-surf.larc.nasa.gov/surf/pages/data-page.html
-- http://www.ngdc.noaa.gov/mgg/global/etopo2.html with a 2 minute resolution heightmap of the earth, including ocean beds.
-- http://heasarc.gsfc.nasa.gov/W3Browse/star-catalog/sao.html

local scene_types = {
	{"evergreen broad forest", day = {2, 2, "&"}, night = {2, 0, "."}},
	{"evergreen needle forest", day = {2, 0, "&"}, night = {2, 0, "."}},
	{"deciduous needle forest", day = {2, 2, "&"}, night = {2, 0, "."}}, -- make seasonal
	{"deciduous broad forest", day = {2, 2, "&"}, night = {2, 0, "."}}, -- make seasonal?  with color?
	{"mixed forest", day = {2, 0,  "&"}, night = {2, 0, "."}},
	{"closed shrubs", day = {2, 0, "&"}, night = {2, 0, "."}},
	{"open shrubs / desert", day = {3, 3, "#"}, night = {2, 0, "."}},
	{"woody savanna", day = {3, 0, "#"}, night = {3, 0, "."}},
	{"savanna", day = {3, 2, "#"}, night = {3, 0, "."}},
	{"grassland", day = {2, 2, "#"}, night = {2, 0, "."}},
	{"wetland", day = {2, 0, "&"}, night = {2, 0, "."}},
	{"cropland", day = {10, 3, "%"}, night = {10, 0, "."}},
	{"urban", day = {2, 2, "$"}, night = {15, 0, ":"}},
	{"crop mosaic", day = {2, 3, "%"}, night = {2, 0, "."}},
	{"antarctic snow", day = {15, 7, "#"}, night = {7, 0, "."}},
	{"barren / desert", day = {11, 3, "#"}, night = {11, 0, "."}},
	{"ocean water", day = {7, 0, "."}, night = {0, 0, " "}}, -- this only comes up when the data doesn't line up quite right
	{"tundra", day = {7, 7, "#"}, night = {7, 0, "."}},
	{"fresh snow", day = {15, 7, "#"}, night = {7, 0, "."}},
	{"sea ice", day = {15, 4, "%"}, night = {7, 0, "."}}
}


-- from the Lua manual:
function fsize (file)
	local current = file:seek()      -- get current position
	local size = file:seek("end")    -- get file size
	file:seek("set", current)        -- restore position
	return size
end

function read32(f)
	local a, b, c, d = string.byte(f:read(4), 1, 4)
	return 256 * (256 * (256 * d + c) + b) + a
end

local function cubemap(source)
	local f = io.open(source, "rb")
	
	if f == nil then
		return nil
	end
	
	local isbmp = string.find(source, "%.bmp$") ~= nil
	-- local bytes = ffi.new("char[?]", 

	print ("Loading cubemap " .. source)
	
	if isbmp then
		f:seek("set", 18)
	end

	local width, height = read32(f), read32(f)
	local sixthwidth = math.floor(width / 6.0)

	if isbmp then
		f:seek("set", 0x436);
	end

	local buffer = f:read(width * height)
	
	-- handle endianness and perhaps other formats?
	f:close()
	
	local function raw(x, y)
		local val = string.byte(buffer, 1 + x + y * width) 
		if val ~= nil then
			return val
		else
			-- buggy
			return nil
		end
	end

	local function onface(face, u, v)
		-- int mapx = (int) (win->earth->width / 6.0 * (u + (float)face));
		-- int mapy = (int) (win->earth->height * v);
		local x, y = math.floor(sixthwidth * (u + face)), math.floor(height * v)
		return raw(x, y)
	end

	return {
		raw = raw,
		onface = onface
	}
end

local function startable(source)
	local header = { }
	local linefmt = { }

	local function headerline(line)
		-- print(line)
		-- local k, _, d, v = string.match(line, "([%w_]+)(%[[%w_]+%])? = (.+)")
		local k, v = string.match(line, "([%w_%[%]]+)%s*=%s*(.+)")
		if k ~= nil then
			header[k] = v

			if k == "line[1]" then
				local idx = 1
				local columns = string.split(v, " ")
				for i, k in pairs(columns) do
					linefmt[k] = i
				end
			end
		end
	end

	local startemplate = {
		{"*", 15},
		{"*", 14},
		{"*", 11},
		{".", 7},
		{".", 3},
		{".", 8},
	}

	local function dataline(line, starlist)
		-- read it according to linefmt, splitting on line
		local data = string.split(line, "|")
		local vmag = tonumber(data[linefmt.vmag])
		local minmag, maxmag = 1, 6

		if vmag ~= nil and vmag < maxmag then 
			local name, ra, dec = data[linefmt.name], tonumber(data[linefmt.ra]), tonumber(data[linefmt.dec])

			ra = ra * math.pi / 180
			dec = dec * math.pi / 180

			local y, scale = math.sin(dec), math.cos(dec)
			local x, z = scale * math.cos(ra), scale * math.sin(ra)

			if vmag < 1 then
				vmag = 1
			end
			
			local idx = math.floor(1 + (#startemplate) * (vmag - minmag) / (maxmag - minmag))
			
			local template = startemplate[idx]
			
			local star = {
				position = {x, y, z},
				glyph = template[1],
				color = template[2],
				vmag = vmag
			}

			-- if name == "SAO 308" then star.glyph = "P" end -- polaris is wonky

			starlist[1 + #starlist] = star
		end
	end

	local function process()
		local mode = 0
		print ("Loading starmap " .. source)
		local starlist = { }

		for line in io.lines(source) do
			local sw = string.byte(line, 1)
			if sw ~= string.byte "#" then
				if sw == string.byte "<" then
					if line == "<HEADER>" then
						mode = 1
					elseif line == "<DATA>" then
						mode = 2
					else
						mode = 0
					end
				else
					if mode == 1 then
						headerline(line)
					elseif mode == 2 then
						dataline(line, starlist)
					end
				end
			end
		end

		return starlist
	end

	return process(source)
end

local function ball_model()
	local center, radius = {0, 0, 0}, 1

	local function intersect(source, heading)
		-- returns, as it were, a source and a heading, or nil if there is no intersection
		local hx, hy, hz = heading[1], heading[2], heading[3]
		local cx, cy, cz = center[1] - source[1], center[2] - source[2], center[3] - source[3]
		
		local a = hx * hx + hy * hy + hz * hz
		local b = -2 * (hx * cx + hy * cy + hz * cz)
		local c = (cx * cx + cy * cy + cz * cz) - (radius * radius)
		
		local disc = b * b - 4 * a * c

		if disc > 0 then
			local t = (-b - math.sqrt(disc)) / (2 * a) -- verified
			
			if t > 0 then
				-- now we've got to work out the vector from the center, handle any necessary rotation (etc.)
				-- but first, the sample point on the cube surface

				local x, y, z = t * hx, t * hy, t * hz
				local nx, ny, nz = x - cx, y - cy, z - cz

				return x, y, z, nx, ny, nz
			else
				return nil
			end
		else
			return nil
		end
	end
	
	return {
		intersect = intersect
	}
end

local function starmap( )
	local stars = startable(earth_source.stars)
	local sun = {
		position = {-1, 0, 0},
		glyph = "#",
		large = true,
		color = 15,
		vmag = 1 -- always drawn
	}

	stars[1 + #stars] = sun

	return {
		stars = stars,
		sun = sun
	}
end

local function globe(sources)
	local ball = ball_model()

	local maps = {
		water = cubemap(sources.water),
		scene = cubemap(sources.scene)
	}

	local function intersect(source, heading)
		local x, y, z, nx, ny, nz = ball.intersect(source, heading)

		return nx, ny, nz, x, y, z
	end

	local function lookup(season, nx, ny, nz)
		if nz == nil then
			return nil
		end

		-- in all likelihood, we should simply return x, y, z and nx, ny, nz
		local sun = season[1]
		local face, u, v = linear.tocubecoord(nx, ny, nz)
			
		local bright = (sun[1] * nx + sun[2] * ny + sun[3] * nz)
		
		if bright < 0 then
			bright = 0
		end

		-- overly specific, incomplete
		u, v = .5 * (1.0 + u), .5 * (1.0 + v)
		return bright, maps.water.onface(face, u, v) / 255, maps.scene.onface(face, u, v) 
		-- return bright, 0, maps.scene.onface(face, u, v) 
	end
	
	return {
		intersect = intersect,
		lookup = lookup
	}
end


local function scene( )
	local earth = globe(earth_source)
	local stars = starmap()

	local time = {min = 0, day = 0}
	local time_radians, day_radians = 0, 0

	--[[inline int locatecubecoord(int *x, int *y, cubecoord c, earthWindow win) {
		projection screen = projector(win);
		vector normal = cubeToSphere(c, win->earth->radius);
		
		vector fromEye = VSUB(normal, screen.origin);
		if (VDOT(normal, fromEye) > 0.0) return 0;
		return unproject(x, y, screen, fromEye);
	}]]

	local function unproject(x, y, projection)
		local origin, screen = projection.origin, projection.screen
		local cellw, halfw, cellh, halfh = projection.cellw, projection.halfw, projection.cellh, projection.halfh
		local forward, right, down = screen[3], screen[1], screen[2]
		
		local facing = {0, 0, 0}
		facing[1] = forward[1] - cellw * (x - halfw) * right[1] - cellh * (y - halfh) * down[1]
		facing[2] = forward[2] - cellw * (x - halfw) * right[2] - cellh * (y - halfh) * down[2]
		facing[3] = forward[3] - cellw * (x - halfw) * right[3] - cellh * (y - halfh) * down[3]

		local x, y, z = earth.intersect(origin, facing)
		
		return x, y, z
	end

	local function plotproject(position, projection, farplane)
		local origin, screen = projection.origin, projection.screen
		local forward, right, down = screen[3], screen[1], screen[2]
		local cellw, halfw, cellh, halfh = projection.cellw, projection.halfw, projection.cellh, projection.halfh

		local position = {position[1] - origin[1], position[2] - origin[2], position[3] - origin[3]}
		local z = linear.dot(position, forward)

		if z > 0 then
			if farplane ~= nil and z > farplane then
				return
			end

			--	local x, y = dot(star.position, right) / (cellw), dot(star.position, down) / (cellh)
			local x, y = -linear.dot(position, right) / (z * cellw), -linear.dot(position, down) / (z * cellh)

			-- todo : fix hardcoded aspect ratio
			return math.floor(.5 + halfw + x), math.floor(.25 + halfh + y), z
		end
	end


	local function raytrace(term, projection, season)
		local origin, screen = projection.origin, projection.screen
		local w, h, aspect = term.getsize()
		local cellw, halfw, cellh, halfh = projection.cellw, projection.halfw, projection.cellh, projection.halfh
		local forward, right, down = screen[3], screen[1], screen[2]

		local facing = {0, 0, 0}
		for y = 0, h do
			for x = 0, w do
				facing[1] = forward[1] - cellw * (x - halfw) * right[1] - cellh * (y - halfh) * down[1]
				facing[2] = forward[2] - cellw * (x - halfw) * right[2] - cellh * (y - halfh) * down[2]
				facing[3] = forward[3] - cellw * (x - halfw) * right[3] - cellh * (y - halfh) * down[3]

				
				local bright, water, scene_number = earth.lookup(season, earth.intersect(origin, facing)) -- sun?

				if water ~= nil then
					local glyph, bg, fg
					if water > .65 or scene_number == 0 then
						if bright == 0 then
							glyph = ' '
							fg, bg = 0, 0
						else
							glyph = ':'
							--fg, bg = 12, 4
							fg, bg = 4, 0
						end
					else
						local scene = scene_types[scene_number]
						
						-- glyph, fg, bg = scene[4], scene[2], scene[3]
						-- glyph = 48 + scene_number

						if bright == 0 then
							-- nighttime
							glyph, fg, bg = scene.night[3], scene.night[1], 0
							bg = 0
						else
							glyph, fg, bg = scene.day[3], scene.day[1], 0
						end
					end
				
					term.at(x, y).bg(bg).fg(fg).put(glyph)
				end
			end
		end
	end

	local function drawstars(term, projection, season)
		local origin, screen = projection.origin, projection.screen
		local cellw, halfw, cellh, halfh = projection.cellw, projection.halfw, projection.cellh, projection.halfh
		
		-- local fake = 2 -- .5 / projection.foreshortening
		-- cellw, cellh = cellw * fake, cellh * fake

		local inverse_season = linear.invert3x3(season)
		local screen = linear.multiply3x3(screen, inverse_season)
		local forward, right, down = screen[3], screen[1], screen[2]
		
		term.bg(0)
		local dimmest = 1.25 * math.log(halfw) -- arbitrary constant 1.25 does pretty well

		for i = 1, #stars.stars do
			local star = stars.stars[i]

			if star.vmag <= dimmest then
				local z = linear.dot(star.position, forward)

				if  z > 0 then
					--	local x, y = dot(star.position, right) / (cellw), dot(star.position, down) / (cellh)
					local x, y = linear.dot(star.position, right) / (z * cellw), linear.dot(star.position, down) / (z * cellh)
					
					term.at(halfw - x, halfh - y).fg(star.color).put(star.glyph)
					--[[if star.large then
						-- term.bg(star.color).fg(star.color)
						for dy = -1, 1 do
							for dx = -1, 1 do
								term.at(x + dx, y + dy).put(star.glyph)
							end
						end
						term.bg(0)
					end]]
				end
			end
		end
	end

	local function drawmarks(term, projection, marks)
		local a = linear.mag(projection.origin) -- should include the center of the earth, too, unless we've already shifted the origin
		local ez = a - 1/a

		if type(marks) == "table" then
			for k, mark in pairs(marks) do
				if mark.position then
					local x, y, z = plotproject(mark.position, projection, ez)
					if x ~= nil then
						-- we need to allow multi-byte marks
						term.at(x, y).fg(mark.fg).bg(mark.bg).center(mark.glyph)
					end
				end
			end
		end
	end

	local function drawcursor(term, projection, beeping)
		if beeping then
			term.fg(11).bg(1)
		else
			term.fg(15).bg(0)
		end

		local x, y = math.floor(projection.halfw), math.floor(projection.halfh)
		term.at(x-1, y).put("[")
		term.at(x+1, y).put("]")
	end

	local function drawscene(term, projection, beeping)
		local w, h, aspect = term.getsize()
		local scale

		if w * aspect > h then
			scale = 1 / (aspect * w)
		else
			scale = 1 / h
		end

		scale = scale * projection.foreshortening

		local cellw, halfw = scale, w / 2
		local cellh, halfh = scale / aspect, h / 2

		-- cache these away so we can easily compute inverses
		projection.cellw, projection.halfw, projection.cellh, projection.halfh = cellw, halfw, cellh, halfh

		-- now render!
		local season = linear.identity3x3()

		-- the stars don't care about the earth's tilt (only the sun cares) -- now of course, this is only
		-- half true, but the stars are in a coordinate system that lets us 


		inplace.rotate(season[1], season[3], time_radians)
		drawstars(term, projection, season)

		inplace.rotate(season[1], season[2], (23.5 / 180.0 * math.pi))
	
		-- now add the tranform for the earth's tilt

		inplace.rotate(season[1], season[3], day_radians) -- not sure

		-- we're doing this late so there'll be one frame's lag, but who'll notice?
		-- where the hell is the sun?
		-- stars.sun.position = {season[1][1], season[1][2], season[1][3]}


		raytrace(term, projection, season)
		drawmarks(term, projection)
		drawcursor(term, projection, beeping)

		local function printmatr(x, y, m)
			for j = 1, 3 do
				for i = 1, 3 do
					local v = tostring(math.floor(1000 * m[j][i]) / 1000)
					term.fg(15).bg(0).at(x + (i-1) * 7, y + (j - 1)).print(v .. "      ")
				end
			end
		end

		--printmatr(82, 1, screen)
	end

	local function updatetime()
		-- the 11 makes our calendar start on January 1 instead of December 21
		day_radians = (((11 + time.day + time.min / 1440) / 365.25) - .5) * (2 * math.pi)
		time_radians = ((time.min + 720) * math.pi / 720) - day_radians
	end

	local function settime(min_of_day, day_of_year)
		time.min = min_of_day
		time.day = day_of_year
		updatetime()
	end

	local function advance(minutes)
		time.min = time.min + minutes
		while time.min >= 1440 do
			time.min = time.min - 1440
			time.day = time.day + 1
		end
		updatetime()
	end

	local function formattime()
		local hour, minute = math.floor(time.min / 60), math.floor(time.min % 60)
		local day, month = math.floor(time.day % 365), 0

		local monthlengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
		local monthnames = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
		
		for i = 1, #monthlengths do
			if day < monthlengths[i] then
				month = i
				day = day + 1
				break
			else
				day = day - monthlengths[i]
			end
		end

		hour = tostring(hour)
		minute = tostring(minute)
		if #hour == 1 then
			hour = "0" .. hour
		end
		if #minute == 1 then
			minute = "0" .. minute
		end

		return hour .. ":" .. minute .. " GMT " .. monthnames[month] .. " " .. day
	end

	settime(0, 0) -- midnight at greenwich, December 22
	
	return {
		draw = drawscene,
		drawmarks = drawmarks,
		settime = settime,
		advance = advance,
		formattime = formattime,
		unproject = unproject
	}
end

return scene()

