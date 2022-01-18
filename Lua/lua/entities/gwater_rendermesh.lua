AddCSLuaFile()

--do not make cloth appear in multiplayer
if not game.SinglePlayer() then return end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater"
ENT.PrintName		= "Render_Mesh"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= true

local ID = 1
local renderMeshes = {}
function ENT:Initialize()
	self:DrawShadow(false)
	if CLIENT then
		self:SetRenderBounds(Vector(-32768, -32768, -32768), Vector(32768, 32768, 32768))

		if gwater and gwater.HasModule then
			gwater.SpawnCloth(LocalPlayer():GetEyeTrace().HitPos + Vector(0, 0, gwater.GetRadius() * 5), 46, gwater.GetRadius() * 0.75, 2)
		end

		self.ID = ID
		ID = ID + 1
	end

	self:SetPos(Vector())
	self:SetAngles(Angle())
end

function ENT:GetRenderMesh()
	if gwater and gwater.HasModule then
		return {Mesh = renderMeshes[self.ID], Material = gwater.Materials["z_cloth"]}
	end
end

function ENT:OnRemove()
	if CLIENT then
		timer.Simple(0, function()
			if not IsValid(self) then
				for k, v in ipairs(renderMeshes) do
					v:Destroy()
				end
				gwater.RemoveAll()
				renderMeshes = {}
				ID = 1
			end
		end)
	else
		for k, v in ipairs(ents.FindByClass("gwater_rendermesh")) do
			SafeRemoveEntity(v)
		end
	end
end

scripted_ents.Register(ENT, "gwater_rendermesh")

if SERVER then return end

--render the cloth
--local rendercvar = gwater.Convars["enablerendering"]
hook.Add("PostDrawTranslucentRenderables", "GWATER_RENDER_CLOTH", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
	if not gwater or not gwater.HasModule then return end
	if gwater:GetTimescale() == 0 then return end

	local positions = gwater.GetClothData()
	clothCount = #positions
	if clothCount == 0 then return end

	for cloth = 1, clothCount do
		particleCount = #positions[cloth]

		if renderMeshes[cloth] and renderMeshes[cloth]:IsValid() then
			renderMeshes[cloth]:Destroy()
			renderMeshes[cloth] = Mesh()
		else
			renderMeshes[cloth] = Mesh()
		end

		mesh.Begin(renderMeshes[cloth], MATERIAL_QUADS, math.Min(particleCount, 8192))
		for i = 1, math.Min(particleCount, 32768), 4 do
			mesh.Quad(positions[cloth][i], positions[cloth][i + 1], positions[cloth][i + 3], positions[cloth][i + 2])
		end
		mesh.End()
	end
end)
