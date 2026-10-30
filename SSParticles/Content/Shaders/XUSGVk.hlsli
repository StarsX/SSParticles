//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#ifndef XUSG_VK_HLSLI
#define XUSG_VK_HLSLI

// DX12 keeps every view type in space 0. These are the Vulkan descriptor sets.
#define XUSG_VK_SPACE_CBV		0
#define XUSG_VK_SPACE_SRV		1
#define XUSG_VK_SPACE_UAV		2
#define XUSG_VK_SPACE_SAMPLER	3

// FXC shader model 5.0 does not accept vk:: attributes.
#ifdef __spirv__
#define XUSG_VK_BINDING(b, s) [[vk::binding(b, s)]]
#else
#define XUSG_VK_BINDING(b, s)
#endif

#endif
