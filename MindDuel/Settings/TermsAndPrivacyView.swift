import SwiftUI

/// Terms of service & privacy text shown from Settings (#73). Copy is
/// in-app for now; before App Store submission this should link to a
/// hosted page with the legally reviewed version.
struct TermsAndPrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "settings_terms_label"),
                         leadingAction: { dismiss() }) { EmptyView() }
                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.md) {
                        section(title: "terms_section_terms_title",
                                body:  "terms_section_terms_body")
                        section(title: "terms_section_privacy_title",
                                body:  "terms_section_privacy_body")
                        section(title: "terms_section_data_title",
                                body:  "terms_section_data_body")
                        section(title: "terms_section_contact_title",
                                body:  "terms_section_contact_body")
                    }
                    .padding(MDSpacing.md)
                }
            }
        }
    }

    private func section(title: String.LocalizationValue, body: String.LocalizationValue) -> some View {
        VStack(alignment: .leading, spacing: MDSpacing.xs) {
            Text(String(localized: title))
                .mdStyle(.heading)
                .foregroundStyle(Color.mdText)
            Text(String(localized: body))
                .mdStyle(.body)
                .foregroundStyle(Color.mdText2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MDSpacing.md)
        .background(Color.mdSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
    }
}
