#include "types.h"
#include "declarations.h"

#define MAX_COLLIDERS 1024
#define MAX_PARTICLES 65536

//tysm this was very useful for debugging
void gjelly_error(NvFlexErrorSeverity type, const char* msg, const char* file, int line) {
    printLua("FLEX ERROR:");
    printLua(msg);
}

//add a particle to flex
void flexAPI::addParticle(Vector pos, Vector vel) {
    Particle particle = { float4{ pos.x, pos.y, pos.z , 0.5}, float3{vel.x, vel.y, vel.z} };
    particleQueue.push_back(particle);
}


//updates position of mesh `id`
void flexAPI::updateMeshPos(float4 pos, float4 ang, int id) {
    props[id].lastPos = pos;
    props[id].lastAng = ang;
}

//maps ALL flex buffers
void flexAPI::mapBuffers() {
    simBuffers->particles = static_cast<float4*>(NvFlexMap(particleBuffer, eNvFlexMapWait));
    simBuffers->velocities = static_cast<float3*>(NvFlexMap(velocityBuffer, eNvFlexMapWait));
    simBuffers->phases = static_cast<int*>(NvFlexMap(phaseBuffer, eNvFlexMapWait));
    simBuffers->activeIndices = static_cast<int*>(NvFlexMap(activeBuffer, eNvFlexMapWait));
    simBuffers->geometry = static_cast<NvFlexCollisionGeometry*>(NvFlexMap(geometryBuffer, eNvFlexMapWait));
    simBuffers->positions = static_cast<float4*>(NvFlexMap(geoPosBuffer, eNvFlexMapWait));
    simBuffers->rotations = static_cast<float4*>(NvFlexMap(geoQuatBuffer, eNvFlexMapWait));
    simBuffers->prevPositions = static_cast<float4*>(NvFlexMap(geoPrevPosBuffer, eNvFlexMapWait));
    simBuffers->prevRotations = static_cast<float4*>(NvFlexMap(geoPrevQuatBuffer, eNvFlexMapWait));
    simBuffers->flags = static_cast<int*>(NvFlexMap(geoFlagsBuffer, eNvFlexMapWait));
    simBuffers->indices = static_cast<int*>(NvFlexMap(indicesBuffer, eNvFlexMapWait));
    simBuffers->lengths = static_cast<float*>(NvFlexMap(lengthsBuffer, eNvFlexMapWait));
    simBuffers->coefficients = static_cast<float*>(NvFlexMap(coefficientsBuffer, eNvFlexMapWait));
}

//unmapps ALL flex buffers
void flexAPI::unmapBuffers() {
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
void flexAPI::freeProp(int id) {
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
    for (int i = id; i < propCount; i++) {
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
    propCount--;


}


void flexAPI::removeInRadius(float3 pos, float radius) {

    bufferMutex->lock();

    if (!simValid) {
        bufferMutex->unlock();
        return;
    }

    mapBuffers();

    int n = 0;
    int num = numParticles;
    for (int i = 0; i < num; i++) {
        if (distance2(simBuffers->particles[i], pos) >= radius) {
            simBuffers->particles[n] = simBuffers->particles[i];
            simBuffers->velocities[n] = simBuffers->velocities[i];
            simBuffers->phases[n] = simBuffers->phases[i];
            //simBuffers->activeIndices[n] = simBuffers->activeIndices[i];  //huh?

            n++;
        }
        else {
            numParticles--;
        }
    }

    unmapBuffers();

    bufferMutex->unlock();

}

void flexAPI::addForceField(Vector pos, float radius, float strength, bool linear, int type) {
    bufferMutex->lock();
    if (!simValid) {
        bufferMutex->unlock();
        return;
    }

    //force field count
    int ffcount = forceFieldData->forceFieldCount;

    //add forcefield
    switch (type) {
        case 2:
            forceFieldData->forceFieldBuffer[ffcount].mMode = NvFlexExtForceMode::eNvFlexExtModeImpulse;
            break;
        case 3:
            forceFieldData->forceFieldBuffer[ffcount].mMode = NvFlexExtForceMode::eNvFlexExtModeVelocityChange;
            break;
        default:
            forceFieldData->forceFieldBuffer[ffcount].mMode = NvFlexExtForceMode::eNvFlexExtModeForce;
    }
 
    forceFieldData->forceFieldBuffer[ffcount].mPosition[0] = pos.x;
    forceFieldData->forceFieldBuffer[ffcount].mPosition[1] = pos.y;
    forceFieldData->forceFieldBuffer[ffcount].mPosition[2] = pos.z;
    forceFieldData->forceFieldBuffer[ffcount].mRadius = radius;
    forceFieldData->forceFieldBuffer[ffcount].mStrength = strength;
    forceFieldData->forceFieldBuffer[ffcount].mLinearFalloff = linear;

    forceFieldData->forceFieldCount++;

    bufferMutex->unlock();
}


void flexAPI::deleteForceField(int ID) {
    bufferMutex->lock();
    if (!simValid) {
        bufferMutex->unlock();
        return;
    }

    forceFieldData->forceFieldCount--;
    for (int i = ID; i < forceFieldData->forceFieldCount; i++) {
        forceFieldData->forceFieldBuffer[i] = forceFieldData->forceFieldBuffer[i + 1];
    }

    bufferMutex->unlock();
}

void flexAPI::removeAllParticles() {
    particleQueue.clear();
    numParticles = 0;
}

void flexAPI::removeAllProps() {
    for (int i = 1; i < props.size(); i++) freeProp(i);
}

//flex startup
flexAPI::flexAPI() {
    flexLibrary = NvFlexInit(NV_FLEX_VERSION, gjelly_error);

    NvFlexSetSolverDescDefaults(&flexSolverDesc);
    flexSolverDesc.maxParticles = MAX_PARTICLES;
    flexSolverDesc.maxDiffuseParticles = 0;

    flexParams = new NvFlexParams();
    initParams();
    radius = 10;

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
    forceFieldData->forceFieldCount = 1;
    forceFieldData->forceFieldBuffer = new NvFlexExtForceField[64];
    
    // Launch our flex solver thread
    std::thread(&flexAPI::flexSolveThread, this).detach();
}

//flex shutdown
flexAPI::~flexAPI() {
    bufferMutex->lock();
    simValid = false;
    numParticles = 0;
    propCount = 0;

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
