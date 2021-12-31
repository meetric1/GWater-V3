-- by andrew
-- purpose: stub functions for people without the gwater module

hook.Add("GWaterInitialize", "GWater.Stubs", function()
	if gwater.HasModule then return end
	
	-- no operator, functions that would take too much effort to stub are set to this
	local no_op = function() end
	
	local convars = gwater.Convars
	gwater = {}
	gwater.Convars = convars
	
    local emitter = ParticleEmitter(Vector())
    function gwater.SpawnParticle(pos, vel)
        local part = emitter:Add("particle/particle_glow_04", pos) 
        if part then
            part:SetDieTime(10)
            part:SetStartAlpha(230) 
            part:SetEndAlpha(100) 
            part:SetStartSize(10) 
            part:SetEndSize(1) 
            part:SetGravity(Vector( 0, 0, -600 )) 
            part:SetVelocity(vel * 8) 
            part:SetBounce(0.2)
            part:SetCollide(true)
            part:SetColor(45, 64, 255)
        end
    end
    
    function gwater.SpawnCube(pos, size, apart, vel)
    	local spawnparticle = gwater.SpawnParticle
    	for z = -size.z, size.z do
    		for y = -size.y, size.y do
    			for x = -size.x, size.x do
    				local pos1 = Vector(pos.x + x * apart, pos.y + y * apart, pos.z + z * apart)
    				spawnparticle(pos1, vel)
    			end
    		end
    	end
	end

	-- who cares about the difference
	gwater.SpawnCubeExact = gwater.SpawnCube
    
    function gwater.SpawnSphere(pos, radius, size, vel)
    	local spawnparticle = gwater.SpawnParticle
    	for z = -size.z, z <= size.z do
    		for y = -size.y, y <= size.y do
    			for x = -size.x, x < size.x do
    				if x * x + y * y + z * z >= radius * radius then continue end
    				local pos1 = Vector(pos.x + x * apart, pos.y + y * apart, pos.z + z * apart)
    				spawnparticle(pos1, vel)
    			end
    		end
    	end
    end
	
	gwater.Blackhole = no_op
	gwater.ApplyForce = no_op
	gwater.ApplyForceOutwards = no_op
	gwater.RemoveAll = no_op
	
	gwater.Materials = {
		water = CreateMaterial("GWater_Water", "Refract", {
	  		["$refractamount"] = 0.01,
	   		["$refracttint"] = "[0.75 1 2]",
	        ["$normalmap"] = "shadertest/noise_normal",
	        ["$dudvmap"] = "dev/water_dudv",
		}),
		simplewater = CreateMaterial("GWater_SimpleWater", "UnlitGeneric", {
	  		["$basetexture"] = "models/debug/debugwhite",
		})
	}
	
	print("[GWATER]: Loaded stub functions!")
end)