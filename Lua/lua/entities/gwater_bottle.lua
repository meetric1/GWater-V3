AddCSLuaFile()
local ENT = ENT or nil
if not ENT then ENT = scripted_ents.Get("base_anim") end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_bottle", {
	Category = "Emitters",
	Name = "Bottle",
	Material = "entities/gwater_bottle.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Bottle"
ENT.Author			= "AndrewEathan"
ENT.Purpose			= "Functional bottle!"
ENT.Instructions	= ""
ENT.Editable		= true
ENT.GWaterEntity 	= true
ENT.SpawnOffset		= Vector(0, 0, 8)

function ENT:Initialize()
	self.Running = false
	
	if CLIENT then 
		self.FlowSound = CreateSound(self, "ambient/water/leak_1.wav")
		self.FlowSound:Stop()
		return 
	end
	
	self:PrecacheGibs()
	self:SetModel("models/props_junk/garbage_glassbottle003a.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(20)
end

function ENT:Break(force)
	if SERVER then
		--self:GibBreakServer(force * 4)
		self:EmitSound("physics/glass/glass_bottle_break" .. math.random(1, 2) .. ".wav")
		self:Remove()
		local e = "Entity(" .. self:EntIndex() .. ")"
		
		BroadcastLua("if " .. e .. ".Break then " .. e .. ":Break(Vector(" .. force.x .. "," .. force.y .. ",".. force.z .. ")) end")
	else
		self:GibBreakClient(force * 2)
		
		if gwater then
			local drawColor = self:GetColor():ToVector()
			if drawColor == Vector(1, 1, 1) then
				drawColor = Vector(0.75, 1, 2)
			end
		
			for i = 1, self:GetBreakSpillAmount() do
				gwater.SpawnParticle(self:GetPos() + VectorRand(-10, 10), force / 3 + VectorRand(-1, 1) * force:Length() / 5, drawColor)
			end
		end
	end
end

function ENT:OnTakeDamage(damage)
	-- have to do some math since the damage force is wayyy too high
	local f = damage:GetDamageForce()
	local mag = f:Length()
	
	self:Break(f:GetNormalized() * math.Clamp(mag * 0.1, 0, 500))
end

function ENT:PhysicsCollide(col)
	if col.Speed > 100 then
		self:Break(col.OurOldVelocity * 0.5)
	end
end

local upvec = Vector(0, 0, -1)
function ENT:Think()
	if SERVER then return end
	if not gwater then return end
	local ang = self:GetAngles():Up()
	
	local last = self.Running
	self.Running = ang:Dot(upvec) > 0
	
	if self.Running then
		local pos = self:LocalToWorld(Vector(0, 0, 10))
		local ang = self:LocalToWorldAngles(Angle(90, 0, 0))
		
		local drawColor = self:GetColor():ToVector()
		if drawColor == Vector(1, 1, 1) then
			drawColor = Vector(0.75, 1, 2)
		end
		
		gwater.SpawnParticle(pos, -ang:Forward() * 10, drawColor)
	end
	
	if last ~= self.Running then
		if self.Running then
			self.FlowSound:Play()
		else
			self.FlowSound:Stop()
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.03 + (1 - ang:Dot(upvec)) / 4)
end

function ENT:OnRemove()
	if CLIENT and self.FlowSound then
		self.FlowSound:Stop()
		self.FlowSound = nil
	end
end

function ENT:SetupDataTables()
	self:NetworkVar( "Int",	0, "BreakSpillAmount",	{ KeyName = "BreakSpillAmount",	Edit = { type = "Int", order = 1, min = 1, max = 500}})
	self:SetBreakSpillAmount(100)
end

scripted_ents.Register(ENT, "gwater_bottle")