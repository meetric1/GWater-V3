-- by andrew

hook.Add("GWaterInitialize", "GWater.Params", function()
	gwater.Params = {
		viscosity = {
			prettyname = "Viscosity",
			name = "viscosity", 
			desc = "Smoothes particle velocities",
			default = 0,
			min = 0,
			max = 1
		},
		drag = {
			prettyname = "Drag",
			name = "drag", 
			desc = "Drag force applied to particles",
			default = 0,
			min = 0,
			max = 1
		},
		dissipation = {
			prettyname = "Dissipation",
			name = "dissipation", 
			desc = "Damps particle velocity based on how many particle contacts it has, this should preferably be a low value",
			default = 0.01,
			min = 0,
			max = 0.5
		},
		damping = {
			prettyname = "Damping",
			name = "damping", 
			desc = "Viscous drag force, applies a force proportional and opposite to the particle velocity",
			default = 0,
			min = 0,
			max = 1
		},
		sleepThreshold = {
			prettyname = "Sleep Threshold",
			name = "sleepThreshold", 
			desc = "Particle with a velocity smaller than this will be considered static (boosts performance a bit)",
			default = 0.1,
			min = 0,
			max = 10
		},
		maxSpeed = {
			prettyname = "Max Speed",
			name = "maxSpeed", 
			desc = "This will be the maximum possible particle velocity, you probably won't ever need to change this.",
			default = math.pow(2, 128),
			min = 0,
			max = math.pow(2, 32)
		},
		maxAcceleration = {
			prettyname = "Max Acceleration",
			name = "maxAcceleration", 
			desc = "This will be the maximum amount of particle velocity change per second, you probably won't ever need to change this.\nHigh values make particles bouncy, for some reason!",
			default = 128,
			min = 0,
			max = 1024
		},
		adhesion = {
			prettyname = "Adhesion",
			name = "adhesion", 
			desc = "How strongly particles stick to surfaces they hit, preferably a low value",
			default = 0,
			min = 0,
			max = 5
		},
		cohesion = {
			prettyname = "Cohesion",
			name = "cohesion", 
			desc = "How strongly particles hold eachother together (0 is water, low is goopy, high is dry strawberry jam)",
			default = 0.01,
			min = 0,
			max = 5
		},
		surfaceTension = {
			prettyname = "Surface Tension",
			name = "surfaceTension", 
			desc = "How strongly particles try to pull eachother together (ex. water drops not just flattening out)\nThis should be a small value, otherwise water acts like huge droplets (at higher values it even goes crazy)",
			default = 0,
			min = 0,
			max = 0.0003,
			decimals = 8
		},
		vorticityConfinement = {
			prettyname = "Vorticity Confinement",
			name = "vorticityConfinement", 
			desc = "How much water swishes around inside a bunch of water if moved",
			default = 0,
			min = 0,
			max = 10
		},
		dynamicFriction = {
			prettyname = "Dynamic Friction",
			name = "dynamicFriction", 
			desc = "Friction when colliding against shapes, doesn't do much",
			default = 0.5,
			min = 0,
			max = 2
		},
		staticFriction = {
			prettyname = "Static Friction",
			name = "staticFriction", 
			desc = "(Static? i'm not sure about this either) Friction when colliding against shapes, doesn't do much",
			default = 0.5,
			min = 0,
			max = 2
		},
		particleFriction = {
			prettyname = "Particle Friction",
			name = "particleFriction", 
			desc = "Friction when particles collide with eachother, should be a low value for water",
			default = 0.01,
			min = 0,
			max = 10
		},
		solidPressure = {
			prettyname = "Solid Pressure",
			name = "solidPressure", 
			desc = "Add pressure from solid surfaces to particles\nThis doesn't seem to do much",
			default = 0.5,
			min = 0,
			max = 10
		}
	}

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

	language.Add("gwater_missing_module", "Sorry, you either don't have the GWater binary module, or you're on a platform besides Windows! \nYou can still see the particles you'll try to spawn, but they will be normal Garry's Mod particles as a placeholder!")
	language.Add("gwater_outdated_module", "Your GWater (what) is outdated!\nModule version is v(module), but the addon needs v(addon)!\nDownload the latest version here:")
	
	if gwater.ModuleVersionMismatch then
		chat.AddText(
			Color(0, 0, 0), "[",
			Color(0, 200, 255), "GWater",
			Color(0, 0, 0), "] ",
			Color(255, 255, 255), "Your GWater is outdated and you will not be able to use it, check the menu for more information!")
	end
	
	print("[GWATER]: Loaded params file!")
end)