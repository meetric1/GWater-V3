#include <NvFlex.h>
#include <NvFlexExt.h>
#include <NvFlexDevice.h>

#include "declarations.h"
#include "types.h"
#include <string>
#include <random>

void sleep(int sec) {
	std::this_thread::sleep_for(std::chrono::milliseconds(sec));
}

using namespace std::chrono;

steady_clock::time_point curtime() {
	return std::chrono::high_resolution_clock::now();
}

void FLEX_API::flexSolveThread() {
	//runs always while sim is active

	NvFlexCopyDesc copyDesc;
	copyDesc.dstOffset = 0;
	copyDesc.srcOffset = 0;
	int waterPhase = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid);
	int particleLoop = 0;
	while (SimValid) {
		//no work to do yet
		float fps = 1.f / *flexMap["simFPS"];
		if (!ParticleCount && !particleQueue.size() || !simTimescale) {
			sleep(fps * 1000.f);
			continue;
		}

		bufferMutex->lock();

		//grab current time vs time it takes to iterate through everything
		steady_clock::time_point timeStart = curtime();

		//because we are in a buffer lock, the simulation might have already been shut down (even with the while loop check!)
		if (!SimValid) {
			bufferMutex->unlock();
			break;
		}

		mapBuffers();

		//loop through queue and add requested particles	(AndrewEathan was here)
		if (particleQueue.size()) {
			for (Particle& particle : particleQueue) {
				if (ParticleCount >= flexSolverDesc.maxParticles) {
					if (flexSolverDesc.maxParticles <= 0) break; 

					int offset = (ParticleCount + particleLoop) % flexSolverDesc.maxParticles;
					simBuffers->particles[offset] = particle.pos;
					simBuffers->velocities[offset] = particle.vel;
					simBuffers->phases[offset] = waterPhase;
					simBuffers->activeIndices[offset] = offset;
					particleLoop = (particleLoop + 1) % flexSolverDesc.maxParticles;
					continue;
				}

				//apply data from queue
				simBuffers->particles[ParticleCount] = particle.pos;
				simBuffers->velocities[ParticleCount] = particle.vel;
				simBuffers->phases[ParticleCount] = waterPhase;
				simBuffers->activeIndices[ParticleCount] = ParticleCount;
				ParticleCount++;
			}
			particleQueue.clear();
		}

		//update prop positions (start at 1 because world never moves)
		for (int i = 1; i < props.size(); i++) {
			Prop* prop = &props[i];
			simBuffers->positions[i] = prop->pos;
			simBuffers->rotations[i] = prop->ang;
			simBuffers->prevPositions[i] = prop->lastPos;
			simBuffers->prevRotations[i] = prop->lastAng;

			prop->lastPos = prop->pos;
			prop->lastAng = prop->ang;
		}

		//copy to particle host to be used in rendering
		memcpy(particleBufferHost, simBuffers->particles, sizeof(float4) * ParticleCount);

		//unmap buffers
		unmapBuffers();

		//write to device (async)
		NvFlexSetParticles(flexSolver, particleBuffer, NULL);
		NvFlexSetVelocities(flexSolver, velocityBuffer, NULL);
		NvFlexSetPhases(flexSolver, phaseBuffer, NULL);
		NvFlexSetActive(flexSolver, activeBuffer, NULL);
		NvFlexSetSprings(flexSolver, indicesBuffer, lengthsBuffer, coefficientsBuffer, springCount);
		NvFlexSetActiveCount(flexSolver, ParticleCount);
		NvFlexSetShapes(flexSolver, geometryBuffer, geoPosBuffer, geoQuatBuffer, geoPrevPosBuffer, geoPrevQuatBuffer, geoFlagsBuffer, PropCount);
		NvFlexSetParams(flexSolver, flexParams);
		NvFlexExtSetForceFields(forceFieldData->forceFieldCallback, forceFieldData->forceFieldBuffer, forceFieldData->forceFieldCount);

		//NvFlexSetDiffuseParticles(flexSolver, diffusePosBuffer, diffuseVelBuffer, diffuseCount);

		//grab end time
		milliseconds diff = duration_cast<milliseconds>(curtime() - timeStart);

		//tick the solver 
		NvFlexUpdateSolver(flexSolver, fps * 8 * simTimescale + (float)(diff.count()) / 1000.f, 3, false);

		copyDesc.elementCount = ParticleCount;
		NvFlexGetParticles(flexSolver, particleBuffer, &copyDesc);
		NvFlexGetVelocities(flexSolver, velocityBuffer, &copyDesc);
		NvFlexGetPhases(flexSolver, phaseBuffer, &copyDesc);
		NvFlexGetActive(flexSolver, activeBuffer, &copyDesc);
		NvFlexGetDiffuseParticles(flexSolver, diffusePosBuffer, NULL, diffuseSingleBuffer);

		// get diffuse particles data (we never set it)
		int* particleCount = (int*)NvFlexMap(diffuseSingleBuffer, eNvFlexMapWait);
		float4* particlePos = (float4*)NvFlexMap(diffusePosBuffer, eNvFlexMapWait);
		diffuseCount = particleCount[0];
		memcpy(diffuseBufferHost, particlePos, sizeof(float4) * diffuseCount);
		NvFlexUnmap(diffuseSingleBuffer);
		NvFlexUnmap(diffusePosBuffer);

		//dont forget to unlock our buffer
		bufferMutex->unlock();

		//sleep until next frame
		sleep(fps * 1000.f);
	}
}