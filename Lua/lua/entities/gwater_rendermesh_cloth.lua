AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_rendermesh_cloth", {
	Category = "Other Cool Stuff",
	Name = "Cloth",
	Material = "entities/gwater_cloth.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Cloth"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= ""
ENT.Instructions	= ""

--due to source lighting, we need an entity in the world to parent the mesh to
function ENT:Initialize()
	self:DrawShadow(false)	-- enabling this does weird shit because the prop is technically like, 32 thousand units wide and casts a map-wide shadow
	if CLIENT then
		if gwater and gwater.HasModule then
			self:SetRenderBoundsWS(Vector(), Vector(), Vector(32768, 32768, 32768)) 		-- just make it render anywhere
		end
		self.ID = #gwater.renderMeshes + 1
	end

	-- put it at 0,0,0 because 0,0,0 needs to be outside the world for the map to compile, and will result in proper lighting
	self:SetPos(Vector())
	self:SetAngles(Angle())
	self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
end

-- send cloth data to the client
function ENT:SpawnFunction(ply, tr, class, type)
	net.Start("GWATER_SPAWNCLOTH")
		net.WriteEntity(ply)
		net.WriteVector(tr.HitPos)
		net.WriteUInt(0, 2)
	net.Broadcast()

	local ent = ents.Create(class)
	ent:SetPos(Vector())
	ent:Spawn()
	ent:Activate()

	return ent
end

--update the mesh with the cloth data
function ENT:GetRenderMesh()
	if gwater and gwater.HasModule then
		return {Mesh = gwater.renderMeshes[self.ID], Material = gwater.Materials["z_cloth"]}
	end
end

--remove all cloth sents because the c++ data is in an array
--this can maybe be edited if I was smart and could manage data in a 1D array
--I tried for hours to try and think of a solution, but I couldnt
function ENT:OnRemove()
	if CLIENT then
		if gwater and gwater.HasModule then
			timer.Simple(0, function()
				if not IsValid(self) then
					for k, v in ipairs(gwater.renderMeshes) do
						v:Destroy()
					end
					gwater.RemoveAllCloth()
					table.Empty(gwater.renderMeshes)
				end
			end)
		end
	else
		for k, v in ipairs(ents.FindByClass("gwater_rendermesh_*")) do	-- die, other rendermeshes
			SafeRemoveEntity(v)
		end
	end
end
