AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater"
ENT.PrintName		= "Drain"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional Drain!"
ENT.Instructions	= ""
ENT.Spawnable		= true

function ENT:Initialize()
	if CLIENT then return end
	
	self:SetModel("models/xqm/button3.mdl")
	self:SetMaterial("phoenix_storms/Future_vents")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(50)
end

function ENT:Think()
	if SERVER then return end
	if not gwater then return end

	gwater.Blackhole(self:GetPos(), 12)
	gwater.ApplyForceOutwards(self:GetPos(), -5, 50, false);
	self:SetNextClientThink(CurTime() + 0.1)
end