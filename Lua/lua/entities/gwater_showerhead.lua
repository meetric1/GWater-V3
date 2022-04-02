AddCSLuaFile()

ENT.Base			= "base_gmodentity"
ENT.Type 			= "anim"

list.Set("gwater_entities", "gwater_showerhead", {
	Category = "Emitters",
	Name = "Shower Head",
	Material = "entities/gwater_showerhead.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Shower Head"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater showerhead!"
ENT.Instructions	= ""
ENT.Editable		= true

function ENT:Initialize()
	self.Running = false
	if CLIENT then return end
	
	if WireLib then
		WireLib.CreateInputs(self, {"On (While this is 1, the bathtub will run)", "Toggle (When this is changed to 1, the bathtub is toggled)"})
		WireLib.CreateOutputs(self, {"Active"})
	end
	
	self:SetModel("models/props_wasteland/prison_lamp001a.mdl")
	self:SetSkin(1)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end

	local ent = ents.Create(class)
	ent:SetModel("models/props_wasteland/prison_lamp001a.mdl")
	ent:SetSkin(1)
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetUseType(SIMPLE_USE)
	ent:SetPos(tr.HitPos + tr.HitNormal * 10)
	ent:Spawn()
	ent:Activate()

	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys:SetMass(50)
	end

	return ent
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
	
	Wire_TriggerOutput(self, "Active", 1)
end

function ENT:TurnOff()
	if not self.Running then return end
	
	self.Running = false
	self:SetNWBool("Running", false)
	self:EmitSound("buttons/lever1.wav")
	
	Wire_TriggerOutput(self, "Active", 0)
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
		local pos = self:LocalToWorld(Vector(0, 0, -20))
		local ang = self:LocalToWorldAngles(Angle(90, 0, 0))
		local vel = self:GetVelocity()
		local ppe = self:GetParticlesPerEmission()
		local fmul = self:GetForceMultiplier()

		local drawColor = self:GetColor():ToVector()
		if drawColor == Vector(1, 1, 1) then
			drawColor = Vector(0.75, 1, 2)
		else
			drawColor = drawColor * 2
		end

		for i = 0, ppe do
			gwater.SpawnParticle(pos + VectorRand(-8 + ppe, 8 - ppe), ang:Forward() * 25 * fmul + vel / 6, drawColor)
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