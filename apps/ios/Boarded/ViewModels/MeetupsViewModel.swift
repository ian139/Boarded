import Foundation
import Combine

@MainActor
final class MeetupsViewModel: ObservableObject {
    @Published private(set) var meetups: [Meetup] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedStatus: MeetupStatus? = .scheduled
    @Published var selectedArea: String? = nil

    private let repository: any MeetupRepository
    private var generation = 0

    init(repository: any MeetupRepository) {
        self.repository = repository
    }

    func load() async {
        generation += 1
        let request = generation
        isLoading = true
        errorMessage = nil
        defer {
            if request == generation { isLoading = false }
        }
        do {
            let fetched = try await repository.fetchMeetups(status: selectedStatus, area: selectedArea)
            try Task.checkCancellation()
            guard request == generation else { return }
            meetups = fetched
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Joins a meetup with optimistic state and rolls back on failure.
    func join(meetupID: UUID) async {
        guard let index = meetups.firstIndex(where: { $0.id == meetupID }) else { return }
        let previous = meetups[index]
        do {
            _ = try await repository.joinMeetup(id: meetupID)
        } catch {
            if let reset = meetups.firstIndex(where: { $0.id == meetupID }) {
                meetups[reset] = previous
            }
            errorMessage = error.localizedDescription
        }
    }

    func leave(meetupID: UUID) async {
        do {
            try await repository.leaveMeetup(id: meetupID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
