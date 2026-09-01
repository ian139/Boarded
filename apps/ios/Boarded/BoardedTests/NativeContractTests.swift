import XCTest
import UIKit
import SwiftUI
@testable import Boarded
#if canImport(Supabase)
import Supabase
#endif
@MainActor
final class NativeContractTests: XCTestCase {
    func testRouteDecodingUsesCanonicalFieldsAndStringGrades() throws {
        let route = try decodeRoute(Self.routeJSON())
        XCTAssertEqual(route.id, "route-1")
        XCTAssertEqual(route.userId, "user-1")
        XCTAssertEqual(route.wallId, "wall-1")
        XCTAssertEqual(route.name, "Canonical Route")
        XCTAssertNil(route.description)
        XCTAssertEqual(route.gradeV, "V4")
        XCTAssertNil(route.gradeFont)
        XCTAssertEqual(route.holds.count, 1)
        XCTAssertTrue(route.isPublic)
        XCTAssertEqual(route.viewCount, 12)
        XCTAssertEqual(route.shareToken, "share-token")
        XCTAssertEqual(route.userName, "Setter")
        XCTAssertEqual(route.wallImageUrl, "https://cdn/wall.jpg")
        XCTAssertEqual(route.wallImageWidth, 1600)
        XCTAssertEqual(route.wallImageHeight, 900)
        XCTAssertEqual(route.likeCount, 4)
        XCTAssertEqual(route.isLiked, true)
        XCTAssertEqual(route.ascents.count, 1)
        XCTAssertEqual(route.ascents[0].gradeV, "V0")
        XCTAssertEqual(route.comments, [])

        let encoded = try JSONEncoder().encode(route)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["grade_v"] as? String, "V4")
        XCTAssertEqual(object["wall_image_width"] as? Int, 1600)
        XCTAssertEqual(object["wall_image_height"] as? Int, 900)
    }


    func testCanonicalGradeLookup() {
        XCTAssertEqual(VGradeOption.value(for: "VB"), -1)
        XCTAssertEqual(VGradeOption.value(for: " v7 "), 7)
        XCTAssertEqual(VGradeOption.label(for: -1), "VB")
        XCTAssertEqual(VGradeOption.label(for: 7), "V7")
    }


    func testMockRouteSnapshotPatchClearsURLAndDimensionsAtomically() async throws {
        let repository = MockRoutesRepository(fixture: true)
        let routes = try await repository.fetchRoutes(userId: nil)
        let route = try XCTUnwrap(routes.first)
        let updated = try await repository.updateRoute(
            id: route.id,
            patch: RoutePatch(
                wallSnapshot: RouteWallSnapshotPatch(wallId: "replacement-wall", wallImageUrl: nil, wallImageWidth: nil, wallImageHeight: nil),
                name: nil,
                gradeV: nil,
                holds: nil
            )
        )
        XCTAssertEqual(updated.wallId, "replacement-wall")
        XCTAssertNil(updated.wallImageUrl)
        XCTAssertNil(updated.wallImageWidth)
        XCTAssertNil(updated.wallImageHeight)
    }

    func testRouteDetailGeometryUsesContainerForInvalidOrMissingDimensions() {
        let container = CGRect(x: 0, y: 0, width: 400, height: 300)
        let fitted = RouteDetailGeometry.imageRect(imageWidth: 1000, imageHeight: 500, in: container)
        XCTAssertEqual(fitted, CGRect(x: 0, y: 50, width: 400, height: 200))
        let marker = CGPoint(x: fitted.minX + 0.25 * fitted.width, y: fitted.minY + 0.75 * fitted.height)
        XCTAssertEqual(marker, CGPoint(x: 100, y: 200))
        XCTAssertEqual(RouteDetailGeometry.imageRect(imageWidth: nil, imageHeight: nil, in: container), container)
        XCTAssertEqual(RouteDetailGeometry.imageRect(imageWidth: 0, imageHeight: 500, in: container), container)
    }

    func testAppColorResolvesAdaptivePaletteForDarkAndLightTraits() {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)

        assertRGB(
            UIColor(AppColor.background).resolvedColor(with: darkTraits),
            red: 0,
            green: 0,
            blue: 0
        )
        assertRGB(
            UIColor(AppColor.text).resolvedColor(with: darkTraits),
            red: 1,
            green: 1,
            blue: 1
        )
        assertRGB(
            UIColor(AppColor.primary).resolvedColor(with: darkTraits),
            red: 1,
            green: 59.0 / 255.0,
            blue: 48.0 / 255.0
        )

        assertRGB(
            UIColor(AppColor.background).resolvedColor(with: lightTraits),
            red: 232.0 / 255.0,
            green: 220.0 / 255.0,
            blue: 200.0 / 255.0
        )
        assertRGB(
            UIColor(AppColor.text).resolvedColor(with: lightTraits),
            red: 0,
            green: 0,
            blue: 0
        )
        assertRGB(
            UIColor(AppColor.primary).resolvedColor(with: lightTraits),
            red: 1,
            green: 59.0 / 255.0,
            blue: 48.0 / 255.0
        )
    }

    func testEditorGeometryUsesModestInitialZoomForMismatchedAspectRatios() {
        let canvas = CGSize(width: 400, height: 300)
        let nearMatchingImage = EditorHoldGeometry.initialImageRect(
            imageAspectRatio: 1.2,
            in: canvas
        )
        XCTAssertEqual(nearMatchingImage.minX, 0, accuracy: 0.001)
        XCTAssertEqual(nearMatchingImage.width, 400, accuracy: 0.001)
        XCTAssertEqual(nearMatchingImage.height, 333.333, accuracy: 0.001)

        let extremePortraitImage = EditorHoldGeometry.initialImageRect(
            imageAspectRatio: 0.5,
            in: canvas
        )
        XCTAssertEqual(extremePortraitImage.width, 202.5, accuracy: 0.001)
        XCTAssertEqual(extremePortraitImage.height, 405, accuracy: 0.001)
        XCTAssertEqual(
            extremePortraitImage.height / 300,
            EditorHoldGeometry.maximumInitialImageScale,
            accuracy: 0.001
        )
    }

    func testWallUploadObjectPathUsesAuthenticatedOwnerPrefix() {
        let userID = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
        XCTAssertEqual(
            wallUploadObjectPath(userId: userID, wallId: "wall-1", fileName: "upload.jpg"),
            "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/wall-1/upload.jpg"
        )
    }

    func testConsolidatedGradeRanksAndCanonicalDisplay() {
        XCTAssertEqual(ProfileStatistics.gradeRank("VB"), 0)
        XCTAssertEqual(ProfileStatistics.gradeRank(" v17 "), 18)
        XCTAssertEqual(ProfileStatistics.gradeRank("V18"), -1)
        XCTAssertEqual(ProfileStatistics.displayGrade(setterGrade: "v0", ascentGrades: []), "V0")
        XCTAssertEqual(ProfileStatistics.displayGrade(setterGrade: "V0", ascentGrades: ["V2"]), "V1")
        XCTAssertNil(ProfileStatistics.displayGrade(setterGrade: "V18", ascentGrades: ["unknown"]))
    }

