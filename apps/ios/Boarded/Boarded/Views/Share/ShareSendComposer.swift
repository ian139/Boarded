import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct ShareDraft: Equatable {
    var sessionID: UUID?
    var featuredAttemptID: UUID?
    var caption = ""
    var imageAlt = ""
    var overlayStyle = OverlayStyle.stats
    var image: UIImage?
}

struct ShareSendComposer: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ShareDraft()
    @State private var picker: PhotosPickerItem?
    @State private var cropImage: UIImage?
    @State private var cropPresented = false
    @State private var progress = 0.0
    @State private var error: String?
    @State private var published = false
    @State private var pendingDraft: PendingSessionDraft?
    @State private var sync: SessionSyncService?
    @State private var replacementSessionID: UUID?
    @State private var replaceDraftPresented = false


    init(initialSessionID: UUID? = nil) {
        _draft = State(initialValue: ShareDraft(sessionID: initialSessionID))
    }
    private var sessions: [PendingSession] { ActiveSessionStore.completedSessions(userID: session.userId, in: context) }
    private var attempts: [PendingAttempt] {
        guard let id = draft.sessionID else { return [] }
        return ActiveSessionStore.attempts(sessionID: id, userID: session.userId, in: context)
    }
    private var selectedSession: PendingSession? { sessions.first { $0.id == draft.sessionID } }
    private var selectedAttempt: PendingAttempt? { attempts.first { $0.id == draft.featuredAttemptID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.space24) { published ? AnyView(success) : AnyView(form) }
                    .padding(AppLayout.screenMargin).boardedContentWidth().frame(maxWidth: .infinity)
            }
            .navigationTitle("Share session")
            .navigationBarTitleDisplayMode(.inline)
            .boardedPageBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .task { if let userID = session.userId { sync = AppServices.makeSessionSyncService(modelContext: context, userID: userID); restoreNewestDraft() } }
        .onChange(of: picker) { _, value in
            Task { if let data = try? await value?.loadTransferable(type: Data.self), let image = UIImage(data: data) { cropImage = image; cropPresented = true } }
        }
        .confirmationDialog("Replace saved draft?", isPresented: $replaceDraftPresented, titleVisibility: .visible) {
            Button("Discard Draft", role: .destructive) { replaceDraft() }
            Button("Keep Draft", role: .cancel) {}
        } message: { Text("Your saved session draft will be deleted before starting another.") }
        .sheet(isPresented: $cropPresented) {
            if let cropImage { PhotoCropView(image: cropImage) { draft.image = $0; cropPresented = false } }
        }
    }

    private var form: some View {
        Group {
            BoardedEyebrow(text: "Completed Session")
            if sessions.isEmpty {
                BoardedRouteLineEmptyState(title: "No completed session yet", message: "End a session before adding it to your journal.")
            } else {
                Picker("Completed session", selection: Binding(get: { draft.sessionID }, set: selectSession)) {
                    Text("Choose a session").tag(UUID?.none)
                    ForEach(sessions) { item in Text("\(item.venueName) · \(BoardedFormat.relative(item.endedAt ?? item.startedAt))").tag(Optional(item.id)) }
                }.accessibilityIdentifier("share-session")
            }
            if draft.sessionID != nil {
                Picker("Featured attempt", selection: $draft.featuredAttemptID) {
                    Text("Choose an attempt").tag(UUID?.none)
                    ForEach(attempts) { attempt in
                        Text("#\(attempt.attemptNumber) · \(attempt.gradeLabel) \(attempt.routeName) · \(attempt.outcome.title)").tag(Optional(attempt.id))
                    }
                }.accessibilityIdentifier("share-featured-attempt")
                Picker("Overlay", selection: $draft.overlayStyle) {
                    Text("Session stats").tag(OverlayStyle.stats)
                    Text("Attempt timeline").tag(OverlayStyle.attemptTimeline)
                }.pickerStyle(.segmented).accessibilityIdentifier("share-overlay")
            }
            PhotosPicker(selection: $picker, matching: .images) {
                Label(draft.image == nil ? "Add required photo" : "Change photo", systemImage: "photo").frame(maxWidth: .infinity)
            }.buttonStyle(BoardedButtonStyle(.secondary)).accessibilityIdentifier("share-photo")
            if let image = draft.image { Image(uiImage: image).resizable().scaledToFill().aspectRatio(3 / 2, contentMode: .fit).clipShape(AppRadius.card()).accessibilityLabel(draft.imageAlt.isEmpty ? "Selected climbing photo" : draft.imageAlt) }
            BoardedTextField(label: "Photo description", prompt: "Describe the photo for screen readers", text: $draft.imageAlt, error: draft.image != nil && draft.imageAlt.trimmedOrNil == nil ? "Photo description is required." : nil)
            BoardedTextEditor(label: "Caption (optional)", prompt: "A note about this session", text: $draft.caption)
            preview
            if progress > 0 && progress < 1 { ProgressView(value: progress).tint(AppColor.accentDefault).accessibilityLabel("Publishing progress") }
            if let error { BoardedInlineError(message: error) { publish() } }
            BoardedPrimaryButton(title: error == nil ? "Publish session" : "Retry publishing", systemImage: "paperplane.fill") { publish() }
                .disabled(!valid).accessibilityIdentifier("publish-session")
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Final preview", subtitle: "This is the session entry your crew will see.")
            if let image = draft.image {
                ZStack(alignment: .bottom) {
                    Image(uiImage: image).resizable().scaledToFill().aspectRatio(3 / 2, contentMode: .fit).clipped()
                    LinearGradient(colors: [.clear, AppColor.backgroundBase.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: AppSpacing.space8) {
                        Text(selectedSession?.venueName ?? "Venue").font(AppTypography.titleM)
                        if let attempt = selectedAttempt { Text("\(attempt.gradeLabel) · \(attempt.routeName) · \(attempt.outcome.title)").font(AppTypography.labelL) }
                        Text("\(attempts.count) attempts · \(attempts.filter { $0.outcome == .sent }.count) sends").font(AppTypography.caption)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(AppSpacing.space16)
                }.clipShape(AppRadius.card())
            } else { Text("Add a photo to complete the preview.").font(AppTypography.bodyM).foregroundStyle(AppColor.textSecondary) }
        }.boardedPanel().accessibilityIdentifier("session-preview")
    }

    private var success: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space24) {
            BoardedEyebrow(text: "Shared")
            Text("Your session is in the journal.").font(AppTypography.displayS)
            BoardedRouteLine().frame(height: 160)
            BoardedPrimaryButton(title: "Done") { dismiss() }
        }.accessibilityIdentifier("share-success")
    }

    private var valid: Bool { draft.sessionID != nil && draft.featuredAttemptID != nil && draft.image != nil && draft.imageAlt.trimmedOrNil != nil }

    private func publish() {
        guard valid, let sessionID = draft.sessionID, let attemptID = draft.featuredAttemptID, let image = draft.image, let sync else { return }
        error = nil; progress = 0.2
        Task {
            do {
                let data = try SendImageProcessor.jpeg(image); progress = 0.55
                let pending: PendingSessionDraft
                if let existing = pendingDraft ?? pendingDraft(for: sessionID) {
                    pending = existing
                    pending.featuredAttemptId = attemptID; pending.caption = draft.caption.trimmedOrNil; pending.imageAlt = draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines); pending.overlayStyle = draft.overlayStyle; pending.syncState = .queued
                    try DraftImageStore.write(data, fileName: pending.imageFileName); try context.save()
                } else {
                    let created = PendingSessionDraft(sessionId: sessionID, featuredAttemptId: attemptID, caption: draft.caption.trimmedOrNil, imageFileName: "\(UUID().uuidString).jpg", imageAlt: draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines), overlayStyle: draft.overlayStyle)
                    try sync.enqueue(draft: created, imageData: data); pendingDraft = created; pending = created
                }
                progress = 0.8; await sync.replay()
                guard sync.state == .synced, !hasPendingDraft(id: pending.id) else { error = sync.errorMessage ?? "Your session draft is saved. Retry when connected."; progress = 0; return }
                progress = 1; published = true
            } catch { self.error = error.localizedDescription; progress = 0 }
        }
    }

    private func selectSession(_ id: UUID?) {
        if let existing = id.flatMap(pendingDraft(for:)) { pendingDraft = existing; draft = draftForPending(existing); return }
        guard id != draft.sessionID else { return }
        if let existing = pendingDraft ?? pendingDrafts().first { replacementSessionID = id; pendingDraft = existing; replaceDraftPresented = true }
        else { draft = ShareDraft(sessionID: id) }
    }

    private func replaceDraft() {
        guard let existing = pendingDraft, let sync else { return }; let id = replacementSessionID
        Task { do { try await sync.delete(draft: existing); pendingDraft = nil; draft = ShareDraft(sessionID: id); replacementSessionID = nil; error = nil } catch { self.error = error.localizedDescription } }
    }

    private func restoreNewestDraft() { guard draft.sessionID == nil else { return }; if let existing = pendingDrafts().first { pendingDraft = existing; draft = draftForPending(existing) } }
    private func draftForPending(_ pending: PendingSessionDraft) -> ShareDraft {
        ShareDraft(sessionID: pending.sessionId, featuredAttemptID: pending.featuredAttemptId, caption: pending.caption ?? "", imageAlt: pending.imageAlt, overlayStyle: pending.overlayStyle, image: DraftImageStore.read(fileName: pending.imageFileName).flatMap(UIImage.init(data:)))
    }
    private func pendingDraft(for sessionID: UUID) -> PendingSessionDraft? { pendingDrafts().first { $0.sessionId == sessionID } }
    private func pendingDrafts() -> [PendingSessionDraft] {
        let owned = Set(sessions.map(\.id)); let descriptor = FetchDescriptor<PendingSessionDraft>(predicate: #Predicate { $0.syncStateRaw != "synced" }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor))?.filter { owned.contains($0.sessionId) } ?? []
    }
    private func hasPendingDraft(id: UUID) -> Bool { let descriptor = FetchDescriptor<PendingSessionDraft>(predicate: #Predicate { $0.id == id }); return (try? context.fetch(descriptor))?.isEmpty == false }
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
                        Image(uiImage: image).resizable().scaledToFill().scaleEffect(scale).offset(offset)
                            .gesture(DragGesture().onChanged { offset = CGSize(width: dragStart.width + $0.translation.width, height: dragStart.height + $0.translation.height) }.onEnded { _ in dragStart = offset })
                            .accessibilityLabel("Photo crop").accessibilityValue("Zoom \(Int(scale * 100)) percent")
                            .accessibilityAdjustableAction { scale = min(4, max(1, scale + ($0 == .increment ? 0.25 : -0.25))) }
                    }.frame(width: proxy.size.width, height: proxy.size.width * 2 / 3).clipShape(AppRadius.card()).position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }.accessibilityIdentifier("photo-crop")
                ViewThatFits { HStack(spacing: AppSpacing.space8) { cropControls }; VStack(spacing: AppSpacing.space8) { cropControls } }.padding(.horizontal, AppLayout.screenMargin)
            }.navigationTitle("Crop 3:2").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Use Photo") { completion(SendImageProcessor.crop(image, scale: scale, offset: offset)) } } }.boardedPageBackground()
        }
    }
    @ViewBuilder private var cropControls: some View {
        Button("Position left", systemImage: "arrow.left") { move(x: -1, y: 0) }; Button("Position up", systemImage: "arrow.up") { move(x: 0, y: -1) }; Button("Reset", systemImage: "arrow.counterclockwise") { scale = 1; offset = .zero; dragStart = .zero }; Button("Position down", systemImage: "arrow.down") { move(x: 0, y: 1) }; Button("Position right", systemImage: "arrow.right") { move(x: 1, y: 0) }
    }
    private func move(x: CGFloat, y: CGFloat) { offset.width += x * AppSpacing.space16; offset.height += y * AppSpacing.space16; dragStart = offset }
}

enum SendImageProcessor {
    static func crop(_ image: UIImage, scale: CGFloat, offset: CGSize) -> UIImage {
        guard let source = image.cgImage else { return image }; let width = CGFloat(source.width); let height = CGFloat(source.height); let baseWidth = min(width, height * 1.5); let baseHeight = baseWidth / 1.5; let cropWidth = baseWidth / max(1, scale); let cropHeight = baseHeight / max(1, scale); let travelX = max(0, width - cropWidth); let travelY = max(0, height - cropHeight); let centerX = width / 2 - offset.width / 300 * travelX; let centerY = height / 2 - offset.height / 300 * travelY; let originX = min(max(0, centerX - cropWidth / 2), width - cropWidth); let originY = min(max(0, centerY - cropHeight / 2), height - cropHeight); guard let cropped = source.cropping(to: CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)) else { return image }; return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
    static func jpeg(_ image: UIImage) throws -> Data { let longest = max(image.size.width, image.size.height); let ratio = min(1, 2048 / longest); let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio); let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.preferredRange = .standard; let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }; guard let data = rendered.jpegData(compressionQuality: 0.82) else { throw CocoaError(.fileWriteUnknown) }; return data }
}

private extension String { var trimmedOrNil: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
