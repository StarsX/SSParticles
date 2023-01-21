//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "BlurCommon.hlsli"

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

	float2 sum = 0.0;
	for (int i = -RADIUS; i <= RADIUS; ++i)
	{
		const uint2 idx = uint2((int)DTid.x + i, DTid.y);

		const float z = g_txDepth[idx];

		// spatial domain
		float w = Gaussian(i, RADIUS);

		// range domain
		//w *= z < 1.0;
		w *= DepthWeight(depth, z, SIGMA_Z);

		sum.x += z * w;
		sum.y += w;
	}

	g_rwDepth[DTid] = sum.y > 0.0 ? sum.x / sum.y : sum.x;
}
