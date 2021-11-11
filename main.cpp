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


#define ADD_GWATER_FUNC(funcName, tblName) GlobalLUA->PushCFunction(funcName); GlobalLUA->SetField(-2, tblName);


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

//returns particle xyz data
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
		LUA->PushNumber(10);
		LUA->PushNumber(10);
		LUA->Call(3, 0);	//pops literally everything above except render and _G

	}

	LUA->Pop(2); //pop _G and render
	LUA->PushNumber(numParticles);

	return 1;
}

//removes all particles in the simulation
LUA_FUNCTION(RemoveAllParticles) {
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

	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(-4);	//pos
	Vector gmodSize = LUA->GetVector(-3);	//size
	Vector gmodVel = LUA->GetVector(-1);	//vel
	float size = LUA->GetNumber(-2);

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
	Vector gmodVel = LUA->GetVector(-1);	//vel
	float size = LUA->GetNumber(-2);

	for (float z = -gmodSize.z * size; z < gmodSize.z * size; z++)
		for (float y = -gmodSize.y * size; y < gmodSize.y * size; y++)
			for (float x = -gmodSize.x * size; x < gmodSize.x * size; x++) {

				Vector newPos;
				newPos.x = x + gmodPos.x;
				newPos.y = x + gmodPos.y;
				newPos.z = x + gmodPos.z;

				flexLib->addParticle(newPos, gmodVel);
			}

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

LUA_FUNCTION(BlackHole) {

	LUA->CheckType(-1, Type::Number); // radius
	LUA->CheckType(-2, Type::Vector); // pos

	float radius = LUA->GetNumber();
	Vector vec = LUA->GetVector(-2);
	
	//flexLib->removeInRadius(float3{vec.x, vec.y, vec.z}, radius * radius);

	return 0;
}

LUA_FUNCTION(SetMeshPos) {

	if (!simValid) return 0;

	LUA->CheckType(-1, Type::Number); // ID
	LUA->CheckType(-2, Type::Vector); // Pos

	LUA->CheckType(-3, Type::Vector); // Ang xyz
	LUA->CheckType(-4, Type::Number); // Ang w

	int id = static_cast<int>(LUA->GetNumber());	//lua is 1 indexed
	Vector gmodPos = LUA->GetVector(-2);
	Vector gmodAng = LUA->GetVector(-3);
	float gmodAngW = static_cast<float>(LUA->GetNumber(-4));

	flexLib->updateMeshPos(float4{ gmodPos.x, gmodPos.y, gmodPos.z, 1.f / 50000.f }, float4{ gmodAng.x, gmodAng.y, gmodAng.z, gmodAngW }, id);

	LUA->Pop(4);	//pop id, pos, ang and angw
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

LUA_FUNCTION(UpdateParam){
	LUA->CheckType(-1, Type::Number); 
	LUA->CheckType(-2, Type::String); //ID of param

	float n = LUA->GetNumber();
	std::string str = LUA->GetString(-2);
	flexLib->updateParam(str, n);

	LUA->Pop(2);

	return 0;
}



GMOD_MODULE_OPEN()
{
	GlobalLUA = LUA;
	LUA->PushSpecial(SPECIAL_GLOB);

	LUA->CreateTable();
	ADD_GWATER_FUNC(RenderParticles, "RenderParticles");
	ADD_GWATER_FUNC(DeleteSimulation, "DeleteSimulation");
	ADD_GWATER_FUNC(AddConvexMesh, "AddConvexMesh");
	ADD_GWATER_FUNC(AddConcaveMesh, "AddConcaveMesh");
	ADD_GWATER_FUNC(SpawnParticle, "SpawnParticle");
	ADD_GWATER_FUNC(RemoveAllParticles, "RemoveAll");
	ADD_GWATER_FUNC(SetMeshPos, "SetMeshPos");
	ADD_GWATER_FUNC(RemoveMesh, "RemoveMesh");
	ADD_GWATER_FUNC(SpawnCube, "SpawnCube");
	ADD_GWATER_FUNC(SpawnCube, "SpawnCubeExact");

	//param funcs
	ADD_GWATER_FUNC(SetRadius, "SetRadius");
	ADD_GWATER_FUNC(UpdateParam, "UpdateParam");

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