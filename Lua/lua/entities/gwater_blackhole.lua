AddCSLuaFile()

ENT.Type			= "anim"

list.Set("gwater_entities", "gwater_blackhole", {
	Category = "Fun with Water",
	Name = "Black Hole",
	Material = "entities/gwater_blackhole.png",
	AdminOnly = true
})

ENT.Category		= "GWater"
ENT.PrintName		= "Black Hole"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "GWater Blackhole! (only works on water)"
ENT.Instructions	= ""
ENT.AdminOnly 		= true
ENT.Editable		= true


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
	ent:SetPos(tr.HitPos + tr.HitNormal * 50)
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Think()
	if SERVER or not gwater or not gwater.HasModule then return end
	for k, v in ipairs(gwater.ForceFields) do
		if v == self then
			gwater.EditForceField(k - 1, self:GetRadius(), self:GetForceMultiplier() * -500, true, 0)
			break
		end
	end

	self:SetNextClientThink(CurTime() + 1)
end


function ENT:SetupDataTables()
	self:NetworkVar( "Int",	0, "Radius",	{ KeyName = "Radius",	Edit = { type = "Int", order = 1, min = 100, max = 10000}})
	self:NetworkVar( "Float",	0, "ForceMultiplier",	{ KeyName = "ForceMultiplier",	Edit = { type = "Float", order = 1, min = -10, max = 10}})
	self:SetRadius(750)
	self:SetForceMultiplier(1)
end