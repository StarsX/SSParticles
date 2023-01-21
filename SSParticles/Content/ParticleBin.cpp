//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include "ParticleData.h"
#include "ParticleBin.h"

void readParticleHeaderBase(ParticleHeaderBase *pHeaderBase, FILE *pFile, char bPrint);
void readParticleHeader(ParticleHeader *pHeader, FILE *pFile, char bPrint);
void readParticleBase(ParticleBase *pBase, FILE *pFile, char bPrint);
void readParticleInfo(ParticleInfo *pInfo, FILE *pFile, char bPrint);
void readParticle(RFParticle *pParticle, FILE *pFile, short version, char bPrint);
void readParticleBin(ParticleBin *pParticleBin, FILE *pFile, char bPrint);

void printParticleHeaderBase(ParticleHeaderBase *pHeaderBase);
void printParticleHeader(ParticleHeader *pHeader);
void printParticleBase(ParticleBase *pBase);
void printParticleOptional(RFParticle *pParticle, short version);
void printParticleInfo(ParticleInfo *pInfo);
void printParticleID(RFParticle *pParticle, short version);

void LoadParticleBinAnimation(ParticleFrame *ParticleFrames, char *pFPS, const char *fileNamePrefix, int numFrames, char bPrint)
{
	int i;
	char fileName[256];
	for (i = 0; i < numFrames; i++) {
		sprintf(fileName, "%s_%05d.bin", fileNamePrefix, i);
		LoadParticleBin(&ParticleFrames[i], pFPS, fileName, bPrint);
	}
}

void LoadParticleBin(ParticleFrame *pParticleFrame, char *pFPS, const char *fileName, char bPrint)
{
	long i;
	ParticleBin particleBin;
	FILE *pFile = fopen(fileName, "rb");
	if (bPrint) printf("%s\n\n", fileName);
	if (pFile) {
		readParticleBin(&particleBin, pFile, bPrint);
		*pFPS = particleBin.Header.HeaderBase.FPS;
		fclose(pFile);

		pParticleFrame->NumParticles = particleBin.Header.HeaderBase.NumParticles;
		pParticleFrame->pParticles = (Particle *)calloc(pParticleFrame->NumParticles, sizeof(Particle));
		if (pParticleFrame->NumParticles > 0) {
			pParticleFrame->Mass = particleBin.Particles->Info.Mass;
			pParticleFrame->RestDensity = 1000.0f;
		}
		for (i = 0; i < pParticleFrame->NumParticles; i++) {
			pParticleFrame->pParticles[i].Position = particleBin.Particles[i].Base.Position;
			pParticleFrame->pParticles[i].Density = particleBin.Particles[i].Info.Density;
			pParticleFrame->pParticles[i].Position.x = -pParticleFrame->pParticles[i].Position.x;
		}
		free(particleBin.Particles);
	}
}

void readParticleHeaderBase(ParticleHeaderBase *pHeaderBase, FILE *pFile, char bPrint)
{
	fread(pHeaderBase, sizeof(ParticleHeaderBase), 1,  pFile);
	if (bPrint) printParticleHeaderBase(pHeaderBase);
}

void readParticleHeader(ParticleHeader *pHeader, FILE *pFile, char bPrint)
{
	readParticleHeaderBase(&pHeader->HeaderBase, pFile, bPrint);
	if (pHeader->HeaderBase.Version >= 7) {
		fread(&pHeader->EmitPos, sizeof(float3), 3, pFile);
		if (bPrint) printParticleHeader(pHeader);
	}
}

void readParticleBase(ParticleBase *pBase, FILE *pFile, char bPrint)
{
	fread(pBase, sizeof(ParticleBase), 1,  pFile);
	if (bPrint) printParticleBase(pBase);
}

void readParticleInfo(ParticleInfo *pInfo, FILE *pFile, char bPrint)
{
	fread(pInfo, sizeof(ParticleInfo), 1,  pFile);
	if (bPrint) printParticleInfo(pInfo);
}

void readParticle(RFParticle *pParticle, FILE *pFile, short version, char bPrint)
{
	readParticleBase(&pParticle->Base, pFile, bPrint);
	if (version >= 9) fread(&pParticle->Vorticity, sizeof(float3), 1, pFile);
	if (version >= 3) fread(&pParticle->Normal, sizeof(float3), 1, pFile);
	if (version >= 4) fread(&pParticle->NumNeighbors, sizeof(int), 1, pFile);
	if (version >= 5) {
		fread(&pParticle->TexCoord, sizeof(float3), 1, pFile);
		fread(&pParticle->InfoBits, sizeof(short), 1, pFile);
	}
	if (bPrint) printParticleOptional(pParticle, version);
	readParticleInfo(&pParticle->Info, pFile, bPrint);
	if (version < 12) fread(&pParticle->PidOld, sizeof(int), 1, pFile);
	else fread(&pParticle->ParticleID, sizeof(uint64_t), 1, pFile);
	if (bPrint) printParticleID(pParticle, version);
}

