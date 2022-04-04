AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_drain", {
	Category = "Fun with Water",
	Name = "Drain",
	Material = "entities/gwater_drain.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Drain"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Functional Drain!"
ENT.Instructions	= ""
ENT.Editable 		= true

function ENT:Initialize()
	if CLIENT then return end
	
	self:SetModel("models/xqm/button3.mdl")
	self:SetMaterial("phoenix_storms/Future_vents")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	self.MySound = CreateSound(self, "ambient/atmosphere/pipe1.wav")
	self.MySound:ChangeVolume(0.5)
	self.MySound:SetSoundLevel(60)
	self.MySound:Play()
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(50)
end

function ENT:Think()
	if SERVER then return end
	if not gwater or not gwater.HasModule then return end

	local res = gwater.Blackhole(self:GetPos(), 12)
	gwater.ApplyForceOutwards(self:GetPos(), -5 * self:GetForceMultiplier(), self:GetDrainRange(), false);
	
	if res > 0 then
		self:EmitSound("player/footsteps/slosh" .. math.random(1,4) .. ".wav", 75, math.random(90, 110), res / 5)
	end
	
	self:SetNextClientThink(CurTime() + 0.1)
end

function ENT:OnRemove()
	if CLIENT then return end
	self.MySound:Stop()
	self.MySound = nil
end

function ENT:SetupDataTables()
	self:NetworkVar( "Int",	0, "DrainRange",	{ KeyName = "EmitterCount",	Edit = { type = "Int", order = 1, min = 10, max = 200}})
	self:NetworkVar( "Float",	1, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = 0, max = 5}})
	self:SetDrainRange(50)
	self:SetForceMultiplier(1)
end