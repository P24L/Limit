import SwiftUI

struct CompactLabelStyle: LabelStyle {
    let spacing: CGFloat

    init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == CompactLabelStyle {
    static func compact(spacing: CGFloat = 4) -> CompactLabelStyle {
        CompactLabelStyle(spacing: spacing)
    }
}
