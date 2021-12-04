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

void flexAPI::flexSolveThread() {

	//declarations
	float simFramerate = 1.f / 60.f;	
	int simFramerateMi = (int)(simFramerate * 1000.f);

	//runs always while sim is active
	while (simValid) {

		if (!numParticles && !particleQueue.size()) {
			sleep(simFramerateMi);
			continue;
		}

		bufferMutex->lock();

		//grab current time vs time it takes to iterate through everything (if cpu is maxed)
		std::chrono::steady_clock::time_point curtimeStart = std::chrono::high_resolution_clock::now();

		if (!simValid) {	//because we are in a buffer lock, the simulation might have already been shut down (even with the while loop check!)
			bufferMutex->unlock();
			break;
		}

		// map buffers
		mapBuffers();

		//loop through queue and add requested particles	(AndrewEathan was here)
		if (particleQueue.size()) {
			for (Particle& particle : particleQueue) {
				if (numParticles >= flexSolverDesc.maxParticles) break;

				//apply data from queue
				simBuffers->particles[numParticles] = particle.pos;
				simBuffers->velocities[numParticles] = particle.vel;
				simBuffers->phases[numParticles] = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid);
				simBuffers->activeIndices[numParticles] = numParticles;
				numParticles++;
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

		//copy to particlehost to be used in rendering
		memcpy(particleBufferHost, simBuffers->particles, sizeof(float4) * numParticles);

		//unmap buffers
		unmapBuffers();

		// write to device (async)	
		NvFlexSetParticles(flexSolver, particleBuffer, NULL);
		NvFlexSetVelocities(flexSolver, velocityBuffer, NULL);
		NvFlexSetPhases(flexSolver, phaseBuffer, NULL);
		NvFlexSetActive(flexSolver, activeBuffer, NULL);
		NvFlexSetActiveCount(flexSolver, numParticles);
		NvFlexSetShapes(flexSolver, geometryBuffer, geoPosBuffer, geoQuatBuffer, geoPrevPosBuffer, geoPrevQuatBuffer, geoFlagsBuffer, propCount);
		NvFlexSetParams(flexSolver, flexParams);
		NvFlexExtSetForceFields(forceFieldData->forceFieldCallback, forceFieldData->forceFieldBuffer, forceFieldData->forceFieldCount);

		//grab end time
		std::chrono::steady_clock::time_point curtimeEnd = std::chrono::high_resolution_clock::now();
		std::chrono::milliseconds diff = std::chrono::duration_cast<std::chrono::milliseconds>(curtimeEnd - curtimeStart);

		// tick the solver 
		NvFlexUpdateSolver(flexSolver, simFramerate * 8 + (float)(diff.count() / 1000.f), 2, false);
		//NvFlexUpdateSolver(flexSolver, simFramerate * 8, 3, false);

		// read back (async)
		NvFlexGetParticles(flexSolver, particleBuffer, NULL);
		NvFlexGetVelocities(flexSolver, velocityBuffer, NULL);
		NvFlexGetPhases(flexSolver, phaseBuffer, NULL);
		NvFlexGetActive(flexSolver, activeBuffer, NULL);

		bufferMutex->unlock();	//dont forget to unlock our buffer

		sleep(simFramerateMi);

	}

}