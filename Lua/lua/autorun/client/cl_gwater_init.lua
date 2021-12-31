
--initialize swimming, rendering, and sim/lostparticles
hook.Add("GWaterInitialized", "GWater.Startup", function()
    if not gwater or not gwater.HasModule then return end
    local propQueue = {}
    local isSwimming = false
    local time = 0

    --mee: lagspikes every 5 seconds, talk to me about this if you want to reenable plz :)
    --a: this barely lags wtf do you mean
    --timer.Create("GWATER_CLEAN_LOST_PARTICLES", 5, 0, function()
    --    gwater.CleanLostParticles()
    --end)

    --timer.Create("GWATER_UPDATE_SIM_PARTICLES", 0.5, 0, function()
    --    gwater.RecalculateSimulatedParticles(EyePos())
    --end)

    timer.Create("GWATER_CANSWIM", 0.1, 0, function()
        local particlesNearMe = gwater.ParticlesNear(LocalPlayer():GetPos() + Vector(0, 0, 30), 1.5)
        if particlesNearMe > 13 then
            if not isSwimming then
                isSwimming = true
                net.Start("GWATER_SWIMMING")
                    net.WriteBool(true)
                net.SendToServer()
                LocalPlayer():EmitSound("Physics.WaterSplash")
            end
        elseif isSwimming then
            isSwimming = false
            net.Start("GWATER_SWIMMING")
                net.WriteBool(false)
            net.SendToServer()
            LocalPlayer():EmitSound("Physics.WaterSplash")
        end
    end)

    local particleCount = 0
	local rendercvar = gwater.Convars["enablerendering"]
	hook.Add("PreDrawTranslucentRenderables", "GWATER_RENDER", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
		if drawingSkybox then return end
		if not rendercvar:GetBool() then return end
		render.SetMaterial(gwater.Material)
		particleCount = gwater.RenderParticles(EyePos(), EyeAngles():Forward())
	end)

    hook.Add( "HUDPaint", "GWATER_SCORE", function() 
        draw.DrawText(tostring(particleCount), "TargetID", ScrW() * 0.99, ScrH() * 0.01, color_white, TEXT_ALIGN_RIGHT )
    end)
end)