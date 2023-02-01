//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "DepthToNormal.hlsli"

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
Texture2D<float> g_txThickness;
TextureCube<float3> g_txEnv;

SamplerState g_sampler;

float4 main(PSIn input) : SV_TARGET
{
	const float4 nrmDepth = DepthToNormal(input);
	const float3 N = nrmDepth.xyz;

	const float thickness = g_txThickness[input.Pos.xy];

	float3 pos = GetViewPos(input.UV, nrmDepth.w);
	pos = mul(float4(pos, 1.0), g_viewI).xyz;

	const float3 L = normalize(float3(1.0, 1.0, -1.0));
	const float3 V = normalize(g_eyePt - pos);
	const float NoV = saturate(dot(N, V));
	const float NoL = saturate(dot(N, L));

	const float3 refl = reflect(-V, N);
	const float3 refr = refract(-V, N, 0.8);
	const float3 spec = g_txEnv.Sample(g_sampler, refl);
	const float3 refraction = g_txEnv.Sample(g_sampler, refr);
	const float fresnel = min(pow(1.0 - NoV, 5.0) + 0.1, 0.25);

	float3 scatter = exp(-thickness / 48.0);
	scatter = lerp(sqrt(NoL + 0.4) * float3(0.24, 0.4, 0.56), refraction, scatter);

	return float4(lerp(scatter, spec, fresnel), 1.0);
}
