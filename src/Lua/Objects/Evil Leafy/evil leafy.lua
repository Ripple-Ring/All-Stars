
local function themaththingthatilluseonce(cur, add, compare)
    if cur < compare
    and cur+add > compare
    or cur > compare
    and cur+add < compare then
        return compare
    end

    return cur+add
end

/*
    A* (or Theta*) if it sucked, probably.
    based mostly on wikipedia's pseudo-code for both mentioned :P
*/
local function reconstruct_path(cameFrom, current)
    local total_path = {current}
    while cameFrom[current] ~= current do
        current = cameFrom[current]
        total_path[#total_path+1] = current
    end
    return total_path
end

local angleIncrement = 45
local memoryCount = 5 -- how many previous moves will evil leafy not do?
local stepupHeight = 128*FU

--- gets a path to `mo.target`, with a constant speed of `speed`<br>
--- `speed` defaults to `mo`'s speed in its object definition.
---@param mo mobj_t
---@param speed fixed_t?
local function getPath(mo, speed)
    if not (mo and mo.valid)
    or not (mo.target and mo.target.valid) then return end

    speed = $ or mo.info.speed

    local parent = {}
    local availablePaths = {mo.x+mo.y}
    local translation = {[mo.x+mo.y] = {x = mo.x, y = mo.y}} -- because im smart :D
    parent[translation[mo.x+mo.y]] = translation[mo.x+mo.y]

    local gScore = {}
    gScore[translation[mo.x+mo.y]] = 0

    local x, y, z = mo.x, mo.y, mo.z
    local helper = P_SpawnMobjFromMobj(mo, 0, 0, 0, MT_THOK)
    helper.state = S_INVISIBLE
    helper.radius, helper.height = mo.radius, mo.height
    helper.flags = mo.flags

    local test = {}
    while #availablePaths > 0 do
        print(#availablePaths)
        P_SetOrigin(mo, x, y, z)

        local lowestDist = INT32_MAX
        local current
        for _, val in ipairs(availablePaths) do
            local trans = translation[val]
            local dist = R_PointToDist2(trans.x, trans.y, mo.target.x, mo.target.y)
            if dist < lowestDist then
                lowestDist = dist
                current = val
            end
        end

        local trans_current = translation[current] -- im so happy for her
        table.remove(availablePaths)
        if trans_current.x == mo.target.x
        and trans_current.y == mo.target.y then
            return reconstruct_path(parent, trans_current)
        end

        for i = 1, 360 do
            local ang = FixedAngle(i * FU)
            local xMove, yMove = P_ReturnThrustX(nil, ang, speed), P_ReturnThrustY(nil, ang, speed)

            local newX, newY = themaththingthatilluseonce(x, xMove, mo.target.x), themaththingthatilluseonce(y, yMove, mo.target.y)
            if not P_TryMove(mo, newX, newY, true) then
                continue
            end

            local neighbor = newX + newY -- the Theta* """""""based""""""" part (still probably sucks compared to that though :P)
            translation[neighbor] = {x = newX, y = newY}
            local trans_neighbor = translation[neighbor] -- im so happy for him
            
            P_SetOrigin(helper, parent[trans_current].x, parent[trans_current].y, z)

            if P_CheckSight(mo, mo.target) then
                if R_PointToDist2(helper.x, helper.y, mo.target.x, mo.target.y) + R_PointToDist2(helper.x, helper.y, mo.x, mo.y) < R_PointToDist2(mo.x, mo.y, mo.target.x, mo.target.y) then
                    parent[trans_neighbor] = parent[trans_current]
                end
            else
                if R_PointToDist2(trans_current.x, trans_current.y, mo.target.x, mo.target.y) + R_PointToDist2(trans_current.x, trans_current.y, mo.x, mo.y) < R_PointToDist2(trans_neighbor.x, trans_neighbor.y, mo.target.x, mo.target.y) then
                    parent[trans_neighbor] = trans_current
                end
            end

            local foundNeighbor = false
            for _, val in ipairs(availablePaths) do
                if val == neighbor then
                    foundNeighbor = true
                    break 1 ---@diagnostic disable-line
                end
            end

            if not foundNeighbor then
                availablePaths[#availablePaths+1] = neighbor
            end
        end
    end
end

function Squigglepants.EvilLeafyMove(mo, speed)
    local helper = P_SpawnMobjFromMobj(mo, 0, 0, 0, MT_THOK)
    helper.state = S_INVISIBLE
    helper.radius, helper.height = mo.radius, mo.height
    helper.flags = mo.flags

    local x, y, z = mo.x, mo.y, mo.z

    local path = getPath(mo, speed)

    if not path then return end

    speed = FixedMul($, mo.scale)

    P_MoveOrigin(mo, path[1].x, path[1].y, mo.z)
end

freeslot(
    "SPR_EVLF",
    "S_ALLSTARS_EVILLEAFY",
    "MT_ALLSTARS_EVILLEAFY"
)

---@diagnostic disable: missing-fields
states[S_ALLSTARS_EVILLEAFY] = { 
    sprite = SPR_EVLF,
    frame = A,
    tics = -1
}

mobjinfo[MT_ALLSTARS_EVILLEAFY] = {
    spawnstate = S_ALLSTARS_EVILLEAFY,
    radius = 16*FU,
    height = 32*FU,
    flags = MF_NOGRAVITY
}

---@param evilleafyisveryevilandismakingthisvariablesuperbig mobj_t
addHook("MobjSpawn", function(evilleafyisveryevilandismakingthisvariablesuperbig)
    evilleafyisveryevilandismakingthisvariablesuperbig.spritexscale = $/2
    evilleafyisveryevilandismakingthisvariablesuperbig.spriteyscale = $/2
end, MT_ALLSTARS_EVILLEAFY)

---@param helloiamevilleafyandiamveryevil mobj_t
addHook("MobjThinker", function(helloiamevilleafyandiamveryevil)
    P_LookForPlayers(helloiamevilleafyandiamveryevil, 0, true)

    if (helloiamevilleafyandiamveryevil.target and helloiamevilleafyandiamveryevil.target.valid)
    and (leveltime % (TICRATE/2)) == 0 then
        Squigglepants.EvilLeafyMove(helloiamevilleafyandiamveryevil, helloiamevilleafyandiamveryevil.target.x, helloiamevilleafyandiamveryevil.target.y, 128*FU)

        if (helloiamevilleafyandiamveryevil.eflags & MFE_VERTICALFLIP) then
            helloiamevilleafyandiamveryevil.z = helloiamevilleafyandiamveryevil.ceilingz
        else
            helloiamevilleafyandiamveryevil.z = helloiamevilleafyandiamveryevil.floorz
        end
    end

    if devparm and (consoleplayer.cmd.buttons & BT_CUSTOM1) then -- DEBUG
        local p = consoleplayer
        p.awayviewmobj = helloiamevilleafyandiamveryevil
        p.awayviewtics = 5
        helloiamevilleafyandiamveryevil.angle = R_PointToAngle2(helloiamevilleafyandiamveryevil.x, helloiamevilleafyandiamveryevil.y, p.realmo.x, p.realmo.y)
    end
end, MT_ALLSTARS_EVILLEAFY)