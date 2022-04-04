-- by andrew

hook.Add("GWaterInitialized", "GWater.Convars", function()
	gwater.Convars = {}
	
	gwater.Convars["enablealtrendering"] = CreateClientConVar("gwater_enablealtrendering", "0", true, false)
	gwater.Convars["enablenetworking"] = CreateClientConVar("gwater_enablenetworking", "1", true, false)
	gwater.Convars["enablesimulation"] = CreateClientConVar("gwater_enablesimulation", "1", true, false)
	
	gwater.Convars["snowemissionrate"] = CreateClientConVar("gwater_snowemissionrate", "10", true, false)
	gwater.Convars["maxnetparticles"] = CreateClientConVar("gwater_maxnetparticles", "32768", true, false)
	gwater.Convars["altrenderingrefreshrate"] = CreateClientConVar("gwater_altrenderingrefreshrate", "0.01", true, false)

	gwater.Convars["renderdiffuse"] = CreateClientConVar("gwater_renderdiffuse", "1", true, false)
end)