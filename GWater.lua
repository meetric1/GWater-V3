local math_sin = math.sin
local math_cos = math.cos
local math_rad = math.rad

local lp = LocalPlayer()
local meshes = {}
local data, particleCount
local gwaterRadius = 10

local function quatUnpack(q)
	return q[1], q[2], q[3], q[4]
end

-- We're gonna make this one not self-modify for the sake of sanity
local function getQuatMul(lhs, rhs)
	local lhs1, lhs2, lhs3, lhs4 = quatUnpack(lhs)
	local rhs1, rhs2, rhs3, rhs4 = quatUnpack(rhs)
	return {
		lhs1 * rhs1 - lhs2 * rhs2 - lhs3 * rhs3 - lhs4 * rhs4,
		lhs1 * rhs2 + lhs2 * rhs1 + lhs3 * rhs4 - lhs4 * rhs3,
		lhs1 * rhs3 + lhs3 * rhs1 + lhs4 * rhs2 - lhs2 * rhs4,
		lhs1 * rhs4 + lhs4 * rhs1 + lhs2 * rhs3 - lhs3 * rhs2
	}
end

local function quatFromAngleComponents(p, y, r)
	p = math_rad(p) * 0.5
	y = math_rad(y) * 0.5
	r = math_rad(r) * 0.5

	return getQuatMul( { math_cos(y), 0, 0, math_sin(y) }, getQuatMul( { math_cos(p), 0, math_sin(p), 0 }, { math_cos(r), math_sin(r), 0, 0 } ) )
end

local function quatFromAngle(ang)
	return quatFromAngleComponents(ang[1], ang[2], ang[3])
end

local function unfuckQuat(q)
    return { q[2], q[3], q[4], q[1] }
end


local function triangulateWorld()
  local surfaces = game.GetWorld():GetBrushSurfaces()
	local m = {}

	for i = 1, #surfaces do
      if surfaces[i]:IsNoDraw() then continue end

      local surface = surfaces[i]:GetVertices()
      for i = 3, #surface do
        local len = #m
        m[len + 1] = Vector(surface[1].x, surface[1].y, surface[1].z)
        m[len + 2] = Vector(surface[i - 1].x, surface[i - 1].y, surface[i - 1].z)
        m[len + 3] = Vector(surface[i].x, surface[i].y, surface[i].z)

	  	end

	end
	  
	  return m
end

