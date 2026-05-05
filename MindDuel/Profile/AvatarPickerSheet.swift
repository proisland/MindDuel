import SwiftUI
import PhotosUI

/// #71: lets the user pick a photo from their library as their avatar.
/// Saves to AvatarStore which is read by MDAvatar.
/// #117: emoji preset grid was removed because the iOS simulator/device
/// emoji font failed to render those glyphs, so the section was empty.
struct AvatarPickerSheet: View {
    @ObservedObject private var store = AvatarStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem? = nil

    var body: some View {
        ZStack {
            Color.mdBg.ignoresSafeArea()
            VStack(spacing: 0) {
                MDTopBar(title: String(localized: "avatar_picker_title"),
                         leadingAction: { dismiss() }) { EmptyView() }

                ScrollView {
                    VStack(alignment: .leading, spacing: MDSpacing.lg) {
                        VStack(spacing: MDSpacing.sm) {
                            MDAvatar(username: store.ownUsername ?? "?",
                                     size: .lg,
                                     customEmoji: store.emoji,
                                     customImageData: store.imageData)
                            Text(String(localized: "avatar_picker_preview_label"))
                                .mdStyle(.micro)
                                .foregroundStyle(Color.mdText3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, MDSpacing.md)

                        sectionLabel(String(localized: "avatar_picker_photo_section"))
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: MDSpacing.sm) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.mdAccent)
                                Text(String(localized: "avatar_picker_choose_photo"))
                                    .mdStyle(.bodyMd)
                                    .foregroundStyle(Color.mdText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.mdText3)
                            }
                            .padding(MDSpacing.md)
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdBorder2, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        if store.emoji != nil || store.imageData != nil {
                            MDButton(.danger, title: String(localized: "avatar_picker_reset")) {
                                store.emoji = nil
                                store.imageData = nil
                            }
                        }
                    }
                    .padding(MDSpacing.md)
                }
            }
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // Compress to keep stored avatar small.
                    let resized = compressed(data: data)
                    await MainActor.run {
                        store.emoji = nil
                        store.imageData = resized
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).mdStyle(.micro).foregroundStyle(Color.mdText3)
    }

    private func compressed(data: Data) -> Data {
        guard let img = UIImage(data: data) else { return data }
        let target: CGFloat = 256
        let scale = min(1, target / max(img.size.width, img.size.height))
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.7) ?? data
    }
}
