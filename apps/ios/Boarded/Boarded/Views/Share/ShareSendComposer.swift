import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct ShareDraft: Equatable {
    let attemptID: UUID?
    let caption: String
    let imageAlt: String
    let image: UIImage?
    func replacing(attemptID: UUID? = nil, caption: String? = nil, imageAlt: String? = nil, image: UIImage?? = nil) -> Self {
        Self(attemptID: attemptID ?? self.attemptID, caption: caption ?? self.caption, imageAlt: imageAlt ?? self.imageAlt, image: image ?? self.image)
    }
}

struct ShareSendComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ShareDraft(attemptID: nil, caption: "", imageAlt: "", image: nil)
    @State private var picker: PhotosPickerItem?
    @State private var cropImage: UIImage?
    @State private var cropPresented = false
    @State private var progress = 0.0
    @State private var error: String?
    @State private var published = false
    @State private var sync: SessionSyncService?
    private var attempts: [PendingAttempt] { ActiveSessionStore.sendableAttempts(in: context) }

    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: AppSpacing.space24) {
            if published { success } else { form }
        }.padding(AppLayout.screenMargin).boardedContentWidth().frame(maxWidth: .infinity) }.navigationTitle("Share Send").navigationBarTitleDisplayMode(.inline).boardedPageBackground().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } } }
        .task { sync = AppServices.makeSessionSyncService(modelContext: context) }
        .onChange(of: picker) { _, value in Task { if let data = try? await value?.loadTransferable(type: Data.self), let image = UIImage(data: data) { cropImage = image; cropPresented = true } } }
        .sheet(isPresented: $cropPresented) { if let cropImage { PhotoCropView(image: cropImage) { image in draft = draft.replacing(image: image); cropPresented = false } } }
    }

    private var form: some View {
        Group {
            BoardedEyebrow(text: "Achievement")
            if attempts.isEmpty { BoardedRouteLineEmptyState(title: "Nothing ready to share", message: "Log and sync a sent attempt first.") }
            else { Picker("Sent attempt", selection: Binding(get: { draft.attemptID }, set: { draft = draft.replacing(attemptID: $0) })) { Text("Choose a send").tag(UUID?.none); ForEach(attempts) { Text("\($0.gradeLabel) — \($0.routeName)").tag(Optional($0.id)) } }.accessibilityIdentifier("share-attempt") }
            PhotosPicker(selection: $picker, matching: .images) { Label(draft.image == nil ? "Add Photo" : "Change Photo", systemImage: "photo").frame(maxWidth: .infinity) }.buttonStyle(BoardedButtonStyle(.secondary))
            if let image = draft.image { Image(uiImage: image).resizable().scaledToFill().aspectRatio(3/2, contentMode: .fit).clipShape(AppRadius.card()) }
            BoardedTextEditor(label: "Caption", prompt: "A concise note about the send", text: Binding(get: { draft.caption }, set: { draft = draft.replacing(caption: $0) }))
            BoardedTextField(label: "Image description", prompt: "Describe the photo for screen readers", text: Binding(get: { draft.imageAlt }, set: { draft = draft.replacing(imageAlt: $0) }), error: draft.image != nil && draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Image description is required." : nil)
            preview
            if progress > 0 && progress < 1 { ProgressView(value: progress).tint(AppColor.accentDefault).accessibilityLabel("Publishing progress") }
            if let error { BoardedInlineError(message: error) { publish() } }
            BoardedPrimaryButton(title: error == nil ? "Publish" : "Retry", systemImage: "paperplane.fill") { publish() }.disabled(!valid)
        }
    }
    private var preview: some View { VStack(alignment: .leading, spacing: AppSpacing.space8) { BoardedSectionHeading(title: "Preview"); Text(attempts.first(where: { $0.id == draft.attemptID })?.gradeLabel ?? "Grade").font(AppTypography.displayS); Text(draft.caption.isEmpty ? "Your caption" : draft.caption).font(AppTypography.bodyM).foregroundStyle(AppColor.textSecondary) }.boardedPanel() }
    private var success: some View { VStack(alignment: .leading, spacing: AppSpacing.space24) { BoardedEyebrow(text: "Shared"); Text("Your send is on the line.").font(AppTypography.displayS); BoardedRouteLine().frame(height: 160); BoardedPrimaryButton(title: "Done") { dismiss() } }.accessibilityIdentifier("share-success") }
    private var valid: Bool { draft.attemptID != nil && (draft.image == nil || !draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    private func publish() {
        guard valid, let id = draft.attemptID, let sync else { return }; error = nil; progress = 0.2
        Task { do { let data = try draft.image.map(SendImageProcessor.jpeg); progress = 0.6; let pending = PendingSendDraft(attemptId: id, caption: draft.caption.trimmedOrNil, imageFileName: data == nil ? nil : "\(UUID().uuidString).jpg", imageAlt: draft.imageAlt.trimmedOrNil); try sync.enqueue(draft: pending, imageData: data); progress = 0.85; await sync.replay(); progress = 1; published = true } catch { self.error = error.localizedDescription; progress = 0 } }
    }
}

struct PhotoCropView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage; let completion: (UIImage) -> Void
    @State private var scale: CGFloat = 1; @State private var offset: CGSize = .zero
    var body: some View { NavigationStack { GeometryReader { proxy in ZStack { AppColor.backgroundBase; Image(uiImage: image).resizable().scaledToFill().scaleEffect(scale).offset(offset).gesture(DragGesture().onChanged { offset = $0.translation }).simultaneousGesture(MagnificationGesture().onChanged { scale = max(1, $0) }) }.frame(width: proxy.size.width, height: proxy.size.width * 2/3).clipShape(AppRadius.card()).position(x: proxy.size.width/2, y: proxy.size.height/2) }.navigationTitle("Crop 3:2").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Use Photo") { completion(SendImageProcessor.crop(image, scale: scale, offset: offset)) } } }.boardedPageBackground() } }
}

enum SendImageProcessor {
    static func crop(_ image: UIImage, scale: CGFloat, offset: CGSize) -> UIImage {
        guard let source = image.cgImage else { return image }
        let width = CGFloat(source.width)
        let height = CGFloat(source.height)
        let baseWidth = min(width, height * 1.5)
        let baseHeight = baseWidth / 1.5
        let cropWidth = baseWidth / max(1, scale)
        let cropHeight = baseHeight / max(1, scale)
        let travelX = max(0, width - cropWidth)
        let travelY = max(0, height - cropHeight)
        let centerX = width / 2 - offset.width / 300 * travelX
        let centerY = height / 2 - offset.height / 300 * travelY
        let originX = min(max(0, centerX - cropWidth / 2), width - cropWidth)
        let originY = min(max(0, centerY - cropHeight / 2), height - cropHeight)
        guard let cropped = source.cropping(to: CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
    static func jpeg(_ image: UIImage) throws -> Data {
        let longest = max(image.size.width, image.size.height); let ratio = min(1, 2048 / longest); let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = rendered.jpegData(compressionQuality: 0.82) else { throw CocoaError(.fileWriteUnknown) }; return data
    }
}

private extension String { var trimmedOrNil: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
