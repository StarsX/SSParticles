//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Structure
//--------------------------------------------------------------------------------------
struct PSIn
{
	float4 Pos	: SV_POSITION;
	float2 UV	: TEXCOORD;
};

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
// Texture
//--------------------------------------------------------------------------------------
Texture2D<float> g_depth;

float3 GetViewPos(float2 uv, float depth)
{
	float2 xy = uv * 2.0 - 1.0;
	xy.y = -xy.y;

	float4 pos = float4(xy, depth, 1.0);
	pos = mul(pos, g_projI);

	return pos.xyz / pos.w;
}

float4 main(PSIn input) : SV_TARGET
{
	float2 texSize;
	g_depth.GetDimensions(texSize.x, texSize.y);

	// Read depth from texture
	const uint2 idx = input.Pos.xy;
	float depth = g_depth[idx];
	if (depth >= 1.0) discard;

	// calculate eye-space position from depth
	float3 pos = GetViewPos(input.UV, depth);
	const float2 texel = 1.0 / texSize;

	// Calculate differences
	depth = g_depth[uint2(idx.x + 1, idx.y)];
	float3 ddx = GetViewPos(float2(input.UV.x + texel.x, input.UV.y), depth) - pos;
	depth = g_depth[uint2(idx.x - 1, idx.y)];
	const float3 ddx2 = pos - GetViewPos(float2(input.UV.x - texel.x, input.UV.y), depth);
	ddx = abs(ddx.z) > abs(ddx2.z) ? ddx2 : ddx;

	depth = g_depth[uint2(idx.x, idx.y + 1)];
	float3 ddy = GetViewPos(float2(input.UV.x, input.UV.y + texel.y), depth) - pos;
	depth = g_depth[uint2(idx.x, idx.y - 1)];
	const float3 ddy2 = pos - GetViewPos(float2(input.UV.x, input.UV.y - texel.y), depth);
	ddy = abs(ddy2.z) < abs(ddy.z) ? ddy2 : ddy;

	// calculate normal
	float3 nrm = normalize(cross(ddx, ddy));
	nrm = mul(nrm, (float3x3)g_viewI);

	return float4(nrm, 1.0);
}
