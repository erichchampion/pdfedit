// A colour value in a colour space (spec Ch 10 §8.6.3).
//
// Pairs components with their space and converts to device RGB/Gray via the space's conversion.
// No MuPDF source was read or referenced.

public struct PDFColor: Sendable {
    public let space: PDFColorSpace
    public let components: [Double]

    public init(space: PDFColorSpace, components: [Double]) {
        self.space = space
        self.components = components
    }

    public func toDeviceRGB() -> RGB { space.toRGB(components) }

    /// Luminance approximation for device gray (§10.10).
    public func toDeviceGray() -> Double {
        let c = toDeviceRGB()
        return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
    }
}
