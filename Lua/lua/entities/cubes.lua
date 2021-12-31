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
	ENT.Spawnable = true
	ENT.AdminOnly = false
	ENT.PrintName = "Cube (" .. v.z .. ")"
	ENT.Category = "GWater"
	ENT.Author = "Mee & AndrewEathan (with help from PotatoOS)"

	
	function ENT:SpawnFunction(ply, tr, ClassName)
		net.Start("GWATER_SPAWNCUBE")
			net.WriteEntity(ply)
			net.WriteVector(tr.HitPos + Vector(0, 0, v.z * 6))
			net.WriteVector(v)
		net.Broadcast()

		return nil
	end

	scripted_ents.Register(ENT, "gwater_cube_" .. v.z)
end
