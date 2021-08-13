#pragma once
#include "types.h"
#include "NvFlex.h"
#include "NvFlexExt.h"
#include "GarrysMod/Lua/SourceCompat.h"
#include <chrono>
#include <iostream>
#include <thread>
#include <string>

class Simulation
{
private:
	static std::thread simThread;
	static NvFlexLibrary* library;

	static NvFlexBuffer* particleBuffer;
	static NvFlexBuffer* velocityBuffer;
	static NvFlexBuffer* phaseBuffer;
	static NvFlexSolver* solver;

	static void internalRun();

	Simulation() {};
public:
	static int count;
	static int maxParticles;
	static bool isRunning;
	static bool isValid;

	static float4* particles;
	static float3* velocities;
	static float radius;
	static int* phases;

	static void InitSimulation();
	static void StartSimulation();
	static void PauseSimulation();
	static void StopSimulation();

	static void SpawnParticle(Vector pos, Vector vel);
};