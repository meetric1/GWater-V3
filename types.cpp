#include "types.h"
#include "declarations.h"

#define MAX_COLLIDERS 1024
#define MAX_PARTICLES 65536

//tysm this was very useful for debugging
void gjelly_error(NvFlexErrorSeverity type, const char* msg, const char* file, int line) {
    LUA_Print("FLEX ERROR:");
    LUA_Print(msg);
}

//add a particle to flex
void FLEX_API::addParticle(Vector pos, Vector vel) {
    Particle particle = Particle{float4(pos , 0.5), float3(vel)};
    particleQueue.push_back(particle);
}

//maps ALL flex buffers
void FLEX_API::mapBuffers() {
    simBuffers->particles = (float4*)NvFlexMap(particleBuffer, eNvFlexMapWait);
    simBuffers->velocities = (float3*)NvFlexMap(velocityBuffer, eNvFlexMapWait);
    simBuffers->phases = (int*)NvFlexMap(phaseBuffer, eNvFlexMapWait);
    simBuffers->activeIndices = (int*)NvFlexMap(activeBuffer, eNvFlexMapWait);
    simBuffers->geometry = (NvFlexCollisionGeometry*)NvFlexMap(geometryBuffer, eNvFlexMapWait);
    simBuffers->positions = (float4*)NvFlexMap(geoPosBuffer, eNvFlexMapWait);
    simBuffers->rotations = (float4*)NvFlexMap(geoQuatBuffer, eNvFlexMapWait);
    simBuffers->prevPositions = (float4*)NvFlexMap(geoPrevPosBuffer, eNvFlexMapWait);
    simBuffers->prevRotations = (float4*)NvFlexMap(geoPrevQuatBuffer, eNvFlexMapWait);
    simBuffers->flags = (int*)NvFlexMap(geoFlagsBuffer, eNvFlexMapWait);
    simBuffers->indices = (int*)NvFlexMap(indicesBuffer, eNvFlexMapWait);
    simBuffers->lengths = (float*)NvFlexMap(lengthsBuffer, eNvFlexMapWait);
    simBuffers->coefficients = (float*)NvFlexMap(coefficientsBuffer, eNvFlexMapWait);
}

//unmapps ALL flex buffers
void FLEX_API::unmapBuffers() {
    NvFlexUnmap(particleBuffer);
    NvFlexUnmap(velocityBuffer);
    NvFlexUnmap(phaseBuffer);
    NvFlexUnmap(activeBuffer);
    NvFlexUnmap(geometryBuffer);
    NvFlexUnmap(geoPrevPosBuffer);
    NvFlexUnmap(geoPrevQuatBuffer);
    NvFlexUnmap(geoPosBuffer);
    NvFlexUnmap(geoQuatBuffer);
    NvFlexUnmap(geoFlagsBuffer);
    NvFlexUnmap(indicesBuffer);
    NvFlexUnmap(lengthsBuffer);
    NvFlexUnmap(coefficientsBuffer);
}


//removes prop from flex
void FLEX_API::freeProp(int id) {
    Prop* prop = &props[id];

    NvFlexFreeBuffer(prop->verts);
    if (prop->indices == nullptr) {
        NvFlexDestroyConvexMesh(flexLibrary, prop->meshID);      //must be convex
    }
    else {
        NvFlexFreeBuffer(prop->indices);
        NvFlexDestroyTriangleMesh(flexLibrary, prop->meshID);    //must be triangle mesh
    }


    mapBuffers();
    for (int i = id; i < PropCount; i++) {
        int nextIndex = i + 1;

        simBuffers->geometry[i] = simBuffers->geometry[nextIndex];
        simBuffers->positions[i] = simBuffers->positions[nextIndex];
        simBuffers->prevPositions[i] = simBuffers->prevPositions[nextIndex];
        simBuffers->rotations[i] = simBuffers->rotations[nextIndex];
        simBuffers->prevRotations[i] = simBuffers->prevRotations[nextIndex];
        simBuffers->flags[i] = simBuffers->flags[nextIndex];

        props[i] = props[nextIndex];
    }
    unmapBuffers();


    props.pop_back();
    PropCount--;
}

