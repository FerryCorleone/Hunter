#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let resourceDirectory = root.appendingPathComponent("Sources/Hunter/Resources", isDirectory: true)
try FileManager.default.createDirectory(at: resourceDirectory, withIntermediateDirectories: true)

try renderAppIcon(to: resourceDirectory.appendingPathComponent("hunter-sunglasses-icon.png"))
if CommandLine.arguments.contains("--all") || CommandLine.arguments.contains("--status") {
    try renderStatusIcon(to: resourceDirectory.appendingPathComponent("hunter-status-icon.png"))
}

private func renderAppIcon(to url: URL) throws {
    let size = 1024
    guard let context = makeContext(width: size, height: size) else {
        throw IconError.contextCreationFailed
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    drawBackground(in: context, rect: rect)
    drawLogo(in: context, scale: 1)

    try writePNG(from: context, to: url)
}

private func renderStatusIcon(to url: URL) throws {
    let size = 72
    guard let context = makeContext(width: size, height: size) else {
        throw IconError.contextCreationFailed
    }

    drawStatusGlyph(in: context)
    try writePNG(from: context, to: url)
}

private func drawBackground(in context: CGContext, rect: CGRect) {
    context.saveGState()
    context.setFillColor(cgColor(0x000000))
    context.fill(rect)
    context.restoreGState()
}

private func drawLogo(in context: CGContext, scale: CGFloat) {
    let white = cgColor(0xFFFFFF)

    let speedLines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (642, 506, 220, 34),
        (662, 428, 180, 26),
        (685, 356, 118, 21)
    ]
    for (x, y, width, lineWidth) in speedLines {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: x * scale, y: y * scale))
        line.addLine(to: CGPoint(x: (x + width) * scale, y: y * scale))
        stroke(context, path: line, lineWidth: lineWidth * scale, color: white)
    }

    let arc = CGMutablePath()
    arc.addArc(
        center: CGPoint(x: 462 * scale, y: 508 * scale),
        radius: 246 * scale,
        startAngle: radians(88),
        endAngle: radians(330),
        clockwise: false
    )
    stroke(context, path: arc, lineWidth: 56 * scale, color: white)

    let needle = CGMutablePath()
    needle.move(to: CGPoint(x: 535 * scale, y: 504 * scale))
    needle.addLine(to: CGPoint(x: 648 * scale, y: 662 * scale))
    stroke(context, path: needle, lineWidth: 54 * scale, color: white)
}

private func drawStatusGlyph(in context: CGContext) {
    let black = cgColor(0x000000)
    let faded = cgColor(0x000000, alpha: 0.48)

    let lines: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (42, 36, 65, 36, 4.8),
        (45, 29, 62, 29, 3.8),
        (48, 22, 58, 22, 3.2)
    ]
    for (x1, y1, x2, y2, width) in lines {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        stroke(context, path: path, lineWidth: width, color: faded)
    }

    let arc = CGMutablePath()
    arc.addArc(center: CGPoint(x: 30, y: 36), radius: 22, startAngle: radians(88), endAngle: radians(330), clockwise: false)
    stroke(context, path: arc, lineWidth: 7.2, color: black)

    let needle = CGMutablePath()
    needle.move(to: CGPoint(x: 36, y: 35))
    needle.addLine(to: CGPoint(x: 47, y: 50))
    stroke(context, path: needle, lineWidth: 7.2, color: black)
}

private func drawGradientStroke(
    _ context: CGContext,
    path: CGPath,
    lineWidth: CGFloat,
    startColor: CGColor,
    endColor: CGColor,
    gradientStart: CGPoint,
    gradientEnd: CGPoint
) {
    context.saveGState()
    context.addPath(path)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [startColor, endColor] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
    context.restoreGState()
}

private func drawShadowedStroke(
    _ context: CGContext,
    path: CGPath,
    lineWidth: CGFloat,
    color: CGColor,
    blur: CGFloat,
    offset: CGSize
) {
    context.saveGState()
    context.setShadow(offset: offset, blur: blur, color: color)
    stroke(context, path: path, lineWidth: lineWidth, color: color)
    context.restoreGState()
}

private func stroke(_ context: CGContext, path: CGPath, lineWidth: CGFloat, color: CGColor) {
    context.saveGState()
    context.addPath(path)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.setStrokeColor(color)
    context.strokePath()
    context.restoreGState()
}

private func makeContext(width: Int, height: Int) -> CGContext? {
    CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

private func writePNG(from context: CGContext, to url: URL) throws {
    guard let image = context.makeImage() else {
        throw IconError.imageCreationFailed
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [.compressionFactor: 0.92]) else {
        throw IconError.pngEncodingFailed
    }
    try data.write(to: url, options: .atomic)
}

private func radians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180
}

private func cgColor(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

private enum IconError: Error {
    case contextCreationFailed
    case imageCreationFailed
    case pngEncodingFailed
}
