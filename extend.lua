-- EXTEND RL
--[[ rl.compass = {
	W = {-1, 0},
	NW = {-1, -1},
	N = {0, -1},
	NE = {1, -1},
	E = {1, 0},
	SE = {1, 1},
	S = {0, 1},
	SW = {-1, 1}
} ]]


-- EXTEND OS
(function ()
	local exit_list = {}
	local exit = os.exit
	local gcwatch

	local function cleanup()
		if exit_list ~= nil then
			-- call atexit functions in reverse order
			for x = #exit_list, 1, -1 do
				local func = exit_list[x]
				func()
			end
			exit_list = nil
			gcwatch = nil
		end
	end

	-- catch normal exit.
	gcwatch = newproxy(true)
	getmetatable(gcwatch).__gc = cleanup

	function os.exit (...)
		cleanup()
		exit(...)
	end

	function os.atexit (fn)
		exit_list[1 + #exit_list] = fn
	end
end) () 

-- EXTEND GLOBAL

_G.printtree = function (obj, key, indent)
	indent = indent or 0
	if type(obj) == "table" then
		print (string.rep(" ", indent) .. tostring(key) .. " = {")
		for k, v in pairs(obj) do
			printtree(v, k, indent + 2)
		end
		print (string.rep(" ", indent) .. "}" .. " (" .. tostring(obj) .. ")")
	else
		print (string.rep(" ", indent) .. tostring(key) .. " = " .. tostring(obj))
	end
end


-- EXTEND TABLE
table.clone = table.clone or function (table)
	local new = { }
	for k, v in pairs(table) do new[k] = v end
	return new
end

table.deepclone = function (table)
	local copies = { }
	local function innerclone (table)
		if copies[table] ~= nil then
			return copies[table]
		else
			local new = { }
			copies[table] = new

			for k, v in pairs(table) do
				if type(k) == "table" then k = innerclone(k) end
				if type(v) == "table" then v = innerclone(v) end

				new[k] = v
			end

			return new
		end
	end
	return innerclone(table)
end

-- EXTEND STRING SPLIT
string.split = string.split or function (S, J)
	assert(type(S) == "string", "split expects a string")

	local words = { }
	local start = 1

	if type(J) ~= "string" then J = "," end

	while start < #S + 1 do
		local last = (string.find(S, J, start, true) or (#S + 1)) - 1
		words[#words + 1] = S:sub(start, last)

		start = last + 1 + #J
	end

	return words
end

-- EXTEND RANDOM
--[[random = rl.random
local random = random
random.quadratic = function(max) 
	return 1 + max - math.ceil(math.sqrt(random.uniform(max * max)))
end
random.between = function(min, max)
	if max < min then
		local swap = min
		min = max
		max = swap
	end
	return (min - 1) + random.uniform(max + 1 - min)
end
random.range = function(range)
	local index = random.uniform(#range - 1)
	return random.between(range[index], range[index + 1])
end
random.choose = function(array)
	return array[random.uniform(#array)]
end
--]]

-- EXTEND MATH

--[[
function math.rotate(theta, x, y) 
	local c, s = math.cos(theta), math.sin(theta)
	return c * x - s * y, c * y + s * x
end

local vecmt
vecmt = {
	__add = function (a, b)
		local result = { }
		if type(a) == "number" then a, b = b, a end

		if type(b) == "table" then
			local arity
			if #a < #b then arity = #a else arity = #b end
			for i = 1, arity do
				result[i] = a[i] + b[i]
			end
		else
			for i = 1, #a do
				result[i] = a[i] + b
			end
		end
		return setmetatable(result, vecmt)
	end,
	__mul = function (a, b) 
		local result = { }
		if type(a) == "number" then a, b = b, a end

		if type(b) == "table" then
			local arity
			if #a < #b then arity = #a else arity = #b end
			for i = 1, arity do
				result[i] = a[i] * b[i]
			end
		else
			for i = 1, #a do
				result[i] = a[i] * b
			end
		end
		return setmetatable(result, vecmt)
	end,
	__unm = function (a)
		local result = { }
		for i = 1, #a do
			result[i] = -a[i]
		end
		return setmetatable(result, vecmt)
	end
}
math.vector = function(v, ...)
	if type(v) == "table" then
		return setmetatable(v, vecmt)
	else
		return setmetatable({v, ...}, vecmt)
	end
end
--]]

math.sgn = function(n)
	if n > 0 then
		return 1, n
	elseif n < 0 then
		return -1, -n
	else
		return 0, 0
	end
end

-- IMPLEMENT LAYERS ?

-- ADD linear AND inplace

if type(_G.linear) ~= "table" then _G.linear = { } end
if type(_G.inplace) ~= "table" then _G.inplace = { } end

function linear.dot (a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

function inplace.rotate(v1, v2, theta)
	local s, c = math.sin(theta), math.cos(theta)
	v1[1], v1[2], v1[3],
	v2[1], v2[2], v2[3] =
	v1[1] * c + v2[1] * s, v1[2] * c + v2[2] * s, v1[3] * c + v2[3] * s,
	v2[1] * c - v1[1] * s, v2[2] * c - v1[2] * s, v2[3] * c - v1[3] * s
	return v1, v2
end

function inplace.rotatetowards(v1, v2, theta)
	-- like rotate, but only v1 changes
	local s, c = math.sin(theta), math.cos(theta)
	v1[1], v1[2], v1[3] = v1[1] * c + v2[1] * s, v1[2] * c + v2[2] * s, v1[3] * c + v2[3] * s
	return v1
end

function linear.mag(v)
	return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
end

function inplace.normalize(v)
	local mag = linear.mag(v)
	if mag > 0 then
		v[1], v[2], v[3] = v[1] / mag, v[2] / mag, v[3] / mag
		return v
	else
		return nil
	end
end

function inplace.coplanar(a, b)
	local d = -linear.dot(a, b)
	b[1], b[2], b[3] = b[1] + d * a[1], b[2] + d * a[2], b[3] + d * a[3]
	return inplace.normalize(b)
end


local abs = math.abs
function linear.tocubecoord(x, y, z)
	local mx, my, mz = abs(x), abs(y), abs(z)
	
	if mx >= my and mx >= mz then
		return x > 0 and 1 or 3, y / x, z / x
	elseif my >= mx and my >= mz then
		return y > 0 and 0 or 5, x / y, z / y
	else
		return z > 0 and 2 or 4, x / z, y / z
	end
end

function linear.scale(s, v)
	return {s * v[1], s * v[2], s * v[3]}
end

function linear.cross(a, b)
	return {a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]}
end

function linear.det3x3(A)
	local a, b, c = A[1][1], A[1][2], A[1][3]
	local d, e, f = A[2][1], A[2][2], A[2][3]
	local g, h, k = A[3][1], A[3][2], A[3][3]

	return a * (e * k - f * h) +  b * (f * g - k * d) + c * (d * h - e * g)
end

function linear.invert3x3(A)
	local a, b, c = A[1][1], A[1][2], A[1][3]
	local d, e, f = A[2][1], A[2][2], A[2][3]
	local g, h, k = A[3][1], A[3][2], A[3][3]

	local det = a * (e * k - f * h) +  b * (f * g - k * d) + c * (d * h - e * g)

	if det ~= 0 then
		return {
			{(e * k - f * h) / det, (c * h - b * k) / det, (b * f - c * e) / det},
			{(f * g - d * k) / det, (a * k - c * g) / det, (c * d - a * f) / det}, 
			{(d * h - e * g) / det, (g * b - a * h) / det, (a * e - b * d) / det}
		}
	end
end

function inplace.normalize3x3(A)
	local det = linear.det3x3(A)
	if det ~=0 then
		for j = 1, 3 do
			for i = 1, 3 do
				A[i][j] = A[i][j] / det
			end
		end
	end
end

function linear.identity3x3()
	return {
		{1, 0, 0},
		{0, 1, 0},
		{0, 0, 1}
	}
end

function linear.multiply3x3(a, b)
	local answer = {
		{0, 0, 0},
		{0, 0, 0},
		{0, 0, 0}
	}
	for i = 1, 3 do
		for j = 1, 3 do
			answer[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end

	return answer
end








-- EXTEND IMPORT
local imported = {}

local path = LUA_PATH
if type(path) ~= "string" then 
	path = os.getenv "LUA_PATH" or "./?.lua"
end

local function package_stub(name)
	return setmetatable(
		{},
		{
			__index = function(_, index)
				error(string.format(
					"member '%s' is accessed before package '%s' is fully imported",
					index, name
				))
			end,
			__newindex = function(_, index, _)
				error(string.format(
					"member '%s' is assigned a value before package '%s' is fully imported",
					index, name
				))
			end
		}
	)
end

local function locate(name)
	local message = ""
	for path in string.gfind(path, "[^;]+") do
		path = string.gsub(path, "?", name)
		local chunk, pathmessage = loadfile(path)
		if chunk then
			 return chunk, path, message
		else
			 message = message .. "\nTried " .. path .. ": " .. pathmessage
		end
	end
	return nil, path, message
end

import = import or function (name)
	local package = imported[name]  
	if package then return package end
	local chunk, path, message = locate(name)
	if not chunk then
		error(string.format(
			"could not locate (or could not run) package '%s' in '%s':" .. message,
			name, path
		))
	end
	package = package_stub(name)
	imported[name] = package
	setfenv(chunk, getfenv(2))
	chunk = chunk()
	setmetatable(package, nil)
	if type(chunk) == "function" then
		chunk(package, name, path)
	end
	return package
end

-- EXTEND LOCATELOADFILE AND LOCATEDOFILE
locateloadfile = locate

locatedofile = function (name)
	local chunk, path, message = locate(name)
	if chunk then
		return chunk( )
	else
		error(message)
	end
end

