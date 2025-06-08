import Foundation
import GRPC
import GRPCImageServiceModels
import Logging
import ModelZoo
import NIO
import NIOSSL

public class ModelDiscoveryClient {
  private let logger = Logger(label: "com.draw-things.model-discovery-client")
  private var client: ImageGenerationServiceNIOClient?
  private var group: EventLoopGroup?
  
  public init() {}
  
  public func connect(host: String, port: Int, useTLS: Bool = false, sharedSecret: String? = nil) throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.group = group
    
    let channel: GRPCChannel
    if useTLS {
      let configuration = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL()
      channel = try GRPCChannelPool.with(
        target: .host(host, port: port),
        transportSecurity: .tls(configuration),
        eventLoopGroup: group
      )
    } else {
      channel = try GRPCChannelPool.with(
        target: .host(host, port: port),
        transportSecurity: .plaintext,
        eventLoopGroup: group
      )
    }
    
    self.client = ImageGenerationServiceNIOClient(channel: channel)
    logger.info("Connected to model server at \(host):\(port)")
  }
  
  public func disconnect() {
    try? group?.syncShutdownGracefully()
    client = nil
    group = nil
  }
  
  public func discoverModels(sharedSecret: String? = nil) async throws -> [RemoteModelInfo] {
    guard let client = client else {
      throw ModelDiscoveryError.notConnected
    }
    
    let request = ListModelsRequest.with {
      if let sharedSecret = sharedSecret {
        $0.sharedSecret = sharedSecret
      }
    }
    
    let response = try await client.listAvailableModels(request).response.get()
    
    guard !response.sharedSecretMissing else {
      throw ModelDiscoveryError.authenticationRequired
    }
    
    var remoteModels: [RemoteModelInfo] = []
    
    for model in response.models {
      remoteModels.append(RemoteModelInfo(
        name: model.name,
        file: model.file,
        humanReadableName: model.humanReadableName,
        version: model.version,
        type: .model,
        fileSize: model.fileSize,
        note: model.note,
        requiredFiles: model.requiredFiles
      ))
    }
    
    for lora in response.loras {
      remoteModels.append(RemoteModelInfo(
        name: lora.name,
        file: lora.file,
        humanReadableName: lora.humanReadableName,
        version: lora.version,
        type: .lora,
        fileSize: lora.fileSize,
        note: lora.note,
        requiredFiles: lora.requiredFiles
      ))
    }
    
    for controlNet in response.controlNets {
      remoteModels.append(RemoteModelInfo(
        name: controlNet.name,
        file: controlNet.file,
        humanReadableName: controlNet.humanReadableName,
        version: controlNet.version,
        type: .controlNet,
        fileSize: controlNet.fileSize,
        note: controlNet.note,
        requiredFiles: controlNet.requiredFiles
      ))
    }
    
    for upscaler in response.upscalers {
      remoteModels.append(RemoteModelInfo(
        name: upscaler.name,
        file: upscaler.file,
        humanReadableName: upscaler.humanReadableName,
        version: upscaler.version,
        type: .upscaler,
        fileSize: upscaler.fileSize,
        note: upscaler.note,
        requiredFiles: upscaler.requiredFiles
      ))
    }
    
    logger.info("Discovered \(remoteModels.count) remote models")
    return remoteModels
  }
}

public enum ModelDiscoveryError: Error {
  case notConnected
  case authenticationRequired
  case networkError(Error)
}

public enum RemoteModelType {
  case model
  case lora
  case controlNet
  case upscaler
}

public struct RemoteModelInfo {
  public let name: String
  public let file: String
  public let humanReadableName: String
  public let version: String
  public let type: RemoteModelType
  public let fileSize: Int64
  public let note: String
  public let requiredFiles: [String]
  
  public init(name: String, file: String, humanReadableName: String, version: String, type: RemoteModelType, fileSize: Int64, note: String, requiredFiles: [String]) {
    self.name = name
    self.file = file
    self.humanReadableName = humanReadableName
    self.version = version
    self.type = type
    self.fileSize = fileSize
    self.note = note
    self.requiredFiles = requiredFiles
  }
} 