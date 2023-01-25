//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "BlurCommon.hlsli"

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

	const float2 domain = BilinearDomainLoc(g_txDepth, uv);
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

	// Calculate the major attribute
	float z = 0.0, ws = 0.0;

	[unroll]
	for (uint i = 0; i < 4; ++i)
	{
		const float w = (srcs[i].y < 1.0) * wb[i]; // Mask out the background (depth = 1)
		z += srcs[i].y * w;
		ws += w;
	}

	z /= ws;

	// Down sampling with 2x2 bilateral filtering
	float2 dst = float2(0.0, 0.0);
	float w_max = 0.0;
	ws = 0.0;

	[unroll]
	for (i = 0; i < 4; ++i)
	{
		// Calculate edge-stopping function
		float w = srcs[i].y < 1.0;
		w *= DepthWeight(z, srcs[i].y, SIGMA_Z);
		w *= wb[i];

		if (w > w_max)
		{
			dst.y = srcs[i].y;
			w_max = w;
		}

		dst.x += srcs[i].x * w;
		ws += w;
	}

	// Fallback for all-zero weights
	dst.x = ws > 0.0 ? dst.x / ws : src0.x;

	g_rwDepth[DTid] = dst;
}
