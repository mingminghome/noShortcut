import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func drawSymbol(
    named name: String,
    pointSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    in rect: CGRect,
    context: CGContext
) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return
    }

    context.saveGState()
    context.interpolationQuality = .high
    context.draw(cgImage, in: rect)
    context.restoreGState()
}

func drawIconPNG(pixelSize: Int) -> Data? {
    let width = pixelSize
    let height = pixelSize

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    let size = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    context.addPath(path)
    context.clip()

    let bgColors = [
        CGColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1),
        CGColor(red: 0.18, green: 0.20, blue: 0.30, alpha: 1)
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 1])!
    context.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    context.resetClip()
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    let ringDiameter = size * 0.58
    let ringRect = CGRect(
        x: (size - ringDiameter) / 2,
        y: (size - ringDiameter) / 2,
        width: ringDiameter,
        height: ringDiameter
    )
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    context.setLineWidth(max(1.5, size * 0.045))
    context.strokeEllipse(in: ringRect)

    let commandSize = size * 0.30
    let commandRect = CGRect(
        x: (size - commandSize) / 2,
        y: (size - commandSize) / 2,
        width: commandSize,
        height: commandSize
    )
    drawSymbol(named: "command", pointSize: commandSize, weight: .bold, color: .white, in: commandRect, context: context)

    guard let cgImage = context.makeImage() else { return nil }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        return nil
    }

    let properties: [CFString: Any] = [
        kCGImagePropertyPixelWidth: width,
        kCGImagePropertyPixelHeight: height,
        kCGImageDestinationLossyCompressionQuality: 1.0
    ]

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}

func writeIcon(filename: String, pixelSize: Int, outputDirectory: URL) {
    guard let png = drawIconPNG(pixelSize: pixelSize) else {
        fputs("Failed to render \(filename)\n", stderr)
        return
    }

    let url = outputDirectory.appendingPathComponent(filename)
    do {
        try png.write(to: url, options: .atomic)
        print("Wrote \(url.path) (\(pixelSize)x\(pixelSize))")
    } catch {
        fputs("Failed to write \(filename): \(error)\n", stderr)
    }
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

let icons: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, pixelSize) in icons {
    writeIcon(filename: filename, pixelSize: pixelSize, outputDirectory: output)
}