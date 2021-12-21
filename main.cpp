#include "declarations.h"
#include "util.h"
#include <string>

using namespace GarrysMod::Lua;

std::shared_ptr<FLEX_API> FLEX_Simulation;
GarrysMod::Lua::ILuaBase* GlobalLUA;

std::mutex* bufferMutex;
float4* particleBufferHost;

int ParticleCount = 0;
int PropCount = 0;
bool SimValid = true;

//overloaded printlua func
void LUA_Print(std::string text)
{
	GlobalLUA->PushSpecial(SPECIAL_GLOB);
	GlobalLUA->GetField(-1, "print");
	GlobalLUA->PushString(text.c_str());
	GlobalLUA->Call(1, 0);
	GlobalLUA->Pop();
}

void LUA_Print(char* text)
{
	GlobalLUA->PushSpecial(SPECIAL_GLOB);
	GlobalLUA->GetField(-1, "print");
	GlobalLUA->PushString(text);
	GlobalLUA->Call(1, 0);
	GlobalLUA->Pop();
}


////////// LUA FUNCTIONS /////////////
//renders particles
LUA_FUNCTION(RenderParticles) 
{
	//get headpos and headang
	LUA->CheckType(1, Type::Vector);
	LUA->CheckType(2, Type::Vector);

	float3 dir = float3(LUA->GetVector());
	float3 pos = float3(LUA->GetVector(-2));

	LUA->Pop(2);
	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->GetField(-1, "render");

	float particleRadius = FLEX_Simulation->radius;

	//loop thru all particles, any that we cannot see are not rendered
	for (int i = 0; i < ParticleCount; i++) {
		float3 thisPos = float3(particleBufferHost[i]);

		if (Dot(thisPos - pos, dir) < 0 || DistanceSquared(thisPos, pos) > MAX_DISTANCE_SQRD) continue;

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
	LUA->PushNumber(ParticleCount);

	return 1;
}

LUA_FUNCTION(ParticlesNear) {
	//get headpos
	LUA->CheckType(1, Type::Vector);
	LUA->CheckType(2, Type::Number);

	float3 pos = float3(LUA->GetVector(1));
	float particleRadius = (float)pow(FLEX_Simulation->radius * LUA->GetNumber(2), 2);
	int particlesBeside = 0;

	for (int i = 0; i < ParticleCount; i++) {
		float3 thisPos = float3(particleBufferHost[i]);
		if (DistanceSquared(thisPos, pos) < particleRadius) {
			particlesBeside++;
		}
	}

	LUA->PushNumber(particlesBeside);
	return 1;
}

//xyz data triangle test
LUA_FUNCTION(GetData) {
	LUA->CreateTable();

	//loop thru all particles & add to table (on stack)
	for (int i = 0; i < ParticleCount; i++) {

		float4 thisPos = particleBufferHost[i];

		Vector gmodPos;
		gmodPos.x = thisPos.x;
		gmodPos.y = thisPos.y;
		gmodPos.z = thisPos.z;

		LUA->PushNumber((double)i + 1);
		LUA->PushVector(gmodPos);
		LUA->SetTable(-3);
	}

	return 1;
}

//removes all particles in the simulation
LUA_FUNCTION(RemoveAll) {
	bufferMutex->lock();

	if (!SimValid) {
		bufferMutex->unlock();
		return 0;
	}
	
	FLEX_Simulation->removeAllParticles();
	bufferMutex->unlock();

	return 0;
}

//sets radius of particles
LUA_FUNCTION(SetRadius) {
	LUA->CheckType(1, Type::Number);
	float radius = (float)LUA->GetNumber();

	if (radius > 8192 || !(radius > 0)) {
		LUA->ThrowError(("Tried to set GWater particle radius to " + std::to_string(radius) + "! (8192 max)").c_str());
		return 0; 
	}

	FLEX_Simulation->initParamsRadius(radius);
	LUA->Pop();
	return 0;
}

//stops simulation
LUA_FUNCTION(DeleteSimulation) {
	if (!SimValid) return 0;
	FLEX_Simulation.reset();

	//set .gwater to nil
	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushNil();
	LUA->SetField(-2, "gwater");
	LUA->Pop(); // pop _G

	return 0;
}

LUA_FUNCTION(SpawnParticle) {
	//check to see if they are both vectors
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // vel

	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(1);	//pos
	Vector gmodVel = LUA->GetVector(2);	//vel

	FLEX_Simulation->addParticle(gmodPos, gmodVel);

	//remove vel and pos from stack
	LUA->Pop(2);	

	return 0;
}

LUA_FUNCTION(SpawnCube) {
	//check to see if they are both vectors
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // size
	LUA->CheckType(3, Type::Number); // size apart (usually radius)
	LUA->CheckType(4, Type::Vector); // vel

	//gmod Vector
	Vector gmodPos = LUA->GetVector(1);		//pos
	Vector gmodSize = LUA->GetVector(2);	//size
	float size = LUA->GetNumber(3);			//size apart
	Vector gmodVel = LUA->GetVector(4);		//vel

	for (int z = -gmodSize.z; z <= gmodSize.z; z++) {
		for (int y = -gmodSize.y; y <= gmodSize.y; y++) {
			for (int x = -gmodSize.x; x <= gmodSize.x; x++) {
				Vector offset;
				offset.x = gmodPos.x + x * size;
				offset.y = gmodPos.y + y * size;
				offset.z = gmodPos.z + z * size;

				FLEX_Simulation->addParticle(offset, gmodVel);
			}
		}
	}

	//remove pos, size, size, and vel
	LUA->Pop(4);

	return 0;
}

LUA_FUNCTION(SpawnSphere) {
	//check to see if they are both vectors
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Number); // size
	LUA->CheckType(3, Type::Number); // size apart (usually radius)
	LUA->CheckType(4, Type::Vector); // vel

	//gmod Vector
	Vector gmodPos = LUA->GetVector(1);		//pos
	float radius = LUA->GetNumber(2);		//radius
	float size = LUA->GetNumber(3);			//size apart
	Vector gmodVel = LUA->GetVector(4);		//vel

	for (int z = -radius; z <= radius; z++) {
		for (int y = -radius; y <= radius; y++) {
			for (int x = -radius; x <= radius; x++) {
				if (x * x + y * y + z * z >= radius * radius) continue;

				Vector offset;
				offset.x = gmodPos.x + x * size;
				offset.y = gmodPos.y + y * size;
				offset.z = gmodPos.z + z * size;

				FLEX_Simulation->addParticle(offset, gmodVel);
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
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // size
	LUA->CheckType(3, Type::Number); // size apart (usually radius)
	LUA->CheckType(4, Type::Vector); // vel

	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(1);		//pos
	Vector gmodSize = LUA->GetVector(2);	//size
	float size = LUA->GetNumber(3);			//size apart
	Vector gmodVel = LUA->GetVector(4);		//vel

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

				FLEX_Simulation->addParticle(newPos, gmodVel);
			}
		}
	}

	LUA->Pop(4);

	return 0;
}

