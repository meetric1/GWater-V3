-- by andrew
-- purpose: stub functions for people without the gwater module

hook.Add("GWaterPostInitialized", "GWater.Stubs", function()
	if gwater.HasModule then return end

	-- no operator, functions that would take too much effort to stub are set to this
	local no_op = function() end

	local convars = gwater.Convars
	gwater.Convars = convars

	local emitter = ParticleEmitter(Vector())
	function gwater.SpawnParticle(pos, vel)
	    local part = emitter:Add("!GWater_ExpensiveWater", pos) 
	    if part then
	        part:SetDieTime(10)
	        part:SetStartAlpha(230) 
	        part:SetEndAlpha(100) 
	        part:SetStartSize(7.5) 
	        part:SetEndSize(1) 
	        part:SetGravity(Vector( 0, 0, -600 )) 
	        part:SetVelocity(vel * 8) 
	        part:SetBounce(0.2)
	        part:SetCollide(true)
	        part:SetColor(45, 64, 255)
	    end
	end

	function gwater.GetRadius()
		return 10
	end

	gwater.SpawnCubeExact = no_op
	gwater.SpawnCube = no_op
	gwater.Blackhole = no_op
	gwater.ApplyForce = no_op
	gwater.ApplyForceOutwards = no_op
	gwater.RemoveAll = no_op
	gwater.SpawnSphere = no_op

	print("[GWATER]: Loaded stub functions!")
end)