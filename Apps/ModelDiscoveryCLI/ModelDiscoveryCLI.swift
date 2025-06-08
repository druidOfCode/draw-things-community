import ArgumentParser
import Foundation
import GRPCServer
import Logging

@main
struct ModelDiscoveryCLI: ParsableCommand {
  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "ModelDiscoveryCLI",
    abstract: "Discover available models from a remote Draw Things gRPC server"
  )
  
  @Option(name: .shortAndLong, help: "The server address to connect to.")
  var host: String = "localhost"
  
  @Option(name: .shortAndLong, help: "The server port to connect to.")
  var port: Int = 7859
  
  @Option(name: .shortAndLong, help: "The shared secret for authentication.")
  var sharedSecret: String = ""
  
  @Flag(help: "Use TLS for the connection.")
  var tls = false
  
  @Flag(help: "Show detailed information about each model.")
  var verbose = false
  
  func run() throws {
    let client = ModelDiscoveryClient()
    
    do {
      try client.connect(
        host: host, 
        port: port, 
        useTLS: tls, 
        sharedSecret: sharedSecret.isEmpty ? nil : sharedSecret
      )
      
      let models = try await client.discoverModels(
        sharedSecret: sharedSecret.isEmpty ? nil : sharedSecret
      )
      
      if models.isEmpty {
        print("No models found on the server.")
        return
      }
      
      print("Found \(models.count) models on server \(host):\(port)")
      print()
      
      let groupedModels = Dictionary(grouping: models) { $0.type }
      
      for (type, typeModels) in groupedModels.sorted(by: { $0.key.sortOrder < $1.key.sortOrder }) {
        print("\(type.displayName):")
        print(String(repeating: "=", count: type.displayName.count + 1))
        
        for model in typeModels.sorted(by: { $0.humanReadableName < $1.humanReadableName }) {
          if verbose {
            print("  • \(model.humanReadableName)")
            print("    File: \(model.file)")
            print("    Version: \(model.version)")
            print("    Size: \(formatFileSize(model.fileSize))")
            if !model.note.isEmpty {
              print("    Note: \(model.note)")
            }
            if model.requiredFiles.count > 1 {
              print("    Required files: \(model.requiredFiles.joined(separator: ", "))")
            }
            print()
          } else {
            let sizeStr = formatFileSize(model.fileSize)
            print("  • \(model.humanReadableName) (\(model.version)) - \(sizeStr)")
          }
        }
        print()
      }
      
      client.disconnect()
      
    } catch ModelDiscoveryError.authenticationRequired {
      print("Error: Authentication required. Please provide a valid shared secret.")
    } catch ModelDiscoveryError.notConnected {
      print("Error: Failed to connect to server.")
    } catch {
      print("Error: \(error)")
    }
  }
  
  private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

extension RemoteModelType {
  var displayName: String {
    switch self {
    case .model: return "Models"
    case .lora: return "LoRA"
    case .controlNet: return "ControlNet"
    case .upscaler: return "Upscaler"
    }
  }
  
  var sortOrder: Int {
    switch self {
    case .model: return 0
    case .lora: return 1
    case .controlNet: return 2
    case .upscaler: return 3
    }
  }
} 