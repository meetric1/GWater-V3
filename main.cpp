#include "declarations.h"
#include "util.h"
#include <string>
#include "GarrysMod/Lua/LuaBase.h"

using namespace GarrysMod::Lua;

std::shared_ptr<FLEX_API> FLEX_Simulation;
GarrysMod::Lua::ILuaBase* GlobalLUA;

std::mutex* bufferMutex;
float4* particleBufferHost;
float4* diffuseBufferHost;

float simTimescale = 1;
int ParticleCount = 0;
int diffuseCount = 0;
int PropCount = 0;
bool SimValid = true;
int RenderDistance = pow(5000, 2);

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
LUA_FUNCTION(RenderParticles) {
	LUA->CheckType(-1, Type::Vector);	//dir left
	LUA->CheckType(-2, Type::Vector);	//dir right
	LUA->CheckType(-3, Type::Vector);	//dir down
	LUA->CheckType(-4, Type::Vector);	//dir up
	LUA->CheckType(-5, Type::Vector);	//eye pos
	LUA->CheckType(-6, Type::Number);	//override
	LUA->CheckType(-7, Type::Bool);	//render diffuse?

	if (ParticleCount < 1) return 0;

	float3 directionArray[4];
	for (int i = 0; i < 4; i++)
		directionArray[i] = LUA->GetVector(-i - 1);

	float3 eyePos = LUA->GetVector(-5);

	// draw sprite or sphere?
	bool renderDiffuse = LUA->GetBool(-7);
	float overrideNum = static_cast<float>(LUA->GetNumber(-6));
	float particleRadius = FLEX_Simulation->radius * overrideNum;
	const char* overrideString = overrideNum != 0.6f ? "GWater_DrawSprite" : "GWater_DrawSphere";

	LUA->Pop(6);
	LUA->PushSpecial(SPECIAL_GLOB);

	float4 particlePos;	// Reassign these, dont redeclare them
	float3 particleMinusPos;
	Vector gmodPos;
	Vector gmodColor;
	Vector gmodLastColor;
	gmodLastColor.x = -1.f;

	//we need to optimize the crap out of this because it can run 65 thousand times per frame!
	for (int i = 0; i < ParticleCount; i++) {
		particlePos = particleBufferHost[i];

		if (particlePos.w != 0.5f) continue;

		particleMinusPos = float3(particlePos) - eyePos;

		if (
			Dot(particleMinusPos, directionArray[0]) < 0 ||
			Dot(particleMinusPos, directionArray[1]) < 0 ||
			Dot(particleMinusPos, directionArray[2]) < 0 ||
			Dot(particleMinusPos, directionArray[3]) < 0
		) continue;

		if (DistanceSquared(particlePos, eyePos) > RenderDistance) continue;

		//reassign, do not redeclare
		gmodPos.x = particlePos.x;
		gmodPos.y = particlePos.y;
		gmodPos.z = particlePos.z;

		// if the color is different (or the first one) then we should update it
		gmodColor = FLEX_Simulation->particleColors[i];
		bool shouldChange = (gmodColor.x != gmodLastColor.x || gmodColor.y != gmodLastColor.y || gmodColor.z != gmodLastColor.z);
		if (shouldChange) {
			LUA->GetField(-1, "GWater_SetDrawColor");
			LUA->PushVector(gmodColor);
			LUA->Call(1, 0);
		}
		gmodLastColor = gmodColor;

		//draws the sprite
		LUA->GetField(-1, overrideString);
		LUA->PushVector(gmodPos);
		LUA->PushNumber(particleRadius);
		LUA->Call(2, 0);	//pops literally everything above except _G
	}

	if (!renderDiffuse) {
		LUA->Pop(1);
		FLEX_Simulation->flexParams->diffuseLifetime = 0.f;
		return 0;
	}
	else {
		FLEX_Simulation->flexParams->diffuseLifetime = 30.f;
	}

	// now render diffuse particles!
	gmodColor.x = gmodColor.x + 0.5;
	gmodColor.y = gmodColor.y + 0.5;
	gmodColor.z = gmodColor.z + 0.5;
	LUA->GetField(-1, "GWater_SetDrawColor");
	LUA->PushVector(gmodColor);
	LUA->Call(1, 0);

	for (int i = 0; i < diffuseCount; i++) {
		particlePos = diffuseBufferHost[i];
		particleMinusPos = float3(particlePos) - eyePos;

		if (particlePos.w < 1) continue;

		if (
			Dot(particleMinusPos, directionArray[0]) < 0 ||
			Dot(particleMinusPos, directionArray[1]) < 0 ||
			Dot(particleMinusPos, directionArray[2]) < 0 ||
			Dot(particleMinusPos, directionArray[3]) < 0
		) continue;

		if (DistanceSquared(particlePos, eyePos) > RenderDistance) continue;

		gmodPos.x = particlePos.x;
		gmodPos.y = particlePos.y;
		gmodPos.z = particlePos.z;

		//draws the sprite
		LUA->GetField(-1, overrideString);
		LUA->PushVector(gmodPos);
		LUA->PushNumber((particlePos.w / 120.f) * particleRadius);
		LUA->Call(2, 0);	//pops literally everything above except _G
	}

	LUA->Pop(1); //pop _G from stack

	return 0;
}

