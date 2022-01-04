AddCSLuaFile()

ENT.Type 			= "anim"
ENT.Category		= "GWater"
ENT.PrintName		= "Black Hole"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "GWater blackhole!"
ENT.AdminOnly		= true
ENT.Instructions	= ""
ENT.Spawnable		= true

function ENT:Initialize()
	self:SetModel("models/hunter/misc/sphere075x075.mdl")
	self:SetMaterial("lights/white")
	self:SetColor(Color(0,0,0))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetModel("models/hunter/misc/sphere075x075.mdl")
	ent:SetMaterial("lights/white")
	ent:SetColor(Color(0,0,0))
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetPos(tr.HitPos + tr.HitNormal * 10)
	ent:Spawn()
	ent:Activate()

	return ent
end