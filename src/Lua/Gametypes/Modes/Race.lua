
local COUNTDOWN_TIME = 4*TICRATE

local function ticsToTimeString(tics)
    return string.format("%02d:%02d.%02d", G_TicsToMinutes(tics, true), G_TicsToSeconds(tics), G_TicsToCentiseconds(tics))
end

sfxinfo[freeslot("sfx_kar1pl")].caption = "your wiener"
sfxinfo[freeslot("sfx_karoth")].caption = "someone wiener"

Squigglepants.addGametype({
    name = "Race",
    color = SKINCOLOR_AZURE,
    identifier = "race",
    description = "its race",
    typeoflevel = TOL_RACE,
    setup = function(self) ---@param self SquigglepantsGametype
        self.leveltime = 0

        self.checkpointList = {}
        self.placements = {}
    end,

    onload = function(self) ---@param self SquigglepantsGametype
        for p in players.iterate do
            p.squigglepants.race_lap = 1
            p.squigglepants.race_time = 0
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
            if p.squigglepants then
                p.squigglepants.race_time = self.leveltime
                p.realtime = p.squigglepants.race_time
            end

            if P_PlayerTouchingSectorSpecialFlag(p, SSF_EXIT) then
                S_StartSound(nil, sfx_kar1pl, p)
                if not P_IsLocalPlayer(p) then
                    S_StartSound(nil, sfx_karoth, p)
                end
                P_DoPlayerFinish(p)
                
                if G_EnoughPlayersFinished() then
                    Squigglepants.endRound()
                end
            end
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

    placement = { ---@type SquigglepantsGametype_placement
        comparison = function(a, b)
            return (a.squigglepants and b.squigglepants) and a.squigglepants.race_time < b.squigglepants.race_time
        end,

        value = function(p)
            return ticsToTimeString(p.squigglepants.race_time)
        end
    }
})