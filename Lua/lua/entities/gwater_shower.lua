AddCSLuaFile()

ENT.Type = "anim"

list.Set("gwater_entities", "gwater_shower", {
	Category = "Emitters",
	Name = "Shower",
	Material = "entities/gwater_shower.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Shower"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional GWater shower!"
ENT.Instructions	= ""
ENT.Editable		= true

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
	
	if WireLib then
		WireLib.CreateInputs(self, {"On (While this is 1, the bathtub will run)", "Toggle (When this is changed to 1, the bathtub is toggled)"})
		WireLib.CreateOutputs(self, {"Active"})
	end
	
	self:SetModel("models/props_wasteland/shower_system001a.mdl")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(50)
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
		local vel = self:GetVelocity()
		local fmul = self:GetForceMultiplier()

		local drawColor = self:GetColor():ToVector()
		if drawColor == Vector(1, 1, 1) then
			drawColor = Vector(0.75, 1, 2)
		else
			drawColor = drawColor * 2
		end

		for k,v in pairs(self.FlowAreas) do
			local pos = self:LocalToWorld(v[1])
			local ang = self:LocalToWorldAngles(v[2]) + Angle(0, 180, 0)
			gwater.SpawnParticle(pos + VectorRand(-1, 1), ang:Forward() * 25 * fmul + vel / 6, drawColor)
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.06)
end

function ENT:SetupDataTables()
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = 0, max = 10}})
	self:SetForceMultiplier(1)
end