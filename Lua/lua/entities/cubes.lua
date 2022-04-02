AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"

local xyz = {
	Vector(2, 2, 2),
	Vector(3, 3, 3),
	Vector(5, 5, 5),
	Vector(10, 10, 10),
	Vector(20, 20, 20),
}

for k, v in ipairs(xyz) do
	local ENT = scripted_ents.Get("base_point")	
	ENT.Type = "point"
	ENT.Base = "base_point"
	ENT.AdminOnly = false
	ENT.PrintName = "Cube (" .. v.z .. ")"
	ENT.Category = "GWater"
	ENT.Author = "Mee & AndrewEathan (with help from PotatoOS)"
	
	function ENT:SpawnFunction(ply, tr, ClassName)
		net.Start("GWATER_SPAWNCUBE")
			net.WriteEntity(ply)
			net.WriteVector(tr.HitPos)
			net.WriteVector(v)
			net.WriteVector(ply.GWATER_COLOR or Vector(0.75, 1, 2))
		net.Broadcast()

		return nil
	end

	scripted_ents.Register(ENT, "gwater_cube_" .. v.z)
	list.Set("gwater_entities", "gwater_cube_" .. v.z, {
		Category = "Cubes",
		Name = "Cube (" .. v.z .. ")",
		Material = "entities/gwater_cube_" .. v.z .. ".png"
	})
end
