local MAX_CONVEXES_PER_PROP = 8
local MAX_COLLISIONS = 1000
local collisionAmount = 0
local propQueue = propQueue or {}
local sentQueue = sentQueue or {}

local margin = Vector(16, 16, 16)
local sentMaxAttempts = 256 --how many ticks can a SENT try to have a physprop?
local propQueueSpeed = 10 --how many entities can be validated per tick?

--Allow collisions for these brush entities
local movingBrushes = {
	func_door = true,
	func_door_rotating = true,
}
--ignore these SENTs for the SENT treatment, and treat them like regular props
local ignoreSENTs = {
	gwater_blackhole = true,
}

local function addPropMesh(prop)
	if collisionAmount > MAX_COLLISIONS then return end
	if not prop or not prop:IsValid() then return end
	--Handle SENTs by only their Physics collider
	if not ignoreSENTs[prop:GetClass()] and prop:GetPhysicsObject():IsValid() and prop:IsScripted() then
		--only use this for 
		for k, convex in pairs(prop:GetPhysicsObject():GetMeshConvexes()) do 
			local finalMesh = {}
			for k, tri in pairs(convex) do
				table.insert(finalMesh, tri.pos) 
			end
			gwater.AddConvexMesh(finalMesh, prop:OBBMins() - margin, prop:OBBMaxs() + margin, prop:GetPos(), prop:GetAngles())
			table.insert(gwater.Meshes, prop)
			collisionAmount = collisionAmount + 1
		end
		return
	end
	
	--Only use brush surfaces for brushes
	if movingBrushes[prop:GetClass()] then
		local finalMesh = {}
		for k, surfinfo in pairs(prop:GetBrushSurfaces()) do 
			local vertices = surfinfo:GetVertices()
			for i = 1, #vertices - 2 do
				local len = #finalMesh
				finalMesh[len + 1] = vertices[1]
				finalMesh[len + 2] = vertices[i+1]
				finalMesh[len + 3] = vertices[i+2]
				col = Color( 0, 255, 0, 255 )
				debugoverlay.Triangle(vertices[1], vertices[i+1], vertices[i+2], 20, col, true)
			end
		end
		gwater.AddConvexMesh(finalMesh, prop:OBBMins() - margin, prop:OBBMaxs() + margin, prop:GetPos(), prop:GetAngles())
		table.insert(gwater.Meshes, prop)
		collisionAmount = collisionAmount + 1
		return
	end
	
	local model = prop:GetModel()
	if not model then return end
	if not util.GetModelMeshes(model) then return end
	
	if prop:GetClass() == "gwater_blackhole" then
		gwater.SpawnForceField(prop:GetPos(), 750, -500, false, 1)
		table.insert(gwater.ForceFields, prop)
	end

	prop:PhysicsInit(6)	
	if not prop:GetPhysicsObject():IsValid() then 
		prop:PhysicsDestroy()
		print("[GWATER]: Failure to get physics mesh!")
		return 
	end

	if prop:GetPhysicsObject():IsValid() and #prop:GetPhysicsObject():GetMeshConvexes() < MAX_CONVEXES_PER_PROP then --physmesh
		for k, convex in pairs(prop:GetPhysicsObject():GetMeshConvexes()) do 
			local finalMesh = {}
			for k, tri in pairs(convex) do 
				table.insert(finalMesh, tri.pos) 
			end
			gwater.AddConvexMesh(finalMesh, prop:OBBMins() - margin, prop:OBBMaxs() + margin, prop:GetPos(), prop:GetAngles())
			table.insert(gwater.Meshes, prop)
			collisionAmount = collisionAmount + 1
		end
	else   --vismesh
		local finalMesh = {}
		for k, mesh in pairs(util.GetModelMeshes(model)) do
			for k, tri in pairs(mesh.triangles) do 
				table.insert(finalMesh, tri.pos)
			end
		end
		gwater.AddConcaveMesh(finalMesh, prop:OBBMins() - Vector(10), prop:OBBMaxs() + Vector(10), prop:GetPos(), prop:GetAngles())
		table.insert(gwater.Meshes, prop)
		collisionAmount = collisionAmount + 1
	end

	--remove physmesh on client, not for SENTs
	prop:PhysicsDestroy()
end

hook.Add("GWaterInitialized", "GWater.Collision", function()
	if not gwater or not gwater.HasModule then return end
	local whitelist = gwater.Whitelist
	
	local props = ents.GetAll()
	for k, v in ipairs(props) do
		if v:IsValid() and not v.GWATER_UPLOADED and whitelist[v:GetClass()] then 
			if v:IsScripted() and not v:GetPhysicsObject():IsValid() then --sents do phys only
				sentQueue[ v:EntIndex() ] = v
			else --not scripted ents dont matter, just add them
				table.insert(propQueue, v)
				v.GWATER_UPLOADED = true
			end
		end 
	end
	--adds props using OnEntityCreated hook
	hook.Add("OnEntityCreated", "GWater.EntityHandler", function(ent)
		if ent:IsValid() and not ent.GWATER_UPLOADED and whitelist[ent:GetClass()] then 
			if ent:IsScripted() and not ent:GetPhysicsObject():IsValid() then --sents do phys only
				sentQueue[ ent:EntIndex() ] = ent
			else --not scripted ents dont matter, just add them
				table.insert(propQueue, ent)
				ent.GWATER_UPLOADED = true
			end
		end 
	end)
	
	--update props, forcefields, and queue
	hook.Add("Think", "GWATER_UPDATE_COLLISION", function()
		--SENT queue, to make sure the physprop is valid.
		for k, v in pairs(sentQueue) do
			if not v:IsValid() or v.GWaterPhysAttempts == sentMaxAttempts then 
				--push prop anyway, if it takes too long, used to terminate, but that caused bugs
				sentQueue[k] = nil
				table.insert(propQueue, v)
				v.GWaterPhysAttempts = nil
				v.GWATER_UPLOADED = true
			elseif v:GetPhysicsObject():IsValid() then
				sentQueue[k] = nil
				table.insert(propQueue, v)
				v.GWaterPhysAttempts = nil
				v.GWATER_UPLOADED = true
			else
				v.GWaterPhysAttempts = (v.GWaterPhysAttempts or 0) + 1
			end
		end
		
		for k, v in ipairs(gwater.Meshes) do
			if not v:IsValid() or not whitelist[v:GetClass()] then 
				gwater.RemoveMesh(k)
				collisionAmount = collisionAmount - 1
				table.remove(gwater.Meshes, k)
				break
			end
			--always update SENTs, their velocity is often broken on the client
			if v:IsScripted() or movingBrushes[v:GetClass()] or (v:GetVelocity() ~= Vector()) then 
				gwater.SetMeshPos(v:GetPos(), v:GetAngles(), k)
			end
		end

		for k, v in ipairs(gwater.ForceFields) do
			if not v:IsValid() then 
				gwater.RemoveForceField(k)
				table.remove(gwater.ForceFields, k)
				break
			end

			if v:GetVelocity() == Vector() then continue end
			gwater.SetForceFieldPos(k - 1, v:GetPos());
		end
	
		for i = 1, propQueueSpeed do
			if not propQueue[1] then break end
			addPropMesh(propQueue[1])
			table.remove(propQueue, 1)
		end
	end)
end)