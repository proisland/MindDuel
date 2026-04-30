import SwiftUI

enum MDButtonVariant {
    case primary
    case ghost
    case danger
}

struct MDButton: View {
    let variant: MDButtonVariant
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(_ variant: MDButtonVariant, title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.variant = variant
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(labelColor)
                } else {
                    Text(title)
                        .mdStyle(.bodyMd)
                        .foregroundStyle(labelColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: variant == .ghost ? 1 : 0)
            )
        }
        .disabled(isLoading)
        .opacity(isEnabled ? 1.0 : 0.4)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: return .mdAccentDeep
        case .ghost:   return .clear
        case .danger:  return .mdRedSoft
        }
    }

    private var labelColor: Color {
        switch variant {
        case .primary: return .mdText
        case .ghost:   return .mdText2
        case .danger:  return .mdRed
        }
    }

    private var borderColor: Color {
        variant == .ghost ? .mdBorder2 : .clear
    }
}
