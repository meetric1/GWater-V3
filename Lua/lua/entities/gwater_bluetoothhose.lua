AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_bluetoothhose", {
	Category = "Emitters",
	Name = "Bluetooth Hose",
	Material = "entities/gwater_bluetoothhose.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Bluetooth Hose"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "wtflol"
ENT.Instructions	= ""

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Enabled")
end

function ENT:Initialize()
	if CLIENT then return end
	
	self:SetModel("models/props_c17/GasPipes006a.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:PhysWake()
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(20)
end

function ENT:Use()
	self:EmitSound("buttons/lever1.wav")
	self:SetEnabled(!self:GetEnabled())
end

function ENT:Think()
	if SERVER then return end
	if not gwater then return end
	
	if self:GetEnabled() then
		local pos = self:LocalToWorld(Vector(-7, 0, 25))
		local ang = self:LocalToWorldAngles(Angle(180, 0, 0))
		local vel = self:GetVelocity()

		local drawColor = self:GetColor():ToVector()
		if drawColor == Vector(1, 1, 1) then
			drawColor = Vector(0.75, 1, 2)
		else
			drawColor = drawColor * 2
		end

		gwater.SpawnParticle(pos + VectorRand(-2, 2), ang:Forward() * 15 + VectorRand(-1, 1) / 5 + vel / 8, drawColor)
	end
	
	self:SetNextClientThink(CurTime() + 0.05)
end