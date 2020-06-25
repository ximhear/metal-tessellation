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

import MetalKit

class Renderer: NSObject {
  
  static var device: MTLDevice!
  static var commandQueue: MTLCommandQueue!
  static var colorPixelFormat: MTLPixelFormat!
  static var library: MTLLibrary?
  var depthStencilState: MTLDepthStencilState
  var renderPipelineState: MTLRenderPipelineState
  var wireframe = true

  // model transform
  var position = float3([0, 0, 0])
  var rotation = float3(Float(-0).degreesToRadians, 0, 0)
  var modelMatrix: float4x4 {
    let translationMatrix = float4x4(translation: position)
    let rotationMatrix = float4x4(rotation: rotation)
    return translationMatrix * rotationMatrix
  }
    
    let patchLevel = 4
    var patchCount: Int {
        return Int(pow(Double(4), Double(patchLevel)))
    }
    var edgeFactors: [Float] = [16, 16, 16]
    var insideFactors: Float = 16
    var controlPointsBuffer: MTLBuffer?
    var tessellationPipelineState: MTLComputePipelineState
    
    lazy var tessellationFactorsBuffer: MTLBuffer? = {
        let count = patchCount * 6
        let size = count * MemoryLayout<Float>.size / 2
        return Renderer.device.makeBuffer(length: size, options: .storageModePrivate)
    }()

  init(metalView: MTKView) {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("GPU not available")
    }
    metalView.depthStencilPixelFormat = .depth32Float
    metalView.device = device
    Renderer.device = device
    Renderer.commandQueue = device.makeCommandQueue()!
    Renderer.colorPixelFormat = metalView.colorPixelFormat
    Renderer.library = device.makeDefaultLibrary()
    
    renderPipelineState = Renderer.buildRenderPipelineState()
    depthStencilState = Renderer.buildDepthStencilState()
    tessellationPipelineState = Renderer.buildComputePipelineState()
    super.init()
    metalView.clearColor = MTLClearColor(red: 1, green: 1,
                                         blue: 1, alpha: 1)
    metalView.delegate = self
    
    let controlPoints = createControlPoints(patchLevel: patchLevel, controlPoints: [float3(0, -0.9, 0), float3(-0.9, 0.9, 0), float3(0.9, 0.9, 0)])
    controlPointsBuffer = Renderer.device.makeBuffer(bytes: controlPoints, length: MemoryLayout<float3>.stride * controlPoints.count)
  }
  
  static func buildDepthStencilState() -> MTLDepthStencilState {
    let descriptor = MTLDepthStencilDescriptor()
    descriptor.depthCompareFunction = .less
    descriptor.isDepthWriteEnabled = true
    return Renderer.device.makeDepthStencilState(descriptor: descriptor)!
  }
  
  static func buildRenderPipelineState() -> MTLRenderPipelineState {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.depthAttachmentPixelFormat = .depth32Float

    let vertexFunction = Renderer.library?.makeFunction(name: "vertex_main")
    let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_main")
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    
    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float3
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0
    
    print("float3 stride: \(MemoryLayout<float3>.stride)")
    vertexDescriptor.layouts[0].stride = MemoryLayout<float3>.stride
    vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
    descriptor.vertexDescriptor = vertexDescriptor
    
    return try! device.makeRenderPipelineState(descriptor: descriptor)
  }
    
    static func buildComputePipelineState() -> MTLComputePipelineState {
        guard let kernelFunc = Renderer.library?.makeFunction(name: "tessellation_main") else {
            fatalError("error")
        }
        return try! Renderer.device.makeComputePipelineState(function: kernelFunc)
        
    }
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }
  
  func draw(in view: MTKView) {
    guard let descriptor = view.currentRenderPassDescriptor,
      let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
      let drawable =  view.currentDrawable
      else {
        return
    }
    // uniforms
    let projectionMatrix = float4x4(projectionFov: 1.2, near: 0.01, far: 100,
                                    aspect: Float(view.bounds.width/view.bounds.height))
    let viewMatrix = float4x4(translation: [0, 0, -1.8])
    var mvp = projectionMatrix * viewMatrix.inverse * modelMatrix

    
    // tessellation pass
    let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
    computeEncoder.setComputePipelineState(tessellationPipelineState)
    computeEncoder.setBytes(&edgeFactors, length: MemoryLayout<Float>.size * edgeFactors.count, index: 0)
    computeEncoder.setBytes(&insideFactors, length: MemoryLayout<Float>.size, index: 1)
    computeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
    let width = min(patchCount, tessellationPipelineState.threadExecutionWidth)
    computeEncoder.dispatchThreads(MTLSizeMake(patchCount, 1, 1), threadsPerThreadgroup: MTLSizeMake(width, 1, 1))
    computeEncoder.endEncoding()

    // render
    let renderEncoder =
      commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
    renderEncoder.setRenderPipelineState(renderPipelineState)
//    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(controlPointsBuffer, offset: 0, index: 0)
    let fillmode: MTLTriangleFillMode = wireframe ? .lines : .fill
    renderEncoder.setTriangleFillMode(fillmode)

    // draw
    renderEncoder.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
//    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    renderEncoder.drawPatches(numberOfPatchControlPoints: 3,
                              patchStart: 0, patchCount: patchCount,
                              patchIndexBuffer: nil,
                              patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}


