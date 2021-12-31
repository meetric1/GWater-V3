-- AndrewEathan
-- Networking for GWater
AddCSLuaFile()

if SERVER then
	util.AddNetworkString("GWATER_SPAWNCUBE")
	util.AddNetworkString("GWATER_SPAWNSPHERE")
	util.AddNetworkString("GWATER_SWIMMING")

	local swimmers = {}
	--sadly easy to exploit, but still pretty awesome 
	net.Receive("GWATER_SWIMMING", function(len, ply)
		if not ply then return end
		local bool = net.ReadBool()
		if bool and ply:GetMoveType() == 2 then 
			ply:SetMoveType(4) 
			ply.GWATER_SWIMMING = true
			table.insert(swimmers, ply)
		else 
			if ply:GetMoveType() == 4 then
				ply:SetMoveType(2) 
			end
			ply.GWATER_SWIMMING = false 
		end
	end)

	hook.Add("Think", "GWATER_PLAYERS_SWIMMING", function()
		for k, v in ipairs(swimmers) do
			if not v or not v.GWATER_SWIMMING then 
				table.remove(swimmers, k) 
				break 
			end
			
			local addVel = Vector(0, 0, (v:KeyDown(IN_JUMP) and 1 or 0) * 20 - 1)
			v:SetVelocity(-v:GetVelocity() * 0.15 + addVel)	--setvelocity on players is actually apply force
		end
	end)
else
	hook.Add("GWaterInitialized", "GWater.Networking", function()
		local enablenetworking = gwater.Convars["enablenetworking"]
		local netlimit = gwater.Convars["maxnetparticles"]
	
		net.Receive("GWATER_SPAWNCUBE", function()
			if not gwater then return end
			gwater.NetworkParticleCount = gwater.NetworkParticleCount or 0
			local owner = net.ReadEntity()
			local pos = net.ReadVector()
			local wsize = net.ReadVector()
			local sum = wsize.x + wsize.y + wsize.z
			
			if sum > 30 then return end
			if (not enablenetworking:GetBool() or gwater.NetworkParticleCount + sum > netlimit:GetInt()) then return end
	
			gwater.NetworkParticleCount = gwater.NetworkParticleCount + sum
			gwater.SpawnCubeExact(pos, wsize, 10, Vector(0, 0, 0))
		end)
		
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
		
		print("[GWater]: Loaded networking!")
	end)
end