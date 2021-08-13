#include "GarrysMod/Lua/Interface.h"
#include "GarrysMod/Lua/SourceCompat.h"
#include "types.h"
#include "Simulation.h"

using namespace GarrysMod::Lua;

ILuaBase* GlobalLUA = nullptr;

void printLua(ILuaBase* LUA, std::string text)
{
    LUA->PushSpecial(SPECIAL_GLOB);
    LUA->GetField(-1, "print");
    LUA->PushString(text.c_str());
    LUA->Call(1, 0);
    LUA->Pop();
}


Vector makeVec(float x, float y, float z) {
    Vector vec;
    vec.x = x;
    vec.y = y;
    vec.z = z;
    return vec;
}

/*
A: unused for now, we'll add meshes after we're sure everything works nicely
for now you should find how flex does the meshes by looking at the source code and searching
LUA_FUNCTION(DummyMeshGen) {
    LUA->PushVector(makeVec(-20, 0, 40));
    LUA->PushVector(makeVec(0, 0, 0));
    LUA->PushVector(makeVec(20, 0, 40));
    return 3;	//number of arguments
}*/



LUA_FUNCTION(GWaterGetParticleData) {
    int returncount = 0;

    if (!Simulation::isValid) return 0; //simulation doesnt exist, bail

    for (int i = 0; i < Simulation::count; ++i)
    {
        float4 pos = (float4)Simulation::particles[i];
        float3 vel = (float3)Simulation::velocities[i];

        Vector pos2 = makeVec(pos.x, pos.y, pos.z);
        Vector vel2 = makeVec(vel.x, vel.y, vel.z);

        //printLua(LUA, std::to_string(pos.y));
        //printLua(LUA, std::to_string(vel.z));

        LUA->PushVector(pos2);
        LUA->PushVector(vel2);
        returncount += 2;
    }

    //printLua(LUA, "IsValid: " + std::to_string(Simulation::isValid) + " | IsRunning: " + std::to_string(Simulation::isRunning) + " | Count: " + std::to_string(Simulation::count));
    return returncount;
}

LUA_FUNCTION(GWaterInitSim) {
    if (Simulation::isValid) { 
        Simulation::StartSimulation();
        return 0; 
    }

    Simulation::InitSimulation();
    Simulation::StartSimulation();
    return 0;
}

LUA_FUNCTION(GWaterStartSim) {
    Simulation::isRunning = true;
    return 0;
}

LUA_FUNCTION(GWaterPauseSim) {
    Simulation::isRunning = false;
    return 0;
}

LUA_FUNCTION(GWaterStopSim) {
    if (!Simulation::isValid) return 0;

    Simulation::StopSimulation();
    return 0;
}

LUA_FUNCTION(GWaterIsRunning) {
    LUA->PushBool(Simulation::isRunning);
    return 1;
}

LUA_FUNCTION(GWaterIsValid) {
    LUA->PushBool(Simulation::isValid);
    return 1;
}

LUA_FUNCTION(GWaterParticleCount) {
    LUA->PushNumber(Simulation::count);
    return 1;
}

//spawns a particle, pass 2 vectors to it
LUA_FUNCTION(GWaterSpawnParticle) {
    Vector pos = LUA->GetVector(-2);    //first agrument would be at the bottom because it is pushed first
    Vector vel = LUA->GetVector(-1);

    //printLua(LUA, std::to_string(pos.x) + " " + std::to_string(pos.y) + " " + std::to_string(pos.z));
    //printLua(LUA, std::to_string(vel.x) + " " + std::to_string(vel.y) + " " + std::to_string(vel.z));

    if (Simulation::isValid && Simulation::count < Simulation::maxParticles) {
        Simulation::SpawnParticle(pos, vel);
    }

    return 0;
}

// Called when the module is loaded
GMOD_MODULE_OPEN()
{
    GlobalLUA = LUA;

    /// Particle Funcs ///

    // push particle data retriever
    LUA->PushSpecial(SPECIAL_GLOB); //push _G

    LUA->PushString("GWater_GetParticleData");
    LUA->PushCFunction(GWaterGetParticleData);
    LUA->SetTable(-3);

    // push particle data retriever
    LUA->PushString("GWater_SpawnParticle");
    LUA->PushCFunction(GWaterSpawnParticle);
    LUA->SetTable(-3);

    // push simulation init
    LUA->PushString("GWater_InitSimulation");
    LUA->PushCFunction(GWaterInitSim);
    LUA->SetTable(-3);

    // push simulation starter
    LUA->PushString("GWater_StartSimulation");
    LUA->PushCFunction(GWaterStartSim);
    LUA->SetTable(-3);

    // push simulation pauser
    LUA->PushString("GWater_PauseSimulation");
    LUA->PushCFunction(GWaterPauseSim);
    LUA->SetTable(-3);

    // push simulation destroyer
    LUA->PushString("GWater_StopSimulation");
    LUA->PushCFunction(GWaterStopSim);
    LUA->SetTable(-3);

    // push simulation isrunning
    LUA->PushString("GWater_IsRunning");
    LUA->PushCFunction(GWaterIsRunning);
    LUA->SetTable(-3);

    // push simulation isvalid
    LUA->PushString("GWater_IsValid");
    LUA->PushCFunction(GWaterIsValid);
    LUA->SetTable(-3);

    // push simulation count retriever
    LUA->PushString("GWater_ParticleCount");
    LUA->PushCFunction(GWaterParticleCount);
    LUA->SetTable(-3);

    LUA->Pop(); //pop _G

    return 0;
}

// Called when the module is unloaded
GMOD_MODULE_CLOSE()
{
    return 0;
}