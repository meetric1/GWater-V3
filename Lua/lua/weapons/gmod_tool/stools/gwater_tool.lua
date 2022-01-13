TOOL.Category = "GWater"
TOOL.Name = "#Tool.gwater_tool.name"

if CLIENT then
	language.Add("Tool.gwater_tool.name", "GWater Remover")
	language.Add("Tool.gwater_tool.desc", "Removes Water In Radius")
	
	TOOL.MyConvar = CreateClientConVar("gwater_remover_radius", "500", true, false)
	TOOL.DisplaySize = TOOL.MyConvar:GetInt()
	TOOL.RealSize = TOOL.DisplaySize

	TOOL.Information = {
		{ name = "left" },
	}

	language.Add( "Tool.gwater_tool.left", "Removes water in an area (100 HU)" )

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {			
			text = "Removes water in an area",
		})
		panel:NumSlider("Radius", "gwater_remover_radius", 10, 2500, 0)
	end
	
	function TOOL:Think()
		self.DisplaySize = self.DisplaySize * 0.9 + self.RealSize * 0.1
		self.RealSize = self.MyConvar:GetInt()
	end
	
	function TOOL:DrawHUD()
		local trace = self.Owner:GetEyeTrace()
		
		cam.Start3D()
			render.SetColorMaterial()
			render.DrawSphere(trace.HitPos, -self.DisplaySize, 16, 16, Color(0, 32, 128, 50))
			render.DrawSphere(trace.HitPos, self.DisplaySize, 16, 16, Color(0, 32, 128, 50))
		cam.End3D()
	end
end

function TOOL:LeftClick(trace)
	if CLIENT then
		net.Start("GWATER_REMOVE")
			net.WriteVector(trace.HitPos)
			net.WriteInt(self.DisplaySize or 500, 16)
		net.SendToServer()
	elseif game.SinglePlayer() then
		net.Start("GWATER_REMOVE")
			net.WriteVector(trace.HitPos)
			net.WriteInt(self.DisplaySize or 500, 16)
		net.Broadcast()
	end

	return true
end

