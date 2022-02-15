hook.Add("GWaterInitialized", "GWater.HydrantMenu", function()
	properties.Add("gwaterhydrant", {
		MenuLabel = "GWater Hydrant Menu",
		Order = 9999,
		MenuIcon = "icon16/water.png",
	
		Filter = function(self, ent, ply)
			if not IsValid(ent) then return false end
			return ent:GetClass() == "gwater_hydrant"
		end,
		Action = function(self, ent)
			if ent.DisplayMenu then
				ent:DisplayMenu()
			else
				notification.AddLegacy("Error! For some reason, this hydrant's menu doesn't work...")
			end
		end
	})
end)