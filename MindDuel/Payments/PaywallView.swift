import SwiftUI
import StoreKit

struct PaywallView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    @State private var selectedProduct: Product? = nil
    @State private var isRestoring = false

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "paywall_title"), leadingAction: { dismiss() }) {
                    EmptyView()
                }

                ScrollView {
                    VStack(spacing: MDSpacing.lg) {
                        heroSection
                        productList
                        footerButtons
                    }
                    .padding(.top, MDSpacing.lg)
                    .padding(.bottom, MDSpacing.xl)
                    .padding(.horizontal, MDSpacing.md)
                }
            }
        }
        .task { await store.loadProducts() }
        .alert(String(localized: "paywall_error_title"), isPresented: Binding(
            get: { store.purchaseError != nil },
            set: { if !$0 { store.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) { store.purchaseError = nil }
        } message: {
            Text(store.purchaseError ?? "")
        }
    }

    // MARK: – Hero

    private var heroSection: some View {
        VStack(spacing: MDSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.mdAccentSoft)
                    .frame(width: 72, height: 72)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.mdAccent)
            }

            Text(String(localized: "paywall_headline"))
                .mdStyle(.title)
                .foregroundStyle(Color.mdText)
                .multilineTextAlignment(.center)

            Text(String(localized: "paywall_subheadline"))
                .mdStyle(.body)
                .foregroundStyle(Color.mdText2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MDSpacing.md)
    }

    // MARK: – Products

    private var productList: some View {
        Group {
            if store.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MDSpacing.xl)
            } else {
                VStack(spacing: MDSpacing.sm) {
                    ForEach(store.products, id: \.id) { product in
                        ProductRow(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            onSelect: { selectedProduct = product }
                        )
                    }
                }
                purchaseButton
            }
        }
    }

    private var purchaseButton: some View {
        MDButton(
            .primary,
            title: selectedProduct.map { String(format: String(localized: "paywall_subscribe_action"), $0.displayPrice) }
                ?? String(localized: "paywall_select_plan")
        ) {
            guard let product = selectedProduct else { return }
            Task {
                do {
                    try await store.purchase(product, userId: userId)
                    dismiss()
                } catch {
                    store.purchaseError = error.localizedDescription
                }
            }
        }
        .disabled(selectedProduct == nil || store.isPurchasing)
        .overlay {
            if store.isPurchasing {
                ProgressView().tint(.white)
            }
        }
        .padding(.top, MDSpacing.xs)
    }

    // MARK: – Footer

    private var footerButtons: some View {
        VStack(spacing: MDSpacing.xs) {
            Button {
                isRestoring = true
                Task {
                    await store.restorePurchases()
                    isRestoring = false
                    dismiss()
                }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text(String(localized: "paywall_restore_action"))
                        .mdStyle(.caption)
                        .foregroundStyle(Color.mdText3)
                }
            }
            .buttonStyle(.plain)

            Text(String(localized: "paywall_terms_note"))
                .mdStyle(.micro)
                .foregroundStyle(Color.mdText3)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: – Product row

private struct ProductRow: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    private var badgeKey: String? {
        switch product.id {
        case StoreKitService.yearlyId:   return "paywall_badge_best_value"
        case StoreKitService.monthlyId:  return "paywall_badge_popular"
        default: return nil
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: MDSpacing.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.mdAccent : Color.mdBorder2, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(Color.mdAccent).frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: MDSpacing.xs) {
                        Text(product.displayName)
                            .mdStyle(.body)
                            .foregroundStyle(Color.mdText)
                        if let key = badgeKey {
                            MDPillTag(label: String(localized: String.LocalizationValue(key)), variant: .accent)
                        }
                    }
                    if let desc = product.description.nilIfEmpty {
                        Text(desc)
                            .mdStyle(.micro)
                            .foregroundStyle(Color.mdText3)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .mdStyle(.body)
                    .foregroundStyle(isSelected ? Color.mdAccent : Color.mdText2)
            }
            .padding(MDSpacing.md)
            .background(Color.mdSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.mdAccent : Color.mdBorder2, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
