local Modules = require ('map.modules')
local Path = require ('map.path')
local Shell = require ('map.shell')
local String = require ('map.string')

local function write_header (output)
	assert (output:write ([[
local package = {
	loaded = {},
	preload = {}
}

function require (name) -- luacheck: globals require
	if package.loaded [name] == nil then
		local preload = package.preload [name]

		if preload == nil then
			error (string.format ("module '%s' not found: no field"
				.. " package.preload['%s']", name, name))
		end

		package.loaded [name] = preload ()
	end

	return package.loaded [name]
end

]]))
end

local function write_module (output, path, name, debug)
	local file = assert (io.open (path, 'rb'))
	local contents = String.trim (assert (file:read ('*a')), '[\r\n]+')
	file:close ()

	if debug then
		debug = debug .. (debug == '@' and path or name)
	end

	if debug then
		assert (output:write (string.format ([[
do -- %s
	package.preload [%q] = assert (load (

%q

	, %q))
end -- %s

]], name, name, contents, debug, name)))
	else
		assert (output:write (string.format ([[
do -- %s
	local _ENV = _ENV
	package.preload [%q] = function (...) -- luacheck: ignore 212
		_ENV = _ENV

%s

	end
end -- %s

]], name, name, contents, name)))
	end
end

local function write_footer (output, name)
	assert (output:write (string.format ([[
require (%q)
]], name)))
end

return function (state)
	local root = state.settings.input.source
	local modules, message = Modules.find (root)

	if not modules then
		error (message)
	end

	local names = {}

	for name in pairs (modules) do
		table.insert (names, name)
	end

	table.sort (names)

	local debug

	if state.settings.debug then
		local mode = state.settings.debug_mode or 'path'

		if mode == 'path' then
			debug = '@'
		elseif mode == 'name' then
			debug = '='
		else
			error ('invalid `debug_mode` specified')
		end
	end

	local path = state.settings.output.file .. '.lua'
	local output = assert (io.open (path, 'wb'))

	write_header (output)

	for _, name in ipairs (names) do
		write_module (output, modules [name], name, debug)
	end

	write_footer (output, root)

	output:close ()

	local status = Shell.execute {
		command = Shell.escape ('luacheck', '--default-config',
			Path.join ('map', 'luacheck', 'luacheckrc'), '--quiet', path)
	}

	if not status then
		return
	end

	io.stdout:write ('\n- ', path, '\n')

	return true
end
