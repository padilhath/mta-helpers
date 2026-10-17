ORM = {}
ORM.__index = ORM

function ORM.new(connection, cacheTime)
    local self = setmetatable({}, ORM)
    self.connection = connection
    self.cacheTime = cacheTime or 10000
    self.INTEGER = "INTEGER"
    self.PRIMARYKEY = "PRIMARY KEY"
    self.NOTNULL = "NOT NULL"
    self.UNIQUE = "UNIQUE"
    self.TEXT = "TEXT"
    return self
end

function ORM:define(tableName, tableData)
    local columns, columnNames = {}, {}
    local hasPrimaryKey = false

    for columnName, attributes in pairs(tableData) do
        local colDef = { columnName }
        for _, attr in ipairs(attributes) do
            table.insert(colDef, attr)
            if attr == self.PRIMARYKEY then
                hasPrimaryKey = true
            end
        end
        table.insert(columns, table.concat(colDef, " "))
        table.insert(columnNames, columnName)
    end

    if not hasPrimaryKey then
        table.insert(columns, 1, "id INTEGER PRIMARY KEY")
        table.insert(columnNames, 1, "id")
    end

    self.connection:exec(string.format("CREATE TABLE IF NOT EXISTS %s (%s)", tableName, table.concat(columns, ", ")))

    return dbTable.__new(self.connection, tableName, columnNames, self.cacheTime)
end

function ORM:query(query, ...)
    local result = self.connection:query(query, ...)
    return dbPoll(result, -1)
end

dbTable = {}
dbTable.__index = dbTable

function dbTable.__new(connection, tableName, columns, cacheTime)
    local self = setmetatable({}, dbTable)
    self.connection = connection
    self.tableName = tableName
    self.columns = columns
    self.cache = {}
    self.cacheTime = cacheTime
    return self
end

function dbTable:__where(where)
    if not where or next(where) == nil then return "", {} end

    local conditions, values = {}, {}
    for col, val in pairs(where) do
        table.insert(conditions, string.format("%s=?", col))
        table.insert(values, val)
    end

    return " WHERE " .. table.concat(conditions, " AND "), values
end

function dbTable:__setCache(key, value)
    self.cache[key] = { data = value, timestamp = getTickCount() }
end

function dbTable:__getCache(key, ttl)
    local entry = self.cache[key]
    if entry and (getTickCount() - entry.timestamp) < ttl then
        return entry.data
    end
    return nil
end

function dbTable:query(query, vals)
    return self.connection:query(query, unpack(vals or {}))
end

function dbTable:exec(query, vals)
    return self.connection:exec(query, unpack(vals or {}))
end

---@param data table
function dbTable:insert(data)
    local cols, placeholders, values = {}, {}, {}
    for col, val in pairs(data) do
        table.insert(cols, col)
        table.insert(placeholders, "?")
        table.insert(values, val)
    end

    local query = string.format(
        "INSERT INTO `%s` (%s) VALUES (%s)", self.tableName, table.concat(cols, ", "), table.concat(placeholders, ", ")
    )

    local result = self:exec(query, values)
    if result then self.cache = {} end
    return result
end

---@param dataList table
function dbTable:bulkInsert(dataList)
    if #dataList == 0 then return false end

    local cols = {}
    for col, _ in pairs(dataList[1]) do
        table.insert(cols, string.format("%s", col))
    end

    local placeholders, values = {}, {}
    for _, data in ipairs(dataList) do
        local rowPlaceholders = {}
        for _, val in pairs(data) do
            table.insert(rowPlaceholders, "?")
            table.insert(values, val)
        end
        table.insert(placeholders, "(" .. table.concat(rowPlaceholders, ", ") .. ")")
    end

    local query = string.format(
        "INSERT INTO `%s` (%s) VALUES %s", self.tableName, table.concat(cols, ", "), table.concat(placeholders, ", ")
    )
    local result = self:exec(query, values)
    if result then self.cache = {} end
    return result
end

---@param where table
---@param one boolean
---@return table
function dbTable:select(where, one)
    local whereString, whereValues = self:__where(where)
    local query = string.format(
        "SELECT * FROM `%s`%s", self.tableName, whereString
    )
    local cacheKey = string.format("%s%s", query, table.concat(whereValues, ","))
    local cachedData = self:__getCache(cacheKey, self.cacheTime)
    if cachedData then
        if one then
            cachedData = cachedData[1]
        end
        return cachedData
    else
        local result = dbPoll(self:query(query, whereValues), -1)
        self:__setCache(cacheKey, result)
        if result and next(result) and one then
            result = result[1]
        end
        return result ---@type table
    end
end

---@param data table
---@param where table
function dbTable:update(data, where)
    local updates, values = {}, {}
    for col, val in pairs(data) do
        table.insert(updates, string.format("%s=?", col))
        table.insert(values, val)
    end

    local whereString, whereValues = self:__where(where)
    for _, v in ipairs(whereValues) do
        table.insert(values, v)
    end

    local query = string.format(
        "UPDATE `%s` SET %s%s", self.tableName, table.concat(updates, ", "), whereString
    )
    local result = self:exec(query, values)
    if result then self.cache = {} end
    return result
end

---@param where table
function dbTable:delete(where)
    local whereString, whereValues = self:__where(where)
    local query = string.format("DELETE FROM `%s`%s", self.tableName, whereString)

    local result = self:exec(query, whereValues)
    if result then self.cache = {} end
    return result
end
