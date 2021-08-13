#include "Simulation.h"
#include "GarrysMod/Lua/Interface.h"
#include <windows.h>

extern GarrysMod::Lua::ILuaBase* GlobalLUA;
extern void printLua(GarrysMod::Lua::ILuaBase* LUA, std::string text);

int Simulation::count = 0;
int Simulation::maxParticles = 65536;
bool Simulation::isRunning = false;
bool Simulation::isValid = false;
float Simulation::radius = 1.f;

NvFlexLibrary* Simulation::library = nullptr;
NvFlexBuffer* Simulation::particleBuffer = nullptr;
NvFlexBuffer* Simulation::velocityBuffer = nullptr;
NvFlexBuffer* Simulation::phaseBuffer = nullptr;
NvFlexSolver* Simulation::solver = nullptr;

float4* Simulation::particles = nullptr;
float3* Simulation::velocities = nullptr;
int* Simulation::phases = nullptr;
std::thread Simulation::simThread = std::thread();

void RenderParticles(float4* particles, float3* velocities) {
    printLua(GlobalLUA, "Position: " + std::to_string(particles[0].x) + ", " + std::to_string(particles[0].y) + ", " + std::to_string(particles[0].z) + "\nVelocity: " + std::to_string(velocities[0].x) + ", " + std::to_string(velocities[0].y) + ", " + std::to_string(velocities[0].z));
    
}

float4 RandomSpawnPosition() {
    int max = 200;
    float x = (float)(rand() % max - max / 2);
    float y = (float)(rand() % max - max / 2);
    float z = (float)(rand() % max - max / 2);
    float w = (float)(rand() % max - max / 2);
    float4 random = { x, y, z, w };
    return random;
}

float3 RandomSpawnVelocity() {
    int max = 200;
    float x = (float)(rand() % max - max / 2);
    float y = (float)(rand() % max - max / 2);
    float z = (float)(rand() % max - max / 2);
    float3 random = { x, y, z };
    return random;
}

void Simulation::InitSimulation()
{
    if (Simulation::isValid) {
        GlobalLUA->ThrowError("Tried to start a simulation while one was already running!");
        return;
    }

    simThread = std::thread(internalRun);
    simThread.detach();

    Simulation::isValid = true;
}

void Simulation::SpawnParticle(Vector pos, Vector vel) {
    if (!Simulation::isValid || solver == nullptr) {
        return;
    }

    count++;

    float4 posconv = { pos.x, pos.y, pos.z, 0 };
    float3 velconv = { vel.x, vel.y, vel.z };

    // map buffers for reading / writing
    if (particles == nullptr) particles = (float4*)NvFlexMap(particleBuffer, eNvFlexMapWait);
    if (velocities == nullptr) velocities = (float3*)NvFlexMap(velocityBuffer, eNvFlexMapWait);
    if (phases == nullptr) phases = (int*)NvFlexMap(phaseBuffer, eNvFlexMapWait);

    particles[count] = posconv;
    velocities[count] = velconv;
    phases[count] = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid);    //make fluid phase, not cloth


    NvFlexBuffer* activeBuffer = NvFlexAllocBuffer(library, maxParticles, sizeof(int), eNvFlexBufferHost);

    int* activeIndices = (int*)NvFlexMap(activeBuffer, eNvFlexMapWait);

    activeIndices[count] = count;
    NvFlexUnmap(activeBuffer);

    NvFlexSetActive(solver, activeBuffer, NULL);
    NvFlexSetActiveCount(solver, count);
}


