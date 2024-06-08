//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#define RADIUS 24
#define PI 3.141592654
#define SIGMA_Z 96.0

//--------------------------------------------------------------------------------------
// Texture sampler
//--------------------------------------------------------------------------------------
SamplerState g_sampler;

float GaussianSigmaFromRadius(int radius)
{
	return (radius + 1) / 3.0;
}

float Gaussian(float r, float sigma)
{
	const float a = r / sigma;

	return exp(-0.5 * a * a);
}

float Gaussian(float r, int radius)
{
	const float sigma = GaussianSigmaFromRadius(radius);

	return Gaussian(r, sigma);
}

float DepthWeight(float depthC, float depth, float sigma)
{
	return exp(-abs(depthC - depth) * depthC * sigma);
}

int GetBlurRadius(Texture2D<float> txDepth, float depth, matrix proj, matrix projI)
{
	float2 texSize;
	txDepth.GetDimensions(texSize.x, texSize.y);
	
	float w = projI[2].z * depth + projI[3].z;
	w /= projI[2].w * depth + projI[3].w;

	return abs(0.05 * proj[0].x / w * texSize.x);
}