//Gets particles near a position in radius
LUA_FUNCTION(ParticlesNear) {
	//get headpos
	LUA->CheckType(1, Type::Vector);
	LUA->CheckType(2, Type::Number);

	float4 particlePos;
	float3 pos = float3(LUA->GetVector(1));
	float particleRadius = (float)pow(LUA->GetNumber(2), 2);
	int particlesBeside = 0;
	std::vector<int> range = std::vector<int>();

	for (int i = 0; i < ParticleCount; i++) {
		particlePos = particleBufferHost[i];
		if (particlePos.w != 0.5) continue;
		if (DistanceSquared(float3(particlePos), pos) < particleRadius) {
			particlesBeside++;
			range.push_back(i);
		}
	}

	LUA->PushNumber(particlesBeside);
	for (int i : range) LUA->PushNumber(i);
	return 1 + range.size();
}

LUA_FUNCTION(CleanLostParticles) {
	FLEX_Simulation->cleanLostParticles();
	return 0;
}

LUA_FUNCTION(CleanLoneParticles) {
	LUA->PushNumber(FLEX_Simulation->cleanLoneParticles());
	return 1;
}

LUA_FUNCTION(GetData) {
	LUA->CreateTable();

	//loop thru all particles & add to table (on stack)
	float4 thisPos;
	Vector gmodPos;
	for (int i = 0; i < ParticleCount; i++) {
		thisPos = particleBufferHost[i];
		gmodPos.x = thisPos.x;
		gmodPos.y = thisPos.y;
		gmodPos.z = thisPos.z;

		LUA->PushNumber((double)i + 1);
		LUA->PushVector(gmodPos);
		LUA->SetTable(-3);
	}

	return 1;
}

LUA_FUNCTION(GetSkewedData) {
	LUA->CreateTable();

	//loop thru all particles & add to table (on stack)
	float4 thisPos;
	Vector gmodPos;
	int n = 0;
	for (int i = 0; i < ParticleCount; i++) {
		if (particleBufferHost[i].w != 0.5) continue;

		thisPos = particleBufferHost[i];
		gmodPos.x = thisPos.x;
		gmodPos.y = thisPos.y;
		gmodPos.z = thisPos.z;

		LUA->PushNumber((double)n + 1);
		LUA->PushVector(gmodPos);
		LUA->SetTable(-3);

		n++;
	}

	return 1;
}