#if canImport(Supabase)
    func testRepositoryEnrichmentHandlesAbsentEqualAndDifferentSnapshotURLs() {
        let repository = SupabaseRoutesRepository(client: nil)
        let absent = repository.enrichRouteSnapshot(
            Self.makeRoute(imageURL: nil, width: nil, height: nil),
            wallImageById: ["wall": WallImageRecord(id: "wall", imageUrl: "https://cdn/wall.jpg", imageWidth: 1200, imageHeight: 800)]
        )
        XCTAssertEqual(absent.wallImageUrl, "https://cdn/wall.jpg")
        XCTAssertEqual(absent.wallImageWidth, 1200)
        XCTAssertEqual(absent.wallImageHeight, 800)

        let equal = repository.enrichRouteSnapshot(
            Self.makeRoute(imageURL: "  https://cdn/wall.jpg  ", width: nil, height: 700),
            wallImageById: ["wall": WallImageRecord(id: "wall", imageUrl: "https://cdn/wall.jpg", imageWidth: 1200, imageHeight: 800)]
        )
        XCTAssertEqual(equal.wallImageUrl, "  https://cdn/wall.jpg  ")
        XCTAssertEqual(equal.wallImageWidth, 1200)
        XCTAssertEqual(equal.wallImageHeight, 700)

        let different = repository.enrichRouteSnapshot(
            Self.makeRoute(imageURL: "https://historical/wall.jpg", width: nil, height: nil),
            wallImageById: ["wall": WallImageRecord(id: "wall", imageUrl: "https://cdn/wall.jpg", imageWidth: 1200, imageHeight: 800)]
        )
        XCTAssertEqual(different.wallImageUrl, "https://historical/wall.jpg")
        XCTAssertNil(different.wallImageWidth)
        XCTAssertNil(different.wallImageHeight)
    }

    func testSnapshotPatchPayloadDistinguishesAbsentFromExplicitNulls() throws {
        let absent = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(patchPayload(from: RoutePatch(wallSnapshot: nil, name: nil, gradeV: nil, holds: nil)))
        ) as? [String: Any]
        XCTAssertNil(absent?["wall_id"])
        XCTAssertNil(absent?["wall_image_url"])

        let clearing = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(patchPayload(from: RoutePatch(
                wallSnapshot: RouteWallSnapshotPatch(wallId: "wall-2", wallImageUrl: nil, wallImageWidth: nil, wallImageHeight: nil),
                name: nil,
                gradeV: nil,
                holds: nil
            )))
        ) as? [String: Any]
        XCTAssertEqual(clearing?["wall_id"] as? String, "wall-2")
        XCTAssertTrue(clearing?["wall_image_url"] is NSNull)
        XCTAssertTrue(clearing?["wall_image_width"] is NSNull)
        XCTAssertTrue(clearing?["wall_image_height"] is NSNull)
    }
