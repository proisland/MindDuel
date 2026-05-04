import SwiftUI

struct QuotaBanner: View {
    let used: Int
    let total: Int

    var body: some View {
        HStack(spacing: MDSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.78, green: 0.39, blue: 0).opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.mdAmber)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "quota_warning_title"), used, total))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.mdText)
                Text(String(localized: "quota_warning_subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.39).opacity(0.7))
            }

            Spacer()

            MDButton(.primary, title: String(localized: "quota_upgrade_action")) { }
                .frame(width: 100)
        }
        .padding(.horizontal, MDSpacing.md)
        .padding(.vertical, MDSpacing.sm)
        .background(
            LinearGradient(
                colors: [Color(red: 0.24, green: 0.10, blue: 0),
                         Color(red: 0.36, green: 0.16, blue: 0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.78, green: 0.39, blue: 0).opacity(0.35), lineWidth: 1)
        )
    }
}
