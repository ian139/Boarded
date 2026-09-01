import SwiftUI
import UIKit

struct LogView: View {
    @StateObject private var store: AttemptLogStore
    @State private var routeName = ""
    @State private var grade = ""
    @State private var confirmEnd = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(fixture: AttemptLogFixture? = nil) {
        _store = StateObject(wrappedValue: AttemptLogStore(fixture: fixture))
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.syncState != .synced {
                localStorageBanner
            }
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.space24) {
                    switch store.presentationState {
                    case .loading:
                        loading
                    case let .error(message):
                        BoardedInlineError(message: message) { store.reload() }
                    case .ready:
                        if let session = store.activeSession { active(session) } else { start }
                        if !store.history.isEmpty { history }
                    }
                }
                .padding(.horizontal, AppSpacing.space20).padding(.vertical, AppSpacing.space24)
                .frame(maxWidth: AppLayout.contentMaxWidth).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Log")
        .boardedPageBackground()
        .safeAreaInset(edge: .bottom) {
            if let confirmation = store.confirmation {
                BoardedSuccessConfirmation(message: confirmation)
                    .padding(.bottom, AppSpacing.space8)
                    .onTapGesture { store.clearConfirmation() }
                    .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("End this session?", isPresented: $confirmEnd) {
            Button("Keep Climbing", role: .cancel) {}
            Button("End Session", role: .destructive) { store.endSession(); successHaptic() }
        } message: { Text("The session result will be saved to your timeline.") }
        .sheet(item: Binding(get: { store.presentedResult }, set: { if $0 == nil { store.dismissResult() } })) { session in
            SessionResultView(session: session) { store.dismissResult() }
                .presentationDetents([.large])
        }
    }

    private var localStorageBanner: some View {
        Label(
            store.isOffline
                ? "Offline. Attempts remain saved on this device."
                : "Saved on this device. Cloud sync is unavailable.",
            systemImage: store.isOffline ? "wifi.slash" : "internaldrive"
        )
        .font(AppTypography.label)
        .foregroundStyle(AppColor.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .padding(.horizontal, AppSpacing.space16)
        .frame(maxWidth: .infinity, minHeight: AppLayout.minimumControlHeight, alignment: .leading)
        .background(AppColor.warning.opacity(0.14))
    }
    private var loading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space16) {
            BoardedSkeleton(shape: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .frame(height: AppSpacing.space40)
            BoardedSkeleton(shape: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .frame(height: AppSpacing.space64)
            BoardedSkeleton(shape: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .frame(height: AppLayout.primaryControlHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading attempt logger")
    }


    private var start: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space20) {
            BoardedSectionHeading(title: "Start a session", subtitle: "Log attempts as they happen. Everything saves locally first.")
            BoardedLabeledField(label: "Route", prompt: "Route name", text: $routeName)
            BoardedLabeledField(label: "Grade", prompt: "V6 or 5.12a", text: $grade)
            BoardedPrimaryButton(title: "Start Session", systemImage: "play.fill") {
                store.startSession(routeName: routeName.trimmingCharacters(in: .whitespacesAndNewlines), grade: grade.trimmingCharacters(in: .whitespacesAndNewlines))
                selectionHaptic()
            }
            .disabled(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if store.history.isEmpty {
                BoardedRouteLineEmptyState(title: "Your session line starts here", message: "Choose a route and grade, then record each attempt with an explicit outcome.")
            }
        }
    }

    private func active(_ session: ClimbSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space24) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.space16) {
                    sessionIdentity(session)
                    Spacer()
                    sessionTimer(session)
                }
                VStack(alignment: .leading, spacing: AppSpacing.space16) {
                    sessionIdentity(session)
                    sessionTimer(session)
                }
            }
            .boardedPanel()

            VStack(alignment: .leading, spacing: AppSpacing.space12) {
                BoardedSectionHeading(title: "Record attempt", subtitle: "Outcome is always shown with a name and symbol.")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.space8) {
                        outcomeButtons
                    }
                    VStack(spacing: AppSpacing.space8) {
                        HStack(spacing: AppSpacing.space8) {
                            outcomeButton(.sent)
                            outcomeButton(.fell)
                        }
                        outcomeButton(.stopped)
                    }
                }
            }

            attemptTimeline(session)

