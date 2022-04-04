AddCSLuaFile()

-- create the render mesh for cloth entities
hook.Add("PreRender", "GWATER_RENDER_CLOTH", function()
	if not gwater or not gwater.HasModule then return end
	if gwater:GetTimescale() == 0 then return end

	local positions = gwater.GetClothData()	-- this is expensive as fuck
	clothCount = #positions
	if clothCount == 0 then return end

	for cloth = 1, clothCount do
		particleCount = #positions[cloth]

		-- recreate the mesh
		if gwater.renderMeshes[cloth] and gwater.renderMeshes[cloth]:IsValid() then
			gwater.renderMeshes[cloth]:Destroy()
			gwater.renderMeshes[cloth] = Mesh()
		else
			gwater.renderMeshes[cloth] = Mesh()
		end

		-- max vertices per mesh in source is 32768, because we are doing quads, we cannot have over 8192 triangles or we will crash
		-- I do no checks here because of debugging purposes, if a GetClothData() does not return n / 4 positions, than something is wrong.
		mesh.Begin(gwater.renderMeshes[cloth], MATERIAL_QUADS, math.Min(particleCount, 8192))
		for i = 1, math.Min(particleCount, 32768), 4 do
			mesh.Quad(positions[cloth][i], positions[cloth][i + 1], positions[cloth][i + 3], positions[cloth][i + 2])
		end
		mesh.End()
		gwater.renderMeshes[cloth]:Draw()
	end
end)
