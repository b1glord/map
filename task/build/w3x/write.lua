local Path = require ('map.path')
local W3X = require ('map.file.w3x')

-- TODO: Remove this table upon release of 1.32.
local import_bytes = {
	[28] = 21,
	[31] = 29
}

return function (state)
	local map = state.settings.map.output

	Path.remove (map, true)
	do
		local directories = Path.parent (map)
		Path.create_directories (directories)
	end

	if state.settings.map.options.directory then
		Path.create_directory (map)
	end

	local environment = state.environment
	local imports = environment.imports
	environment.imports = nil
	local files = state.loaded_files
	local version = environment.information.version
	local options = {
		import_byte = import_bytes [environment.information.format]
	}

	local input = assert (W3X.open (state.settings.map.input, 'r'))
	local output = assert (W3X.open (map, 'w+', options))

	for name, unpacked in pairs (environment) do
		local path = files [name]

		-- Do not copy loaded files, as we pack their data instead.
		imports [path] = nil

		local library = require ('map.file.' .. path)
		local packed = assert (library.pack (unpacked, version))
		local file = output:open (path, 'w', #packed)
		file:write (packed)
		file:close ()
	end

	do
		assert (environment.information.is_lua)
		assert (output:add (state.settings.script.output, 'war3map.lua'))
	end

	for name, path in pairs (imports) do
		if type (name) ~= 'string' then -- luacheck: ignore 542
		elseif path == true then
			local source = assert (input:open (name))
			local destination = assert (
				output:open (name, 'w', source:seek ('end')))
			source:seek ('set')

			repeat
				local bytes = source:read (512)
			until not bytes or not destination:write (bytes)

			assert (source:close ())
			assert (destination:close ())
		else
			assert (output:add (path, name))
		end
	end

	assert (input:close ())
	assert (output:close (true))
	io.stdout:write ('Output: ', map, '\n')

	return true
end
