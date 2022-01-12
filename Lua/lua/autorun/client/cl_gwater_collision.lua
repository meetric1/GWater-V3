local MAX_CONVEXES_PER_PROP = 8
local MAX_COLLISIONS = 1000
local collisionAmount = 0
local propQueue = propQueue or {}
local sentQueue = sentQueue or {}

local margin = Vector(16, 16, 16)
local propQueueSpeed = 3 --how many entities can be validated per tick?

local function addPropMesh(prop)
	if not prop or not prop:IsValid() then return end

	--handle sents 
	if prop:GetPhysicsObject():IsValid() then
		for k, convex in pairs(prop:GetPhysicsObject():GetMeshConvexes()) do 
			local finalMesh = {}
			for k, tri in pairs(convex) do
				table.insert(finalMesh, tri.pos) 
			end
			gwater.AddConvexMesh(finalMesh, prop:OBBMins() - margin, prop:OBBMaxs() + margin, prop:GetPos(), prop:GetAngles())
			table.insert(gwater.Meshes, prop)
		end
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
	end

	--remove physmesh on client, not for SENTs
	prop:PhysicsDestroy()
end

hook.Add("GWaterInitialized", "GWater.Collision", function()
	if not gwater or not gwater.HasModule then return end
	local whitelist = gwater.Whitelist
	
	--initially add props
	local props = ents.GetAll()
	for k, v in ipairs(props) do
		if v:IsValid() and not v.GWATER_UPLOADED and whitelist[v:GetClass()] then 
			table.insert(propQueue, v)
			v.GWATER_UPLOADED = true
		end 
	end
	--adds props using OnEntityCreated hook
	hook.Add("OnEntityCreated", "GWater.EntityHandler", function(ent)
		if ent:IsValid() and not ent.GWATER_UPLOADED and whitelist[ent:GetClass()] then 
			table.insert(propQueue, ent)
			ent.GWATER_UPLOADED = true
		end 
	end)
	
	--update props, forcefields, and queue
	hook.Add("Think", "GWATER_UPDATE_COLLISION", function()
		--update meshes
		for k, v in ipairs(gwater.Meshes) do
			if not v:IsValid() or not whitelist[v:GetClass()] then 
				gwater.RemoveMesh(k)
				table.remove(gwater.Meshes, k)
				break
			end
			--always update SENTs, their velocity is often broken on the client
			if v:IsScripted() or (v:GetVelocity() ~= Vector()) then 
				gwater.SetMeshPos(v:GetPos(), v:GetAngles(), k)
			end
		end

		--update forcefields (blackholes)
		for k, v in ipairs(gwater.ForceFields) do
			if not v:IsValid() then 
				gwater.RemoveForceField(k)
				table.remove(gwater.ForceFields, k)
				break
			end

			if v:GetVelocity() == Vector() then continue end
			gwater.SetForceFieldPos(k - 1, v:GetPos());
		end
		
		--add props through the queue
		for i = 1, propQueueSpeed do
			if not propQueue[1] then break end
			addPropMesh(propQueue[1])
			table.remove(propQueue, 1)
		end
	end)
end)