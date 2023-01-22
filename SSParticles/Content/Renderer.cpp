//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#include "DXFrameworkHelper.h"
#include "Renderer.h"
#include "ParticleBin.h"

using namespace std;
using namespace DirectX;
using namespace XUSG;

struct CBPerFrame
{
	XMFLOAT4X4	WorldView;
	XMFLOAT4X4	Proj;
	XMFLOAT4X4	ViewI;
	XMFLOAT4X4	ProjI;
};

Renderer::Renderer() :
	m_frameParity(0)
{
	m_shaderLib = ShaderLib::MakeUnique();
}

Renderer::~Renderer()
{
}

bool Renderer::Init(CommandList* pCommandList, vector<Resource::uptr>& uploaders,
	const char* fileNamePrefix, int numFrames)
{
	const auto pDevice = pCommandList->GetDevice();
	m_numFrames = numFrames;

	// Load frame data of particles
#if defined (_DEBUG)
	const auto bPrint = false;
#else
	const auto bPrint = false;
#endif
	vector<ParticleFrame> particleFrameData(numFrames);
	LoadParticleBinAnimation(particleFrameData.data(), &m_fps, fileNamePrefix, numFrames, bPrint);

	// Create buffers
	m_particleFrames.resize(numFrames);
	m_numParticles.resize(numFrames);
	for (auto i = 0; i < numFrames; ++i)
	{
		auto& frameData = particleFrameData[i];
		auto& particleFrame = m_particleFrames[i];
		const auto numParticles = max<uint32_t>(frameData.NumParticles, 1);

		particleFrame = StructuredBuffer::MakeUnique();
		XUSG_N_RETURN(particleFrame->Create(pDevice, numParticles,
			sizeof(Particle), ResourceFlag::NONE, MemoryType::DEFAULT, 1, nullptr,
			1, nullptr, MemoryFlag::NONE, (L"ParticleFrame" + to_wstring(i)).c_str()), false);

		uploaders.emplace_back(Resource::MakeUnique());
		XUSG_N_RETURN(particleFrame->Upload(pCommandList, uploaders.back().get(), frameData.pParticles,
			sizeof(Particle) * numParticles, 0, ResourceState::NON_PIXEL_SHADER_RESOURCE), false);

		m_numParticles[i] = numParticles;
		SAFE_FREE(frameData.pParticles);
	}

	// Create constant buffer
	m_cbPerFrame = ConstantBuffer::MakeUnique();
	XUSG_N_RETURN(m_cbPerFrame->Create(pDevice, sizeof(CBPerFrame[FrameCount]), FrameCount,
		nullptr, MemoryType::UPLOAD, MemoryFlag::NONE, L"CBPerFrame"), false);

	// Create shaders and input layout
	XUSG_N_RETURN(createShaders(), false);

	return true;
}

bool Renderer::SetViewport(const Device* pDevice, uint32_t width, uint32_t height)
{
	m_viewport = XMUINT2(width, height);

	// Create resources and pipelines
	m_numMips = CalculateMipLevels(m_viewport.x, m_viewport.y);
	assert(m_numMips >= 2);

	// Create output views
	m_depth = DepthStencil::MakeUnique();
	XUSG_N_RETURN(m_depth->Create(pDevice, width, height, Format::D32_FLOAT,
		ResourceFlag::NONE, 1, 1, 1, 1.0f, 0, false, MemoryFlag::NONE, L"Depth"), false);

	m_scratch = Texture::MakeUnique();
	XUSG_N_RETURN(m_scratch->Create(pDevice, width, height, Format::R32_FLOAT, 1,
		ResourceFlag::ALLOW_UNORDERED_ACCESS, m_numMips, 1, false, MemoryFlag::NONE, L"Scratch"), false);

	m_filtered = Texture::MakeUnique();
	XUSG_N_RETURN(m_filtered->Create(pDevice, width, height, Format::R32_FLOAT, 1,
		ResourceFlag::ALLOW_UNORDERED_ACCESS, m_numMips, 1, false, MemoryFlag::NONE, L"FilteredDepth"), false);

	// Create constant buffers
	const uint8_t numPasses = m_numMips - 1;
	m_cbPerPass = ConstantBuffer::MakeUnique();
	XUSG_N_RETURN(m_cbPerPass->Create(pDevice, sizeof(uint32_t) * numPasses,
		numPasses, nullptr, MemoryType::UPLOAD, MemoryFlag::NONE, L"CBPerPass"), false);
	for (uint8_t i = 0; i < numPasses; ++i)
		*static_cast<uint32_t*>(m_cbPerPass->Map(i)) = numPasses - (i + 1);

	return true;
}

