local MAX_CONVEXES_PER_PROP = 8
local propQueue = {}

local function addPropMesh(prop)
    if not prop or not prop:IsValid() then return end
    prop.GWATER_UPLOADED = true
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
		for k, convex in pairs( prop:GetPhysicsObject():GetMeshConvexes()) do 
			local finalMesh = {}
			for k, tri in pairs(convex) do 
                table.insert(finalMesh, tri.pos) 
            end
			gwater.AddConvexMesh(finalMesh, prop:OBBMins() - Vector(10), prop:OBBMaxs() + Vector(10), prop:GetPos(), prop:GetAngles())
			table.insert(gwater.Meshes, prop)
            print("[GWATER]: Added convex")
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
        print("[GWATER]: Added concave")
	end

    --remove physmesh on client
	prop:PhysicsDestroy()
end

hook.Add("GWaterInitialized", "GWater.Collision", function()
    if not gwater or not gwater.HasModule then return end
    local whitelist = gwater.Whitelist

    --add props every second
    timer.Create("GWATER_ADD_PROP", 1, 0, function()
        whitelist = gwater.Whitelist
        local props = ents.GetAll()
        for k, v in ipairs(props) do
            if v.GWATER_UPLOADED then continue end
            if not whitelist[v:GetClass()] then continue end
            table.insert(propQueue, v)
        end
    end)

    --update props, forcefields, and queue
    hook.Add("Think", "GWATER_UPDATE_COLLISION", function()
        for k, v in ipairs(gwater.Meshes) do
            if not v:IsValid() or not whitelist[v:GetClass()] then 
                gwater.RemoveMesh(k)
                print("[GWater]: Removed mesh " .. k)
                table.remove(gwater.Meshes, k)
                break
            end

            if v:GetVelocity() == Vector() then continue end
            gwater.SetMeshPos(v:GetPos(), v:GetAngles(), k);
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

        if not propQueue[1] then return end
        addPropMesh(propQueue[1])
        table.remove(propQueue, 1)
    end)
end)