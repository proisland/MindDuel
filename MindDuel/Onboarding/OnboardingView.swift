import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void

    @State private var page = 0

    private let pages: [(symbol: String, color: Color, titleKey: String, bodyKey: String)] = [
        ("gamecontroller.fill",    .mdAccent, "onboarding_page1_title", "onboarding_page1_body"),
        ("heart.fill",             .mdRed,    "onboarding_page2_title", "onboarding_page2_body"),
        ("chart.bar.fill",         .mdGreen,  "onboarding_page3_title", "onboarding_page3_body"),
        ("person.2.fill",          .mdPink,   "onboarding_page4_title", "onboarding_page4_body"),
    ]

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { onDone() } label: {
                        Text(String(localized: "onboarding_skip_action"))
                            .mdStyle(.caption)
                            .foregroundStyle(Color.mdText3)
                            .padding(.horizontal, MDSpacing.md)
                            .padding(.vertical, MDSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, MDSpacing.sm)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: page)

                pageIndicator
                    .padding(.bottom, MDSpacing.md)

                MDButton(.primary, title: page < pages.count - 1
                    ? String(localized: "onboarding_next_action")
                    : String(localized: "onboarding_done_action")
                ) {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onDone()
                    }
                }
                .padding(.horizontal, MDSpacing.lg)
                .padding(.bottom, MDSpacing.xl)
            }
        }
    }

    private func pageView(_ p: (symbol: String, color: Color, titleKey: String, bodyKey: String)) -> some View {
        VStack(spacing: MDSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(p.color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: p.symbol)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(p.color)
            }

            VStack(spacing: MDSpacing.sm) {
                Text(String(localized: String.LocalizationValue(p.titleKey)))
                    .mdStyle(.title)
                    .foregroundStyle(Color.mdText)
                    .multilineTextAlignment(.center)

                Text(String(localized: String.LocalizationValue(p.bodyKey)))
                    .mdStyle(.body)
                    .foregroundStyle(Color.mdText2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, MDSpacing.lg)

            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.mdAccent : Color.mdText3.opacity(0.3))
                    .frame(width: i == page ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
            }
        }
    }
}
