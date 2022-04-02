AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"

local xyz = {
	1,
	2,
	3,
	5,
	10,
	20
}

for k,v in ipairs(xyz) do
	local ENT = scripted_ents.Get("base_point")	
	ENT.Type = "point"
	ENT.Base = "base_point"
	ENT.PrintName = "Sphere (" .. v .. ")"
	ENT.Category = "GWater"
	ENT.Author = "Mee & AndrewEathan (with help from PotatoOS)"
	ENT.AdminOnly = (v == 20)
	
	function ENT:SpawnFunction(ply, tr, ClassName)
		net.Start("GWATER_SPAWNSPHERE")
			net.WriteEntity(ply)
			net.WriteVector(tr.HitPos)
			net.WriteInt(v, 8)
			net.WriteVector(ply.GWATER_COLOR or Vector(0.75, 1, 2))
		net.Broadcast()
		
		return nil
	end

	scripted_ents.Register(ENT, "gwater_sphere_" .. v)
	list.Set("gwater_entities", "gwater_sphere_" .. v, {
		Category = "Spheres",
		Name = "Sphere (" .. v .. ")",
		Material = "entities/gwater_sphere_" .. v .. ".png",
		AdminOnly = (v == 20) -- if it's the 20 size sphere, make it admin only
	})
end
