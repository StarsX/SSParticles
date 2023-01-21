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
	float3 PosV	: POSVIEW;
	float Radius : RADIUS;
};

//--------------------------------------------------------------------------------------
// Constant buffer
//--------------------------------------------------------------------------------------
cbuffer cbPerFrame
{
	matrix	g_worldView;
	matrix	g_proj;
};

float main(PSIn input) : SV_DepthLessEqual
{
	// Calculate eye-space sphere normal from texture coordinates
	float3 nrm;
	nrm.xy = input.UV * 2.0 - 1.0;

	float r_sq = dot(nrm.xy, nrm.xy);
	if (r_sq > 1.0) discard; // Kill pixels outside circle

	nrm.z = -sqrt(1.0 - r_sq);
	nrm = normalize(nrm);

	// Calculate depth
	const float4 posV = float4(input.PosV + nrm * input.Radius, 1.0);
	const float4 pos = mul(posV, g_proj);

	return pos.z / pos.w;
}
