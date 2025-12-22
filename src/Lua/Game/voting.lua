
-- handles voting stuff
-- duh
-- returns the voting screen's HUD stuff :P

local hook = Squigglepants.Hooks

local inttime = CV_FindVar("inttime")
local roulettetime = 10 * TICRATE
local fadeTime = 2*TICRATE

sfxinfo[freeslot("sfx_kirlon")].caption = "you win!!!"
sfxinfo[freeslot("sfx_kirsho")].caption = "you tried"

---Gets a random map. Capable of blacklisting maps & gamemodes
---@param map_blacklist function?
---@param mode_blacklist function?
---@return integer, integer
function Squigglepants.getRandomMap(map_blacklist, mode_blacklist)
    local mapnum, modenum

    while modenum == nil
    or type(mode_blacklist) == "function" and mode_blacklist(modenum) do
        modenum = P_RandomRange(1, #Squigglepants.gametypes)
    end

    while mapnum == nil
    or not mapheaderinfo[mapnum]
    or not (mapheaderinfo[mapnum].typeoflevel & Squigglepants.gametypes[modenum].typeoflevel)
    or type(map_blacklist) == "function" and map_blacklist(mapnum)
    or Squigglepants.gametypes[modenum]:blacklist(mapnum) do
        mapnum = P_RandomRange(1, 1035)
    end

    return mapnum, modenum
end

--- ends the round :P
function Squigglepants.endRound()
    mapmusname = Squigglepants.changeMusic("KSSWAI", true, nil, 0, 0, 500)
    Squigglepants.sync.gamestate = SST_INTERMISSION

    for mo in mobjs.iterate() do
        mo.flags = MF_NOTHINK
        mo.state = S_INVISIBLE
    end
    for p in players.iterate do
        p.pflags = ($ & ~PF_FINISHED)
        p.exiting = 0
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype] ---@type SquigglepantsGametype?
    local div = (gtDef and gtDef.hasIntermission) and 2 or 1

    Squigglepants.sync.inttime = inttime.value*TICRATE / div
    if div == 2 then
        Squigglepants.sync.inttime = $ + fadeTime
    end
    Squigglepants.sync.voteMaps = {}
    local foundMaps = {}
    for i = 1, 3 do
        while Squigglepants.sync.voteMaps[i] == nil
        or foundMaps[Squigglepants.sync.voteMaps[i][1]] do
            Squigglepants.sync.voteMaps[i] = {Squigglepants.getRandomMap()}
        end
        foundMaps[Squigglepants.sync.voteMaps[i][1]] = true
    end
    Squigglepants.sync.voteMaps[4] = {Squigglepants.getRandomMap()}

    if gtDef then
        gtDef:onend()

        if gtDef.hasIntermission then
            Squigglepants.sync.placements = {}
            for p in players.iterate do
                Squigglepants.sync.placements[#Squigglepants.sync.placements+1] = p
            end

            Squigglepants.sync.placements = Squigglepants.sortTied($, gtDef.placement.comparison, gtDef.placement.value)
        end
    end

    local quotes = Squigglepants.defaultQuotes -- NOTE: maybe add gametype specific quotes?
    Squigglepants.sync.curQuote = quotes[P_RandomRange(1, #quotes)]
end

COM_AddCommand("endround", function()
    Squigglepants.endRound()
end, COM_ADMIN)

COM_AddCommand("squiggle_setgamemode", function(_, arg)
    local gt = Squigglepants.getGametypeDef(arg)
    if not gt
    and tonumber(arg) then
        gt = Squigglepants.gametypes[tonumber(arg)]
    end

    if gt then
        G_SetCustomExitVars(gamemap, 2)
        G_ExitLevel()
        Squigglepants.sync.gametype = _G["SGT_"+gt.identifier:upper()]
    end
end, COM_ADMIN)

addHook("PreThinkFrame", function()
    if gametype ~= GT_SQUIGGLEPANTS
    or Squigglepants.sync.gamestate == SST_NONE then return end

    local result = hook.execHook("IntermissionThinker", nil)
    if result then return end

    Squigglepants.sync.inttime = $-1

    local selectedMaps = {}
    if Squigglepants.sync.gamestate == SST_VOTE then
        local playerList = {
            total = 0,
            selected = 0
        }
        for p in players.iterate do
            playerList.total = $+1
            if p.squigglepants.vote.selected then
                playerList.selected = $+1

                local selMap = p.squigglepants.vote.selX + 2*(p.squigglepants.vote.selY - 1)
                selectedMaps[#selectedMaps+1] = selMap
            end
        end

        if playerList.total == playerList.selected then
            Squigglepants.sync.inttime = 0
        end
    end

    if Squigglepants.sync.inttime <= 0 then
        if Squigglepants.sync.gamestate == SST_INTERMISSION then
            mapmusname = Squigglepants.changeMusic("KARSRE", true, nil, 0, 0, 500)

            Squigglepants.sync.inttime = inttime.value*TICRATE / 2
            Squigglepants.sync.gamestate = SST_VOTE
        elseif Squigglepants.sync.gamestate == SST_VOTE then
            Squigglepants.sync.inttime = roulettetime
            Squigglepants.sync.gamestate = SST_ROULETTE

            local rand = #selectedMaps and selectedMaps[P_RandomRange(1, #selectedMaps)] or P_RandomRange(1, 4)
            Squigglepants.sync.selectedMap = Squigglepants.sync.voteMaps[rand]
        else
            G_SetCustomExitVars(Squigglepants.sync.selectedMap[1], 1)
            Squigglepants.sync.gametype = Squigglepants.sync.selectedMap[2]
            G_ExitLevel()
        end
    end
end)

---@param cur number
---@param minval number?
---@param maxval number?
---@return number
local function clamp(cur, minval, maxval)
    if minval == nil then
        minval = -1
    end
    if maxval == nil then
        maxval = 1
    end
    return min(max(cur, minval), maxval)
end

---@param p player_t
hook.addHook("PrePlayerThink", function(p)
    if Squigglepants.sync.gamestate == SST_NONE then return end
    local vote = p.squigglepants.vote

    if Squigglepants.sync.gamestate == SST_VOTE then
        if not vote.selected then
            local oldVote = vote.selX + vote.selY
            if abs(p.cmd.forwardmove) > 15
            and abs(vote.lastcmd.forwardmove) <= 15 then
                local add = -clamp(p.cmd.forwardmove)

                vote.selY = $+add
                if vote.selY < 1 then
                    vote.selX = $-1
                elseif vote.selY > 2 then
                    vote.selX = $+1
                end
            end
            if abs(p.cmd.sidemove) > 15
            and abs(vote.lastcmd.sidemove) <= 15 then
                local add = clamp(p.cmd.sidemove)

                vote.selX = $+add
                if vote.selX < 1 then
                    vote.selY = $-1
                elseif vote.selX > 2 then
                    vote.selY = $+1
                end
            end

            if oldVote ~= vote.selX + vote.selY then
                S_StartSound(nil, sfx_menu1, p)
            end

            if vote.selX < 1 then
                vote.selX = 2
            elseif vote.selX > 2 then
                vote.selX = 1
            end
            if vote.selY < 1 then
                vote.selY = 2
            elseif vote.selY > 2 then
                vote.selY = 1
            end

            if (p.cmd.buttons & BT_JUMP)
            and not (vote.lastcmd.buttons & BT_JUMP) then
                vote.selected = true
                S_StartSound(nil, sfx_addfil, p)
            end
        elseif (p.cmd.buttons & BT_SPIN)
        and not (vote.lastcmd.buttons & BT_SPIN) then
            vote.selected = false
            S_StartSound(nil, sfx_notadd, p)
        end
    elseif Squigglepants.sync.gamestate == SST_INTERMISSION
    and Squigglepants.sync.inttime == (inttime.value * TICRATE/2) then
        local position = -1
        local plyrPos = 1
        local truePos = 1
        for _, t in ipairs(Squigglepants.sync.placements) do
            plyrPos = truePos
            for _, np in ipairs(t) do
                if np == p then
                    position = plyrPos
                    break 2
                end
                truePos = $+1
            end
        end

        local sfx = position == 1 and sfx_kirlon or sfx_kirsho
        S_StartSound(nil, sfx, p)
        mapmusname = ""
        S_ChangeMusic("", true, p)
    end

    vote.lastcmd.forwardmove = p.cmd.forwardmove
    vote.lastcmd.sidemove = p.cmd.sidemove
    vote.lastcmd.buttons = p.cmd.buttons
    p.cmd.forwardmove = 0
    p.cmd.sidemove = 0
    p.cmd.buttons = 0
end)

local scrollTime = 8 * TICRATE
local bgScale = FU

local mapScale = tofixed("0.95")
local lvlWidth, lvlHeight = (160 * mapScale), (100 * mapScale)
local mapMargin = 4 * FU

---@param v videolib
local function drawVoteBG(v)
    local patch = Squigglepants.HUD.getPatch(v, "SRB2BACK")
    local time = FixedDiv(leveltime % scrollTime, scrollTime)

    local x = ease.linear(time, -patch.width * bgScale, 0)
    local y = ease.linear(time, -patch.height * bgScale, 0)

    Squigglepants.HUD.patchFill(v, x, y, nil, nil, bgScale, patch, V_SNAPTOTOP|V_SNAPTOLEFT)
end

---@param self SquigglepantsGametype
---@param v videolib
local function resultsHUD(self, v)
    local fadeTime_passed = fadeTime - (Squigglepants.sync.inttime - (inttime.value * TICRATE/2))

    if fadeTime_passed > fadeTime/2 then
        drawVoteBG(v)

        local mapPicture = G_BuildMapName(gamemap) + "P"
        mapPicture = v.patchExists($) and Squigglepants.HUD.getPatch(v, $) or Squigglepants.HUD.getPatch(v, "BLANKLVL") ---@type patch_t

        local gfxScale = FU/2
        local stripHeight = mapPicture.height * (gfxScale/2) / FU
        v.drawFill(0, 0, v.width() / v.dupx(), stripHeight, 15|V_SNAPTOTOP|V_SNAPTOLEFT)

        -- TODO: figure out a good cropping method for the line; gfx doesn't work for intended thingie
        v.drawScaled(320*FU - mapPicture.width * gfxScale, 0, gfxScale, mapPicture, V_SNAPTORIGHT|V_SNAPTOTOP)

        v.drawString(8, 8, self.name + " - " + G_BuildMapTitle(gamemap), V_SNAPTOTOP|V_SNAPTOLEFT|V_ALLOWLOWERCASE)

        local x = 8
        local yPos = 0
        local plyrPos = 1
        local truePos = 1
        for _, t in ipairs(Squigglepants.sync.placements) do ---@param p player_t
            plyrPos = truePos
            for _, p in ipairs(t) do
                if not (p and p.valid) then continue end

                v.drawString(x, stripHeight + 8 + 12 * yPos, plyrPos + "- " + p.name + ": " + self.placement.value(self, p), 0, "thin")
                yPos = $+1

                truePos = $+1

                if (stripHeight + 8 + 12 * yPos > 200) then
                    yPos = 0
                    x = 100
                end
            end
        end
    end

    if fadeTime_passed < fadeTime then
        local strength = 31

        local fade = 0xFB00 -- to black: 0xFF00 or 0xFA00, first is to black, second is blue-tinted to black
        if fadeTime_passed > fadeTime - fadeTime/4 then
            strength = ease.linear(FixedDiv(fadeTime_passed - (fadeTime - fadeTime/4), fadeTime/4), 32*FU, 0) / FU -- maths.
        elseif fadeTime_passed < fadeTime/4 then
            strength = ease.linear(FixedDiv(fadeTime_passed, fadeTime/2), 0, 32*FU) / FU -- maths.
        end

        v.fadeScreen(fade, strength)
    end
end

---@param v videolib
---@param x fixed_t
---@param y fixed_t
---@param map integer
---@param gametype_num integer
---@param align integer?
---@return fixed_t
---@return fixed_t
local function drawVoteMap(v, x, y, map, gametype_num, align)
    local lvlgfx, modeName, lvlName = Squigglepants.HUD.getPatch(v, "BLANKLVL"), "???", "???"
    
    local textAdd, textSuffix = 2*FU, ""
    if align == 1 then
        textAdd, textSuffix = lvlWidth - 2*FU, "-right"
    end

    if map >= 1 and map <= 1035 then
        local name = G_BuildMapName(map) + "P"
        if v.patchExists(name) then
            lvlgfx = Squigglepants.HUD.getPatch(v, name)
        end

        lvlName = G_BuildMapTitle(map)
    end
        
    if Squigglepants.gametypes[gametype_num]
    and Squigglepants.gametypes[gametype_num].name then
        modeName = Squigglepants.gametypes[gametype_num].name
    else
        lvlgfx = Squigglepants.HUD.getPatch(v, "BLANKLVL")
        modeName = "???"
    end

    v.drawScaled(x, y, mapScale, lvlgfx)
    v.drawString(x + textAdd, y + lvlHeight - 8*FU, modeName, 0, "fixed"+textSuffix)
    v.drawString(x + textAdd, y + lvlHeight - 16*FU, lvlName, 0, "thin-fixed"+textSuffix)
end

---@param v videolib
---@param offsetX fixed_t?
---@param offsetY fixed_t?
---@param margin fixed_t?
local function drawVoteMaps(v, offsetX, offsetY, margin)
    offsetX = $ or 0
    offsetY = $ or 0
    if margin == nil then
        margin = mapMargin
    end

    for i = 1, 4 do
        local map = Squigglepants.sync.voteMaps[i]

        local mapnum, modenum = unpack(map)
        if i >= 4 then
            mapnum = 0
            modenum = INT32_MAX
        end

        local xAdd = -(margin + lvlWidth)
        local align = -1
        local yAdd = -(margin + lvlHeight)
        if (i % 2) == 0 then
            xAdd = margin
            align = 1
        end
        if i > 2 then
            yAdd = margin
        end

        local x, y = (160*FU + xAdd + offsetX), (100*FU + yAdd + offsetY)

       drawVoteMap(v, x, y, mapnum, modenum, align)
    end
end

---@param v videolib
---@param timeleft number
local function drawVoteExtras(v, timeleft)
    local timercircle = Squigglepants.HUD.getPatch(v, "TIMERCIRCLE") ---@type patch_t
    v.drawScaled(160*FU - timercircle.width*FU/4, 100*FU - timercircle.height*FU/4, FU/2, timercircle, V_HUDTRANS)
    v.drawString(160, 100 - 4, timeleft, V_HUDTRANS, "center")
    v.drawString(160, 1, (Squigglepants.sync.curQuote or "Whoops! You have to put the CD in your computer."), V_SNAPTOTOP|V_HUDTRANS|V_ALLOWLOWERCASE, "thin-center")
end

---@param v videolib
local function voteHUD(v)
    local p = displayplayer ---@type player_t
    local vote = p.squigglepants.vote

    drawVoteBG(v)

    local playerList = {}
    for ip in players.iterate do ---@param ip player_t
        if not ip.squigglepants.vote.selected then continue end
        local ivote = ip.squigglepants.vote

        local iHover = ivote.selX + 2*(ivote.selY - 1)
        if not playerList[iHover] then
            playerList[iHover] = {ip}
        else
            table.insert(playerList[iHover], ip)
        end
    end

    drawVoteMaps(v)
    local mapHovered = vote.selX + 2*(vote.selY - 1)

    local xAdd = -(mapMargin + lvlWidth)
    local xMul = 1
    local yAdd = -(mapMargin + lvlHeight)
    if (mapHovered % 2) == 0 then
        xAdd = lvlWidth
        xMul = -1
    end
    if mapHovered > 2 then
        yAdd = mapMargin
    end

    local x, y = (160*FU + xAdd) + 2*FU, (100*FU + yAdd) + 2*FU
    for i = 1, 4 do
        if playerList[i] then
            local margin = 2*FU
            if #playerList[i] > 6 then
                margin = -9 * (#playerList[i] - 6) * FU
            end

            for _, ip in ipairs(playerList[i]) do ---@param ip player_t
                local char
                local spr2 = SPR2_LIFE
                while not (char and char.valid) do
                    char = v.getSprite2Patch(ip.skin, spr2)
                    spr2 = spr2defaults[$]
                end
                local charScale = (skins[ip.skin].flags & SF_HIRES) and skins[ip.skin].highresscale or FU
                local charAdd = xMul == -1 and -char.width*charScale or 0

                v.drawScaled(x + charAdd + char.leftoffset*charScale, y + char.topoffset*charScale, charScale, char, V_HUDTRANS, v.getColormap(ip.skin, ip.skincolor))
                x = $ + (char.width*charScale + margin) * xMul
            end
        end
    end

    if not vote.selected then
        local char
        local spr2 = SPR2_LIFE
        while not (char and char.valid) do
            char = v.getSprite2Patch(p.skin, spr2)
            spr2 = spr2defaults[$]
        end
        local charScale = (skins[p.skin].flags & SF_HIRES) and skins[p.skin].highresscale or FU
        local charAdd = xMul == -1 and -char.width*charScale or 0

        v.drawScaled(x + charAdd + char.leftoffset*charScale, y + char.topoffset*charScale, charScale, char, V_HUDTRANS, v.getColormap(TC_DEFAULT, 0, "Squigglepants_EyesOnly"))
    end
    
    drawVoteExtras(v, Squigglepants.sync.inttime/TICRATE+1)
end

local pre_centerWait = TICRATE/4
local centerTime = TICRATE - TICRATE/4
local centerWait = 0
local mysteryTime = 2*TICRATE + TICRATE/4
local mysteryWait = TICRATE + TICRATE/4
local waitTime = 2*TICRATE

roulettetime = pre_centerWait + centerTime + centerWait + mysteryTime + mysteryWait + waitTime
---@param v videolib
local function rouletteHUD(v)
    local timeleft = roulettetime - Squigglepants.sync.inttime

    drawVoteBG(v)
    if timeleft < pre_centerWait then
        drawVoteMaps(v)
    end
    drawVoteExtras(v, 0)

    if timeleft < pre_centerWait then return end

    local blankgfx = Squigglepants.HUD.getPatch(v, "BLANKLVL") ---@type patch_t
    if timeleft < (pre_centerWait + centerTime + centerWait) then
        local time = min(FixedDiv(timeleft - pre_centerWait, centerTime), FU)
        for i = 1, 4 do
            local map = Squigglepants.sync.voteMaps[i]
            local mapnum, modenum = unpack(map)
            
            if i >= 4 then
                mapnum, modenum = 0, INT32_MAX
            end

            local xAdd = -(mapMargin + lvlWidth)
            local align = -1
            local yAdd = -(mapMargin + lvlHeight)
            if (i % 2) == 0 then
                xAdd = mapMargin
                align = 1
            end
            if i > 2 then
                yAdd = mapMargin
            end

            local x, y = 160*FU + ease.insine(time, xAdd, -(mapMargin + lvlWidth/2)), 100*FU + ease.insine(time, yAdd, -(mapMargin + lvlHeight/2))

            drawVoteMap(v, x, y, mapnum, modenum, align)
        end
    elseif timeleft < (pre_centerWait + centerTime + centerWait + mysteryTime + mysteryWait) then
        local time = min(FixedDiv(timeleft - (pre_centerWait + centerTime + centerWait), mysteryTime), FU)

        local xOffset, yOffset = v.RandomFixed() * v.RandomRange(-1, 1), v.RandomFixed() * v.RandomRange(-1, 1)
        xOffset, yOffset = ease.inexpo(time, 0, 8*$1), ease.inexpo(time, 0, 8*$2)

        local x, y = (160*FU - blankgfx.width*mapScale/2) + xOffset, (100*FU - blankgfx.height*mapScale/2) + yOffset
        drawVoteMap(v, x, y, 0, INT32_MAX, 1)

        local trans = FixedRound(ease.insine(time, 10*FU, 0))/FU

        if trans >= 10 then return end

        v.drawScaled(x, y, mapScale, blankgfx, trans << V_ALPHASHIFT, v.getColormap(TC_DEFAULT, SKINCOLOR_NONE, "AllWhite"))
    else
        local timeNum = timeleft - (pre_centerWait + centerTime + centerWait + mysteryTime + mysteryWait)
        local time = min(FixedDiv(timeNum, TICRATE/4), FU)

        local xOffset, yOffset = 0, 0
        
        local x, y = (160*FU - blankgfx.width*mapScale/2 + xOffset), (100*FU - blankgfx.height*mapScale/2 + yOffset)

        local map = Squigglepants.sync.selectedMap

        drawVoteMap(v, x, y, map[1], map[2], 1)
        local trans = FixedRound(ease.insine(time, 0, 10*FU))/FU

        if trans >= 10 then return end

        v.drawScaled(x, y, mapScale, blankgfx, trans << V_ALPHASHIFT, v.getColormap(TC_DEFAULT, SKINCOLOR_NONE, "AllWhite"))
    end
end

return resultsHUD, voteHUD, rouletteHUD