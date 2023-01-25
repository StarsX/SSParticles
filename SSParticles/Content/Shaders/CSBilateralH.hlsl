//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "BlurCommon.hlsli"

//--------------------------------------------------------------------------------------
// Constant buffer
//--------------------------------------------------------------------------------------
cbuffer cbPerFrame
{
	matrix	g_worldView;
	matrix	g_proj;
	matrix	g_viewI;
	matrix	g_projI;
};

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
RWTexture2D<float3> g_rwDepth;

Texture2D<float> g_txDepth;

[numthreads(8, 8, 1)]
void main(uint2 DTid : SV_DispatchThreadID)
{
	const float depth = g_txDepth[DTid];
	if (depth >= 1.0)
	{
		g_rwDepth[DTid] = 1.0;
		return;
	}

	const int radius = GetBlurRadius(g_txDepth, depth, g_proj, g_projI);

	float2 sum = 0.0;
	for (int i = -radius; i <= radius; ++i)
	{
		const uint2 idx = uint2((int)DTid.x + i, DTid.y);

		const float z = g_txDepth[idx];

		// spatial domain
		float w = Gaussian(i, radius);

		// range domain
		w *= z < 1.0;
		w *= DepthWeight(depth, z, SIGMA_Z);

		sum.x += z * w;
		sum.y += w;
	}

	g_rwDepth[DTid] = sum.y > 0.0 ? sum.x / sum.y : sum.x;
}
