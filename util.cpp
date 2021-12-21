#include "util.h"

//distance squared
float DistanceSquared(float3 a, float3 b) {
	float3 sub = a - b;
	return (sub.x * sub.x + sub.y * sub.y + sub.z * sub.z);
}

// dot product
float Dot(float3 a, float3 b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}