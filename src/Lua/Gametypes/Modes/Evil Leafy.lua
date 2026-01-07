
-- evil leafy stuff
-- object specific stuff can be found at "Lua/Objects/Evil Leafy"!!
-- -pac

Squigglepants.addGametype({
    name = "Evil Leafy",
    identifier = "evilleafy",
    typeoflevel = TOL_MATCH|TOL_TAG,

    onload = function(self) ---@param self SquigglepantsGametype
        P_SpawnMobjFromMobj(consoleplayer.realmo, 0, 0, 0, MT_ALLSTARS_EVILLEAFY)
    end
})