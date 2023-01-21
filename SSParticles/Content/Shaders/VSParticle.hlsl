//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Structure
//--------------------------------------------------------------------------------------
struct VSOut
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

//--------------------------------------------------------------------------------------
// Buffer
//--------------------------------------------------------------------------------------
StructuredBuffer<float4> g_particles;

VSOut main(uint VId : SV_VertexID, uint particleId : SV_InstanceID)
{
	VSOut output;

	const float4 particle = g_particles[particleId];
	float4 pos = mul(float4(particle.xyz, 1.0), g_worldView);

	const float r = 0.007 * pow(abs(particle.w), 1.0 / 3.0);

	const float2 uv = float2(VId & 1, VId >> 1);
	pos.xy += (uv * float2(2.0, -2.0) + float2(-1.0, 1.0)) * r;

	output.Pos = mul(pos, g_proj);
	output.UV = uv;
	output.PosV = pos.xyz;
	output.Radius = r;

	return output;
}
