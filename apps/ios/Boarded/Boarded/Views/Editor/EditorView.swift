import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum EditorHoldGeometry {
    static let minimumHoldRadius: CGFloat = 8
    static let maximumHoldRadius: CGFloat = 96

    static let maximumInitialImageScale: CGFloat = 1.35

    static func initialImageRect(imageAspectRatio: CGFloat, in size: CGSize) -> CGRect {
        guard imageAspectRatio.isFinite,
              imageAspectRatio > 0,
              size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else {
            return .zero
        }
        let canvasAspectRatio = size.width / size.height
        let fittedSize: CGSize
        if canvasAspectRatio > imageAspectRatio {
            fittedSize = CGSize(width: size.height * imageAspectRatio, height: size.height)
        } else {
            fittedSize = CGSize(width: size.width, height: size.width / imageAspectRatio)
        }
        let fillScale = max(size.width / fittedSize.width, size.height / fittedSize.height)
        let initialScale = min(fillScale, maximumInitialImageScale)
        let initialSize = CGSize(
            width: fittedSize.width * initialScale,
            height: fittedSize.height * initialScale
        )
        return CGRect(
            x: (size.width - initialSize.width) / 2,
            y: (size.height - initialSize.height) / 2,
            width: initialSize.width,
            height: initialSize.height
        )
    }

    static func imagePoint(
        from viewPoint: CGPoint,
        canvasSize: CGSize,
        zoomScale: CGFloat,
        panOffset: CGSize
    ) -> CGPoint? {
        guard viewPoint.x.isFinite,
              viewPoint.y.isFinite,
              canvasSize.width.isFinite,
              canvasSize.height.isFinite,
              canvasSize.width > 0,
              canvasSize.height > 0,
              zoomScale.isFinite,
              zoomScale > 0,
              panOffset.width.isFinite,
              panOffset.height.isFinite else {
            return nil
        }
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let point = CGPoint(
            x: ((viewPoint.x - center.x - panOffset.width) / zoomScale) + center.x,
            y: ((viewPoint.y - center.y - panOffset.height) / zoomScale) + center.y
        )
        return point.x.isFinite && point.y.isFinite ? point : nil
    }

    static func radius(from center: CGPoint, to point: CGPoint) -> CGFloat? {
        guard center.x.isFinite, center.y.isFinite, point.x.isFinite, point.y.isFinite else {
            return nil
        }
        let distance = hypot(point.x - center.x, point.y - center.y)
        return distance.isFinite ? distance : nil
    }

    static func clampedRadius(_ radius: CGFloat) -> CGFloat? {
        guard radius.isFinite else { return nil }
        return min(max(radius, minimumHoldRadius), maximumHoldRadius)
    }

    static func scaledRadius(_ radius: CGFloat, magnification: CGFloat) -> CGFloat? {
        guard radius.isFinite,
              radius > 0,
              magnification.isFinite,
              magnification > 0 else {
            return nil
        }
        return clampedRadius(radius * magnification)
    }

    static func defaultRadius(for size: HoldSize) -> CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 12
        case .large: return 18
        }
    }
}
enum EditorHoldInteraction {
    static let defaultType: HoldType = .start

    static func nextType(after type: HoldType) -> HoldType? {
        switch type {
        case .start: return .hand
        case .hand: return .foot
        case .foot: return .finish
        case .finish: return nil
        }
    }
}
private struct EditorHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct EditorCanvasInteractionShape: Shape {
    let topInset: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = min(max(topInset, 0), rect.height)
        guard inset < rect.height else { return Path() }
        return Path(
            CGRect(
                x: rect.minX,
                y: rect.minY + inset,
                width: rect.width,
                height: rect.height - inset
            )
        )
    }
}



private enum TopoPresentationMode {
    case browse
    case edit
}

struct EditorView: View {
    let routeToEdit: Route?
    let onRouteUpdated: (Route) -> Void

    @EnvironmentObject var session: AppSession
    @EnvironmentObject var routesViewModel: RoutesViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var wallsViewModel: WallsViewModel
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var presentationMode: TopoPresentationMode
    @State private var selectedHoldID: String?
    @FocusState private var focusedHoldID: String?
    @State private var holds: [Hold] = []
    @State private var routeName = ""
    @State private var routeGrade: String? = nil
    @State private var isSavePresented = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String? = nil
    @State private var isWallPickerPresented = false
    @State private var zoomScale: CGFloat = 1
    @State private var lastZoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var acceptedWallID: String? = nil
    @State private var pendingWallID: String? = nil
    @State private var isApplyingWallSelection = false
    @State private var hasPendingWallSelection = false
    @State private var isWallSwitchConfirmationPresented = false
    @State private var wallImageState: WallImageState = .none
    @State private var imageReloadID = UUID()
    @State private var isGestureInProgress = false
    @State private var suppressNextCanvasTap = false
    @State private var suppressNextMarkerTap = false
    @State private var didPan = false
    @State private var isCanvasMagnificationActive = false
    @State private var canvasTapSuppressionGeneration = 0
    @State private var markerTapSuppressionGeneration = 0
    @State private var isRefreshingWallMetadata = false
    @State private var wallMetadataRefreshGeneration = 0
    @State private var loadedWallAspectRatio: CGFloat? = nil
    @State private var wallAspectRequestID: UUID? = nil
    @State private var headerHeight: CGFloat = 0

    @State private var markerMagnificationSession: MarkerMagnificationSession?

    private struct MarkerMagnificationSession {
        let id: String
        let originalRadius: CGFloat
    }

    init() {
        self.init(
            routeToEdit: nil,
            onRouteUpdated: { _ in },
            wallsRepository: AppServices.wallsRepository
        )
    }

    init(
        routeToEdit: Route?,
        onRouteUpdated: @escaping (Route) -> Void,
        wallsRepository: any WallsRepository = AppServices.wallsRepository
    ) {
        self.routeToEdit = routeToEdit
        self.onRouteUpdated = onRouteUpdated
        _wallsViewModel = StateObject(wrappedValue: WallsViewModel(repository: wallsRepository))
        _presentationMode = State(initialValue: .edit)
        _holds = State(initialValue: routeToEdit?.holds ?? [])
        _routeName = State(initialValue: routeToEdit?.name ?? "")
        _routeGrade = State(initialValue: routeToEdit?.gradeV)
        _acceptedWallID = State(initialValue: routeToEdit?.wallId)
        _isApplyingWallSelection = State(initialValue: routeToEdit != nil)
    }


    private enum WallImageState: Equatable {
        case none
        case loading
        case ready
        case failed
    }

    var body: some View {
        let theme = BoardedTheme()
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                canvasSurface(size: proxy.size, headerHeight: headerHeight)
            }
            .ignoresSafeArea(.container, edges: .bottom)

