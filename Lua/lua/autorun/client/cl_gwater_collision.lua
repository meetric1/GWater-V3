local MAX_CONVEXES_PER_PROP = 8
local MAX_COLLISIONS = 4096 - MAX_CONVEXES_PER_PROP - 1
local propQueue = propQueue or {}
local sentQueue = sentQueue or {}

local margin = Vector(16, 16, 16)
local propQueueSpeed = 8 --how many entities can be validated per tick?
local sentMaxAttempts = 256 --how many ticks to try to validate SENT physics?

--Allow collisions for these brush entities
--This is a whitelist
local allowedBrushEntities = {
	func_door = true,
	func_door_rotating = true,
	func_movelinear = true,
	func_tracktrain = true,
	func_wall = true,
	func_breakable = true,
	func_brush = true,
	func_detail = true,
	func_lod = true,
	func_rotating = true,
	func_physbox = true,
}

-- sent classes in which collisions are networked and are buffered
local sentWhitelist = {

}

local function addPropMesh(prop)
	if #gwater.Meshes > MAX_COLLISIONS then print("[GWATER]: Max mesh limit reached!") return end
	if not prop or not prop:IsValid() then return end

	if prop:IsScripted() and prop:GetPhysicsObject():IsValid() then
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

	if allowedBrushEntities[prop:GetClass()] then
		local finalMesh = {}
		local surfaces = prop:GetBrushSurfaces()
		if !surfaces or #surfaces == 0 then return end
		--combine all brush surfaces into a convex shape.
		for k, surfinfo in pairs(surfaces) do
			local vertices = surfinfo:GetVertices()
			--triangulate polygon shapes, use vertex 1 as "pivot"
			for i = 1, #vertices - 2 do
				local len = #finalMesh
				finalMesh[len + 1] = vertices[1]
				finalMesh[len + 2] = vertices[i + 1]
				finalMesh[len + 3] = vertices[i + 2]
			end
		end

		if #finalMesh == 0 then return end
		--add this concave shape, it may actually have holes frankly
		gwater.AddConcaveMesh(finalMesh, prop:OBBMins() - margin, prop:OBBMaxs() + margin, prop:GetPos(), prop:GetAngles())
		table.insert(gwater.Meshes, prop)
		return
	end

	--normal checking continues from here
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
		gwater.AddConcaveMesh(finalMesh, prop:OBBMins() - margin, prop:OBBMaxs() + margin, prop:GetPos(), prop:GetAngles())
		table.insert(gwater.Meshes, prop)
	end

	--remove physmesh on client, not for SENTs
	prop:PhysicsDestroy()
end

hook.Add("GWaterInitialized", "GWater.InitFunctions", function()
	if not gwater or not gwater.HasModule then return end
	--removes a prop from the collisison queue, allows it's collision to be re-evaluated with the function below this one
	function gwater.InvalidateCollision(ent)
		if not (ent and ent:IsValid()) then return end
		if not (ent.GWATER_UPLOADED and sentQueue[ent:EntIndex()]) then return end

		for k, v in ipairs(gwater.Meshes) do
			if ent == v then
				ent.GWATER_UPLOADED = nil
				gwater.RemoveMesh(k)
				table.remove(gwater.Meshes, k)
				break
			end
		end
	end

	--Add a prop to the collision queue
	function gwater.AddColliderToQueue( ent )
		if ent:IsValid() and not ent.GWATER_UPLOADED and (gwater.Whitelist[ent:GetClass()] or allowedBrushEntities[ent:GetClass()] ) then
			if ent:IsScripted() and not ent:GetPhysicsObject():IsValid() and sentWhitelist[ent:GetClass()] then --sents do phys only
				sentQueue[ ent:EntIndex() ] = ent
			else --not scripted ents dont matter, just add them
				table.insert(propQueue, ent)
				ent.GWATER_UPLOADED = true
			end
		end
	end

	-- adds a class to the special sent whitelist
	function gwater.AddSpecialSENTClass(class)
		if class then
			sentWhitelist[class] = true
		else
			print("[GWATER]: Invalid class!")
		end
	end
end)

hook.Add("GWaterPostInitialized", "GWater.Collision", function()
	if not gwater or not gwater.HasModule then return end

	--initially add props
	local props = ents.GetAll()
	for k, v in ipairs(props) do
		gwater.AddColliderToQueue( v )
	end

	--adds props using OnEntityCreated hook
	hook.Add("OnEntityCreated", "GWater.EntityHandler", function(ent)
		gwater.AddColliderToQueue( ent )
	end)

	--update props, forcefields, and queue
	hook.Add("Think", "GWATER_UPDATE_COLLISION", function()
		-- physgun pickup

		--SENT queue, to make sure the physprop is valid.
		for k, v in pairs(sentQueue) do
			if not v:IsValid() then sentQueue[k] = nil continue end
			if ( v.GWaterPhysAttempts == sentMaxAttempts ) or v:GetPhysicsObject():IsValid() then
				sentQueue[k] = nil
				table.insert(propQueue, v)
				v.GWaterPhysAttempts = nil
				v.GWATER_UPLOADED = true
			else 
				v.GWaterPhysAttempts = (v.GWaterPhysAttempts or 0) + 1
			end
		end

		--update meshes
		for k, v in ipairs(gwater.Meshes) do
			if not v:IsValid() or not ( gwater.Whitelist[v:GetClass()] or allowedBrushEntities[v:GetClass()] ) then
				gwater.RemoveMesh(k)
				table.remove(gwater.Meshes, k)
				continue
			end
			gwater.SetMeshPos(v:GetPos(), v:GetAngles(), k)
		end

		--update forcefields (blackholes)
		for k, v in ipairs(gwater.ForceFields) do
			if not v:IsValid() then
				gwater.RemoveForceField(k)
				table.remove(gwater.ForceFields, k)
				continue
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

	hook.Add("PreCleanupMap", "GWater_CleanMapFix", function()
		gwater.RemoveAll()
		for k, v in ipairs(gwater.Meshes) do
			gwater.RemoveMesh(1)
		end
		table.Empty(gwater.Meshes)
	end)
end)

