//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include <stdio.h>
#include "ParticleData.h"

void PrintParticleFrame(ParticleFrame *pParticleFrame)
{
	long i;
	printf("Number of particles:\t%u\n", pParticleFrame->NumParticles);
	printf("Particle Mass:\t\t%.3f\n", pParticleFrame->Mass);
	printf("ID\tPosition (x, y, z)\t\tDensity\n");
	for (i = 0; i < pParticleFrame->NumParticles; i++) {
		printf("%u\t(", i);
		pParticleFrame->pParticles[i].Position.x >= 0.0f ?
			printf(" %.3f", pParticleFrame->pParticles[i].Position.x) :
			printf("%.3f", pParticleFrame->pParticles[i].Position.x);
		printf(", ");
		pParticleFrame->pParticles[i].Position.y >= 0.0f ?
			printf(" %.3f", pParticleFrame->pParticles[i].Position.y) :
			printf("%.3f", pParticleFrame->pParticles[i].Position.y);
		printf(", ");
		pParticleFrame->pParticles[i].Position.z >= 0.0f ?
			printf(" %.3f", pParticleFrame->pParticles[i].Position.z) :
			printf("%.3f", pParticleFrame->pParticles[i].Position.z);
		printf(")");
		printf("\t%.3f\n", pParticleFrame->pParticles[i].Density);
	}
}
