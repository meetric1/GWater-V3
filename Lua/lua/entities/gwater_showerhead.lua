AddCSLuaFile()

ENT.Type = "anim"

ENT.Category		= "GWater"
ENT.PrintName		= "Shower Head"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater showerhead!"
ENT.Instructions	= ""
ENT.Editable		= true
ENT.Spawnable		= true

function ENT:Initialize()
	self.Running = false
	if CLIENT then return end
	
	self.FlowSound = CreateSound(self, "ambient/water/water_flow_loop1.wav")
	self:SetModel("models/props_wasteland/prison_lamp001a.mdl")
	self:SetSkin(1)
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(50)
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
		local pos = self:LocalToWorld(Vector(0, 0, -20))
		local ang = self:LocalToWorldAngles(Angle(90, 0, 0))
		local vel = self:GetVelocity()
		local ppe = self:GetParticlesPerEmission()
		local fmul = self:GetForceMultiplier()

		for i = 0, ppe do
			gwater.SpawnParticle(pos + VectorRand(-8 + ppe, 8 - ppe), ang:Forward() * 25 * fmul + vel / 6)
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.06)
end

function ENT:SetupDataTables()
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = 0, max = 10}})
	self:NetworkVar( "Float",	1, "ParticlesPerEmission",	{ KeyName = "ParticlesPerEmission",	Edit = { type = "Float", order = 2, min = 1, max = 16}})
	
	self:SetForceMultiplier(1)
	self:SetParticlesPerEmission(4)
end