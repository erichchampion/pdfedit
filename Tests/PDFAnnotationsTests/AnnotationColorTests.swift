// AnnotationColor conversion tests (spec §12.5.2 / §10.x). The CMYK case delegates to the
// colour-space conversion. Self-authored; no MuPDF.

import Testing
import PDFColor
@testable import PDFAnnotations

@Test func annotationColorCMYKMatchesColorSpace() async throws {
    let cmyk = AnnotationColor.cmyk(0.2, 0.4, 0.6, 0.1)
    #expect(cmyk.rgb == PDFColorSpace.deviceCMYK.toRGB([0.2, 0.4, 0.6, 0.1]))
    #expect(AnnotationColor.gray(0.5).rgb == RGB(0.5, 0.5, 0.5))
    #expect(AnnotationColor.rgb(RGB(0.1, 0.2, 0.3)).rgb == RGB(0.1, 0.2, 0.3))
}
