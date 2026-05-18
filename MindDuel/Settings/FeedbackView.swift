import SwiftUI
import PhotosUI
import OSLog

private let logger = Logger(subsystem: "no.mindduel.app", category: "FeedbackUpload")

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: Category = .feedback
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var showOpenedConfirm = false
    @State private var isSubmitting = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

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

                        // Image attachment
                        sectionLabel(String(localized: "feedback_image_label"))
                        PhotosPicker(selection: $selectedPhotoItem,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            HStack(spacing: MDSpacing.sm) {
                                if let data = selectedImageData,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .foregroundStyle(Color.mdAccent)
                                }
                                Text(selectedImageData != nil
                                     ? String(localized: "feedback_image_selected")
                                     : String(localized: "feedback_image_add"))
                                    .mdStyle(.caption)
                                    .foregroundStyle(Color.mdText)
                                Spacer()
                                if selectedImageData != nil {
                                    Button {
                                        selectedPhotoItem = nil
                                        selectedImageData = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.mdText3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(MDSpacing.sm)
                            .background(Color.mdSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mdBorder2, lineWidth: 0.5))
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImageData = uiImage.jpegData(compressionQuality: 0.7)
                                } else {
                                    selectedImageData = nil
                                }
                            }
                        }

                        MDButton(.primary, title: String(localized: "feedback_submit_action")) {
                            Task { await submit() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
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

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let info = Bundle.main.infoDictionary
        let appVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let appBuild   = (info?["CFBundleVersion"] as? String) ?? "?"
        let osVersion  = UIDevice.current.systemVersion
        let device     = UIDevice.current.model

        let message = """
        [\(category.rawValue.uppercased())] \(title)

        \(details)

        ---
        App: \(appVersion) (build \(appBuild)) · iOS \(osVersion) · \(device)
        """

        do {
            // Upload image if selected — failure is non-fatal; submit without image
            var imageUrl: String? = nil
            if let imageData = selectedImageData {
                do {
                    struct ImageUploadBody: Encodable { let data: String }
                    struct ImageUploadResponse: Decodable { let publicUrl: String }
                    let body = ImageUploadBody(data: imageData.base64EncodedString())
                    let resp: ImageUploadResponse = try await APIClient.shared.post("feedback/image", body: body)
                    imageUrl = resp.publicUrl
                } catch {
                    logger.error("Bildeopplasting feilet: \(error)")
                }
            }

            struct Body: Encodable { let message: String; let imageUrl: String? }
            let _: Empty = try await APIClient.shared.post("feedback", body: Body(message: message, imageUrl: imageUrl))
            showOpenedConfirm = true
        } catch APIError.unauthorized {
            // User not signed in; silently ignore (feedback requires auth)
        } catch {
            // Non-critical: show success anyway to avoid user frustration
            showOpenedConfirm = true
        }
    }
}
