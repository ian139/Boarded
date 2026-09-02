import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct SessionArtworkAttempt: Equatable, Identifiable {
    let number: Int
    let outcome: AttemptOutcome
    var id: Int { number }
}

struct SessionArtworkModel: Equatable {
    let venue: String
    let duration: TimeInterval
    let attemptCount: Int
    let sendCount: Int
    let featuredRoute: String
    let featuredGrade: String
    let outcome: AttemptOutcome
    let featuredAttemptNumber: Int
    let overlayStyle: OverlayStyle
    var attemptOutcomes: [SessionArtworkAttempt] = []
}

struct SessionArtworkView: View {
    enum Presentation { case screen, export }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let image: Image
    let imageAlt: String
    let model: SessionArtworkModel
    var presentation: Presentation = .screen
    var forcesOpaqueContinuation = false

    private var usesContinuation: Bool {
        (presentation == .screen && dynamicTypeSize.isAccessibilitySize) || forcesOpaqueContinuation
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                image.resizable().scaledToFill()
                    .aspectRatio(usesContinuation ? 3.2 : 3.0 / 2.0, contentMode: .fit)
                    .clipped()
                    .accessibilityLabel(imageAlt)
                if !usesContinuation {
                    LinearGradient(
                        colors: [.clear, AppColor.backgroundBase.opacity(presentation == .export ? 0.88 : 0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    ).accessibilityHidden(true)
                    SessionArtworkFacts(
                        model: model,
                        usesMaterial: presentation == .screen,
                        compactLayout: presentation == .export
                    )
                }
                if presentation == .export {
                    LinearGradient(
                        colors: [AppColor.scrimTop, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityHidden(true)
                    Text("Boarded")
                        .font(AppTypography.titleM)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(AppSpacing.space16)
                        .accessibilityHidden(true)
                }
            }
            if usesContinuation { SessionArtworkFacts(model: model, opaque: true) }
        }
        .background(AppColor.backgroundBase)
        .clipShape(AppRadius.card())
        .overlay { AppRadius.card().stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
        .accessibilityElement(children: .contain)
    }
}

struct CanonicalSessionArtworkPreview: View {
    let image: UIImage
    let imageAlt: String
    let model: SessionArtworkModel

    var body: some View {
        Color.clear
            .aspectRatio(402.0 / 268.0, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    let scale = proxy.size.width / 402
                    SessionArtworkView(
                        image: Image(uiImage: image),
                        imageAlt: imageAlt,
                        model: model,
                        presentation: .export
                    )
                    .environment(\.dynamicTypeSize, .large)
                    .frame(width: 402, height: 268)
                    .scaleEffect(scale, anchor: .topLeading)
                }
            }
            .clipped()
            .accessibilityIdentifier("canonical-session-artwork-preview")
    }
}

struct SessionArtworkFacts: View {
    let model: SessionArtworkModel
    var opaque = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var usesMaterial = true
    var compactLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: compactLayout ? AppSpacing.space4 : AppSpacing.space12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.venue).font(AppTypography.titleM).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.space8)
                Label(model.outcome.title, systemImage: model.outcome.systemImage)
                    .font(AppTypography.labelM)
                    .foregroundStyle(model.outcome == .sent ? AppColor.accentDefault : AppColor.textPrimary)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                featuredRoute
            }
            if model.overlayStyle == .attemptTimeline {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AppSpacing.space8) {
                            timelineItems
                        }
                    } else if usesCompactTimeline {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(
                                    .flexible(),
                                    spacing: AppSpacing.space4,
                                    alignment: .center
                                ),
                                count: AppLayout.attemptTimelineCompactColumns
                            ),
                            alignment: .leading,
                            spacing: AppSpacing.space4
                        ) {
                            compactTimelineItems
                        }
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(minimum: AppLayout.attemptTimelineColumnMinWidth),
                                    alignment: .leading
                                )
                            ],
                            alignment: .leading,
                            spacing: AppSpacing.space8
                        ) {
                            timelineItems
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(timelineSummary)
                .accessibilityIdentifier("session-attempt-timeline")
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.space8) { facts }
            } else {
                HStack(spacing: AppSpacing.space16) { facts }
            }
            if dynamicTypeSize.isAccessibilitySize {
                featuredRoute
            }
        }
        .foregroundStyle(AppColor.textPrimary)
        .padding(compactLayout ? AppSpacing.space8 : AppSpacing.space16)
        .background(opaque ? AppColor.surfaceCard : Color.clear)
        .modifier(SessionArtworkShelfMaterial(enabled: !opaque && usesMaterial))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(opaque ? "session-facts-continuation" : "session-facts-overlay")
    }
    private var featuredRoute: some View {
        Text("\(model.featuredGrade) · \(model.featuredRoute)")
            .font(AppTypography.labelL)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("session-featured-route")
    }

    private var timelineAttempts: [SessionArtworkAttempt] {
        if !model.attemptOutcomes.isEmpty {
            return model.attemptOutcomes.sorted { $0.number < $1.number }
        }
        return [SessionArtworkAttempt(number: model.featuredAttemptNumber, outcome: model.outcome)]
    }

    private var usesCompactTimeline: Bool {
        timelineAttempts.count > AppLayout.attemptTimelineCompactThreshold
    }

    @ViewBuilder private var timelineItems: some View {
        ForEach(timelineAttempts) { attempt in
            Label(
                "\(attempt.number) \(attempt.outcome.title)",
                systemImage: attempt.outcome.systemImage
            )
            .font(AppTypography.caption)
            .foregroundStyle(attempt.outcome == .sent ? AppColor.accentDefault : AppColor.textPrimary)
            .accessibilityLabel("Attempt \(attempt.number), \(attempt.outcome.title)")
        }
    }

    @ViewBuilder private var compactTimelineItems: some View {
        ForEach(timelineAttempts) { attempt in
            Image(systemName: attempt.outcome.systemImage)
                .font(AppTypography.caption)
                .foregroundStyle(attempt.outcome == .sent ? AppColor.accentDefault : AppColor.textPrimary)
                .accessibilityLabel("Attempt \(attempt.number), \(attempt.outcome.title)")
        }
    }

    private var timelineSummary: String {
        timelineAttempts.map { "Attempt \($0.number), \($0.outcome.title)" }.joined(separator: "; ")
    }

    @ViewBuilder private var facts: some View {
        Label(BoardedFormat.duration(model.duration), systemImage: "clock")
            .accessibilityLabel(BoardedFormat.duration(model.duration))
            .accessibilityIdentifier("session-duration")
        Label("\(model.attemptCount) attempts", systemImage: "number")
            .accessibilityIdentifier("session-attempt-count")
        Label("\(model.sendCount) sends", systemImage: "checkmark.circle")
            .accessibilityIdentifier("session-result-sends")
    }
}

