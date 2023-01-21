//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#ifndef __PARTICLE_BIN
#define __PARTICLE_BIN

typedef struct _ParticleHeaderBase
{
	long	VeriCode;
	char	FluidName[250];
	short	Version;
	float	ScaleScene;
	int		FluidType;
	float	ElapseTime;
	int		FrameNum;
	int		FPS;
	long	NumParticles;
	float	Radius;
	float3	Pressure;
	float3	Speed;
	float3	Temperature;
} ParticleHeaderBase;

typedef struct _ParticleHeader
{
	ParticleHeaderBase	HeaderBase;
	float3				EmitPos;
	float3				EmitRot;
	float3				EmitScl;
} ParticleHeader;

typedef struct _ParticleBase
{
	float3	Position;
	float3	Velocity;
	float3	Force;
} ParticleBase;

typedef struct _ParticleInfo
{
	float	Age;
	float	IsoTime;
	float	Viscosity;
	float	Density;
	float	Pressure;
	float	Mass;
	float	Temperature;
} ParticleInfo;

typedef struct _RFParticle
{
	ParticleBase	Base;
	float3			Vorticity;
	float3			Normal;
	int				NumNeighbors;
	float3			TexCoord;
	short			InfoBits;
	ParticleInfo	Info;
	int				PidOld;
	uint64_t		ParticleID;
} RFParticle;

typedef struct _ParticleBin
{
	ParticleHeader	Header;
	RFParticle		*Particles;
} ParticleBin;

void LoadParticleBinAnimation(ParticleFrame *ParticleFrames, char *pFPS, const char *fileNamePrefix, int numFrames, char bPrint);
void LoadParticleBin(ParticleFrame *pParticleFrame, char *pFPS, const char *fileName, char bPrint);

#endif
