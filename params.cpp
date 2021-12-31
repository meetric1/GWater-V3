#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>

#include "declarations.h"
#include <float.h>


void FLEX_API::initParams() {
	flexParams->gravity[0] = 0.0f;
	flexParams->gravity[1] = 0.0f;
	flexParams->gravity[2] = -9.8f;

	flexParams->wind[0] = 0.0f;
	flexParams->wind[1] = 0.0f;
	flexParams->wind[2] = 0.0f;

	flexParams->radius = 0.f;
	flexParams->viscosity = 0.0f;
	flexParams->dynamicFriction = 0.5f;	//5/r
	flexParams->staticFriction = 0.5f;
	flexParams->particleFriction = 0.01f; // scale friction between particles by default
	flexParams->freeSurfaceDrag = 0.0f;
	flexParams->drag = 0.0f;
	flexParams->lift = 1.0f;
	flexParams->numIterations = 3;
	flexParams->fluidRestDistance = 0.f;
	flexParams->solidRestDistance = 0.f;

	flexParams->anisotropyScale = 0.0f;
	flexParams->anisotropyMin = 0.0f;
	flexParams->anisotropyMax = 0.0f;
	flexParams->smoothing = 0.0f;

	flexParams->dissipation = 0.01f;
	flexParams->damping = 0.0f;
	flexParams->particleCollisionMargin = 0.f;
	flexParams->shapeCollisionMargin = 0.f;
	flexParams->collisionDistance = 0.f; // Needed for tri-particle intersection
	flexParams->sleepThreshold = 1.f;
	flexParams->shockPropagation = 0.0f;
	flexParams->restitution = 1.0f;

	flexParams->maxSpeed = FLT_MAX;
	flexParams->maxAcceleration = 128.0f;	// approximately 10x gravity
	flexParams->relaxationMode = eNvFlexRelaxationLocal;
	flexParams->relaxationFactor = 0.0f;
	flexParams->solidPressure = 0.0f;
	flexParams->adhesion = 0.0f;
	flexParams->cohesion = 0.01f;
	flexParams->surfaceTension = 0.0f;
	flexParams->vorticityConfinement = 0.0f;
	flexParams->buoyancy = 1.0f;
	flexParams->diffuseThreshold = 0.0f;
	flexParams->diffuseBuoyancy = 0.0f;
	flexParams->diffuseDrag = 0.0f;
	flexParams->diffuseBallistic = 0;
	flexParams->diffuseLifetime = 0.0f;

	// planes created after particles
	flexParams->planes[0][0] = 0.f;
	flexParams->planes[0][1] = 0.f;
	flexParams->planes[0][2] = 1.f;
	flexParams->planes[0][3] = 32768.f;

	flexParams->numPlanes = 1;

	flexMap["viscosity"] = &(flexParams->viscosity);
	flexMap["drag"] = &(flexParams->drag);
	flexMap["dissipation"] = &(flexParams->dissipation);
	flexMap["damping"] = &(flexParams->damping);
	flexMap["sleepThreshold"] = &(flexParams->sleepThreshold);
	flexMap["maxSpeed"] = &(flexParams->maxSpeed);
	flexMap["maxAcceleration"] = &(flexParams->maxAcceleration);
	flexMap["adhesion"] = &(flexParams->adhesion);
	flexMap["cohesion"] = &(flexParams->cohesion);
	flexMap["surfaceTension"] = &(flexParams->surfaceTension);
	flexMap["solidPressure"] = &(flexParams->solidPressure);
	flexMap["vorticityConfinement"] = &(flexParams->vorticityConfinement);
	flexMap["gravityX"] = &(flexParams->gravity[0]);
	flexMap["gravityY"] = &(flexParams->gravity[1]);
	flexMap["gravityZ"] = &(flexParams->gravity[2]);
	flexMap["windX"] = &(flexParams->wind[0]);
	flexMap["windY"] = &(flexParams->wind[1]);
	flexMap["windZ"] = &(flexParams->wind[2]);
	flexMap["dynamicFriction"] = &(flexParams->dynamicFriction);	//5/r
	flexMap["staticFriction"] = &(flexParams->staticFriction);
	flexMap["particleFriction"] = &(flexParams->particleFriction); // scale friction between particles by default

	gwaterMap["simulationFramerate"] = 60;

	//its an int
	//flexMap["NUM_ITERATIONS"] = &(flexParams->numIterations);
}

void FLEX_API::initParamsRadius(float r) {
	radius = r;
	flexParams->radius = r;
	flexParams->fluidRestDistance = r * 0.75f;
	flexParams->solidRestDistance = r * 0.5f;
	flexParams->particleCollisionMargin = r * 0.5f;
	flexParams->shapeCollisionMargin = r * 0.25f;
	flexParams->collisionDistance = r * 0.5f; // Needed for tri-particle intersection
}


void FLEX_API::updateParam(std::string str, float n) {
	try {
		*flexMap.at(str) = n;
	}
	catch (std::exception e) {
		GlobalLUA->ThrowError(("Invalid parameter \"" + str + "\"!").c_str());
	}
}

void FLEX_API::updateExtraParam(std::string str, float n) {
	try {
		gwaterMap.at(str) = n;
	}
	catch (std::exception e) {
		GlobalLUA->ThrowError(("Invalid extra parameter \"" + str + "\"!").c_str());
	}
}

