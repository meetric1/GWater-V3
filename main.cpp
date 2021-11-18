#include "declarations.h"
#include <string>

using namespace GarrysMod::Lua;

std::shared_ptr<flexAPI> flexLib;
GarrysMod::Lua::ILuaBase* GlobalLUA;

std::mutex* bufferMutex;
float4* particleBufferHost;

int numParticles = 0;
int propCount = 0;
bool simValid = true;

//overloaded printlua func
void printLua(std::string text)
{
	GlobalLUA->PushSpecial(SPECIAL_GLOB);
	GlobalLUA->GetField(-1, "print");
	GlobalLUA->PushString(text.c_str());
	GlobalLUA->Call(1, 0);
	GlobalLUA->Pop();
}
void printLua(char* text)
{
	GlobalLUA->PushSpecial(SPECIAL_GLOB);
	GlobalLUA->GetField(-1, "print");
	GlobalLUA->PushString(text);
	GlobalLUA->Call(1, 0);
	GlobalLUA->Pop();
}


////////QUAT LIB//////////

#define _PI 3.14159265358979323846
float rad(float degree) {
	return (degree * (_PI / 180));
}

//oh my ucking god kill me
float4 getQuatMul(float4 lhs, float4 rhs) {
	return float4{
		lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z - lhs.w * rhs.w,
		lhs.x * rhs.y + lhs.y * rhs.x + lhs.z * rhs.w - lhs.w * rhs.z,
		lhs.x * rhs.z + lhs.z * rhs.x + lhs.w * rhs.y - lhs.y * rhs.w,
		lhs.x * rhs.w + lhs.w * rhs.x + lhs.y * rhs.z - lhs.z * rhs.y
	};
}

float4 quatFromAngleComponents(float p, float y, float r) {
	p = rad(p) * 0.5;
	y = rad(y) * 0.5;
	r = rad(r) * 0.5;

	float4 q_x = float4{ static_cast<float>(cos(y)), 0, 0, static_cast<float>(sin(y)) };
	float4 q_y = float4{ static_cast<float>(cos(p)), 0, static_cast<float>(sin(p)), 0 };
	float4 q_z = float4{ static_cast<float>(cos(r)), static_cast<float>(sin(r)), 0, 0 };

	return getQuatMul(q_x, getQuatMul(q_y, q_z));
}


float4 quatFromAngle(QAngle ang) {
	return quatFromAngleComponents(ang.x, ang.y, ang.z);
}

float4 unfuckQuat(float4 q) {
	return float4{ q.y, q.z, q.w, q.x };
}


#define ADD_FUNC(funcName, tblName) GlobalLUA->PushCFunction(funcName); GlobalLUA->SetField(-2, tblName);

//random extras
float distance2(float4 a, float3 b) {
	float x = b.x - a.x;
	float y = b.y - a.y;
	float z = b.z - a.z;

	return (x * x + y * y + z * z);
}


