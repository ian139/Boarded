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
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ShareDraft(attemptID: nil, caption: "", imageAlt: "", image: nil)
    @State private var picker: PhotosPickerItem?
    @State private var cropImage: UIImage?
    @State private var cropPresented = false
    @State private var progress = 0.0
    @State private var error: String?
    @State private var published = false
    @State private var pendingDraft: PendingSendDraft?
    @State private var sync: SessionSyncService?
    @State private var replacementAttemptID: UUID?
    @State private var replaceDraftPresented = false
    private var attempts: [PendingAttempt] {
        ActiveSessionStore.sendableAttempts(userID: session.userId, in: context)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.space24) {
                    if published { success } else { form }
                }
                .padding(AppLayout.screenMargin)
                .boardedContentWidth()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Share Send")
            .navigationBarTitleDisplayMode(.inline)
            .boardedPageBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            guard let userID = session.userId else { return }
            sync = AppServices.makeSessionSyncService(modelContext: context, userID: userID)
        }
        .onChange(of: picker) { _, value in
            Task {
                if let data = try? await value?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    cropImage = image
                    cropPresented = true
                }
            }
        }
        .confirmationDialog(
            "Replace saved draft?",
            isPresented: $replaceDraftPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive) {
                replaceDraft()
            }
            Button("Keep Draft", role: .cancel) {}
        } message: {
            Text("Your saved draft will be deleted before starting this share.")
        }
        .sheet(isPresented: $cropPresented) {
            if let cropImage {
                PhotoCropView(image: cropImage) { image in
                    draft = draft.replacing(image: image)
                    cropPresented = false
                }
            }
        }
    }

    private var form: some View {
        Group {
            BoardedEyebrow(text: "Achievement")
            if attempts.isEmpty {
                BoardedRouteLineEmptyState(
                    title: "Nothing ready to share",
                    message: "Log and sync a sent attempt first."
                )
            } else {
                Picker(
                    "Sent attempt",
                    selection: Binding(
                        get: { draft.attemptID },
                        set: { selectAttempt($0) }
                    )
                ) {
                    Text("Choose a send").tag(UUID?.none)
                    ForEach(attempts) {
                        Text("\($0.gradeLabel) — \($0.routeName)").tag(Optional($0.id))
                    }
                }
                .accessibilityIdentifier("share-attempt")
                Label("Public", systemImage: "globe")
                    .font(AppTypography.labelL)
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityLabel("Audience: Public")
                Text("Anyone can see this post.")
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textSecondary)
            }
            PhotosPicker(
                selection: $picker,
                matching: .images
            ) {
                Label(
                    draft.image == nil ? "Add Photo" : "Change Photo",
                    systemImage: "photo"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BoardedButtonStyle(.secondary))
            if let image = draft.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .clipShape(AppRadius.card())
            }
            BoardedTextEditor(
                label: "Caption",
                prompt: "A concise note about the send",
                text: Binding(
                    get: { draft.caption },
                    set: { draft = draft.replacing(caption: $0) }
                )
            )
            BoardedTextField(
                label: "Image description",
                prompt: "Describe the photo for screen readers",
                text: Binding(
                    get: { draft.imageAlt },
                    set: { draft = draft.replacing(imageAlt: $0) }
                ),
                error: draft.image != nil
                    && draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Image description is required."
                    : nil
            )
            preview
            if progress > 0 && progress < 1 {
                ProgressView(value: progress)
                    .tint(AppColor.accentDefault)
                    .accessibilityLabel("Publishing progress")
            }
            if let error {
                BoardedInlineError(message: error) { publish() }
            }
            BoardedPrimaryButton(
                title: error == nil ? "Publish" : "Retry",
                systemImage: "paperplane.fill"
            ) {
                publish()
            }
            .disabled(!valid)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            BoardedSectionHeading(title: "Preview")
            Label("Public", systemImage: "globe")
                .font(AppTypography.labelM)
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityLabel("Audience: Public")
            Text(attempts.first(where: { $0.id == draft.attemptID })?.gradeLabel ?? "Grade")
                .font(AppTypography.displayS)
            Text(draft.caption.isEmpty ? "Your caption" : draft.caption)
                .font(AppTypography.bodyM)
                .foregroundStyle(AppColor.textSecondary)
        }
        .boardedPanel()
    }

    private var success: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space24) {
            BoardedEyebrow(text: "Shared")
            Text("Your send is on the line.").font(AppTypography.displayS)
            BoardedRouteLine().frame(height: 160)
            BoardedPrimaryButton(title: "Done") { dismiss() }
        }
        .accessibilityIdentifier("share-success")
    }

    private var valid: Bool {
        draft.attemptID != nil
            && (draft.image == nil
                || !draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func publish() {
        guard valid, let id = draft.attemptID, let sync else { return }
        error = nil
        progress = 0.2

        Task {
            do {
                let data = try draft.image.map(SendImageProcessor.jpeg)
                progress = 0.6

                let pending: PendingSendDraft
                if let existing = pendingDraft?.attemptId == id
                    ? pendingDraft
                    : pendingDraft(for: id) {
                    pendingDraft = existing
                    pending = existing
                    pending.caption = draft.caption.trimmedOrNil
                    pending.imageAlt = draft.imageAlt.trimmedOrNil
                    if let data {
                        let fileName = pending.imageFileName ?? "\(pending.id.uuidString).jpg"
                        pending.imageFileName = fileName
                        try DraftImageStore.write(data, fileName: fileName)
                    }
                    pending.syncState = .queued
                    try context.save()
                } else {
                    let created = PendingSendDraft(
                        attemptId: id,
                        caption: draft.caption.trimmedOrNil,
                        imageFileName: data == nil ? nil : "\(UUID().uuidString).jpg",
                        imageAlt: draft.imageAlt.trimmedOrNil
                    )
                    try sync.enqueue(draft: created, imageData: data)
                    pendingDraft = created
                    pending = created
                }

                progress = 0.85
                await sync.replay()

                guard sync.state == .synced, !hasPendingDraft(id: pending.id) else {
                    error = sync.errorMessage
                        ?? "Your draft is saved. Retry to share it."
                    progress = 0
                    return
                }

                progress = 1
                published = true
            } catch {
                self.error = error.localizedDescription
                progress = 0
            }
        }
    }

    private func selectAttempt(_ id: UUID?) {
        if let existing = pendingDraft(for: id) {
            pendingDraft = existing
            draft = draftForPending(existing)
            return
        }
        guard id != draft.attemptID else { return }
        guard let existing = pendingDraft(for: draft.attemptID) ?? pendingDrafts().first else {
            draft = ShareDraft(attemptID: id, caption: "", imageAlt: "", image: nil)
            pendingDraft = nil
            return
        }
        replacementAttemptID = id
        pendingDraft = existing
        replaceDraftPresented = true
    }

    private func replaceDraft() {
        guard let existing = pendingDraft, let sync else { return }
        let id = replacementAttemptID
        Task {
            do {
                try await sync.delete(draft: existing)
                pendingDraft = nil
                draft = ShareDraft(attemptID: id, caption: "", imageAlt: "", image: nil)
                replacementAttemptID = nil
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func draftForPending(_ pending: PendingSendDraft) -> ShareDraft {
        let image = pending.imageFileName
            .flatMap { DraftImageStore.read(fileName: $0) }
            .flatMap { UIImage(data: $0) }
        return ShareDraft(
            attemptID: pending.attemptId,
            caption: pending.caption ?? "",
            imageAlt: pending.imageAlt ?? "",
            image: image
        )
    }

    private func pendingDraft(for attemptID: UUID?) -> PendingSendDraft? {
        guard let attemptID, session.userId != nil else { return nil }
        let owned = ActiveSessionStore.sendableAttempts(userID: session.userId, in: context)
        guard owned.contains(where: { $0.id == attemptID }) else { return nil }
        let descriptor = FetchDescriptor<PendingSendDraft>(
            predicate: #Predicate {
                $0.attemptId == attemptID && $0.syncStateRaw != "synced"
            }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func pendingDrafts() -> [PendingSendDraft] {
        guard session.userId != nil else { return [] }
        let owned = Set(ActiveSessionStore.sendableAttempts(userID: session.userId, in: context).map(\.id))
        let descriptor = FetchDescriptor<PendingSendDraft>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        return (try? context.fetch(descriptor))?.filter { owned.contains($0.attemptId) } ?? []
    }

    private func hasPendingDraft(id: UUID) -> Bool {
        let descriptor = FetchDescriptor<PendingSendDraft>(
            predicate: #Predicate { $0.id == id }
        )
        guard let drafts = try? context.fetch(descriptor) else { return true }
        return !drafts.isEmpty
    }
}

struct PhotoCropView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let completion: (UIImage) -> Void
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.space16) {
                GeometryReader { proxy in
                    ZStack {
                        AppColor.backgroundBase
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                DragGesture()
                                    .onChanged {
                                        offset = CGSize(
                                            width: dragStart.width + $0.translation.width,
                                            height: dragStart.height + $0.translation.height
                                        )
                                    }
                                    .onEnded { _ in dragStart = offset }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { scale = min(4, max(1, $0)) }
                            )
                            .accessibilityLabel("Photo crop")
                            .accessibilityValue("Zoom \(Int(scale * 100)) percent")
                            .accessibilityAdjustableAction { direction in
                                scale = min(4, max(1, scale + (direction == .increment ? 0.25 : -0.25)))
                            }
                            .accessibilityAction(named: "Move left") { moveCrop(x: -1, y: 0) }
                            .accessibilityAction(named: "Move right") { moveCrop(x: 1, y: 0) }
                            .accessibilityAction(named: "Move up") { moveCrop(x: 0, y: -1) }
                            .accessibilityAction(named: "Move down") { moveCrop(x: 0, y: 1) }
                            .accessibilityAction(named: "Reset crop") { reset() }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.width * 2 / 3)
                    .clipShape(AppRadius.card())
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .accessibilityIdentifier("photo-crop")

                ViewThatFits {
                    HStack(spacing: AppSpacing.space8) { cropControls }
                    VStack(spacing: AppSpacing.space8) { cropControls }
                }
                .padding(.horizontal, AppLayout.screenMargin)
            }
            .navigationTitle("Crop 3:2")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        completion(SendImageProcessor.crop(image, scale: scale, offset: offset))
                    }
                }
            }
            .boardedPageBackground()
        }
    }

    @ViewBuilder private var cropControls: some View {
        Button("Position left", systemImage: "arrow.left") { moveCrop(x: -1, y: 0) }
        Button("Position up", systemImage: "arrow.up") { moveCrop(x: 0, y: -1) }
        Button("Reset", systemImage: "arrow.counterclockwise") { reset() }
        Button("Position down", systemImage: "arrow.down") { moveCrop(x: 0, y: 1) }
        Button("Position right", systemImage: "arrow.right") { moveCrop(x: 1, y: 0) }
    }

    private func moveCrop(x: CGFloat, y: CGFloat) {
        offset.width += x * AppSpacing.space16
        offset.height += y * AppSpacing.space16
        dragStart = offset
    }

    private func reset() {
        scale = 1
        offset = .zero
        dragStart = .zero
    }
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
