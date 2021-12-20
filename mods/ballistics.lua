#include "projectile.lua"

Ballistics = {}
Ballistics.Projectiles = {}
Ballistics.Type = {
	Bullet = 0,
	Rocket = 1
}

--[[-------------------------------------------------------------------------
Arguments:
	data: Table of projectile's settings which contains

	Type = Type of the projectile
	Owner = Who's shooting
	Pos = Position where shoot from
	Dir = Direction where shoot at (Normalised vector)
	Vel = Velocity of the projectile (Vector)

	If "Type" of the projectile is "Bullet", then:
		Soft = Hole radius for soft materials
		Medium = Hole radius for medium materials. May not be bigger than "soft". Default zero.
		Hard = Hole radius for hard materials. May not be bigger than "hard". Default zero.
	In other case it's "Rocket", and required filds are:
		Explosion = Explosion size from 0.5 to 4.0

	Damage = damage to player (0-1). Default zero
	NoHole = if true, then do not create a hole
	Life = how many penetrations(walls) can be?

	Gravity(optional) = Gravity of the projectile (-1 for example would drag projectile to the ground)
	HitPlayerAndContinue(optional) = if projectile must hit player(and damage him) and continue "flying" till physical obstacle, then set this to true
	-- Usually it used for default tools or for weapons which penetration is cool enough 
---------------------------------------------------------------------------]]
function Ballistics:Shoot(data)
	data.Damage = data.Damage or 0
	data.Soft = data.Soft or 0
	data.Medium = data.Medium or 0
	data.Hard = data.Hard or 0
	data.Gravity = data.Gravity or 0
	data.Life = data.Life or 0
	data.ShootPos = data.Pos

	local projectile = Projectile(data)

	self.Projectiles[#self.Projectiles + 1] = projectile

	return projectile
end

function Ballistics:Tick()
	for i, projectile in ipairs(self.Projectiles) do
		projectile:Tick()
		
		if projectile.hit then table.remove(self.Projectiles, i) end
	end
end

local function Distance(a, b)
	local sub = VecSub(a, b)
	return sub[1]^2 + sub[2]^2 + sub[3]^2
end

local axis = {
	Vec(1, 0, 0),
	Vec(0, 1, 0),
	Vec(0, 0, 1)
}
local function IntersectOBB(rayOrigin, rayDir, OBBpos, OBBmin, OBBmax)
	local tMin, tMax = 0, math.huge

	local t = Transform(OBBpos)
	local delta = VecSub(OBBpos, rayOrigin)
	for i, ax in ipairs(axis) do
		local e = VecDot(ax, delta)
		local f = VecDot(rayDir, ax)

		if f == 0 then return false end

		local t1 = (e + OBBmin[i]) / f
		local t2 = (e + OBBmax[i]) / f

		if t1 > t2 then
			local old_t1 = t1
			t1 = t2
			t2 = old_t1
		end

		if t2 < tMax then
			tMax = t2
		end

		if t1 > tMin then
			tMin = t1
		end

		if tMax < tMin then return false end
	end
	
	return true, tMin
end

-- https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
local function IntersectSphere(rayOrigin, rayDir, spherePos, sphereRad)
	local oc = VecSub(rayOrigin, spherePos)
	local b = VecDot(oc, rayDir)
	local c = VecDot(oc, oc) - sphereRad*sphereRad
	local h = b*b - c

	if h < 0 then return false end

	h = math.sqrt(h)

	return true, -b-h, -b+h
end

local flyByDist = 4.5^2
local suppressDist = 1000

--[[-------------------------------------------------------------------------
Whether or not segment hits an obstacle or player

Arguments:
	1: startPos - Start position of the segment
	2: endPos - End position of the segment
	3: direction - Direction of the segment
	4: ignorePlayers[optional] - If it would need to hit a player, players in that table would be ignored. Keys must be players!
		Can be table of players or just player

Returns:
	1: isHit
	2: hitDistance - Distance from startPos to hit
	3: hitPos
	4: player - The player who was hitten (If exists)
---------------------------------------------------------------------------]]
function Ballistics:Hit(startPos, endPos, direction, ignorePlayers, velocity, projectile)
	if not startPos then return end
	ignorePlayers = ignorePlayers or {}

	local hit, dist = QueryRaycast(startPos, direction, VecLength(VecSub(startPos, endPos)))
	local hitPos
	if hit then
		hitPos = VecAdd(startPos, VecScale(VecNormalize(VecSub(endPos, startPos)), dist))
	end

	local ply -- closest
	local dist = math.huge

	--[[local isSingle = isPlayer(ignorePlayers) -- instead of checking in each step of the loop

	for steamid, player in pairs(players) do
		if isSingle and (player ~= ignorePlayers) or not isSingle and (not ignorePlayers[steamid]) then
			local pos = player:GetPos()
			local newDist = Distance(endPos, pos)
			if newDist < dist then
				dist = newDist
				ply = player
			end

			if player:IsMe() then
				local theDist = Distance(startPos, pos)
				local bulletPos = startPos
				if theDist > newDist then
					bulletPos = endPos
					theDist = newDist
				end

				if theDist <= flyByDist and player.LastFlyBy ~= projectile then
					if projectile.Type == Ballistics.Type.Bullet then
						PlaySound(Bullets_FlyBy_Sub[math.random(1,#Bullets_FlyBy_Sub)], VecLerp(startPos, endPos, .5), .3)

						if Distance(projectile.ShootPos, player:GetPos()) >= suppressDist then
							SetValue("SuppresionAmount", SuppresionAmount + .03, "linear", .5)
						end

						player.LastFlyBy = projectile
					end
				end
			end
		end
	end]]

	if not ply then
		return hit and {
			Dist = dist,
			HitPos = hitPos,
		}
	end

	local pos = ply:GetPos()

	local min, max = Vec(-.35, 0, -.35), Vec(.35, ply:IsCrouching() and 1.1 or 1.8, .35)

	local sphereBottom = VecAdd(pos, Vec(0,.35,0))
	local sphereCenter = VecAdd(pos, Vec(0,max[2]/2,0))
	local sphereTop = VecAdd(pos, Vec(0,max[2]-.35,0))
	local sIntersect, sMin, sM = IntersectSphere(startPos, direction, sphereBottom, .35)
	local sIntersect2, sMin2, sM2 = IntersectSphere(startPos, direction, sphereCenter, .35)
	local sIntersect3, sMin3, sM3 = IntersectSphere(startPos, direction, sphereTop, .35)
			

	local int1, int2, int3 = (sIntersect and math.abs(sMin) - velocity <= 3), (sIntersect2 and math.abs(sMin2) - velocity <= 3), (sIntersect3 and math.abs(sMin3) - velocity <= 3)
	if int1 or int2 or int3 then
		if hitPos then
			-- if player behind the wall
			if Distance(pos, startPos) >= Distance(hitPos, startPos) then
				return {
					Dist = dist,
					HitPos = hitPos,
				}
			end
		end

		return {
			Dist = finDist,
			HitPos = int1 and sphereBottom or int2 and sphereCenter or sphereTop,
			Player = ply,
			HitPart = sIntersect and "Legs" or sIntersect2 and "Body" or "Head",

			MakeHole = hit and hitPos or nil -- If we hit a vox as well, then make a hole inside it
		}
	else
		return hit and {
			Dist = dist,
			HitPos = hitPos,
		}
	end
end