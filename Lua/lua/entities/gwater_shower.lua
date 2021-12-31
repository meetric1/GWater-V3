AddCSLuaFile()

ENT.Type = "anim"

ENT.Category		= "GWater"
ENT.PrintName		= "Shower"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater shower!"
ENT.Instructions	= ""
ENT.Editable		= true
ENT.Spawnable		= true

function ENT:Initialize()
	self.Running = false
	
	if CLIENT then
		self.FlowAreas = {
			{Vector(10,72,7), Angle(44,-69,-180)},
			{Vector(-24,43,8), Angle(44,-37,-180)},
			{Vector(-38,0,7), Angle(44,0,-180)},
			{Vector(-24,-44,7), Angle(44,32,-180)},
			{Vector(10,-73,7), Angle(44,68,-180)}
		}
		return
	end
	
	self.FlowSound = CreateSound(self, "ambient/water/water_flow_loop1.wav")
	self:SetModel("models/props_wasteland/shower_system001a.mdl")
	
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
		local vel = self:GetVelocity()
		local fmul = self:GetForceMultiplier()

		for k,v in pairs(self.FlowAreas) do
			local pos = self:LocalToWorld(v[1])
			local ang = self:LocalToWorldAngles(v[2]) + Angle(0, 180, 0)
			gwater.SpawnParticle(pos + VectorRand(-1, 1), ang:Forward() * 25 * fmul + vel / 6)
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.06)
end

function ENT:SetupDataTables()
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = 0, max = 10}})
	self:SetForceMultiplier(1)
end