//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#ifndef __PARTICLE_DATA
#define __PARTICLE_DATA

#define SAFE_FREE(x) if (x) { free(x); x = NULL; }

typedef struct _float3
{
	float x;
	float y;
	float z;
} float3;

typedef struct _Particle
{
	float3	Position;
	float	Density;
} Particle;

typedef struct _ParticleFrame
{
	long		NumParticles;
	float		Mass;
	float		RestDensity;
	Particle	*pParticles;
} ParticleFrame;

void PrintParticleFrame(ParticleFrame *pParticleFrame);

#endif
