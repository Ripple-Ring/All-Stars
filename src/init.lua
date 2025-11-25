
-- initialize !!
-- for what i call
-- codename Spongebob Squigglepants
-- -pac

freeslot("TOL_SQUIGGLEPANTS")

G_AddGametype({ -- get us our gametype
    name = "SRB2: All-Stars",
    identifier = "squigglepants",
    typeoflevel = TOL_COOP|TOL_SQUIGGLEPANTS,
    rules = GTR_EMERALDTOKENS|GTR_EMERALDHUNT|GTR_SPAWNENEMIES,
    intermissiontype = int_none,
    headercolor = 103,
    description = "doo doo fart"
})

rawset(_G, "Squigglepants", { -- and our variable! below is also variable stuff
	sync = {
		gametype = 1, ---@type integer what gametype is it? uses SGT_ constants
		gamestate = -1, ---@type integer what gamestate is it? uses SST_ constants
		inttime = 0, ---@type tic_t how many tics is it left before intermission ends?
        voteMaps = {}, ---@type table<number> the maps available to vote, goes from 1 to 3
        selectedMap = {} ---@type table the map that's been selected
	}
})

rawset(_G, "SST_NONE", -1)
rawset(_G, "SST_INTERMISSION", 0)
rawset(_G, "SST_VOTE", 1)
rawset(_G, "SST_ROULETTE", 2)

addHook("NetVars", function(net)
	Squigglepants.sync = net($)
    Squigglepants.gametypes = net($)
end)

-- actual dofiling
dofile("Libs/lib_customhud.lua")
dofile("Functions/misc.lua")
dofile("Functions/hud.lua")
dofile("Functions/hook.lua")

local dofile = Squigglepants.dofile

dofile("Game/handler.lua")
dofile("Game/voting.lua")

dofile("Gametypes/handler.lua")
dofile("Gametypes/Modes/Race.lua")
dofile("Gametypes/Modes/Gourmet Race.lua")