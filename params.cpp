#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>

#include "declarations.h"
#include <float.h>


void flexAPI::initParams() {
	flexParams->gravity[0] = 0.0f;
	flexParams->gravity[1] = 0.0f;
	flexParams->gravity[2] = -9.8f;

	flexParams->wind[0] = 0.0f;
	flexParams->wind[1] = 0.0f;
	flexParams->wind[2] = 0.0f;

	flexParams->radius = 10.f;
	flexParams->viscosity = 0.0f;
	flexParams->dynamicFriction = 0.5f;	//5/r
	flexParams->staticFriction = 0.5f;
	flexParams->particleFriction = 0.01f; // scale friction between particles by default
	flexParams->freeSurfaceDrag = 0.0f;
	flexParams->drag = 0.0f;
	flexParams->lift = 1.0f;
	flexParams->numIterations = 2;
	flexParams->fluidRestDistance = 7.5f;
	flexParams->solidRestDistance = 5.f;

	flexParams->anisotropyScale = 0.0f;
	flexParams->anisotropyMin = 0.0f;
	flexParams->anisotropyMax = 0.0f;
	flexParams->smoothing = 0.0f;

	flexParams->dissipation = 0.01f;
	flexParams->damping = 0.0f;
	flexParams->particleCollisionMargin = 5.f;
	flexParams->shapeCollisionMargin = 2.5f;
	flexParams->collisionDistance = 5.0f; // Needed for tri-particle intersection
	flexParams->sleepThreshold = 0.1f;
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
	flexParams->planes[0][3] = 13288.f;

	flexParams->numPlanes = 1;

	flexMap["VISCOSITY"] = &(flexParams->viscosity);
	flexMap["DRAG"] = &(flexParams->drag);
	flexMap["DISSIPATION"] = &(flexParams->dissipation);
	flexMap["DAMPING"] = &(flexParams->damping);
	flexMap["SLEEP_THRESHOLD"] = &(flexParams->sleepThreshold);
	flexMap["MAX_SPEED"] = &(flexParams->maxSpeed);
	flexMap["MAX_ACCELERATION"] = &(flexParams->maxAcceleration);
	flexMap["ADHESION"] = &(flexParams->adhesion);
	flexMap["COHESION"] = &(flexParams->cohesion);
	flexMap["SURFACE_TENSION"] = &(flexParams->surfaceTension);
	flexMap["VORTICITY_CONFINEMENT"] = &(flexParams->vorticityConfinement);
	flexMap["GRAVITY_X"] = &(flexParams->gravity[0]);
	flexMap["GRAVITY_Y"] = &(flexParams->gravity[1]);
	flexMap["GRAVITY_Z"] = &(flexParams->gravity[2]);
	flexMap["WIND_X"] = &(flexParams->wind[0]);
	flexMap["WIND_Y"] = &(flexParams->wind[1]);
	flexMap["WIND_Z"] = &(flexParams->wind[2]);
	flexMap["DYNAMIC_FRICTION"] = &(flexParams->dynamicFriction);	//5/r
	flexMap["STATIC_FRICTION"] = &(flexParams->staticFriction);
	flexMap["PARTICLE_FRICTION"] = &(flexParams->particleFriction); // scale friction between particles by default

	//its an int
	//flexMap["NUM_ITERATIONS"] = &(flexParams->numIterations);
}

void flexAPI::initParamsRadius(float r) {
	flexParams->radius = r;
	flexParams->fluidRestDistance = r * 0.75f;
	flexParams->solidRestDistance = r * 0.5f;
	flexParams->particleCollisionMargin = r * 0.5f;
	flexParams->shapeCollisionMargin = r * 0.25f;
	flexParams->collisionDistance = r * 0.5f; // Needed for tri-particle intersection

	radius = r;
}


void flexAPI::updateParam(std::string str, float n) {
	try {
		*flexMap.at(str) = n;
	}
	catch (std::exception e) {
		printLua("PARAM '" + str + "' IS INVALID!");
	}
}