            Button(role: .destructive) { confirmEnd = true } label: {
                Label("End Session", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }.buttonStyle(BoardedButtonStyle(.secondary)).foregroundStyle(AppColor.danger)
        }
    }

    @ViewBuilder private var outcomeButtons: some View {
        ForEach(AttemptOutcome.allCases) { outcome in
            outcomeButton(outcome)
        }
    }

    private func outcomeButton(_ outcome: AttemptOutcome) -> some View {
        Button {
            store.record(outcome)
            outcome == .sent ? successHaptic() : selectionHaptic()
        } label: {
            Label(outcome.title, systemImage: outcome.symbol)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, minHeight: AppLayout.primaryControlHeight)
        }
        .buttonStyle(BoardedButtonStyle(outcome == .sent ? .primary : .secondary))
        .accessibilityLabel("Record \(outcome.title)")
        .accessibilityHint("Adds a \(outcome.title.lowercased()) outcome to this session")
        .keyboardShortcut(keyboardShortcut(for: outcome), modifiers: [])
    }

    private func attemptTimeline(_ session: ClimbSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            HStack {
                BoardedSectionHeading(title: "Attempt line", subtitle: session.attempts.isEmpty ? "No attempts yet" : "Newest attempt last")
                Spacer()
                if !session.attempts.isEmpty {
                    Button("Undo latest") { store.undoLatestAttempt(); selectionHaptic() }.frame(minHeight: 44)
                }
            }
            if session.attempts.isEmpty {
                BoardedRouteLineEmptyState(title: "Ready for attempt one", message: "Record Sent, Fell, or Stopped after the attempt.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(session.attempts.enumerated()), id: \.element.id) { index, attempt in
                        HStack(spacing: AppSpacing.space12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(color(for: attempt.outcome))
                                    .frame(width: AppSpacing.space12, height: AppSpacing.space12)
                                    .overlay {
                                        Image(systemName: attempt.outcome == .sent ? "checkmark" : attempt.outcome == .fell ? "xmark" : "stop.fill")
                                            .font(.caption2.bold())
                                            .foregroundStyle(AppColor.backgroundBase)
                                    }
                                    .overlay {
                                        if differentiateWithoutColor {
                                            Circle().stroke(AppColor.textPrimary, lineWidth: AppStroke.hairline)
                                        }
                                    }
                                if index < session.attempts.count - 1 {
                                    Rectangle().fill(AppColor.strokeDefault).frame(width: AppStroke.hairline).frame(minHeight: 36)
                                }
                            }.accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: AppSpacing.space4) {
                                Text(attempt.outcome.title).font(AppTypography.headline)
                                Text(attempt.occurredAt, style: .time).font(AppTypography.caption).foregroundStyle(AppColor.textSecondary)
                            }.padding(.bottom, AppSpacing.space12)
                            Spacer()
                        }.accessibilityElement(children: .combine)
                    }
                }
                .animation(reduceMotion ? nil : AppMotion.routeTrace, value: session.attempts)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Recent sessions")
            ForEach(store.history) { session in
                HStack(spacing: AppSpacing.space12) {
                    Image(systemName: session.result.symbol).foregroundStyle(session.result == .sent ? AppColor.accentDefault : AppColor.textSecondary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.space4) {
                        Text("\(AttemptFormatting.grade(session.grade)) · \(session.routeName)").font(AppTypography.headline).fixedSize(horizontal: false, vertical: true)
                        Text("\(session.result.title) · \(AttemptFormatting.attemptCount(session.attempts.count)) · \(AttemptFormatting.dateTime(session.endedAt ?? session.startedAt))")
                            .font(AppTypography.body).foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                }.padding(AppSpacing.space16).boardedGlassSurface(in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func color(for outcome: AttemptOutcome) -> Color {
        switch outcome { case .sent: return AppColor.accentDefault; case .fell: return AppColor.danger; case .stopped: return AppColor.warning }
    }
    private func sessionIdentity(_ session: ClimbSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Label("ACTIVE SESSION", systemImage: "record.circle")
                .font(AppTypography.caption).foregroundStyle(AppColor.accentDefault)
            Text(AttemptFormatting.grade(session.grade)).font(AppTypography.displayLarge).foregroundStyle(AppColor.textPrimary).fixedSize()
            Text(session.routeName).font(AppTypography.title).foregroundStyle(AppColor.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sessionTimer(_ session: ClimbSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let boundedStart = max(session.startedAt, context.date.addingTimeInterval(-86_399))
            Text(AttemptFormatting.duration(from: boundedStart, to: context.date, abbreviated: true))
                .font(AppTypography.data).foregroundStyle(AppColor.textPrimary).monospacedDigit()
                .accessibilityLabel("Elapsed time \(AttemptFormatting.duration(from: boundedStart, to: context.date, abbreviated: false))")
        }
    }

    private func keyboardShortcut(for outcome: AttemptOutcome) -> KeyEquivalent {
        switch outcome {
        case .sent: return "s"
        case .fell: return "f"
        case .stopped: return "t"
        }
    }
    private func selectionHaptic() { UISelectionFeedbackGenerator().selectionChanged() }
    private func successHaptic() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

private struct SessionResultView: View {
    let session: ClimbSession
    let dismiss: () -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.space20) {
                Label(session.result == .sent ? "SENT" : "SESSION COMPLETE", systemImage: session.result.symbol)
                    .font(AppTypography.caption)
                    .foregroundStyle(session.result == .sent ? AppColor.accentDefault : AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(session.result.title)
                    .font(AppTypography.displayLarge)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(resultDescription)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(AttemptFormatting.attemptCount(session.attempts.count), systemImage: "figure.climbing")
                    .font(AppTypography.label)
                if let endedAt = session.endedAt {
                    Label(AttemptFormatting.duration(from: session.startedAt, to: endedAt, abbreviated: false), systemImage: "timer")
                        .font(AppTypography.label)
                }
                ShareLink(item: shareText) {
                    Label("Share Session", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(BoardedButtonStyle(session.result == .sent ? .primary : .secondary))
                .accessibilityHint("Opens the system share sheet")
                Button(action: dismiss) {
                    Label("Done", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(BoardedButtonStyle(session.result == .sent ? .secondary : .primary))
                .keyboardShortcut(.defaultAction)
            }
            .padding(AppSpacing.space24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColor.backgroundBase)
        .preferredColorScheme(.dark)
    }

    private var resultDescription: String {
        let route = "\(AttemptFormatting.grade(session.grade)) · \(session.routeName)"
        if session.result == .sent {
            return "\(route)\nSent in \(AttemptFormatting.attemptCount(session.attempts.count))."
        }
        return "\(route)\nNo send today. \(AttemptFormatting.attemptCount(session.attempts.count)) safely recorded."
    }

    private var shareText: String {
        if session.result == .sent {
            return "Sent \(AttemptFormatting.grade(session.grade)) \(session.routeName) in \(AttemptFormatting.attemptCount(session.attempts.count)) with Boarded."
        }
        return "Logged \(AttemptFormatting.attemptCount(session.attempts.count)) on \(AttemptFormatting.grade(session.grade)) \(session.routeName) with Boarded."
    }
}
