import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct LogTabView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.modelContext) private var context
    @State private var logger: SessionLoggerViewModel?
    @State private var sync: SessionSyncService?
    var body: some View {
        Group {
            if let userID = session.userId {
                if let logger, let sync {
                    LogHomeView(logger: logger, syncService: sync)
                } else {
                    ProgressView()
                }
            } else {
                AuthenticationView(showsDismissButton: false)
            }
        }
        .navigationTitle("Log")
        .boardedPageBackground()
        .onChange(of: session.userId) { _, userID in
            // A logger and its sync service are account-bound. Tear both down
            // before constructing a graph for a different account (or nil).
            logger = nil
            sync = nil
            if let userID {
                configure(userID)
            }
        }
        .task(id: session.userId) {
            guard let userID = session.userId, logger == nil || sync == nil else {
                return
            }
            configure(userID)
        }
    }

    private func configure(_ id: UUID) {
        let service = AppServices.makeSessionSyncService(modelContext: context, userID: id)
        sync = service
        logger = SessionLoggerViewModel(modelContext: context, syncService: service, userId: id)
    }
}

struct LogHomeView: View {
    @ObservedObject var logger: SessionLoggerViewModel
    @ObservedObject var syncService: SessionSyncService
    @State private var venue = ""
    @State private var active = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: AppLayout.sectionGap) {
            BoardedSyncBanner(isOffline: !syncService.isOnline, state: syncService.state) { Task { await logger.retrySync() } }
            if logger.isActive { activeCard } else { startCard }
            BoardedSectionHeading(title: "Session history", subtitle: "Newest sessions appear first after sync.")
        }.padding(AppLayout.screenMargin).boardedContentWidth().frame(maxWidth: .infinity) }
        .navigationDestination(isPresented: $active) { ActiveSessionView(logger: logger, syncService: syncService) }
    }
    private var startCard: some View { VStack(alignment: .leading, spacing: AppSpacing.space16) { BoardedEyebrow(text: "New Session"); Text("Start where you are").font(AppTypography.displayS); BoardedTextField(label: "Venue", prompt: "Gym or crag", text: $venue); BoardedPrimaryButton(title: "Start Session", systemImage: "play.fill") { logger.startSession(venueName: venue); active = true }.disabled(venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("start-session") }.boardedPanel(padding: AppLayout.featureCardPadding) }
    private var activeCard: some View { VStack(alignment: .leading, spacing: AppSpacing.space16) { BoardedEyebrow(text: "Active Session"); Text(logger.activeSession?.venueName ?? "Session").font(AppTypography.titleM); Text("Attempts remain safely on this device until synced.").font(AppTypography.bodyM).foregroundStyle(AppColor.textSecondary); BoardedPrimaryButton(title: "Resume Logging", systemImage: "arrow.right") { active = true }.accessibilityIdentifier("resume-session") }.boardedPanel(padding: AppLayout.featureCardPadding) }
}

