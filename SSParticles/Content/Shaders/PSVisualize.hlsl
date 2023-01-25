//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "DepthToNormal.hlsli"

float4 main(PSIn input) : SV_TARGET
{
	const float3 N = DepthToNormal(input);

	// Simple shading
	const float3 L = normalize(float3(1.0, 1.0, -1.0));
	const float NoL = saturate(dot(N, L));

	return float4(float3(0.2, 0.6, 1.0) * (NoL + 0.25), 1.0);
}
