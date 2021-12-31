AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater"
ENT.PrintName		= "Bathtub"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater bathtub!"
ENT.Instructions	= ""
ENT.Spawnable		= true

function ENT:Initialize()
	self.Running = false
	if CLIENT then return end
	
	self.FlowSound = CreateSound(self, "ambient/water/water_flow_loop1.wav")
	
	self:SetModel("models/props_interiors/BathTub01a.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
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
		local pos = self:LocalToWorld(Vector(-30, 0, 25))
		local pos1 = self:LocalToWorld(Vector(-30, 12, 25))
		local ang = self:LocalToWorldAngles(Angle(90, 0, 0))
		local vel = self:GetVelocity()

		gwater.SpawnParticle(pos + VectorRand(-2, 2), ang:Forward() * 15 + VectorRand(-1, 1) / 4 + vel / 6)
		gwater.SpawnParticle(pos1 + VectorRand(-2, 2), ang:Forward() * 15 + VectorRand(-1, 1) / 4 + vel / 6)
	end
	
	self:SetNextClientThink(CurTime() + 0.05)
end