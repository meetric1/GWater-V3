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
	ENT.Spawnable = true
	ENT.AdminOnly = k == 20 -- if it's the 20 size sphere, make it admin only
	ENT.PrintName = "Sphere (" .. v .. ")"
	ENT.Category = "GWater"
	ENT.Author = "Mee & AndrewEathan (with help from PotatoOS)"
	
	function ENT:SpawnFunction(ply, tr, ClassName)
		net.Start("GWATER_SPAWNSPHERE")
			net.WriteEntity(ply)
			net.WriteVector(tr.HitPos + Vector(0, 0, v * 12))
			net.WriteInt(v, 8)
		net.Broadcast()

		return nil
	end

	scripted_ents.Register(ENT, "gwater_sphere_" .. v)
end
