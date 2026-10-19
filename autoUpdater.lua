local REPOSITORY = "https://raw.githubusercontent.com/padilhath/mta-helpers/main/"

-- [caminho remoto] = [caminho local]
local FILES = {
	["autoUpdater.lua"] = "lib/autoUpdater.lua",
	["helpers.lua"] = "lib/helpers.lua",
}

addEventHandler("onResourceStart", resourceRoot, function()
	for remotePath, localPath in pairs(FILES) do
		local URL = REPOSITORY .. remotePath

		fetchRemote(URL, function(content, errorCode)
			if errorCode ~= 0 or type(content) ~= "string" then
				return
			end

			if fileExists(localPath) then
				fileDelete(localPath)
			end

			local file = fileCreate(localPath)
			if file then
				fileWrite(file, content)
				fileClose(file)
			end
		end)
	end
end)
