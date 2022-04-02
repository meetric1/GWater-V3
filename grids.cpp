#include "types.h"
#include "declarations.h"
#include <string.h>


float length(float3 v) {
    return sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z));
}

float3 normalize(float3 v) {
    return v / length(v);
}


//https://github.com/NVIDIAGameWorks/FleX/blob/b1ea0f87b72582649c935d53fd8531b1e7335160/demo/helpers.h
void FLEX_API::CreateSpring(int i, int j, float stiffness, float give) {
    if (springCount >= flexSolverDesc.maxParticles) return;
    simBuffers->indices[springCount * 2] = i;
    simBuffers->indices[springCount * 2 + 1] = j;
    simBuffers->lengths[springCount] = (1.0f + give) * length(float3(simBuffers->particles[i]) - float3(simBuffers->particles[j]));
    simBuffers->coefficients[springCount] = stiffness;
    springCount++;
}

inline int GridIndex(int x, int y, int dx) { return y * dx + x; }

// FOR CLOTH
void FLEX_API::CreateSpringGrid(float3 lower, int dx, int dy, float radius, int phase, float stiffness, float mass) {
    int baseIndex = ParticleCount;
    int particleCoeff[2];
    particleCoeff[0] = ParticleCount;
    particleCoeff[1] = springCount;

    for (int y = 0; y < dy; ++y)
    {
        for (int x = 0; x < dx; ++x)
        {
            if (ParticleCount >= flexSolverDesc.maxParticles) break;

            float3 positionfloat3 = lower + float3(radius) * float3(float(x) + 0.5f, float(y) + 0.5f, 0);
            float4 positionfloat4 = float4(positionfloat3.x, positionfloat3.y, positionfloat3.z, 1 / mass);

            simBuffers->particles[ParticleCount] = positionfloat4;
            simBuffers->velocities[ParticleCount] = float3(0.f);
            simBuffers->phases[ParticleCount] = phase;
            simBuffers->activeIndices[ParticleCount] = ParticleCount;
            particleColors.push_back(Vector{});
            ParticleCount++;
        }
    }

    // horizontal
    for (int y = 0; y < dy; ++y)
    {
        for (int x = 0; x < dx; ++x)
        {
            int index0 = y * dx + x;
            /*
            if (x > 0)
            {
                int index1 = y * dx + x - 1;
                CreateSpring(baseIndex + index0, baseIndex + index1, stretchStiffness);     // stiffness? maybe later..
            }

            if (x > 1)
            {
                int index2 = y * dx + x - 2;
                CreateSpring(baseIndex + index0, baseIndex + index2, bendStiffness);
            }*/

            if (y > 0)
            {
                int indexDiag = (y - 1) * dx + x;
                CreateSpring(baseIndex + index0, baseIndex + indexDiag, stiffness);
            }

            if (x > 0)
            {
                int indexDiag = y * dx + x - 1;
                CreateSpring(baseIndex + index0, baseIndex + indexDiag, stiffness);
            }
        }
    }

    // push triangles to a vector
    std::vector<int> tris;
    for (int y = 1; y < dy; ++y)
    {
        for (int x = 1; x < dx; ++x)
        {
            if (baseIndex + (y * dx + x) >= flexSolverDesc.maxParticles) break;

            tris.push_back(baseIndex + (y * dx + x));
            tris.push_back(baseIndex + (y * dx + x - 1));
            tris.push_back(baseIndex + ((y - 1) * dx + x));
            tris.push_back(baseIndex + ((y - 1) * dx + x - 1));
        }
    }

    triangles.push_back(tris);
}


