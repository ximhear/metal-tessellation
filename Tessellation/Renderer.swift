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

    var colorMap: MTLTexture

  // model transform
  var position = float3([0, 0, 0])
  var rotation = float3(Float(-90).degreesToRadians, 0, 0)
  var modelMatrix: float4x4 {
    let translationMatrix = float4x4(translation: position)
    let rotationMatrix = float4x4(rotation: rotation)
    return translationMatrix * rotationMatrix
  }
    
    let patches = (horizontal: 2, vertical: 2)
    var patchCount: Int {
        patches.horizontal * patches.vertical
    }
    static let factor: Float = 8
    var edgeFactors: [Float] = [factor, factor, factor, factor]
    var insideFactors: [Float] = [factor, factor]
    var controlPointsBuffer: MTLBuffer?
    var controlPointsTextureBuffer: MTLBuffer?
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

    do {
        colorMap = try Renderer.loadTexture(device: device, textureName: "grass-color")
    } catch {
        print("Unable to load texture. Error info: \(error)")
        exit(0)
    }

    
    super.init()
    metalView.clearColor = MTLClearColor(red: 1, green: 1,
                                         blue: 1, alpha: 1)
    metalView.delegate = self
    
    let controlPoints = createControlPoints(patches: patches, size: (2, 2))
    controlPointsBuffer = Renderer.device.makeBuffer(bytes: controlPoints.0, length: MemoryLayout<float3>.stride * controlPoints.0.count)
    controlPointsTextureBuffer = Renderer.device.makeBuffer(bytes: controlPoints.1, length: MemoryLayout<float2>.stride * controlPoints.1.count)
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
    descriptor.maxTessellationFactor = 64
    descriptor.tessellationOutputWindingOrder = .clockwise

    let vertexFunction = Renderer.library?.makeFunction(name: "vertex_main")
    let fragmentFunction = Renderer.library?.makeFunction(name: "fragment_main")
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    
    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float3
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0
    
    vertexDescriptor.attributes[1].format = .float2
    vertexDescriptor.attributes[1].offset = 0
    vertexDescriptor.attributes[1].bufferIndex = 1

    print("float3 stride: \(MemoryLayout<float3>.stride)")
    vertexDescriptor.layouts[0].stride = MemoryLayout<float3>.stride
    vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
    vertexDescriptor.layouts[1].stride = MemoryLayout<float2>.stride
    vertexDescriptor.layouts[1].stepFunction = .perPatchControlPoint
    descriptor.vertexDescriptor = vertexDescriptor
    
    return try! device.makeRenderPipelineState(descriptor: descriptor)
  }
    
    static func buildComputePipelineState() -> MTLComputePipelineState {
        guard let kernelFunc = Renderer.library?.makeFunction(name: "tessellation_main") else {
            fatalError("error")
        }
        return try! Renderer.device.makeComputePipelineState(function: kernelFunc)
        
    }
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling

        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)

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
//    let projectionMatrix = float4x4(projectionFov: 1.2, near: 0.01, far: 100,
//                                    aspect: Float(view.bounds.width/view.bounds.height))
    
    let projectionMatrix = float4x4(orthographic: Rectangle(left: 0, right: 1, top: 1, bottom: 0), near: -10, far: 10)
    let viewMatrix = float4x4(translation: [0, 0, -1.8])
    var mvp = projectionMatrix * viewMatrix.inverse * modelMatrix

    
    // tessellation pass
    let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
    computeEncoder.setComputePipelineState(tessellationPipelineState)
    computeEncoder.setBytes(&edgeFactors, length: MemoryLayout<Float>.size * edgeFactors.count, index: 0)
    computeEncoder.setBytes(&insideFactors, length: MemoryLayout<Float>.size * edgeFactors.count, index: 1)
    computeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
    let width = min(patchCount, tessellationPipelineState.threadExecutionWidth)
    computeEncoder.dispatchThreads(MTLSizeMake(patchCount, 1, 1), threadsPerThreadgroup: MTLSizeMake(width, 1, 1))
    computeEncoder.endEncoding()

    // render
    let renderEncoder =
      commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
    renderEncoder.setCullMode(.back)
    renderEncoder.setFrontFacing(.counterClockwise)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 2)
    renderEncoder.setRenderPipelineState(renderPipelineState)
//    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(controlPointsBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(controlPointsTextureBuffer, offset: 0, index: 1)
    let fillmode: MTLTriangleFillMode = wireframe ? .lines : .fill
    renderEncoder.setTriangleFillMode(fillmode)
    renderEncoder.setFragmentTexture(colorMap, index: 0)

    // draw
    renderEncoder.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
//    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    renderEncoder.drawPatches(numberOfPatchControlPoints: 4,
                              patchStart: 0, patchCount: patchCount,
                              patchIndexBuffer: nil,
                              patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}


