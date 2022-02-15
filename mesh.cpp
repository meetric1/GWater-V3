#include "types.h"
#include "declarations.h"
#include <string>

//Quat library provided by potatoOS, turns a eular angle into a quaterion
#define _PI 3.14159265358979323846
float rad(float degree) {
    return (degree * (_PI / 180));
}

float4 getQuatMul(float4 lhs, float4 rhs) {
    return float4(
        lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z - lhs.w * rhs.w,
        lhs.x * rhs.y + lhs.y * rhs.x + lhs.z * rhs.w - lhs.w * rhs.z,
        lhs.x * rhs.z + lhs.z * rhs.x + lhs.w * rhs.y - lhs.y * rhs.w,
        lhs.x * rhs.w + lhs.w * rhs.x + lhs.y * rhs.z - lhs.z * rhs.y
    );
}

float4 quatFromAngleComponents(float p, float y, float r) {
    p = rad(p) * 0.5f;
    y = rad(y) * 0.5f;
    r = rad(r) * 0.5f;

    float4 q_x = float4((float)cos(y), 0, 0, (float)sin(y));
    float4 q_y = float4((float)cos(p), 0, (float)sin(p), 0);
    float4 q_z = float4((float)cos(r), (float)sin(r), 0, 0);

    return getQuatMul(q_x, getQuatMul(q_y, q_z));
}

float4 unfuckQuat(float4 q) {
    return float4(q.y, q.z, q.w, q.x);
}

float4 quatFromAngle(QAngle ang) {
    return unfuckQuat(quatFromAngleComponents(ang.x, ang.y, ang.z));
}

float3 crossProduct(float3 A, float3 B) {
    return float3(
        A.y * B.z - A.z * B.y,
        A.z * B.x - A.x * B.z,
        A.x * B.y - A.y * B.x
    );
}

//adds CONVEX mesh for flex
void FLEX_API::addMeshConvex(GarrysMod::Lua::ILuaBase* LUA) {
    float4 meshAng = quatFromAngle(LUA->GetAngle(-1));
    float4 meshPos = float4(LUA->GetVector(-2), 1.f / 50000.f);
    float3 meshMax = LUA->GetVector(-3);
    float3 meshMin = LUA->GetVector(-4);
    float minFloat[3] = { meshMin.x, meshMin.y, meshMin.z };
    float maxFloat[3] = { meshMax.x, meshMax.y, meshMax.z };
    size_t tableLen = LUA->ObjLen(-5);
    LUA->Pop(4);    //pops all stuff above, the table is now at index -1

    //add the prop
    Prop p = Prop();
    p.pos = meshPos;
    p.ang = meshAng;
    p.lastPos = meshPos;
    p.lastAng = meshAng;
    p.verts = NvFlexAllocBuffer(flexLibrary, tableLen, sizeof(float4), eNvFlexBufferHost);

    float4* hostVerts = (float4*)(NvFlexMap(p.verts, eNvFlexMapWait));

    //loop through vertices
    for (int i = 0; i < tableLen; i += 3) {
        float3 verts[3] = {};

        for (int j = 0; j < 3; j++) {
            LUA->PushNumber((double)(i + j) + 1.0);
            LUA->GetTable(-2);

            Vector thisPos = LUA->GetVector();
            verts[j] = float3(thisPos);
            LUA->Pop(); //pop the pos
        }
        float3 cross = normalize(crossProduct(verts[1] - verts[0], verts[2] - verts[0]));
        float d = cross.x * verts[0].x + cross.y * verts[0].y + cross.z * verts[0].z;
        hostVerts[i / 3] = float4(-cross.x, -cross.y, -cross.z, d);
    }

    //make sure to unmap the verts
    NvFlexUnmap(p.verts);

    LUA->Pop(); //pop table

    //create the triangle mesh
    p.meshID = NvFlexCreateConvexMesh(flexLibrary);
    NvFlexUpdateConvexMesh(flexLibrary, p.meshID, p.verts, tableLen / 3, minFloat, maxFloat);

    // Add data to BUFFERS
    mapBuffers();
    simBuffers->flags[PropCount] = NvFlexMakeShapeFlags(eNvFlexShapeConvexMesh, true);	//always dynamic (props)
    simBuffers->geometry[PropCount].convexMesh.mesh = p.meshID;
    simBuffers->geometry[PropCount].convexMesh.scale[0] = 1.0f;
    simBuffers->geometry[PropCount].convexMesh.scale[1] = 1.0f;
    simBuffers->geometry[PropCount].convexMesh.scale[2] = 1.0f;
    simBuffers->positions[PropCount] = meshPos;
    simBuffers->rotations[PropCount] = meshAng;	//dont set rotation to 0,0,0,0 or flex kabooms
    simBuffers->prevPositions[PropCount] = meshPos;
    simBuffers->prevRotations[PropCount] = meshAng;
    unmapBuffers();

    props.push_back(p);
    PropCount++;

}

