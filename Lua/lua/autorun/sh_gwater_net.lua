-- AndrewEathan
-- Networking for GWater
AddCSLuaFile()

if SERVER then
	util.AddNetworkString("GWATER_SPAWNCUBE")
	util.AddNetworkString("GWATER_SPAWNSPHERE")
	util.AddNetworkString("GWATER_SPAWNCLOTH")
	util.AddNetworkString("GWATER_SWIMMING")
	util.AddNetworkString("GWATER_REMOVE")
	util.AddNetworkString("GWATER_NETWORKMAP")
	util.AddNetworkString("GWATER_REQUESTCOLOR")

	-- thanks kodya, very cool, speed will be used later in stuff like speed gels
	-- sadly easy to exploit, but still pretty awesome 
	net.Receive("GWATER_SWIMMING", function(len, ply)
		if not ply then return end
		local bool = net.ReadBool()
		local spd = net.ReadFloat()

		ply.GWATER_SWIMMING = bool
		ply.GWATER_SPEED = math.Clamp(spd, 0, 10)

		--tell clients to make the player look like they are swimming
		net.Start("GWATER_SWIMMING")
			net.WriteEntity(ply)
			net.WriteBool(bool)
		net.Broadcast()
	end)

	net.Receive("GWATER_REMOVE", function(len, ply)
		local pos = net.ReadVector()
		local r = math.Clamp(net.ReadInt(16), 1, 2500)

		net.Start("GWATER_REMOVE")
			net.WriteVector(pos)
			net.WriteInt(r, 16)
		net.Broadcast()
	end)

	net.Receive("GWATER_REQUESTCOLOR", function(len, ply)
		local col = net.ReadVector()
		ply.GWATER_COLOR = col
	end)
else
	hook.Add("GWaterInitialized", "GWater.Networking", function()
		local enablenetworking = gwater.Convars["enablenetworking"]
		local netlimit = gwater.Convars["maxnetparticles"]

		--cubes
		net.Receive("GWATER_SPAWNCUBE", function()
			if not gwater then return end
			local owner = net.ReadEntity()
			local pos = net.ReadVector()
			local wsize = net.ReadVector()
			local color = net.ReadVector()
			local sum = wsize.x + wsize.y + wsize.z

			if not enablenetworking:GetBool() and owner != LocalPlayer() then return end

			gwater.SpawnCube(pos + Vector(0, 0, gwater.GetRadius() * wsize.z), wsize, gwater.GetRadius() * 0.9, Vector(), color)
		end)

		--spheres
		net.Receive("GWATER_SPAWNSPHERE", function()
			if not gwater then return end
			local owner = net.ReadEntity()
			local pos = net.ReadVector()
			local wsize = net.ReadInt(8)
			local color = net.ReadVector()
			
			if not enablenetworking:GetBool() and owner != LocalPlayer() then return end

			gwater.SpawnSphere(pos + Vector(0, 0, gwater.GetRadius() * wsize * 1.5), wsize, gwater.GetRadius() * 0.9, Vector(), color)
		end)

		--cloth
		net.Receive("GWATER_SPAWNCLOTH", function()
			if not gwater or not gwater.HasModule then return end
			local owner = net.ReadEntity()
			local pos = net.ReadVector()
			local wsize = net.ReadUInt(2)

			if not enablenetworking:GetBool() and owner != LocalPlayer() then return end

			if wsize == 0 then
				gwater.SpawnCloth(pos + Vector(0, 0, gwater.GetRadius() * 5), 50, gwater.GetRadius() * 0.75, 1)
			elseif wsize == 1 then
				gwater.SpawnRigidbody(pos + Vector(0, 0, gwater.GetRadius() * 6), Vector(10, 10, 10), gwater.GetRadius(), true)
			else
				gwater.SpawnRigidbody(pos + Vector(0, 0, gwater.GetRadius() * 5), Vector(10, 10, 10), gwater.GetRadius(), false)
			end
		end)

		--remove
		net.Receive("GWATER_REMOVE", function()
			if not gwater or not gwater.HasModule then return end
			local pos = net.ReadVector()
			local radius = net.ReadInt(16)
			if radius == 0 then
				gwater.RemoveAll()
			else
				gwater.Blackhole(pos, radius)
			end
		end)
	end)

	net.Receive("GWATER_SWIMMING", function()
		local ply = net.ReadEntity()
		local swim = net.ReadBool()
		ply.GWATER_SWIMMING = swim
	end)
end


-- cool swimming animation & movement
-- by kodya, thanks, very cool

local gravity_convar = GetConVar("sv_gravity")

hook.Add("CalcMainActivity", "GWater.Swimming", function(ply)
	if not ply.GWATER_SWIMMING or ply:IsOnGround() then return end
	return ACT_MP_SWIM, -1
end)

hook.Add("Move", "GWater.Swimming", function(ply, move)
	if not ply.GWATER_SWIMMING or CLIENT then return end

	local vel = move:GetVelocity()
	local ang = move:GetMoveAngles()

	local acel =
	(ang:Forward() * move:GetForwardSpeed()) +
	(ang:Right() * move:GetSideSpeed()) +
	(ang:Up() * move:GetUpSpeed())

	local aceldir = acel:GetNormalized()
	local acelspeed = math.min(acel:Length(), ply:GetMaxSpeed()) * ply.GWATER_SPEED
	acel = aceldir * acelspeed * 2

	if bit.band(move:GetButtons(), IN_JUMP) ~= 0 then
	    acel.z = acel.z + ply:GetMaxSpeed() * ply.GWATER_SPEED
	end

	vel = vel + acel * FrameTime()
	vel = vel * (1 - FrameTime() * 2)

	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5
	vel.z = vel.z + FrameTime() * gravity

	move:SetVelocity(vel * 0.99)
end)

hook.Add("FinishMove", "GWater.Swimming", function(ply, move)
	if not ply.GWATER_SWIMMING then return end
	local vel = move:GetVelocity()
	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5

	vel.z = vel.z + FrameTime() * gravity
	move:SetVelocity(vel)
end)