void FLEX_API::removeInRadius(float3 pos, float radius) {
    bufferMutex->lock();

    if (!SimValid) {
        bufferMutex->unlock();
        return;
    }

    mapBuffers();

    //remember we are using distance2 (distance squared) we must follow system of equations
    //dist = sqrt((x_2 - x_1)^2 + (y_2 - y_1) ^2) is the same as d^2 = (x_2 - x_1)^2 + (y_2-y_1)^2 with (^ = pow)
    //square root is pretty expensive especially in large amounts, and we should optimize best we can to avoid it, this is why we use distance2()
    radius *= 2;

    int n = 0;
    int num = ParticleCount;
    for (int i = 0; i < num; i++) {
        if (DistanceSquared(simBuffers->particles[i], pos) >= radius) {
            simBuffers->particles[n] = simBuffers->particles[i];
            simBuffers->velocities[n] = simBuffers->velocities[i];
            simBuffers->phases[n] = simBuffers->phases[i];
            n++;
        }
        else {
            ParticleCount--;
        }
    }

    unmapBuffers();

    bufferMutex->unlock();
}

// Culls particles outside of maxParticles, this is only to be used for maxParticles changes
void FLEX_API::cullParticles()
{
    bufferMutex->lock();

    if (!SimValid) {
        bufferMutex->unlock();
        return;
    }

    mapBuffers();
    
    for (int i = flexSolverDesc.maxParticles; i < 65536; i++) {
        simBuffers->particles[i] = 0;
        simBuffers->velocities[i] = 0;
        simBuffers->phases[i] = 0;
    }

    unmapBuffers();
    bufferMutex->unlock();
}

void FLEX_API::cleanLostParticles() {
    bufferMutex->lock();

    if (!SimValid) {
        bufferMutex->unlock();
        return;
    }

    mapBuffers();

    int n = 0;
    int num = ParticleCount;
    for (int i = 0; i < num; i++) {
        if (simBuffers->particles[i].z >= -32760) {
            simBuffers->particles[n] = simBuffers->particles[i];
            simBuffers->velocities[n] = simBuffers->velocities[i];
            simBuffers->phases[n] = simBuffers->phases[i];
            n++;
        }
        else {
            ParticleCount--;
        }
    }

    unmapBuffers();
    bufferMutex->unlock();
}

int FLEX_API::cleanLoneParticles() {
    bufferMutex->lock();

    if (!SimValid) {
        bufferMutex->unlock();
        return 0;
    }

    mapBuffers();

    int n = 0;
    int purged = 0;
    for (int i = 0; i < ParticleCount; i++) {
        int neighbors = 0;

        for (int j = 0; j < ParticleCount; j++)
            if (DistanceSquared(simBuffers->particles[i], simBuffers->particles[j]) < 10000) neighbors++;
        
        if (neighbors > 2) {
            simBuffers->particles[n] = simBuffers->particles[i];
            simBuffers->velocities[n] = simBuffers->velocities[i];
            simBuffers->phases[n] = simBuffers->phases[i];
            n++;
        }
        else {
            ParticleCount--; //begone loner :trollhd:
            purged++;
        }
    }

    unmapBuffers();
    bufferMutex->unlock();
    return purged;
}

/*int FLEX_API::recalculateSimulatedParticles(float3 eyepos)
{
    bufferMutex->lock();
    if (!SimValid) {
        bufferMutex->unlock();
        return 0;
    }

    int count = 0;
    mapBuffers();
        for (int i = 0; i < ParticleCount; i++) {
            float dist = DistanceSquared(simBuffers->particles[i], eyepos);
            if (dist <= SimulationDistance) {
                simBuffers->activeIndices[i] = i;
                count++;
            }
            else
            {
                simBuffers->activeIndices[i] = 0;
            }
        }
    unmapBuffers();

    bufferMutex->unlock();
    return count;
}*/

void FLEX_API::applyForce(float3 pos, float3 vel, float radius, bool linear) {
    bufferMutex->lock();
    if (!SimValid) {
        bufferMutex->unlock();
        return;
    }

    mapBuffers();

    radius *= 2;

    int num = ParticleCount;
    for (int i = 0; i < num; i++) {
        float dist = DistanceSquared(simBuffers->particles[i], pos);
        if (dist <= radius) {
            float theta = 1 - dist / radius;
            simBuffers->velocities[i] = simBuffers->velocities[i] + vel * (linear ? theta : 1);
        }
    }

    unmapBuffers();
    bufferMutex->unlock();
}