struct ActiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var logger: SessionLoggerViewModel
    @ObservedObject var syncService: SessionSyncService
    @State private var outcomeSheet = false
    @State private var result: SessionSummary?
    @State private var confirmEnd = false
    @ViewBuilder var body: some View {
        if let result {
            SessionResultView(summary: result) { dismiss() }
        } else {
            activeLogger
        }
    }

    private var activeLogger: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.space16) {
                BoardedSyncBanner(isOffline: !syncService.isOnline, state: syncService.state) {
                    Task { await logger.retrySync() }
                }
                if let session = logger.activeSession {
                    BoardedEyebrow(text: "Active Session")
                    Text(session.venueName).font(AppTypography.titleL)
                    VStack(alignment: .leading, spacing: AppSpacing.space8) {
                        TimelineView(.periodic(from: .now, by: 1)) { value in
                            Text(BoardedFormat.duration(value.date.timeIntervalSince(session.startedAt)))
                                .font(AppTypography.dataL)
                                .foregroundStyle(AppColor.accentDefault)
                                .accessibilityLabel("Elapsed time")
                        }
                        BoardedPrimaryButton(title: "Log Attempt", systemImage: "plus") {
                            outcomeSheet = true
                        }
                        .accessibilityIdentifier("log-attempt")
                    }
                    .boardedPanel()
                    queue
                    Button("End Session") { confirmEnd = true }
                        .buttonStyle(BoardedButtonStyle(.destructive))
                }
            }
            .padding(AppLayout.screenMargin)
        }
        .boardedPageBackground()
        .sheet(isPresented: $outcomeSheet) {
            OutcomeSheet { route, discipline, system, grade, outcome, notes in
                logger.recordAttempt(routeName: route, discipline: discipline, gradeSystem: system, gradeLabel: grade, outcome: outcome, notes: notes)
            }
        }
        .confirmationDialog("End this session?", isPresented: $confirmEnd) {
            Button("End Session", role: .destructive) { end() }
                .accessibilityIdentifier("confirm-end-session")
        }
    }
    private var queue: some View { VStack(alignment: .leading, spacing: AppSpacing.space8) { HStack { BoardedSectionHeading(title: "Attempts", subtitle: "Newest first"); Spacer(); if !logger.attempts.isEmpty { Button("Undo") { logger.undoLatestAttempt() }.accessibilityIdentifier("undo-attempt") } }; ForEach(Array(logger.attempts.reversed())) { item in HStack { Text("#\(item.attemptNumber)").font(AppTypography.dataS); VStack(alignment: .leading) { Text(item.routeName); Text("\(item.gradeLabel) · \(BoardedFormat.timeOnly(item.occurredAt))").font(AppTypography.caption).foregroundStyle(AppColor.textSecondary) }; Spacer(); Label(item.outcome.title, systemImage: item.outcome.systemImage).foregroundStyle(item.outcome == .sent ? AppColor.accentDefault : AppColor.textPrimary) }.frame(minHeight: AppLayout.listRowMinHeight) } } }
    private func end() { guard let active = logger.activeSession else { return }; let now = Date(); result = SessionSummary(sessionID: active.id, venue: active.venueName, startedAt: active.startedAt, endedAt: now, attempts: logger.attempts); logger.endSession(at: now) }
}

extension SessionSummary: Identifiable { var id: UUID { sessionID } }

struct OutcomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var route = ""
    @State private var discipline = ClimbDiscipline.boulder
    @State private var system = GradeSystem.vScale
    @State private var grade = "V0"
    @State private var notes = ""
    @State private var outcome = AttemptOutcome.sent
    let submit: (String, ClimbDiscipline, GradeSystem, String, AttemptOutcome, String?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.space16) {
                    BoardedTextField(label: "Route", prompt: "Route name", text: $route)
                    Picker("Discipline", selection: $discipline) {
                        ForEach(ClimbDiscipline.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Grade", selection: $grade) {
                        ForEach(GradeCatalog.grades(for: system), id: \.self) { Text($0).tag($0) }
                    }
                    BoardedTextEditor(label: "Notes", prompt: "Optional", text: $notes)
                    outcomeChoices
                    BoardedPrimaryButton(title: "Save Attempt") {
                        submit(route, discipline, system, grade, outcome, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                    .disabled(route.isEmpty)
                }
                .padding(AppLayout.screenMargin)
            }
            .navigationTitle("Attempt")
            .boardedPageBackground()
        }
    }

    @ViewBuilder private var outcomeChoices: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.space8) { outcomeButtons }
        } else {
            ViewThatFits {
                HStack(spacing: AppSpacing.space8) { outcomeButtons }
                VStack(spacing: AppSpacing.space8) { outcomeButtons }
            }
        }
    }

    @ViewBuilder private var outcomeButtons: some View {
        ForEach(AttemptOutcome.allCases, id: \.self) { value in
            Button { outcome = value } label: {
                Label(value.title, systemImage: value.systemImage)
                    .frame(maxWidth: .infinity, minHeight: AppLayout.primaryControlHeight)
                    .background(outcome == value ? AppColor.accentSoft : AppColor.surfaceCard, in: AppRadius.control)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(outcome == value ? .isSelected : [])
        }
    }
}

struct SessionResultView: View {
    let summary: SessionSummary
    let done: () -> Void
    @State private var share = false
    @State private var picker: PhotosPickerItem?
    @State private var cropImage: UIImage?
    @State private var cropPresented = false
    @State private var selectedImage: UIImage?
    @State private var imageAlt = ""

