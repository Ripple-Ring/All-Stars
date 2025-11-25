
local function emptyFunc() end

---@class SquigglepantsGametype_placement: table
---@field comparison function The same as `table.sort`'s `comp` argument.
---@field value function<player_t>? The value ties are handled with. Should return a value, preferably part of the player's userdata.

---@class SquigglepantsGametype: table
local gametypeDefault = {
    name = "UNDEFINED", ---@type string The gametype's name, shows up on the Player List & Voting Screen.
    identifier = "UNDEFINED", ---@type string The gametype's identifier, "spongebob" would make it so the gametype is identified as SGT_SPONGEBOB code-wise.
    description = nil, ---@type string? The gametype's description, shows up on the Voting Screen.
    color = SKINCOLOR_NONE, ---@type integer? The gametype name's color, active on the Player List & Voting Screen.
    typeoflevel = TOL_COOP|TOL_SQUIGGLEPANTS, ---@type integer? The gametype's TOL_ flags, chooses which type of levels the mode accepts :P
    blacklist = emptyFunc, ---@type function? Map blacklist for this gametype.

    thinker = emptyFunc, ---@type function? ThinkFrame, but only when the gametype is active.<br>- Function has a self argument, representing the gametype's definition.
    preThink = emptyFunc, ---@type function? PreThinkFrame, but only when the gametype is active.<br>- Function has a self argument, representing the gametype's definition.
    playerThink = emptyFunc, ---@type function? PlayerThink, but only when the gametype is active.<br>- Function has a self argument, representing the gametype's definition.
    setup = emptyFunc, ---@type function? MapChange, but only when the gametype is active.<br>- Function has a self argument, representing the gametype's definition.
    onload = emptyFunc, ---@type function? MapLoad, but only when the gametype is active.<br>- Function has a self argument, representing the gametype's definition.
    onend = emptyFunc, ---@type function? Triggered on end of mode, so when intermission / voting starts.<br>- Function has a self argument, representing the gametype's definition.

    gameHUD = emptyFunc, ---@type function? A normal "game" type HUD hook, but only when the gametype is active.<br><br>Check the [wiki's page](https://wiki.srb2.org/wiki/Lua/Functions#HUD_hooks) for more information..<br>- Function has a self argument, representing the gametype's definition.
    placement = nil, ---@type SquigglepantsGametype_placement?
    hasIntermission = nil ---@type boolean? Does this mode have an intermission? Automatically set based on if there's an intermission HUD set or not.
}
-- table with all the gametypes added. <br>
-- not recommended to directly modify this, but do whatever u want
Squigglepants.gametypes = {} ---@type table<SquigglepantsGametype>

local gtMeta = {
    __index = gametypeDefault
}

registerMetatable(gtMeta)

--- adds a gametype; allows for custom variables as global per-gametype vars.
---@param definition SquigglepantsGametype
function Squigglepants.addGametype(definition)
    if type(definition) ~= "table" then
        error("wheres the definition", 2)
        return
    end

    if type(definition.name) ~= "string"
    or type(definition.identifier) ~= "string" then
        error("Oops! It seems you've forgotten to specify some of the arguments!", 2)
        return
    end

    local idName = "SGT_" + definition.identifier:upper()
    local idNum = #Squigglepants.gametypes + 1
    if _G[idName] ~= nil then
        idNum = _G[idName]
    else
        rawset(_G, idName, idNum)
    end

    local hasIntermission = type(definition.placement) == "table"
    
    setmetatable(definition, gtMeta)
    local defMeta = {
        __index = definition
    }
    registerMetatable(defMeta)

    local gtTable = setmetatable({}, defMeta)
    gtTable.hasIntermission = hasIntermission
    
    Squigglepants.gametypes[idNum] = gtTable
end

--- gets a gametype's identifier by gametype name; name is case-sensitive. <br>
--- not recommended as it may cause resynchs if multiple gametypes have the same name.
---@param name string
---@return SquigglepantsGametype?
function Squigglepants.getGametypeDef(name)
    if type(name) ~= "string" then
        error("Oops! It seems you've forgotten to specify a name!", 2)
        return
    end

    for _, value in ipairs(Squigglepants.gametypes) do
        if type(value) == "table"
        and value.name == name then
            return value
        end
    end
end

addHook("ThinkFrame", function()
    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then
        return
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype
    if not gtDef then
        return
    end

    if Squigglepants.sync.gamestate == SST_NONE then
        gtDef:thinker()
    end
end)

addHook("PreThinkFrame", function()
    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then
        return
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype
    if not gtDef then
        return
    end

    if Squigglepants.sync.gamestate == SST_NONE then
        gtDef:preThink()
    end
end)


---@param p player_t
addHook("PlayerThink", function(p)
    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then
        return
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype
    if not gtDef then
        return
    end

    if Squigglepants.sync.gamestate == SST_NONE then
        gtDef:playerThink(p)
    end
end)

local voteHUD, rouletteHUD = Squigglepants.dofile("Game/voting.lua") ---@type function, function

-- handle intermission/vote HUD stuff
customhud.SetupItem("Squigglepants_Intermission", "Squigglepants", function(v)
    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then return end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype?
    if not gtDef then return end

    local gamestate = Squigglepants.sync.gamestate

    if gamestate == SST_INTERMISSION then
        gtDef:intermission(v)
    elseif gamestate == SST_VOTE then
        voteHUD(v)
    elseif gamestate == SST_ROULETTE then
        rouletteHUD(v)
    end
end, "gameandscores")

-- handle gametype HUD stuff
customhud.SetupItem("Squigglepants_Main", "Squigglepants", function(v, ...)
    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then return end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype?
    if not gtDef then return end

    local gamestate = Squigglepants.sync.gamestate

    if gamestate == SST_NONE then
        gtDef:gameHUD(v, ...)
    end
end, "game")