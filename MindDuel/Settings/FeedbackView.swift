import SwiftUI

/// #89: lets users submit task suggestions, general feedback, feature
/// requests and bug reports. Each submission opens a pre-filled GitHub
/// issue with the right label so the team can triage from existing tools.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: Category = .feedback
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var showOpenedConfirm = false

    enum Category: String, CaseIterable, Identifiable {
        case task, feedback, feature, bug
        var id: String { rawValue }

        var labelKey: String.LocalizationValue {
            switch self {
            case .task:     return "feedback_category_task"
            case .feedback: return "feedback_category_feedback"
            case .feature:  return "feedback_category_feature"
            case .bug:      return "feedback_category_bug"
            }
        }

        var icon: String {
            switch self {
            case .task:     return "list.bullet.rectangle"
            case .feedback: return "bubble.left.and.bubble.right"
            case .feature:  return "sparkles"
            case .bug:      return "ladybug.fill"
            }
        }

        /// GitHub issue label applied to the auto-opened issue.
        var ghLabel: String {
            switch self {
            case .task:     return "task-suggestion"
            case .feedback: return "feedback"
            case .feature:  return "feature"
            case .bug:      return "bug"
            }
        }

        var titleHintKey: String.LocalizationValue {
            switch self {
            case .task:     return "feedback_title_hint_task"
            case .feedback: return "feedback_title_hint_feedback"
            case .feature:  return "feedback_title_hint_feature"
            case .bug:      return "feedback_title_hint_bug"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "feedback_title"),
                         leadingAction: { dismiss() }) { EmptyView() }

                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        sectionLabel(String(localized: "feedback_category_label"))
                        VStack(spacing: MDSpacing.xs) {
                            ForEach(Category.allCases) { c in
                                categoryRow(c)
                            }
                        }

                        sectionLabel(String(localized: "feedback_title_label"))
                        TextField(String(localized: category.titleHintKey),
                                  text: $title)
                            .mdStyle(.bodyMd)
                            .foregroundStyle(Color.mdText)
                            .padding(MDSpacing.sm)
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))

                        sectionLabel(String(localized: "feedback_body_label"))
                        TextEditor(text: $details)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                            .padding(MDSpacing.sm)
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))

                        MDButton(.primary, title: String(localized: "feedback_submit_action")) {
                            submit()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(MDSpacing.md)
                }
            }
        }
        .alert(String(localized: "feedback_submitted_title"), isPresented: $showOpenedConfirm) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(String(localized: "feedback_submitted_message"))
        }
    }

    private func categoryRow(_ c: Category) -> some View {
        Button { category = c } label: {
            HStack(spacing: MDSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color.mdAccentSoft).frame(width: 26, height: 26)
                    Image(systemName: c.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.mdAccent)
                }
                Text(String(localized: c.labelKey))
                    .mdStyle(.caption)
                    .foregroundStyle(Color.mdText)
                Spacer()
                if category == c {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.mdAccent)
                } else {
                    Circle().stroke(Color.mdBorder2, lineWidth: 1).frame(width: 18, height: 18)
                }
            }
            .padding(MDSpacing.sm)
            .background(Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                category == c ? Color.mdAccent.opacity(0.5) : Color.mdBorder2,
                lineWidth: category == c ? 1 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).mdStyle(.micro).foregroundStyle(Color.mdText3)
    }

    private func submit() {
        let info = Bundle.main.infoDictionary
        let appVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let appBuild   = (info?["CFBundleVersion"] as? String) ?? "?"
        let osVersion  = UIDevice.current.systemVersion
        let device     = UIDevice.current.model

        let footer = """


        ---
        _Submitted via MindDuel iOS_
        - App: \(appVersion) (build \(appBuild))
        - OS: iOS \(osVersion)
        - Device: \(device)
        - Category: \(category.rawValue)
        """

        let fullBody = details + footer
        var components = URLComponents(string: "https://github.com/proisland/mindduel/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: fullBody),
            URLQueryItem(name: "labels", value: category.ghLabel),
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
        showOpenedConfirm = true
    }
}

