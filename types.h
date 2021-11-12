#pragma once

#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>
#include <vector>
#include "GarrysMod/Lua/Interface.h"
#include <string>
#include <map>

struct float4 {
    float x, y, z, w;
};

struct float3 {
    float x, y, z;
};

struct Particle {
    float4 pos;
    float3 vel;
};

struct Prop {
    NvFlexBuffer* verts;
    NvFlexBuffer* indices;
    int meshID;
    
    float4 pos;
    float4 lastPos;

    float4 ang;
    float4 lastAng;
};

struct SimBuffers {
    float4* particles;
    float3* velocities;
    int* phases;
    int* activeIndices;
    NvFlexCollisionGeometry* geometry;
    float4* positions;
    float4* rotations;
    float4* prevPositions;
    float4* prevRotations;
    int* flags;
};



class flexAPI {
    NvFlexLibrary* flexLibrary;
    NvFlexSolver* flexSolver;
    SimBuffers* simBuffers;

    NvFlexBuffer* particleBuffer;
    NvFlexBuffer* velocityBuffer;
    NvFlexBuffer* phaseBuffer;
    NvFlexBuffer* activeBuffer;

    NvFlexBuffer* geometryBuffer;
    NvFlexBuffer* geoFlagsBuffer;
    NvFlexBuffer* geoPosBuffer;
    NvFlexBuffer* geoQuatBuffer;

    NvFlexBuffer* geoPrevPosBuffer;
    NvFlexBuffer* geoPrevQuatBuffer;

    NvFlexParams* flexParams;
    NvFlexSolverDesc flexSolverDesc;

    std::vector<Prop> props;
    std::vector<Particle> particleQueue;
    std::map<std::string, float*> flexMap;

public:

    float radius;

    void addParticle(Vector pos, Vector vel);

    void addMeshConcave(GarrysMod::Lua::ILuaBase* LUA, const float* minFloat, const float* maxFloat, size_t tableLen);
    void addMeshConvex(GarrysMod::Lua::ILuaBase* LUA, const float* minFloat, const float* maxFloat, size_t tableLen);
    void updateMeshPos(float4 pos, float4 ang, int id);
    void freeProp(int ID);

    void updateParam(std::string, float n);

    void initParams();
    void initParamsRadius(float r);
    void flexSolveThread();
    void removeAllParticles();
    void removeAllProps();

    void mapBuffers();
    void unmapBuffers();
    flexAPI();
    ~flexAPI();

};