void FLEX_API::applyForceOutwards(float3 pos, float strength, float radius, bool linear) {
    bufferMutex->lock();
    if (!SimValid) {
        bufferMutex->unlock();
        return;
    }

    mapBuffers();

    radius *= 2;

    int num = ParticleCount;
    for (int i = 0; i < num; i++) {
        float dist = DistanceSquared(simBuffers->particles[i], pos);
        if (dist <= radius) {
            float theta = 1 - dist / radius;
            float3 vel = normalize(pos - float3(simBuffers->particles[i])) * strength;
            simBuffers->velocities[i] = simBuffers->velocities[i] + vel * (linear ? theta : 1);
        }
    }
    unmapBuffers();

    bufferMutex->unlock();
}

void FLEX_API::addForceField(Vector pos, float radius, float strength, bool linear, int type) {
    //force field count
    int ffcount = forceFieldData->forceFieldCount;
    if (ffcount > 64) return;

    //NvFlexExtForceMode::eNvFlexExtModeForce               //0
    //NvFlexExtForceMode::eNvFlexExtModeImpulse             //1
    //NvFlexExtForceMode::eNvFlexExtModeVelocityChange      //2

    forceFieldData->forceFieldBuffer[ffcount].mPosition[0] = pos.x;
    forceFieldData->forceFieldBuffer[ffcount].mPosition[1] = pos.y;
    forceFieldData->forceFieldBuffer[ffcount].mPosition[2] = pos.z;
    forceFieldData->forceFieldBuffer[ffcount].mRadius = radius;
    forceFieldData->forceFieldBuffer[ffcount].mStrength = strength;
    forceFieldData->forceFieldBuffer[ffcount].mLinearFalloff = linear;
    forceFieldData->forceFieldBuffer[ffcount].mMode = (NvFlexExtForceMode)type;
    forceFieldData->forceFieldCount++;
}


void FLEX_API::setForceFieldPos(int ID, Vector pos) {
    forceFieldData->forceFieldBuffer[ID].mPosition[0] = pos.x;
    forceFieldData->forceFieldBuffer[ID].mPosition[1] = pos.y;
    forceFieldData->forceFieldBuffer[ID].mPosition[2] = pos.z;
}

void FLEX_API::editForceField(int ID, float radius, float strength, bool linear, int type) {
    forceFieldData->forceFieldBuffer[ID].mRadius = radius;
    forceFieldData->forceFieldBuffer[ID].mStrength = strength;
    forceFieldData->forceFieldBuffer[ID].mLinearFalloff = linear;
    forceFieldData->forceFieldBuffer[ID].mMode = (NvFlexExtForceMode)type;
}

void FLEX_API::deleteForceField(int ID) {
    //lock for this one because we are iterating through the entire array
    bufferMutex->lock();
    if (!SimValid) {
        bufferMutex->unlock();
        return;
    }

    ID = std::min(ID, 64);
    forceFieldData->forceFieldCount--;
    for (int i = ID; i < forceFieldData->forceFieldCount; i++) {
        forceFieldData->forceFieldBuffer[i] = forceFieldData->forceFieldBuffer[i + 1];
    }

    bufferMutex->unlock();
}

void FLEX_API::removeAllParticles() {
    particleQueue.clear();
    ParticleCount = 0;
}


void FLEX_API::removeAllProps()
{
    // andrew: ???
    // this wasn't defined when i noticed that intellisense pointed it out
    // i guess i'll try to make it for you but this isn't used anywhere so idk
    for (int i = 0; i < props.size(); i++) {
        freeProp(i);
    }
}

