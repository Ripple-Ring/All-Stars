-- figured i'd try using actions for once
-- -pac

local maxJumpTics = 2 * TICRATE + TICRATE / 4
function A_MarioDecide(mo)
	mo.tics = P_RandomRange(TICRATE / 2, 2*TICRATE)
	mo.angle = FixedAngle(360 * P_RandomFixed())
	
	mo.walktics = P_RandomRange(3*TICRATE, 5*TICRATE)
	mo.willskid = (leveltime % 8) > 3 and true or false
	mo.jumptics = max(P_RandomRange(-maxJumpTics * 2, maxJumpTics), 0)
end

---@diagnostic disable: missing-fields
mobjinfo[MT_SO_RETRO] = {
	--$Title Mario
	--$Sprite SRMRARAL
	--$Category All-Stars
	--$Category Spongebob Squigglepants
	--$Angled
	doomednum = 3200,
	spawnhealth = 1,
	spawnstate = S_SR_STAND,
	deathstate = S_SR_DEAD,
	xdeathstate = S_NULL,
	deathsound = sfx_smbded,
	radius = 8*FU,
	height = 16*FU,
	activesound = sfx_smbjum,
	flags = MF_SPECIAL|MF_RUNSPAWNFUNC
}

states[S_SR_STAND] = {
    sprite = SPR_SRMR,
    frame = A,
	action = A_MarioDecide,
	nextstate = S_SR_WALK
}

states[S_SR_WALK] = {
    sprite = SPR_SRMR,
	frame = B|FF_ANIMATE,
	var1 = E,
	var2 = 3
}

states[S_SR_DEAD] = {
    sprite = SPR_SRMR,
    frame = I
}

states[S_SR_JUMP] = {
    sprite = SPR_SRMR,
    frame = H
}

states[S_SR_SKID] = {
    sprite = SPR_SRMR,
    frame = G
}

-- because accuracy or something gjgbgghh -pac
local function convertValue(block, pixel, spixel, sspixel, ssspixel, accel)
	block = $ and (tonumber($, 16) * FU * 16) or 0
	pixel = $ and (tonumber($, 16) * FU) or 0
	spixel = $ and (tonumber($, 16) * FU / 16) or 0
	sspixel = $ and (tonumber($, 16) * FU / 16 / 16) or 0
	ssspixel = $ and (tonumber($, 16) * FU / 16 / 16 / 16) or 0
	accel = $ or false
	
	local finalVal = block + pixel + spixel + sspixel + ssspixel
	if accel then
		finalVal = FixedMul($, 60*FU / 35)
	end
	return finalVal
end

local WALK_ACCEL = convertValue(0, 0, 0, 9, 8, true)
local BASE_DEACCEL = convertValue(0, 0, 0, "D", 0, true)

local MIN_WALKSPEED = convertValue(0, 0, 1, 3, 0)
local MAX_WALKSPEED = convertValue(0, 1, 9, 0, 0)

local JUMP_VEL = convertValue(0, 4, 0, 0, 0)

local HOLDA_GRAV = convertValue(0, 0, 2, 0, 0, true)
local BASE_GRAV = convertValue(0, 0, 7, 0, 0, true)

addHook("TouchSpecial", function(mo, pmo)
	return not P_PlayerCanDamage(pmo.player, mo)
end, MT_SO_RETRO)

addHook("MobjThinker", function(mo)
	mo.friction = FU
	if mo.momz then
		mo.momz = $ - P_GetMobjGravity(mo) -- we dont want no gravity
	end
	
	local speed = R_PointToDist2(0, 0, mo.momx, mo.momy)
	
	if speed >= MAX_WALKSPEED
	or mo.state == S_SR_WALK and mo.walktics <= 0 then
		P_Thrust(mo, mo.angle, -FixedMul(BASE_DEACCEL, mo.scale))
		
		if R_PointToDist2(0, 0, mo.momx, mo.momy) > speed then -- overshot it
			mo.state = S_SR_STAND
			P_InstaThrust(mo, 0, 0)
		end
	end
	
	if mo.state == S_SR_WALK then
		if mo.jumptics > 0 then
			S_StartSound(mo, sfx_smbjum)
			mo.state = S_SR_JUMP
			P_SetObjectMomZ(mo, JUMP_VEL)
			return
		end
		
		if mo.walktics > 0 then
			if speed < MIN_WALKSPEED then
				P_InstaThrust(mo, mo.angle, FixedMul(MIN_WALKSPEED, mo.scale))
			end
			
			if speed < MAX_WALKSPEED then
				P_Thrust(mo, mo.angle, FixedMul(WALK_ACCEL, mo.scale))
			end
			
			mo.walktics = $-1
		end
	end
	
	if mo.state == S_SR_JUMP then
		if mo.momz*P_MobjFlip(mo) <= 0 then
			if P_IsObjectOnGround(mo) then
				mo.state = S_SR_STAND
			end
			mo.jumptics = 0
		else
			mo.jumptics = $-1
		end
	end
	
	if mo.state == S_SR_DEAD then
		P_InstaThrust(mo, 0, 0)
		mo.walktics, mo.jumptics = 0, 0
		
		if not mo.deadtics then
			P_SetObjectMomZ(mo, JUMP_VEL)
		end
		mo.deadtics = $ and $+1 or 1
	end
	
	local holdingJump = mo.jumptics > 0 and true or false -- simulate holding jump
	P_SetObjectMomZ(mo, -(holdingJump and HOLDA_GRAV or BASE_GRAV), true)
	
	if mo.z+mo.height < mo.floorz and not (mo.eflags & MFE_VERTICALFLIP)
	or mo.z > mo.ceilingz and (mo.eflags & MFE_VERTICALFLIP) then
		P_RemoveMobj(mo)
	end
end, MT_SO_RETRO)

addHook("MobjMoveBlocked", function(mo)
	mo.angle = $ + ANGLE_180 + FixedAngle(45 * P_RandomFixed())
	P_InstaThrust(mo, mo.angle, FixedMul(MIN_WALKSPEED, mo.scale))
end, MT_SO_RETRO)

addHook("PlayerSpawn", function(p)
	P_SpawnMobjFromMobj(p.mo, 0, 0, 0, MT_SO_RETRO)
end)