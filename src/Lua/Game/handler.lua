
-- handles Squigglepants' true basics
-- yeyeyeyeh -pac

addHook("MapChange", function()
    Squigglepants.sync.gamestate = SST_NONE
    Squigglepants.sync.inttime = 0
    for p in players.iterate do
        p.squigglepants = nil
    end

    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then
        return
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype?
    if gtDef then
        gtDef:setup()
    end
end)

addHook("MapLoad", function()
    if gametype ~= GT_SQUIGGLEPANTS
    or not Squigglepants.sync.gametype then
        return
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype?
    if gtDef then
        gtDef:onload()
    end
end)

local function genSquigglepants()
    return {
        vote = {
            selX = 1,
            selY = 1,
            selected = false,
            lastcmd = {
                forwardmove = 0,
                sidemove = 0,
                buttons = 0
            }
        },
        cmd = {
            forwardmove = 0,
            sidemove = 0,
            buttons = 0
        }
    }
end

---@class player_t -- just so it autocompletes :D
local autocompleteifitwascool = {squigglepants = genSquigglepants()}

addHook("ThinkFrame", function()
    if gametype ~= GT_SQUIGGLEPANTS then return end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype
    if not gtDef then
        return
    end

    ---@param p player_t
    for p in players.iterate do
        if p.squigglepants == nil then
            p.squigglepants = genSquigglepants()
        end
    end

    if not gtDef.hasIntermission
    and Squigglepants.sync.gamestate == SST_INTERMISSION then
        Squigglepants.sync.gamestate = SST_VOTE
    end

    if Squigglepants.sync.gamestate ~= SST_NONE then
        if consoleplayer then
            local showhud = CV_FindVar("showhud")

            if showhud.value == 0 then
                CV_StealthSet(showhud, 1)
            end
        end
    end
end)