//generate a TRIANGLE mesh for flex
void FLEX_API::addMeshConcave(GarrysMod::Lua::ILuaBase* LUA) {
    float4 meshAng = quatFromAngle(LUA->GetAngle(-1));
    float4 meshPos = float4(LUA->GetVector(-2), 1.f / 50000.f);
    float3 meshMax = LUA->GetVector(-3);
    float3 meshMin = LUA->GetVector(-4);
    float minFloat[3] = { meshMin.x, meshMin.y, meshMin.z };
    float maxFloat[3] = { meshMax.x, meshMax.y, meshMax.z };
    size_t tableLen = LUA->ObjLen(-5);
    LUA->Pop(4);    //pops all stuff above, the table is now at index -1

    //add the prop
    Prop p = Prop();
    p.pos = meshPos;
    p.ang = meshAng;
    p.lastPos = meshPos;
    p.lastAng = meshAng;
    p.verts = NvFlexAllocBuffer(flexLibrary, tableLen, sizeof(float4), eNvFlexBufferHost);
    p.indices = NvFlexAllocBuffer(flexLibrary, tableLen, sizeof(int), eNvFlexBufferHost);

    float4* hostVerts = (float4*)(NvFlexMap(p.verts, eNvFlexMapWait));
    int* hostIndices = (int*)(NvFlexMap(p.indices, eNvFlexMapWait));

    for (int i = 0; i < tableLen; i++) {
        LUA->PushNumber((double)i + 1.0);   //lua is 1 indexed, C++ is 0 indexed
        LUA->GetTable(-2);

        Vector thisPos = LUA->GetVector();
        float4 vert = float4(thisPos, 0.f);
        hostVerts[i] = vert;
        hostIndices[i] = i;

        //counter clockwise -> clockwise triangle winding
        if (i % 3 == 1) {
            int host = hostIndices[i];
            hostIndices[i] = hostIndices[i - 1];
            hostIndices[i - 1] = host;
        }
        LUA->Pop(); //pop pos
    }
    LUA->Pop(); //pop table
    NvFlexUnmap(p.verts);
    NvFlexUnmap(p.indices);

    // create the triangle mesh
    p.meshID = NvFlexCreateTriangleMesh(flexLibrary);
    NvFlexUpdateTriangleMesh(flexLibrary, p.meshID, p.verts, p.indices, tableLen, tableLen / 3, minFloat, maxFloat);

    mapBuffers();
    simBuffers->flags[PropCount] = NvFlexMakeShapeFlags(eNvFlexShapeTriangleMesh, PropCount != 0);	//index 0 is ALWAYS the world
    simBuffers->geometry[PropCount].triMesh.mesh = p.meshID;
    simBuffers->geometry[PropCount].triMesh.scale[0] = 1.0f;
    simBuffers->geometry[PropCount].triMesh.scale[1] = 1.0f;
    simBuffers->geometry[PropCount].triMesh.scale[2] = 1.0f;
    simBuffers->positions[PropCount] = meshPos;
    simBuffers->rotations[PropCount] = meshAng;	//dont set rotation to 0,0,0,0 or flex kabooms
    simBuffers->prevPositions[PropCount] = meshPos;
    simBuffers->prevRotations[PropCount] = meshAng;
    unmapBuffers();

    props.push_back(p);
    PropCount++;
}

//make a capsule mesh collider
void FLEX_API::addMeshCapsule(GarrysMod::Lua::ILuaBase* LUA) {
    float4 meshAng = quatFromAngle(LUA->GetAngle(-1));
    float4 meshPos = float4(LUA->GetVector(-2), 1.f / 50000.f);
    float meshRadius = LUA->GetNumber(-3);
    float meshLength = LUA->GetNumber(-4);
    LUA->Pop(4);    //pops all stuff above, the table is now at index -1

    //add the prop
    Prop p = Prop();
    p.pos = meshPos;
    p.ang = meshAng;
    p.lastPos = meshPos;
    p.lastAng = meshAng;

    mapBuffers();
    simBuffers->flags[PropCount] = NvFlexMakeShapeFlags(eNvFlexShapeCapsule, true);	//index 0 is ALWAYS the world
    simBuffers->geometry[PropCount].capsule.halfHeight = meshLength;
    simBuffers->geometry[PropCount].capsule.radius = meshRadius;
    simBuffers->positions[PropCount] = meshPos;
    simBuffers->rotations[PropCount] = meshAng;	//dont set rotation to 0,0,0,0 or flex kabooms
    simBuffers->prevPositions[PropCount] = meshPos;
    simBuffers->prevRotations[PropCount] = meshAng;
    unmapBuffers();

    props.push_back(p);
    PropCount++;
}

//updates position of mesh `id` (50000 is max gmod weight)
void FLEX_API::updateMeshPos(Vector pos, QAngle ang, int id) {
    props[id].pos = float4(pos, 1.f / 50000.f);
    props[id].ang = quatFromAngle(ang);
}
