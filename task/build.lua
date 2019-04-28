local Tasks = require ('map.tasks')

return function (state)
	local tasks = {
		'check',
		'build.environment',
		'build.w3x.read',
		'build.inline-strings',
		'build.user-files',
		'build.script',
		'build.w3x.write'
	}

	Tasks.add (state, tasks)

	return true
end
