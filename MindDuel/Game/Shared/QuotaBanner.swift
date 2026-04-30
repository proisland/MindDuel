import SwiftUI

struct QuotaBanner: View {
    let used: Int
    let total: Int

    var body: some View {
        HStack(spacing: MDSpacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mdAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "quota_warning_title"), used, total))
                    .mdStyle(.bodyMd)
                Text(String(localized: "quota_warning_subtitle"))
                    .mdStyle(.micro)
                    .foregroundStyle(Color.mdText3)
            }

            Spacer()

            MDButton(.primary, title: String(localized: "quota_upgrade_action")) { }
                .frame(width: 90)
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
        .background(Color.mdAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.mdAmber.opacity(0.3), lineWidth: 0.5)
        )
    }
}
