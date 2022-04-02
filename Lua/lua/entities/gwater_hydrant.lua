AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_gmodentity"

list.Set("gwater_entities", "gwater_hydrant", {
	Category = "Fun with Water",
	Name = "Bluetooth Hydrant",
	Material = "entities/gwater_hydrant.png"
})

ENT.Category		= "GWater"
ENT.PrintName		= "Bluetooth Hydrant"
ENT.Author			= "Mee & AndrewEathan (with help from PotatoOS)"
ENT.Purpose			= "Lets you connect GWater entities to it to toggle them on/off at once!"
ENT.Instructions	= ""
ENT.GWaterEntity 	= true

function ENT:Initialize()
	self.Running = false
	self.ConnectedEntities = {}
	
	if CLIENT then 
		self.MenuShown = false
		return 
	end
	
	if WireLib then
		WireLib.CreateSpecialInputs(self, {
			"Enable (Activate the connected entities)",
			"Disable (Deactivate the connected entities)",
			"Toggle (Toggle the state of the connected entities)", 
			"ToggleWhen1 (When this is 1, toggle the state of the connected entities)",
			"ConnectedEntities (Sets this hydrant's connected entities)"
		}, {
			"NORMAL", "NORMAL", "NORMAL", "NORMAL", "ARRAY"
		})
	
		WireLib.CreateSpecialOutputs(self, {"ConnectedEntities (This hydrant's connected entities)"}, {"ARRAY"})
	end
	
	self:SetModel("models/props_wasteland/gaspump001a.mdl")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:PhysWake()
	
	local phys = self:GetPhysicsObject()
	phys:SetMass(200)
end

function ENT:TriggerInput(name, value)
	if name == "Enable" and value == 1 then
		for k,v in pairs(self.ConnectedEntities) do
			if v.TurnOn then v:TurnOn() end
		end
	end
	
	if name == "Disable" and value == 1 then
		for k,v in pairs(self.ConnectedEntities) do
			if v.TurnOff then v:TurnOff() end
		end
	end
	
	if name == "Toggle" then
		self:Use(self)
	end
	
	if name == "ToggleWhen1" then
		if value == 1 then
			self:Use(self)
		end
	end
	
	if name == "ConnectedEntities" then
		self.ConnectedEntities = {}
		for k,v in pairs(value) do
			if isentity(v) and v:IsValid() then
				table.insert(self.ConnectedEntities, v)
			end
		end
	
		if WireLib then Wire_TriggerOutput(self, "ConnectedEntities", self.ConnectedEntities) end 
		self:UpdateClientEntities()
	end
end

