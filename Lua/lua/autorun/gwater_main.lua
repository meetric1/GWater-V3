AddCSLuaFile()

if SERVER then
	
	net.Receive("GWATER_NETWORKMAP", function(len, ply)
		
		if not ply.GWATER_DownloadedMap then --only allow this once, to prevent lag
			print("[GWATER]: Downloading physicsmap")
			downloadMapToPlayer(ply)
		end
		ply.GWATER_DownloadedMap = true
		
	end)
	
	function downloadMapToPlayer(ply)
		local Buffer = Entity(0):GetPhysicsObject():GetMeshConvexes()
		local maxConvexesPerNet = 32
		local totaltris = 0
		local unreliable = false
		net.Start("GWATER_NETWORKMAP", unreliable)
		net.WriteUInt(0, 8) --start
		net.WriteUInt(#Buffer, 16)
		net.Send(ply)
		hook.Add("Tick", "downloader"..ply:EntIndex(), function() 
			local counter = 0 
			--print("s", net.BytesLeft()) net.BytesLeft() > 10000 and 
			while counter < maxConvexesPerNet and #Buffer ~= 0 do
				nextBrush = table.remove(Buffer)
				net.Start("GWATER_NETWORKMAP", unreliable)
				net.WriteUInt(1, 8) --blob
				net.WriteUInt(#nextBrush, 32)
				counter = counter + 1
				for i = 1, #nextBrush do
					--net.WriteVector(nextBrush[ i ].pos)
					local vert = nextBrush[ i ].pos
					net.WriteInt(vert.x, 16)
					net.WriteInt(vert.y, 16)
					net.WriteInt(vert.z, 16)
					totaltris = totaltris + 1
				end
				net.Send(ply)
			end
			if #Buffer == 0 then 
				hook.Remove("Tick", "downloader"..ply:EntIndex())
				net.Start("GWATER_NETWORKMAP", unreliable)
				net.WriteUInt(2, 8) --finish
				net.WriteUInt(totaltris, 32)
				net.Send(ply) 
			end
		end)
	end
	--[[
	local worldmesh = Entity(0):GetPhysicsObject():GetMeshConvexes()
	print("convexes:", #worldmesh)
	local z = 0
	for i = 1, #worldmesh do
		local convex = worldmesh[ i ]
		local col = ColorRand() col.a = 64
		for j = 0, (#convex / 3) - 1 do
			local normal = -((convex[2+j*3].pos - convex[1+j*3].pos):Cross(convex[3+j*3].pos - convex[1+j*3].pos))
			normal:Normalize()
			z = z + 1
			debugoverlay.Triangle(convex[1+j*3].pos + normal, convex[2+j*3].pos + normal, convex[3+j*3].pos + normal, 10, col, false)
		end
	end
	--]]--
	--print("vertex count:", z, table.Count(uniques))
end

if SERVER then return end

--unused
--[[
local function triangulateWorld()
	local surfaces = game.GetWorld():GetBrushSurfaces()
	local m = {}

	for i = 1, #surfaces do
		if surfaces[i]:IsNoDraw() then continue end

		local surface = surfaces[i]:GetVertices()
		local vcount = #surface

		if vcount == 3 then
			local len = #m
			m[len + 1] = surface[1]
			m[len + 2] = surface[2]
			m[len + 3] = surface[3]
			
			--local col = ColorRand() col.a = 64
			--debugoverlay.Triangle(surface[1], surface[2], surface[3], 10, col, false)
		elseif vcount == 4 then
			local len = #m
			m[len + 1] = surface[1]
			m[len + 2] = surface[2]
			m[len + 3] = surface[3]
			m[len + 4] = surface[1]
			m[len + 5] = surface[3]
			m[len + 6] = surface[4] 
			
			--local col = ColorRand() col.a = 64
			--debugoverlay.Triangle(surface[1], surface[2], surface[3], 10, col, false)
			--debugoverlay.Triangle(surface[1], surface[3], surface[4], 10, col, false)
		else
			
			--local col = ColorRand() col.a = 64
			for i = 1, vcount - 2 do
				local len = #m
				m[len + 1] = surface[1]
				m[len + 2] = surface[i+1]
				m[len + 3] = surface[i+2]
				
				--debugoverlay.Triangle(surface[1], surface[i+1], surface[i+2], 1, col, false)
			end
		end
	end
	  
	return m
end
]]--


--file.exists only works on 64bit?
local function loadGWater()
	if file.Exists("lua/bin/gmcl_GWater_win64.dll", "MOD") and file.Exists("lua/bin/gmcl_GWater_win32.dll", "MOD") then 
		require("GWater") 
		
		if not LocalPlayer().GWATER_DownloadedMap then 
			timer.Simple(4, function()
				net.Start("GWATER_NETWORKMAP")
				print("[GWATER]: Acquiring physicsmap")
				net.SendToServer()
			end)
			
			local Vertices = {}
			
			local brushesToGo = 0
			local brushesProcessed = 0
			local brushesProcessedBar = 0 
			
			local startTime = CurTime()
			
			net.Receive("GWATER_NETWORKMAP", function(len, ply)
				msg = net.ReadUInt(8)
				if msg == 0 then
					brushesToGo = net.ReadUInt(16)
					hook.Add("HUDPaint", "GWATER_MAPDL", function() 
						
						brushesProcessedBar = math.ceil(brushesProcessedBar * 0.9 + brushesProcessed * 0.1)
						
						surface.SetDrawColor(0, 0, 0, 127)
						surface.DrawRect(ScrW() * 0.5 - 128, ScrH() * 0.01, 256, 16)
						surface.SetDrawColor(0, 0, 255, 191)
						surface.DrawRect(ScrW() * 0.5 - 128, ScrH() * 0.01, 256 * brushesProcessedBar / brushesToGo, 16)
						
						draw.DrawText(brushesProcessedBar.."/"..brushesToGo.."\nDownloading map convexes", "TargetID", ScrW() * 0.5, ScrH() * 0.01, color_white, TEXT_ALIGN_CENTER)
						
					end)
				elseif msg == 1 then
					brushesProcessed = brushesProcessed + 1
					local VertexCount = net.ReadUInt(32)
					for i = 1, VertexCount do
						local x = net.ReadInt(16)
						local y = net.ReadInt(16)
						local z = net.ReadInt(16)
						table.insert(Vertices, Vector(x, y, z)) 
					end
					--print(VertexCount)
				elseif msg == 2 then
					local TotalTris = net.ReadUInt(32)
					local endTime = CurTime()
					local deltaTime = endTime - startTime
					local text = "[GWATER]: Finished downloading map convexes.\nDownloaded "..#Vertices.."/"..TotalTris.." Vertices\nThis took "..string.format("%.3f Seconds",deltaTime)
					print(text)
					
					hook.Add("HUDPaint", "GWATER_MAPDL", function() 
						local timeSinceFinished = CurTime() - endTime
						local ease = ((timeSinceFinished / 5) ^ 4) * 64
						brushesProcessedBar = math.ceil(brushesProcessedBar * 0.9 + brushesProcessed * 0.1)
						
						surface.SetDrawColor(0, 0, 0, 127)
						surface.DrawRect(ScrW() * 0.5 - 128, ScrH() * 0.01 - ease * 0.5, 256, 16)
						surface.SetDrawColor(0, 0, 255, 191)
						surface.DrawRect(ScrW() * 0.5 - 128, ScrH() * 0.01 - ease * 0.5, 256 * brushesProcessedBar / brushesToGo, 16)
						
						draw.DrawText(text, "TargetID", ScrW() * 0.5, ScrH() * 0.01 - ease, color_white, TEXT_ALIGN_CENTER)
						
					end)
					timer.Simple(5, function() hook.Remove("HUDPaint", "GWATER_MAPDL") end)
					--gwater.AddConcaveMesh({Vector(),Vector(),Vector()}, Vector(-1, -1, -1), Vector(1, 1, 1), Vector(), Angle())
					gwater.AddConcaveMesh(Vertices, Vector(-33000, -33000, -33000), Vector(33000, 33000, 33000), Vector(), Angle())
					
					for i = 0, #Vertices / 3 - 1 do
						debugoverlay.Triangle(Vertices[1+i*3], Vertices[2+i*3], Vertices[3+i*3], 10, Color(255,0,255,64), false)
					end
					--Initialise after map download
					hook.Run("GWaterInitialized")
					hook.Run("GWaterPostInitialized")
					
				end
			end)
		end
		
		LocalPlayer().GWATER_DownloadedMap = true
		
		--gwater.AddConcaveMesh(triangulateWorld(), Vector(-33000, -33000, -33000), Vector(33000, 33000, 33000), Vector(), Angle())
		print("[GWATER]: Loaded module!")
		
		gwater.Whitelist = {
			prop_physics = true,
			prop_effect = true,
			gwater_sink = true,
			gwater_shower = true,
			gwater_fountain = true,
			gwater_blackhole = true,
			gwater_bathtub = true,
			player = true,
			func_door = true,
		}
		
		gwater.NetworkParticleCount = 0
		gwater.Meshes = {}
		gwater.ForceFields = {}
		gwater.HasModule = true
		hook.Run("GWaterInitialize")
		hook.Run("GWaterPostInitialized")
		
		gwater.Material = gwater.Materials["water"]

		if gwater.GetModuleVersion() ~= gwater.GetModuleVersionForLua() then
			gwater.HasModule = false
			gwater.ModuleVersionMismatch = true
			print("[GWATER]: Module version is v" .. gwater.GetModuleVersion() .. ", but i need v" .. gwater.GetModuleVersionForLua() .. "!")
		end
		
		print("[GWATER]: Successfully initialized!")
	else
		gwater = {}
		gwater.HasModule = false
		gwater.NetworkParticleCount = 0
		hook.Run("GWaterInitialize")
		hook.Run("GWaterPostInitialized")
		if game.SinglePlayer() then
			LocalPlayer():ConCommand("gwater_menu")
		end
		
		print("[GWATER]: No DLL found!")
	end
end

hook.Add("Think", "GWATER_INITIALIZE", function()
	hook.Remove("Think", "GWATER_INITIALIZE")
	loadGWater()
	--hook.Run("GWaterInitialized")
	--hook.Run("GWaterPostInitialized")
end)

--Add menu button to utilities tab
hook.Add("PopulateToolMenu", "GWATER_MENU", function()
	spawnmenu.AddToolMenuOption("Utilities", "GWater", "GWater", "#GWater", "", "", function(panel)
		panel:ClearControls()
		panel:Help("Press the button to open the GWater menu, where you can control nearly everything about GWater!")
		panel:Help("If you want to make it easier for yourself to access the menu, press the button below to copy the bind command, open the Developer Console, and paste it in!")
			
		panel:Button("\"bind kp_leftarrow gwater_menu\"").DoClick = function()
			SetClipboardText("bind kp_leftarrow gwater_menu")
			surface.PlaySound("buttons/button15.wav")
		end
			
		panel:Button("Open GWater Menu", "gwater_menu")
	end)
end)		