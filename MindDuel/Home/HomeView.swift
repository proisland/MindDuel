import SwiftUI

struct HomeView: View {
    let username: String
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: "MindDuel") {
                    Button { authState.signOut() } label: {
                        Image(systemName: "person.circle")
                            .foregroundStyle(Color.mdText2)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        VStack(alignment: .leading, spacing: MDSpacing.xs) {
                            Text(String(localized: "welcome_greeting"))
                                .mdStyle(.caption)
                                .foregroundStyle(Color.mdText2)
                            Text(username)
                                .mdStyle(.title)
                        }
                        .padding(.horizontal, MDSpacing.lg)
                        .padding(.top, MDSpacing.xl)

                        MDPrimaryCard {
                            HStack(spacing: MDSpacing.md) {
                                MDPillTag(label: "π", variant: .accent)
                                VStack(alignment: .leading, spacing: MDSpacing.xs) {
                                    Text(String(localized: "mode_pi"))
                                        .mdStyle(.heading)
                                    Text(String(localized: "mode_pi_desc"))
                                        .mdStyle(.caption)
                                        .foregroundStyle(Color.mdText2)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, MDSpacing.lg)

                        MDPrimaryCard {
                            HStack(spacing: MDSpacing.md) {
                                MDPillTag(label: "∑", variant: .pink)
                                VStack(alignment: .leading, spacing: MDSpacing.xs) {
                                    Text(String(localized: "mode_math"))
                                        .mdStyle(.heading)
                                    Text(String(localized: "mode_math_desc"))
                                        .mdStyle(.caption)
                                        .foregroundStyle(Color.mdText2)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, MDSpacing.lg)
                    }
                }
            }
        }
    }
}