//flex startup
FLEX_API::FLEX_API() {
    flexLibrary = NvFlexInit(NV_FLEX_VERSION, gjelly_error);

    NvFlexSetSolverDescDefaults(&flexSolverDesc);
    flexSolverDesc.maxParticles = MAX_PARTICLES;
    flexSolverDesc.maxDiffuseParticles = 0;

    flexParams = new NvFlexParams();
    initParams();
    initParamsRadius(10);
    radius = 10;
    simTimescale = 1;

    flexSolver = NvFlexCreateSolver(flexLibrary, &flexSolverDesc);
    NvFlexSetParams(flexSolver, flexParams);


    // Create buffers
    particleBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(float4), eNvFlexBufferHost);
    velocityBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(float3), eNvFlexBufferHost);
    phaseBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(int), eNvFlexBufferHost);
    activeBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(int), eNvFlexBufferHost);

    // Geometry buffers 
    geometryBuffer = NvFlexAllocBuffer(flexLibrary, MAX_COLLIDERS, sizeof(NvFlexCollisionGeometry), eNvFlexBufferHost);
    geoPosBuffer = NvFlexAllocBuffer(flexLibrary, MAX_COLLIDERS, sizeof(float4), eNvFlexBufferHost);
    geoFlagsBuffer = NvFlexAllocBuffer(flexLibrary, MAX_COLLIDERS, sizeof(int), eNvFlexBufferHost);
    geoQuatBuffer = NvFlexAllocBuffer(flexLibrary, MAX_COLLIDERS, sizeof(float4), eNvFlexBufferHost);
    geoPrevPosBuffer = NvFlexAllocBuffer(flexLibrary, MAX_COLLIDERS, sizeof(float4), eNvFlexBufferHost);
    geoPrevQuatBuffer = NvFlexAllocBuffer(flexLibrary, MAX_COLLIDERS, sizeof(float4), eNvFlexBufferHost);

    //spring buffers
    indicesBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(int), eNvFlexBufferHost);
    lengthsBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(float), eNvFlexBufferHost);
    coefficientsBuffer = NvFlexAllocBuffer(flexLibrary, flexSolverDesc.maxParticles, sizeof(float), eNvFlexBufferHost);

    // Host buffer
    particleBufferHost = static_cast<float4*>(malloc(sizeof(float4) * flexSolverDesc.maxParticles));

    //create buffer for the thread
    bufferMutex = new std::mutex();
    simBuffers = new SimBuffers{};

    //forcefield struct
    forceFieldData = new ForceFieldData{};
    forceFieldData->forceFieldCallback = NvFlexExtCreateForceFieldCallback(flexSolver);
    forceFieldData->forceFieldCount = 0;
    forceFieldData->forceFieldBuffer = new NvFlexExtForceField[64];

    // Launch our flex solver thread
    std::thread(&FLEX_API::flexSolveThread, this).detach();
}

//flex shutdown
FLEX_API::~FLEX_API() {
    bufferMutex->lock();
    SimValid = false;
    ParticleCount = 0;
    PropCount = 0;

    if (flexLibrary != nullptr) {

        //remove props from memory
        for (int i = 0; i < props.size(); i++) freeProp(i);

        //clear ALL buffers
        NvFlexFreeBuffer(particleBuffer);
        NvFlexFreeBuffer(velocityBuffer);
        NvFlexFreeBuffer(phaseBuffer);
        NvFlexFreeBuffer(activeBuffer);
        NvFlexFreeBuffer(geometryBuffer);
        NvFlexFreeBuffer(geoPosBuffer);
        NvFlexFreeBuffer(geoQuatBuffer);
        NvFlexFreeBuffer(geoFlagsBuffer);
        NvFlexFreeBuffer(geoPrevPosBuffer);
        NvFlexFreeBuffer(geoPrevQuatBuffer);
        NvFlexFreeBuffer(indicesBuffer);
        NvFlexFreeBuffer(lengthsBuffer);
        NvFlexFreeBuffer(coefficientsBuffer);

        NvFlexExtDestroyForceFieldCallback(forceFieldData->forceFieldCallback);

        delete flexParams;

        free(particleBufferHost);

        //shutdown library
        NvFlexDestroySolver(flexSolver);
        NvFlexShutdown(flexLibrary);
        flexLibrary = nullptr;

        //if for some reason there are some still in queue
        particleQueue.clear();

    }

    bufferMutex->unlock();

    delete bufferMutex;
}

