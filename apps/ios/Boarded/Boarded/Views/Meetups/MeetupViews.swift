import SwiftUI

struct MeetupsListView: View {
    @Environment(\.boardedAuth) private var auth
    @StateObject private var model = MeetupsViewModel(repository: AppServices.meetupRepository)
    @State private var query = ""
    @State private var create = false
    private var filtered: [Meetup] { query.isEmpty ? model.meetups : model.meetups.filter { [$0.title,$0.venueName,$0.area].joined(separator: " ").localizedCaseInsensitiveContains(query) } }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: AppSpacing.space16) {
            SearchField(text: $query, placeholder: "Search venue or area")
            HStack { BoardedFilterControl(title: "Scheduled", isSelected: model.selectedStatus == .scheduled) { model.selectedStatus = .scheduled; Task { await model.load() } }; BoardedFilterControl(title: "Cancelled", isSelected: model.selectedStatus == .cancelled) { model.selectedStatus = .cancelled; Task { await model.load() } } }
            if model.isLoading { BoardedFeedCardSkeleton() } else if let error = model.errorMessage { BoardedInlineError(message: error) { Task { await model.load() } } } else if filtered.isEmpty { BoardedRouteLineEmptyState(title: "No meetups on this line", message: "Create a session and invite your crew.", actionTitle: "Create Meetup", action: requestCreate) } else { LazyVStack(spacing: 0) { ForEach(filtered) { item in NavigationLink { MeetupDetailView(meetup: item) } label: { MeetupRow(meetup: item) }.buttonStyle(.plain) } } }
        }.padding(AppLayout.screenMargin).boardedContentWidth().frame(maxWidth: .infinity) }.navigationTitle("Meetups").boardedPageBackground().toolbar { ToolbarItem(placement: .primaryAction) { Button(action: requestCreate) { Image(systemName: "plus").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Create meetup") } }.sheet(isPresented: $create) { MeetupFormView() }.task { await model.load() }
    }
    private func requestCreate() { if auth.isAuthenticated { create = true } else { auth.requestAuthentication() } }
}

struct MeetupRow: View { let meetup: Meetup; var body: some View { HStack { VStack(alignment: .leading, spacing: AppSpacing.space4) { Text(meetup.title).font(AppTypography.labelL).foregroundStyle(AppColor.textPrimary); Text("\(meetup.venueName) · \(meetup.area)").font(AppTypography.bodyM).foregroundStyle(AppColor.textSecondary); Label(BoardedFormat.dateTime(meetup.startsAt), systemImage: "calendar").font(AppTypography.caption).foregroundStyle(AppColor.textTertiary) }; Spacer(); if meetup.status == .cancelled { Label("Cancelled", systemImage: "xmark.circle").font(AppTypography.labelM).foregroundStyle(AppColor.danger) } else { Image(systemName: "chevron.right").foregroundStyle(AppColor.textTertiary) } }.frame(minHeight: AppLayout.listRowMinHeight).overlay(alignment: .bottom) { Divider().overlay(AppColor.divider) }.accessibilityElement(children: .combine) } }

struct MeetupDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.boardedAuth) private var auth
    let meetup: Meetup
    @State private var current: Meetup; @State private var attendees: [MeetupAttendee] = []; @State private var comments: [MeetupComment] = []; @State private var joined = false; @State private var comment = ""; @State private var edit = false; @State private var error: String?
    private let repository = AppServices.meetupRepository
    init(meetup: Meetup) { self.meetup = meetup; _current = State(initialValue: meetup) }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: AppSpacing.space24) {
        if current.status == .cancelled { Label("Cancelled meetup", systemImage: "xmark.circle.fill").foregroundStyle(AppColor.danger) }
        BoardedEyebrow(text: current.area); Text(current.title).font(AppTypography.titleL); Text(current.description).font(AppTypography.bodyL).foregroundStyle(AppColor.textSecondary)
        VStack(alignment: .leading, spacing: AppSpacing.space8) { Label(current.venueName, systemImage: "mappin.and.ellipse"); Label(BoardedFormat.dateTime(current.startsAt), systemImage: "calendar"); if let capacity = current.capacity { Label("\(attendees.count + 1) of \(capacity) places", systemImage: "person.3") } }.font(AppTypography.bodyM)
        actions; commentsView
    }.padding(AppLayout.screenMargin).boardedContentWidth().frame(maxWidth: .infinity) }.navigationTitle("Meetup").navigationBarTitleDisplayMode(.inline).boardedPageBackground().toolbar { if current.organizerId == session.userId { ToolbarItem(placement: .primaryAction) { Button("Edit") { edit = true } } } }.sheet(isPresented: $edit) { MeetupFormView(meetup: current) { current = $0 } }.task { await load() } }
    private var actions: some View { VStack(spacing: AppSpacing.space12) { if current.organizerId == session.userId { Button("Cancel Meetup") { Task { await cancel() } }.buttonStyle(BoardedButtonStyle(.destructive)) } else if current.status == .scheduled { BoardedPrimaryButton(title: joined ? "Leave Meetup" : (isFull ? "Meetup Full" : "Join Meetup")) { mutateAttendance() }.disabled(isFull && !joined) }; if let error { Text(error).font(AppTypography.labelM).foregroundStyle(AppColor.danger) } } }
    private var commentsView: some View { VStack(alignment: .leading, spacing: AppSpacing.space12) { BoardedSectionHeading(title: "Comments"); ForEach(comments) { Text($0.content).font(AppTypography.bodyL).frame(maxWidth: .infinity, alignment: .leading) }; HStack { TextField("Add a comment", text: $comment).padding(AppSpacing.space12).boardedSurface(in: AppRadius.control, interactive: true); Button("Post") { post() }.disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
    private var isFull: Bool { current.capacity.map { attendees.count + 1 >= $0 } ?? false }
    private func load() async { do { async let a = repository.fetchAttendees(meetupID: current.id); async let c = repository.fetchComments(meetupID: current.id); (attendees, comments) = try await (a,c); joined = attendees.contains { $0.userId == session.userId } } catch { self.error = error.localizedDescription } }
    private func mutateAttendance() { guard auth.isAuthenticated else { auth.requestAuthentication(); return }; Task { do { if joined { try await repository.leaveMeetup(id: current.id); joined = false } else { attendees.append(try await repository.joinMeetup(id: current.id)); joined = true } } catch { self.error = error.localizedDescription } } }
    private func post() { guard auth.isAuthenticated else { auth.requestAuthentication(); return }; Task { do { comments.append(try await repository.createComment(meetupID: current.id, content: comment)); comment = "" } catch { self.error = error.localizedDescription } } }
    private func cancel() async { do { current = try await repository.cancelMeetup(id: current.id) } catch { self.error = error.localizedDescription } }
}

struct MeetupFormView: View {
    @Environment(\.dismiss) private var dismiss
    var meetup: Meetup?; var completion: ((Meetup) -> Void)?
    @State private var title = ""; @State private var description = ""; @State private var venue = ""; @State private var area = ""; @State private var startsAt = Date().addingTimeInterval(3600); @State private var hasEnd = false; @State private var endsAt = Date().addingTimeInterval(7200); @State private var capacity = ""; @State private var error: String?
    private let repository = AppServices.meetupRepository
    var body: some View { NavigationStack { Form { Section("Details") { TextField("Title", text: $title); TextField("Venue", text: $venue); TextField("Area", text: $area); TextField("Description", text: $description, axis: .vertical) }; Section("Time") { DatePicker("Starts", selection: $startsAt); Toggle("Set end time", isOn: $hasEnd); if hasEnd { DatePicker("Ends", selection: $endsAt) } }; Section("Capacity") { TextField("Optional capacity", text: $capacity).keyboardType(.numberPad) }; if let error { Text(error).foregroundStyle(AppColor.danger) } }.scrollContentBackground(.hidden).boardedPageBackground().navigationTitle(meetup == nil ? "Create Meetup" : "Edit Meetup").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }.onAppear { populate() } } }
    private func populate() { guard let m = meetup, title.isEmpty else { return }; title=m.title; description=m.description; venue=m.venueName; area=m.area; startsAt=m.startsAt; if let end=m.endsAt { hasEnd=true; endsAt=end }; capacity=m.capacity.map(String.init) ?? "" }
    private func save() { guard !title.trimmed.isEmpty, !venue.trimmed.isEmpty, !area.trimmed.isEmpty else { error="Title, venue, and area are required."; return }; let cap=Int(capacity); if !capacity.isEmpty && (cap ?? 0) < 1 { error="Capacity must be at least 1."; return }; guard !hasEnd || endsAt > startsAt else { error="End time must be after the start."; return }; let draft=MeetupDraft(title:title.trimmed, description:description.trimmed, venueName:venue.trimmed, area:area.trimmed, startsAt:startsAt, endsAt:hasEnd ? endsAt:nil, capacity:cap); Task { do { let saved = if let meetup { try await repository.updateMeetup(id: meetup.id, draft: draft) } else { try await repository.createMeetup(draft) }; completion?(saved); dismiss() } catch { self.error=error.localizedDescription } } }
}
private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
