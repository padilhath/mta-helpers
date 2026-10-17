--- @param player player
--- @param aclGroupName string
--- @return boolean
--- @throws Error if `aclGroupName` is not a string or the ACL group is not found.
function isPlayerInACLGroup(player, aclGroupName)
	assert(
		isElement(player) and getElementType(player) == "player",
		string.format("Bad argument @ isPlayerInAcl 'player' [Expected player, got %s]", type(player))
	)

	assert(
		type(aclGroupName) == "string",
		string.format("Bad argument @ isPlayerInAcl 'aclGroupName' [Expected string, got %s]", type(aclGroupName))
	)

	local group = aclGetGroup(aclGroupName)
	assert(
		type(group) == "userdata",
		string.format("Bad argument @ isPlayerInAcl 'aclGroupName' [ACL group '%s' not found]", aclGroupName)
	)

	local isPlayerInAcl = isObjectInACLGroup("user." .. getAccountName(getPlayerAccount(player)), group)
	if isPlayerInAcl then
		return true
	else
		return false
	end
end

---@param groupName string
---@param groupNameBy "ACL"|"GROUP"
---@param player player
---@return boolean
function playerHavePermission(player, groupName, groupNameBy)
	if isPlayerInACLGroup(player, "Admin") then
		return true
	elseif groupNameBy == "GROUP" and exports["cstrike_groups"]:getPlayerGroup(player) == groupName then
		return true
	elseif groupNameBy == "ACL" and isPlayerInACLGroup(player, groupName) then
		return true
	end
	return false
end

function updatePlayerData(player, data, value)
	if not getElementData(player, "logedin") then
		return
	end

	if type(value) == "boolean" then
		setElementData(player, data, value)
	end

	local current = getElementData(player, data) or 0

	if type(current) == "boolean" then
		setElementData(player, data, value)
	end

	if data == "hunger" or data == "thirst" then
		if current + value > 100 then
			setElementData(player, data, 100)
		elseif current + value < 1 then
			setElementData(player, data, 0)
			updatePlayerData(player, "blood", math.random(-250, 0))
		else
			setElementData(player, data, current + value)
		end
	elseif data == "blood" then
		if current + value > 12000 then
			setElementData(player, data, 12000)
		else
			setElementData(player, data, current + value)
		end
	elseif data == "temperature" then
		if current + value > 41 then
			setElementData(player, data, 41)
		elseif current + value <= 31 then
			setElementData(player, data, 31)
		else
			setElementData(player, data, current + value)
		end
	elseif data == "bleeding" then
		if current + value <= 0 then
			setElementData(player, data, 0)
		else
			setElementData(player, data, current + value)
		end
	else
		setElementData(player, data, current + value)
	end
end

function updateElementData(element, data, value)
	if type(value) == "boolean" then
		setElementData(element, data, value)
		return
	end

	local current = getElementData(element, data) or 0
	setElementData(element, data, current + value)
end

function elementHave(element, itemName, qnt)
	if getElementData(element, itemName) and getElementData(element, itemName) >= qnt then
		return true
	else
		return false
	end
end

function table.random(tbl)
	return tbl[math.random(1, #tbl)]
end

function table.contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

function math.percentChance(percent, repeatTime)
	local hits = 0
	for _ = 1, repeatTime do
		if math.random() < percent then
			hits = hits + 1
		end
	end
	return hits
end

---@param self string
function string:stripHexColorCodes()
	return self:gsub("#%x%x%x%x%x%x", "")
end

function table.th(...)
	local temp = {}
	local tables = { ... } -- Armazena todas as tabelas passadas como argumentos

	-- Itera sobre cada tabela
	for _, t in ipairs(tables) do
		-- Adiciona os elementos da tabela atual à tabela temp
		for i = 1, #t do
			temp[#temp + 1] = t[i]
		end
	end

	return temp
end

function isTestServer()
	if
		string.find(getServerConfigSetting("servername") --[[@as string]], "TEST")
	then
		return true
	else
		return false
	end
end

function doForAllLogedinPlayers(fun)
	for _, player in ipairs(getElementsByType("player")) do
		if not getElementData(player, "logedin") then
			return
		end

		fun(player)
	end
end

function doForAllPlayers(fun)
	for _, player in ipairs(getElementsByType("player")) do
		fun(player)
	end
end

---@param element element
---@param data string
---@param parentType elementTypeAutoComplete
---@return colshape|false
function getElementParentElement(element, parentType)
	local returnElement
	for _, v in ipairs(getAttachedElements(element)) do
		if getElementType(v) == parentType then
			returnElement = v
		end
	end

	if not returnElement then
		returnElement = getElementAttachedTo(element)
	end

	return returnElement
end

function newRngItems(itensList, value)
	local returnTable = {}

	-- cria lista de chaves
	local keys = {}
	for k in pairs(itensList) do
		table.insert(keys, k)
	end

	while value > 0 do
		-- cria lista de itens que cabem no value atual
		local possibleItems = {}
		for _, item in ipairs(keys) do
			if itensList[item] <= value then
				table.insert(possibleItems, item)
			end
		end

		-- se não há mais itens possíveis, para
		if #possibleItems == 0 then
			break
		end

		-- seleciona aleatoriamente entre os que cabem
		local selectedItem = possibleItems[math.random(#possibleItems)]
		local itemValue = itensList[selectedItem]

		value = value - itemValue
		returnTable[selectedItem] = (returnTable[selectedItem] or 0) + 1
	end

	return returnTable
end

function getNearestElement(player, type, distance)
	if not player then
		return false
	end
	if not isElement(player) then
		return false
	end

	local pX, pY, pZ = getElementPosition(player)
	local pInterior = getElementInterior(player)
	local pDimension = getElementDimension(player)

	local result, dist
	local elements = getElementsWithinRange(pX, pY, pZ, distance, type, pInterior, pDimension)
	for _, element in ipairs(elements) do
		if element ~= player then
			local x1, y1, z1 = getElementPosition(player)
			local x2, y2, z2 = getElementPosition(element)

			if not dist then
				dist = getDistanceBetweenPoints3D(x1, y1, z1, x2, y2, z2)
				result = element
			else
				local newDist = getDistanceBetweenPoints3D(x1, y1, z1, x2, y2, z2)
				if newDist <= dist then
					dist = newDist
					result = element
				end
			end
		end
	end
	return result
end
