AddCSLuaFile()
if SERVER then
	return
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


--file.exists only works on 64bit?
local function loadGWater()
    if file.Exists("lua/bin/gmcl_GWater_win64.dll", "MOD") and file.Exists("lua/bin/gmcl_GWater_win32.dll", "MOD") then 
        require("GWater")
        
        gwater.AddConcaveMesh(triangulateWorld(), Vector(-33000, -33000, -33000), Vector(33000, 33000, 33000), Vector(), Angle())
        print("[GWATER]: Loaded module!")
        
        gwater.Whitelist = {
            prop_physics = true,
            prop_effect = true,
            gwater_sink = true,
            gwater_shower = true,
            gwater_fountain = true,
            gwater_blackhole = true,
            gwater_bathtub = true,
        }
        
        gwater.NetworkParticleCount = 0
        gwater.Meshes = {}
        gwater.ForceFields = {}
        gwater.HasModule = true
        hook.Run("GWaterInitialize")
        
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
        if game.SinglePlayer() then
            LocalPlayer():ConCommand("gwater_menu")
        end
        
        print("[GWATER]: No DLL found!")
    end
end

hook.Add("Think", "GWATER_INITIALIZE", function()
    hook.Remove("Think", "GWATER_INITIALIZE")
    loadGWater()
    hook.Run("GWaterInitialized")
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