float dot(float3 a, float3 b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

float3 subtractFloat34(float4 a, float3 b) {
	return float3{ a.x - b.x, a.y - b.y, a.z - b.z };
}



////////// LUA FUNCTIONS /////////////

//renders particles
LUA_FUNCTION(RenderParticles) {

	//get headpos and headang
	LUA->CheckType(-1, Type::Vector);
	LUA->CheckType(-2, Type::Vector);

	Vector gmodDir = LUA->GetVector();
	float3 dir = float3{ gmodDir.x, gmodDir.y, gmodDir.z };

	Vector gmodPos = LUA->GetVector(-2);
	float3 pos = float3{ gmodPos.x, gmodPos.y, gmodPos.z };

	LUA->Pop(2);

	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->GetField(-1, "render");

	float particleRadius = flexLib->radius;

	//loop thru all particles, any that we cannot see are not sent to gmod
	for (int i = 0; i < numParticles; i++) {
		float4 thisPos = particleBufferHost[i];

		if (dot(subtractFloat34(thisPos, pos), dir) < 0 || distance2(thisPos, pos) > 25000000) {
			continue;
		}

		Vector gmodPos;
		gmodPos.x = thisPos.x;
		gmodPos.y = thisPos.y;
		gmodPos.z = thisPos.z;

		//draws the sprite
		LUA->GetField(-1, "DrawSprite");
		LUA->PushVector(gmodPos);
		LUA->PushNumber(particleRadius);
		LUA->PushNumber(particleRadius);
		LUA->Call(3, 0);	//pops literally everything above except render and _G

	}

	LUA->Pop(2); //pop _G and render
	LUA->PushNumber(numParticles);

	return 1;
}

//xyz data triangle test
LUA_FUNCTION(GetData) {
	LUA->CreateTable();

	//loop thru all particles & add to table (on stack)
	for (int i = 0; i < numParticles; i++) {

		float4 thisPos = particleBufferHost[i];

		Vector gmodPos;
		gmodPos.x = thisPos.x;
		gmodPos.y = thisPos.y;
		gmodPos.z = thisPos.z;

		LUA->PushNumber(static_cast<double>(i) + 1);
		LUA->PushVector(gmodPos);
		LUA->SetTable(-3);
	}

	return 1;
}


//removes all particles in the simulation
LUA_FUNCTION(RemoveAll) {
	bufferMutex->lock();
	if (!simValid) {
		bufferMutex->unlock();
		return 0;
	}
	
	flexLib->removeAllParticles();

	bufferMutex->unlock();

	return 0;
}

//sets radius of particles
LUA_FUNCTION(SetRadius) {
	LUA->CheckType(-1, Type::Number);
	flexLib->initParamsRadius(static_cast<float>(LUA->GetNumber()));
	LUA->Pop();
	return 0;
}

//stops simulation
LUA_FUNCTION(DeleteSimulation) {
	flexLib.reset();

	//set .gwater to nil
	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushNil();
	LUA->SetField(-2, "gwater");
	LUA->Pop(); // pop _G

	return 0;
}

LUA_FUNCTION(SpawnParticle) {
	//check to see if they are both vectors
	LUA->CheckType(-2, Type::Vector); // pos
	LUA->CheckType(-1, Type::Vector); // vel

	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(-2);	//pos
	Vector gmodVel = LUA->GetVector(-1);	//vel

	flexLib->addParticle(gmodPos, gmodVel);

	//remove vel and pos from stack
	LUA->Pop(2);	

	return 0;
}

LUA_FUNCTION(SpawnCube) {
	//check to see if they are both vectors
	LUA->CheckType(-4, Type::Vector); // pos
	LUA->CheckType(-3, Type::Vector); // size
	LUA->CheckType(-2, Type::Number); // size apart (usually radius)
	LUA->CheckType(-1, Type::Vector); // vel

	//gmod Vector
	Vector gmodPos = LUA->GetVector(-4);	//pos
	Vector gmodSize = LUA->GetVector(-3);	//size
	float size = LUA->GetNumber(-2);		//size apart
	Vector gmodVel = LUA->GetVector(-1);	//vel

	for (int z = -gmodSize.z; z <= gmodSize.z; z++) {
		for (int y = -gmodSize.y; y <= gmodSize.y; y++) {
			for (int x = -gmodSize.x; x <= gmodSize.x; x++) {

				Vector offset;
				offset.x = gmodPos.x + x * size;
				offset.y = gmodPos.y + y * size;
				offset.z = gmodPos.z + z * size;

				flexLib->addParticle(offset, gmodVel);
			}

		}

	}

	//remove pos, size, size, and vel
	LUA->Pop(4);

	return 0;
}

LUA_FUNCTION(SpawnSphere) {
	//check to see if they are both vectors
	LUA->CheckType(-4, Type::Vector); // pos
	LUA->CheckType(-3, Type::Number); // size
	LUA->CheckType(-2, Type::Number); // size apart (usually radius)
	LUA->CheckType(-1, Type::Vector); // vel

	//gmod Vector
	Vector gmodPos = LUA->GetVector(-4);	//pos
	float radius = LUA->GetNumber(-3);	//radius
	float size = LUA->GetNumber(-2);		//size apart
	Vector gmodVel = LUA->GetVector(-1);	//vel

	for (int z = -radius; z <= radius; z++) {
		for (int y = -radius; y <= radius; y++) {
			for (int x = -radius; x <= radius; x++) {
				if (x * x + y * y + z * z >= radius * radius) continue;

				Vector offset;
				offset.x = gmodPos.x + x * size;
				offset.y = gmodPos.y + y * size;
				offset.z = gmodPos.z + z * size;

				flexLib->addParticle(offset, gmodVel);
			}

		}

	}

	//remove pos, size, size, and vel
	LUA->Pop(4);

	return 0;
}

//andreweathan
LUA_FUNCTION(SpawnCubeExact) {
	//check to see if they are both vectors
	LUA->CheckType(-4, Type::Vector); // pos
	LUA->CheckType(-3, Type::Vector); // size
	LUA->CheckType(-2, Type::Number); // size apart (usually radius)
	LUA->CheckType(-1, Type::Vector); // vel

	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(-4);	//pos
	Vector gmodSize = LUA->GetVector(-3);	//size
	float size = LUA->GetNumber(-2);		//size apart
	Vector gmodVel = LUA->GetVector(-1);	//vel

	gmodSize.x /= 2;
	gmodSize.y /= 2;
	gmodSize.z /= 2;

	for (float z = -gmodSize.z; z < gmodSize.z; z++) {
		for (float y = -gmodSize.y ; y < gmodSize.y; y++) {
			for (float x = -gmodSize.x; x < gmodSize.x; x++) {

				Vector newPos;
				newPos.x = (x * size) + gmodPos.x;
				newPos.y = (y * size) + gmodPos.y;
				newPos.z = (z * size) + gmodPos.z;

				flexLib->addParticle(newPos, gmodVel);
			}
		}
	}

	LUA->Pop(4);

	return 0;
}

//the world mesh
LUA_FUNCTION(AddConvexMesh) {

	LUA->CheckType(-1, Type::Vector); // Max
	LUA->CheckType(-2, Type::Vector); // Min
	LUA->CheckType(-3, Type::Table);  // Sorted verts

	//obbminmax
	Vector maxV = LUA->GetVector();
	Vector minV = LUA->GetVector(-2);
	float minFloat[3] = { minV.x, minV.y, minV.z };
	float maxFloat[3] = { maxV.x, maxV.y, maxV.z };
	LUA->Pop(2); //pop off min & max

	//lock buffer
	bufferMutex->lock();

	if (!simValid) {
		bufferMutex->unlock();
		LUA->PushBool(false);
		return 0;
	}

	size_t len = LUA->ObjLen();

	//check to make sure the mesh is even valid (error models)
	if (len < 1 || len % 3 != 0) {
		bufferMutex->unlock();
		printLua("[GWATER]: Invalid mesh given");
		LUA->PushBool(false);
		return 1;
	}

	if (len / 3 <= 64) {
		flexLib->addMeshConvex(LUA, minFloat, maxFloat, LUA->ObjLen());
		printLua("[GWATER]: Added convex mesh " + std::to_string(propCount));
	}
	else {
		flexLib->addMeshConcave(LUA, minFloat, maxFloat, LUA->ObjLen());
		printLua("[GWATER]: Too many tris for mesh " + std::to_string(propCount) + ", adding as concave mesh!");
	}

	bufferMutex->unlock();

	LUA->PushBool(true);

	return 1;

}


LUA_FUNCTION(AddConcaveMesh) {

	LUA->CheckType(-1, Type::Vector); // Max
	LUA->CheckType(-2, Type::Vector); // Min
	LUA->CheckType(-3, Type::Table);  // Sorted verts

	//obbminmax
	Vector maxV = LUA->GetVector();
	Vector minV = LUA->GetVector(-2);
	float minFloat[3] = { minV.x, minV.y, minV.z };
	float maxFloat[3] = { maxV.x, maxV.y, maxV.z };
	LUA->Pop(2); //pop off min & max

	//lock buffer
	bufferMutex->lock();

	if (!simValid) {
		bufferMutex->unlock();
		LUA->PushBool(false);
		return 1;
	}

	size_t len = LUA->ObjLen();

	//check to make sure the mesh is even valid (error models)
	if (len < 1 || len % 3 != 0) {
		bufferMutex->unlock();
		printLua("[GWATER]: Invalid mesh given");
		LUA->PushBool(false);
		return 1;
	}

	flexLib->addMeshConcave(LUA, minFloat, maxFloat, LUA->ObjLen());
	printLua("[GWATER]: Added concave mesh " + std::to_string(propCount));

	bufferMutex->unlock();

	LUA->PushBool(true);

	return 1;
}

LUA_FUNCTION(Blackhole) {

	LUA->CheckType(-1, Type::Number); // radius
	LUA->CheckType(-2, Type::Vector); // pos

	float radius = LUA->GetNumber();
	Vector vec = LUA->GetVector(-2);
	
	flexLib->removeInRadius(float3{vec.x, vec.y, vec.z}, radius * radius);

	return 0;
}

LUA_FUNCTION(SpawnForceField) {
	LUA->CheckType(-1, Type::Number); // type
	LUA->CheckType(-2, Type::Bool); // linear
	LUA->CheckType(-3, Type::Number);  // strength
	LUA->CheckType(-4, Type::Number);  // radius
	LUA->CheckType(-5, Type::Vector);  // pos

	flexLib->addForceField(LUA->GetVector(-5), LUA->GetNumber(-4), LUA->GetNumber(-3), LUA->GetBool(-2), LUA->GetNumber(-1));

	LUA->Pop(5);
	return 0;
}

LUA_FUNCTION(RemoveForceField) {
	LUA->CheckType(-1, Type::Number); // ID of forcefield

	flexLib->deleteForceField(LUA->GetNumber(-1));

	LUA->Pop(1);
	return 0;
}

LUA_FUNCTION(SetMeshPos) {

	if (!simValid) return 0;

	LUA->CheckType(-1, Type::Number); // ID
	LUA->CheckType(-2, Type::Angle); // Ang pyr
	LUA->CheckType(-3, Type::Vector); // pos

	int id = static_cast<int>(LUA->GetNumber(-1));	//lua is 1 indexed
	QAngle gmodAng = LUA->GetAngle(-2);
	Vector gmodPos = LUA->GetVector(-3);

	// 1.f/50000.f inverse mass?
	flexLib->updateMeshPos(float4{ gmodPos.x, gmodPos.y, gmodPos.z, 1.f / 50000.f }, unfuckQuat(quatFromAngle(gmodAng)), id);

	LUA->Pop(3);	//pop id, ang, pos
	return 0;
}


LUA_FUNCTION(RemoveMesh) {
	LUA->CheckType(-1, Type::Number); // ID
	int id = static_cast<int>(LUA->GetNumber());	

	bufferMutex->lock();
	if (!simValid) {
		bufferMutex->unlock();
		return 0;
	}

	flexLib->freeProp(id);

	bufferMutex->unlock();

	LUA->Pop();	//pop id

	return 0;
}

LUA_FUNCTION(UpdateParam) {
	LUA->CheckType(-1, Type::Number); 
	LUA->CheckType(-2, Type::String); //ID of param

	float n = LUA->GetNumber();
	std::string str = LUA->GetString(-2);
	flexLib->updateParam(str, n);

	LUA->Pop(2);

	return 0;
}


//called when module is opened
GMOD_MODULE_OPEN()
{
	GlobalLUA = LUA;
	LUA->PushSpecial(SPECIAL_GLOB);

	LUA->CreateTable();
	ADD_FUNC(RenderParticles, "RenderParticles");
	ADD_FUNC(DeleteSimulation, "DeleteSimulation");
	ADD_FUNC(AddConvexMesh, "AddConvexMesh");
	ADD_FUNC(AddConcaveMesh, "AddConcaveMesh");
	ADD_FUNC(SpawnParticle, "SpawnParticle");
	ADD_FUNC(RemoveAll, "RemoveAll");
	ADD_FUNC(SetMeshPos, "SetMeshPos");
	ADD_FUNC(RemoveMesh, "RemoveMesh");
	ADD_FUNC(SpawnCube, "SpawnCube");
	ADD_FUNC(SpawnSphere, "SpawnSphere");
	ADD_FUNC(SpawnCubeExact, "SpawnCubeExact");
	ADD_FUNC(GetData, "GetData");
	ADD_FUNC(Blackhole, "Blackhole");
	ADD_FUNC(SpawnForceField, "SpawnForceField");
	ADD_FUNC(RemoveForceField, "RemoveForceField");

	//param funcs
	ADD_FUNC(SetRadius, "SetRadius");
	ADD_FUNC(UpdateParam, "UpdateParam");

	LUA->SetField(-2, "gwater");
	LUA->Pop(); //remove _G

	// Initialize FleX api class
	flexLib = std::make_shared<flexAPI>();

	return 0;

}

// Called when the module is unloaded
GMOD_MODULE_CLOSE()
{

	flexLib.reset();

	//set .gwater to nil
	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushNil();
	LUA->SetField(-2, "gwater");
	LUA->Pop(); // pop _G

	return 0;

}