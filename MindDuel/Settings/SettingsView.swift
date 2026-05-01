import SwiftUI

struct SettingsView: View {
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode = "system"
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    @State private var showSignOutModal = false
    @State private var showLanguagePicker = false
    @State private var showLanguageRestartAlert = false
    @State private var debugTapCount = 0
    @State private var showDebugSection = false

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "settings_title"), leadingAction: { dismiss() }) {
                    EmptyView()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        settingsSection(String(localized: "settings_account_section")) {
                            toggleRow(
                                icon: "bell.fill", iconBg: .mdAccentSoft, iconColor: .mdAccent,
                                label: String(localized: "settings_notifications_label")
                            ) {
                                Toggle("", isOn: $notificationsEnabled)
                                    .tint(Color.mdAccent)
                                    .labelsHidden()
                                    .onChange(of: notificationsEnabled, perform: { val in
                                        UserDefaults.standard.set(val, forKey: "notificationsEnabled")
                                    })
                            }

                            Button { showLanguagePicker = true } label: {
                                staticRow(
                                    icon: "globe", iconBg: .mdAccentSoft, iconColor: .mdAccent,
                                    label: String(localized: "settings_language_label"),
                                    value: currentLanguageLabel
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        settingsSection(String(localized: "settings_subscription_section")) {
                            VStack(alignment: .leading, spacing: MDSpacing.sm) {
                                Text(String(localized: "settings_free_plan_label"))
                                    .mdStyle(.caption)
                                    .foregroundStyle(Color.mdText2)
                                MDButton(.primary, title: String(localized: "quota_upgrade_action")) { }
                            }
                            .padding(MDSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
                        }

                        settingsSection(String(localized: "settings_privacy_section")) {
                            chevronRow(
                                icon: "doc.text.fill", iconBg: .mdAccentSoft, iconColor: .mdAccent,
                                label: String(localized: "settings_terms_label")
                            )
                            destructiveRow(
                                icon: "trash.fill",
                                label: String(localized: "settings_delete_account_label")
                            )
                        }

                        MDButton(.danger, title: String(localized: "settings_signout_action")) {
                            showSignOutModal = true
                        }
                        .padding(.horizontal, MDSpacing.md)
                        .padding(.top, MDSpacing.xs)

                        if showDebugSection {
                            debugSection
                        }

                        Text("MindDuel M5")
                            .mdStyle(.micro)
                            .foregroundStyle(Color.mdText3.opacity(showDebugSection ? 0.6 : 0.2))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, MDSpacing.sm)
                            .onTapGesture {
                                debugTapCount += 1
                                if debugTapCount >= 5 { showDebugSection = true }
                            }
                    }
                    .padding(.top, MDSpacing.lg)
                    .padding(.bottom, MDSpacing.xl)
                }
            }

            if showSignOutModal {
                signOutModal
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSignOutModal)
        .animation(.easeInOut(duration: 0.2), value: showDebugSection)
        .confirmationDialog(
            String(localized: "settings_language_picker_title"),
            isPresented: $showLanguagePicker,
            titleVisibility: .visible
        ) {
            Button("Norsk") { setLanguage("nb") }
            Button("English") { setLanguage("en") }
        }
        .alert(
            String(localized: "settings_language_restart_title"),
            isPresented: $showLanguageRestartAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(String(localized: "settings_language_restart_message"))
        }
    }

    // MARK: – Language

    private var currentLanguageLabel: String {
        switch selectedLanguageCode {
        case "nb": return "Norsk"
        case "en": return "English"
        default:   return String(localized: "settings_language_system")
        }
    }

    private func setLanguage(_ code: String) {
        selectedLanguageCode = code
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        showLanguageRestartAlert = true
    }

    // MARK: – Debug section

    private var debugSection: some View {
        settingsSection(String(localized: "debug_section_title")) {
            Button {
                ProgressionStore.shared.resetDailyQuota()
            } label: {
                staticRow(
                    icon: "arrow.counterclockwise", iconBg: .mdAmberSoft, iconColor: .mdAmber,
                    label: String(localized: "debug_reset_quota_action"),
                    value: "0 / \(ProgressionStore.dailyQuota)"
                )
            }
            .buttonStyle(.plain)

            Button {
                SocialStore.shared.resetForTesting()
            } label: {
                staticRow(
                    icon: "person.2.fill", iconBg: .mdAmberSoft, iconColor: .mdAmber,
                    label: String(localized: "debug_reset_social_action"),
                    value: ""
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: – Section builder

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            Text(title)
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
                .padding(.horizontal, MDSpacing.md)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, MDSpacing.md)
        }
    }

    // MARK: – Row types

    private func toggleRow<T: View>(
        icon: String, iconBg: Color, iconColor: Color,
        label: String,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack(spacing: MDSpacing.sm) {
            iconBox(icon, bg: iconBg, color: iconColor)
            Text(label).mdStyle(.caption).foregroundStyle(Color.mdText)
            Spacer()
            trailing()
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        .padding(.bottom, 4)
    }

    private func staticRow(icon: String, iconBg: Color, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: MDSpacing.sm) {
            iconBox(icon, bg: iconBg, color: iconColor)
            Text(label).mdStyle(.caption).foregroundStyle(Color.mdText)
            Spacer()
            if !value.isEmpty {
                Text(value).mdStyle(.caption).foregroundStyle(Color.mdText3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mdText3)
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        .padding(.bottom, 4)
    }

    private func chevronRow(icon: String, iconBg: Color, iconColor: Color, label: String) -> some View {
        HStack(spacing: MDSpacing.sm) {
            iconBox(icon, bg: iconBg, color: iconColor)
            Text(label).mdStyle(.caption).foregroundStyle(Color.mdText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mdText3)
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
        .padding(.bottom, 4)
    }

    private func destructiveRow(icon: String, label: String) -> some View {
        HStack(spacing: MDSpacing.sm) {
            iconBox(icon, bg: .mdRedSoft, color: .mdRed)
            Text(label).mdStyle(.caption).foregroundStyle(Color.mdRed)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mdRed)
        }
        .padding(MDSpacing.sm)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }

    private func iconBox(_ name: String, bg: Color, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(bg).frame(width: 24, height: 24)
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: – Sign-out modal

    private var signOutModal: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture { showSignOutModal = false }

            VStack(spacing: MDSpacing.lg) {
                ZStack {
                    Circle().fill(Color.mdAmberSoft).frame(width: 64, height: 64)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.mdAmber)
                }

                VStack(spacing: MDSpacing.xs) {
                    Text(String(localized: "signout_title"))
                        .mdStyle(.heading)
                        .foregroundStyle(Color.mdText)
                    Text(String(localized: "signout_message"))
                        .mdStyle(.body)
                        .foregroundStyle(Color.mdText2)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: MDSpacing.xs) {
                    MDButton(.danger, title: String(localized: "settings_signout_action")) {
                        showSignOutModal = false
                        onSignOut()
                    }
                    MDButton(.ghost, title: String(localized: "continue_playing_action")) {
                        showSignOutModal = false
                    }
                }
            }
            .padding(MDSpacing.lg)
            .background(Color.mdSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mdBorder2, lineWidth: 0.5))
            .padding(.horizontal, MDSpacing.lg)
        }
    }
}
