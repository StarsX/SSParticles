//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "BlurCommon.hlsli"

//#ifndef _CALC_COARSE_WEIGHT_DIRECTLY_
//#define _CALC_COARSE_WEIGHT_DIRECTLY_
//#endif

#ifndef _MULTI_FINER_
#define _MULTI_FINER_
#endif

//--------------------------------------------------------------------------------------
// Constant buffer
//--------------------------------------------------------------------------------------
cbuffer cbPerFrame	: register (b0)
{
	matrix	g_worldView;
	matrix	g_proj;
	matrix	g_viewI;
	matrix	g_projI;
};

cbuffer cbPerPass	: register (b1)
{
	uint g_level;
};

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
RWTexture2D<float> g_rwDst;

Texture2D<float> g_txDepthCoarser	: register (t0);
Texture2D<float> g_txDepth			: register (t1);
Texture2D<float> g_txDepth0			: register (t2);

//--------------------------------------------------------------------------------------
// Get domain location of bilinear filter
//--------------------------------------------------------------------------------------
float2 BilinearDomainLoc(Texture2D<float> tx, float2 uv)
{
	float2 texSize;
	tx.GetDimensions(texSize.x, texSize.y);

	return frac(uv * texSize - 0.5);
}

//--------------------------------------------------------------------------------------
// Calculate blending weight
//--------------------------------------------------------------------------------------
float MipGaussianBlendWeight(uint level, int radius)
{
	// Compute deviation
	const float sigma = GaussianSigmaFromRadius(radius);
	const float sigma_sq = sigma * sigma;

	// Gaussian-approximating Haar coefficients (weights of box filters)
	const float l = level + 0.6;
	const float c = 2.0 * PI * sigma_sq;
	const float numerator = pow(16.0, l) * log(4.0);
	const float denorminator = c * (pow(4.0, l) + c);
	//const float numerator = pow(2.0, level * 4.0) * log(4.0);
	//const float denorminator = c * (pow(2.0, level * 2.0) + c);
	//const float numerator = (1u << (level * 4)) * log(4.0);
	//const float denorminator = c * ((1u << (level * 2)) + c);
	//const float numerator = (1u << (level << 2)) * log(4.0);
	//const float denorminator = c * ((1u << (level << 1)) + c);

	return saturate(numerator / denorminator);
}

float MipGaussianBlendWeightCoarse(uint level, int radius)
{
	// Compute deviation
	const float sigma = GaussianSigmaFromRadius(radius);
	const float sigma_sq = sigma * sigma;

	// Gaussian-approximating Haar coefficients (weights of box filters)
	//const float r = pow(4.0, level);
	//const float r = pow(2.0, level * 2.0);
	//const float r = 1 << (level * 2);
	const float r = 1 << (level << 1);

	return exp(-3.0 / (2.0 * PI) * r / sigma_sq);
}

//--------------------------------------------------------------------------------------
// 3x3 finer samples
//--------------------------------------------------------------------------------------
void Fetch3x3(out float samples3x3[9], Texture2D<float> txSrc, uint2 pos)
{
	uint i = 0;
	[unroll]
	for (int y = -1; y <= 1; ++y)
	{
		[unroll]
		for (int x = -1; x <= 1; ++x)
		{
			const uint2 idx = (int2)pos + int2(x, y);
			samples3x3[i++] = txSrc[idx];
		}
	}
}

//--------------------------------------------------------------------------------------
// Compute shader
//--------------------------------------------------------------------------------------
[numthreads(8, 8, 1)]
void main(uint2 DTid : SV_DispatchThreadID)
{
	float2 imageSize;
	g_rwDst.GetDimensions(imageSize.x, imageSize.y);

	const float2 uv = (DTid + 0.5) / imageSize;

	const float depth = g_txDepth[DTid];
	if (g_level > 0)
	{
		if (depth >= 1.0) return;
	}
	else if (depth >= 1.0)
	{
		g_rwDst[DTid] = depth;

		return;
	}

	// Fetch 3x3 finer samples
	float depths[9];
	Fetch3x3(depths, g_txDepth, DTid);

	// Gather 2x2 coarser samples
	const float4 coarserDepths = g_txDepthCoarser.GatherRed(g_sampler, uv);

	// Calculate domain weights for bilinear interpolation
	const float2 domain = BilinearDomainLoc(g_txDepthCoarser, uv);
	const float2 domainInv = 1.0 - domain;
	// |3|2|
	// |0|1|
	const float2 domains[] =
	{
		float2(domain.x, domainInv.y),
		float2(domainInv.x, domainInv.y),
		float2(domainInv.x, domain.y),
		float2(domain.x, domain.y),
	};
	const float4 wb =
	{
		domainInv.x * domain.y,
		domain.x * domain.y,
		domain.x * domainInv.y,
		domainInv.x * domainInv.y
	};

	// Assign center samples
	const float depthC = depths[4];

	// Calculate Gaussian weight
	const float blurRadius = GetBlurRadius(g_txDepth0, depthC, g_proj, g_projI);
#ifdef _CALC_COARSE_WEIGHT_DIRECTLY_
	const float w = 1.0 - MipGaussianBlendWeightCoarse(g_level, blurRadius);
#else
	const float w = MipGaussianBlendWeight(g_level, blurRadius);
#endif

	float src = depthC; // Fallback to the center sample
	float ws;

	uint i;
#ifdef _MULTI_FINER_
	// Apply 3x3 finer samples as fallback
	src = 0.0;
	ws = 0.0;

	[unroll]
	for (i = 0; i < 9; ++i)
	{
		const float depth = depths[i];

		// Calculate edge-stopping function
		float w = depth < 1.0;
		w *= DepthWeight(depthC, depth, SIGMA_Z);

		// 3x3 bilateral filter
		src += depth * w;
		ws += w;
	}

	src = ws > 0.0 ? src / ws : depthC;
#endif

	float dst = 0.0;
	ws = 0.0;

	[unroll]
	for (i = 0; i < 4; ++i)
	{
		const float depth = coarserDepths[i];

		// Calculate edge-stopping function
		float we = depth < 1.0;
		we *= DepthWeight(depthC, depth, SIGMA_Z);
		we = sqrt(sqrt(we));

		// Apply the convolution weight with edge-stopping function
		const float coarser = lerp(src, depth, we);
		dst += lerp(coarser * we, depthC, w) * wb[i];
		ws += lerp(we, 1.0, w) * wb[i];
	}

	dst = ws > 0.0 ? dst / ws : src;

	g_rwDst[DTid] = dst;
}
