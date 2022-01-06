AddCSLuaFile()

ENT.Type 			= "point"
ENT.Category		= "GWater"
ENT.PrintName		= "Remove water for me"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "what else do you think this does lol"
ENT.AdminOnly		= false
ENT.Instructions	= ""
ENT.Editable 		= false
ENT.Spawnable		= true

function ENT:SpawnFunction(owner)
	-- apparently somehow i don't have this in singleplayer? added a check just to be safe
	if owner.SendLua then
		owner:SendLua([[
			if gwater and gwater.HasModule then 
				gwater.NetworkParticleCount = 0 
				gwater.RemoveAll() 
			else 
				notification.AddLegacy("You don't have GWater, dummy!", NOTIFY_ERROR, 3) 
			end
		]])
	end

	
	return nil
end