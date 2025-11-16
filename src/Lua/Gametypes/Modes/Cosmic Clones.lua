
local CLONE_OFFSET = TICRATE / 2 -- when the clones start showing up
local CLONE_STARTUP = TICRATE -- how long the clones do their start-up anim
local CLONE_STUN = TICRATE -- how long the clones are stunned for
local CLONES_PER_SECOND = 4 -- self-explanatory, can go up to TICRATE (35)
local CLONE_OPACITY = FU - FU/4 -- 0 to FU, gets halved when it's not your clone

local RING_TOTAL = 4 -- 1/xth of the total rings

mobjinfo[freeslot("MT_SQUIGGLEPANTS_COSMICCLONE")] = {
    spawnstate = S_INVISIBLE,
    flags = MF_PAIN|MF_NOCLIPHEIGHT|MF_NOGRAVITY
}

local copyList = {"x", "y", "z", "angle", "sprite", "sprite2", "frame", "destscale", "scale", "eflags"}

Squigglepants.addGametype({
    name = "Cosmic Clones",
    identifier = "cosmicclone",
    description = "galaxy D:",
    typeoflevel = TOL_RACE,
    setup = function(self) ---@param self SquigglepantsGametype
        self.clonetimer = 0
        self.ringtotal = 0 -- how many rings are in the level
        self.ringcount = 0 -- how many rings were collected

        self.cloneList = {}
    end,

    onload = function(self) ---@param self SquigglepantsGametype
        for p in players.iterate do
            p.squigglepants.cosmicclones = {
                lives = 3
            }
        end

        for mo in mobjs.iterate() do -- TODO: make this account for other ring types
            if mo.type == MT_RING then
                self.ringtotal = $+1
            end

            if mo.type == MT_RING_BOX then
                self.ringtotal = $+10
            end
        end

        if self.ringtotal == 0 then
            Squigglepants.endRound()
            return
        end
        
        print(self.ringtotal / RING_TOTAL)
    end,

    thinker = function(self) ---@param self SquigglepantsGametype
        if leveltime > CLONE_OFFSET then
            self.clonetimer = $+1
        end

        for i = 0, 31 do
            if self.cloneList[i] ~= nil
            and not (players[i] and players[i].valid) then
                self.cloneList[i] = nil
            end
        end
    end,

    ---@param self SquigglepantsGametype
    ---@param p player_t
    playerThink = function(self, p)
        if not (p.mo and p.mo.valid)
        or (p.pflags & PF_FINISHED)
        or p.exiting then return end

        if self.ringtotal > 0
        and self.ringcount >= self.ringtotal / RING_TOTAL then
            Squigglepants.endRound()
        end

        self.ringcount = p.rings

        if not self.cloneList[#p] then
            self.cloneList[#p] = {}
        end

        local cloneList_pos = #self.cloneList[#p]+1
        self.cloneList[#p][cloneList_pos] = {}
        for _, key in ipairs(copyList) do
            self.cloneList[#p][cloneList_pos][key] = p.mo[key]
        end
        self.cloneList[#p][cloneList_pos].angle = p.drawangle

        if leveltime > CLONE_OFFSET
        and (self.clonetimer % (TICRATE / CLONES_PER_SECOND)) == 0
        and self.cloneList and self.cloneList[#p] then
            local clonePos = self.cloneList[#p][1]
            local clone = P_SpawnMobj(clonePos.x, clonePos.y, clonePos.z, MT_SQUIGGLEPANTS_COSMICCLONE)
            clone.angle = clonePos.angle
            clone.cloneNum = #p
            clone.height = p.mo.height
            clone.radius = p.mo.radius

            clone.skin = p.mo.skin
            clone.color = SKINCOLOR_GALAXY
            clone.colorized = true
            clone.state = S_PLAY_STND
        end

        if p.playerstate == PST_REBORN then
            p.squigglepants.cosmicclones.lives = $-1

            if p.squigglepants.cosmicclones.lives <= 0 then
                G_DoReborn(#p)
                p.rmomx, p.rmomy = 0, 0
                p.spectator = true
            end
        end
    end
})

---@param mo mobj_t
addHook("MobjThinker", function(mo)
    if mo.cloneNum == nil then
        P_RemoveMobj(mo)
        return
    end

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype]
    if not gtDef
    or not gtDef.clonetimer
    or not gtDef.cloneList then
        P_RemoveMobj(mo)
        return
    end

    if mo.timeAlive ~= nil
    and mo.timeAlive > CLONE_STARTUP then
        local clonePos_num = mo.timeAlive and mo.timeAlive - CLONE_STARTUP or 1
        local clonePos = gtDef.cloneList[mo.cloneNum]
        if not clonePos
        or not clonePos[clonePos_num] then
            P_RemoveMobj(mo)
            return
        end

        clonePos = clonePos[clonePos_num]
        P_MoveOrigin(mo, clonePos.x, clonePos.y, clonePos.z)
        for _, key in ipairs(copyList) do
            if key ~= "x"
            and key ~= "y"
            and key ~= "z" then
                mo[key] = clonePos[key]
            end
        end
    end

    if displayplayer 
    and not splitscreen then
        if displayplayer ~= players[mo.cloneNum] then
            mo.alpha = CLONE_OPACITY/2
        else
            mo.alpha = CLONE_OPACITY
        end
    end
    mo.timeAlive = $ and $+1 or 2
end, MT_SQUIGGLEPANTS_COSMICCLONE)

addHook("ShouldDamage", function(pmo, clone)
    if not (pmo and pmo.valid)
    or not (clone and clone.valid)
    or clone.type ~= MT_SQUIGGLEPANTS_COSMICCLONE then return end

    if #pmo.player ~= clone.cloneNum
    or not clone.timeAlive
    or clone.timeAlive <= CLONE_STARTUP then
        return false
    end
end, MT_PLAYER)