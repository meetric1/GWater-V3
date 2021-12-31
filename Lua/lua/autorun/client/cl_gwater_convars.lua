-- by andrew

hook.Add("GWaterInitialize", "GWater.Convars", function()
	gwater.Convars = {}
	
	gwater.Convars["enablerendering"] = CreateClientConVar("gwater_enablerendering", "1", true, false)
	gwater.Convars["enablenetworking"] = CreateClientConVar("gwater_enablenetworking", "1", true, false)
	gwater.Convars["enablesimulation"] = CreateClientConVar("gwater_enablesimulation", "1", true, false)
	
	gwater.Convars["snowemissionrate"] = CreateClientConVar("gwater_snowemissionrate", "10", true, false)
	gwater.Convars["maxnetparticles"] = CreateClientConVar("gwater_maxnetparticles", "32768", true, false)
	
	print("[GWATER]: Loaded convars file!")
end)