void Renderer::SetLightProbe(const Texture::sptr& radiance)
{
	m_radiance = radiance;
}

void Renderer::UpdateFrame(double time, uint8_t frameIndex,
	CXMVECTOR eyePt, CXMMATRIX view, CXMMATRIX proj)
{
	{
		const auto viewI = XMMatrixInverse(nullptr, view);
		const auto projI = XMMatrixInverse(nullptr, proj);

		const auto pCbData = reinterpret_cast<CBPerFrame*>(m_cbPerFrame->Map(frameIndex));
		XMStoreFloat4x4(&pCbData->WorldView, XMMatrixTranspose(view));
		XMStoreFloat4x4(&pCbData->Proj, XMMatrixTranspose(proj));
		XMStoreFloat4x4(&pCbData->ViewI, XMMatrixTranspose(viewI));
		XMStoreFloat4x4(&pCbData->ProjI, XMMatrixTranspose(projI));
	}

	m_particleFrameIdx = static_cast<uint32_t>(m_fps * time) % m_numFrames;
	m_frameParity = !m_frameParity;
}

void Renderer::Render(EZ::CommandList* pCommandList, uint8_t frameIndex,
	RenderTarget* pOutView, bool needClear)
{
	renderSphereDepth(pCommandList, frameIndex);
#if 1
	pCommandList->Blit(m_scratch.get(), m_depth.get(), POINT_CLAMP);
	bilateralDown(pCommandList);
	bilateralUp(pCommandList, frameIndex);
#else
	bilateralH(pCommandList, frameIndex);
	bilateralV(pCommandList, frameIndex);
#endif
	visualize(pCommandList, frameIndex, pOutView, needClear);
	//environment(pCommandList, frameIndex);
}

uint32_t Renderer::GetFrameIndex() const
{
	return m_particleFrameIdx;
}

uint32_t Renderer::GetParticleCount() const
{
	return m_numParticles[m_particleFrameIdx];
}

bool Renderer::createShaders()
{
	auto vsIndex = 0u;
	auto psIndex = 0u;
	auto csIndex = 0u;

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::VS, vsIndex, L"VSParticle.cso"), false);
	m_shaders[VS_PARTICLE] = m_shaderLib->GetShader(Shader::Stage::VS, vsIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::VS, vsIndex, L"VSScreenQuad.cso"), false);
	m_shaders[VS_SCREEN_QUAD] = m_shaderLib->GetShader(Shader::Stage::VS, vsIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::PS, psIndex, L"PSSphere.cso"), false);
	m_shaders[PS_SPHERE] = m_shaderLib->GetShader(Shader::Stage::PS, psIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::PS, psIndex, L"PSVisualize.cso"), false);
	m_shaders[PS_VISUALIZE] = m_shaderLib->GetShader(Shader::Stage::PS, psIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::PS, psIndex, L"PSEnvironment.cso"), false);
	m_shaders[PS_ENVIRONMENT] = m_shaderLib->GetShader(Shader::Stage::PS, psIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::CS, csIndex, L"CSBilateralH.cso"), false);
	m_shaders[CS_BILATERAL_H] = m_shaderLib->GetShader(Shader::Stage::CS, csIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::CS, csIndex, L"CSBilateralV.cso"), false);
	m_shaders[CS_BILATERAL_V] = m_shaderLib->GetShader(Shader::Stage::CS, csIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::CS, csIndex, L"CSBilateralDown.cso"), false);
	m_shaders[CS_BILATERAL_DOWN] = m_shaderLib->GetShader(Shader::Stage::CS, csIndex++);

	XUSG_N_RETURN(m_shaderLib->CreateShader(Shader::Stage::CS, csIndex, L"CSBilateralUp.cso"), false);
	m_shaders[CS_BILATERAL_UP] = m_shaderLib->GetShader(Shader::Stage::CS, csIndex++);

	return true;
}

