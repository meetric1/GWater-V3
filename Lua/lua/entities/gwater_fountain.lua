AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_fountain", {
	Category = "Emitters",
	Name = "Fountain",
	Material = "entities/gwater_fountain.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Fountain"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater fountain!"
ENT.Instructions	= ""
ENT.Editable		= true

function ENT:Initialize()
	self.Running = false
	if CLIENT then return end
	
	if WireLib then
		WireLib.CreateInputs(self, {"On (While this is 1, the bathtub will run)", "Toggle (When this is changed to 1, the bathtub is toggled)"})
		WireLib.CreateOutputs(self, {"Active"})
	end
	
	self:SetModel("models/props_c17/fountain_01.mdl")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:PhysWake()
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(1500)
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
	
	self.Running = true
	self:SetNWBool("Running", true)
	self:EmitSound("buttons/lever1.wav")
	
	if WireLib then Wire_TriggerOutput(self, "Active", 1) end
end

function ENT:TurnOff()
	if not self.Running then return end
	
	self.Running = false
	self:SetNWBool("Running", false)
	self:EmitSound("buttons/lever1.wav")
	
	if WireLib then Wire_TriggerOutput(self, "Active", 0) end
end

function ENT:Use()
	if self.Running then
		self:TurnOff()
	else
		self:TurnOn()
	end
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

		local drawColor = self:GetColor():ToVector()
		if drawColor == Vector(1, 1, 1) then
			drawColor = Vector(0.75, 1, 2)
		else
			drawColor = drawColor * 2
		end
		
		for i = 0, emul do
			local ang = self:LocalToWorldAngles(Angle(angle, i / emul * 360, 0))
			gwater.SpawnParticle(pos + ang:Forward() * emul * Vector(6, 6, 0), ang:Forward() * fmul, drawColor)
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