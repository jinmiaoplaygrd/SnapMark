import Foundation

struct RegressionFailure: Error {
    let message: String
}

@main
struct SnapMarkRegressionChecks {
    static func main() {
        let checks: [(String, () throws -> Void)] = [
            ("editor content uses natural image size", testEditorContentSizeUsesNaturalImageDimensions),
            ("editor content clamps tiny images", testEditorContentSizeClampsTinyImages),
            ("toolbar shows all items when width fits", testToolbarShowsEverythingWhenWidthIsSufficient),
            ("toolbar overflows trailing items when narrow", testToolbarMovesTrailingItemsIntoOverflowWhenWindowIsNarrow),
            ("toolbar drops trailing separators from visible area", testToolbarDoesNotLeaveTrailingSeparatorVisible),
        ]

        var failures: [String] = []

        for (name, check) in checks {
            do {
                try check()
                print("PASS: \(name)")
            } catch let error as RegressionFailure {
                failures.append("FAIL: \(name) - \(error.message)")
            } catch {
                failures.append("FAIL: \(name) - unexpected error: \(error)")
            }
        }

        guard failures.isEmpty else {
            failures.forEach { print($0) }
            exit(1)
        }

        print("All SnapMark regression checks passed.")
    }

    private static func testEditorContentSizeUsesNaturalImageDimensions() throws {
        let size = AnnotationEditorLayoutRules.contentSize(for: CGSize(width: 123.2, height: 45.1))
        try expectEqual(size.width, 124, "expected width to round up to the natural image width")
        try expectEqual(size.height, 96, "expected height to include rounded image height plus toolbar")
    }

    private static func testEditorContentSizeClampsTinyImages() throws {
        let size = AnnotationEditorLayoutRules.contentSize(for: .zero)
        try expectEqual(size.width, 1, "expected zero-width images to clamp to one point")
        try expectEqual(size.height, 51, "expected zero-height images to clamp and still include toolbar")
    }

    private static func testToolbarShowsEverythingWhenWidthIsSufficient() throws {
        let entries = sampleEntries()
        let availableWidth = ToolbarOverflowRules.sidePadding * 2
            + 34 + ToolbarOverflowRules.controlSpacing
            + 34 + ToolbarOverflowRules.controlSpacing
            + 1 + ToolbarOverflowRules.separatorSpacing
            + 24 + ToolbarOverflowRules.controlSpacing
            + 34

        let visibleCount = ToolbarOverflowRules.visibleEntryCount(entries: entries, availableWidth: availableWidth)
        try expectEqual(visibleCount, entries.count, "expected no toolbar entries to overflow when the width fits")
    }

    private static func testToolbarMovesTrailingItemsIntoOverflowWhenWindowIsNarrow() throws {
        let entries = sampleEntries()
        let visibleCount = ToolbarOverflowRules.visibleEntryCount(entries: entries, availableWidth: 140)

        try expect(visibleCount < entries.count, "expected some toolbar entries to move into the overflow menu")
        try expectEqual(visibleCount, 2, "expected only the leading two controls to stay visible at this width")
    }

    private static func testToolbarDoesNotLeaveTrailingSeparatorVisible() throws {
        let entries: [ToolbarOverflowRules.Entry] = [
            .init(width: 34, kind: .control),
            .init(width: 1, kind: .separator),
            .init(width: 34, kind: .control),
        ]

        let visibleCount = ToolbarOverflowRules.visibleEntryCount(entries: entries, availableWidth: 94)
        try expectEqual(visibleCount, 1, "expected the trailing separator to be hidden with the overflowed control")
    }

    private static func sampleEntries() -> [ToolbarOverflowRules.Entry] {
        [
            .init(width: 34, kind: .control),
            .init(width: 34, kind: .control),
            .init(width: 1, kind: .separator),
            .init(width: 24, kind: .control),
            .init(width: 34, kind: .control),
        ]
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw RegressionFailure(message: message)
        }
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
        guard actual == expected else {
            throw RegressionFailure(message: "\(message); got \(actual), expected \(expected)")
        }
    }
}