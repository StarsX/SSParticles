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
RWTexture2D<float> g_rwDepth;

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
	for (int y = -radius; y <= radius; ++y)
	{
		for (int x = -radius; x <= radius; ++x)
		{
			const int2 offset = int2(x, y);
			const uint2 idx = (int2)DTid + offset;

			const float z = g_txDepth[idx];

			// spatial domain
			const float r = length(offset);
			float w = Gaussian(r, radius);

			// range domain
			w *= z < 1.0;
			w *= DepthWeight(depth, z, SIGMA_Z);
			w = pow(w, 0.333);

			sum.x += z * w;
			sum.y += w;
		}
	}

	g_rwDepth[DTid] = sum.y > 0.0 ? sum.x / sum.y : sum.x;
}
