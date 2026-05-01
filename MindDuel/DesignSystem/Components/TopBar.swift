import SwiftUI

struct MDTopBar<Trailing: View>: View {
    let title: String
    var leadingAction: (() -> Void)?
    let trailing: Trailing

    init(
        title: String,
        leadingAction: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leadingAction = leadingAction
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let leadingAction {
                    Button(action: leadingAction) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.mdText2)
                    }
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, height: 44)

            Spacer()

            Text(title)
                .mdStyle(.subtitle)

            Spacer()

            trailing
                .frame(height: 44)
        }
        .padding(.horizontal, MDSpacing.md)
        .frame(height: 56)
        .background(Color.mdBg)
    }
}

extension MDTopBar where Trailing == Color {
    init(title: String, leadingAction: (() -> Void)? = nil) {
        self.init(title: title, leadingAction: leadingAction) { Color.clear }
    }
}
