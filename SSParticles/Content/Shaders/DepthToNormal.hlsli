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
	float3 g_eyePt;
};

//--------------------------------------------------------------------------------------
// Texture
//--------------------------------------------------------------------------------------
Texture2D<float> g_txDepth;

float3 GetViewPos(float2 uv, float depth)
{
	float2 xy = uv * 2.0 - 1.0;
	xy.y = -xy.y;

	float4 pos = float4(xy, depth, 1.0);
	pos = mul(pos, g_projI);

	return pos.xyz / pos.w;
}

float4 DepthToNormal(PSIn input)
{
	float2 texSize;
	g_txDepth.GetDimensions(texSize.x, texSize.y);

	// Read depth from texture
	const uint2 idx = input.Pos.xy;
	float depth = g_txDepth[idx];
	if (depth >= 1.0) discard;

	// Calculate eye-space position from depth
	const float3 pos = GetViewPos(input.UV, depth);
	const float2 texel = 1.0 / texSize;

	// Calculate differences
	depth = g_txDepth[uint2(idx.x + 1, idx.y)];
	float3 ddx = GetViewPos(float2(input.UV.x + texel.x, input.UV.y), depth) - pos;
	depth = g_txDepth[uint2(idx.x - 1, idx.y)];
	const float3 ddx2 = pos - GetViewPos(float2(input.UV.x - texel.x, input.UV.y), depth);
	ddx = abs(ddx.z) > abs(ddx2.z) ? ddx2 : ddx;

	depth = g_txDepth[uint2(idx.x, idx.y + 1)];
	float3 ddy = GetViewPos(float2(input.UV.x, input.UV.y + texel.y), depth) - pos;
	depth = g_txDepth[uint2(idx.x, idx.y - 1)];
	const float3 ddy2 = pos - GetViewPos(float2(input.UV.x, input.UV.y - texel.y), depth);
	ddy = abs(ddy2.z) < abs(ddy.z) ? ddy2 : ddy;

	// Calculate normal
	float3 nrm = normalize(cross(ddx, ddy));

	return float4(mul(nrm, (float3x3)g_viewI), depth);
}
