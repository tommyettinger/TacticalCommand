local earth = locatedofile("earth")
local craft = locatedofile("craft")
local battlemode = locatedofile("battle-main")
local basemode = locatedofile("base")

local term = locatedofile("curses")

-- duplicated in tact
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

-- Muroc, Office of Special Investigations
term.settitle "Tactical Command"

local function geoscape(term)
	-- geoscape mode:

	local marks = { }
	local screen = linear.identity3x3()
	local selected, selectiontype = nil, nil
	local tracking = false

	local command = nil
	local origin = {0, 0, 0}
	
	local hasquit = false

	local projection = {
		screen = screen,
		origin = origin,
		foreshortening = 1/2 -- the viewing angle from the camera's perspective -- the smaller this is, the smaller (and more zoomed in) a space is drawn
	}

	local view = {
		friendly = true,
		targets = true,
		enemy = true,
		reports = false,
		marks = true
	}

	local radius = 1
	local hardmin, hardmax = (-1 + -0.05 / projection.foreshortening) * radius, (-2 / projection.foreshortening) * radius
	local zoomrate = .40
	local altitude = hardmax

	local time = 0

	local orient = false
	local rate, paused = 1, true
	local reaction = 0
	local autotrack = false

	local beeping = false

	local function beep()
		beeping = 7
	end

	local function getselector(key)
		if key == nil then
			key = term.getch( )
		end

		-- targets
		local markset, selectiontype = nil, nil
		if key == "f" then
			markset = craft.friend
			selectiontype = "craft"
		end
		if key == "e" then
			markset = craft.foe
			selectiontype = "enemy"
		end
		if key == "w" then
			markset = craft.marks
			selectiontype = "waypoint" -- ?
		end

		if markset ~= nil then
			key = term.getch( )
			
			local mark = markset[key]
			if mark ~= nil then
				if selectiontype == "target" then
					mark = mark.target
				end
				return mark, selectiontype
			else
				beep()
			end
		end
	end

	local function emit_target(target)
		if target ~= nil then
			-- what shall we do with it?
			if command == nil then
				-- treat it as a selection command
				if not target.autotarget then
					selected, selectiontype = target, cmd
				else
					if selected then
						craft.target(selected, target)
					else
						beep()
					end
				end
			else
				-- target is the only command for now
				if selected then
					craft.target(selected, target)
				end
				command = nil
			end
		end
	end

	local function emit_command(newcmd)
		-- does the command make any sense right now?
		if command == nil then
			command = newcmd
		else
			command = nil
			beep()
		end
	end

	local function interactiveinput()
		local key, code = term.nbgetch()
		-- playerturn(player, key)

		if key == "Q" then
			hasquit = true
			return
		end

		-- rotinplace(screen[1], screen[2], .01)
		-- local screen, origin = projection.screen, projection.origin
		if key ~= nil then

			local lowerkey = string.lower(key)
			local dir = compass[lowerkey]
			local radius = 1.00
			
			if dir ~= nil then
				local speed, hstep, vstep = 0, 6, 3 -- todo: fix hardcoded aspect ratio
				
				if key >= "A" and key <= "Z" then
					hstep = projection.halfw - 1
					vstep = projection.halfh - 1
				end

				
				local x, y, z = earth.unproject(projection.halfw + (hstep * dir[1]), projection.halfh + (vstep * dir[2]), projection)

				if x == nil then
					-- too big, so turn to the horizon
					speed = math.acos(radius / (-altitude + radius))
				else
					speed = math.acos(-linear.dot(projection.screen[3], {x, y, z}))
				end

				-- this sequence of rotations guarantees that diagonals invert properly --
				if dir[1] == -1 then inplace.rotate(screen[1], screen[3], speed) end
				if dir[2] == -1 then inplace.rotate(screen[2], screen[3], speed) end

				if dir[2] == 1 then inplace.rotate(screen[2], screen[3], -speed) end
				if dir[1] == 1 then inplace.rotate(screen[1], screen[3], -speed) end
				
				tracking = false
			elseif lowerkey == "s" or lowerkey == "d" then
				
				-- zoom control
				local softmin = .8 * hardmin
				local zoomrate = 1 + zoomrate
				
				if lowerkey == "d" then altitude = softmin + (altitude - softmin) / zoomrate end
				if lowerkey == "s" then altitude = softmin + (altitude - softmin) * zoomrate end
				
				if altitude > hardmin or key == "D" then
					altitude = hardmin
				end
				if altitude < hardmax or key == "S" then
					altitude = hardmax
				end
			end

			-- orientation control
			if key == "[" then inplace.rotate(screen[1], screen[2], .4) end
			if key == "]" then inplace.rotate(screen[1], screen[2], -.4) end
			if key == "o" then orient = true end

			-- if key == "1" then rate, unpauserate = 0, rate + unpauserate end
			if key == "1" then rate = .25, 0 end -- fifteen seconds at an interval
			if key == "2" then rate = 1, 0 end
			if key == "3" then rate = 5, 0 end
			if key == "4" then rate = 60, 0 end
			if key == "5" then rate = 24 * 60, 0 end
			if key == "p" then paused = not paused end
			-- if key == "P" then singlestep, rate, unpauserate = rate + unpauserate, 0, rate + unpauserate end
			
			-- marks
			if key == "m" then
				local markname = term.getch()
				if (markname >= "a" and markname <= "z") or (markname >= "A" and markname <= "Z") then
					local mark = {
						screen = table.deepclone(screen),
						altitude = altitude,
						position = {-screen[3][1], -screen[3][2], -screen[3][3]},
						fg = 0, bg = 7, glyph = markname
					}
					marks[markname] = mark
				end
			end
			if key == "'" or key == "`" then
				local markname = term.getch()
				local mark = marks[markname]
				if mark ~= nil then
					screen = table.deepclone(mark.screen)
					projection.screen = screen

					if key == "`" then
						altitude = mark.altitude
					end
					orient = false
				end
			end

			if key == "%" then
				battlemode.focus(term)
				paused = true
			end
			if key == "^" then
				basemode().focus(term)
				local key = term.getch()
				paused = true
			end

			if key == "t" then
				emit_command("target")
			end

			if key == "f" or key == "e" or key == "d" or key == "w" then
				emit_target(getselector(key))
			end

			if selected ~= nil then
				if key == "z" then
					tracking = 1
				end
				
				if key == "T" then
					if selected and selected.target then
						selected = selected.target
						tracking = 1
					end
				end

				if key == "Z" then
					tracking = true
				end

				if key == "g" then
					key = term.getch()
				end

				if key == "C" then
					autotrack = true
				end

				if autotrack or key == "c" then
					-- should verify that this kind of thing can take a target
					emit_target {
						waypoint = true,
						autotarget = true,
						position = linear.scale(-1, screen[3]),
						screen = table.deepclone(screen)
					}
				end
			end
		end
	end

	repeat
		-- rotinplace(screen[1], screen[3], .001)
		interactiveinput()

		if orient then
			local angle = -math.atan2(screen[1][2], screen[2][2])
			if angle > .3 then
				angle = .3
			elseif angle < -.3 then
				angle = -.3
			else
				orient = false
			end
			inplace.rotate(screen[1], screen[2], angle)
		end

		if tracking then
			if selected then
				screen[3] = linear.scale(-1, selected.position)
				screen[2] = inplace.coplanar(screen[3], {0, 1, 0}) or {1, 0, 0}
				-- screen[2] = inplace.coplanar(screen[3], linear.scale(1, screen[2]))
				screen[1] = linear.cross(screen[2], screen[3])
			else
				tracking = nil
			end
			if type(tracking) == "number" then
				tracking = tracking - 1
				if tracking == 0 then
					tracking = nil
				end
			end
		end
		
		origin[1], origin[2], origin[3] = altitude * screen[3][1], altitude * screen[3][2], altitude * screen[3][3]
		-- origin[1], origin[2], origin[3] = -altitude * screen[3][1], -altitude * screen[3][2], -altitude * screen[3][3] -- stargazing

		term.erase()
		term.clip(0, 0, nil, nil, "square")
		earth.draw(term, projection, beeping)

		if view.marks then
			earth.drawmarks(term, projection, marks)
		end
		if view.reports then
			earth.drawmarks(term, projection, craft.reports)
		end
		if view.targets then
			earth.drawmarks(term, projection, craft.targetmarks)
		end
		if view.friendly then
			earth.drawmarks(term, projection, craft.friend)
		end
		if view.enemy then
			earth.drawmarks(term, projection, craft.foe)
		end

		term.fg(15).bg(0).at(1, 1).print(earth.formattime())

		if type(beeping) == "number" then
			beeping = beeping - 1
			if beeping < 1 then
				beeping = false
			end
		end

		-- and change the ship's target on a whim
		-- ships[1].target[1], ships[1].target[2], ships[1].target[3] = -projection.screen[3][1], -projection.screen[3][2], -projection.screen[3][3]
		
		local w, h = term.getsize() -- current "square" terminal
		term.clip(w, 0, nil, nil)

		reaction = 30 + rate * 15

		if selected then
			selected.isselected = true
		end
		
		term.at(0).fg(15).bg(0).print("FPS: " .. term.tcod.TCOD_sys_get_fps() .. "; FRIENDLIES:").cr()
		for i, v in pairs(craft.friend) do 
			craft.infocard(term, v, reaction)
		end

		term.cr()
		-- term.at(0).fg(15).bg(0).print "ENEMY CRAFT".cr()
		for i, v in pairs(craft.foe) do 
			craft.infocard(term, v, reaction)
		end

		if selected then
			selected.isselected = false
		end
		
		term.clip()

		if command == nil and not paused then
			earth.advance(rate)
			craft.advance(rate)
		else
			-- this is crummy
			earth.advance(0)
			craft.advance(0)
		end

		term.refresh()
		term.napms(15)
	until hasquit
end

geoscape(term)



term.erase()
term.refresh()
term.endwin()

