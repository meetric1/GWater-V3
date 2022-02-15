AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_cloth", {
	Category = "Other Cool Stuff",
	Name = "Cloth",
	Material = "entities/gwater_cloth.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Cloth"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.GWaterEntity 	= true

--due to source lighting, we need an entity in the world to parent the mesh to
local renderMeshes = {}
function ENT:Initialize()
	print("horg")
	self:DrawShadow(false)	-- enabling this does weird shit because the prop is technically like, 32 thousand units wide and casts a map-wide shadow
	if CLIENT then
		self:SetRenderBounds(Vector(-32768, -32768, -32768), Vector(32768, 32768, 32768))	-- just make it render anywhere
		if gwater and gwater.HasModule then
			--gwater.SpawnRigidbody(LocalPlayer():GetEyeTrace().HitPos + Vector(0, 0, gwater.GetRadius() * 7), Vector(50, 2, 2), gwater.GetRadius())
			gwater.SpawnCloth(LocalPlayer():GetEyeTrace().HitPos + Vector(0, 0, gwater.GetRadius() * 5), 46, gwater.GetRadius() * 0.75, 1)
		end
		self.ID = #renderMeshes + 1
	end

	-- put it at 0,0,0 because 0,0,0 needs to be outside the world for the map to compile, and will result in proper lighting
	self:SetPos(Vector())
	self:SetAngles(Angle())
end

--update the mesh with the cloth data
function ENT:GetRenderMesh()
	self:SetPos(Vector())
	self:SetAngles(Angle())
	if gwater and gwater.HasModule then
		return {Mesh = renderMeshes[self.ID], Material = gwater.Materials["z_cloth"]}
	end
end

--remove all cloth sents because the c++ data is in an array
--this can maybe be edited if I was smart and could manage data in a 1D array
--I tried for hours to try and think of a solution, but I couldnt
function ENT:OnRemove()
	if CLIENT then
		timer.Simple(0, function()
			if not IsValid(self) then
				for k, v in ipairs(renderMeshes) do
					v:Destroy()
				end
				gwater.RemoveAllCloth()
				table.Empty(renderMeshes)
			end
		end)
	else
		for k, v in ipairs(ents.FindByClass("gwater_cloth")) do	-- die, other rendermeshes
			SafeRemoveEntity(v)
		end
	end
end

if SERVER then return end

-- create the render mesh for cloth entities
local time = 0
hook.Add("PostDrawTranslucentRenderables", "GWATER_RENDER_CLOTH", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
	if not gwater or not gwater.HasModule then return end
	if gwater:GetTimescale() == 0 then return end
	time = time % (1 / gwater.GetConfig("simFPS") * 120) + 1
	if time != 1 then return end

	local positions = gwater.GetClothData()	-- this is expensive as fuck and it would probably help if we updated the mesh every other frame
	clothCount = #positions
	if clothCount == 0 then return end

	for cloth = 1, clothCount do
		particleCount = #positions[cloth]

		-- recreate the mesh
		if renderMeshes[cloth] and renderMeshes[cloth]:IsValid() then
			renderMeshes[cloth]:Destroy()
			renderMeshes[cloth] = Mesh()
		else
			renderMeshes[cloth] = Mesh()
		end

		-- max vertices per mesh in source is 32768, because we are doing quads, we cannot have over 8192 triangles or we will crash
		-- I do no checks here because of debugging purposes, if a GetClothData() does not return n / 4 positions, than something is wrong.
		mesh.Begin(renderMeshes[cloth], MATERIAL_QUADS, math.Min(particleCount, 8192))
		for i = 1, math.Min(particleCount, 32768), 4 do
			mesh.Quad(positions[cloth][i], positions[cloth][i + 1], positions[cloth][i + 3], positions[cloth][i + 2])
		end
		mesh.End()
	end
end)