private struct SessionArtworkShelfMaterial: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.boardedMaterial(.sessionFactShelf, in: AppRadius.card()) } else { content }
    }
}

struct ShareDraft: Equatable {
    var sessionID: UUID?
    var featuredAttemptID: UUID?
    var caption = ""
    var imageAlt = ""
    var overlayStyle = OverlayStyle.stats
    var image: UIImage?
}

struct ShareComposerPresentation: Equatable {
    enum RecoveryAction: Equatable {
        case retryPublication
        case retryDiscard
    }

    let showsEditingControls: Bool
    let showsSavedPublication: Bool
    let recoveryAction: RecoveryAction

    init(publicationStartedAt: Date?, discardPending: Bool = false) {
        showsEditingControls = publicationStartedAt == nil
        showsSavedPublication = publicationStartedAt != nil
        recoveryAction = discardPending ? .retryDiscard : .retryPublication
    }
}

struct ShareDiscardRecoveryState: Equatable {
    let draftStillPending: Bool
    var shouldResetComposer: Bool { !draftStillPending }
    var showsPublishedSuccess: Bool { false }
}

struct ShareSendComposer: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var discardStartedDraftPresented = false
    @State private var discardPending = false
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


    init(initialSessionID: UUID? = nil, featuredAttemptID: UUID? = nil, image: UIImage? = nil, imageAlt: String = "") {
        _draft = State(initialValue: ShareDraft(sessionID: initialSessionID, featuredAttemptID: featuredAttemptID, imageAlt: imageAlt, image: image))
    }
    private var sessions: [PendingSession] { ActiveSessionStore.completedSessions(userID: session.userId, in: context) }
    private var attempts: [PendingAttempt] {
        guard let id = draft.sessionID else { return [] }
        return ActiveSessionStore.attempts(sessionID: id, userID: session.userId, in: context)
    }
    private var selectedSession: PendingSession? { sessions.first { $0.id == draft.sessionID } }
    private var selectedAttempt: PendingAttempt? { attempts.first { $0.id == draft.featuredAttemptID } }
    private var artworkModel: SessionArtworkModel? {
        guard let selectedSession, let selectedAttempt else { return nil }
        return SessionArtworkModel(
            venue: selectedSession.venueName,
            duration: (selectedSession.endedAt ?? selectedSession.startedAt).timeIntervalSince(selectedSession.startedAt),
            attemptCount: attempts.count,
            sendCount: attempts.filter { $0.outcome == .sent }.count,
            featuredRoute: selectedAttempt.routeName,
            featuredGrade: selectedAttempt.gradeLabel,
            outcome: selectedAttempt.outcome,
            featuredAttemptNumber: selectedAttempt.attemptNumber,
            overlayStyle: draft.overlayStyle,
            attemptOutcomes: attempts.map { SessionArtworkAttempt(number: $0.attemptNumber, outcome: $0.outcome) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.space24) {
                    published ? AnyView(success) : AnyView(form)
                }
                .padding(AppLayout.screenMargin)
                .boardedContentWidth()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Share session")
            .navigationBarTitleDisplayMode(.inline)
            .boardedPageBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            if let userID = session.userId {
                sync = AppServices.makeSessionSyncService(modelContext: context, userID: userID)
                restoreDraft()
                seedFixtureIfNeeded()
            }
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
            Button("Discard Draft", role: .destructive) { replaceDraft() }
            Button("Keep Draft", role: .cancel) {}
        } message: {
            Text("Your saved session draft will be deleted before starting another.")
        }
        .confirmationDialog(
            "Discard saved publication?",
            isPresented: $discardStartedDraftPresented,
            titleVisibility: .visible
        ) {
            Button("Discard and Share New", role: .destructive) {
                discardStartedDraft()
            }
            Button("Keep Saved Publication", role: .cancel) {}
        } message: {
            Text("This removes the saved publication and its photo. You can start a new share only after cleanup succeeds.")
        }
        .sheet(isPresented: $cropPresented) {
            if let cropImage {
                PhotoCropView(image: cropImage) {
                    draft.image = $0
                    draft.imageAlt = ""
                    cropPresented = false
                }
            }
        }
    }

    private var form: some View {
        Group {
            BoardedEyebrow(text: "Completed Session")
            if presentation.showsSavedPublication {
                savedPublicationForm
            } else if presentation.showsEditingControls {
                VStack(alignment: .leading, spacing: AppSpacing.space24) {
                    editablePublicationForm
                }
            }
        }
    }

    @ViewBuilder private var editablePublicationForm: some View {
        if sessions.isEmpty {
            BoardedEmptyState(
                title: "No completed session yet",
                message: "End a session before adding it to your journal."
            )
        } else {
            Picker(
                "Completed session",
                selection: Binding(get: { draft.sessionID }, set: selectSession)
            ) {
                Text("Choose a session").tag(UUID?.none)
                ForEach(sessions) { item in
                    Text("\(item.venueName) · \(BoardedFormat.relative(item.endedAt ?? item.startedAt))")
                        .tag(Optional(item.id))
                }
            }
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize
                    ? AppLayout.accessibilitySelectionMinHeight
                    : AppLayout.minimumTarget
            )
            .accessibilityIdentifier("share-session")
        }
        if draft.sessionID != nil {
            Picker("Featured attempt", selection: $draft.featuredAttemptID) {
                Text("Choose an attempt").tag(UUID?.none)
                ForEach(attempts) { attempt in
                    Text("#\(attempt.attemptNumber) · \(attempt.gradeLabel) \(attempt.routeName) · \(attempt.outcome.title)")
                        .tag(Optional(attempt.id))
                }
            }
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize
                    ? AppLayout.accessibilitySelectionMinHeight
                    : AppLayout.minimumTarget
            )
            .accessibilityIdentifier("share-featured-attempt")
            Picker("Overlay", selection: $draft.overlayStyle) {
                Text("Session stats").tag(OverlayStyle.stats)
                Text("Attempt timeline").tag(OverlayStyle.attemptTimeline)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("share-overlay")
        }
        PhotosPicker(selection: $picker, matching: .images) {
            Label(
                draft.image == nil ? "Add required photo" : "Change photo",
                systemImage: "photo"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BoardedButtonStyle(.secondary))
        .accessibilityIdentifier("share-photo")
        if dynamicTypeSize.isAccessibilitySize {
            Label("Scroll for photo details and final preview", systemImage: "chevron.down")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityIdentifier("share-scroll-affordance")
        }
        selectedPhoto
        BoardedTextField(
            label: "Photo description",
            prompt: "Describe the photo for screen readers",
            text: $draft.imageAlt,
            error: draft.image != nil && draft.imageAlt.trimmedOrNil == nil
                ? "Photo description is required."
                : nil
        )
        BoardedTextEditor(
            label: "Caption (optional)",
            prompt: "A note about this session",
            text: $draft.caption
        )
        preview
        publishingProgress
        if let error {
            BoardedInlineError(message: error) { publish() }
        }
        BoardedPrimaryButton(
            title: error == nil ? "Publish session" : "Retry publishing",
            systemImage: "paperplane.fill"
        ) {
            publish()
        }
        .disabled(!valid)
        .accessibilityIdentifier("publish-session")
    }

    private var savedPublicationForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space16) {
            VStack(alignment: .leading, spacing: AppSpacing.space8) {
                Text("Saved publication")
                    .font(AppTypography.titleM)
                savedFact("Session", selectedSession?.venueName ?? "Saved session")
                if let selectedAttempt {
                    savedFact(
                        "Featured attempt",
                        "#\(selectedAttempt.attemptNumber) · \(selectedAttempt.gradeLabel) \(selectedAttempt.routeName) · \(selectedAttempt.outcome.title)"
                    )
                }
                savedFact(
                    "Artwork",
                    draft.overlayStyle == .attemptTimeline ? "Attempt timeline" : "Session stats"
                )
                savedFact("Photo description", draft.imageAlt)
                savedFact("Caption", draft.caption.trimmedOrNil ?? "No caption")
            }
            .boardedPanel()
            .accessibilityIdentifier("saved-publication-fields")
            selectedPhoto
            preview
            publishingProgress
            publicationRecovery
        }
    }

    private func savedFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textTertiary)
            Text(value)
                .font(AppTypography.bodyM)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var selectedPhoto: some View {
        if let image = draft.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .aspectRatio(3 / 2, contentMode: .fit)
                .clipShape(AppRadius.card())
                .accessibilityLabel(
                    draft.imageAlt.isEmpty ? "Selected climbing photo" : draft.imageAlt
                )
        }
    }

    @ViewBuilder private var publishingProgress: some View {
        if progress > 0 && progress < 1 {
            ProgressView(value: progress)
                .tint(AppColor.accentDefault)
                .accessibilityLabel("Publishing progress")
        }
    }

    private var presentation: ShareComposerPresentation {
        ShareComposerPresentation(
            publicationStartedAt: pendingDraft?.publicationStartedAt,
            discardPending: discardRecoveryPending
        )
    }

    private var publicationStarted: Bool {
        pendingDraft?.publicationStartedAt != nil
    }

    private var publicationRecovery: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            Text(discardRecoveryPending ? "Discard is waiting to finish" : "Publishing was interrupted")
                .font(AppTypography.titleM)
            Text(
                discardRecoveryPending
                    ? "Your saved publication is protected while cleanup finishes. Retry discard before sharing a new one."
                    : "Your session and photo are saved. Retry publishing, or discard this saved publication before sharing a new one."
            )
            .font(AppTypography.bodyM)
            .foregroundStyle(AppColor.textSecondary)
            if let error {
                Text(error)
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.danger)
            }
            BoardedPrimaryButton(
                title: discardRecoveryPending ? "Retry discard" : "Retry publishing",
                systemImage: "arrow.clockwise"
            ) {
                if presentation.recoveryAction == .retryDiscard {
                    discardStartedDraft()
                } else {
                    publish()
                }
            }
            if !discardRecoveryPending {
                Button("Discard and Share New", role: .destructive) {
                    discardStartedDraftPresented = true
                }
                .accessibilityHint("Requires confirmation and preserves the saved publication until cleanup succeeds")
            }
        }
        .boardedPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("publication-recovery")
    }

    @ViewBuilder private var previewArtwork: some View {
        if let image = draft.image, let artworkModel {
            if dynamicTypeSize.isAccessibilitySize {
                SessionArtworkView(
                    image: Image(uiImage: image),
                    imageAlt: draft.imageAlt,
                    model: artworkModel,
                    presentation: .screen,
                    forcesOpaqueContinuation: true
                )
            } else {
                CanonicalSessionArtworkPreview(
                    image: image,
                    imageAlt: draft.imageAlt,
                    model: artworkModel
                )
            }
        } else {
            Text("Add a photo and featured attempt to complete the preview.")
                .font(AppTypography.bodyM).foregroundStyle(AppColor.textSecondary)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Final preview", subtitle: "The uploaded journal image uses this exact composition.")
            previewArtwork
        }.boardedPanel().accessibilityIdentifier("session-preview")
    }

    private var success: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space24) {
            BoardedEyebrow(text: "Shared")
            Text("Your session is in the journal.").font(AppTypography.displayS)
            Label("Published", systemImage: "checkmark.circle.fill")
                .font(AppTypography.labelL)
                .foregroundStyle(AppColor.accentDefault)
            BoardedPrimaryButton(title: "Done") { dismiss() }
        }.accessibilityIdentifier("share-success")
    }

    private var valid: Bool { draft.sessionID != nil && draft.featuredAttemptID != nil && draft.image != nil && draft.imageAlt.trimmedOrNil != nil && artworkModel != nil }

    private func publish() {
        if discardRecoveryPending {
            discardStartedDraft()
            return
        }
        if let existing = pendingDraft, existing.publicationStartedAt != nil {
            retryStartedPublication(existing)
            return
        }
        guard valid, let sessionID = draft.sessionID, let attemptID = draft.featuredAttemptID, let image = draft.image, let artworkModel, let sync else { return }
        error = nil; progress = 0.2
        Task { @MainActor in
            do {
                let data = try SendImageProcessor.artworkJPEG(
                    image: image,
                    imageAlt: draft.imageAlt,
                    model: artworkModel
                )
                let sourceData = try SendImageProcessor.sourceJPEG(image)
                progress = 0.55
                let pending: PendingSessionDraft
                if let existing = pendingDraft ?? pendingDraft(for: sessionID) {
                    existing.featuredAttemptId = attemptID
                    existing.caption = draft.caption.trimmedOrNil
                    existing.imageAlt = draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines)
                    existing.overlayStyle = draft.overlayStyle
                    existing.syncState = .queued
                    try sync.replaceDraftMedia(draft: existing, imageData: data, sourceData: sourceData)
                    pending = existing
                } else {
                    let created = PendingSessionDraft(sessionId: sessionID, featuredAttemptId: attemptID, caption: draft.caption.trimmedOrNil, imageFileName: "\(UUID().uuidString).jpg", imageAlt: draft.imageAlt.trimmingCharacters(in: .whitespacesAndNewlines), overlayStyle: draft.overlayStyle)
                    try sync.enqueue(draft: created, imageData: data, sourceData: sourceData)
                    pendingDraft = created; pending = created
                }
                progress = 0.8; await sync.replay()
                guard sync.state == .synced, !hasPendingDraft(id: pending.id) else { error = sync.errorMessage ?? "Your session draft is saved. Retry when connected."; progress = 0; return }
                progress = 1; published = true
            } catch { self.error = error.localizedDescription; progress = 0 }
        }
    }

    private func retryStartedPublication(_ existing: PendingSessionDraft) {
        guard let sync else { return }
        error = nil
        progress = 0.8
        Task { @MainActor in
            await sync.replay()
            if hasPendingDraftDeletion(id: existing.id) {
                discardPending = true
                discardStartedDraft()
                return
            }
            guard sync.state == .synced, !hasPendingDraft(id: existing.id) else {
                error = sync.errorMessage ?? "Your session and photo are saved. Retry when connected."
                progress = 0
                return
            }
            progress = 1
            published = true
        }
    }

    private var discardRecoveryPending: Bool {
        discardPending || pendingDraft.map { hasPendingDraftDeletion(id: $0.id) } == true
    }

    private func discardStartedDraft() {
        guard let existing = pendingDraft, let sync else { return }
        discardPending = true
        error = nil
        Task { @MainActor in
            let recovery = ShareDiscardRecoveryState(
                draftStillPending: hasPendingDraft(id: existing.id)
            )
            guard !recovery.shouldResetComposer else {
                resetAfterDiscard(existing)
                return
            }
            do {
                try await sync.delete(draft: existing)
                resetAfterDiscard(existing)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func resetAfterDiscard(_ existing: PendingSessionDraft) {
        pendingDraft = nil
        draft = ShareDraft(sessionID: existing.sessionId)
        discardPending = false
        published = false
        error = nil
        progress = 0
        seedFixtureIfNeeded()
    }

    private func hasPendingDraftDeletion(id: UUID) -> Bool {
        let descriptor = FetchDescriptor<PendingDraftDeletion>(
            predicate: #Predicate { $0.id == id }
        )
        return ((try? context.fetch(descriptor)) ?? []).isEmpty == false
    }


    private func selectSession(_ id: UUID?) {
        if let existing = id.flatMap(pendingDraft(for:)) { pendingDraft = existing; draft = draftForPending(existing); return }
        guard id != draft.sessionID else { return }
        if let existing = pendingDraft ?? pendingDrafts().first { replacementSessionID = id; pendingDraft = existing; replaceDraftPresented = true }
        else { draft = ShareDraft(sessionID: id) }
    }

    private func replaceDraft() {
        guard let existing = pendingDraft, let sync else { return }; let id = replacementSessionID
        Task {
            do {
                try await sync.delete(draft: existing)
                pendingDraft = nil; draft = ShareDraft(sessionID: id); replacementSessionID = nil; error = nil
            } catch { self.error = error.localizedDescription }
        }
    }

    private func restoreDraft() {
        if let sessionID = draft.sessionID, let existing = pendingDraft(for: sessionID) {
            pendingDraft = existing; draft = draftForPending(existing); return
        }
        guard draft.sessionID == nil, let existing = pendingDrafts().first else { return }
        pendingDraft = existing; draft = draftForPending(existing)
    }
    private func seedFixtureIfNeeded() {
        guard AppLaunchConfiguration.isUITestFixture, draft.image == nil else { return }
        draft.image = UITestFixtures.sessionImage
        draft.imageAlt = UITestFixtures.sessionImageAlt
        if draft.featuredAttemptID == nil { draft.featuredAttemptID = attempts.first?.id }
    }
    private func sourceFileName(for pending: PendingSessionDraft) -> String { "\(pending.imageFileName).source" }
    private func draftForPending(_ pending: PendingSessionDraft) -> ShareDraft {
        let sourceImage = DraftImageStore.read(fileName: sourceFileName(for: pending)).flatMap(UIImage.init(data:))
        return ShareDraft(sessionID: pending.sessionId, featuredAttemptID: pending.featuredAttemptId, caption: pending.caption ?? "", imageAlt: pending.imageAlt, overlayStyle: pending.overlayStyle, image: sourceImage)
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
    @MainActor static func artworkJPEG(
        image: UIImage,
        imageAlt: String,
        model: SessionArtworkModel
    ) throws -> Data {
        let content = SessionArtworkView(
            image: Image(uiImage: image),
            imageAlt: imageAlt,
            model: model,
            presentation: .export
        )
        .environment(\.dynamicTypeSize, .large)
        .frame(width: 402, height: 268)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2048.0 / 402.0
        guard let flattened = renderer.uiImage,
              let data = flattened.jpegData(compressionQuality: 0.82)
        else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
    static func sourceJPEG(_ image: UIImage) throws -> Data {
        let longest = max(image.size.width, image.size.height)
        let ratio = min(1, 2048 / longest)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.92) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}

private extension String { var trimmedOrNil: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
