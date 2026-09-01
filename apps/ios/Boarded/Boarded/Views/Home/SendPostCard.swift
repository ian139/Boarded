import SwiftUI

/// Public URL for a send-post image stored in the `social-media` bucket.
enum FeedImageURL {
    static func publicURL(for path: String) -> URL? {
        guard let base = SupabaseConfig.current?.url else { return nil }
        return base.appendingPathComponent("storage/v1/object/public/social-media/\(path)")
    }
}

/// Feed card. The achievement leads: person and time, large serif grade,
/// route name, image, then the reaction controls.
struct SendPostCard: View {
    let item: SendFeedItem
    var onLike: () -> Void = {}
    var showsActions = true

    private var authorName: String { item.author.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? item.author.username?.nonEmpty ?? "Climber" }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            header
            achievement
            if let imagePath = item.imagePath, let url = FeedImageURL.publicURL(for: imagePath) {
                FeedPostImage(url: url, alt: item.imageAlt)
            }
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsActions {
                actions
            }
        }
        .boardedPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("send-post-card")
    }

    private var header: some View {
        HStack(spacing: AppSpacing.space12) {
            BoardedAvatar(name: authorName, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(authorName)
                    .font(AppTypography.labelL)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
                Text(BoardedFormat.relative(item.createdAt))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var achievement: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.space12) {
            Text(item.attempt.gradeLabel)
                .font(AppTypography.displayS)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize()
                .accessibilityLabel("Grade \(item.attempt.gradeLabel)")
            VStack(alignment: .leading, spacing: 2) {
                Text(item.attempt.routeName)
                    .font(AppTypography.bodyL)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(item.attempt.discipline.title) · sent")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.space20) {
            Button(action: onLike) {
                HStack(spacing: AppSpacing.space4) {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                    if item.likeCount > 0 {
                        Text("\(item.likeCount)")
                            .font(AppTypography.labelM)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(item.isLiked ? AppColor.accentDefault : AppColor.textSecondary)
                .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isLiked ? "Unlike" : "Like")
            .accessibilityValue("\(item.likeCount) likes")
            .accessibilityIdentifier("post-like")

            HStack(spacing: AppSpacing.space4) {
                Image(systemName: "bubble.right")
                if item.commentCount > 0 {
                    Text("\(item.commentCount)")
                        .font(AppTypography.labelM)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(AppColor.textSecondary)
            .frame(minHeight: AppLayout.minimumTarget)
            .accessibilityLabel("Comments")
            .accessibilityValue("\(item.commentCount) comments")
            .accessibilityIdentifier("post-comments")

            Spacer(minLength: 0)

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share post")
            .accessibilityIdentifier("post-share")
        }
        .font(AppTypography.labelL)
    }

    private var shareText: String {
        "\(authorName) sent \(item.attempt.gradeLabel) — \(item.attempt.routeName) on Boarded."
    }
}

/// 3:2 post image with slate placeholder and alt-text accessibility.
struct FeedPostImage: View {
    let url: URL
    var alt: String?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder(systemImage: "photo")
            case .empty:
                placeholder(systemImage: nil)
            @unknown default:
                placeholder(systemImage: nil)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .clipShape(AppRadius.card())
        .overlay { AppRadius.card().stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
        .accessibilityLabel(alt ?? "Climbing photo")
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            AppColor.backgroundElevated
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
