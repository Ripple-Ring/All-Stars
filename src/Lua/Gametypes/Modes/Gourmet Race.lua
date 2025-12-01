
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
    flags = MF_NOGRAVITY|MF_NOCLIPHEIGHT|MF_SPECIAL,
}

sfxinfo[sfx_asgrfc].caption = "Eating"

local TIMELIMIT = 60*TICRATE -- plus a 5 second window so people have Time to see the title card :D

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
        self.foodPlacements = {}
        self.food = 0
    end,

    onload = function(self) ---@param self SquigglepantsGametype
        mapmusname = Squigglepants.changeMusic("KARSGR", true, nil, mapmusflags)

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
                foodList[i].temporarysupercoolgourmetracevariablethatindicatesivespawnedfoodinhereandthuswillnotbeapartofthepossiblespawnlocations = true -- i dont think another mod's gonna use this variable name, ngl

                foodCount = $+1
            end
            i = $ < #foodList and $+1 or 1
        end

        for _, mo in ipairs(foodList) do
            if not mo.temporarysupercoolgourmetracevariablethatindicatesivespawnedfoodinhereandthuswillnotbeapartofthepossiblespawnlocations then
                self.foodPlacements[#self.foodPlacements+1] = {mo.x, mo.y, mo.z}
            end
            P_RemoveMobj(mo)
        end

        self.food = foodTotal
    end,

    thinker = function(self)
        if leveltime > TIMELIMIT + 5*TICRATE then
            Squigglepants.endRound()
        end
    end,

    placement = { ---@type SquigglepantsGametype_placement
        comparison = function(a, b)
            return a.rings < b.rings
        end,

        value = function(p)
            return p.rings
        end
    }
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

    if mo.variablenamethatindicatesthatthisfoodisfallingfromthesky then
        mo.flags = ($|MF_NOCLIPHEIGHT) & ~MF_NOGRAVITY
        if not mo.helloiamfoodthatfallsandivespawnedalready then
            mo.z = (mo.subsector.sector.ceilingheight + 500*FU)
            mo.helloiamfoodthatfallsandivespawnedalready = true
        end

        local grav = P_GetMobjGravity(mo)
        mo.momz = $ + grav + grav/2

        if (leveltime % 2) == 0 then
            for i = 1, 4 do
                P_SpawnMobjFromMobj(mo, P_RandomRange(-32, 32)*P_RandomFixed(), P_RandomRange(-32, 32)*P_RandomFixed(), P_RandomRange(-20, 20)*P_RandomFixed(), MT_SPINDUST).scale = P_RandomFixed()+FU/2
            end
        end

        if mo.z + mo.momz - mo.desiredz <= 0 then
            mo.variablenamethatindicatesthatthisfoodisfallingfromthesky = false
            mo.momz = 0
            mo.z = mo.desiredz
            mo.flags = ($|MF_NOGRAVITY) & ~MF_NOCLIPHEIGHT
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

    local gtDef = Squigglepants.gametypes[Squigglepants.sync.gametype]
    local pos = table.remove(gtDef.foodPlacements, P_RandomRange(1, #gtDef.foodPlacements))
    local food = P_SpawnMobj(pos[1], pos[2], pos[3], MT_ALLSTARS_FOOD)
    food.variablenamethatindicatesthatthisfoodisfallingfromthesky = true
    food.desiredz = pos[3]
    gtDef.foodPlacements[#gtDef.foodPlacements+1] = {mo.x, mo.y, mo.z}
    pmo.state = S_PLAY_GASP
end, MT_ALLSTARS_FOOD)