//mesh creation funcs
LUA_FUNCTION(AddConvexMesh) {
	LUA->CheckType(1, Type::Table);  // Sorted verts
	LUA->CheckType(2, Type::Vector); // Min
	LUA->CheckType(3, Type::Vector); // Max
	LUA->CheckType(4, Type::Vector); // prop pos
	LUA->CheckType(5, Type::Angle);  // prop angle

	//is the mesh valid?
	size_t len = LUA->ObjLen(-5);
	if (len < 1 || len % 3 != 0) {
		LUA->PushBool(false);
		return 1;
	}

	//lock buffer
	bufferMutex->lock();
	if (!SimValid) {
		bufferMutex->unlock();
		LUA->PushBool(false);
		return 0;
	}

	//flex can only handle 64 convex planes!
	if (len / 3 <= 64) 
		FLEX_Simulation->addMeshConvex(LUA);
	else 
		FLEX_Simulation->addMeshConcave(LUA);

	bufferMutex->unlock();
	LUA->PushBool(true);

	return 1;
}

LUA_FUNCTION(AddConcaveMesh) {
	LUA->CheckType(1, Type::Table);  // Sorted verts
	LUA->CheckType(2, Type::Vector); // Min
	LUA->CheckType(3, Type::Vector); // Max
	LUA->CheckType(4, Type::Vector); // prop pos
	LUA->CheckType(5, Type::Angle); // prop angle

	//is the mesh valid?
	size_t len = LUA->ObjLen(-5);
	if (len < 1 || len % 3 != 0) {
		LUA->PushBool(false);
		return 1;
	}

	//lock buffer
	bufferMutex->lock();
	if (!SimValid) {
		bufferMutex->unlock();
		LUA->PushBool(false);
		return 1;
	}

	FLEX_Simulation->addMeshConcave(LUA);
	bufferMutex->unlock();
	LUA->PushBool(true);

	return 1;
}


