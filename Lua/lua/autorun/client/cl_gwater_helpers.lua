-- by andrew

hook.Add("GWaterInitialized", "GWater.Helpers", function()
	function gwater.AddClass(class)
		if gwater.Whitelist then gwater.Whitelist[class] = true end
	end
	
	function gwater.RemoveClass(class)
		if gwater.Whitelist then gwater.Whitelist[class] = false end
	end
	
	function gwater.GetLuaVersion()
		return 1.2
	end
	
	function gwater.GetModuleVersionForLua()
		return 1.2 -- change this when needed
	end
end)