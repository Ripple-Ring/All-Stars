
local COUNTDOWN_TIME = 4*TICRATE

Squigglepants.addGametype({
    name = "Race",
    identifier = "race",
    description = "its race",
    typeoflevel = TOL_RACE,
    setup = function(self) ---@param self SquigglepantsGametype
        self.leveltime = 0

        self.winnerList = {}
        self.checkpointList = {}
        self.placements = {}
    end,

    onload = function(self) ---@param self SquigglepantsGametype
        for p in players.iterate do
            p.squigglepants.race_lap = 1
        end
    end,

    thinker = function(self) ---@param self SquigglepantsGametype
        if leveltime <= COUNTDOWN_TIME then
            if leveltime % TICRATE == 0
            and leveltime > 0 then
                S_StartSound(nil, sfx_thok)
            end

            if not #self.checkpointList
            and leveltime <= 5 then
                local sign
                for mt in mapthings.iterate do
                    if mt.type == 502 then
                        self.checkpointList[mt.mobj.health] = mt.mobj
                    end
                    
                    if mt.type == 501 then
                        sign = mt
                    end
                end

                if (sign and sign.valid) then
                    local signPos = {
                        x = sign.x * FU,
                        y = sign.y * FU
                    }
                    signPos.z = P_FloorzAtPos(signPos.x, signPos.y, ONFLOORZ, 0) + sign.z * FU
                    if (sign.options & MTF_OBJECTFLIP) then
                        signPos.z = P_CeilingzAtPos(signPos.x, signPos.y, ONFLOORZ, 0) - sign.z * FU
                    end

                    self.checkpointList[#self.checkpointList+1] = signPos
                end
            end
            return
        end

        if (leveltime % 5) == 0 then
            local temp_placements = {}
            for p in players.iterate do
                temp_placements[#temp_placements+1] = p
            end

            ---@param p1 squigglepantsPlayer
            ---@param p2 squigglepantsPlayer
            table.sort(temp_placements, function(p1, p2)
                if p1.starpostnum ~= p2.starpostnum then
                    return p1.starpostnum < p2.starpostnum
                end

                local checkpoint = self.checkpointList[p1.starpostnum+1] or self.checkpointList[#self.checkpointList]
                return R_PointToDist2(p1.realmo.x, p1.realmo.y, checkpoint.x, checkpoint.y) < R_PointToDist2(p2.realmo.x, p2.realmo.y, checkpoint.x, checkpoint.y)
            end)

            local true_placements = {}
            local trueKey = 1
            local prevPlyr
            for _, p in ipairs(temp_placements) do
                if not (p and p.valid) then continue end

                if (prevPlyr and prevPlyr.valid)
                and prevPlyr.starpostnum == p.starpostnum then
                    local checkpoint = self.checkpointList[p.starpostnum+1] or self.checkpointList[#self.checkpointList]
                    if abs(R_PointToDist2(prevPlyr.realmo.x, prevPlyr.realmo.y, checkpoint.x, checkpoint.y) - R_PointToDist2(p.realmo.x, p.realmo.y, checkpoint.x, checkpoint.y)) <= p.realmo.radius + prevPlyr.realmo.radius then
                        table.insert(true_placements[trueKey-1], p)
                        prevPlyr = p
                        continue
                    end
                end

                true_placements[trueKey] = {p}
                prevPlyr = p
                trueKey = $+1
            end

            self.placements = true_placements
        end

        self.leveltime = $+1
    end,

    ---@param self SquigglepantsGametype
    ---@param p player_t
    playerThink = function(self, p)
        if leveltime <= COUNTDOWN_TIME then
            p.pflags = $1|PF_FULLSTASIS
        end

        if not (p.pflags & PF_FINISHED)
        and not p.exiting then
            p.realtime = self.leveltime

            if P_PlayerTouchingSectorSpecialFlag(p, SSF_EXIT) then
                P_DoPlayerFinish(p)
                
                if G_EnoughPlayersFinished() then
                    Squigglepants.endRound()
                end
            end
        end
    end,

    onend = function(self) ---@param self SquigglepantsGametype
        local temp_winnerList = {}
        for p in players.iterate do
            temp_winnerList[#temp_winnerList+1] = p
        end

        table.sort(temp_winnerList, function(a, b)
            return a.realtime < b.realtime
        end)

        local trueKey = 1
        local prevPlyr
        for _, p in ipairs(temp_winnerList) do
            if not (p and p.valid) then continue end

            if (prevPlyr and prevPlyr.valid)
            and prevPlyr.realtime == p.realtime then
                table.insert(self.winnerList[trueKey-1], p)
                prevPlyr = p
                continue
            end

            self.winnerList[trueKey] = {p}
            prevPlyr = p
            trueKey = $+1
        end
    end,

    ---@param v videolib
    ---@param p player_t
    gameHUD = function(self, v, p)
        if leveltime < COUNTDOWN_TIME then
            local timer = (COUNTDOWN_TIME / TICRATE - 1) - (leveltime / TICRATE)
            v.drawString(160, 100, timer, 0, "center")

            return
        end

        if self.placements then
            for key, t in ipairs(self.placements) do
                for _, t_p in ipairs(t) do
                    if t_p ~= p then continue end

                    v.drawString(320 - 16, 200 - 16, key, V_SNAPTOBOTTOM|V_SNAPTORIGHT|V_PERPLAYER, "right")
                    break 2
                end
            end
        end
        v.drawString(320 - 16, 200 - 28, (p.starpostnum + 1)+"/"+(#self.checkpointList), V_SNAPTOBOTTOM|V_SNAPTORIGHT|V_PERPLAYER, "right")
    end,

    intermission = function(self, v) ---@param v videolib
        local yPos = 0
        local plyrPos = 1
        for key, t in ipairs(self.winnerList) do ---@param p squigglepantsPlayer
            for _, p in ipairs(t) do
                if not (p and p.valid) then continue end

                v.drawString(8, 8 + 12 * yPos, plyrPos + "- " + p.name, 0, "thin")
                yPos = $+1

                if plyrPos ~= key then
                    plyrPos = key - (#self.winnerList[key-1] - 1)
                end
            end
        end
    end,

    placement = { ---@type SquigglepantsGametype_placement
        comparison = function(a, b)
            return a.realtime < b.realtime
        end,

        value = function(p)
            return p.realtime
        end
    }
})