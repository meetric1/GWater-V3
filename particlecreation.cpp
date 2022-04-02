#include "types.h"
#include "declarations.h"

//add a particle to flex
void FLEX_API::addParticle(Vector pos, Vector vel, Vector color) {
    Particle particle = Particle{ float4(pos, 0.5f), float3(vel) };
    particleQueue.push_back(particle);
    particleColors.push_back(color);
}

int clothPhase = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide);
int rigidPhase = NvFlexMakePhase(1, 0);
void FLEX_API::addCloth(float3 pos, int width, float radius, float stiffness, float mass) {
    mapBuffers();
    CreateSpringGrid(float3(pos) - float3(width, width, 0) * radius / 2, width, width, radius, clothPhase, stiffness, mass);
    unmapBuffers();
}

void FLEX_API::addRigidbody(float3 lower, int dimx, int dimy, int dimz, float radius, float3 velocity, float mass, bool constraints) {
    mapBuffers();
    CreateParticleGrid(lower - float3(dimx, dimy, dimz) * radius / 2, dimx, dimy, dimz, radius, velocity, mass, clothPhase, constraints);
    unmapBuffers();
}