            let headerShape = UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: theme.controlCornerRadius,
                bottomTrailingRadius: theme.controlCornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )

            header
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: EditorHeaderHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                    }
                )
                .background {
                    Color.clear
                        .boardedGlassSurface(in: headerShape)
                        .ignoresSafeArea(.container, edges: .top)
                }
                .overlay(alignment: .bottom) {
                    theme.primaryText.opacity(0.12).frame(height: 1)
                }
                .zIndex(2000)

            if zoomScale > 1.01 || abs(panOffset.width) > 0.5 || abs(panOffset.height) > 0.5 {
                zoomControls
                    .padding(.top, headerHeight + 10)
                    .padding(.horizontal, 10)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(2001)
            }
        }
        .boardedPageBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !holds.isEmpty {
                topoNodeActionList
            }
        }
        .sheet(isPresented: $isSavePresented) {
            SaveRouteSheet(
                routeName: $routeName,
                routeGrade: $routeGrade,
                holdsCount: holds.count,
                isEditing: routeToEdit != nil,
                isSaving: isSaving,
                errorMessage: saveErrorMessage,
                onSave: { await saveRoute() },
                onCancel: { isSavePresented = false }
            )
        }
        .confirmationDialog(
            "Switch walls?",
            isPresented: $isWallSwitchConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Switch and Clear Holds", role: .destructive) {
                confirmWallSwitch()
            }
            Button("Cancel", role: .cancel) {
                pendingWallID = nil
                hasPendingWallSelection = false
            }
        } message: {
            Text("Existing holds will be cleared because their positions belong to the current wall.")
        }
        .onChange(of: wallsViewModel.selectedWallId) { _, newValue in
            handleWallSelectionChange(newValue)
        }
        .onChange(of: wallsViewModel.wallImageRevision) { _, _ in
            resetWallImageState(for: acceptedWallID)
        }
        .onChange(of: imageReloadID) { _, _ in
            guard selectedWall != nil else {
                wallImageState = .none
                return
            }
            if selectedWallImageURL == nil {
                updateWallImageState(.failed, requestID: imageReloadID)
            } else {
                wallImageState = .loading
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallImageDidChange)) { notification in
            guard presentationMode == .edit,
                  let wallID = notification.object as? String,
                  wallID == acceptedWallID else { return }
            holds.removeAll()
            announce("Wall image changed. Holds cleared.")
            resetZoom(animated: false)
            refreshWallMetadata()
        }
        .onChange(of: presentationMode) { _, mode in
            selectedHoldID = nil
            focusedHoldID = nil
            if mode == .browse {
                resetZoom()
            }
        }
        .onChange(of: holds) { _, updatedHolds in
            guard let selectedHoldID,
                  updatedHolds.contains(where: { $0.id == selectedHoldID }) else {
                self.selectedHoldID = nil
                return
            }
        }
        .onPreferenceChange(EditorHeaderHeightPreferenceKey.self) { measuredHeight in
            let clampedHeight = max(0, measuredHeight)
            if abs(headerHeight - clampedHeight) > 0.5 {
                headerHeight = clampedHeight
            }
        }
        .task {
            isApplyingWallSelection = routeToEdit != nil
            await wallsViewModel.load(userId: session.userId)
            if let routeToEdit {
                wallsViewModel.restoreWallSelection(id: routeToEdit.wallId)
                acceptedWallID = routeToEdit.wallId
            } else {
                acceptedWallID = wallsViewModel.selectedWallId
            }
            isApplyingWallSelection = false
            resetWallImageState(for: acceptedWallID)
        }
    }

    private var zoomControls: some View {
        HStack {
            Text("\(zoomPercentage)%")
                .font(AppTypography.label)
                .foregroundColor(AppColor.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .boardedGlassSurface(in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Wall zoom")
                .accessibilityValue("\(zoomPercentage) percent")

            Spacer()

            Button("Reset") {
                resetZoom()
            }
            .font(AppTypography.label)
            .foregroundColor(AppColor.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minWidth: 44, minHeight: 44)
            .boardedGlassSurface(in: Capsule(), interactive: true)
            .accessibilityLabel("Reset wall zoom")
            .accessibilityHint("Returns the wall to 100 percent and centers it.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.space12) {
                    headerTitle
                    if presentationMode == .edit {
                        wallPickerButton
                    }
                    holdCountView
                    Spacer(minLength: AppSpacing.space4)
                    modeActionButton
                    if presentationMode == .edit {
                        saveButton
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.space8) {
                    HStack(spacing: AppSpacing.space8) {
                        headerTitle
                        Spacer(minLength: AppSpacing.space4)
                        modeActionButton
                    }
                    HStack(spacing: AppSpacing.space8) {
                        if presentationMode == .edit {
                            wallPickerButton
                        }
                        holdCountView
                        Spacer(minLength: AppSpacing.space4)
                        if presentationMode == .edit {
                            saveButton
                        }
                    }
                }
            }

            if presentationMode == .browse {
                Text("Select any topo node to inspect its type, position, and route order.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.vertical, AppSpacing.space8)
        .frame(maxWidth: AppLayout.editorMaxWidth)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $isWallPickerPresented, onDismiss: {
            presentPendingWallSwitchIfPossible()
        }) {
            WallPickerView(
                viewModel: wallsViewModel,
                canSaveWallEdit: { wall, imageURL, imageData in
                    guard wall.id == acceptedWallID, !holds.isEmpty else { return true }
                    guard imageData == nil else { return false }
                    return normalizedRemoteImageURLString(wall.imageUrl)
                        == normalizedRemoteImageURLString(imageURL)
                }
            )
            .environmentObject(session)
        }
    }

    private var modeActionButton: some View {
        Button {
            presentationMode = presentationMode == .browse ? .edit : .browse
        } label: {
            Label(
                presentationMode == .browse ? "Edit route" : "Browse topo",
                systemImage: presentationMode == .browse ? "pencil" : "eye"
            )
            .font(AppTypography.label)
            .frame(minHeight: AppLayout.minimumControlHeight)
            .padding(.horizontal, AppSpacing.space12)
            .foregroundStyle(presentationMode == .browse ? AppColor.accentOnAccent : AppColor.textPrimary)
            .background(
                presentationMode == .browse ? AppColor.accentDefault : AppColor.backgroundElevated,
                in: Capsule()
            )
            .overlay {
                if presentationMode == .edit {
                    Capsule().stroke(AppColor.strokeDefault, lineWidth: AppStroke.hairline)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            presentationMode == .browse
                ? "Enters edit mode. Changes are not saved until you choose Save."
                : "Shows the route without editing controls."
        )
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(presentationMode == .browse ? (routeName.isEmpty ? "Topo" : routeName) : "Route editor")
                .font(presentationMode == .browse ? AppTypography.display : AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.8)
            if presentationMode == .browse, let routeGrade {
                Text(routeGrade)
                    .font(AppTypography.label)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var wallPickerButton: some View {
        Button {
            isWallPickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.3.offgrid")
                    .font(.system(size: 12, weight: .semibold))
                Text(selectedWallName)
                    .font(AppTypography.label)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(AppColor.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Select wall")
        .accessibilityValue(selectedWall?.name ?? "No wall selected")
    }

    private var holdCountView: some View {
        Text("\(holds.count) \(holds.count == 1 ? "hold" : "holds")")
            .font(AppTypography.label)
            .foregroundColor(AppColor.muted)
            .lineLimit(1)
            .accessibilityLabel("Hold count")
            .accessibilityValue("\(holds.count)")
    }

    private var saveButton: some View {
        Button {
            saveErrorMessage = nil
            isSavePresented = true
        } label: {
            Text("Save")
                .font(AppTypography.label)
                .foregroundColor(AppColor.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColor.primary.opacity(0.12))
                .clipShape(Capsule())
        }
        .disabled(holds.isEmpty || !wallIsUsable)
        .opacity((holds.isEmpty || !wallIsUsable) ? 0.4 : 1)
        .accessibilityLabel("Save")
        .accessibilityHint("Saves this route.")
        .accessibilityIdentifier("Editor save route")
    }

    private func canvasSurface(size: CGSize, headerHeight: CGFloat) -> some View {
        let imageRect = EditorHoldGeometry.initialImageRect(imageAspectRatio: wallAspectRatio, in: size)
        let reservedHeaderHeight = min(max(headerHeight, 0), size.height)
        let interactionRect = CGRect(
            x: 0,
            y: reservedHeaderHeight,
            width: size.width,
            height: max(0, size.height - reservedHeaderHeight)
        )
        let theme = BoardedTheme()

        return ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(EditorCanvasInteractionShape(topInset: reservedHeaderHeight))
                .frame(width: size.width, height: size.height)
                .zIndex(0)
                .simultaneousGesture(dragGesture(in: size, imageRect: imageRect))
                .accessibilityElement()
                .accessibilityIdentifier("Editor canvas surface")
                .accessibilityLabel(presentationMode == .browse ? "Topo wall" : "Wall editor")
                .accessibilityValue(canvasAccessibilityValue)
                .accessibilityHint(
                    presentationMode == .browse
                        ? "Explore the route nodes below. Drag to pan and pinch to zoom."
                        : "Activate to add a Start hold at the wall center. Drag to pan and pinch to zoom."
                )
                .accessibilityAction {
                    guard presentationMode == .edit, wallIsUsable else { return }
                    let viewPoint = CGPoint(
                        x: size.width / 2,
                        y: max(reservedHeaderHeight + 1, size.height / 2)
                    )
                    guard interactionRect.contains(viewPoint),
                          let imagePoint = EditorHoldGeometry.imagePoint(
                              from: viewPoint,
                              canvasSize: size,
                              zoomScale: zoomScale,
                              panOffset: panOffset
                          ),
                          imageRect.contains(imagePoint) else {
                        return
                    }
                    placeHold(
                        at: imagePoint,
                        in: imageRect,
                        type: EditorHoldInteraction.defaultType
                    )
                }

            wallImage(in: imageRect)
                .frame(width: size.width, height: size.height)
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .allowsHitTesting(false)
                .zIndex(1)
            if presentationMode == .browse, holds.count > 1 {
                topoRouteTrace(in: imageRect)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .allowsHitTesting(false)
                    .zIndex(1.75)
            }

            if holds.isEmpty && wallIsUsable {
                emptyCanvasReadabilityTint
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .allowsHitTesting(false)
                    .zIndex(1.5)
            }

            ZStack {
                ForEach(Array(holds.enumerated()), id: \.element.id) { index, hold in
                    markerButton(
                        for: hold,
                        index: index,
                        imageRect: imageRect,
                        canvasSize: size,
                        headerHeight: reservedHeaderHeight
                    )
                    .zIndex(Double(index + 2))
                    .allowsHitTesting(
                        wallIsUsable
                            && markerCanReceiveInput(
                                for: hold,
                                imageRect: imageRect,
                                canvasSize: size,
                                headerHeight: reservedHeaderHeight
                            )
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(zoomScale)
            .offset(panOffset)
            .zIndex(2)

            if reservedHeaderHeight > 0 {
                Color.clear
                    .frame(width: size.width, height: reservedHeaderHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .zIndex(100)
            }

            if selectedWall == nil {
                noWallPanel
                    .zIndex(2000)
            } else if wallImageState == .loading {
                loadingPanel
                    .zIndex(2000)
            } else if wallImageState == .failed {
                failedImagePanel
                    .zIndex(2000)
            } else if holds.isEmpty {
                emptyWallPanel
                    .zIndex(2000)
                    .allowsHitTesting(false)
            }


        }
        .contentShape(EditorCanvasInteractionShape(topInset: reservedHeaderHeight))
        .highPriorityGesture(
            magnificationGesture(
                in: size,
                imageRect: imageRect,
                headerHeight: reservedHeaderHeight
            )
        )
        .simultaneousGesture(
            spatialTapGesture(
                in: size,
                imageRect: imageRect,
                headerHeight: reservedHeaderHeight
            )
        )
        .coordinateSpace(name: "editorCanvas")
    }

    private func topoRouteTrace(in imageRect: CGRect) -> some View {
        Path { path in
            guard let first = holds.first else { return }
            path.move(
                to: CGPoint(
                    x: imageRect.minX + first.normalizedX * imageRect.width,
                    y: imageRect.minY + first.normalizedY * imageRect.height
                )
            )
            for hold in holds.dropFirst() {
                path.addLine(
                    to: CGPoint(
                        x: imageRect.minX + hold.normalizedX * imageRect.width,
                        y: imageRect.minY + hold.normalizedY * imageRect.height
                    )
                )
            }
        }
        .stroke(
            AppColor.textPrimary,
            style: StrokeStyle(
                lineWidth: differentiateWithoutColor ? AppStroke.focus : AppStroke.hairline + 1,
                lineCap: .round,
                lineJoin: .round,
                dash: differentiateWithoutColor ? [AppSpacing.space8, AppSpacing.space4] : []
            )
        )
        .shadow(color: AppColor.backgroundBase.opacity(0.72), radius: AppSpacing.space4)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func wallImage(in rect: CGRect) -> some View {
        #if DEBUG
        let isFixtureImage = isFixtureWallImage(for: selectedWall?.id)
        #else
        let isFixtureImage = false
        #endif
        if isFixtureImage {
            Image("DefaultWall")
                .resizable()
                .scaledToFill()
                .frame(width: rect.width, height: rect.height)
                .onAppear { wallImageState = .ready }
        } else if let url = selectedWallImageURL {
            let requestID = imageReloadID
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.clear
                        .frame(width: rect.width, height: rect.height)
                        .onAppear { updateWallImageState(.loading, requestID: requestID) }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: rect.width, height: rect.height)
                        .onAppear { prepareWallImage(url: url, requestID: requestID) }
                case .failure:
                    Color.clear
                        .frame(width: rect.width, height: rect.height)
                        .onAppear { updateWallImageState(.failed, requestID: requestID) }
                @unknown default:
                    Color.clear
                        .frame(width: rect.width, height: rect.height)
                        .onAppear { updateWallImageState(.failed, requestID: requestID) }
                }
            }
            .id(imageReloadID)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
        } else {
            Color.clear
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
                .onAppear {
                    wallImageState = selectedWall == nil ? .none : .failed
                }
        }
    }

    private var placeholderWall: some View {
        Image("DefaultWall")
            .resizable()
            .scaledToFit()
    }

    private var noWallPanel: some View {
        VStack(spacing: 8) {
            Button {
                isWallPickerPresented = true
            } label: {
                Text("Select a wall")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColor.primary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select a wall")
            .accessibilityHint("Opens the wall picker.")

            Text("Choose a wall above to start setting.")
                .font(AppTypography.label)
                .foregroundColor(AppColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .boardedGlassSurface(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loadingPanel: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(AppColor.primary)
            Text("Loading wall…")
                .font(AppTypography.label)
                .foregroundColor(AppColor.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .boardedGlassSurface(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var failedImagePanel: some View {
        ZStack {
            placeholderWall
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                Text("Wall image couldn’t load.")
                    .font(AppTypography.label)
                    .foregroundColor(AppColor.text)
                Button("Retry") {
                    retryWallImage()
                }
                .font(AppTypography.label)
                .foregroundColor(AppColor.primary)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 10)
                .boardedGlassSurface(in: Capsule(), interactive: true)
                .accessibilityLabel("Retry wall image")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .boardedGlassSurface(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyWallPanel: some View {
        VStack(spacing: 8) {
            Text("Tap the wall to add a Start hold")
                .font(AppTypography.headline)
                .foregroundColor(AppColor.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Drag to pan when the wall overflows. Pinch to zoom. Tap a hold to cycle its type.")
                .font(AppTypography.label)
                .foregroundColor(AppColor.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            BoardedTheme().panelBackground,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }






    private var selectedHold: Hold? {
        guard let selectedHoldID else { return nil }
        return holds.first(where: { $0.id == selectedHoldID })
    }

    private var topoNodeActionList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            nodeSelectionMenu
            if let selectedHold {
                if presentationMode == .browse {
                    nodeInspection(for: selectedHold)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppSpacing.space8) {
                            nodeEditMenu(for: selectedHold)
                            nodeMoveMenu(for: selectedHold)
                            nodeOrderControls(for: selectedHold)
                            Spacer(minLength: AppSpacing.space4)
                            deleteNodeButton(selectedHold)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.space8) {
                            HStack(spacing: AppSpacing.space8) {
                                nodeEditMenu(for: selectedHold)
                                nodeMoveMenu(for: selectedHold)
                            }
                            HStack(spacing: AppSpacing.space8) {
                                nodeOrderControls(for: selectedHold)
                                Spacer(minLength: AppSpacing.space4)
                                deleteNodeButton(selectedHold)
                            }
                        }
                    }
                }
            } else {
                nodeGuidance
            }
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.vertical, AppSpacing.space12)
        .background(AppColor.backgroundElevated)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColor.strokeSubtle).frame(height: AppStroke.hairline)
        }
        .accessibilityElement(children: .contain)
    }

    private func nodeInspection(for hold: Hold) -> some View {
        Text(
            "\(typeDisplayName(hold.type)) · Route position \(nodeNumber(for: hold.id)) of \(holds.count) · "
                + "\(Int(hold.x.rounded())) percent x, \(Int(hold.y.rounded())) percent y"
        )
        .font(AppTypography.body)
        .foregroundStyle(AppColor.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(
            "\(typeDisplayName(hold.type)). Route position \(nodeNumber(for: hold.id)) of \(holds.count). "
                + "\(Int(hold.x.rounded())) percent x, \(Int(hold.y.rounded())) percent y."
        )
    }

    private var nodeSelectionMenu: some View {
        Menu {
            ForEach(Array(holds.enumerated()), id: \.element.id) { index, hold in
                Button {
                    selectHold(hold.id)
                } label: {
                    Label(
                        "Node \(index + 1), \(typeDisplayName(hold.type))",
                        systemImage: selectedHoldID == hold.id ? "checkmark.circle.fill" : nodeSymbol(for: hold.type)
                    )
                }
            }
        } label: {
            Label(
                selectedHold.map { "Node \(nodeNumber(for: $0.id))" } ?? "Select node",
                systemImage: selectedHold == nil ? "list.number" : "checkmark.circle.fill"
            )
            .font(AppTypography.label)
            .frame(minHeight: AppLayout.minimumControlHeight)
            .padding(.horizontal, AppSpacing.space12)
        }
        .foregroundStyle(selectedHold == nil ? AppColor.textPrimary : AppColor.accentDefault)
        .boardedGlassSurface(in: Capsule(), interactive: true)
        .accessibilityLabel("Select topo node")
        .accessibilityValue(selectedHold.map { "Node \(nodeNumber(for: $0.id)), \(typeDisplayName($0.type))" } ?? "None selected")
    }

    private var nodeGuidance: some View {
        Text(
            presentationMode == .browse
                ? "Select a node to inspect its details."
                : "Select a node to edit its type, position, route order, or delete it."
        )
        .font(AppTypography.body)
        .foregroundStyle(AppColor.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func nodeEditMenu(for hold: Hold) -> some View {
        Menu {
            ForEach(HoldType.allCases, id: \.self) { type in
                Button {
                    setHoldType(id: hold.id, type: type)
                } label: {
                    Label(typeDisplayName(type), systemImage: hold.type == type ? "checkmark" : nodeSymbol(for: type))
                }
            }
        } label: {
            Label("Edit", systemImage: "pencil")
                .font(AppTypography.label)
                .frame(minHeight: AppLayout.minimumControlHeight)
                .padding(.horizontal, AppSpacing.space12)
        }
        .foregroundStyle(AppColor.textPrimary)
        .boardedGlassSurface(in: Capsule(), interactive: true)
        .accessibilityLabel("Edit node \(nodeNumber(for: hold.id)) type")
        .accessibilityValue(typeDisplayName(hold.type))
    }

    private func nodeMoveMenu(for hold: Hold) -> some View {
        Menu {
            Button("Move up", systemImage: "arrow.up") { moveHold(id: hold.id, x: 0, y: -5) }
            Button("Move down", systemImage: "arrow.down") { moveHold(id: hold.id, x: 0, y: 5) }
            Button("Move left", systemImage: "arrow.left") { moveHold(id: hold.id, x: -5, y: 0) }
            Button("Move right", systemImage: "arrow.right") { moveHold(id: hold.id, x: 5, y: 0) }
        } label: {
            Label("Move", systemImage: "move.3d")
                .font(AppTypography.label)
                .frame(minHeight: AppLayout.minimumControlHeight)
                .padding(.horizontal, AppSpacing.space12)
        }
        .foregroundStyle(AppColor.textPrimary)
        .boardedGlassSurface(in: Capsule(), interactive: true)
        .accessibilityLabel("Move node \(nodeNumber(for: hold.id))")
        .accessibilityHint("Moves the node five percent in a chosen direction.")
    }

    private func nodeOrderControls(for hold: Hold) -> some View {
        let index = holds.firstIndex(where: { $0.id == hold.id }) ?? holds.startIndex
        return HStack(spacing: AppSpacing.space4) {
            nodeOrderButton(title: "Earlier", image: "arrow.left", disabled: index == holds.startIndex) {
                reorderHold(id: hold.id, offset: -1)
            }
            nodeOrderButton(title: "Later", image: "arrow.right", disabled: index == holds.index(before: holds.endIndex)) {
                reorderHold(id: hold.id, offset: 1)
            }
        }
    }

    private func nodeOrderButton(title: String, image: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .frame(minWidth: AppLayout.minimumControlHeight, minHeight: AppLayout.minimumControlHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? AppColor.textDisabled : AppColor.textPrimary)
        .boardedGlassSurface(in: Circle(), interactive: true)
        .disabled(disabled)
        .accessibilityLabel("\(title) in route order")
    }

    private func deleteNodeButton(_ hold: Hold) -> some View {
        Button(role: .destructive) {
            deleteHold(id: hold.id)
        } label: {
            Label("Delete", systemImage: "trash")
                .font(AppTypography.label)
                .frame(minHeight: AppLayout.minimumControlHeight)
                .padding(.horizontal, AppSpacing.space12)
        }
        .foregroundStyle(AppColor.danger)
        .boardedGlassSurface(in: Capsule(), interactive: true)
        .accessibilityLabel("Delete node \(nodeNumber(for: hold.id))")
    }

    private func selectHold(_ id: String) {
        selectedHoldID = id
        focusedHoldID = id
        announce("Node \(nodeNumber(for: id)) selected.")
    }

    private func setHoldType(id: String, type: HoldType) {
        guard presentationMode == .edit,
              let index = holds.firstIndex(where: { $0.id == id }) else { return }
        holds[index].type = type
        holds[index].color = type.colorHex
        announce("Node \(index + 1) changed to \(typeDisplayName(type).lowercased()).")
    }

    private func reorderHold(id: String, offset: Int) {
        guard presentationMode == .edit,
              let index = holds.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard holds.indices.contains(destination) else { return }
        holds.swapAt(index, destination)
        announce("Node moved to position \(destination + 1).")
    }

    private func moveHold(id: String, x: Double, y: Double) {
        guard presentationMode == .edit,
              let index = holds.firstIndex(where: { $0.id == id }) else { return }
        holds[index].x = min(100, max(0, holds[index].x + x))
        holds[index].y = min(100, max(0, holds[index].y + y))
        announce("Node \(index + 1) moved to \(Int(holds[index].x.rounded())) percent x, \(Int(holds[index].y.rounded())) percent y.")
    }

    private func deleteHold(id: String) {
        guard presentationMode == .edit,
              let index = holds.firstIndex(where: { $0.id == id }) else { return }
        holds.remove(at: index)
        selectedHoldID = nil
        focusedHoldID = nil
        announce("Node \(index + 1) deleted.")
    }

    private func nodeNumber(for id: String) -> Int {
        (holds.firstIndex(where: { $0.id == id }) ?? 0) + 1
    }

    private func nodeSymbol(for type: HoldType) -> String {
        switch type {
        case .start: return "play.fill"
        case .hand: return "hand.raised.fill"
        case .foot: return "shoeprints.fill"
        case .finish: return "flag.checkered"
        }
    }

    private func markerButton(
        for hold: Hold,
        index: Int,
        imageRect: CGRect,
        canvasSize: CGSize,
        headerHeight: CGFloat
    ) -> some View {
        let minimumTargetSize = 44 / max(zoomScale, 1)
        let targetSize = max(minimumTargetSize, holdDiameterValue(hold))
        let canReceiveInput = markerCanReceiveInput(
            for: hold,
            imageRect: imageRect,
            canvasSize: canvasSize,
            headerHeight: headerHeight
        )

        return Button {
            handleMarkerTap(id: hold.id)
        } label: {
            holdView(for: hold, isSelected: selectedHoldID == hold.id)
                .frame(width: targetSize, height: targetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedHoldID, equals: hold.id)
        .frame(width: targetSize, height: targetSize)
        .position(
            x: imageRect.minX + hold.normalizedX * imageRect.width,
            y: imageRect.minY + hold.normalizedY * imageRect.height
        )
        .simultaneousGesture(
            dragGesture(in: canvasSize, imageRect: imageRect, suppressMarkerTap: true)
        )
        .simultaneousGesture(markerMagnificationGesture(id: hold.id))
        .zIndex(Double(index + 2))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Editor hold \(index + 1)")
        .accessibilityLabel("Node \(index + 1), \(markerAccessibilityLabel(for: hold))")
        .accessibilityValue("\(selectedHoldID == hold.id ? "Selected, " : "")\(Int(hold.x.rounded())) percent x, \(Int(hold.y.rounded())) percent y, \(Int(holdRadiusValue(hold).rounded())) image points")
        .accessibilityHint(presentationMode == .browse ? "Selects this node for inspection." : "Activates the next hold type. Adjust to resize.")
        .accessibilityAddTraits(selectedHoldID == hold.id ? .isSelected : [])
        .accessibilityHidden(!wallIsUsable || !canReceiveInput)
        .accessibilityAdjustableAction { direction in
            guard presentationMode == .edit else { return }
            adjustHoldRadius(id: hold.id, direction: direction)
        }
    }

    private func markerCanReceiveInput(
        for hold: Hold,
        imageRect: CGRect,
        canvasSize: CGSize,
        headerHeight: CGFloat
    ) -> Bool {
        let markerCenter = CGPoint(
            x: imageRect.minX + hold.normalizedX * imageRect.width,
            y: imageRect.minY + hold.normalizedY * imageRect.height
        )
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let transformedCenter = CGPoint(
            x: (markerCenter.x - canvasCenter.x) * zoomScale + canvasCenter.x + panOffset.width,
            y: (markerCenter.y - canvasCenter.y) * zoomScale + canvasCenter.y + panOffset.height
        )
        let targetSize = max(44 / max(zoomScale, 1), holdDiameterValue(hold))
        let targetRadius = targetSize * zoomScale / 2
        return transformedCenter.y - targetRadius >= max(0, headerHeight)
    }

    private func handleMarkerTap(id: String) {
        guard wallIsUsable, !isGestureInProgress else { return }
        if suppressNextMarkerTap {
            suppressNextMarkerTap = false
            return
        }
        if presentationMode == .browse {
            selectHold(id)
            return
        }
        guard let index = holds.firstIndex(where: { $0.id == id }) else { return }
        let currentType = holds[index].type
        guard let nextType = EditorHoldInteraction.nextType(after: currentType) else {
            holds.remove(at: index)
            announce("Finish hold deleted.")
            return
        }
        holds[index].type = nextType
        holds[index].color = nextType.colorHex
        announce("Hold changed to \(typeDisplayName(nextType).lowercased()).")
    }

    private func holdView(for hold: Hold, isSelected: Bool) -> some View {
        let size = holdDiameterValue(hold)
        let holdColor = Color.hex(hold.type.colorHex)

        return ZStack {
            Circle()
                .stroke(
                    isSelected ? AppColor.accentDefault : holdColor,
                    lineWidth: isSelected ? AppStroke.focus : AppStroke.hairline + 2
                )
                .background(
                    Circle().fill(isSelected ? AppColor.surfaceSelected : AppColor.backgroundBase.opacity(0.72))
                )
                .overlay {
                    if isSelected && differentiateWithoutColor {
                        Circle()
                            .stroke(
                                AppColor.textPrimary,
                                style: StrokeStyle(lineWidth: AppStroke.hairline, dash: [AppSpacing.space4])
                            )
                            .padding(-AppSpacing.space4)
                    }
                }
                .frame(width: size, height: size)

            Image(systemName: nodeSymbol(for: hold.type))
                .font(.system(size: max(8, size * 0.35), weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
        }
    }


    private func updateMarkerMagnification(id: String, magnification: CGFloat) {
        guard presentationMode == .edit,
              wallIsUsable,
              let index = holds.firstIndex(where: { $0.id == id }) else {
            return
        }
        if markerMagnificationSession == nil {
            markerMagnificationSession = MarkerMagnificationSession(
                id: id,
                originalRadius: holdRadiusValue(holds[index])
            )
            isGestureInProgress = true
            suppressNextCanvasTap = true
        }
        guard let session = markerMagnificationSession,
              session.id == id,
              let radius = EditorHoldGeometry.scaledRadius(
                session.originalRadius,
                magnification: magnification
              ) else {
            return
        }
        holds[index].radius = Double(radius)
    }

    private func finishMarkerMagnification(id: String) {
        guard markerMagnificationSession?.id == id else { return }
        markerMagnificationSession = nil
        isGestureInProgress = false
        suppressNextCanvasTap = true
        scheduleCanvasTapSuppressionClear()
        suppressNextMarkerTap = true
        scheduleMarkerTapSuppressionClear()
    }


    private func adjustHoldRadius(
        id: String,
        direction: AccessibilityAdjustmentDirection
    ) {
        guard presentationMode == .edit,
              wallIsUsable,
              let index = holds.firstIndex(where: { $0.id == id }) else { return }
        let current = holdRadiusValue(holds[index])
        let delta: CGFloat = direction == .increment ? 4 : -4
        guard let radius = EditorHoldGeometry.clampedRadius(current + delta) else { return }
        holds[index].radius = Double(radius)
        announce("Hold radius \(Int(radius.rounded())) image points.")
    }

    private func markerMagnificationGesture(id: String) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                updateMarkerMagnification(id: id, magnification: value.magnification)
            }
            .onEnded { _ in
                finishMarkerMagnification(id: id)
            }
    }

    private func magnificationGesture(
        in size: CGSize,
        imageRect: CGRect,
        headerHeight: CGFloat
    ) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if let session = markerMagnificationSession {
                    updateMarkerMagnification(
                        id: session.id,
                        magnification: value.magnification
                    )
                } else if presentationMode == .edit,
                          let touchedHold = hold(
                              at: value.startLocation,
                              in: size,
                              imageRect: imageRect,
                              headerHeight: headerHeight
                          ) {
                    updateMarkerMagnification(
                        id: touchedHold.id,
                        magnification: value.magnification
                    )
                } else {
                    updateCanvasMagnification(
                        value.magnification,
                        in: size,
                        imageRect: imageRect
                    )
                }
            }
            .onEnded { _ in
                if let session = markerMagnificationSession {
                    finishMarkerMagnification(id: session.id)
                } else {
                    finishCanvasMagnification(in: size, imageRect: imageRect)
                }
            }
    }

    private func updateCanvasMagnification(
        _ magnification: CGFloat,
        in size: CGSize,
        imageRect: CGRect
    ) {
        guard wallIsUsable else { return }
        isCanvasMagnificationActive = true
        isGestureInProgress = true
        suppressNextCanvasTap = true
        let nextScale = min(4, max(1, lastZoomScale * magnification))
        zoomScale = nextScale
        panOffset = clampedPanOffset(
            panOffset,
            in: size,
            scale: nextScale,
            imageRect: imageRect
        )
    }

    private func finishCanvasMagnification(in size: CGSize, imageRect: CGRect) {
        guard isCanvasMagnificationActive else { return }
        if zoomScale <= 1.01 {
            resetZoom(animated: false)
        } else {
            zoomScale = min(4, max(1, zoomScale))
            panOffset = clampedPanOffset(
                panOffset,
                in: size,
                scale: zoomScale,
                imageRect: imageRect
            )
            lastZoomScale = zoomScale
            lastPanOffset = panOffset
        }
        isCanvasMagnificationActive = false
        isGestureInProgress = false
        suppressNextCanvasTap = true
        scheduleCanvasTapSuppressionClear()
    }

    private func dragGesture(
        in size: CGSize,
        imageRect: CGRect,
        suppressMarkerTap: Bool = false
    ) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                updateCanvasDrag(
                    translation: value.translation,
                    in: size,
                    imageRect: imageRect
                )
            }
            .onEnded { _ in
                finishCanvasDrag(suppressMarkerTap: suppressMarkerTap)
            }
    }

    private func updateCanvasDrag(
        translation: CGSize,
        in size: CGSize,
        imageRect: CGRect
    ) {
        guard markerMagnificationSession == nil,
              !isCanvasMagnificationActive,
              imageRect.width * zoomScale > size.width + 0.5
                || imageRect.height * zoomScale > size.height + 0.5 else { return }
        didPan = true
        isGestureInProgress = true
        let proposed = CGSize(
            width: lastPanOffset.width + translation.width,
            height: lastPanOffset.height + translation.height
        )
        panOffset = clampedPanOffset(
            proposed,
            in: size,
            scale: zoomScale,
            imageRect: imageRect
        )
    }

    private func finishCanvasDrag(suppressMarkerTap: Bool) {
        guard didPan else { return }
        if suppressMarkerTap {
            suppressNextMarkerTap = true
            scheduleMarkerTapSuppressionClear()
        }
        lastPanOffset = panOffset
        didPan = false
        isGestureInProgress = false
        suppressNextCanvasTap = true
        scheduleCanvasTapSuppressionClear()
    }

    private func spatialTapGesture(
        in size: CGSize,
        imageRect: CGRect,
        headerHeight: CGFloat
    ) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                handleCanvasTap(
                    at: value.location,
                    in: size,
                    imageRect: imageRect,
                    headerHeight: headerHeight
                )
            }
    }

    private func handleCanvasTap(
        at location: CGPoint,
        in size: CGSize,
        imageRect: CGRect,
        headerHeight: CGFloat
    ) {
        guard !isGestureInProgress else { return }
        if suppressNextCanvasTap {
            suppressNextCanvasTap = false
            return
        }

        guard wallIsUsable, location.y >= max(0, headerHeight) else { return }

        if let tappedHold = hold(
            at: location,
            in: size,
            imageRect: imageRect,
            headerHeight: headerHeight
        ) {
            handleMarkerTap(id: tappedHold.id)
            return
        }
        guard presentationMode == .edit else { return }

        guard let imagePoint = EditorHoldGeometry.imagePoint(
            from: location,
            canvasSize: size,
            zoomScale: zoomScale,
            panOffset: panOffset
        ) else { return }
        guard imageRect.contains(imagePoint) else { return }

        placeHold(at: imagePoint, in: imageRect, type: EditorHoldInteraction.defaultType)
    }

    private func hold(
        at location: CGPoint,
        in size: CGSize,
        imageRect: CGRect,
        headerHeight: CGFloat
    ) -> Hold? {
        guard location.y >= max(0, headerHeight),
              let point = EditorHoldGeometry.imagePoint(
                  from: location,
                  canvasSize: size,
                  zoomScale: zoomScale,
                  panOffset: panOffset
              ) else {
            return nil
        }
        func isHit(_ hold: Hold) -> Bool {
            guard markerCanReceiveInput(
                for: hold,
                imageRect: imageRect,
                canvasSize: size,
                headerHeight: headerHeight
            ) else {
                return false
            }
            let markerPoint = CGPoint(
                x: imageRect.minX + hold.normalizedX * imageRect.width,
                y: imageRect.minY + hold.normalizedY * imageRect.height
            )
            let hitRadius = max(22 / max(zoomScale, 1), holdRadiusValue(hold))
            let dx = point.x - markerPoint.x
            let dy = point.y - markerPoint.y
            return (dx * dx) + (dy * dy) <= hitRadius * hitRadius
        }

        return holds.reversed().first(where: isHit)
    }

    private func placeHold(at imagePoint: CGPoint, in imageRect: CGRect, type: HoldType) {
        guard presentationMode == .edit,
              imageRect.width > 0,
              imageRect.height > 0 else { return }
        let x = max(2, min(98, ((imagePoint.x - imageRect.minX) / imageRect.width) * 100))
        let y = max(2, min(98, ((imagePoint.y - imageRect.minY) / imageRect.height) * 100))
        let newHold = Hold(
            id: UUID().uuidString,
            x: x,
            y: y,
            type: type,
            color: type.colorHex,
            size: .medium,
            notes: nil
        )
        holds.append(newHold)
        announce("Added \(typeDisplayName(type).lowercased()) hold.")
    }




    private func handleWallSelectionChange(_ newID: String?) {
        guard presentationMode == .edit, !isApplyingWallSelection else { return }
        guard newID != acceptedWallID else { return }
        if let acceptedWallID, !wallsViewModel.walls.contains(where: { $0.id == acceptedWallID }) {
            holds.removeAll()
            acceptWallSelection(newID, announcement: "Previous wall deleted. Holds cleared.")
            return
        }

        if !holds.isEmpty {
            pendingWallID = newID
            hasPendingWallSelection = true
            isApplyingWallSelection = true
            wallsViewModel.restoreWallSelection(id: acceptedWallID)
            DispatchQueue.main.async {
                isApplyingWallSelection = false
                presentPendingWallSwitchIfPossible()
            }
        } else {
            acceptWallSelection(newID)
        }
    }

    private func presentPendingWallSwitchIfPossible() {
        guard hasPendingWallSelection, !isWallPickerPresented else { return }
        isWallSwitchConfirmationPresented = true
    }

    private func confirmWallSwitch() {
        guard presentationMode == .edit, hasPendingWallSelection else { return }
        let targetWallID = pendingWallID
        isApplyingWallSelection = true
        wallsViewModel.restoreWallSelection(id: targetWallID)
        acceptedWallID = targetWallID
        pendingWallID = nil
        hasPendingWallSelection = false
        holds.removeAll()
        announce("Wall changed. Holds cleared.")
        resetZoom(animated: false)
        resetWallImageState(for: acceptedWallID)
        DispatchQueue.main.async {
            isApplyingWallSelection = false
        }
    }

    private func acceptWallSelection(_ id: String?, announcement: String? = nil) {
        acceptedWallID = id
        pendingWallID = nil
        hasPendingWallSelection = false
        if let announcement {
            announce(announcement)
        }
        resetZoom(animated: false)
        resetWallImageState(for: id)
    }

    private func retryWallImage() {
        refreshWallMetadata()
    }

    private func refreshWallMetadata() {
        guard acceptedWallID != nil else {
            wallImageState = .none
            return
        }

        let requestID = UUID()
        imageReloadID = requestID
        wallAspectRequestID = nil
        wallImageState = .loading
        isRefreshingWallMetadata = true
        wallMetadataRefreshGeneration += 1
        let refreshGeneration = wallMetadataRefreshGeneration

        Task {
            await wallsViewModel.load(userId: session.userId)
            guard refreshGeneration == wallMetadataRefreshGeneration else { return }
            let loadSucceeded = wallsViewModel.errorMessage == nil
            isRefreshingWallMetadata = false
            guard loadSucceeded else {
                updateWallImageState(.failed, requestID: requestID)
                return
            }
            resetWallImageState(for: acceptedWallID)
        }
    }

    private func resetWallImageState(for id: String?) {
        imageReloadID = UUID()
        wallAspectRequestID = nil
        loadedWallAspectRatio = wallMetadataAspectRatio(for: id)
        guard id != nil else {
            wallImageState = .none
            return
        }
        #if DEBUG
        if isFixtureWallImage(for: id) {
            wallImageState = .ready
            return
        }
        #endif
        if wallImageURL(for: id) == nil {
            updateWallImageState(.failed, requestID: imageReloadID)
        } else {
            wallImageState = .loading
        }
    }

    private func prepareWallImage(url: URL, requestID: UUID) {
        guard requestID == imageReloadID, wallAspectRequestID != requestID else { return }
        wallAspectRequestID = requestID

        if let metadataAspectRatio = wallMetadataAspectRatio(for: wallsViewModel.selectedWallId) {
            loadedWallAspectRatio = metadataAspectRatio
            updateWallImageState(.ready, requestID: requestID)
            return
        }

        #if canImport(UIKit)
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data), image.size.height > 0 else {
                    throw NSError(
                        domain: "Boarded.EditorView",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The wall image dimensions could not be read."]
                    )
                }
                let aspectRatio = image.size.width / image.size.height
                await MainActor.run {
                    guard requestID == imageReloadID else { return }
                    loadedWallAspectRatio = aspectRatio
                    updateWallImageState(.ready, requestID: requestID)
                }
            } catch {
                await MainActor.run {
                    guard requestID == imageReloadID else { return }
                    updateWallImageState(.failed, requestID: requestID)
                }
            }
        }
        #else
        updateWallImageState(.ready, requestID: requestID)
        #endif
    }

    private func updateWallImageState(_ state: WallImageState, requestID: UUID) {
        guard !isRefreshingWallMetadata else { return }
        guard requestID == imageReloadID else { return }
        guard wallImageState != state else { return }
        wallImageState = state
        if state == .failed {
            announce("Wall image couldn’t load.")
        }
    }

    private func scheduleCanvasTapSuppressionClear() {
        canvasTapSuppressionGeneration += 1
        let generation = canvasTapSuppressionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard generation == canvasTapSuppressionGeneration else { return }
            suppressNextCanvasTap = false
        }
    }
    private func scheduleMarkerTapSuppressionClear() {
        markerTapSuppressionGeneration += 1
        let generation = markerTapSuppressionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard generation == markerTapSuppressionGeneration else { return }
            suppressNextMarkerTap = false
        }
    }



    private func clampedPanOffset(
        _ offset: CGSize,
        in size: CGSize,
        scale: CGFloat,
        imageRect: CGRect
    ) -> CGSize {
        guard scale >= 1 else { return .zero }
        let maxX = max(0, (imageRect.width * scale - size.width) / 2)
        let maxY = max(0, (imageRect.height * scale - size.height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func resetZoom(animated: Bool = true) {
        let reset = {
            zoomScale = 1
            lastZoomScale = 1
            panOffset = .zero
            lastPanOffset = .zero
        }
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.18), reset)
        } else {
            reset()
        }
    }




    private var wallIsUsable: Bool {
        selectedWall != nil
            && wallImageState == .ready
            && wallAspectIsReady
            && !isRefreshingWallMetadata
    }

    private var emptyCanvasReadabilityTint: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.32)
            : Color.white.opacity(0.28)
    }


    private var canvasAccessibilityValue: String {
        let wallName = selectedWall?.name ?? "No wall selected"
        return "\(wallName), \(holds.count) \(holds.count == 1 ? "hold" : "holds"), zoom \(zoomPercentage) percent."
    }


    private var zoomPercentage: Int {
        Int((zoomScale * 100).rounded())
    }

#if DEBUG
    private func isFixtureWallImage(for id: String?) -> Bool {
        guard AppLaunchConfiguration.isUITestFixture,
              let id,
              let wall = wallsViewModel.walls.first(where: { $0.id == id }) else {
            return false
        }
        return wall.imageUrl == "fixture://default-wall"
    }
#endif


    private func markerAccessibilityLabel(for hold: Hold) -> String {
        "\(typeDisplayName(hold.type)) hold, \(sizeDisplayName(hold.size))"
    }

    private func typeDisplayName(_ type: HoldType) -> String {
        switch type {
        case .start: return "Start"
        case .hand: return "Hand"
        case .foot: return "Foot"
        case .finish: return "Finish"
        }
    }

    private func sizeDisplayName(_ size: HoldSize) -> String {
        switch size {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    private func holdRadiusValue(_ hold: Hold) -> CGFloat {
        if let radius = hold.radius,
           radius.isFinite,
           let clamped = EditorHoldGeometry.clampedRadius(CGFloat(radius)) {
            return clamped
        }
        return EditorHoldGeometry.defaultRadius(for: hold.size)
    }

    private func holdDiameterValue(_ hold: Hold) -> CGFloat {
        holdRadiusValue(hold) * 2
    }

    private var selectedWallName: String {
        if let wall = selectedWall {
            return "Wall: \(wall.name)"
        }
        return "Select wall"
    }

    private var selectedWall: Wall? {
        guard let id = wallsViewModel.selectedWallId else { return nil }
        return wallsViewModel.walls.first(where: { $0.id == id })
    }

    private func wallImageURL(for id: String?) -> URL? {
        guard let id,
              let wall = wallsViewModel.walls.first(where: { $0.id == id }),
              let normalized = normalizedRemoteImageURLString(wall.imageUrl) else {
            return nil
        }
        return URL(string: normalized)
    }

    private var selectedWallImageURL: URL? {
        wallImageURL(for: wallsViewModel.selectedWallId)
    }

    private var wallAspectRatio: CGFloat {
        loadedWallAspectRatio
            ?? wallMetadataAspectRatio(for: wallsViewModel.selectedWallId)
            ?? AppLayout.defaultWallAspectRatio
    }

    private var wallAspectIsReady: Bool {
        loadedWallAspectRatio != nil
            || wallMetadataAspectRatio(for: wallsViewModel.selectedWallId) != nil
    }

    private func wallMetadataAspectRatio(for id: String?) -> CGFloat? {
        guard let id,
              let wall = wallsViewModel.walls.first(where: { $0.id == id }),
              let width = wall.imageWidth,
              let height = wall.imageHeight,
              width > 0,
              height > 0 else {
            return nil
        }
        return CGFloat(width) / CGFloat(height)
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    private func saveRoute() async {
        guard !isSaving else { return }
        guard let wall = selectedWall, wallIsUsable else {
            saveErrorMessage = "Select a wall with a loaded image before saving."
            return
        }

        let trimmedName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveErrorMessage = "Add a route name before saving."
            return
        }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        do {
            if let routeToEdit {
                let patch = RoutePatch(
                    wallSnapshot: RouteWallSnapshotPatch(
                        wallId: wall.id,
                        wallImageUrl: wall.normalizedImageUrl,
                        wallImageWidth: wall.imageWidth,
                        wallImageHeight: wall.imageHeight
                    ),
                    name: trimmedName,
                    gradeV: routeGrade,
                    holds: holds
                )
                let updatedRoute = try await routesViewModel.updateRoute(
                    routeId: routeToEdit.id,
                    patch: patch
                )
                onRouteUpdated(updatedRoute)
            } else {
                try await routesViewModel.createRoute(
                    name: trimmedName,
                    gradeV: routeGrade,
                    holds: holds,
                    wall: wall,
                    userId: session.userId,
                    userName: session.displayName
                )
                announce("Route saved.")
                routeName = ""
                routeGrade = nil
                holds = []
                resetZoom()
            }
            isSavePresented = false
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

struct SaveRouteSheet: View {
    @Binding var routeName: String
    @Binding var routeGrade: String?
    let holdsCount: Int
    let isEditing: Bool
    let isSaving: Bool
    let errorMessage: String?
    let onSave: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Route name", text: $routeName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                                .stroke(AppColor.border, lineWidth: 1)
                        )
                        .font(AppTypography.body)
                        .accessibilityIdentifier("Route name")

                    Picker("Grade", selection: $routeGrade) {
                        if !isEditing || routeGrade == nil {
                            Text("Ungraded")
                                .tag(nil as String?)
                                .disabled(isEditing)
                        }
                        ForEach(VGradeOption.all) { grade in
                            Text(grade.label).tag(grade.label as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                            .stroke(AppColor.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Route grade")
                    if isEditing {
                        Text("An existing grade cannot be cleared while editing.")
                            .font(AppTypography.label)
                            .foregroundColor(AppColor.muted)
                    }

                    Text("\(holdsCount) \(holdsCount == 1 ? "hold" : "holds") placed")
                        .font(AppTypography.label)
                        .foregroundColor(AppColor.muted)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(AppTypography.label)
                            .foregroundColor(AppColor.destructive)
                    }

                    if isSaving {
                        ProgressView()
                            .tint(AppColor.primary)
                    }
                    Spacer()
                }
                .padding(AppLayout.horizontalPadding)
            }
            .navigationTitle("Save Route")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(AppColor.muted)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await onSave() }
                    } label: {
                        Text(isSaving ? "Saving..." : "Save")
                    }
                    .foregroundColor(AppColor.primary)
                    .disabled(routeName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .accessibilityIdentifier("Route form save")
                }
            }
        }
            .interactiveDismissDisabled(isSaving)
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView()
            .environmentObject(AppSession())
            .environmentObject(RoutesViewModel(repository: MockRoutesRepository()))
    }
}
