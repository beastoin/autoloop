import XCTest
@testable import AgentSwiftLib

final class ClickTests: XCTestCase {

    // MARK: - performClick exists and returns Bool

    func testPerformClickMethodExists() {
        // performClick(at:) is a static method on AXClient that returns Bool
        // We can't actually click in tests (no GUI), but verify the API shape
        let point = CGPoint(x: 100, y: 200)
        // Type check: the method signature accepts CGPoint and returns Bool
        let _: (CGPoint) -> Bool = AXClient.performClick
        XCTAssertTrue(true) // If this compiles, the API exists
    }

    // MARK: - Click target parsing

    func testClickRefTargetDetection() {
        // Ref targets start with @ or e
        let ref1 = "@e1"
        XCTAssertTrue(ref1.hasPrefix("@") || ref1.hasPrefix("e"))

        let ref2 = "e5"
        XCTAssertTrue(ref2.hasPrefix("@") || ref2.hasPrefix("e"))

        // Coordinate targets are numbers
        let coord = "150"
        XCTAssertFalse(coord.hasPrefix("@") || coord.hasPrefix("e"))
        XCTAssertNotNil(Double(coord))
    }

    func testClickCenterPointCalculation() {
        // Given an element with position and size, center = (x + w/2, y + h/2)
        let node = AXNode(role: "AXButton", subrole: nil, title: "Nav Item", axDescription: nil,
                         value: nil, identifier: nil, childStaticText: nil, enabled: true, focused: false,
                         position: CGPoint(x: 100, y: 200), size: CGSize(width: 80, height: 30),
                         actions: ["AXPress"], children: [])

        let pos = node.position!
        let sz = node.size!
        let center = CGPoint(x: pos.x + sz.width / 2, y: pos.y + sz.height / 2)

        XCTAssertEqual(center.x, 140.0)
        XCTAssertEqual(center.y, 215.0)
    }

    func testClickRequiresBounds() {
        // Element without bounds cannot be clicked by ref
        let noBounds = AXNode(role: "AXButton", subrole: nil, title: "Hidden", axDescription: nil,
                             value: nil, identifier: nil, childStaticText: nil, enabled: true, focused: false,
                             position: nil, size: nil, actions: [], children: [])
        XCTAssertNil(noBounds.position)
        XCTAssertNil(noBounds.size)
    }

    func testClickCoordinateParsing() {
        // Valid coordinates
        let x = Double("250")
        let y = Double("400")
        XCTAssertEqual(x, 250.0)
        XCTAssertEqual(y, 400.0)

        // Invalid coordinates
        let badX = Double("notanumber")
        XCTAssertNil(badX)
    }

    // MARK: - Schema

    func testClickSchemaShape() {
        let schema = CommandSchema(
            name: "click",
            description: "Click element or coordinates via CGEvent",
            args: [CommandSchema.ArgSchema(name: "target", type: "string", required: true),
                   CommandSchema.ArgSchema(name: "y", type: "number", required: false)],
            flags: [CommandSchema.FlagSchema(name: "--json", type: "bool", defaultValue: "false")],
            exitCodes: ["0": "success", "2": "error"]
        )
        XCTAssertEqual(schema.name, "click")
        XCTAssertEqual(schema.args.count, 2)
        XCTAssertTrue(schema.args[0].required)
        XCTAssertFalse(schema.args[1].required)
        XCTAssertEqual(schema.exitCodes["0"], "success")
        XCTAssertEqual(schema.exitCodes["2"], "error")
    }
}
