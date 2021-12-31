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
	//declarations
	float simFPS = 1.f / gwaterMap["simulationFramerate"];
	int simFPS_ms = (int)(simFPS * 1000.f);

	//runs always while sim is active
	while (SimValid) {
		//no work to do yet
		if (!ParticleCount && !particleQueue.size() || !simTimescale) {
			sleep(simFPS_ms);
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
				if (ParticleCount >= flexSolverDesc.maxParticles) break;

				//apply data from queue
				simBuffers->particles[ParticleCount] = particle.pos;
				simBuffers->velocities[ParticleCount] = particle.vel;
				simBuffers->phases[ParticleCount] = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid);
				simBuffers->activeIndices[ParticleCount] = ParticleCount;
				ParticleCount++;
			}
			particleQueue.clear();
		}
		
		//update prop positions (start at 1 because world never moves)
		for (int i = 1; i < props.size(); i++) {
			Prop* prop = &props[i];
			simBuffers->positions[i] = prop->lastPos;
			simBuffers->rotations[i] = prop->lastAng;
			simBuffers->prevPositions[i] = prop->pos;
			simBuffers->prevRotations[i] = prop->ang;

			prop->pos = prop->lastPos;
			prop->ang = prop->lastAng;
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
		NvFlexSetActiveCount(flexSolver, ParticleCount);
		NvFlexSetShapes(flexSolver, geometryBuffer,	geoPosBuffer, geoQuatBuffer, geoPrevPosBuffer, geoPrevQuatBuffer, geoFlagsBuffer, PropCount);
		NvFlexSetParams(flexSolver, flexParams);
		NvFlexExtSetForceFields(forceFieldData->forceFieldCallback, forceFieldData->forceFieldBuffer, forceFieldData->forceFieldCount);

		//grab end time
		steady_clock::time_point timeEnd = curtime();
		milliseconds diff = duration_cast<milliseconds>(timeEnd - timeStart);

		//tick the solver 
		NvFlexUpdateSolver(flexSolver, simFPS * 8 * simTimescale + (float)(diff.count()) / 1000.f, 3, false);

		//read back (async)
		NvFlexGetParticles(flexSolver, particleBuffer, NULL);
		NvFlexGetVelocities(flexSolver, velocityBuffer, NULL);
		NvFlexGetPhases(flexSolver, phaseBuffer, NULL);
		NvFlexGetActive(flexSolver, activeBuffer, NULL);

		//dont forget to unlock our buffer
		bufferMutex->unlock();

		//sleep until next frame
		sleep(simFPS_ms);
	}
}