function GWaterSpawnEntity(ply, pos, ang, class)
	if not gamemode.Call("PlayerSpawnSENT", ply, class) then return end
	local ENT = scripted_ents.Get(class)
	
	if not ENT.GWaterEntity then return end
	local ent = ents.Create(class)
	if not ent then return print("[GWATER]: Tried to spawn " .. class .. ", but the entity couldn't be created!") end
	
	if ent.GWaterNotPhysical then
		ent:SpawnFunction(ply, {
			HitPos = pos
		}, class)
	
		ent:Remove()
	else
		ent:SetAngles(ang)
		ent:SetPos(pos + (ent.SpawnOffset or Vector()))
		ent:Spawn()
		ent:Activate()
	end
	
	if CPPI and IsValid(ent) then ent:CPPISetOwner(ply) end
	gamemode.Call("PlayerSpawnedSENT", ply, ent)
	return ent
end

function GWaterSpawnEntityWrapper(ply, class, trace)
	local args = string.Replace(class, "\"", "")
	local ENT = scripted_ents.Get(args)
	if not ENT then return print("[GWATER]: " .. ply:Nick() .. " tried to spawn an invalid GWater entity " .. args) end
	
	if ENT.GWaterEntity then
		local ang = ply:EyeAngles() + Angle(0, 180, 0)
		ang.p = 0
		ang.r = 0
		
		local ent = GWaterSpawnEntity(ply, trace.HitPos, ang, args)
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then phys:Sleep() end
		
		undo.Create("SENT")
			undo.SetPlayer(ply)
			undo.AddEntity(ent)
		undo.Finish("GWater " .. ENT.PrintName)
	end
end

concommand.Add("gwater_spawn_entity", function(ply, _, _, args)
	local trace = ply:GetEyeTraceNoCursor()
	GWaterSpawnEntityWrapper(ply, args, trace)
end)