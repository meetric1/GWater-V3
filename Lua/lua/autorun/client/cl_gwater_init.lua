
--initialize swimming, rendering, and sim/lostparticles
hook.Add("GWaterPostInitialized", "GWater.Startup", function()
    if not gwater or not gwater.HasModule then return end
    local isSwimming = false
    local water_sound_id = 0

    timer.Create("GWATER_CANSWIM", 0.1, 0, function()
        local playersize = LocalPlayer().SCALE_MULTIPLIER or 1  -- make it compatable with my shrink addon :)
        local particlesNearMe = gwater.ParticlesNear(LocalPlayer():GetPos() + Vector(0, 0, playersize * 30), 1.5 * gwater.GetRadius())
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
    end)

    -- rendering
    local rendercvar = gwater.Convars["enablerendering"]
    local fov = LocalPlayer():GetFOV()

    local drawSprite = render.DrawSprite
    local drawSphere = render.DrawSphere

    local currentWatermat
    local refractInt = "$refracttint"
    function GWater_DrawSprite(pos, size)   --cache drawSprite and put this on _G for faster lookup in c++
        drawSprite(pos, size, size)
    end

    function GWater_DrawSphere(pos, size)
        drawSphere(pos, size, 5, 5)
    end

    function GWater_SetDrawColor(color)
        currentWatermat:SetVector(refractInt, color)
    end

    -- raytracing test, not used + bad performance
    --[[
    local scale = 5
    local scrw = ScrW() / scale - 1
    local scrh = ScrH() / scale - 1
    local finalColor = Vector(0, 1, 1)
    local function renderScene(eyePos, eyeAngles, coeff)
        for y = 0, scrh do
            for x = 0, scrw do
                -- fov and direction per pixel calc
                local dir = Vector(
                    1,
                    ((scrw - x) / (scrw - 1) - 0.5) * coeff,
                    (coeff / scrw) * (scrh - y) - 0.5 * (coeff / scrw) * (scrh - 1)
                )
                dir:Rotate(eyeAngles)
    
                -- actual tracing
                local dist, pos = gwater.TraceLine(eyePos, dir)
                if dist > 0 then
                    //local d = (((eyePos + dir * dist) - pos):GetNormalized()):Dot(Vector(0.58, 0.58, 0.58)) / 2 + 0.5
                    local finalVector = ((eyePos + dir * dist) - pos):GetNormalized() / 2 + Vector(0.5, 0.5, 0.5)
                    //surface.SetDrawColor((finalColor * d):ToColor())
                    surface.SetDrawColor(finalVector:ToColor())
                    surface.DrawRect(x * scale, y * scale, scale, scale)
                end
            end
        end
    end]]

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

        local origColor = gwater.Material:GetVector("$refracttint")
        currentWatermat = gwater.Material
        gwater.RenderParticles(override, EyePos(), dir1, dir2, dir3, dir4)
        gwater.Material:SetVector("$refracttint", origColor)
    end)

    --[[
    local meshes = {}
    local function refreshMeshes()
        local ppm = 8192    -- particles per mesh
        local i = 0
        while true do   -- refresh forever
            coroutine.yield()
            
            local data = gwater.GetSkewedData()
            if #data == 0 then 
                for k, v in ipairs(meshes) do
                    v:Destroy()
                    meshes[k] = nil
                end
                i = 1
                continue 
            end

            if not meshes[i] then 
                meshes[i] = Mesh()
            else
                meshes[i]:Destroy()
                meshes[i] = Mesh()
            end

            -- generate our mesh
            local radius = gwater.GetRadius() * 1.5
            local eyeForward = EyeAngles():Forward()
            mesh.Begin(meshes[i], MATERIAL_QUADS, ppm) -- Begin writing to the static mesh
            local _, err = pcall(function()
                for vertex = (i - 1) * ppm + 1, #data do
                    if vertex > ppm * i then break end

                    mesh.QuadEasy(data[vertex], eyeForward, radius, radius)

                    if vertex >= #data then 
                        i = 0  -- its gonna add 1 to 'i' right after this
                    end
                end
            end)
            if err then print(err) end
            mesh.End()
            i = i + 1
        end

        print("if this runs you better pray to jesus")
    end

    local coro = coroutine.create(refreshMeshes)
    hook.Add("PostDrawTranslucentRenderables", "GWATER_RENDER_MESHES", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
        if drawingSkybox then return end
        if not rendercvar:GetBool() then return end

        coroutine.resume(coro)
        render.SetMaterial(gwater.Material)
        for k, v in ipairs(meshes) do
            v:Draw()
        end
    end)]]

    hook.Add( "HUDPaint", "GWATER_SCORE", function()
        draw.DrawText(tostring(gwater.GetParticleCount()), "TargetID", ScrW() * 0.99, ScrH() * 0.01, color_white, TEXT_ALIGN_RIGHT)

        //local Fov = (LocalPlayer():GetFOV() * 0.97) / (LocalPlayer():KeyDown(IN_ZOOM) and 2 or 1)
        //local coeff = math.tan((Fov / 2) * (3.1416 / 180)) * 2.71828
        //renderScene(EyePos(), EyeAngles(), coeff)
    end)
end)

--[[
function GWater_DrawSprite(pos, size)   --lmao light source
    local c = (1 / LocalPlayer():GetPos():Distance(pos)) * 100 * ((util.TraceHull({
        start = pos, 
        endpos = LocalPlayer():GetPos() + Vector(0, 0, 30), 
        mins = Vector( -1, -1, -1 ),
        maxs = Vector( 1, 1, 1 ),
    }).Entity == LocalPlayer()) and 1 or 0.3)
    gwater.Material:SetVector("$refracttint", Vector(c, c, c, 255))
    render.DrawSprite(pos, size, size)
end]]