// FOR SOFTBODIES (kinda garbage ingame)
void FLEX_API::CreateParticleGrid(float3 lower, int dimx, int dimy, int dimz, float radius, float3 velocity, float mass, int phase, bool constraints) {
    int baseIndex = ParticleCount;

    for (int z = 0; z < dimz; ++z)
    {
        for (int y = 0; y < dimy; ++y)
        {
            for (int x = 0; x < dimx; ++x)
            {
                if (ParticleCount >= flexSolverDesc.maxParticles) break;

                const float3 positionfloat3 = lower + float3(radius) * float3(float(x) + 0.5f, float(y) + 0.5f, float(z) + 0.5f);
                const float4 positionfloat4 = float4(positionfloat3.x, positionfloat3.y, positionfloat3.z, 1.f / mass);

                simBuffers->particles[ParticleCount] = positionfloat4;
                simBuffers->velocities[ParticleCount] = velocity;
                simBuffers->phases[ParticleCount] = phase;
                simBuffers->activeIndices[ParticleCount] = ParticleCount;
                particleColors.push_back(Vector());
                ParticleCount++;
            }
        }
    }

    std::vector<int> tris;
    const int width = 1;       //prolly more springy and rigid if this value is higher
    //(z * dimy * dimx + y * dimx + x)
    for (int z = 0; z < dimz; ++z)
    {
        for (int y = 0; y < dimy; ++y)
        {
            for (int x = 0; x < dimx; ++x)
            {
                const int index0 = baseIndex + (z * dimy * dimx + y * dimx + x);
                if (index0 >= flexSolverDesc.maxParticles) break;

                if (constraints) {
                    // create springs to all the neighbors within the width
                    for (int i = x - width; i <= x + width; ++i)
                    {
                        for (int j = y - width; j <= y + width; ++j)
                        {
                            for (int k = z - width; k <= z + width; ++k)
                            {
                                if (i < 0 || i >= dimx) continue;
                                if (j < 0 || j >= dimy) continue;
                                if (k < 0 || k >= dimz) continue;
                                const int neighborIndex = baseIndex + (k * dimy * dimx + j * dimx + i);
                                CreateSpring(index0, neighborIndex, 1.f);
                            }
                        }
                    }
                }

                // ok its time to push triangles to our mesh vector thingy
                
                if (z == 0 && y > 0 && x > 0) {   //the bottom & top
                    tris.push_back(baseIndex + ((y - 1) * dimx + x));
                    tris.push_back(baseIndex + ((y - 1) * dimx + x - 1));
                    tris.push_back(baseIndex + (y * dimx + x));
                    tris.push_back(baseIndex + (y * dimx + x - 1));

                    tris.push_back(ParticleCount - 1 - (y * dimx + x));
                    tris.push_back(ParticleCount - 1 - (y * dimx + x - 1));
                    tris.push_back(ParticleCount - 1 - ((y - 1) * dimx + x));
                    tris.push_back(ParticleCount - 1 - ((y - 1) * dimx + x - 1));
                }
                
                if (x == 0 && z > 0 && y > 0) {   //the right & left
                    tris.push_back(baseIndex + ((z - 1) * dimy * dimx + y * dimx));
                    tris.push_back(baseIndex + ((z - 1) * dimy * dimx + (y - 1) * dimx));
                    tris.push_back(baseIndex + (z * dimy * dimx + y * dimx));
                    tris.push_back(baseIndex + (z * dimy * dimx + (y - 1) * dimx));
                    
                    tris.push_back(ParticleCount - 1 - (z * dimy * dimx + y * dimx));
                    tris.push_back(ParticleCount - 1 - (z * dimy * dimx + (y - 1) * dimx));
                    tris.push_back(ParticleCount - 1 - ((z - 1) * dimy * dimx + y * dimx));
                    tris.push_back(ParticleCount - 1 - ((z - 1) * dimy * dimx + (y - 1) * dimx));
                }
                
                if (y == 0 && x > 0 && z > 0) {   //the back & front
                    tris.push_back(baseIndex + (z * dimy * dimx + x));
                    tris.push_back(baseIndex + (z * dimy * dimx + (x - 1)));
                    tris.push_back(baseIndex + ((z - 1) * dimy * dimx + x));
                    tris.push_back(baseIndex + ((z - 1) * dimy * dimx + (x - 1)));

                    tris.push_back(ParticleCount - 1 - ((z - 1) * dimy * dimx + x));
                    tris.push_back(ParticleCount - 1 - ((z - 1) * dimy * dimx + (x - 1)));
                    tris.push_back(ParticleCount - 1 - (z * dimy * dimx + x));
                    tris.push_back(ParticleCount - 1 - (z * dimy * dimx + (x - 1)));
                }

            }
        }

    } 

    triangles.push_back(tris);
}