LUA_FUNCTION(SetMeshPos) {
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Angle); // angle
	LUA->CheckType(3, Type::Number); // ID

	FLEX_Simulation->updateMeshPos(LUA->GetVector(-3), LUA->GetAngle(-2), LUA->GetNumber(-1));

	LUA->Pop(3);	//pop all
	return 0;
}

//Removes particles in a radius
LUA_FUNCTION(Blackhole) {
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Number); // radius
	FLEX_Simulation->removeInRadius(LUA->GetVector(-2), LUA->GetNumber());
	return 0;
}

// Andrew: this applies force to particles in an area
LUA_FUNCTION(ApplyForce) {
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // vel
	LUA->CheckType(3, Type::Number); // radius
	LUA->CheckType(4, Type::Bool); // linear?
	// if it's linear then particles at Radius position get the weakest force while the closest to Pos get the strongest
	// if it's not then every particle in that radius gets the same force

	Vector pos = LUA->GetVector(1); 
	Vector vel = LUA->GetVector(2);
	float radius = LUA->GetNumber(3);
	bool linear = LUA->GetBool(4);

	FLEX_Simulation->applyForce(float3(pos), float3(vel), radius, linear);

	return 0;
}

// this will help with simulating explosions and stuff affecting water
LUA_FUNCTION(ApplyForceOutwards) {
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Number); // force
	LUA->CheckType(3, Type::Number); // radius
	LUA->CheckType(4, Type::Bool); // linear?
	// if it's linear then particles at Radius position get the weakest force while the closest to Pos get the strongest
	// if it's not then every particle in that radius gets the same force

	Vector pos = LUA->GetVector(1); 
	float force = LUA->GetNumber(2);
	float radius = LUA->GetNumber(3);
	bool linear = LUA->GetBool(4);

	FLEX_Simulation->applyForceOutwards(pos, force, radius, linear);

	return 0;
}

//Forcefield functions
LUA_FUNCTION(SpawnForceField) {
	LUA->CheckType(1, Type::Vector);  // pos
	LUA->CheckType(2, Type::Number);  // radius
	LUA->CheckType(3, Type::Number);  // strength
	LUA->CheckType(4, Type::Bool); // linear
	LUA->CheckType(5, Type::Number); // type

	FLEX_Simulation->addForceField(LUA->GetVector(1), LUA->GetNumber(2), LUA->GetNumber(3), LUA->GetBool(4), LUA->GetNumber(5));

	LUA->Pop(5);
	return 0;
}

LUA_FUNCTION(EditForceField) {
	LUA->CheckType(1, Type::Number);  // ID
	LUA->CheckType(2, Type::Number);  // radius
	LUA->CheckType(3, Type::Number);  // strength
	LUA->CheckType(4, Type::Bool); // linear
	LUA->CheckType(5, Type::Number); // type

	int idx = LUA->GetNumber(1);

	if (idx < 0 || idx > 63) {
		LUA->ThrowError("Tried to edit a forcefield under index 0 or above 63!");
		return 0;
	}

	FLEX_Simulation->editForceField(idx, LUA->GetNumber(2), LUA->GetNumber(3), LUA->GetBool(4), LUA->GetNumber(5));

	LUA->Pop(5);
	return 0;
}

LUA_FUNCTION(SetForceFieldPos) {
	LUA->CheckType(1, Type::Number); // id
	LUA->CheckType(2, Type::Vector); // pos

	int idx = LUA->GetNumber(1);

	if (idx < 0 || idx > 63) {
		LUA->ThrowError("Tried to set a forcefield's position under index 0 or above 63!");
		return 0;
	}

	FLEX_Simulation->setForceFieldPos(idx, LUA->GetVector(2));

	LUA->Pop(2);
	return 0;
}

