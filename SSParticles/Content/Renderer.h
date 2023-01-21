//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#pragma once

#include "Helper/XUSG-EZ.h"
#include "ParticleData.h"

class RendererEZ
{
public:
	RendererEZ();
	virtual ~RendererEZ();

	bool Init(XUSG::CommandList* pCommandList, std::vector<XUSG::Resource::uptr>& uploaders,
		const char* fileNamePrefix, int numFrames);
	bool SetViewport(const XUSG::Device* pDevice, uint32_t width, uint32_t height);

	void SetLightProbe(const XUSG::Texture::sptr& radiance);
	void UpdateFrame(double time, uint8_t frameIndex, DirectX::CXMVECTOR eyePt,
		DirectX::CXMMATRIX viewProj, DirectX::CXMMATRIX proj);
	void Render(XUSG::EZ::CommandList* pCommandList, uint8_t frameIndex,
		XUSG::RenderTarget* pOutView, bool needClear = false);

	uint32_t GetFrameIndex() const;
	uint32_t GetParticleCount() const;

	static const uint8_t FrameCount = 3;

protected:
	enum ShaderIndex : uint8_t
	{
		VS_PARTICLE,
		VS_SCREEN_QUAD,

		PS_SPHERE,
		PS_VISUALIZE,
		PS_ENVIRONMENT,

		CS_BILATERAL_H,
		CS_BILATERAL_V,

		NUM_SHADER
	};

	bool createShaders();

	void renderSphereDepth(XUSG::EZ::CommandList* pCommandList, uint8_t frameIndex);
	void bilateralH(XUSG::EZ::CommandList* pCommandList, uint8_t frameIndex);
	void bilateralV(XUSG::EZ::CommandList* pCommandList, uint8_t frameIndex);
	void visualize(XUSG::EZ::CommandList* pCommandList, uint8_t frameIndex,
		XUSG::RenderTarget* pOutView, bool needClear);
	void environment(XUSG::EZ::CommandList* pCommandList, uint8_t frameIndex);

	uint8_t		m_frameParity;

	DirectX::XMUINT2	m_viewport;
	DirectX::XMFLOAT4X4	m_worldViewProj;

	XUSG::Texture::sptr m_radiance;

	std::vector<XUSG::StructuredBuffer::uptr> m_particleFrames;

	XUSG::Texture::uptr			m_scratch;
	XUSG::Texture::uptr			m_filtered;
	XUSG::DepthStencil::uptr	m_depth;

	XUSG::ConstantBuffer::uptr	m_cbPerFrame;

	XUSG::ShaderLib::uptr		m_shaderLib;
	XUSG::Blob m_shaders[NUM_SHADER];

	std::vector<uint32_t>		m_numParticles;
	uint32_t					m_numFrames;
	uint32_t					m_particleFrameIdx;
	char m_fps;
};
