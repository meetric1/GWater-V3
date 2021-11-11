#include "types.h"
#include "declarations.h"

#define MAX_COLLIDERS 1024

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
    simBuffers->geometry = static_cast<NvFlexCollisionGeometry*>(NvFlexMap(geometryBuffer, 0));
    simBuffers->positions = static_cast<float4*>(NvFlexMap(geoPosBuffer, 0));
    simBuffers->rotations = static_cast<float4*>(NvFlexMap(geoQuatBuffer, 0));
    simBuffers->prevPositions = static_cast<float4*>(NvFlexMap(geoPrevPosBuffer, 0));
    simBuffers->prevRotations = static_cast<float4*>(NvFlexMap(geoPrevQuatBuffer, 0));
    simBuffers->flags = static_cast<int*>(NvFlexMap(geoFlagsBuffer, 0));
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
/*
void flexAPI::removeInRadius(float3 pos, float r) {

    bufferMutex->lock();

    if (!simValid) {
        bufferMutex->unlock();
        return;

    }

    float4* particles = static_cast<float4*>(NvFlexMap(particleBuffer, eNvFlexMapWait));
    float3* velocities = static_cast<float3*>(NvFlexMap(velocityBuffer, eNvFlexMapWait));
    int* phases = static_cast<int*>(NvFlexMap(phaseBuffer, eNvFlexMapWait));
    int* activeIndices = static_cast<int*>(NvFlexMap(activeBuffer, eNvFlexMapWait));

    bool shiftBack = false;
    int n = numParticles;
    for (int i = 0; i < n; i++) {
        if (!shiftBack) {
            if (distance2(particles[i], pos) < r) {
                shiftBack = true;
                numParticles--;
            }
            else {
                continue;
            }
        }
        
        int nextIndex = i + 1;

        particles[i] = particles[nextIndex];
        velocities[i] = velocities[nextIndex];
        phases[i] = phases[nextIndex];
        activeIndices[i] = activeIndices[nextIndex];

        

    }

    NvFlexUnmap(particleBuffer);
    NvFlexUnmap(velocityBuffer);
    NvFlexUnmap(phaseBuffer);
    NvFlexUnmap(activeBuffer);

    bufferMutex->unlock();

}
*/

void flexAPI::removeAllParticles() {
    particleQueue.clear();
    numParticles = 0;
}


//flex startup
flexAPI::flexAPI() {
    flexLibrary = NvFlexInit(NV_FLEX_VERSION, gjelly_error);

    NvFlexSetSolverDescDefaults(&flexSolverDesc);
    flexSolverDesc.maxParticles = 65536;
    flexSolverDesc.maxDiffuseParticles = 0;

    flexParams = new NvFlexParams();
    initParams();

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

    // Host buffer
    particleBufferHost = static_cast<float4*>(malloc(sizeof(float4) * flexSolverDesc.maxParticles));

    //create buffer for the thread
    bufferMutex = new std::mutex();

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
