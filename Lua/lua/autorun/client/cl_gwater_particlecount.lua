-- by andrew



hook.Add("GWaterInitialized", "GWater.ParticleCount", function()
	if not gwater or not gwater.HasModule then return end
	
	local lastamount = 0

	local lastchange = CurTime()

		

	-- optimisations

	local drawcolor = surface.SetDrawColor

	local outline = surface.DrawOutlinedRect

	local drawrect = surface.DrawRect

	

	local drawtext = surface.DrawText

	local drawstext = draw.SimpleText

	local setfont = surface.SetFont

	local measure = surface.GetTextSize

	local settextpos = surface.SetTextPos

	local settextcolor = surface.SetTextColor

	

	hook.Add("HUDPaint", "GWATER_SCORE", function()

		setfont("GWaterThinSmall")

		local count = gwater.GetParticleCount()

		local max = gwater.GetMaxParticles()

		local ct = CurTime()

		

		if lastamount ~= count then lastamount = count lastchange = ct end

		local delta = ct - lastchange

		local alpha = 1 - ((delta > 3) and math.Clamp((delta - 3) / 5, 0, 0.9) or 0)

		

		local cratio = count / max * 255

		local col = Color(255, 255 - cratio, 255 - cratio, 255 * alpha)

		local color_black = Color(0, 0, 0, 255 * alpha)

		local maxtxt = count .. " / " .. max .. " (" .. math.Round(count / max * 100) .. "%)"

		if count == 0 then maxtxt = "No particles spawned!" end

		

		local tw, ty = measure("GWater Particles")

		local tw1, ty1 = measure(maxtxt)

		local W = ScrW()

		local H = ScrH()

		local CW = math.max(tw + 20, tw1 + 20)

		local CH = 40

		local CX = W - CW - 10

		local CY = 10

		

		drawcolor(0, 0, 0, 200 * alpha)

		drawrect(CX, CY, CW, CH)

		

		drawcolor(64, 168, 255, 255 * alpha)

		outline(CX, CY, CW, CH, 1)

		

		settextpos(CX + 12, CY + 7)

		settextcolor(0, 0, 0, 255 * alpha)

		drawtext("GWater Particles")

		

		settextpos(CX + 10, CY + 5)

		settextcolor(255, 255, 255, 255 * alpha)

		drawtext("GWater Particles")

		

		drawstext(maxtxt, "GWaterThinSmall", CX + CW / 2 + 2, CY + 20 + 2, color_black, TEXT_ALIGN_CENTER)

		drawstext(maxtxt, "GWaterThinSmall", CX + CW / 2, CY + 20, col, TEXT_ALIGN_CENTER)

	end)

end)