void readParticleBin(ParticleBin *pParticleBin, FILE *pFile, char bPrint)
{
	short v;
	long i, n;
	readParticleHeader(&pParticleBin->Header, pFile, bPrint);
	v = pParticleBin->Header.HeaderBase.Version;
	n = pParticleBin->Header.HeaderBase.NumParticles;
	pParticleBin->Particles = (RFParticle *)calloc(n, sizeof(RFParticle));
	for (i = 0; i < n; i++) {
		if (bPrint) printf("\tParticle %u {\n", i);
		readParticle(&pParticleBin->Particles[i], pFile, v, bPrint);
		if (bPrint) printf("\t}\n");
	}
}

void printParticleHeaderBase(ParticleHeaderBase *pHeaderBase)
{
	printf("Verification Code:\t0x%lX\n"
		"Fluid Name:\t\t%s\n"
		"Version:\t\t%hd\n"
		"Scene Scale:\t\t%.3f\n"
		"Fluid Type:\t\t%d\n"
		"Elapsed Time:\t\t%.3f\n"
		"Frame Number:\t\t%d\n"
		"FPS:\t\t\t%d\n"
		"Number of Particles:\t%ld\n"
		"Radius:\t\t\t%.3f\n"
		"Pressure:\t\t(%.3f, %.3f, %.3f)\n"
		"Speed:\t\t\t(%.3f, %.3f, %.3f)\n"
		"Temperature:\t\t(%.3f, %.3f, %.3f)\n",
		pHeaderBase->VeriCode,
		pHeaderBase->FluidName,
		pHeaderBase->Version,
		pHeaderBase->ScaleScene,
		pHeaderBase->FluidType,
		pHeaderBase->ElapseTime,
		pHeaderBase->FrameNum,
		pHeaderBase->FPS,
		pHeaderBase->NumParticles,
		pHeaderBase->Radius,
		pHeaderBase->Pressure.x,
		pHeaderBase->Pressure.y,
		pHeaderBase->Pressure.z,
		pHeaderBase->Speed.x,
		pHeaderBase->Speed.y,
		pHeaderBase->Speed.z,
		pHeaderBase->Temperature.x,
		pHeaderBase->Temperature.y,
		pHeaderBase->Temperature.z
	);
}

void printParticleHeader(ParticleHeader *pHeader)
{
	printf("Emitter Position:\t(%.3f, %.3f, %.3f)\n"
		"Emitter Rotation:\t(%.3f, %.3f, %.3f)\n"
		"Emitter Scaling:\t(%.3f, %.3f, %.3f)\n\n",
		pHeader->EmitPos.x,
		pHeader->EmitPos.y,
		pHeader->EmitPos.z,
		pHeader->EmitRot.x,
		pHeader->EmitRot.y,
		pHeader->EmitRot.z,
		pHeader->EmitScl.x,
		pHeader->EmitScl.y,
		pHeader->EmitScl.z
	);
}

void printParticleBase(ParticleBase *pBase)
{
	printf("\t\tPosition:\t\t(%.3f, %.3f, %.3f)\n"
		"\t\tVelocity:\t\t(%.3f, %.3f, %.3f)\n"
		"\t\tForce:\t\t\t(%.3f, %.3f, %.3f)\n",
		pBase->Position.x,
		pBase->Position.y,
		pBase->Position.z,
		pBase->Velocity.x,
		pBase->Velocity.y,
		pBase->Velocity.z,
		pBase->Force.x,
		pBase->Force.y,
		pBase->Force.z
	);
}

void printParticleOptional(RFParticle *pParticle, short version)
{
	if (version >= 9)
		printf("\t\tVorticity:\t\t(%.3f, %.3f, %.3f)\n",
			pParticle->Vorticity.x,
			pParticle->Vorticity.y,
			pParticle->Vorticity.z
		);
	if (version >= 3)
		printf("\t\tNormal:\t\t\t(%.3f, %.3f, %.3f)\n",
			pParticle->Normal.x,
			pParticle->Normal.y,
			pParticle->Normal.z
		);
	if (version >= 4) printf("\t\tNumber of Neighbors:\t%d\n", pParticle->NumNeighbors);
	if (version >= 5) {
		printf("\t\tTexture Coordinates:\t(%.3f, %.3f, %.3f)\n",
			pParticle->TexCoord.x,
			pParticle->TexCoord.y,
			pParticle->TexCoord.z
		);
		printf("\t\tInfo Bits:\t\t%hd\n", pParticle->InfoBits);
	}
}

void printParticleInfo(ParticleInfo *pInfo)
{
	printf("\t\tAge:\t\t\t%.3f\n"
		"\t\tIsolation Time:\t\t%.3f\n"
		"\t\tViscosity:\t\t%.3f\n"
		"\t\tDensity:\t\t%.3f\n"
		"\t\tPressure:\t\t%.3f\n"
		"\t\tMass:\t\t\t%.3f\n"
		"\t\tTemperature:\t\t%.3f\n",
		pInfo->Age,
		pInfo->IsoTime,
		pInfo->Viscosity,
		pInfo->Density,
		pInfo->Pressure,
		pInfo->Mass,
		pInfo->Temperature
	);
}

void printParticleID(RFParticle *pParticle, short version)
{
	if (version < 12) printf("\t\tParticle ID:\t\t%d\n", pParticle->PidOld);
	else printf("\t\tParticle ID:\t\t%llu\n", pParticle->ParticleID);
}
