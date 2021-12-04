#pragma once

#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>
#include <vector>
#include "GarrysMod/Lua/Interface.h"
#include <string>
#include <map>

// cpp moment, have to do this

// A: since your float structs are doodoo shid i will fix them with my better implementations from V4
struct float3 {
    float x, y, z;
    float3(float x1, float y1, float z1) : x(x1), y(y1), z(z1) {};
    float3() : x(0), y(0), z(0) {};
    float3(float l) : x(l), y(l), z(l) {};
    float3(Vector l) : x(l.x), y(l.y), z(l.z) {};
    float3 operator+(float3 e) {
        return { x + e.x, y + e.y, z + e.z };
    }
    float3 operator*(float3 e) {
        return { x * e.x, y * e.y, z * e.z };
    }
    float3 operator-(float3 e) {
        return { x - e.x, y - e.y, z - e.z};
    }
    float3 operator/(float e) {
        return { x / e, y / e, z / e };
    }
};

struct float4 {
    float x, y, z, w;
    float4(float3 fl, float w1) : x(fl.x), y(fl.y), z(fl.z), w(w1) {};
    float4(float x1, float y1, float z1, float w1) : x(x1), y(y1), z(z1), w(w1) {};
    float4() : x(0), y(0), z(0), w(0) {};
    float4(float l) : x(l), y(l), z(l), w(l) {};
    float4(Vector l) : x(l.x), y(l.y), z(l.z), w(0) {};
    float4 operator+(float4 other) {
        x = other.x;
        y = other.y;
        z = other.z;
        w = other.w;
    }
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
    int* indices;
    float* lengths;
    float* coefficients;
};

struct ForceFieldData {
    NvFlexExtForceFieldCallback* forceFieldCallback;
    NvFlexExtForceField* forceFieldBuffer;
    int forceFieldCount;
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

    NvFlexBuffer* indicesBuffer;
    NvFlexBuffer* lengthsBuffer;
    NvFlexBuffer* coefficientsBuffer;

    NvFlexParams* flexParams;
    NvFlexSolverDesc flexSolverDesc;

    ForceFieldData* forceFieldData;

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
    void removeInRadius(float3 pos, float radius);

    void applyForce(float3 pos, float3 vel, float radius, bool linear);
    void applyForceOutwards(float3 pos, float strength, float radius, bool linear);

    void addCloth(GarrysMod::Lua::ILuaBase* LUA, size_t tableLen);

    void addForceField(Vector pos, float radius, float strength, bool linear, int type);
    void deleteForceField(int ID);
    void setForceFieldPos(int ID, Vector pos);
    void editForceField(int ID, float radius, float strength, bool linear, int type);

    void mapBuffers();
    void unmapBuffers();
    flexAPI();
    ~flexAPI();
};

