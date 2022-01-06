-- andrew was here

surface.CreateFont( "GWaterThicc", {
	font = "Coolvetica",
	extended = false,
	size = 22,
	weight = 800,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = true,
	additive = false,
	outline = true,
})

surface.CreateFont( "GWaterThin", {
	font = "Coolvetica",
	extended = false,
	size = 20,
	weight = 600,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

surface.CreateFont( "GWaterThinSmall", {
	font = "Coolvetica",
	extended = false,
	size = 15,
	weight = 600,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

surface.CreateFont( "GWaterThinLarge", {
	font = "Coolvetica",
	extended = false,
	size = 24,
	weight = 400,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

local function GWLabel(tab, text, font, x, y)
	local label = vgui.Create("DLabel", tab)
	label:SetPos(x, y)
	label:SetFont(font)
	label:SetText(text)
	label:SizeToContents()
	label:SetTextColor(Color(200, 200, 200))
	return label
end

local function DrawTabs(self, w, h)
	draw.RoundedBox(0, 0, 0, w, 20, Color( 10, 4, 20, 220))
	surface.SetDrawColor(30, 150, 150)
	surface.DrawOutlinedRect(0, 0, w, 20, 1)
end


local function GenericPaint(self, w, h) 
	draw.RoundedBox(0, 0, 0, w, h, Color( 10, 4, 20, 220))
	surface.SetDrawColor(30, 150, 150)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function GenericPaintNBG(self, w, h) 
	surface.SetDrawColor(30, 150, 150)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local psound = surface.PlaySound

local function quickControlsTab(tabs)
	local quickcontrol = vgui.Create("DPanel", tabs)
	local qcontroltab = tabs:AddSheet("Quick Control", quickcontrol, "icon16/wrench_orange.png").Tab
	
	qcontroltab.Paint = DrawTabs
	quickcontrol.Paint = GenericPaintNBG
	
	local ang = -EyeAngles()
	
	util.PrecacheModel("models/maxofs2d/cube_tool.mdl")
	
	local icon = vgui.Create("DModelPanel", quickcontrol)
	icon:SetSize(150, 150)
	icon:SetPos(10, 10)
	icon:SetFOV(80)
	icon:SetModel("models/maxofs2d/cube_tool.mdl")
	icon.Entity:SetBodygroup(1, 1)
	icon.Entity:SetAngles(Angle(-90, 0, 0))
	icon:SetAmbientLight(Color(100, 100, 100))
	icon:SetCamPos(ang:Forward() * Vector(50, -50, 50))
	icon:SetLookAt(icon.Entity:GetPos() + icon.Entity:GetForward() * 15)
	
	icon.PaintOver = function(self, w, h)
		GenericPaintNBG(self, w, h)
		
		surface.SetFont("GWaterThin")
		surface.SetTextColor(200, 200, 200)
		surface.SetTextPos(18, 0)
		surface.DrawText("Water Gravity")
	end
	
	local dir = EyeAngles():Forward() * 9.8
	
	local inittoaim = vgui.Create("DButton", quickcontrol)
	inittoaim:SetText("Set to your aim direction")
	inittoaim:SetPos( 170, 10 )
	inittoaim:SetSize( 130, 20 )
	inittoaim.Paint = GenericPaint
	inittoaim:SetTextColor(Color(100, 200, 200))
	inittoaim.DoClick = function()
		psound("buttons/button15.wav")
		gwater.SetConfig("gravityX", dir.x)
		gwater.SetConfig("gravityY", dir.y)
		gwater.SetConfig("gravityZ", dir.z)
	end
	
	local inittoaim = vgui.Create("DButton", quickcontrol)
	inittoaim:SetText("Set gravity to the ground")
	inittoaim:SetPos( 170, 40 )
	inittoaim:SetSize( 130, 20 )
	inittoaim.Paint = GenericPaint
	inittoaim:SetTextColor(Color(100, 200, 200))
	inittoaim.DoClick = function()
		psound("buttons/button15.wav")
		gwater.SetConfig("gravityX", 0)
		gwater.SetConfig("gravityY", 0)
		gwater.SetConfig("gravityZ", -9.8)
	end
	
	function icon:LayoutEntity(Entity) return end
	
	local clear = vgui.Create("DButton", quickcontrol)
	clear:SetText("Remove all particles")
	clear:SetPos(170, 70)
	clear:SetSize(130, 90)
	clear.Paint = GenericPaint
	clear:SetTextColor(Color(100, 200, 200))
	clear.DoClick = function()
		psound("buttons/button15.wav")
		gwater.RemoveAll()
	end
	
	local clear1 = vgui.Create("DButton", quickcontrol)
	clear1:SetText("Clean lone particles")
	clear1:SetPos(310, 70)
	clear1:SetSize(130, 90)
	clear1.Paint = GenericPaint
	clear1:SetTextColor(Color(100, 200, 200))
	clear1.DoClick = function()
		psound("buttons/button15.wav")
		gwater.CleanLoneParticles()
	end
	
	local radius = vgui.Create("DNumSlider", quickcontrol)
	radius:SetPos(10, 170)
	radius:SetSize(600, 20)
	radius:SetText("Particle Radius")
	radius:SetMinMax(1, 64)
	radius:SetValue(gwater.GetRadius())
	radius:SetDecimals(1)
	
	radius.OnValueChanged = function(self, value)
		gwater.SetRadius(value)
	end
end


local function renderingTab(tabs)
	local rendering = vgui.Create("DScrollPanel", tabs)
	local renderingtab = tabs:AddSheet("Rendering & Performance", rendering, "icon16/camera.png").Tab
	renderingtab.Paint = DrawTabs
	rendering.Paint = GenericPaintNBG
	
	for k,v in pairs(rendering:GetVBar():GetChildren()) do 
		v.PaintOver = GenericPaint 
	end
	
	local coltris = {
		[1] = {x = 0, y = 50},
		[53] = {x = 150, y = 100},
		[54] = {x = 0, y = 100}
	}
	
	local watercol = vgui.Create("DPanel", rendering)
	watercol:SetPos(10, 10)
	watercol:SetSize(150, 100)
	watercol.PaintOver = GenericPaintNBG
	watercol.Paint = function(self, w, h)
		local v = gwater.Material:GetVector("$color") or gwater.Material:GetVector("$refracttint") or Vector(1, 1, 1)
		surface.SetFont("GWaterThin")
		surface.SetTextColor(200, 200, 200)
		surface.SetTextPos(24, 2)
		surface.DrawText("Water Color")
		
		surface.SetDrawColor(v.x * 128, v.y * 128, v.z * 128)
		draw.NoTexture()
		
		for i=2, 52 do
			coltris[i] = {x = i * 3, y = 50 + math.sin(i / 2 - CurTime() * 8) * 5}
		end
		
		surface.DrawPoly(coltris)
	end
	
	local vec = gwater.Material:GetVector("$refracttint") or gwater.Material:GetVector("$color")
	
	local reds = vgui.Create("DNumSlider", rendering)
	reds:SetPos(170, 10)
	reds:SetSize(220, 20)
	reds:SetText("Red")
	reds:SetMinMax(0, 255)
	reds:SetValue(vec and (vec.x * 255 / 2) or 255)
	reds:SetDecimals(0)
	
	reds.OnValueChanged = function(self, value)
		vec.x = value / 255 * 2
		gwater.Material:SetVector("$refracttint", vec)
		gwater.Material:SetVector("$color", vec)
	end
	
	local greens = vgui.Create("DNumSlider", rendering)
	greens:SetPos(170, 50)
	greens:SetSize(220, 20)
	greens:SetText("Green")
	greens:SetMinMax(0, 255)
	greens:SetValue(vec and (vec.y * 255 / 2) or 255)
	greens:SetDecimals(0)
	
	greens.OnValueChanged = function(self, value)
		vec.y = value / 255 * 2
		gwater.Material:SetVector("$refracttint", vec)
		gwater.Material:SetVector("$color", vec)
	end
	
	local blues = vgui.Create("DNumSlider", rendering)
	blues:SetPos(170, 90)
	blues:SetSize(220, 20)
	blues:SetText("Blue")
	blues:SetMinMax(0, 255)
	blues:SetValue(vec and (vec.z * 255 / 2) or 255)
	blues:SetDecimals(0)
	
	blues.OnValueChanged = function(self, value)
		vec.z = value / 255 * 2
		gwater.Material:SetVector("$refracttint", vec)
		gwater.Material:SetVector("$color", vec)
	end
	
	local refract = vgui.Create("DNumSlider", rendering)
	refract:SetPos(380, 90)
	refract:SetSize(220, 20)
	refract:SetText("Refract Amount")
	refract:SetMinMax(0, 0.1)
	refract:SetValue(0.01)
	refract:SetDecimals(5)
	
	refract.OnValueChanged = function(self, value)
		gwater.Material:SetFloat("$refractamount", value)
	end
	
	GWLabel(rendering, "Water Material", "GWaterThin", 10, 120)
	
	local pickmat = vgui.Create("DComboBox", rendering)
	pickmat:SetPos(10, 150)
	pickmat:SetSize(150, 20)
	pickmat:SetValue("water")
	pickmat:SetTextColor(Color(200, 200, 200))
	
	for k,v in pairs(gwater.Materials) do
		pickmat:AddChoice(k)
	end
	
	pickmat.Paint = GenericPaint
	
	pickmat.OnSelect = function(self, k, v)
		gwater.Material = gwater.Materials[v]
		local vec = gwater.Material:GetVector("$refracttint") or gwater.Material:GetVector("$color")
		reds:SetValue(vec.x * 255 / 2)
		greens:SetValue(vec.y * 255 / 2)
		blues:SetValue(vec.z * 255 / 2)
	end
	
	local solve = vgui.Create("DCheckBoxLabel", rendering)
	solve:SetPos(10, 210)
	solve:SetText("Enable Simulation")
	solve:SetConVar("gwater_enablesimulation")
	
	local checkbox = vgui.Create("DCheckBoxLabel", rendering)
	checkbox:SetPos(10, 231)
	checkbox:SetText("Enable Rendering")
	checkbox:SetConVar("gwater_enablerendering")
	
	GWLabel(rendering, "Performance", "GWaterThin", 10, 180)
	
	local renderdist = vgui.Create("DNumSlider", rendering)
	renderdist:SetPos(10, 250)
	renderdist:SetSize(600, 20)
	renderdist:SetText("Render Distance")
	renderdist:SetMinMax(0, 32768)
	renderdist:SetValue(gwater.GetRenderDistance())
	renderdist:SetDefaultValue(gwater.GetRenderDistance())
	renderdist:SetDecimals(0)
	renderdist.OnValueChanged = function(self, value)
		gwater.SetRenderDistance(value)
	end
	
	local maxpart = vgui.Create("DNumSlider", rendering)
	maxpart:SetPos(10, 270)
	maxpart:SetSize(600, 20)
	maxpart:SetText("Particle Limit")
	maxpart:SetMinMax(0, 65536)
	maxpart:SetValue(gwater.GetMaxParticles())
	maxpart:SetDecimals(0)
	maxpart.OnValueChanged = function(self, value)
		gwater.SetMaxParticles(value)
	end
end


local function networkingTab(tabs)
	local networking = vgui.Create("DPanel", tabs)
	local networkingtab = tabs:AddSheet("Networking", networking, "icon16/group.png").Tab
	networkingtab.Paint = DrawTabs
	networking.Paint = GenericPaintNBG
	
	local checkbox = vgui.Create("DCheckBoxLabel", networking)
	checkbox:SetPos(10, 10)
	checkbox:SetText("Enable Networking (you can see others' particles)")
	checkbox:SetConVar("gwater_enablenetworking")
	
	local timescale = vgui.Create("DNumSlider", networking)
	timescale:SetPos(10, 30)
	timescale:SetValue(gwater.GetTimescale()) 
	timescale:SetSize(600, 20)
	timescale:SetText("Simulation Timescale (needs networking disabled)")
	timescale:SetMinMax(0, 10)
	timescale:SetDecimals(3)
	timescale.OnValueChanged = function(self, value)
		gwater.SetTimescale(value)
	end
	
	local maxpart = vgui.Create("DNumSlider", networking)
	maxpart:SetPos(10, 50)
	maxpart:SetSize(600, 20)
	maxpart:SetText("Networked Particle Limit")
	maxpart:SetMinMax(0, 65536)
	maxpart:SetConVar("gwater_maxnetparticles")
	maxpart:SetDecimals(0)
end

local function createConfigButton(tab, cfgname, x, y, w, h, name, desc, range)
	local myEntry = gwater.Params[cfgname]
	
	local btn = vgui.Create("DButton", tab)
	btn:SetPos(x, y)
	btn:SetSize(w, h)
	btn:SetText(cfgname)
	btn:SetTextColor(Color(100, 200, 200))
	
	btn.Paint = function(self, w, h)
		GenericPaint(self, w, h)
		draw.NoTexture()
		surface.SetDrawColor(25, 100, 200, 128)
		surface.DrawRect(0, 0, gwater.GetConfig(cfgname) / myEntry.max * w, h)
	end
	
	btn.DoClick = function()
		name:SetText(cfgname)
		desc:SetText(myEntry.desc)
		range:SetMinMax(myEntry.min, myEntry.max)
		range:SetValue(gwater.GetConfig(cfgname))
		range:SetDecimals(myEntry.decimals or 5)
		range:SetDefaultValue(myEntry.default)
		psound("buttons/button15.wav")
	end
end

local function gwaterTab(tabs)
	local gwpanel = vgui.Create("DScrollPanel", tabs)
	local gwatertab = tabs:AddSheet("GWater Settings", gwpanel, "icon16/water.png").Tab
	gwatertab.Paint = DrawTabs
	gwpanel.Paint = GenericPaintNBG
	
	for k,v in pairs(gwpanel:GetVBar():GetChildren()) do 
		v.PaintOver = GenericPaint 
	end
	
	local cfgtitle = GWLabel(gwpanel, "Click a parameter to edit it!", "GWaterThicc", 10, 130)
	cfgtitle:SetTextColor(Color(150, 250, 250))
	
	local cfgdesc = GWLabel(gwpanel, "Its description will show up here!", "GWaterThinSmall", 10, 152)
	cfgdesc:SetTextColor(Color(150, 250, 250))
	cfgdesc:SetText("Its description will show up here! You can also middle-click on the draggable knob of the slider to reset the property to its default value.")
	cfgdesc:SetWrap(true)
	cfgdesc:SetAutoStretchVertical(true)
	cfgdesc:SetSize(600, 100)
	
	local value = vgui.Create("DNumSlider", gwpanel)
	value:SetPos(10, 250)
	value:SetSize(600, 20)
	value:SetText("Value")
	value:SetMinMax(0, 1)
	value:SetValue(0)
	value:SetDecimals(5)
	
	function value:OnValueChanged(value)
		if gwater.Params[cfgtitle:GetText()] then
			gwater.SetConfig(cfgtitle:GetText(), value)
		end
	end
	
	local buttons = {}
	
	local i = 0
	for k,v in pairs(gwater.Params) do
		buttons[k] = createConfigButton(gwpanel, k, 10 + math.floor(i / 4) * 120, 10 + (i % 4) * 30, 110, 20, cfgtitle, cfgdesc, value)
		i = i + 1
	end
	
	
	local shid = vgui.Create("DButton", gwpanel)
	shid:SetPos(490, 10)
	shid:SetSize(100, 50)
	shid:SetText("Set for Potato PCs")
	shid:SetTextColor(Color(100, 200, 200))
	shid.Paint = GenericPaint
	shid.DoClick = function()
		for k,v in pairs(gwater.Params) do
			gwater.SetConfig(k, 0)
		end
		
		gwater.SetConfig("dynamicFriction", 0.15)
		gwater.SetConfig("gravityZ", -9.8)
		gwater.SetConfig("maxSpeed", 65536)
		gwater.SetConfig("maxAcceleration", 128)
		gwater.SetConfig("sleepThreshold", 2)
		
		psound("buttons/button15.wav")
	end
	
	local good = vgui.Create("DButton", gwpanel)
	good:SetPos(490, 70)
	good:SetSize(100, 50)
	good:SetText("Set to default")
	good:SetTextColor(Color(100, 200, 200))
	good.Paint = GenericPaint
	good.DoClick = function()
		for k,v in pairs(gwater.Params) do
			gwater.SetConfig(k, v.default)
		end
		
		psound("buttons/button15.wav")
	end
	
	
	
	local snowlabel = GWLabel(gwpanel, "Snow Mode", "GWaterThicc", 10, 280)
	local snowdesc = GWLabel(gwpanel, "It's winter, and with it, GWater has the ability to act like snow!", "GWaterThinSmall", 10, 302)
	snowlabel:SetTextColor(Color(150, 250, 250))
	snowdesc:SetTextColor(Color(150, 250, 250))
	
	local snowcvar = gwater.Convars["snowemissionrate"]
	local snowmode = vgui.Create("DButton", gwpanel)
	snowmode:SetPos(10, 325)
	snowmode:SetSize(200, 30)
	snowmode:SetFont("GWaterThinSmall")
	snowmode:SetText(gwater.SnowMode and "Stop Snow Mode" or "Make GWater act like snow")
	snowmode:SetTextColor(Color(100, 200, 200))
	snowmode.Paint = GenericPaint
	snowmode.DoClick = function()
		psound("buttons/button15.wav")
		
		if gwater.SnowMode then --reset to normal
			gwater.SnowMode = false
			gwater.SetConfig("maxAcceleration", gwater.Params["maxAcceleration"].default)
			gwater.SetConfig("adhesion", gwater.Params["adhesion"].default)
			gwater.SetConfig("gravityX", 0)
			gwater.SetConfig("gravityY", 0)
			gwater.SetConfig("gravityZ", -9.8)
			gwater.Materials["water"]:SetVector("$refracttint", Vector(0.75, 1, 2))
			
			timer.Remove("gwater_snowmode")
		else --turn on snowy stuff xd
			gwater.SetConfig("maxAcceleration", 64)
			gwater.SetConfig("adhesion", 0.08)
			gwater.SetConfig("gravityZ", -0.8)
			gwater.Materials["water"]:SetVector("$refracttint", Vector(2, 2, 2))
			gwater.Material = gwater.Materials["water"]
			
			timer.Create("gwater_snowmode", 0.1, 0, function()
				gwater.SetConfig("gravityX", math.sin(CurTime() * 1.2) * 2)
				gwater.SetConfig("gravityY", math.cos(CurTime() * 1.6) * 2)
				
				if snowcvar:GetInt() == 0 then return end
				for i = 0, snowcvar:GetInt() do
					local pos = LocalPlayer():GetPos() + 
								Vector(math.random(-1000, 1000), math.random(-1000, 1000), 900) +
								LocalPlayer():GetVelocity() * 2
								
					local vel = VectorRand(-25, 25)
				
					gwater.SpawnParticle(pos, vel)
				end
			end)
			
			gwater.SnowMode = true
		end
		
		snowmode:SetText(gwater.SnowMode and "Stop Snow Mode" or "Make GWater act like snow")
	end
	
	local snowcount = vgui.Create("DNumSlider", gwpanel)
	snowcount:SetPos(10, 360)
	snowcount:SetSize(300, 20)
	snowcount:SetText("Snow Emission Rate")
	snowcount:SetMinMax(0, 30)
	snowcount:SetValue(10)
	snowcount:SetDecimals(0)
	snowcount:SetConVar("gwater_snowemissionrate")
end




concommand.Add("gwater_menu", function()
	if not gwater then gwater = {} end
	if gwater.Menu then return end
	
	local menu = vgui.Create("DFrame")
	menu:SetTitle("GWater Menu  |  Running addon v" .. gwater.GetLuaVersion()
		.. (gwater.HasModule and " and module v" .. gwater.GetModuleVersion() or ""))
	menu:SetSize(640, 360)
	menu:Center()
	menu:MakePopup()
	menu.Paint = function(self, w, h)
		if gwater and gwater.Materials["water"] then
			surface.SetMaterial(gwater.Materials["water"])
			surface.SetDrawColor(255, 255, 255, 50)
			surface.DrawTexturedRect(0, 0, w, h)
		end
		
		draw.NoTexture()
		draw.RoundedBox(0, 0, 0, w, h, Color( 10, 4, 20, 200))
		surface.SetDrawColor(50, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	
	local cs = menu:GetChildren()
	cs[4]:SetFont("GWaterThicc")
	cs[4]:SetPos(5, 5)
	
	if gwater.ModuleVersionMismatch then
		local text = language.GetPhrase("gwater_outdated_module")
		text = string.Replace(text, "(what)", gwater.GetModuleVersionForLua() > gwater.GetModuleVersion() and "addon" or "module")
		text = string.Replace(text, "(module)", gwater.GetModuleVersion())
		text = string.Replace(text, "(addon)", gwater.GetModuleVersionForLua())
		
		local label = GWLabel(menu, text, "GWaterThinLarge", 10, 10)
		label:SetWrap(true)
		label:SetAutoStretchVertical()
		label:SetSize(620, 100)
		
		local ulabel = vgui.Create("DButton", menu)
		ulabel:SetPos(10, 100)
		ulabel:SetFont("GWaterThin")
		ulabel:SetText("Open in Browser")
		ulabel:SetTextColor(Color(100, 200, 200))
		ulabel.Paint = GenericPaint
		ulabel:SetSize(200, 40)
		ulabel.DoClick = function()
			gui.OpenURL("https://github.com/Mee12345/GWater-V3")
		end
		return
	end
	
	if not gwater.HasModule then
		local label = GWLabel(menu, language.GetPhrase("gwater_missing_module"), "GWaterThinLarge", 10, 10)
		label:SetWrap(true)
		label:SetAutoStretchVertical()
		label:SetSize(620, 140)
		
		local btn = vgui.Create("DButton", menu)
		btn:SetPos(10, 145)
		btn.Paint = GenericPaintNBG
		btn:SetSize(120, 40)
		btn:SetText("Reload GWater")
		btn:SetTextColor(Color(100, 200, 200))
		btn.DoClick = function()
			local populate = gwater.PopulateGWaterFunctions
			hook.Remove("Think", "GWATER_UPDATE")
			hook.Remove("PostDrawTranslucentRenderables", "GWATER_RENDER")
			timer.Remove("GWATER_ADD_PROP")
			timer.Remove("GWATER_CLEAN_LONE_PARTICLES")
			hook.Remove( "HUDPaint", "GWATER_SCORE")
			hook.Remove("OnPlayerChat", "GWATER_CHAT")
			hook.Remove("PlayerButtonDown", "GWATER_KEYPRESS")
			hook.Remove("PopulateToolMenu", "GWATER_MENU")

			include("autorun/gwater_main.lua")
			menu:Close()
			
			if populate then populate() end
			
			timer.Simple(0.2, function()
				RunConsoleCommand("gwater_menu")
			end)
		end

		return
	end
	
	-- tabs
	local tabs = vgui.Create("DPropertySheet", menu)
	tabs:Dock(FILL)
	tabs.Paint = function(self, w, h) 
		surface.SetDrawColor(30, 150, 150)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	
	
	-- Quick Control tab
	quickControlsTab(tabs)

	-- Rendering tab
	renderingTab(tabs)

	-- Networking tab
	networkingTab(tabs)

	-- GWater tab
	gwaterTab(tabs)
end)

--if IsValid(LocalPlayer()) and LocalPlayer():Nick() == "AndrewEathan" then RunConsoleCommand("gwater_menu") end