void Renderer::renderSphereDepth(EZ::CommandList* pCommandList, uint8_t frameIndex)
{
	// Set pipeline state
	pCommandList->SetGraphicsShader(Shader::Stage::VS, m_shaders[VS_PARTICLE]);
	pCommandList->SetGraphicsShader(Shader::Stage::PS, m_shaders[PS_SPHERE]);
	pCommandList->DSSetState(Graphics::DEFAULT_LESS);

	// Set depth target
	const auto dsv = EZ::GetDSV(m_depth.get());
	pCommandList->OMSetRenderTargets(0, nullptr, &dsv);

	// Clear depth target
	pCommandList->ClearDepthStencilView(dsv, ClearFlag::DEPTH, 1.0f);

	// Set viewport
	Viewport viewport(0.0f, 0.0f, static_cast<float>(m_viewport.x), static_cast<float>(m_viewport.y));
	RectRange scissorRect(0, 0, m_viewport.x, m_viewport.y);
	pCommandList->RSSetViewports(1, &viewport);
	pCommandList->RSSetScissorRects(1, &scissorRect);

	// Set IA
	pCommandList->IASetPrimitiveTopology(PrimitiveTopology::TRIANGLESTRIP);

	// Set CBVs
	const auto cbv = EZ::GetCBV(m_cbPerFrame.get(), frameIndex);
	pCommandList->SetResources(Shader::Stage::VS, DescriptorType::CBV, 0, 1, &cbv);
	pCommandList->SetResources(Shader::Stage::PS, DescriptorType::CBV, 0, 1, &cbv);

	// Set SRV
	const auto srv = EZ::GetSRV(m_particleFrames[m_particleFrameIdx].get());
	pCommandList->SetResources(Shader::Stage::VS, DescriptorType::SRV, 0, 1, &srv);

	pCommandList->Draw(4, m_numParticles[m_particleFrameIdx], 0, 0);
}

void Renderer::bilateralH(EZ::CommandList* pCommandList, uint8_t frameIndex)
{
	// Set pipeline state
	pCommandList->SetComputeShader(m_shaders[CS_BILATERAL_H]);

	// Set UAV
	const auto uav = EZ::GetUAV(m_scratch.get());
	pCommandList->SetResources(Shader::Stage::CS, DescriptorType::UAV, 0, 1, &uav);

	// Set CBV
	const auto cbv = EZ::GetCBV(m_cbPerFrame.get(), frameIndex);
	pCommandList->SetResources(Shader::Stage::CS, DescriptorType::CBV, 0, 1, &cbv);

	// Set SRV
	const auto srv = EZ::GetSRV(m_depth.get());
	pCommandList->SetResources(Shader::Stage::CS, DescriptorType::SRV, 0, 1, &srv);

	// Dispatch grid
	pCommandList->Dispatch(XUSG_DIV_UP(m_viewport.x, 8), XUSG_DIV_UP(m_viewport.y, 8), 1);
}

