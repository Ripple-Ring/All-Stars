
freeslot("SPR_GORA", "S_ALLSTARS_FOOD", "MT_ALLSTARS_FOOD", "sfx_asgrfc")

states[S_ALLSTARS_FOOD] = {
    sprite = SPR_GORA,
    frame = A,
    action = A_AttractChase,
    tics = -1
}

mobjinfo[MT_ALLSTARS_FOOD] = {
    spawnstate = S_ALLSTARS_FOOD,
    deathstate = S_SPRK1,
    deathsound = sfx_asgrfc,
    reactiontime = MT_ALLSTARS_FOOD,
    radius = 24*FU,
    height = 40*FU,
    flags = MF_NOGRAVITY|MF_SPECIAL,
}

sfxinfo[sfx_asgrfc].caption = "Eating"

-- TODO: add the 1% thing idk

Squigglepants.addGametype({
    name = "Gourmet Race",
    identifier = "gourmetrace",
    typeoflevel = TOL_COOP,

    blacklist = function(_, map)
        return not ( -- TODO: remove nights stages from the possibilities, 2.2 doesn't like those in multiplayer
            map >= sstage_start
            and map <= sstage_end
            or map >= smpstage_start
            and map <= smpstage_end
        )
    end,

    setup = function(self) ---@param self SquigglepantsGametype
        self.food = 0
    end,

    onload = function(self) ---@param self SquigglepantsGametype
        mapmusname = "SBBGOR"
        S_ChangeMusic("SBBGOR", true, nil, mapmusflags)

        local foodCount, foodTotal = 0, 0
        local foodList = {}
        for mo in mobjs.iterate() do
            if mo.type == MT_BLUESPHERE
            or mo.type == MT_RING then
                foodTotal = $+1
                foodList[#foodList+1] = mo
            end
        end

        local i = 1
        while foodCount < foodTotal/4 do
            if P_RandomChance(FU/2) then
                P_SpawnMobjFromMobj(foodList[i], 0, 0, 0, MT_ALLSTARS_FOOD)

                foodCount = $+1
            end
            i = $ < #foodList and $+1 or 1
        end

        for _, mo in ipairs(foodList) do
            P_RemoveMobj(mo)
        end

        self.food = foodCount
    end,

    thinker = function(self)
        if leveltime < 5 then return end

        local totalFood = 0
        for p in players.iterate do
            totalFood = $+p.rings
        end

        if totalFood >= self.food then
            Squigglepants.endRound()
        end
    end
})

addHook("MobjSpawn", function(mo)
    mo.frame = P_RandomRange(A, L)
    mo.spritexscale, mo.spriteyscale = $1/2, $2/2
end, MT_ALLSTARS_FOOD)

addHook("MobjThinker", function(mo)
    if mo.state ~= mo.info.spawnstate then
        if mo.food_yoffset then
            mo.food_yoffset = 0
            mo.spriteyoffset = 0
        end

        return
    end

    if mo.food_yoffset then
        local yOffset = sin(mo.food_yoffset * ANG1)

        mo.spriteyoffset = 5*yOffset
    end

    mo.food_yoffset = $ and ($+2) or (P_RandomFixed() * P_RandomRange(1, 10))
end, MT_ALLSTARS_FOOD)

addHook("TouchSpecial", function(mo, pmo)
    mo.spritexscale, mo.spriteyscale = 2*FU, 2*FU

    if (pmo.player and pmo.player.valid) then
        P_GivePlayerRings(pmo.player, 1)
    end
end, MT_ALLSTARS_FOOD)