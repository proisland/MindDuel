import SwiftUI

struct MDPrimaryCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(MDSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.mdBorder2, lineWidth: 0.5)
            )
    }
}

struct MDSecondaryCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(MDSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.mdBorder2, lineWidth: 0.5)
            )
    }
}
