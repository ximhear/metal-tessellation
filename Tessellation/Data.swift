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

import simd

let vertices: [float3] = [
  [-1,  0,  1],
  [ 1,  0, -1],
  [-1,  0, -1],
  [-1,  0,  1],
  [ 1,  0, -1],
  [ 1,  0,  1]
]

let vertexBuffer = Renderer.device.makeBuffer(bytes: vertices,
                                              length: MemoryLayout<float3>.stride * vertices.count,
                                              options: [])

/**
 Create control points
 - Parameters:
     - patches: number of patches across and down
     - size: size of plane
 - Returns: an array of patch control points. Each group of four makes one patch.
**/
func createControlPoints(patchLevel: Int, controlPoints c: [float3]) -> [float3] {
  
    if patchLevel == 0 {
        return c
    }
    var points: [float3] = []
    
    var m: [float3] = []
    m.append((c[0] + c[1]) / 2)
    m.append((c[1] + c[2]) / 2)
    m.append((c[2] + c[0]) / 2)
    points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [c[0], m[0], m[2]]))
    points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [m[0], c[1], m[1]]))
    points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [m[1], c[2], m[2]]))
    points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [m[0], m[1], m[2]]))
  return points
}
