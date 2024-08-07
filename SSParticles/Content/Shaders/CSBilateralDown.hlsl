//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "BlurCommon.hlsli"

#define _ACCURACY_MAJOR_

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
RWTexture2D<float2> g_rwDepth;

Texture2D<float2> g_txDepth;

//--------------------------------------------------------------------------------------
// Get domain location of bilinear filter
//--------------------------------------------------------------------------------------
float2 BilinearDomainLoc(Texture2D<float2> tx, float2 uv)
{
	float2 texSize;
	tx.GetDimensions(texSize.x, texSize.y);

	return frac(uv * texSize - 0.5);
}

//--------------------------------------------------------------------------------------
// Calculate domain weights for bilinear interpolation
//--------------------------------------------------------------------------------------
float4 BilinearDomainWeights(Texture2D<float2> tex, float2 uv)
{
	float2 texSize;
	tex.GetDimensions(texSize.x, texSize.y);

	const float2 domain = frac(uv * texSize - 0.5);
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

	return float4(
		domainInv.x * domain.y,
		domain.x * domain.y,
		domain.x * domainInv.y,
		domainInv.x * domainInv.y);
}

//--------------------------------------------------------------------------------------
// Compute shader
//--------------------------------------------------------------------------------------
[numthreads(8, 8, 1)]
void main(uint2 DTid : SV_DispatchThreadID)
{
	float2 imageSize;
	g_rwDepth.GetDimensions(imageSize.x, imageSize.y);

	const float2 uv = (DTid + 0.5) / imageSize;

	float2x4 gathers = float2x4(
		g_txDepth.GatherRed(g_sampler, uv),
		g_txDepth.GatherGreen(g_sampler, uv)
		);

	const float4x2 srcs = transpose(gathers);
	if (all(gathers[1] >= 1.0))
	{
		g_rwDepth[DTid] = 1.0;

		return;
	}

	// Get fallback samples with point (nearest) sampler
	const float2 src0 = g_txDepth.SampleLevel(g_sampler, uv, 0.0);

	// Calculate domain weights for bilinear interpolation
	const float4 wb = BilinearDomainWeights(g_txDepth, uv);

	// Select the major attributes (normal, depth, and roughness)
	uint m = 0;
	float z = 0.0;
#ifdef _ACCURACY_MAJOR_
	float ws = 0.0;

	// Calculate the average attribute values
	[unroll]
	for (uint i = 0; i < 4; ++i)
	{
		if (srcs[i].y < 1.0)
		{
			z += srcs[m].y;
			ws += 1.0;
		}
	}

	[unroll]
	for (i = 0; i < 4; ++i) z /= ws;

	// Select the max-weighted attributes as the major attributes
	ws = 0.0;
	[unroll]
	for (i = 0; i < 4; ++i)
	{
		// Calculate simplified edge-stopping function  for comparison (no need to normalize)
		float w = srcs[i].y < 1.0;
		w *= DepthWeight(z, srcs[i].y, 1.0);
		w *= wb[i];

		if (w > ws)
		{
			m = i;
			ws = w;
		}
	}
#else
	static const uint2x2 ms = { 1, 0, 2, 3 };
	const uint rm = ms[DTid.y & 1][DTid.x & 1];

	[unroll]
	for (uint i = 0; i < 4; ++i)
	{
		m = srcs[i].y < 1.0 ? i : m;
		if (m == rm) break;
	}
#endif

	z = srcs[m].y;

	// 2x2 down sampling
	float2 dst = 0.0;

	[unroll]
	for (i = 0; i < 4; ++i)
	{
		// Calculate edge-stopping function
		float w = srcs[i].y < 1.0;
		w *= DepthWeight(z, srcs[i].y, SIGMA_Z);
		w *= wb[i];

		dst.x += srcs[i].x * w;
		dst.y += w;
	}

	// Fallback for all-zero weights
	dst.x = dst.y > 0.0 ? dst.x / dst.y : src0.x;

	g_rwDepth[DTid] = float2(dst.x, z);
}
