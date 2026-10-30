//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "XUSGVk.hlsli"

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
XUSG_VK_BINDING(0, XUSG_VK_SPACE_UAV)
RWTexture2D<float2> g_rwDepth;

XUSG_VK_BINDING(0, XUSG_VK_SPACE_SRV)
Texture2D<float> g_txDepth;

[numthreads(8, 8, 1)]
void main(uint2 DTid : SV_DispatchThreadID)
{
	g_rwDepth[DTid] = g_txDepth[DTid];
}
