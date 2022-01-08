
--initialize swimming, rendering, and sim/lostparticles
hook.Add("GWaterInitialized", "GWater.Startup", function()
    if not gwater or not gwater.HasModule then return end
    local propQueue = {}
    local isSwimming = false
    local time = 0
    local water_sound_id = 0

    timer.Create("GWATER_CANSWIM", 0.1, 0, function()
        local particlesNearMe = gwater.ParticlesNear(LocalPlayer():GetPos() + Vector(0, 0, 30), 1.5)
        if particlesNearMe > 13 then
            if not isSwimming then
                isSwimming = true
                net.Start("GWATER_SWIMMING")
                    net.WriteBool(true)
                    net.WriteFloat(1)
                net.SendToServer()
                LocalPlayer():EmitSound("Physics.WaterSplash")
                LocalPlayer():SetDSP(14)
                water_sound_id = LocalPlayer():StartLoopingSound("ambient/water/underwater.wav")
            end
        elseif isSwimming then
            isSwimming = false
            net.Start("GWATER_SWIMMING")
                net.WriteBool(false)
                net.WriteFloat(1)
            net.SendToServer()
            LocalPlayer():EmitSound("Physics.WaterSplash")
            LocalPlayer():SetDSP(0)
            LocalPlayer():StopLoopingSound(water_sound_id)
        end
    end)

	local rendercvar = gwater.Convars["enablerendering"]
	hook.Add("PreDrawTranslucentRenderables", "GWATER_RENDER", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
		if drawingSkybox then return end
		if not rendercvar:GetBool() then return end
		render.SetMaterial(gwater.Material)
        
        local fov = LocalPlayer():GetFOV()
        local eye = EyeAngles()
        local forward = eye:Forward() * math.atan((fov / 45) / 1) * 1.5
        local dir1 = forward + eye:Right()
        local dir2 = forward - eye:Right()
        local dir3 = forward + eye:Up() * 2
        local dir4 = forward - eye:Up() * 2
		gwater.RenderedParticles = gwater.RenderParticles(EyePos(), dir1, dir2, dir3, dir4)
	end)

    hook.Add( "HUDPaint", "GWATER_SCORE", function()
        draw.DrawText(tostring(gwater.GetParticleCount()), "TargetID", ScrW() * 0.99, ScrH() * 0.01, color_white, TEXT_ALIGN_RIGHT )
    end)
end)