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

    private var photoComposition: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                FeedPostImage(url: FeedImageURL.publicURL(for: item.imagePath), alt: item.imageAlt)
                if !dynamicTypeSize.isAccessibilitySize {
                    LinearGradient(colors: [.clear, AppColor.backgroundBase.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                        .accessibilityHidden(true)
                    SessionFactShelf(session: item.session, overlayStyle: item.overlayStyle)
                        .padding(AppSpacing.space12)
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                SessionFactShelf(session: item.session, overlayStyle: item.overlayStyle, opaque: true)
            }
        }
        .clipShape(AppRadius.card())
        .overlay { AppRadius.card().stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
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

struct SessionFactShelf: View {
    let session: FeedSessionSummary
    let overlayStyle: OverlayStyle
    var opaque = false

    private var outcome: FeedFeaturedAttempt { session.featuredAttempt }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.venueName).font(AppTypography.titleM).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.space8)
                Label(outcome.outcome.title, systemImage: outcome.outcome.systemImage)
                    .font(AppTypography.labelM)
                    .foregroundStyle(outcome.outcome == .sent ? AppColor.accentDefault : AppColor.textPrimary)
            }
            if overlayStyle == .attemptTimeline {
                HStack(spacing: AppSpacing.space8) {
                    ForEach(1...max(session.attemptCount, 1), id: \.self) { index in
                        Circle().fill(index == outcome.attemptNumber ? AppColor.accentDefault : AppColor.textSecondary).frame(width: AppSpacing.space8, height: AppSpacing.space8)
                    }
                }
                .accessibilityLabel("Featured attempt \(outcome.attemptNumber) of \(session.attemptCount)")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.space16) { facts }
                VStack(alignment: .leading, spacing: AppSpacing.space8) { facts }
            }
            Text("\(outcome.gradeLabel) · \(outcome.routeName)")
                .font(AppTypography.labelL).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppColor.textPrimary)
        .padding(AppSpacing.space16)
        .background(opaque ? AppColor.surfaceCard : Color.clear)
        .modifier(SessionShelfMaterial(enabled: !opaque))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var facts: some View {
        Label(BoardedFormat.duration(TimeInterval(session.durationSeconds)), systemImage: "clock")
        Label("\(session.attemptCount) attempts", systemImage: "number")
        Label("\(session.sendCount) sends", systemImage: "checkmark.circle")
    }
}

private struct SessionShelfMaterial: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.boardedMaterial(.sessionFactShelf, in: AppRadius.card()) } else { content }
    }
}

struct FeedPostImage: View {
    let url: URL?
    let alt: String

    var body: some View {
        AsyncImage(url: url) { phase in
            if case let .success(image) = phase { image.resizable().aspectRatio(contentMode: .fill) }
            else { ZStack { AppColor.backgroundElevated; ProgressView().tint(AppColor.textSecondary) } }
        }
        .frame(maxWidth: .infinity).aspectRatio(3.0 / 2.0, contentMode: .fit).clipped()
        .accessibilityLabel(alt)
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