LUA_FUNCTION(GetClothData) {
	LUA->CreateTable();

	//loop thru all particles & add to table (on stack)
	float3 particlePos;
	Vector gmodPos;
	for (int i = 0; i < FLEX_Simulation->triangles.size(); i++) {
		LUA->PushNumber((double)i + 1);
		LUA->CreateTable();		//table inside bigger table

		for (int j = 0; j < FLEX_Simulation->triangles[i].size(); j++) {
			particlePos = particleBufferHost[FLEX_Simulation->triangles[i][j]];
			gmodPos.x = particlePos.x;
			gmodPos.y = particlePos.y;
			gmodPos.z = particlePos.z;

			LUA->PushNumber((double)j + 1);
			LUA->PushVector(gmodPos);
			LUA->SetTable(-3);	
		}

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

LUA_FUNCTION(RemoveAllCloth) {
	bufferMutex->lock();

	if (!SimValid) {
		bufferMutex->unlock();
		return 0;
	}

	FLEX_Simulation->removeAllCloth();
	bufferMutex->unlock();

	return 0;
}

//sphere intersection code for function below (gotta pick up particles somehow)
float sphereIntersection(float3 center, float radius, float3 origin, float3 direction) {
	float3 oc = origin - center;
	float a = Dot(direction, direction);
	float b = 2.f * Dot(oc, direction);
	float c = Dot(oc, oc) - radius * radius;
	float discriminant = b * b - 4 * a * c;
	if (discriminant < 0) {
		return -1.f;
	}
	else {
		return (-b - sqrt(discriminant)) / (2.f * a);
	}
}

//sets radius of particles
LUA_FUNCTION(TraceLine) {
	LUA->CheckType(1, Type::Vector);
	LUA->CheckType(2, Type::Vector);

	int particleIndex = -1;
	float dist = -1.f;
	float r = FLEX_Simulation->radius / 2.f;
	float4 pos;
	float3 rayOrigin = LUA->GetVector(1);
	float3 rayDirection = LUA->GetVector(2);

	for (int i = 0; i < ParticleCount; i++) {
		float particleHit = sphereIntersection(particleBufferHost[i], r, rayOrigin, rayDirection);
		if ((particleHit > 0.f && particleHit < dist) || dist < 0.f) {
			dist = particleHit;
			pos = particleBufferHost[i];
			particleIndex = i;
		}
	}

	Vector gmodVector;
	gmodVector.x = pos.x;
	gmodVector.y = pos.y;
	gmodVector.z = pos.z;

	LUA->Pop(2);
	LUA->PushNumber(dist);
	LUA->PushVector(gmodVector);
	LUA->PushNumber(particleIndex);
	return 3;
}

LUA_FUNCTION(SetParticlePos) {
	LUA->CheckType(1, Type::Number);
	LUA->CheckType(2, Type::Vector);
	LUA->CheckType(3, Type::Number);

	float invMass = FLEX_Simulation->editParticle(LUA->GetNumber(1), LUA->GetVector(2), float3(), LUA->GetNumber(3));

	LUA->Pop(2);
	LUA->PushNumber(invMass);
	return 1;
}


//sets radius of particles
LUA_FUNCTION(SetRadius) {
	LUA->CheckType(1, Type::Number);
	float radius = (float)LUA->GetNumber();

	if (radius > 8192 || !(radius > 0)) {
		LUA->ThrowError(("Tried to set GWater particle radius to " + std::to_string(radius) + "! (1 min, 8192 max)").c_str());
		return 0;
	}

	FLEX_Simulation->initParamsRadius(radius);
	LUA->Pop();
	return 0;
}

LUA_FUNCTION(GetRadius) {
	LUA->PushNumber(FLEX_Simulation->radius);
	return 1;
}

//A: sets max particles, this can't actually change the 65535 hard limit without editing the cpp
//so this will just change the limit that is checked by the code, and additionally erase any extra particles when maxparticles < particlecount 
LUA_FUNCTION(SetMaxParticles) {
	LUA->CheckType(1, Type::Number);
	FLEX_Simulation->SetParticleLimit((int)LUA->GetNumber());
	LUA->Pop();
	return 0;
}

//A: getter
LUA_FUNCTION(GetMaxParticles) {
	LUA->PushNumber(FLEX_Simulation->flexSolverDesc.maxParticles);
	return 1;
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
	LUA->CheckType(3, Type::Vector); // color


	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(1);	//pos
	Vector gmodVel = LUA->GetVector(2);	//vel
	Vector gmodColor = LUA->GetVector(3);	//color

	FLEX_Simulation->addParticle(gmodPos, gmodVel, gmodColor);

	//remove vel and pos from stack
	LUA->Pop(2);	

	return 0;
}

LUA_FUNCTION(SpawnCloth) {
	//check to see if they are both vectors
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Number); // width
	LUA->CheckType(3, Type::Number); // how close apart particles are
	LUA->CheckType(4, Type::Number); // stiffness
	bufferMutex->lock();
	if (!SimValid) {
		bufferMutex->unlock();
		return 1;
	}

	float num = LUA->GetNumber(5);
	if (LUA->GetNumber(5) <= 0) {	//getnumber returns 0 on fail
		num = 1.f;
	}
	
	FLEX_Simulation->addCloth(LUA->GetVector(1), LUA->GetNumber(2), LUA->GetNumber(3), LUA->GetNumber(4), num);

	bufferMutex->unlock();
	LUA->Pop(4);

	return 0;
}

LUA_FUNCTION(SpawnRigidbody) {
	//check to see if they are both vectors
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // width
	LUA->CheckType(3, Type::Number); // how close apart particles are
	LUA->CheckType(4, Type::Bool);	// constraint force
	//LUA->CheckType(4, Type::Number); // mass
	bufferMutex->lock();
	if (!SimValid) {
		bufferMutex->unlock();
		return 0;
	}

	float3 rigidRes = LUA->GetVector(2);
	FLEX_Simulation->addRigidbody(LUA->GetVector(1), rigidRes.x, rigidRes.y, rigidRes.z, LUA->GetNumber(3), float3(), 10.f, LUA->GetBool(4));

	bufferMutex->unlock();
	LUA->Pop(3);

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
	Vector gmodColor = LUA->GetVector(5);	//color

	for (int z = -radius; z <= radius; z++) {
		for (int y = -radius; y <= radius; y++) {
			for (int x = -radius; x <= radius; x++) {
				if (x * x + y * y + z * z >= radius * radius) continue;

				Vector offset;
				offset.x = gmodPos.x + x * size;
				offset.y = gmodPos.y + y * size;
				offset.z = gmodPos.z + z * size;

				FLEX_Simulation->addParticle(offset, gmodVel, gmodColor);
			}
		}
	}

	//remove pos, size, size, and vel
	LUA->Pop(4);

	return 0;
}

//andreweathan
LUA_FUNCTION(SpawnCube) {
	//check to see if they are both vectors
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // size
	LUA->CheckType(3, Type::Number); // size apart (usually radius)
	LUA->CheckType(4, Type::Vector); // vel
	LUA->CheckType(5, Type::Vector); // color


	//gmod Vector and fleX float4
	Vector gmodPos = LUA->GetVector(1);		//pos
	Vector gmodSize = LUA->GetVector(2);	//size
	float size = LUA->GetNumber(3);			//size apart
	Vector gmodVel = LUA->GetVector(4);		//vel
	Vector gmodColor = LUA->GetVector(5);	//color

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

				FLEX_Simulation->addParticle(newPos, gmodVel, gmodColor);
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

LUA_FUNCTION(AddCapsuleMesh) {
	LUA->CheckType(1, Type::Number); // Length
	LUA->CheckType(2, Type::Number); // Radius
	LUA->CheckType(3, Type::Vector); // prop pos
	LUA->CheckType(4, Type::Angle); // prop angle

	//lock buffer
	bufferMutex->lock();
	if (!SimValid) {
		bufferMutex->unlock();
		return 0;
	}

	FLEX_Simulation->addMeshCapsule(LUA);
	bufferMutex->unlock();

	return 0;
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
	LUA->PushNumber(FLEX_Simulation->removeInRadius(LUA->GetVector(-2), LUA->GetNumber()));
	return 1;
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

// i am so tired
LUA_FUNCTION(ApplyForceRange) {
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Vector); // vel
	LUA->CheckType(3, Type::Number); // radius
	LUA->CheckType(4, Type::Bool); // linear?
	LUA->CheckType(5, Type::Number); // amount of particles
	// if it's linear then particles at Radius position get the weakest force while the closest to Pos get the strongest
	// if it's not then every particle in that radius gets the same force

	std::vector<int> range = std::vector<int>();
	Vector pos = LUA->GetVector(1);
	Vector vel = LUA->GetVector(2);
	float radius = LUA->GetNumber(3);
	bool linear = LUA->GetBool(4);
	int count = (int)LUA->GetNumber(5);

	for (int i = 0; i < count; i++) {
		range.push_back((int)LUA->GetNumber(6 + i));
	}

	FLEX_Simulation->applyForceRange(float3(pos), float3(vel), radius, linear, range);

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

// this should help with physgun
LUA_FUNCTION(ApplyForceOutwardsRange) {
	LUA->CheckType(1, Type::Vector); // pos
	LUA->CheckType(2, Type::Number); // force
	LUA->CheckType(3, Type::Number); // radius
	LUA->CheckType(4, Type::Bool); // linear?
	LUA->CheckType(5, Type::Number); // amount of particles

	std::vector<int> range = std::vector<int>();
	Vector pos = LUA->GetVector(1);
	float force = LUA->GetNumber(2);
	float radius = LUA->GetNumber(3);
	bool linear = LUA->GetBool(4);
	int count = (int)LUA->GetNumber(5);

	for (int i = 0; i < count; i++) {
		range.push_back((int)LUA->GetNumber(6 + i));
	}

	FLEX_Simulation->applyForceOutwardsRange(pos, force, radius, linear, range);

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

LUA_FUNCTION(SetConfig) {
	LUA->CheckType(1, Type::String); //ID of param
	LUA->CheckType(2, Type::Number);

	FLEX_Simulation->updateParam(LUA->GetString(1), LUA->GetNumber(2));

	LUA->Pop(2);
	return 0;
}

LUA_FUNCTION(GetConfig) {
	LUA->CheckType(1, Type::String); //ID of param
	LUA->PushNumber(*FLEX_Simulation->flexMap[LUA->GetString()]);
	return 1;
}

LUA_FUNCTION(GetModuleVersion) {
	LUA->PushNumber(GWATER_VERSION);
	return 1;
}

LUA_FUNCTION(SetTimescale) {
	LUA->CheckType(-1, Type::Number);
	simTimescale = LUA->GetNumber();
	if (simTimescale < 0) simTimescale = 0;
	LUA->Pop();
	return 0;
}

LUA_FUNCTION(GetTimescale) {
	LUA->PushNumber(simTimescale);
	return 1;
}


LUA_FUNCTION(SetRenderDistance) {
	LUA->CheckType(-1, Type::Number);
	RenderDistance = pow(LUA->GetNumber(), 2);
	if (RenderDistance < 0) RenderDistance = 0;
	LUA->Pop();
	return 0;
}

LUA_FUNCTION(GetRenderDistance) {
	LUA->PushNumber(sqrt(RenderDistance));
	return 1;
}

LUA_FUNCTION(GetParticleCount) {
	LUA->PushNumber(ParticleCount);
	return 1;
}

void PopulateFunctions(ILuaBase* LUA) {
	LUA->PushSpecial(SPECIAL_GLOB);
	LUA->CreateTable();

	//particle-related
	ADD_FUNC(SpawnParticle, "SpawnParticle");
	ADD_FUNC(SpawnSphere, "SpawnSphere");
	ADD_FUNC(SpawnCube, "SpawnCube");
	ADD_FUNC(SpawnCloth, "SpawnCloth");
	ADD_FUNC(SpawnRigidbody, "SpawnRigidbody");
	ADD_FUNC(CleanLostParticles, "CleanLostParticles");
	ADD_FUNC(CleanLoneParticles, "CleanLoneParticles");
	ADD_FUNC(SetMaxParticles, "SetMaxParticles");
	ADD_FUNC(GetMaxParticles, "GetMaxParticles");
	ADD_FUNC(GetParticleCount, "GetParticleCount");
	ADD_FUNC(TraceLine, "TraceLine");
	ADD_FUNC(SetParticlePos, "SetParticlePos")

	//meshes
	ADD_FUNC(AddConvexMesh, "AddConvexMesh");
	ADD_FUNC(AddConcaveMesh, "AddConcaveMesh");
	ADD_FUNC(AddCapsuleMesh, "AddCapsuleMesh");
	ADD_FUNC(SetMeshPos, "SetMeshPos");
	ADD_FUNC(RemoveMesh, "RemoveMesh");

	//rendering & data transfer
	ADD_FUNC(RenderParticles, "RenderParticles");
	ADD_FUNC(RemoveAll, "RemoveAll");
	ADD_FUNC(RemoveAllCloth, "RemoveAllCloth");
	ADD_FUNC(ParticlesNear, "ParticlesNear");
	ADD_FUNC(GetData, "GetData");
	ADD_FUNC(GetSkewedData, "GetSkewedData");
	ADD_FUNC(GetClothData, "GetClothData");
	ADD_FUNC(SetRenderDistance, "SetRenderDistance");
	ADD_FUNC(GetRenderDistance, "GetRenderDistance");

	//forces
	ADD_FUNC(SpawnForceField, "SpawnForceField");
	ADD_FUNC(RemoveForceField, "RemoveForceField");
	ADD_FUNC(SetForceFieldPos, "SetForceFieldPos");
	ADD_FUNC(EditForceField, "EditForceField");
	ADD_FUNC(ApplyForce, "ApplyForce");
	ADD_FUNC(ApplyForceRange, "ApplyForceRange");
	ADD_FUNC(ApplyForceOutwards, "ApplyForceOutwards");
	ADD_FUNC(ApplyForceOutwardsRange, "ApplyForceOutwardsRange");

	//param funcs
	ADD_FUNC(SetRadius, "SetRadius");
	ADD_FUNC(GetRadius, "GetRadius");
	
	ADD_FUNC(SetConfig, "SetConfig");
	ADD_FUNC(GetConfig, "GetConfig");

	//extras
	ADD_FUNC(Blackhole, "Blackhole");
	ADD_FUNC(GetModuleVersion, "GetModuleVersion");
	ADD_FUNC(SetTimescale, "SetTimescale");
	ADD_FUNC(GetTimescale, "GetTimescale");

	LUA->SetField(-2, "gwater");
	LUA->Pop(); //remove _G
}


//called when module is opened
GMOD_MODULE_OPEN() {
	GlobalLUA = LUA;

	PopulateFunctions(LUA);

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