void Renderer::bilateralV(EZ::CommandList* pCommandList, uint8_t frameIndex)
{
	// Set pipeline state
	pCommandList->SetComputeShader(m_shaders[CS_BILATERAL_V]);

	// Set UAV
	const auto uav = EZ::GetUAV(m_filtered.get());
	pCommandList->SetResources(Shader::Stage::CS, DescriptorType::UAV, 0, 1, &uav);

	// Set CBV
	const auto cbv = EZ::GetCBV(m_cbPerFrame.get(), frameIndex);
	pCommandList->SetResources(Shader::Stage::CS, DescriptorType::CBV, 0, 1, &cbv);

	// Set SRV
	const auto srv = EZ::GetSRV(m_scratch.get());
	pCommandList->SetResources(Shader::Stage::CS, DescriptorType::SRV, 0, 1, &srv);

	// Dispatch grid
	pCommandList->Dispatch(XUSG_DIV_UP(m_viewport.x, 8), XUSG_DIV_UP(m_viewport.y, 8), 1);
}

void Renderer::bilateralDown(EZ::CommandList* pCommandList)
{
	// Generate mipmaps
	// Set pipeline state
	pCommandList->SetComputeShader(m_shaders[CS_BILATERAL_DOWN]);

	// Set sampler
	const auto sampler = POINT_CLAMP;
	pCommandList->SetSamplerStates(Shader::Stage::CS, 0, 1, &sampler);

	for (uint8_t i = 1; i < m_numMips; ++i)
	{
		// Set UAV
		const auto uav = EZ::GetUAV(m_scratch.get(), i);
		pCommandList->SetResources(Shader::Stage::CS, DescriptorType::UAV, 0, 1, &uav);

		// Set SRV
		const auto srv = EZ::GetSRVLevel(m_scratch.get(), i - 1);
		pCommandList->SetResources(Shader::Stage::CS, DescriptorType::SRV, 0, 1, &srv);

		// Dispatch grid
		const auto threadsX = (max)(m_viewport.x >> i, 1u);
		const auto threadsY = (max)(m_viewport.y >> i, 1u);
		pCommandList->Dispatch(XUSG_DIV_UP(threadsX, 8), XUSG_DIV_UP(threadsY, 8), 1);
	}
}

void Renderer::bilateralUp(EZ::CommandList* pCommandList, uint8_t frameIndex)
{
	// Up sampling
	// Set pipeline state
	pCommandList->SetComputeShader(m_shaders[CS_BILATERAL_UP]);

	// Set sampler
	const auto sampler = LINEAR_CLAMP;
	pCommandList->SetSamplerStates(Shader::Stage::CS, 0, 1, &sampler);

	const uint8_t numPasses = m_numMips - 1;
	for (uint8_t i = 0; i < numPasses; ++i)
	{
		const auto c = numPasses - i;
		const auto level = c - 1;

		// Set UAV
		const auto uav = EZ::GetUAV(m_filtered.get(), level);
		pCommandList->SetResources(Shader::Stage::CS, DescriptorType::UAV, 0, 1, &uav);

		// Set CBV
		const EZ::ResourceView cbvs[] =
		{
			EZ::GetCBV(m_cbPerFrame.get(), frameIndex),
			EZ::GetCBV(m_cbPerPass.get(), i)
		};
		pCommandList->SetResources(Shader::Stage::CS, DescriptorType::CBV, 0, static_cast<uint32_t>(size(cbvs)), cbvs);

		// Set SRVs
		const EZ::ResourceView srvs[] =
		{
			EZ::GetSRVLevel(i > 0 ? m_filtered.get() : m_scratch.get(), c),
			EZ::GetSRVLevel(m_scratch.get(), level),
			EZ::GetSRVLevel(m_scratch.get(), 0)
		};
		pCommandList->SetResources(Shader::Stage::CS, DescriptorType::SRV, 0, static_cast<uint32_t>(size(srvs)), srvs);

		// Dispatch grid
		const auto threadsX = (max)(m_viewport.x >> level, 1u);
		const auto threadsY = (max)(m_viewport.y >> level, 1u);
		pCommandList->Dispatch(XUSG_DIV_UP(threadsX, 8), XUSG_DIV_UP(threadsY, 8), 1);
	}
}

