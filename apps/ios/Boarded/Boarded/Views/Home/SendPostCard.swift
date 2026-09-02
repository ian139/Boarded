import SwiftUI

/// Public URL for a session-journal image stored in the `social-media` bucket.
enum FeedImageURL {
    static func publicURL(for path: String) -> URL? {
        guard let base = SupabaseConfig.current?.url else { return nil }
        return base.appendingPathComponent("storage/v1/object/public/social-media/\(path)")
    }
}

struct SendPostCard: View {
    let item: SessionFeedItem
    var onLike: () -> Void = {}
    var showsActions = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var authorName: String { item.author.fullName?.trimmedNonEmpty ?? item.author.username?.trimmedNonEmpty ?? "Climber" }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            header
            photoComposition
            if let caption = item.caption?.trimmedNonEmpty {
                Text(caption)
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.space16)
                    .background(AppColor.surfaceCard, in: AppRadius.card())
                    .accessibilityIdentifier("session-post-caption")
            }
            if showsActions { actions }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-post-card")
    }

    private var header: some View {
        HStack(spacing: AppSpacing.space12) {
            BoardedAvatar(name: authorName, size: 40)
            VStack(alignment: .leading, spacing: AppSpacing.space4) {
                Text(authorName).font(AppTypography.labelL).foregroundStyle(AppColor.textPrimary)
                Text(BoardedFormat.relative(item.createdAt)).font(AppTypography.caption).foregroundStyle(AppColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var artworkModel: SessionArtworkModel {
        SessionArtworkModel(
            venue: item.session.venueName,
            duration: TimeInterval(item.session.durationSeconds),
            attemptCount: item.session.attemptCount,
            sendCount: item.session.sendCount,
            featuredRoute: item.session.featuredAttempt.routeName,
            featuredGrade: item.session.featuredAttempt.gradeLabel,
            outcome: item.session.featuredAttempt.outcome,
            featuredAttemptNumber: item.session.featuredAttempt.attemptNumber,
            overlayStyle: item.overlayStyle,
            attemptOutcomes: item.session.artworkAttempts
        )
    }

    @ViewBuilder private var photoComposition: some View {
        if item.imagePath == UITestFixtures.localSessionImagePath,
           let image = UITestFixtures.sessionImage {
            fixturePhoto(image)
        } else {
            ProductionFeedPhoto(item: item)
        }
    }

    @ViewBuilder private func fixturePhoto(_ image: UIImage) -> some View {
        if dynamicTypeSize.isAccessibilitySize || UITestFixtures.usesAccessibilityLargeText {
            SessionArtworkView(
                image: Image(uiImage: image),
                imageAlt: item.imageAlt,
                model: artworkModel,
                presentation: .screen,
                forcesOpaqueContinuation: true
            )
        } else {
            CanonicalSessionArtworkPreview(
                image: image,
                imageAlt: item.imageAlt,
                model: artworkModel
            )
        }
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.space20) {
            Button(action: onLike) {
                Label("\(item.likeCount)", systemImage: item.isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(item.isLiked ? AppColor.accentDefault : AppColor.textSecondary)
                    .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isLiked ? "Unlike" : "Like")
            .accessibilityValue("\(item.likeCount) likes")
            .modifier(LikeSelectionAccessibility(isSelected: item.isLiked))
            .accessibilityIdentifier("post-like")

            Label("\(item.commentCount)", systemImage: "bubble.right")
                .foregroundStyle(AppColor.textSecondary)
                .frame(minHeight: AppLayout.minimumTarget)
                .accessibilityLabel("\(item.commentCount) comments")
                .accessibilityIdentifier("post-comments")
            Spacer(minLength: 0)
            ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up").frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget) }
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityLabel("Share session journal entry")
        }
        .font(AppTypography.labelL)
    }

    private var shareText: String {
        let attempt = item.session.featuredAttempt
        return "\(authorName)'s session at \(item.session.venueName): \(attempt.gradeLabel) \(attempt.routeName), \(attempt.outcome.title) on Boarded."
    }
}



private struct ProductionFeedPhoto: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: SessionFeedItem

    private var artworkModel: SessionArtworkModel {
        let attempt = item.session.featuredAttempt
        return SessionArtworkModel(
            venue: item.session.venueName,
            duration: TimeInterval(item.session.durationSeconds),
            attemptCount: item.session.attemptCount,
            sendCount: item.session.sendCount,
            featuredRoute: attempt.routeName,
            featuredGrade: attempt.gradeLabel,
            outcome: attempt.outcome,
            featuredAttemptNumber: attempt.attemptNumber,
            overlayStyle: item.overlayStyle,
            attemptOutcomes: item.session.artworkAttempts
        )
    }

    @ViewBuilder var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                FeedPostImage(path: item.sourceImagePath, alt: item.imageAlt)
                SessionArtworkFacts(model: artworkModel, opaque: true)
            }
            .clipShape(AppRadius.card())
            .overlay { AppRadius.card().stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
        } else {
            // Published post pixels already contain the flattened facts; a live
            // shelf here would duplicate the exported composition.
            basePhoto.modifier(FeedPhotoAccessibility(session: item.session))
        }
    }

    private var basePhoto: some View {
        FeedPostImage(path: item.imagePath, alt: item.imageAlt)
            .clipShape(AppRadius.card())
            .overlay { AppRadius.card().stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
    }
}

private struct FeedPhotoAccessibility: ViewModifier {
    let session: FeedSessionSummary

    private var featuredAttemptDescription: String {
        let attempt = session.featuredAttempt
        return "\(attempt.gradeLabel) \(attempt.routeName), \(attempt.outcome.title)"
    }
    private var attemptTimelineDescription: String {
        session.artworkAttempts
            .map { "Attempt \($0.number), \($0.outcome.title)" }
            .joined(separator: "; ")
    }

    private var factSummary: String {
        [
            "Venue \(session.venueName)",
            "Duration \(BoardedFormat.duration(TimeInterval(session.durationSeconds)))",
            "\(session.attemptCount) attempts",
            "\(session.sendCount) sends",
            "Featured attempt \(featuredAttemptDescription)",
            attemptTimelineDescription
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }


    func body(content: Content) -> some View {
        content
            .accessibilityCustomContent(AccessibilityCustomContentKey("Venue"), Text(session.venueName))
            .accessibilityCustomContent(AccessibilityCustomContentKey("Duration"), Text(BoardedFormat.duration(TimeInterval(session.durationSeconds))))
            .accessibilityCustomContent(AccessibilityCustomContentKey("Attempts"), Text("\(session.attemptCount)"))
            .accessibilityCustomContent(AccessibilityCustomContentKey("Sends"), Text("\(session.sendCount)"))
            .accessibilityCustomContent(AccessibilityCustomContentKey("Featured attempt"), Text(featuredAttemptDescription))
            .accessibilityCustomContent(AccessibilityCustomContentKey("Attempt timeline"), Text(attemptTimelineDescription))
            .accessibilityValue(factSummary)
    }
}
private extension FeedSessionSummary {
    var artworkAttempts: [SessionArtworkAttempt] {
        (attemptTimeline ?? []).map {
            SessionArtworkAttempt(number: $0.attemptNumber, outcome: $0.outcome)
        }
    }
}


struct FeedPostImage: View {
    let path: String
    let alt: String

    var body: some View {
        Group {
            if (path == UITestFixtures.localSessionImagePath || AppLaunchConfiguration.isUITestFixture),
               let image = UITestFixtures.sessionImage {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                AsyncImage(url: FeedImageURL.publicURL(for: path)) { phase in
                    if case let .success(image) = phase { image.resizable().aspectRatio(contentMode: .fill) }
                    else { ZStack { AppColor.backgroundElevated; ProgressView().tint(AppColor.textSecondary) } }
                }
            }
        }
        .frame(maxWidth: .infinity).aspectRatio(3.0 / 2.0, contentMode: .fit).clipped()
        .accessibilityLabel(alt)
    }
}

private struct LikeSelectionAccessibility: ViewModifier {
    let isSelected: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isSelected {
            content.accessibilityAddTraits(.isSelected)
        } else {
            content
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
