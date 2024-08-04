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

Texture2D<float2> g_txDepthCoarser	: register (t0);
Texture2D<float2> g_txDepthCoarserE	: register (t1);
Texture2D<float2> g_txDepth			: register (t2);
Texture2D<float> g_txDepth0			: register (t3);

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
void Fetch3x3(out float2 samples3x3[9], Texture2D<float2> txSrc, uint2 pos)
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
// Calculate domain weights for 2x2 to 3x3 linear interpolation
//--------------------------------------------------------------------------------------
void DomainWeights(out float wd[9], uint2 idx)
{
	const int2 offset = int2(idx % 2) * 2 - 1;
	uint i = 0;

	[unroll]
	for (int y = -1; y <= 1; ++y)
	{
		[unroll]
		for (int x = -1; x <= 1; ++x)
		{
			float2 d = int2(x, y) * 4 - offset;
			//d = (33.0 - d * d) / 64.0;
			d = (17.0 - abs(d) * 3.0) / 24.0;
			wd[i] = d.x * d.y;
			++i;
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

	const float depth = g_txDepth[DTid].y;
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
	float2 depths[9], depthCoarsers[9], depthCoarsersE[9];
	Fetch3x3(depths, g_txDepth, DTid);

	const uint2 posCC = DTid / 2; // Center texcoord position of the coarser layer
	Fetch3x3(depthCoarsers, g_txDepthCoarser, posCC);
	Fetch3x3(depthCoarsersE, g_txDepthCoarserE, posCC);

	[unroll]
	for (uint i = 0; i < 9; ++i) depthCoarsers[i].y = depthCoarsersE[i].y;

	// Calculate domain weights for 3x3 linear interpolation
	float wd[9];
	DomainWeights(wd, DTid);

	// Assign center samples
	const float2 depthC = depths[4];

	// Calculate Gaussian weight
	const float blurRadius = GetBlurRadius(g_txDepth0, depthC.x, g_proj, g_projI);
#ifdef _CALC_COARSE_WEIGHT_DIRECTLY_
	const float wc = MipGaussianBlendWeightCoarse(g_level, blurRadius);
	float wf = 1.0;
#else
	float wf = MipGaussianBlendWeight(g_level, blurRadius);
	float wc = 1.0 - wf;
	wf = 1.0;
#endif

	float2 filtered = float2(depthC.x, 1.0); // Fallback to the center sample
	float2 dst = 0.0;

#ifdef _MULTI_FINER_
	// Apply 3x3 finer samples as fallback
	[unroll]
	for (i = 0; i < 9; ++i)
	{
		if (i != 4)
		{
			const float2 depth = depths[i];

			// Calculate edge-stopping function
			float fr = depth.y < 1.0;
			fr *= DepthWeight(depthC.y, depth.y, SIGMA_Z);
			//fr = pow(fr, 0.333);

			// 3x3 bilateral filter
			filtered.x += depth.x * fr;
			filtered.y += fr;
		}
	}

	filtered.x = filtered.y > 0.0 ? filtered.x / filtered.y : depthC.x;
#endif

	i = 0;

	[unroll]
	for (int y = -1; y <= 1; ++y)
	{
		[unroll]
		for (int x = -1; x <= 1; ++x)
		{
			const float2 depth = depthCoarsers[i];
			float w = wc;

			// Calculate edge-stopping function
			float fr = depth.y < 1.0;
			fr *= DepthWeight(depthC.y, depth.y, SIGMA_Z);
			//fr = pow(fr, 0.333);

			// Apply the coarser weight with edge-stopping function and the sample weight
			float coarser = depth.x;
			//coarser = lerp(filtered.x, coarser, fr);

			w *= wd[i];
			wf -= w;
			w *= fr;

			dst.x += coarser * w;
			dst.y += w;
			++i;
		}
	}

	// Center sample
	dst.x += depthC.x * wf;
	dst.y += wf;

	dst.x = dst.y > 0.0 ? dst.x / dst.y : filtered.x;

	g_rwDst[DTid] = dst.x;
}
