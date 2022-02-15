AddCSLuaFile()

ENT.Type			= "anim"

list.Set("gwater_entities", "gwater_blackhole", {
	Category = "Fun with Water",
	Name = "Black Hole",
	Material = "entities/gwater_blackhole.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Black Hole"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "GWater Blackhole! (only works on water)"
ENT.Instructions	= ""
ENT.AdminOnly 		= true
ENT.Editable		= true
ENT.GWaterEntity 	= true
ENT.SpawnOffset		= Vector(0, 0, 18)


function ENT:Initialize()
	if CLIENT then return end
	self:SetModel("models/hunter/misc/sphere075x075.mdl")
	self:SetMaterial("lights/white")
	
	self:SetColor(Color(0,0,0))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetModel("models/hunter/misc/sphere075x075.mdl")
	ent:SetMaterial("lights/white")
	ent:SetColor(Color(0,0,0))
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetPos(tr.HitPos + tr.HitNormal * 10)
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:SetupDataTables()
	self:NetworkVar( "Int",	0, "Radius",	{ KeyName = "Radius",	Edit = { type = "Int", order = 1, min = 100, max = 10000}})
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = -10, max = 10}})
	self:SetRadius(750)
	self:SetForceMultiplier(1)
end