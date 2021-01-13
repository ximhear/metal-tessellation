///// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

#include <metal_stdlib>
#include "Common.h"

using namespace metal;

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
    float4 color;
};

struct VertexIn {
  float4 position [[attribute(0)]];
};

struct ControlPoint {
  float4 position [[attribute(0)]];
//    float2 tex [[attribute(1)]];
};


[[patch(quad, 4)]]
vertex VertexOut vertex_main(patch_control_point<ControlPoint> control_points [[stage_in]],
                             constant float4x4 &mvp [[buffer(1)]],
                             float2 patch_coord [[position_in_patch]],
                             uint patch_id [[patch_id]])
{
  VertexOut out;
    float u = patch_coord.x;
    float v = patch_coord.y;
//  float4 position = mvp * in.position;
    float2 top = mix(control_points[0].position.xz, control_points[1].position.xz, u);
    float2 bottom = mix(control_points[3].position.xz, control_points[2].position.xz, u);
    float2 interpolated = mix(top, bottom, v);

//    float2 topTex = mix(control_points[0].tex.xy, control_points[1].position.xy, u);
//    float2 bottomTex = mix(control_points[3].tex.xy, control_points[2].tex.xy, u);
//    float2 interpolatedTex = mix(topTex, bottomTex, v);

//    out.position = float4(2 * u - 1, (1 - v) * 2 - 1, 0, 1);
    
    out.position = float4(interpolated.x, interpolated.y, 0, 1);
//    out.position = float4(2 * u - 1 + 0.5 * (patch_id % 2), (1 - v) * 2 - 1 - 0.5 * (patch_id / 2), 0, 1);
//    out.texCoord = interpolatedTex;
    out.texCoord = interpolated;
    out.color = out.position;
    
    if (patch_id == 0) {
        out.color = float4(1, 0, 0, 1);
    }
    else if (patch_id == 1) {
        out.color = float4(0, 1, 0, 1);
    }
    else {
        out.color = float4(u, v, 0, 1);
    }
    out.color = float4(1, 0, 0, 1);
  return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               texture2d<half> colorMap     [[ texture(0) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

//    return in.color;
    return float4(colorSample);
}


kernel void tessellation_main(constant float* edge_factors [[ buffer(0) ]],
                              constant float* inside_factors [[ buffer(1) ]],
                              device MTLQuadTessellationFactorsHalf* factors [[buffer(2)]],
                              uint pid [[thread_position_in_grid]]) {
    
    factors[pid].edgeTessellationFactor[0] = edge_factors[0];
    factors[pid].edgeTessellationFactor[1] = edge_factors[1];
    factors[pid].edgeTessellationFactor[2] = edge_factors[2];
    factors[pid].edgeTessellationFactor[3] = edge_factors[3];

    factors[pid].insideTessellationFactor[0] = inside_factors[0];
    factors[pid].insideTessellationFactor[1] = inside_factors[1];
}
