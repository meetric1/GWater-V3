TOOL.Category = "GWater"
TOOL.Name = "#Tool.gwater_tool.name"

if CLIENT then
	language.Add("Tool.gwater_tool.name", "GWater Remover")
	language.Add("Tool.gwater_tool.desc", "Removes Water In Radius")
	

	TOOL.Information = {
		{ name = "left" },
	}

	language.Add( "Tool.gwater_tool.left", "Removes water in an area (100 HU)" )

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {			
			text = "Removes water in an area",
		})
	end
end

function TOOL:LeftClick(trace)
	if SERVER then
		if not trace.HitPos then return end
		net.Start("GWATER_REMOVE")
			net.WriteVector(trace.HitPos)
			net.WriteInt(65000, 16)
		net.Broadcast()
	end

	return true
end

