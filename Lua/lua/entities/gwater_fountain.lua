AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater"
ENT.PrintName		= "Fountain"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater fountain!"
ENT.Instructions	= ""
ENT.Editable		= true
ENT.Spawnable		= true

function ENT:Initialize()
	self.Running = false
	
	if CLIENT then return end
	
	self.FlowSound = CreateSound(self, "ambient/water/water_flow_loop1.wav")
	self:SetModel("models/props_c17/fountain_01.mdl")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(150)
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
		local vel = self:GetVelocity()
		local emul = self:GetEmitterCount()
		local fmul = self:GetForceMultiplier()
		local angle = self:GetEmissionAngle()
		local pos = self:LocalToWorld(Vector(0, 0, 276))
		
		for i = 0, emul do
			local ang = self:LocalToWorldAngles(Angle(angle, i / emul * 360, 0))
			gwater.SpawnParticle(pos + ang:Forward() * emul * Vector(6, 6, 0), ang:Forward() * fmul)
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.06)
end

function ENT:SetupDataTables()
	self:NetworkVar( "Int",	0, "EmitterCount",	{ KeyName = "EmitterCount",	Edit = { type = "Int", order = 1, min = 3, max = 40}})
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = 0, max = 10}})
	self:NetworkVar( "Float",	1, "EmissionAngle",	{ KeyName = "EmissionAngle",	Edit = { type = "Float", order = 2, min = -90, max = -60}})
	self:SetEmitterCount(20)
	self:SetForceMultiplier(30)
	self:SetEmissionAngle(-85)
end

scripted_ents.Register(ENT, "gwater_fountain")