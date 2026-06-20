import AppKit

// Exports the curated 1024px app icon source for release tooling.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let sourceURL = scriptURL.appendingPathComponent("AppIcon-1024.png")
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/agentpet-icon-1024.png"
let outputURL = URL(fileURLWithPath: outputPath)

guard let image = NSImage(contentsOf: sourceURL),
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to load \(sourceURL.path)\n".utf8))
    exit(1)
}

try png.write(to: outputURL)
print("wrote \(outputURL.path)")
