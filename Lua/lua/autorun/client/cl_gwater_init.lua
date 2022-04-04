
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
    local rendercvar = gwater.Convars["enablealtrendering"]
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

    -- alternative rendering
    local meshes = {}
    local function refreshMeshes()
        local ppm = 8192    -- particles per mesh
        local i = 0
        while true do   -- refresh forever
            coroutine.wait(math.max(gwater.Convars["altrenderingrefreshrate"]:GetFloat(), 0))
            
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
            local eyeForward = -EyeAngles():Forward()
            mesh.Begin(meshes[i], MATERIAL_QUADS, ppm) -- lets start making the static mesh
            local _, err = pcall(function()
            for vertex = (i - 1) * ppm + 1, #data do
                if !data[vertex] or vertex > ppm * i then break end

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

    local drawcoro = coroutine.create(refreshMeshes)
    hook.Add("PostDrawTranslucentRenderables", "GWATER_RENDER", function(drawingDepth, drawingSkybox, isDraw3DSkybox)
        if drawingSkybox then return end
        if not rendercvar:GetBool() then
            local override = 1
            if gwater.Material == gwater.Materials["water"] then
                override = 1.5
            elseif gwater.Material == gwater.Materials["expensive_water"] then
                override = 0.6
            end

            render.SetMaterial(gwater.Material)

            local eye = EyeAngles()
            local forward = eye:Forward() * math.atan((fov / 45) / 1) * 1.5 -- hacky non accurate fov calculation
            local dir1 = forward + eye:Right()
            local dir2 = forward - eye:Right()
            local dir3 = forward + eye:Up() * 2
            local dir4 = forward - eye:Up() * 2

            local origColor = gwater.Material:GetVector("$refracttint")
            currentWatermat = gwater.Material
            gwater.RenderParticles(gwater.Convars["renderdiffuse"]:GetBool(), override, EyePos(), dir1, dir2, dir3, dir4)
            gwater.Material:SetVector("$refracttint", origColor)
        else
            coroutine.resume(drawcoro)
            render.SetMaterial(gwater.Material)
            for k, v in ipairs(meshes) do
                v:Draw()
            end
        end
    end)
end)