LUA_FUNCTION(RemoveForceField) {
	LUA->CheckType(1, Type::Number); // ID of forcefield
	int idx = LUA->GetNumber(1);

	if (idx < 0 || idx > 63) {
		LUA->ThrowError("Tried to remove a forcefield under index 0 or above 63!");
		return 0;
	}

	FLEX_Simulation->deleteForceField(idx);
	LUA->Pop();
	return 0;
}

LUA_FUNCTION(RemoveMesh) {
	LUA->CheckType(1, Type::Number); // ID
	int propidx = LUA->GetNumber(1);
	
	if (propidx < 0) {
		LUA->ThrowError("Tried to remove a mesh under index 0!");
		return 0;
	}

	bufferMutex->lock();
	if (!SimValid) {
		bufferMutex->unlock();
		return 0;
	}

	FLEX_Simulation->freeProp(propidx);
	bufferMutex->unlock();
	LUA->Pop();	//pop id

	return 0;
}

LUA_FUNCTION(UpdateParams) {
	LUA->CheckType(1, Type::String); //ID of param
	LUA->CheckType(2, Type::Number);

	FLEX_Simulation->updateParam(LUA->GetString(1), LUA->GetNumber(2));

	LUA->Pop(2);
	return 0;
}

LUA_FUNCTION(UpdateExtraParams) {
	LUA->CheckType(1, Type::String); //ID of param
	LUA->CheckType(2, Type::Number);

	FLEX_Simulation->updateExtraParam(LUA->GetString(1), LUA->GetNumber(2));

	LUA->Pop(2);
	return 0;
}

LUA_FUNCTION(GetModuleVersion) {
	LUA->PushNumber(GWATER_VERSION);
	return 1;
}


//called when module is opened
GMOD_MODULE_OPEN() {
	GlobalLUA = LUA;
	LUA->PushSpecial(SPECIAL_GLOB);

	LUA->CreateTable();
	//particle creation
	ADD_FUNC(SpawnParticle, "SpawnParticle");
	ADD_FUNC(SpawnCube, "SpawnCube");
	ADD_FUNC(SpawnSphere, "SpawnSphere");
	ADD_FUNC(SpawnCubeExact, "SpawnCubeExact");

	//meshes
	ADD_FUNC(AddConvexMesh, "AddConvexMesh");
	ADD_FUNC(AddConcaveMesh, "AddConcaveMesh");
	ADD_FUNC(SetMeshPos, "SetMeshPos");
	ADD_FUNC(RemoveMesh, "RemoveMesh");

	//rendering & data transfer
	ADD_FUNC(RenderParticles, "RenderParticles");
	ADD_FUNC(RemoveAll, "RemoveAll");
	ADD_FUNC(ParticlesNear, "ParticlesNear");
	ADD_FUNC(GetData, "GetData");

	//forces
	ADD_FUNC(SpawnForceField, "SpawnForceField");
	ADD_FUNC(RemoveForceField, "RemoveForceField");
	ADD_FUNC(SetForceFieldPos, "SetForceFieldPos");
	ADD_FUNC(EditForceField, "EditForceField");
	ADD_FUNC(ApplyForce, "ApplyForce");
	ADD_FUNC(ApplyForceOutwards, "ApplyForceOutwards");

	//param funcs
	ADD_FUNC(SetRadius, "SetRadius");
	ADD_FUNC(UpdateParams, "UpdateParams");
	ADD_FUNC(UpdateExtraParams, "UpdateExtraParams");

	//extras
	ADD_FUNC(DeleteSimulation, "DeleteSimulation");
	ADD_FUNC(Blackhole, "Blackhole");
	ADD_FUNC(GetModuleVersion, "GetModuleVersion");

	LUA->SetField(-2, "gwater");
	LUA->Pop(); //remove _G

	// Initialize FleX api class
	FLEX_Simulation = std::make_shared<FLEX_API>();

	return 0;
}

// Called when the module is unloaded
GMOD_MODULE_CLOSE() {
	FLEX_Simulation.reset();
	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->PushNil();
	LUA->SetField(-2, "gwater");
	LUA->Pop(); // pop _G

	return 0;
}