import SwiftUI

struct UsernameSetupView: View {
    let userID: String
    @EnvironmentObject private var authState: AuthState
    @State private var username = ""

    private var isValid: Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return (3...20).contains(username.count)
            && username.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "choose_username"))

                VStack(alignment: .leading, spacing: MDSpacing.sm) {
                    Text(String(localized: "username_hint"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)

                    TextField(String(localized: "username_placeholder"), text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(MDSpacing.md)
                        .background(Color.mdSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.mdBorder2, lineWidth: 1)
                        )
                        .foregroundStyle(Color.mdText)
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.top, MDSpacing.xl)

                Spacer()

                MDButton(.primary, title: String(localized: "continue_action")) {
                    authState.setUsername(username, userID: userID)
                }
                .disabled(!isValid)
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }
}
