AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater"
ENT.PrintName		= "Toilet"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "wtflol"
ENT.Instructions	= ""
ENT.Spawnable		= true

function ENT:Initialize()
	self.Running = false
	if CLIENT then return end
	
	self.FlowSound = CreateSound(self, "ambient/water/water_flow_loop1.wav")
	
	self:SetModel("models/props_c17/FurnitureToilet001a.mdl")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(200)
end

function ENT:Use()
	self.Running = not self.Running
	self:SetNWBool("Running", self.Running)
	
	self:EmitSound("buttons/lever1.wav")
	if self.Running then
		self.FlowSound:Play()
	else
		self.FlowSound:Stop()
	end
end

function ENT:OnRemove()
	if CLIENT then return end
	
	self.FlowSound:Stop()
	self.FlowSound = nil
end

function ENT:Think()
	if SERVER then return end
	if not gwater then return end
	
	if self:GetNWBool("Running") then
		local pos = self:LocalToWorld(Vector(4, 0, -22))
		local ang = self:LocalToWorldAngles(Angle(-70, 0, 0))
		local vel = self:GetVelocity()

		gwater.SpawnParticle(pos + VectorRand(-2, 2), ang:Forward() * 15 + VectorRand(-1, 1) / 5 + vel / 8)
	end
	
	self:SetNextClientThink(CurTime() + 0.05)
end