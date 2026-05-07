import SwiftUI

struct ThinkQGlassSurface: ViewModifier {
    var material: Material = .regularMaterial
    var cornerRadius: CGFloat = 8
    var isInteractive = false

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func thinkQGlassSurface(
        _ material: Material = .regularMaterial,
        cornerRadius: CGFloat = 8,
        interactive: Bool = false
    ) -> some View {
        modifier(ThinkQGlassSurface(material: material, cornerRadius: cornerRadius, isInteractive: interactive))
    }
}
