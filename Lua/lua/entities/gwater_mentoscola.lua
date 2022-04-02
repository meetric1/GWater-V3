AddCSLuaFile()

ENT.Type = "anim"

list.Set("gwater_entities", "gwater_mentoscola", {
	Category = "Emitters",
	Name = "Mentos with Cola",
	Material = "entities/gwater_mentoscola.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Mentos with Cola"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "OH NO"
ENT.AdminOnly		= false
ENT.Instructions	= ""
ENT.Editable 		= true

function ENT:Initialize()
	self.Running = false
	self.Started = false
	
	if CLIENT then
		return
	end
	
	if WireLib then
		WireLib.CreateInputs(self, {"On", "Toggle"})
		WireLib.CreateOutputs(self, {"Active"})
	end
	
	self.FlowSound = CreateSound(self, "PhysicsCannister.ThrusterLoop")
	self:SetModel("models/props_junk/garbage_glassbottle003a.mdl")
	self:SetMaterial("models/debug/env_cubemap_model")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	self.phys = self:GetPhysicsObject()
	self.phys:SetMass(10)
end

function ENT:Use()
	if self.Started then return end
	self.Started = true
	
	if self.Running then
		self.Running = false
		self.Started = false
		self.FlowSound:ChangeVolume(0, 1)
		self.FlowSound:Stop()
		self:SetNWBool("Running", self.Running)
		return
	end
	
	self:EmitSound("ambient/weather/rain_drip4.wav")
	
	timer.Simple(2, function()
		if not self:IsValid() then return end
		self.Started = false
		self.Running = true
		self:SetNWBool("Running", self.Running)
		self:SetNWInt("TimeSinceRun", CurTime())
		
		if self.Running then
			self.FlowSound:Play()
			self.FlowSound:ChangeVolume(1)
		else
			self.FlowSound:Stop()
		end
	end)
end

function ENT:TriggerInput(name, value)
	if name == "On" then
		if value == 1 then
			self:TurnOn()
		else
			self:TurnOff()
		end
	end
	if name == "Toggle" and value == 1 then
		self:Use(self)
	end
end

function ENT:TurnOn()
	if self.Running then return end
	
	self.Started = false
	self.Running = true
	self:SetNWBool("Running", self.Running)
	self:SetNWInt("TimeSinceRun", CurTime())
	
	self.FlowSound:Play()
	self.FlowSound:ChangeVolume(1)
	
	if WireLib then Wire_TriggerOutput(self, "Active", 1) end
end

function ENT:TurnOff()
	if not self.Running then return end
	
	self.Running = false
	self:SetNWBool("Running", self.Running)
	self.FlowSound:Stop()
	
	if WireLib then Wire_TriggerOutput(self, "Active", 0) end
end

function ENT:Use()
	if self.Running then
		self:TurnOff()
	else
		self:TurnOn()
	end
end

function ENT:OnRemove()
	if CLIENT then return end
	
	self.FlowSound:Stop()
	self.FlowSound = nil
end

function ENT:Think()
	local die = self:GetDieTime()
	local timesince = self:GetNWInt("TimeSinceRun")
	local dtunclamped = CurTime() - timesince
	local dt = math.Clamp(dtunclamped, 0, die)
	
	if SERVER then 
		if not self:GetNWBool("Running") then return end
		self.FlowSound:ChangeVolume(1 - dt / die)
		util.ScreenShake(self:GetPos(), die - dt, 20, 1, 1000)
		self.phys:ApplyForceCenter(-self:GetUp() * (1 - dt / die) * self.phys:GetMass() * 200 * self:GetForceMultiplier())
		
		if dtunclamped > die + 2 then
			self.Running = false
			self:SetNWBool("Running", self.Running)
			self.FlowSound:Stop()
		end
		
		return 
	end
	
	if not gwater then return end
	
	if self:GetNWBool("Running") then
		local pos = self:LocalToWorld(Vector(0, 0, 5))
		local ang = self:GetUp()

		local drawColor = self:GetColor():ToVector()
		if drawColor == Vector(1, 1, 1) then
			drawColor = Vector(0.75, 1, 2)
		else
			drawColor = drawColor * 2
		end
		
		for i=0, 5 - dt do
			gwater.SpawnParticle(pos + VectorRand(-8, 8), VectorRand(-1, 1) * 25 * (1 - dt / die), drawColor)
		end
		
		for i=0, 20 * (1 - dt / die) do
			gwater.SpawnParticle(self:LocalToWorld(Vector(0, 0, math.random(7, 20))), ang * 200 * (1 - dt / die), drawColor)
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.03)
end


function ENT:SetupDataTables()
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = 0, max = 60}})
	self:NetworkVar( "Float",	1, "DieTime",	{ KeyName = "DieTime",	Edit = { type = "Float", order = 2, min = 1, max = 20}})
	
	self:SetForceMultiplier(1)
	self:SetDieTime(6)
end