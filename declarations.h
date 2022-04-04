#pragma once

#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>

#include <thread>
#include <mutex>
#include "types.h"

#define GWATER_VERSION 1.4
#define ADD_FUNC(funcName, tblName) GlobalLUA->PushCFunction(funcName); GlobalLUA->SetField(-2, tblName);

extern std::shared_ptr<FLEX_API> FLEX_Simulation;
extern GarrysMod::Lua::ILuaBase* GlobalLUA;

extern std::mutex* bufferMutex;
extern float4* particleBufferHost;
extern float4* diffuseBufferHost;

extern float simTimescale;
extern int ParticleCount;
extern int diffuseCount;
extern int PropCount;
extern bool SimValid;
extern int RenderDistance;

extern void LUA_Print(std::string text);
extern void LUA_Print(char*);
extern float DistanceSquared(float3 a, float3 b);
extern float3 normalize(float3 v);