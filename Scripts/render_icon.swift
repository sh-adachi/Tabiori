#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Recreate the app icon from code: swift Scripts/render_icon.swift [output.png]
let destination = CommandLine.arguments.dropFirst().first
    ?? "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = NSSize(width: 1024, height: 1024)
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let bounds = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.05, green: 0.35, blue: 0.36, alpha: 1).setFill()
bounds.fill()
NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.48, blue: 0.46, alpha: 1),
           ending: NSColor(calibratedRed: 0.025, green: 0.28, blue: 0.32, alpha: 1))!
    .draw(in: bounds, angle: -65)

func polygon(_ points: [NSPoint], color: NSColor) {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    color.setFill()
    path.fill()
}

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
shadow.shadowBlurRadius = 35
shadow.shadowOffset = NSSize(width: 0, height: -20)
shadow.set()
polygon([NSPoint(x: 188, y: 688), NSPoint(x: 401, y: 756), NSPoint(x: 619, y: 681),
         NSPoint(x: 836, y: 750), NSPoint(x: 836, y: 340), NSPoint(x: 619, y: 270),
         NSPoint(x: 401, y: 345), NSPoint(x: 188, y: 277)],
        color: NSColor(calibratedWhite: 0.98, alpha: 1))
NSGraphicsContext.restoreGraphicsState()

polygon([NSPoint(x: 401, y: 756), NSPoint(x: 619, y: 681), NSPoint(x: 619, y: 270), NSPoint(x: 401, y: 345)],
        color: NSColor(calibratedRed: 0.82, green: 0.91, blue: 0.85, alpha: 1))
polygon([NSPoint(x: 619, y: 681), NSPoint(x: 836, y: 750), NSPoint(x: 836, y: 340), NSPoint(x: 619, y: 270)],
        color: NSColor(calibratedRed: 0.92, green: 0.96, blue: 0.90, alpha: 1))

let route = NSBezierPath()
route.move(to: NSPoint(x: 270, y: 398))
route.curve(to: NSPoint(x: 492, y: 490), controlPoint1: NSPoint(x: 405, y: 387), controlPoint2: NSPoint(x: 364, y: 601))
route.curve(to: NSPoint(x: 721, y: 520), controlPoint1: NSPoint(x: 621, y: 380), controlPoint2: NSPoint(x: 617, y: 580))
route.lineWidth = 21
route.lineCapStyle = .round
route.lineJoinStyle = .round
let dashes: [CGFloat] = [11, 29]
route.setLineDash(dashes, count: dashes.count, phase: 0)
NSColor(calibratedRed: 0.11, green: 0.45, blue: 0.44, alpha: 1).setStroke()
route.stroke()

let start = NSBezierPath(ovalIn: NSRect(x: 248, y: 376, width: 44, height: 44))
NSColor(calibratedRed: 0.11, green: 0.45, blue: 0.44, alpha: 1).setFill()
start.fill()

let pin = NSBezierPath()
pin.move(to: NSPoint(x: 708, y: 509))
pin.curve(to: NSPoint(x: 599, y: 671), controlPoint1: NSPoint(x: 678, y: 562), controlPoint2: NSPoint(x: 599, y: 610))
pin.curve(to: NSPoint(x: 708, y: 780), controlPoint1: NSPoint(x: 599, y: 731), controlPoint2: NSPoint(x: 648, y: 780))
pin.curve(to: NSPoint(x: 817, y: 671), controlPoint1: NSPoint(x: 768, y: 780), controlPoint2: NSPoint(x: 817, y: 731))
pin.curve(to: NSPoint(x: 708, y: 509), controlPoint1: NSPoint(x: 817, y: 610), controlPoint2: NSPoint(x: 738, y: 562))
pin.close()
NSColor(calibratedRed: 0.93, green: 0.43, blue: 0.33, alpha: 1).setFill()
pin.fill()
NSColor(calibratedWhite: 1, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 670, y: 639, width: 76, height: 76)).fill()
NSGraphicsContext.restoreGraphicsState()

let output = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let writer = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(writer, context.makeImage()!, nil)
guard CGImageDestinationFinalize(writer) else { fatalError("PNG encoding failed") }
print("Wrote \(output.path)")
