-- AndrewEathan
-- Networking for GWater
AddCSLuaFile()

if SERVER then
	util.AddNetworkString("GWATER_SPAWNCUBE")
	util.AddNetworkString("GWATER_SPAWNSPHERE")
	util.AddNetworkString("GWATER_SWIMMING")
	util.AddNetworkString("GWATER_REMOVE")

	-- thanks kodya, very cool
	-- sadly easy to exploit, but still pretty awesome 
	net.Receive("GWATER_SWIMMING", function(len, ply)
		if not ply then return end
		local bool = net.ReadBool()
		local spd = net.ReadFloat()
		
		ply.GWATER_SWIMMING = bool
		ply.GWATER_SPEED = spd
		
		net.Start("GWATER_SWIMMING")
			net.WriteEntity(ply)
			net.WriteBool(bool)
			net.WriteFloat(math.Clamp(spd, 0, 8))
		net.Broadcast()
	end)
	
	net.Receive("GWATER_REMOVE", function(len, ply)
		local pos = net.ReadVector()
		local r = net.ReadInt(16)
		
		if ply:IsAdmin() then
			net.Start("GWATER_REMOVE")
				net.WriteVector(pos)
				net.WriteInt(r, 16)
			net.Broadcast()
		end
	end)
else
	hook.Add("GWaterInitialized", "GWater.Networking", function()
		local enablenetworking = gwater.Convars["enablenetworking"]
		local netlimit = gwater.Convars["maxnetparticles"]
	
		--cubes
		net.Receive("GWATER_SPAWNCUBE", function()
			if not gwater then return end
			gwater.NetworkParticleCount = gwater.NetworkParticleCount or 0
			local owner = net.ReadEntity()
			local pos = net.ReadVector()
			local wsize = net.ReadVector()
			local sum = wsize.x + wsize.y + wsize.z
			
			if sum > 60 then return end
			if (not enablenetworking:GetBool() or gwater.NetworkParticleCount + sum > netlimit:GetInt()) and owner ~= LocalPlayer() then return end
	
			gwater.NetworkParticleCount = gwater.NetworkParticleCount + sum
			gwater.SpawnCubeExact(pos, wsize, 10, Vector(0, 0, 0))
		end)
		
		--spheres
		net.Receive("GWATER_SPAWNSPHERE", function()
			if not gwater then return end
			gwater.NetworkParticleCount = gwater.NetworkParticleCount or 0
			local owner = net.ReadEntity()
			local pos = net.ReadVector()
			local wsize = net.ReadInt(8)
			
			if wsize > 20 then return end
			if (not enablenetworking:GetBool() or gwater.NetworkParticleCount + wsize * wsize * wsize > netlimit:GetInt()) and owner ~= LocalPlayer() then return end
			
			gwater.NetworkParticleCount = gwater.NetworkParticleCount + wsize * wsize * wsize
			gwater.SpawnSphere(pos, wsize, 10, Vector(0, 0, 0))
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
		local secr = net.ReadFloat()
		ply.GWATER_SWIMMING = swim
		ply.GWATER_SPEED = 0
	end)

	local water = false
	local water_last = false
	local water_sound_id = 0
	
	timer.Create("GWaterUpdateSwimming", 0.3, 0, function()
		if not gwater or not gwater.HasModule then return end
		water = gwater.ParticlesNear(EyePos(), 0.7) > 1
	end)
	
	hook.Add("Think", "GWater.Sound", function()
		if not gwater or not gwater.HasModule then return end
		
		if water ~= water_last then
			water_last = water
			LocalPlayer():SetDSP(water and 14 or 0)
			
			if water then
				water_sound_id = LocalPlayer():StartLoopingSound("ambient/water/underwater.wav")
			else
				LocalPlayer():StopLoopingSound(water_sound_id)
			end
		end
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
	if not ply.GWATER_SWIMMING then return end

    local vel = move:GetVelocity()
    local ang = move:GetMoveAngles()

    local acel = 
    (ang:Forward() * move:GetForwardSpeed()) +
    (ang:Right() * move:GetSideSpeed()) +
    (ang:Up() * move:GetUpSpeed())

    if bit.band(move:GetButtons(), IN_JUMP) ~= 0 then
        acel.z = acel.z + ply:GetMaxSpeed()
    end

    local aceldir = acel:GetNormalized()
    local acelspeed = math.min(acel:Length(), ply:GetMaxSpeed()) * ply.GWATER_SPEED
    acel = aceldir * acelspeed * 2

    vel = vel + acel * FrameTime()
    vel = vel * (1 - FrameTime() * 2)

   	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
    local gravity = pgrav * gravity_convar:GetFloat() * 0.5
    vel.z = vel.z + FrameTime() * gravity

    move:SetVelocity(vel)
end)

hook.Add("FinishMove", "GWater.Swimming", function(ply, move)
	if not ply.GWATER_SWIMMING then return end
    local vel = move:GetVelocity()
    local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
    local gravity = pgrav * gravity_convar:GetFloat() * 0.5
    
    vel.z = vel.z + (gravity + math.sin(CurTime() * 2) * 6) * FrameTime()
    move:SetVelocity(vel)
end)