    private var featuredAttempt: PendingAttempt? { summary.bestSend ?? summary.attempts.last }
    private var artworkModel: SessionArtworkModel? {
        guard let featuredAttempt else { return nil }
        return SessionArtworkModel(
            venue: summary.venue,
            duration: summary.duration,
            attemptCount: summary.attempts.count,
            sendCount: summary.sendCount,
            featuredRoute: featuredAttempt.routeName,
            featuredGrade: featuredAttempt.gradeLabel,
            outcome: featuredAttempt.outcome,
            featuredAttemptNumber: featuredAttempt.attemptNumber,
            overlayStyle: .stats,
            attemptOutcomes: summary.attempts.map { SessionArtworkAttempt(number: $0.attemptNumber, outcome: $0.outcome) }
        )
    }

    private var opaqueSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            Text(summary.venue).font(AppTypography.titleM)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.space16) { summaryFacts }
                VStack(alignment: .leading, spacing: AppSpacing.space8) { summaryFacts }
            }
            if let featuredAttempt {
                Label(
                    "\(featuredAttempt.gradeLabel) · \(featuredAttempt.routeName) · \(featuredAttempt.outcome.title)",
                    systemImage: featuredAttempt.outcome.systemImage
                )
                .font(AppTypography.labelL)
            }
        }
        .foregroundStyle(AppColor.textPrimary)
        .padding(AppSpacing.space16)
        .background(AppColor.surfaceCard, in: AppRadius.card())
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var summaryFacts: some View {
        Label(BoardedFormat.duration(summary.duration), systemImage: "clock")
        Label("\(summary.routeCount) routes", systemImage: "square.stack")
        Label("\(summary.attempts.count) attempts", systemImage: "number")
        Label("\(summary.sendCount) sends", systemImage: "checkmark.circle")
            .accessibilityIdentifier("session-result-sends")
        Label(summary.successRate.map(BoardedFormat.percent) ?? "—", systemImage: "percent")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.space24) {
                    BoardedEyebrow(text: "Session Complete")
                    Text(summary.bestSend?.gradeLabel ?? "\(summary.attempts.count) attempts")
                        .font(AppTypography.displayL)
                        .foregroundStyle(summary.sendCount > 0 ? AppColor.accentDefault : AppColor.textPrimary)
                    if let selectedImage, let artworkModel {
                        SessionArtworkView(image: Image(uiImage: selectedImage), imageAlt: imageAlt, model: artworkModel)
                            .accessibilityIdentifier("session-result-artwork")
                    } else {
                        opaqueSummary
                    }
                    PhotosPicker(selection: $picker, matching: .images) {
                        Label(selectedImage == nil ? "Add session photo" : "Change session photo", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BoardedButtonStyle(.secondary))
                    .accessibilityIdentifier("session-result-photo")
                    if selectedImage != nil {
                        BoardedTextField(
                            label: "Photo description",
                            prompt: "Describe the overhanging wall or climbing scene",
                            text: $imageAlt,
                            error: imageAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Photo description is required." : nil
                        )
                    }
                    if !summary.attempts.isEmpty {
                        Button("Share session") { share = true }
                            .buttonStyle(BoardedButtonStyle(.secondary))
                            .disabled(selectedImage == nil || imageAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("share-completed-session")
                    }
                    BoardedPrimaryButton(title: "Done", action: done)
                }
                .padding(AppLayout.screenMargin)
            }
            .boardedPageBackground()
            .task {
                if AppLaunchConfiguration.isUITestFixture {
                    selectedImage = UITestFixtures.sessionImage
                    imageAlt = UITestFixtures.sessionImageAlt
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
            .sheet(isPresented: $cropPresented) {
                if let cropImage {
                    PhotoCropView(image: cropImage) {
                        selectedImage = $0
                        imageAlt = ""
                        cropPresented = false
                    }
                }
            }
            .sheet(isPresented: $share) {
                ShareSessionComposer(
                    initialSessionID: summary.sessionID,
                    featuredAttemptID: featuredAttempt?.id,
                    image: selectedImage,
                    imageAlt: imageAlt
                )
            }
        }
        .accessibilityIdentifier("session-result")
    }
}
