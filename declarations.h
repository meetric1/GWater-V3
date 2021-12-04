#pragma once

#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>

#include <thread>
#include <mutex>
#include "types.h"

extern std::shared_ptr<flexAPI> flexLib;
extern GarrysMod::Lua::ILuaBase* GlobalLUA;

extern std::mutex* bufferMutex;
extern float4* particleBufferHost;

extern int numParticles;
extern int propCount;
extern bool simValid;

extern void printLua(std::string text);
extern void printLua(char*);
extern float distance2(float3 a, float3 b);
extern float3 normalize(float3 v);