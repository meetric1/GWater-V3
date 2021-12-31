AddCSLuaFile()

ENT.Type 			= "anim"
ENT.Category		= "GWater"
ENT.PrintName		= "Black Hole"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "GWater blackhole!"
ENT.AdminOnly		= true
ENT.Instructions	= ""
ENT.Spawnable		= true

function ENT:Initialize()
	if CLIENT then return end
	self:SetModel("models/hunter/misc/sphere075x075.mdl")
	self:SetMaterial("lights/white")
	self:SetColor(Color(0,0,0))
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
end