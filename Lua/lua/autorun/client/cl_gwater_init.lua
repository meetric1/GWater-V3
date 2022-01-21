
--initialize swimming, rendering, and sim/lostparticles
hook.Add("GWaterPostInitialized", "GWater.Startup", function()
    if not gwater or not gwater.HasModule then return end
    local isSwimming = false
    local water_sound_id = 0

    timer.Create("GWATER_CANSWIM", 0.1, 0, function()
        local particlesNearMe = gwater.ParticlesNear(LocalPlayer():GetPos() + Vector(0, 0, 30), 1.5)
        if particlesNearMe > 13 then --13
            if not isSwimming then
                isSwimming = true
                net.Start("GWATER_SWIMMING")
                    net.WriteBool(true)
                    net.WriteFloat(1)
                net.SendToServer()
                LocalPlayer():EmitSound("Physics.WaterSplash")
                LocalPlayer():SetDSP(14, true)
                water_sound_id = LocalPlayer():StartLoopingSound("ambient/water/underwater.wav")
            end
        elseif isSwimming then
            isSwimming = false
            net.Start("GWATER_SWIMMING")
                net.WriteBool(false)
                net.WriteFloat(1)
            net.SendToServer()
            LocalPlayer():EmitSound("Physics.WaterSplash")
            LocalPlayer():SetDSP(0, true)
            LocalPlayer():StopLoopingSound(water_sound_id)
        end

        local plys = ents.FindByClass("player")
        for k, v in ipairs(plys) do
            if v:IsValid() and v:GetActiveWeapon():IsValid() and v:GetActiveWeapon():GetClass() == "weapon_physcannon" and v:KeyDown(IN_ATTACK2) then
                gwater.ApplyForceOutwards(v:EyePos() + v:EyeAngles():Forward() * 125 + Vector(0, 0, 10), -15, 100, false);
            end
        end
    end)

    -- rendering
    local rendercvar = gwater.Convars["enablerendering"]
    local fov = LocalPlayer():GetFOV()

    local drawSprite = render.DrawSprite
    local drawSphere = render.DrawSphere

    function GWater_DrawSprite(pos, size)   --cache drawSprite and put this on _G for faster lookup in c++
        drawSprite(pos, size, size)
    end

    function GWater_DrawSphere(pos, size)
        drawSphere(pos, size, 5, 5)
    end

    hook.Add("PostDrawTranslucentRenderables", "GWATER_RENDER", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
        if drawingSkybox then return end
        if not rendercvar:GetBool() then return end
        local override = 1
        if gwater.Material == gwater.Materials["water"] then
            override = 1.5
        elseif gwater.Material == gwater.Materials["expensive_water"] then
            override = 0.6
        end

        render.SetMaterial(gwater.Material)

        local eye = EyeAngles()
        local forward = eye:Forward() * math.atan((fov / 45) / 1) * 1.5
        local dir1 = forward + eye:Right()
        local dir2 = forward - eye:Right()
        local dir3 = forward + eye:Up() * 2
        local dir4 = forward - eye:Up() * 2

        gwater.RenderedParticles = gwater.RenderParticles(override, EyePos(), dir1, dir2, dir3, dir4)
    end)

    hook.Add( "HUDPaint", "GWATER_SCORE", function()
        draw.DrawText(tostring(gwater.GetParticleCount()), "TargetID", ScrW() * 0.99, ScrH() * 0.01, color_white, TEXT_ALIGN_RIGHT)
    end)
end)