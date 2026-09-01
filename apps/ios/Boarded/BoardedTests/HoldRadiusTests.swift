import XCTest
@testable import Boarded

final class HoldRadiusTests: XCTestCase {
    func testDefaultTypeIsStart() {
        XCTAssertEqual(EditorHoldInteraction.defaultType, .start)
    }
    func testNextTypeCyclesThroughPlacementTypesThenDeletes() {
        XCTAssertEqual(EditorHoldInteraction.nextType(after: .start), .hand)
        XCTAssertEqual(EditorHoldInteraction.nextType(after: .hand), .foot)
        XCTAssertEqual(EditorHoldInteraction.nextType(after: .foot), .finish)
        XCTAssertNil(EditorHoldInteraction.nextType(after: .finish))
    }

    func testImagePointConversionIsScaleIndependent() {
        let atOne = EditorHoldGeometry.imagePoint(
            from: CGPoint(x: 240, y: 170),
            canvasSize: CGSize(width: 400, height: 300),
            zoomScale: 1,
            panOffset: .zero
        )
        let atTwo = EditorHoldGeometry.imagePoint(
            from: CGPoint(x: 280, y: 190),
            canvasSize: CGSize(width: 400, height: 300),
            zoomScale: 2,
            panOffset: .zero
        )
        XCTAssertEqual(atOne?.x, 240)
        XCTAssertEqual(atOne?.y, 170)
        XCTAssertEqual(atTwo?.x, 240)
        XCTAssertEqual(atTwo?.y, 170)
    }

    func testRadiusClampsToBounds() {
        XCTAssertEqual(EditorHoldGeometry.clampedRadius(1), 8)
        XCTAssertEqual(EditorHoldGeometry.clampedRadius(120), 96)
        XCTAssertEqual(EditorHoldGeometry.clampedRadius(32), 32)
    }

    func testScaledRadiusMultipliesWithinBounds() {
        XCTAssertEqual(EditorHoldGeometry.scaledRadius(24, magnification: 1.5), 36)
    }

    func testScaledRadiusClampsToBounds() {
        XCTAssertEqual(EditorHoldGeometry.scaledRadius(4, magnification: 2), 8)
        XCTAssertEqual(EditorHoldGeometry.scaledRadius(60, magnification: 2), 96)
        XCTAssertEqual(EditorHoldGeometry.scaledRadius(32, magnification: 1), 32)
    }

    func testScaledRadiusRejectsNonFiniteAndNonPositiveInput() {
        XCTAssertNil(EditorHoldGeometry.scaledRadius(.nan, magnification: 2))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(24, magnification: .infinity))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(24, magnification: -.infinity))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(24, magnification: .nan))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(0, magnification: 2))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(-1, magnification: 2))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(24, magnification: 0))
        XCTAssertNil(EditorHoldGeometry.scaledRadius(24, magnification: -1))
    }

    func testNonFiniteRadiusCancels() {
        XCTAssertNil(EditorHoldGeometry.radius(from: CGPoint(x: 10, y: 10), to: CGPoint(x: CGFloat.infinity, y: 10)))
        XCTAssertNil(EditorHoldGeometry.clampedRadius(.nan))
    }

    func testRadiusKeepsCenterFixed() {
        let center = CGPoint(x: 20, y: 30)
        let finger = CGPoint(x: 50, y: 70)
        XCTAssertEqual(EditorHoldGeometry.radius(from: center, to: finger), 50)
    }

    func testResizeSnapshotUndoesResizeBeforeEarlierMutation() {
        let original = hold(id: "a", x: 20, radius: 12)
        let added = hold(id: "b", x: 40, radius: 12)
        var history = EditorHoldHistory()
        history.record([original])

        let beforeResize = [original, added]
        history.record(beforeResize)
        var resized = beforeResize
        resized[1].radius = 28

        XCTAssertEqual(history.undo(current: resized), beforeResize)
        XCTAssertEqual(history.undo(current: beforeResize), [original])
    }

    func testClearingHistoryPreventsOldWallCoordinatesFromReturning() {
        let oldWallHolds = [hold(id: "old-wall", x: 88, radius: 18)]
        var history = EditorHoldHistory()
        history.record(oldWallHolds)
        _ = history.undo(current: [])

        history.clear()

        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertNil(history.undo(current: []))
        XCTAssertNil(history.redo(current: []))
    }

    private func hold(id: String, x: Double, radius: Double) -> Hold {
        Hold(
            id: id,
            x: x,
            y: 50,
            type: .hand,
            color: HoldType.hand.colorHex,
            size: .medium,
            radius: radius,
            notes: nil
        )
    }
}
