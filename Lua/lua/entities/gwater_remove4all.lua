AddCSLuaFile()

ENT.Type 			= "point"
ENT.Base 			= "base_point"

list.Set("gwater_entities", "gwater_remove4all", {
	Category = "Quick Access",
	Name = "Remove water for all",
	Material = "entities/gwater_remove4all.png",
	AdminOnly = true
})

ENT.Category		= "GWater"
ENT.PrintName		= "Remove water for all"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "what else do you think this does lol"
ENT.AdminOnly		= true
ENT.Instructions	= ""
ENT.Editable 		= false
ENT.GWaterEntity 	= true
ENT.GWaterNotPhysical = true

function ENT:SpawnFunction(owner)
	if SERVER then
		net.Start("GWATER_REMOVE")
			net.WriteVector(Vector())
			net.WriteInt(0, 16)
		net.Broadcast()
	end
	
	return nil
end
scripted_ents.Register(ENT, "gwater_remove4all")