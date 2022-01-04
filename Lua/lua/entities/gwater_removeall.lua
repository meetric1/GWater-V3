AddCSLuaFile()

ENT.Type 			= "point"
ENT.Category		= "GWater"
ENT.PrintName		= "REMOVE ALL WATER"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "what else do you think this does lol"
ENT.AdminOnly		= false
ENT.Instructions	= ""
ENT.Editable 		= false
ENT.Spawnable		= true

print("fuck you")

function ENT:SpawnFunction(owner)
	if SERVER then
		net.Start("GWATER_REMOVE")
			net.WriteVector(Vector())
			net.WriteInt(0, 16)
		net.Broadcast()
	end
	
	return nil
end