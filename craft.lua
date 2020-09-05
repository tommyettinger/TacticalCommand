
-- rendering is handled by earth.lua, which is also how the marks from craft are added
-- but the rest of ship-based logic goes on here -- even the stuff that makes assumptions
-- about the earth and its geometry (namely its roundness)

-- this source file will handle all craft and missile AI until it becomes unwieldy


local circumference = 24901.55 -- miles
local radius = circumference / (2 * math.pi)

local mph = 1 / radius
local mach = 761.2 / radius

local yours, theirs = {}, {}

local mobs = {
	{glyph = "a", name = "Interceptor 1", fg = 15, bg = 4, position = {0, -1, 0}, heading = {1, 0, 1}, speed = 600 * mph, dta = 0, eta = 0, cantarget = true, team = yours},
	{glyph = "b", name = "Interceptor 2", fg = 15, bg = 4, position = {0, -1, 0}, heading = {1, 0, 1}, speed = 600 * mph, dta = 0, eta = 0, cantarget = true, team = yours},
	-- {glyph = "c", name = "UFO 3", fg = 11, bg = 1, position = {1, 0, 0}, heading = {0, 1, 0}, speed = mach * 2, dta = 0, eta = 0, cantarget = true}

	--[[{glyph = "a", name = "UFO 1", fg = 11, bg = 1, position = {0, 0, 1}, heading = {0, 1, 0}, speed = mach * 2, dta = 0, eta = 0, cantarget = true},
	{glyph = "b", name = "UFO 2", fg = 11, bg = 1, position = {0, 1, 0}, heading = {0, 1, 0}, speed = mach * 2, dta = 0, eta = 0, cantarget = true},
	{glyph = "c", name = "UFO 3", fg = 11, bg = 1, position = {1, 0, 0}, heading = {0, 1, 0}, speed = mach * 2, dta = 0, eta = 0, cantarget = true}]]
}

local friend, foe, missile = { }, { }, { }
local reports, friendlytargets, targetmarks = { }, { }, { }
local function uniformrandomspherical( )
	local magnitude, x, y, z
	repeat
		x, y, z = 2 * (math.random() - .5), 2 * (math.random() - .5), 2 * (math.random() - .5)
		magnitude = x * x + y * y + z * z
	until magnitude <= 1
	magnitude = math.sqrt(magnitude)
	return x / magnitude, y / magnitude, z / magnitude
end

for i = 1, 26 do
	reports[1 + #reports] = {
		glyph = string.char(string.byte("a") + i - 1),
		name = "Report " .. i,
		fg = 14, bg = 6,
		position = {uniformrandomspherical()}
	}
end

for i, v in pairs(mobs) do
	if v.team == yours then
		friend[v.glyph] = v
		v.targetmark = {glyph = v.glyph, fg = 0, bg = 7}
		targetmarks[v] = v.targetmark
	else
		foe[v.glyph] = v
	end
end

local function advanceship(ship, dt)
	if ship.speed == nil then
		return
	end

	-- target and distance are already chosen and evaluated
	local position, heading, target, distance = ship.position, ship.heading, ship.target, ship.distance
	
	local dx = dt * ship.speed

	if target ~= nil then
		target = target.position
		if dx >= 0 then
			if distance <= dx then
				position[1], position[2], position[3] = target[1], target[2], target[3]
				distance = 0
			else
				-- inplace.rotatetowards(position, linear.cross(target), math.pi * dx / distance)
				-- heading[1], heading[2], heading[3] = target[1] - position[1], target[2] - position[2], target[3] - position[3]
				heading[1], heading[2], heading[3] = target[1], target[2], target[3]
				inplace.coplanar(position, heading)
				inplace.rotatetowards(position, heading, dx)

				-- inplace.normalize(position)
			
				-- local lineardx = dx -- math.sin(dx) / math.cos(dx)
				--[[position[1], position[2], position[3] =
				position[1] + lineardx * heading[1],
				position[2] + lineardx * heading[2],
				position[3] + lineardx * heading[3]]

				-- inplace.normalize(position)
				
				distance = distance - dx
			end
		end
		
		ship.distance = distance
		ship.dta = distance * radius
		ship.eta = distance / ship.speed
	else
		ship.eta = 0
		ship.dta = 0
		ship.distance = 0
	end


	-- with a heading but no target, like so
	--[[
		-- heading[1], heading[2], heading[3] = target[1] - position[1], target[2] - position[2], target[3] - position[3]

	local offcourse = linear.dot(heading, position)
	heading[1], heading[2], heading[3] = heading[1] - position[1] * offcourse, heading[2] - position[2] * offcourse, heading[3] - position[3] * offcourse
	inplace.normalize(heading)
	
	position[1], position[2], position[3] = position[1] + heading[1] * dx, position[2] + heading[2] * dx, position[3] + heading[3] * dx
	inplace.normalize(position)

	-- for the tracking code; lots of extra work when it's not really used
	local offcourse = linear.dot(heading, position)
	heading[1], heading[2], heading[3] = heading[1] - position[1] * offcourse, heading[2] - position[2] * offcourse, heading[3] - position[3] * offcourse
	inplace.normalize(heading)
	]]--
end

local function advanceall(minutes)
	local dt = minutes / 60
	for i = 1, #mobs do
		-- update target and dta -- things can move, eh?
		local ship = mobs[i]
		
		local position, heading, target = ship.position, ship.heading, nil
		
		target = friendlytargets[ship]
		
		local distance
		if target ~= nil then
			local cosdistance = linear.dot(position, target.position)

			if cosdistance >= 1 then
				distance = 0
				target = nil
				ship.targetmark.position = nil
			else
				ship.targetmark.position = target.position
				distance = math.acos(cosdistance)
			end

		else
			ship.targetmark.position = nil
		end

		ship.target, ship.distance = target, distance
	end

	for i = 1, #mobs do
		-- this is silly, of course, but an experiment only, and it works rather well, considering
		local ship = mobs[i]
		advanceship(ship, dt)
	end
end

local function infocard(term, ship, responsetime)
	local function dhm(time)
		local hours = math.floor(ship.eta)
		local minutes = tostring(math.floor((ship.eta * 60) % 60))
		if #minutes == 1 then
			minutes = "0" .. minutes
		end
		return hours .. ":" .. minutes
	end
	
	local urgent, inactive = false, false
	if ship.eta == nil or ship.eta == 0 then
		inactive = true
	elseif 60 * ship.eta <= responsetime then
		urgent = true
	end

	term.at(0).fg(ship.fg).bg(ship.bg).put(ship.glyph)

	if not ship.isselected then
		term.fg(7).bg(0)
	end

	term.skip(1).print(ship.name)

	if ship.eta ~= nil and ship.eta > 0 then
		term.bg(0).skip(1)
		if urgent then
			term.fg(11).bg(1)
		elseif inactive then
			term.fg(7).bg(0)
		else
			term.fg(7).bg(0)
		end
		term.print("ETA: " .. dhm(ship.eta) .. " (" .. math.ceil(ship.dta) .. " mi)" )
	end

	term.cr()
end


local function target(ship, destination)
	friendlytargets[ship] = destination
end

return {
	advance = advanceall,
	friend = friend,
	foe = foe,
	targetmarks = targetmarks,
	reports = reports,

	target = target,
	infocard = infocard
}


