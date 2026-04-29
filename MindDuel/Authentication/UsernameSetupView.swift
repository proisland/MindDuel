import SwiftUI

struct UsernameSetupView: View {
    let userID: String
    @EnvironmentObject private var authState: AuthState
    @State private var username = ""

    private var hasValidLength: Bool {
        (3...20).contains(username.count)
    }

    private var hasValidChars: Bool {
        guard !username.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return username.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private var isAvailable: Bool {
        // M2+: backend uniqueness check. For now, always green when other rules pass.
        hasValidLength && hasValidChars
    }

    private var isValid: Bool {
        hasValidLength && hasValidChars && isAvailable
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                content
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("MindDuel")
                .mdStyle(.heading)
            Spacer()
            Button { } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.mdText2)
                    .frame(width: 36, height: 36)
                    .background(Color.mdSurface2)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, MDSpacing.md)
        .frame(height: 56)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: MDSpacing.lg) {
                avatarPlaceholder
                    .padding(.top, MDSpacing.lg)

                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "choose_your_tag"))
                        .mdStyle(.display)
                    Text(String(localized: "tag_subtitle"))
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                }

                MDPrimaryCard {
                    VStack(spacing: MDSpacing.md) {
                        inputField
                        validationRules
                        MDButton(.primary, title: String(localized: "continue_action")) {
                            authState.setUsername(username, userID: userID)
                        }
                        .disabled(!isValid)
                        .padding(.top, MDSpacing.xs)
                    }
                }
                .padding(.horizontal, MDSpacing.lg)
            }
            .padding(.bottom, MDSpacing.xl)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.mdSurface2)
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.mdText3)
            )
            .overlay(
                Circle().stroke(Color.mdBorder2, lineWidth: 1)
            )
    }

    private var inputField: some View {
        HStack(spacing: MDSpacing.sm) {
            Text("@")
                .mdStyle(.title2)
                .foregroundStyle(Color.mdText3)

            TextField("", text: $username, prompt: Text(String(localized: "username_placeholder"))
                .foregroundColor(Color.mdText3))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color.mdText)

            if isValid {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.mdGreen)
            }
        }
        .padding(.horizontal, MDSpacing.md)
        .frame(height: 44)
        .background(Color.mdSurface2)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isValid ? Color.mdGreen : Color.mdBorder2, lineWidth: 1)
        )
    }

    private var validationRules: some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            ValidationRow(label: String(localized: "rule_length"), passing: hasValidLength)
            ValidationRow(label: String(localized: "rule_chars"), passing: hasValidChars)
            ValidationRow(label: String(localized: "rule_available"), passing: isAvailable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ValidationRow: View {
    let label: String
    let passing: Bool

    var body: some View {
        HStack(spacing: MDSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(passing ? Color.mdGreen : Color.mdText4)
                .frame(width: 16)
            Text(label)
                .mdStyle(.body)
                .foregroundStyle(passing ? Color.mdText2 : Color.mdText3)
        }
    }
}
