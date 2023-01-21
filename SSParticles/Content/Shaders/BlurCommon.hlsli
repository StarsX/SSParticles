//--------------------------------------------------------------------------------------
// Copyright (c) XU, Tianchen. All rights reserved.
//--------------------------------------------------------------------------------------

#define RADIUS 16
#define PI 3.141592654
#define SIGMA_Z 128.0

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