//the function that the thread runs
void Simulation::internalRun() {
    
    NvFlexLibrary* library = NvFlexInit();
    float dt = 1.0f / 60.0f;
    // create new solver
    NvFlexSolverDesc solverDesc;
    NvFlexSetSolverDescDefaults(&solverDesc);
    solverDesc.maxParticles = maxParticles;
    solverDesc.maxDiffuseParticles = 0;

    NvFlexParams g_params;
    g_params.gravity[0] = 0.0f;
    g_params.gravity[1] = -9.8f;
    g_params.gravity[2] = 0.0f;

    g_params.radius = Simulation::radius;
    g_params.viscosity = 0.0f;
    g_params.dynamicFriction = 0.0f;
    g_params.staticFriction = 0.0f;
    g_params.particleFriction = 0.0f; // scale friction between particles by default
    g_params.freeSurfaceDrag = 0.0f;
    g_params.drag = 0.0f;
    g_params.lift = 0.0f;
    g_params.numIterations = 1;
    g_params.fluidRestDistance = Simulation::radius / 2.f;
    g_params.solidRestDistance = 0.0f;

    g_params.anisotropyScale = 1.0f;
    g_params.anisotropyMin = 0.1f;
    g_params.anisotropyMax = 2.0f;
    g_params.smoothing = 1.0f;

    g_params.dissipation = 0.0f;
    g_params.damping = 0.0f;
    g_params.particleCollisionMargin = 0.0f;
    g_params.shapeCollisionMargin = 0.0f;
    g_params.collisionDistance = 0.0f;
    g_params.sleepThreshold = 0.0f;
    g_params.shockPropagation = 0.0f;
    g_params.restitution = 0.0f;

    g_params.maxSpeed = FLT_MAX;
    g_params.maxAcceleration = 100.0f;    // approximately 10x gravity

    g_params.relaxationMode = eNvFlexRelaxationLocal;
    g_params.relaxationFactor = 1.0f;
    g_params.solidPressure = 1.0f;
    g_params.adhesion = 0.0f;
    g_params.cohesion = 0.025f;
    g_params.surfaceTension = 0.0f;
    g_params.vorticityConfinement = 0.0f;
    g_params.buoyancy = 1.0f;
    g_params.diffuseThreshold = 100.0f;
    g_params.diffuseBuoyancy = 1.0f;
    g_params.diffuseDrag = 0.8f;
    g_params.diffuseBallistic = 16;
    g_params.diffuseLifetime = 2.0f;

    // planes created after particles
    g_params.numPlanes = 0;


    NvFlexSolver* solver = NvFlexCreateSolver(library, &solverDesc);
    Simulation::solver = solver;
    NvFlexSetParams(solver, &g_params);

    NvFlexBuffer* particleBuffer = NvFlexAllocBuffer(library, maxParticles, sizeof(float4), eNvFlexBufferHost);
    NvFlexBuffer* velocityBuffer = NvFlexAllocBuffer(library, maxParticles, sizeof(float3), eNvFlexBufferHost);
    NvFlexBuffer* phaseBuffer = NvFlexAllocBuffer(library, maxParticles, sizeof(int), eNvFlexBufferHost);
    // map buffers for reading / writing
    auto particles = (float4*)NvFlexMap(particleBuffer, eNvFlexMapWait);
    auto velocities = (float3*)NvFlexMap(velocityBuffer, eNvFlexMapWait);
    auto phases = (int*)NvFlexMap(phaseBuffer, eNvFlexMapWait);

    // spawn particles
    //for (int i = 0; i < n; i++) {
        //std::cout << i << std::endl;
        particles[0] = float4{ 0, 0, 1, 1 };
        velocities[0] = float3{ 0, 1, 0 };
        phases[0] = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid);

        count++;
    //}
    // unmap buffers
    NvFlexUnmap(particleBuffer);
    NvFlexUnmap(velocityBuffer);
    NvFlexUnmap(phaseBuffer);

    //NvFlexSetParams(solver, &g_params);
    NvFlexSetParticles(solver, particleBuffer, NULL);
    NvFlexSetVelocities(solver, velocityBuffer, NULL);
    NvFlexSetPhases(solver, phaseBuffer, NULL);

    while(isValid){
        if (!isRunning) continue;
        // map buffers for reading / writing

        particles = (float4*)NvFlexMap(particleBuffer, eNvFlexMapWait);
        velocities = (float3*)NvFlexMap(velocityBuffer, eNvFlexMapWait);
        phases = (int*)NvFlexMap(phaseBuffer, eNvFlexMapWait);
        // render (print in this case)
        //RenderParticles(particles, velocities);
        // unmap buffers
        NvFlexUnmap(particleBuffer);
        NvFlexUnmap(velocityBuffer);
        NvFlexUnmap(phaseBuffer);
        // write to device (async)
        NvFlexSetParticles(solver, particleBuffer, NULL);
        NvFlexSetVelocities(solver, velocityBuffer, NULL);
        NvFlexSetPhases(solver, phaseBuffer, NULL);
        // set active count
        NvFlexSetActiveCount(solver, maxParticles);
        // tick
        NvFlexUpdateSolver(solver, dt, 1, false);
        // read back (async)
        NvFlexGetParticles(solver, particleBuffer, NULL);
        NvFlexGetVelocities(solver, velocityBuffer, NULL);
        NvFlexGetPhases(solver, phaseBuffer, NULL);

        Sleep(160);
    }

    NvFlexFreeBuffer(particleBuffer);
    NvFlexFreeBuffer(velocityBuffer);
    NvFlexFreeBuffer(phaseBuffer);
    NvFlexDestroySolver(solver);
    NvFlexShutdown(library);
}

void Simulation::StartSimulation()
{
    isRunning = true;
}

void Simulation::PauseSimulation()
{
    isRunning = false;
}

void Simulation::StopSimulation()
{
    isValid = false;
    isRunning = false;
    count = 0;
}