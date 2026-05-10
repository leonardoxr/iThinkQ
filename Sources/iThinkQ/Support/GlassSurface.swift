import SwiftUI

struct IThinkQGlassSurface: ViewModifier {
    var material: Material = .regularMaterial
    var cornerRadius: CGFloat = 8
    var isInteractive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
                .contentShape(shape)
        } else {
            content
                .background(material, in: shape)
                .overlay {
                    shape
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }
                .contentShape(shape)
        }
#else
        content
            .background(material, in: shape)
            .overlay {
                shape
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
            .contentShape(shape)
#endif
    }
}

extension View {
    func thinkQGlassSurface(
        _ material: Material = .regularMaterial,
        cornerRadius: CGFloat = 8,
        interactive: Bool = false
    ) -> some View {
        modifier(IThinkQGlassSurface(material: material, cornerRadius: cornerRadius, isInteractive: interactive))
    }
}
