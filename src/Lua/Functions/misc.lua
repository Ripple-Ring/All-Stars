
local storedFiles = {}

-- dofile
-- but it stores stuff
---@param file string
---@return ...any
function Squigglepants.dofile(file)
    if not storedFiles[file] then
        storedFiles[file] = {dofile(file)}
    end

    if type(storedFiles[file]) == "table" then
        return unpack(storedFiles[file])
    end
    return (storedFiles[file])
end

---returns a copy of table `t`
---@param t table
---@return table
function Squigglepants.copy(t)
    local copy = {}
    for key, val in pairs(t) do
        if type(val) == "table" then
            copy[key] = Squigglepants.copy(val)
        else
            copy[key] = val
        end
    end
    return copy
end

---returns if value `val` is in table `t`
---@param t table
---@param val any
---@return boolean
function Squigglepants.find(t, val)
    for _, tval in pairs(t) do
        if tval == val then
            return true
        end
    end
    return false
end

function Squigglepants.sortTied(t, sortFunc, valFunc)
    local canSort = (type(sortFunc) == "function")
    if canSort then
        table.sort(t, sortFunc)
    end
    
    local newTable = {}
    local valList = {}
    for _, val in ipairs(t) do
        local trueVal = val
        if type(valFunc) == "function" then
            local newVal = valFunc(val)
            if newVal ~= nil then
                trueVal = valFunc(val)
            end
        end

        if valList[trueVal] then
            valList[trueVal][#valList[trueVal]+1] = val
        else
            table.insert(newTable, {val})
            valList[trueVal] = newTable[#newTable]
        end
    end
    
    return newTable
end

--- S_ChangeMusic, but it takes alt musics into account 😱😱😱😱<br>
--- also returns the musicname back, so u can change mapmusname properly if u want to
---@param musicname string
---@param looping boolean?
---@param player player_t?
---@param mflags integer?
---@param position integer?
---@param prefadems integer?
---@param fadeinms integer?
function Squigglepants.changeMusic(musicname, looping, player, mflags, position, prefadems, fadeinms)
    if Squigglepants.altMusic[musicname]
    and P_RandomChance(FU/10) then
        if type(Squigglepants.altMusic[musicname]) == "table" then
            local musicnum = P_RandomRange(1, #Squigglepants.altMusic[musicname])
            musicname = Squigglepants.altMusic[musicname][musicnum] or $
        else
            musicname = Squigglepants.altMusic[musicname]
        end
    end

    S_ChangeMusic(musicname, looping, player, mflags, position, prefadems, fadeinms)

    return musicname
end