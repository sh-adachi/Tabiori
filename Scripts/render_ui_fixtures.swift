import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Local documents used by the native Files and Photos picker UI tests.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func label(_ text: String, in context: CGContext, point: CGPoint, size: CGFloat) {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.12, alpha: 1)
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = point
    CTLineDraw(line, context)
}
let pdfURL = output.appendingPathComponent("Tabiori-Test-Ticket.pdf")
var mediaBox = CGRect(x: 0, y: 0, width: 600, height: 400)
let pdf = CGContext(pdfURL as CFURL, mediaBox: &mediaBox, nil)!
pdf.beginPDFPage(nil)
pdf.setFillColor(CGColor(red: 0.93, green: 0.97, blue: 0.96, alpha: 1))
pdf.fill(mediaBox)
label("TABIORI TEST TICKET", in: pdf, point: CGPoint(x: 40, y: 300), size: 30)
label("TOKYO  >  KYOTO", in: pdf, point: CGPoint(x: 40, y: 235), size: 24)
label("Fixture only - not valid for travel", in: pdf, point: CGPoint(x: 40, y: 100), size: 16)
pdf.endPDFPage()
pdf.closePDF()

let image = CGContext(data: nil, width: 900, height: 600, bitsPerComponent: 8, bytesPerRow: 900 * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
image.setFillColor(CGColor(red: 0.70, green: 0.88, blue: 0.85, alpha: 1))
image.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
label("TABIORI PHOTO FIXTURE", in: image, point: CGPoint(x: 50, y: 350), size: 40)
label("A real image imported through Photos", in: image, point: CGPoint(x: 50, y: 240), size: 24)
let writer = CGImageDestinationCreateWithURL(output.appendingPathComponent("Tabiori-Test-Photo.jpg") as CFURL,
                                            UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(writer, image.makeImage()!, nil)
guard CGImageDestinationFinalize(writer) else { fatalError("Could not write image fixture") }
print(output.path)