if CLIENT then
	local draw_color = surface.SetDrawColor
	local outlined_rect = surface.DrawOutlinedRect
	local draw_text = draw.SimpleText
	local draw_text_outlined = draw.SimpleTextOutlined
	local rect = surface.DrawRect
		
	local paintfun = function(self, w, h, v, owner, hy, k)
		if not IsValid(v) then
			table.remove(hy.ConnectedEntities, k)
			return
		end
		
		local x, y = self:LocalToScreen(0, 0)
		local offset = Angle(15, CurTime() * 50, 0)
		local dist = v:OBBMaxs():Length() * 0.9 + v:OBBMins():Length() * 0.9
			render.RenderView({
				origin = v:GetPos() + v:OBBCenter() * Vector(0, 0, 1) - offset:Forward() * dist,
				angles = offset,
				x = x + 5, 
				y = y + 5, 
				w = 128 - 10, 
				h = 128 - 10,
				fov = 60,
				drawmonitors = true,
				aspect = 1
			})
		draw_color(255, 255, 255)
		outlined_rect(5, 5, 128 - 10, 128 - 10)
		draw_text_outlined(v.PrintName .. " [" .. v:EntIndex() .. "]", "GWaterThinSmall", 8, 5, color_white, 0, 0, 1, color_black)
		draw_text_outlined(owner.Nick and owner:Nick() or owner:GetClass(), "GWaterThinSmaller", 8, 17, color_white, 0, 0, 1, color_black)
	end
	
	function ENT:DisplayMenu()
		if self.MenuShown then return end
		self.MenuShown = true
		
		local s = vgui.Create("DFrame")
		local e = self
		
		self.Menu = s
		
		function s:OnClose()
			e.MenuShown = false
		end
		
		s:SetTitle("")
		s:SetSize(1000, 600)
		s:Center()
		s:MakePopup()
		
		function s:Paint(w, h)
			draw_color(0, 8, 32, 240)
			rect(0, 0, w, h)
			draw_color(255, 255, 255)
			outlined_rect(0, 0, w, h)
		end
		
		local title = vgui.Create("DLabel", s)
		title:SetFont("GWaterThin")
		title:SetText("Hydrant Settings")
		title:SetPos(7, 2)
		title:SizeToContents()
		
		local scroll = vgui.Create("DScrollPanel", s)
		scroll:SetSize(1000 - 20, 270)
		scroll:SetPos(10, 50)
		
		local layout = vgui.Create("DIconLayout", scroll)
		layout:SetSize(1000, 270)
		layout:Dock(FILL)
		
		local scroll1 = vgui.Create("DScrollPanel", s)
		scroll1:SetSize(1000 - 20, 220)
		scroll1:SetPos(10, 370)
		
		local layout1 = vgui.Create("DIconLayout", scroll1)
		layout1:SetSize(1000, 270)
		layout1:Dock(FILL)
		
		local desc = vgui.Create("DLabel", s)
		desc:SetFont("GWaterThin")
		desc:SetText("Click on the below GWater entities to connect them to the hydrant!")
		desc:SetPos(7, 25)
		desc:SizeToContents()
		
		local desc1 = vgui.Create("DLabel", s)
		desc1:SetFont("GWaterThin")
		desc1:SetText("Connected entities:")
		desc1:SetPos(7, 345)
		desc1:SizeToContents()
		
		function scroll:Paint(w, h)
			draw_color(0, 8, 32, 240)
			rect(0, 0, w, h)
			draw_color(255, 255, 255)
			outlined_rect(0, 0, w, h)
		end
		
		function scroll1:Paint(w, h)
			draw_color(0, 8, 32, 240)
			rect(0, 0, w, h)
			draw_color(255, 255, 255)
			outlined_rect(0, 0, w, h)
		end
		
		local gents = ents.FindByClass("gwater_*")
		for k,v in pairs(gents) do
			if table.HasValue(self.ConnectedEntities, v) then continue end
			if v:GetClass() == "gwater_hydrant" then continue end
			local owner = v.CPPIGetOwner and v:CPPIGetOwner() or Entity(0)
			
			local btn = vgui.Create("DImageButton")
			btn:SetSize(128, 128)
			
			btn.Paint = function(self2, w, h)
				paintfun(self2, w, h, v, owner, self, k)
			end
			
			function btn:DoClick()
				net.Start("gwater_connect_entity")
				net.WriteEntity(e)
				net.WriteEntity(v)
				net.SendToServer()
			end
			
			layout:Add(btn)
		end
		
		for k,v in pairs(self.ConnectedEntities) do
			local btn = vgui.Create("DImageButton")
			btn:SetSize(128, 128)
			local owner = v.CPPIGetOwner and v:CPPIGetOwner() or Entity(0)
			
			btn.Paint = function(self2, w, h)
				paintfun(self2, w, h, v, owner, self, k)
			end
			
			function btn:DoClick()
				net.Start("gwater_disconnect_entity")
				net.WriteEntity(e)
				net.WriteEntity(v)
				net.SendToServer()
			end
			
			layout1:Add(btn)
		end
	end

	net.Receive("gwater_hydrant_menu", function()
		local ent = net.ReadEntity()
		ent:DisplayMenu()
	end)

	net.Receive("gwater_connected_entities", function()
		local ent = net.ReadEntity()
		local count = net.ReadInt(13)
		local tbl = {}
		
		for i = 1, count do
			table.insert(tbl, net.ReadEntity())
		end
		
		ent.ConnectedEntities = tbl
		
		if IsValid(ent.Menu) and ent.Menu:IsVisible() then
			if ent.Menu.Close then ent.Menu:Close() end
			ent:DisplayMenu()
		end
	end)
else
	util.AddNetworkString("gwater_hydrant_menu")
	util.AddNetworkString("gwater_connected_entities")
	util.AddNetworkString("gwater_connect_entity")
	util.AddNetworkString("gwater_disconnect_entity")
	
	net.Receive("gwater_connect_entity", function(len, ply)
		local ent = net.ReadEntity()
		local ent1 = net.ReadEntity()
		
		if not table.HasValue(ent.ConnectedEntities, ent1) then
			table.insert(ent.ConnectedEntities, ent1)
		end
		
		ent:EmitSound("gwater/bluetooth_hose_on.wav")
		ent1:EmitSound("gwater/bluetooth_hose_on.wav")
		
		if WireLib then Wire_TriggerOutput(ent, "ConnectedEntities", ent.ConnectedEntities) end
		ent:UpdateClientEntities()
	end)
	
	net.Receive("gwater_disconnect_entity", function(len, ply)
		local ent = net.ReadEntity()
		local ent1 = net.ReadEntity()
		
		if table.HasValue(ent.ConnectedEntities, ent1) then
			table.RemoveByValue(ent.ConnectedEntities, ent1)
		end
		
		ent:EmitSound("gwater/bluetooth_hose_off.wav")
		ent1:EmitSound("gwater/bluetooth_hose_off.wav")
		
		if WireLib then Wire_TriggerOutput(ent, "ConnectedEntities", ent.ConnectedEntities) end
		ent:UpdateClientEntities()
	end)
end

function ENT:UpdateClientEntities()
	net.Start("gwater_connected_entities")
		net.WriteEntity(self)
		net.WriteInt(#self.ConnectedEntities, 13)
		for k,v in pairs(self.ConnectedEntities) do
			net.WriteEntity(v)
		end
	net.Broadcast()
end

function ENT:Use(activator)
	if #self.ConnectedEntities > 0 then
		self:EmitSound("buttons/button17.wav")
		
		for k,v in pairs(self.ConnectedEntities) do
			if not IsValid(v) then table.remove(self.ConnectedEntities, k) continue end
			v:Use(activator)
		end
	else
		self:EmitSound("buttons/button2.wav")
		activator:SendLua("notification.AddLegacy('There are no GWater entities connected to this hydrant, add one in its menu!', 0, 4)")
		
		net.Start("gwater_hydrant_menu")
			net.WriteEntity(self)
		net.Send(activator)
	end
end