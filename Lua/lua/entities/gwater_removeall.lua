AddCSLuaFile()

ENT.Type 			= "point"

list.Set("gwater_entities", "gwater_removeall", {
	Category = "Quick Access",
	Name = "Remove water for me",
	Material = "entities/gwater_removeall.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Remove water for me"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "what else do you think this does lol"
ENT.AdminOnly		= false
ENT.Instructions	= ""
ENT.Editable 		= false
ENT.GWaterEntity 	= true
ENT.GWaterNotPhysical = true

function ENT:SpawnFunction(owner)
	-- apparently somehow i don't have this in singleplayer? added a check just to be safe
	if owner.SendLua then
		owner:SendLua([[
			if gwater and gwater.HasModule then 
				gwater.NetworkParticleCount = 0 
				gwater.RemoveAll() 
			else 
				notification.AddLegacy("You don't have the GWater module! Please check if you've set it up right.", NOTIFY_ERROR, 3) 
			end
		]])
	end

	
	return nil
end