#endif

    private func assertRGB(
        _ color: UIColor,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        XCTAssertTrue(
            color.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha),
            "Expected an RGB color, got \(color)",
            file: file,
            line: line
        )
        XCTAssertEqual(actualRed, red, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualGreen, green, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualBlue, blue, accuracy: 0.001, file: file, line: line)
    }

    private func decodeRoute(_ json: String) throws -> Route {
        try JSONDecoder().decode(Route.self, from: Data(json.utf8))
    }

    private static func makeRoute(imageURL: String?, width: Int?, height: Int?) -> Route {
        Route(
            id: "route", userId: nil, wallId: "wall", name: "Route", description: nil,
            gradeV: "V1", gradeFont: nil, holds: [], isPublic: true, viewCount: 0,
            shareToken: nil, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z",
            userName: nil, wallImageUrl: imageURL, wallImageWidth: width, wallImageHeight: height,
            likeCount: nil, isLiked: nil, ascents: [], comments: []
        )
    }

    private static func routeJSON() -> String {
        """
        {
          "id":"route-1","user_id":"user-1","wall_id":"wall-1","name":"Canonical Route",
          "description":null,"grade_v":"V4","grade_font":null,
          "holds":[{"id":"hold-1","x":20,"y":30,"type":"hand","color":"#FFFFFF","size":"medium","radius":8,"notes":null}],
          "is_public":true,"view_count":12,"share_token":"share-token",
          "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z",
          "user_name":"Setter","wall_image_url":"https://cdn/wall.jpg",
          "wall_image_width":1600,"wall_image_height":900,"like_count":4,"is_liked":true,
          "ascents":[{"id":"ascent-1","route_id":"route-1","user_id":"user-1","user_name":"Climber","grade_v":"V0","rating":null,"notes":null,"flashed":true,"created_at":"2026-01-02T00:00:00Z"}],
          "comments":[]
        }
        """
    }
}