void Renderer::visualize(EZ::CommandList* pCommandList, uint8_t frameIndex,
	RenderTarget* pOutView, bool needClear)
{
	// Set pipeline state
	pCommandList->SetGraphicsShader(Shader::Stage::VS, m_shaders[VS_SCREEN_QUAD]);
	pCommandList->SetGraphicsShader(Shader::Stage::PS, m_shaders[PS_VISUALIZE]);
	pCommandList->DSSetState(Graphics::DEPTH_STENCIL_NONE);

	// Set render target
	const auto rtv = EZ::GetRTV(pOutView);
	pCommandList->OMSetRenderTargets(1, &rtv, nullptr);

	// Clear render target
	const float clearColor[4] = { 0.2f, 0.2f, 0.2f, 0.0f };
	if (needClear) pCommandList->ClearRenderTargetView(rtv, clearColor);

	// Set viewport
	Viewport viewport(0.0f, 0.0f, static_cast<float>(m_viewport.x), static_cast<float>(m_viewport.y));
	RectRange scissorRect(0, 0, m_viewport.x, m_viewport.y);
	pCommandList->RSSetViewports(1, &viewport);
	pCommandList->RSSetScissorRects(1, &scissorRect);

	// Set IA
	pCommandList->IASetPrimitiveTopology(PrimitiveTopology::TRIANGLESTRIP);

	// Set CBV
	const auto cbvPerFrame = EZ::GetCBV(m_cbPerFrame.get(), frameIndex);
	pCommandList->SetResources(Shader::Stage::PS, DescriptorType::CBV, 0, 1, &cbvPerFrame);

	// Set SRV
	const auto srv = EZ::GetSRV(m_filtered.get());
	pCommandList->SetResources(Shader::Stage::PS, DescriptorType::SRV, 0, 1, &srv);

	// Set sampler
	//const auto sampler = SamplerPreset::ANISOTROPIC_WRAP;
	//pCommandList->SetSamplerStates(Shader::Stage::PS, 0, 1, &sampler);

	pCommandList->Draw(3, 1, 0, 0);
}

void Renderer::environment(EZ::CommandList* pCommandList, uint8_t frameIndex)
{
	//// Set pipeline state
	//pCommandList->SetGraphicsShader(Shader::Stage::VS, m_shaders[VS_SCREEN_QUAD]);
	//pCommandList->SetGraphicsShader(Shader::Stage::PS, m_shaders[PS_ENVIRONMENT]);
	//pCommandList->DSSetState(Graphics::DEPTH_READ_LESS_EQUAL);

	//// Set render target
	//const auto rtv = EZ::GetRTV(m_renderTargets[RT_COLOR].get());
	//auto dsv = EZ::GetDSV(m_depth.get());
	//pCommandList->OMSetRenderTargets(1, &rtv, &dsv);

	//// Set CBV
	//const auto cbv = EZ::GetCBV(m_cbPerFrame.get(), frameIndex);
	//pCommandList->SetResources(Shader::Stage::PS, DescriptorType::CBV, 0, 1, &cbv);

	//// Set SRVs
	//const EZ::ResourceView srvs[] =
	//{
	//	EZ::GetSRV(m_radiance.get()),
	//	EZ::GetSRV(m_coeffSH.get())
	//};
	//pCommandList->SetResources(Shader::Stage::PS, DescriptorType::SRV, 0,
	//	static_cast<uint32_t>(size(srvs)), srvs);

	//// Set sampler
	//const auto sampler = SamplerPreset::ANISOTROPIC_WRAP;
	//pCommandList->SetSamplerStates(Shader::Stage::PS, 0, 1, &sampler);

	//pCommandList->IASetPrimitiveTopology(PrimitiveTopology::TRIANGLELIST);
	//pCommandList->Draw(3, 1, 0, 0);
}