--potatofunc
local function addPropMesh(prop)
    local model = prop:GetModel()
	if !util.GetModelMeshes(model) then prop.GWATER_UPLOADED = true return end

	prop:PhysicsInit(6)	--SOLID_VPHYSICS

	if(#prop:GetPhysicsObject():GetMeshConvexes() < 8) then

		--physmesh
		for _, convex in pairs( prop:GetPhysicsObject():GetMeshConvexes() ) do 
			local chonker_mesh = {}
			for _, tri in pairs(convex) do 
				table.insert( chonker_mesh, tri.pos )
			end

			gwater.AddConvexMesh(chonker_mesh, prop:OBBMins() - Vector(10, 10, 10), prop:OBBMaxs() + Vector(10, 10, 10))
			table.insert(meshes, prop)
		end

	else 

		local chonker_mesh = {}
		--vismesh
		for _, mesh in pairs( util.GetModelMeshes(model) ) do -- combine all model meshes into the chonker mesh
			for _, tri in pairs( mesh.triangles ) do
				table.insert( chonker_mesh, tri.pos )
			end
		end

		gwater.AddConcaveMesh(chonker_mesh, prop:OBBMins() - Vector(10, 10, 10), prop:OBBMaxs() + Vector(10, 10, 10))
		table.insert(meshes, prop)
	end

	prop:PhysicsDestroy()	--just removes physmesh

	prop.GWATER_UPLOADED = true
	prop.GWATER_LASTPOS = Vector()
end

if(!_G.gwater)then
	require("GWater_Rewrite")

	--world mesh--
	gwater.AddConcaveMesh(triangulateWorld(), Vector(-33000, -33000, -33000), Vector(33000, 33000, 33000))
end

--material
GWATER_MAT = Material("effects/circle2")		--phoenix_storms/blue_steel

--update particles
hook.Add("Think", "GWATER_PARTICLE_UPDATE", function()
	if(!lp or !lp:IsValid() or not gwater) then return end
	if(lp:Alive() and lp:GetActiveWeapon():GetClass() == "weapon_crowbar") then
		--attack1
		if lp:KeyDown(1) then
			for i = 1, 10 do
				gwater.SpawnParticle(LocalPlayer():GetPos() + Vector(0, 0, 63) + lp:EyeAngles():Forward() * 100 + VectorRand(-15, 15) , lp:EyeAngles():Forward() * 100)
			end
		end

		--attack2
		if lp:KeyDown(2048) then
			gwater.SpawnParticle(LocalPlayer():GetPos() + Vector(0, 0, 63) + lp:EyeAngles():Forward() * 100 + VectorRand(-1, 1) , Vector())
		end

		--reload
		if lp:KeyDown(8192) then
			gwater.RemoveAll()
		end
	end

	for i, mesh in ipairs(meshes) do
		if !mesh:IsValid() then 
			print("[GWATER]: Removing mesh " .. i)
			gwater.RemoveMesh(i)
			table.remove(meshes, i)
			break
		end

		if mesh.GWATER_LASTPOS == mesh:GetPos() then continue end

		local newQuat = unfuckQuat( quatFromAngle( mesh:GetAngles() ) )
		gwater.SetMeshPos(newQuat[4], Vector(newQuat[1], newQuat[2], newQuat[3]), mesh:GetPos(), i);

		--mesh.LASTPOS = mesh.LASTPOS + (mesh:GetPos() - mesh.LASTPOS):GetNormalized()

	end

end)

--update props
timer.Create("GWATER_ADD_PROP", 1, 0, function()
	local props = ents.GetAll()
	for i = 1, #props do
		local prop = props[i]
		if prop.GWATER_UPLOADED then 
			continue 
		end
		if prop:GetClass() == "prop_physics" then
			addPropMesh(prop) 
		end

	end


end)

local WATER_COLOR = Color(0, 0, 255)
local MAX_RANGE = 500 -- Range for gwater particles to be rendered
MAX_RANGE = MAX_RANGE * MAX_RANGE
 
--draw particles
hook.Add("PostDrawOpaqueRenderables", "GWATER_RENDER", function()
	data, particleCount = gwater.GetData(lp:EyePos(), lp:EyeAngles():Forward())
	render.SetMaterial(GWATER_MAT)
	render.DrawSprite(Vector(0, 0, 0), 100, 100, Color( 255, 255, 255 ) )
 
	for i=1, math.min(particleCount, 18000) do
		--local particlePos = data[i]
		--if (particlePos-EyePos()):GetNormalized():Dot(EyeVector()) < 0.75 then continue end
 
		--if (particlePos:DistToSqr(EyePos()) > MAX_RANGE) then continue end
		render.DrawSprite(data[i], gwaterRadius, gwaterRadius, WATER_COLOR)
		--render.DrawSphere(particlePos, GWATER_RADIUS / 1.5, 3, 3)
		--render.DrawBox(particlePos, Angle(0, 0, 0), Vector(-5), Vector(5))
	end
 
end)

--particle count
hook.Add( "HUDPaint", "GWATER_SCORE", function() 
	draw.DrawText(tostring(particleCount), "TargetID", ScrW() * 0.99, ScrH() * 0.01, color_white, TEXT_ALIGN_RIGHT )
end )

--chat commands
hook.Add("OnPlayerChat", "GWATER_CHAT", function(ply, str) 
    if (ply != LocalPlayer()) then return end
	local str = string.lower(str)

	local s = string.Split(str, " ")

	if (s[1] == "-radius" ) then 
		gwaterRadius = tonumber(s[2]) or 10
		gwater.SetRadius(gwaterRadius) 
	end
end )
