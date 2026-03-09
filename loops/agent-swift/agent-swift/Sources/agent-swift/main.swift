import ArgumentParser
import ApplicationServices
import Foundation
import AppKit
import AgentSwiftLib

struct AgentSwift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-swift",
        abstract: "CLI for AI agents to control macOS apps via Accessibility API",
        version: "0.1.0",
        subcommands: [
            DoctorCommand.self,
            ConnectCommand.self,
            DisconnectCommand.self,
            StatusCommand.self,
            SnapshotCommand.self,
            PressCommand.self,
            FillCommand.self,
            GetCommand.self,
            FindCommand.self,
            ScreenshotCommand.self
        ]
    )

}

do {
    var command = try AgentSwift.parseAsRoot()
    try command.run()
} catch {
    let exitCode = AgentSwift.exitCode(for: error)
    let msg = AgentSwift.fullMessage(for: error)
    if exitCode == .success {
        // --help and --version
        if !msg.isEmpty { print(msg) }
    } else {
        // Errors -> stderr, remap all non-zero to exit 2 (agent contract)
        if !msg.isEmpty {
            FileHandle.standardError.write(Data((msg + "\n").utf8))
        }
    }
    Darwin.exit(exitCode == .success ? 0 : 2)
}

// MARK: - Global options

struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Output JSON")
    var json = false
}

// MARK: - Doctor

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Check prerequisites and diagnose issues")

    @OptionGroup var globals: GlobalOptions

    struct Check: Codable {
        let name: String
        let status: String
        let message: String
        var fix: String?
    }

    struct DoctorResult: Codable {
        let checks: [Check]
        let allPass: Bool
    }

    func run() throws {
        var checks: [Check] = []

        let trusted = AXClient.isTrusted(prompt: false)
        checks.append(Check(
            name: "accessibility",
            status: trusted ? "pass" : "fail",
            message: trusted ? "Accessibility access granted" : "Accessibility access NOT granted",
            fix: trusted ? nil : "Grant access in System Settings > Privacy & Security > Accessibility"
        ))

        let session = SessionStore().load()
        if session.isConnected, let pid = session.pid {
            let running = AXClient.isProcessRunning(pid: pid)
            checks.append(Check(
                name: "target_app",
                status: running ? "pass" : "fail",
                message: running ? "Target app (PID \(pid)) is running" : "Target app (PID \(pid)) is NOT running",
                fix: running ? nil : "Reconnect with: agent-swift connect"
            ))
        }

        let allPass = checks.allSatisfy { $0.status == "pass" }
        let result = DoctorResult(checks: checks, allPass: allPass)

        if globals.json {
            print(Output.json(result))
        } else {
            for check in checks {
                let icon = check.status == "pass" ? "✓" : "✗"
                print("\(icon) \(check.message)")
                if let fix = check.fix {
                    print("  fix: \(fix)")
                }
            }
        }
    }
}

// MARK: - Connect

struct ConnectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "connect", abstract: "Connect to a macOS app")

    @OptionGroup var globals: GlobalOptions

    @Option(name: .long, help: "Process ID")
    var pid: Int?

    @Option(name: .long, help: "Bundle identifier")
    var bundleId: String?

    struct ConnectResult: Codable {
        let connected: Bool
        let pid: Int
        let bundleId: String?
        let connectedAt: String
    }

    func run() throws {
        guard AXClient.isTrusted() else {
            Output.printError(code: "AX_NOT_TRUSTED", message: "Accessibility permission not granted",
                            hint: "Grant access in System Settings > Privacy & Security > Accessibility", useJson: globals.json)
            throw ExitCode(2)
        }

        let resolvedPid: Int
        let resolvedBundleId: String?

        if let p = pid {
            guard AXClient.isProcessRunning(pid: p) else {
                Output.printError(code: "APP_NOT_RUNNING", message: "No running process with PID: \(p)",
                                hint: "Check with: ps -p \(p)", useJson: globals.json)
                throw ExitCode(2)
            }
            resolvedPid = p
            // Resolve bundleId from PID if not provided
            resolvedBundleId = bundleId ?? NSRunningApplication(processIdentifier: pid_t(p))?.bundleIdentifier
        } else if let bid = bundleId {
            guard let p = AXClient.resolvePID(bundleId: bid) else {
                Output.printError(code: "APP_NOT_FOUND", message: "No running app with bundle ID: \(bid)",
                                hint: "Launch the app first, or use --pid", useJson: globals.json)
                throw ExitCode(2)
            }
            resolvedPid = p
            resolvedBundleId = bid
        } else {
            Output.printError(code: "INVALID_ARGS", message: "Must specify --pid or --bundle-id",
                            hint: "Example: agent-swift connect --bundle-id com.apple.TextEdit", useJson: globals.json)
            throw ExitCode(2)
        }

        let now = ISO8601DateFormatter().string(from: Date())
        var session = SessionData.empty
        session.pid = resolvedPid
        session.bundleId = resolvedBundleId
        session.connectedAt = now

        let store = SessionStore()
        try store.save(session)

        let result = ConnectResult(connected: true, pid: resolvedPid, bundleId: resolvedBundleId, connectedAt: now)

        if globals.json {
            print(Output.json(result))
        } else {
            print("Connected to PID \(resolvedPid)" + (resolvedBundleId.map { " (\($0))" } ?? ""))
        }
    }
}

// MARK: - Disconnect

struct DisconnectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "disconnect", abstract: "Disconnect from app")

    @OptionGroup var globals: GlobalOptions

    func run() throws {
        let store = SessionStore()
        try store.clear()
        if globals.json {
            print(Output.json(["disconnected": true]))
        } else {
            print("Disconnected")
        }
    }
}

// MARK: - Status

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show connection state")

    @OptionGroup var globals: GlobalOptions

    struct StatusResult: Codable {
        let connected: Bool
        let pid: Int?
        let bundleId: String?
        let connectedAt: String?
        let refs: Int
    }

    func run() throws {
        let session = SessionStore().load()
        let result = StatusResult(
            connected: session.isConnected,
            pid: session.pid,
            bundleId: session.bundleId,
            connectedAt: session.connectedAt,
            refs: session.refs.count
        )

        if globals.json {
            print(Output.json(result))
        } else {
            if session.isConnected {
                print("Connected to PID \(session.pid!)" + (session.bundleId.map { " (\($0))" } ?? ""))
                print("Since: \(session.connectedAt ?? "unknown")")
                print("Refs: \(session.refs.count)")
            } else {
                print("Not connected")
            }
        }
    }
}

// MARK: - Snapshot

struct SnapshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "snapshot", abstract: "Capture element tree with refs")

    @OptionGroup var globals: GlobalOptions

    @Flag(name: .shortAndLong, help: "Interactive elements only")
    var interactive = false

    func run() throws {
        let store = SessionStore()
        var session = store.load()

        guard session.isConnected, let pid = session.pid else {
            Output.printError(code: "NOT_CONNECTED", message: "No active session",
                            hint: "Run: agent-swift connect --bundle-id <id>", useJson: globals.json)
            throw ExitCode(2)
        }

        guard AXClient.isProcessRunning(pid: pid) else {
            Output.printError(code: "APP_NOT_RUNNING", message: "Target app (PID \(pid)) is no longer running",
                            hint: "Reconnect with: agent-swift connect", useJson: globals.json)
            throw ExitCode(2)
        }

        let root = AXClient.appElement(pid: pid)
        let tree = AXClient.walkTree(element: root)
        var allNodes = AXClient.flattenTree(tree)

        if interactive {
            allNodes = allNodes.filter { $0.isInteractive }
        }

        var elements: [(ref: String, node: AXNode)] = []
        var refs: [String: SessionData.RefEntry] = [:]
        for (i, node) in allNodes.enumerated() {
            let ref = "e\(i + 1)"
            elements.append((ref: ref, node: node))
            refs[ref] = node.toRefEntry()
        }

        session.refs = refs
        session.lastSnapshotAt = ISO8601DateFormatter().string(from: Date())
        session.interactiveSnapshot = interactive
        try store.save(session)

        if globals.json {
            print(SnapshotFormatter.formatJson(elements: elements))
        } else {
            print(SnapshotFormatter.formatHuman(elements: elements))
        }
    }
}

// MARK: - Press

struct PressCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "press", abstract: "Press element by ref")

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Element ref (e.g. @e1)")
    var ref: String

    struct PressResult: Codable {
        let pressed: String
        let success: Bool
    }

    func run() throws {
        let store = SessionStore()
        let session = store.load()

        guard session.isConnected, let pid = session.pid else {
            Output.printError(code: "NOT_CONNECTED", message: "No active session",
                            hint: "Run: agent-swift connect --bundle-id <id>", useJson: globals.json)
            throw ExitCode(2)
        }

        let refKey = ref.hasPrefix("@") ? String(ref.dropFirst()) : ref
        guard session.refs[refKey] != nil else {
            Output.printError(code: "ELEMENT_NOT_FOUND", message: "Element not found: \(ref)",
                            hint: "Re-run: agent-swift snapshot -i", useJson: globals.json)
            throw ExitCode(2)
        }

        guard let numStr = refKey.dropFirst().first.map({ String($0) }) ?? nil,
              let _ = Int(String(refKey.dropFirst())) else {
            Output.printError(code: "INVALID_INPUT", message: "Invalid ref format: \(ref)",
                            hint: "Use @eN format (e.g. @e1)", useJson: globals.json)
            throw ExitCode(2)
        }
        let index = Int(String(refKey.dropFirst()))! - 1

        let root = AXClient.appElement(pid: pid)
        let useInteractive = session.interactiveSnapshot ?? false

        var elements: [AXUIElement] = []
        AXClient.collectElements(element: root, interactiveOnly: useInteractive, into: &elements)

        guard index >= 0 && index < elements.count else {
            Output.printError(code: "ELEMENT_NOT_FOUND", message: "Element \(ref) no longer exists (stale ref)",
                            hint: "Re-run: agent-swift snapshot -i", useJson: globals.json)
            throw ExitCode(2)
        }

        let target = elements[index]
        var acted = AXClient.performPress(element: target, actionName: "AXPress")
        if !acted {
            acted = AXClient.performPress(element: target, actionName: "AXConfirm")
        }

        if acted {
            if globals.json {
                print(Output.json(PressResult(pressed: ref, success: true)))
            } else {
                print("Pressed \(ref)")
            }
        } else {
            Output.printError(code: "ACTION_NOT_SUPPORTED", message: "Cannot press \(ref)",
                            hint: "Pick a different target from snapshot", useJson: globals.json)
            throw ExitCode(2)
        }
    }
}

// MARK: - Ref Resolution Helper

struct ResolvedRef {
    let refKey: String
    let index: Int
    let element: AXUIElement
    let node: AXNode
}

func resolveRef(_ ref: String, session: SessionData, pid: Int, useJson: Bool) throws -> ResolvedRef {
    let refKey = ref.hasPrefix("@") ? String(ref.dropFirst()) : ref
    guard session.refs[refKey] != nil else {
        Output.printError(code: "ELEMENT_NOT_FOUND", message: "Element not found: \(ref)",
                        hint: "Re-run: agent-swift snapshot -i", useJson: useJson)
        throw ExitCode(2)
    }

    guard let _ = Int(String(refKey.dropFirst())) else {
        Output.printError(code: "INVALID_INPUT", message: "Invalid ref format: \(ref)",
                        hint: "Use @eN format (e.g. @e1)", useJson: useJson)
        throw ExitCode(2)
    }
    let index = Int(String(refKey.dropFirst()))! - 1

    let root = AXClient.appElement(pid: pid)
    let useInteractive = session.interactiveSnapshot ?? false

    var elements: [AXUIElement] = []
    AXClient.collectElements(element: root, interactiveOnly: useInteractive, into: &elements)

    guard index >= 0 && index < elements.count else {
        Output.printError(code: "ELEMENT_NOT_FOUND", message: "Element \(ref) no longer exists (stale ref)",
                        hint: "Re-run: agent-swift snapshot -i", useJson: useJson)
        throw ExitCode(2)
    }

    let tree = AXClient.walkTree(element: root)
    let allNodes = AXClient.flattenTree(tree)
    let nodes = useInteractive ? allNodes.filter { $0.isInteractive } : allNodes

    let node = index < nodes.count ? nodes[index] : AXNode(
        role: "AXUnknown", subrole: nil, title: nil, axDescription: nil, value: nil,
        identifier: nil, childStaticText: nil, enabled: false, focused: false,
        position: nil, size: nil, actions: [], children: [])

    return ResolvedRef(refKey: refKey, index: index, element: elements[index], node: node)
}

// MARK: - Fill

struct FillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "fill", abstract: "Enter text into element by ref")

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Element ref (e.g. @e1)")
    var ref: String

    @Argument(help: "Text to enter")
    var text: String

    struct FillResult: Codable {
        let filled: String
        let text: String
        let success: Bool
    }

    func run() throws {
        let store = SessionStore()
        let session = store.load()

        guard session.isConnected, let pid = session.pid else {
            Output.printError(code: "NOT_CONNECTED", message: "No active session",
                            hint: "Run: agent-swift connect --bundle-id <id>", useJson: globals.json)
            throw ExitCode(2)
        }

        let resolved = try resolveRef(ref, session: session, pid: pid, useJson: globals.json)
        let success = AXClient.performFill(element: resolved.element, text: text)

        if success {
            if globals.json {
                print(Output.json(FillResult(filled: ref, text: text, success: true)))
            } else {
                print("Filled \(ref) with \"\(text)\"")
            }
        } else {
            Output.printError(code: "ACTION_NOT_SUPPORTED", message: "Cannot fill \(ref)",
                            hint: "Element may not accept text input. Use a textfield or textarea.", useJson: globals.json)
            throw ExitCode(2)
        }
    }
}

// MARK: - Get

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read element property by ref")

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Property: text, type, role, identifier, or attrs")
    var property: String

    @Argument(help: "Element ref (e.g. @e1)")
    var ref: String

    struct GetResult: Codable {
        let ref: String
        let property: String
        let value: String?
    }

    struct AttrsResult: Codable {
        let ref: String
        let role: String
        let type: String
        let label: String?
        let identifier: String?
        let value: String?
        let enabled: Bool
        let focused: Bool
        let bounds: SessionData.RefEntry.Bounds?
        let actions: [String]
    }

    func run() throws {
        let store = SessionStore()
        let session = store.load()

        guard session.isConnected, let pid = session.pid else {
            Output.printError(code: "NOT_CONNECTED", message: "No active session",
                            hint: "Run: agent-swift connect --bundle-id <id>", useJson: globals.json)
            throw ExitCode(2)
        }

        let resolved = try resolveRef(ref, session: session, pid: pid, useJson: globals.json)
        let node = resolved.node

        switch property {
        case "text":
            let text = node.displayLabel
            if globals.json {
                print(Output.json(GetResult(ref: ref, property: "text", value: text)))
            } else {
                print(text ?? "")
            }
        case "type":
            let type = node.displayType
            if globals.json {
                print(Output.json(GetResult(ref: ref, property: "type", value: type)))
            } else {
                print(type)
            }
        case "role":
            if globals.json {
                print(Output.json(GetResult(ref: ref, property: "role", value: node.role)))
            } else {
                print(node.role)
            }
        case "identifier":
            if globals.json {
                print(Output.json(GetResult(ref: ref, property: "identifier", value: node.identifier)))
            } else {
                print(node.identifier ?? "")
            }
        case "attrs":
            let attrs = AttrsResult(
                ref: ref,
                role: node.role,
                type: node.displayType,
                label: node.displayLabel,
                identifier: node.identifier,
                value: node.value,
                enabled: node.enabled,
                focused: node.focused,
                bounds: node.bounds,
                actions: node.actions
            )
            if globals.json {
                print(Output.json(attrs))
            } else {
                print("role: \(node.role)")
                print("type: \(node.displayType)")
                if let label = node.displayLabel { print("label: \(label)") }
                if let id = node.identifier { print("identifier: \(id)") }
                if let val = node.value { print("value: \(val)") }
                print("enabled: \(node.enabled)")
                print("focused: \(node.focused)")
                if let b = node.bounds { print("bounds: \(b.x),\(b.y) \(b.width)x\(b.height)") }
                if !node.actions.isEmpty { print("actions: \(node.actions.joined(separator: ", "))") }
            }
        default:
            Output.printError(code: "INVALID_ARGS", message: "Unknown property: \(property)",
                            hint: "Use: text, type, role, identifier, or attrs", useJson: globals.json)
            throw ExitCode(2)
        }
    }
}

// MARK: - Find

struct FindCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "find", abstract: "Find element by locator")

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Locator type: role, text, or identifier")
    var locator: String

    @Argument(help: "Value to match")
    var value: String

    @Argument(help: "Optional chained action: press, fill, or get")
    var action: String?

    @Argument(help: "Action argument (text for fill, property for get)")
    var actionArg: String?

    struct FindResult: Codable {
        let ref: String
        let type: String
        let label: String?
        let identifier: String?
    }

    struct FindActionResult: Codable {
        let found: String
        let action: String
        let success: Bool
    }

    struct FindFillResult: Codable {
        let found: String
        let action: String
        let text: String
        let success: Bool
    }

    struct FindGetResult: Codable {
        let found: String
        let action: String
        let property: String
        let value: String
    }

    func run() throws {
        let store = SessionStore()
        let session = store.load()

        guard session.isConnected, let pid = session.pid else {
            Output.printError(code: "NOT_CONNECTED", message: "No active session",
                            hint: "Run: agent-swift connect --bundle-id <id>", useJson: globals.json)
            throw ExitCode(2)
        }

        // Walk tree to get nodes
        let root = AXClient.appElement(pid: pid)
        let tree = AXClient.walkTree(element: root)
        let allNodes = AXClient.flattenTree(tree)
        let useInteractive = session.interactiveSnapshot ?? false
        let nodes = useInteractive ? allNodes.filter { $0.isInteractive } : allNodes

        // Find matching element
        var matchIndex: Int? = nil
        for (i, node) in nodes.enumerated() {
            switch locator {
            case "role":
                if node.role == value || node.displayType == value {
                    matchIndex = i
                }
            case "text":
                if let label = node.displayLabel, label.contains(value) {
                    matchIndex = i
                }
            case "identifier":
                if node.identifier == value {
                    matchIndex = i
                }
            default:
                Output.printError(code: "INVALID_ARGS", message: "Unknown locator: \(locator)",
                                hint: "Use: role, text, or identifier", useJson: globals.json)
                throw ExitCode(2)
            }
            if matchIndex != nil { break }
        }

        guard let idx = matchIndex else {
            Output.printError(code: "ELEMENT_NOT_FOUND", message: "No element matches \(locator)=\"\(value)\"",
                            hint: "Re-run: agent-swift snapshot -i", useJson: globals.json)
            throw ExitCode(2)
        }

        let matchedNode = nodes[idx]
        let matchedRef = "@e\(idx + 1)"

        // If no chained action, just print the match
        guard let action = action else {
            if globals.json {
                print(Output.json(FindResult(ref: matchedRef, type: matchedNode.displayType,
                                            label: matchedNode.displayLabel, identifier: matchedNode.identifier)))
            } else {
                var line = "\(matchedRef) [\(matchedNode.displayType)]"
                if let label = matchedNode.displayLabel { line += " \"\(label)\"" }
                if let id = matchedNode.identifier { line += "  identifier=\(id)" }
                print(line)
            }
            return
        }

        // Resolve AXUIElement for chained action
        var elements: [AXUIElement] = []
        AXClient.collectElements(element: root, interactiveOnly: useInteractive, into: &elements)

        guard idx < elements.count else {
            Output.printError(code: "ELEMENT_NOT_FOUND", message: "Element \(matchedRef) no longer exists",
                            hint: "Re-run: agent-swift snapshot -i", useJson: globals.json)
            throw ExitCode(2)
        }

        let target = elements[idx]

        switch action {
        case "press":
            var acted = AXClient.performPress(element: target, actionName: "AXPress")
            if !acted { acted = AXClient.performPress(element: target, actionName: "AXConfirm") }
            if acted {
                if globals.json {
                    print(Output.json(FindActionResult(found: matchedRef, action: "press", success: true)))
                } else {
                    print("Found \(matchedRef) → pressed")
                }
            } else {
                Output.printError(code: "ACTION_NOT_SUPPORTED", message: "Cannot press \(matchedRef)",
                                hint: "Pick a different target", useJson: globals.json)
                throw ExitCode(2)
            }
        case "fill":
            guard let text = actionArg else {
                Output.printError(code: "INVALID_ARGS", message: "fill requires text argument",
                                hint: "Example: agent-swift find identifier \"field\" fill \"text\"", useJson: globals.json)
                throw ExitCode(2)
            }
            let success = AXClient.performFill(element: target, text: text)
            if success {
                if globals.json {
                    print(Output.json(FindFillResult(found: matchedRef, action: "fill", text: text, success: true)))
                } else {
                    print("Found \(matchedRef) → filled with \"\(text)\"")
                }
            } else {
                Output.printError(code: "ACTION_NOT_SUPPORTED", message: "Cannot fill \(matchedRef)",
                                hint: "Element may not accept text input", useJson: globals.json)
                throw ExitCode(2)
            }
        case "get":
            let prop = actionArg ?? "text"
            let val: String?
            switch prop {
            case "text": val = matchedNode.displayLabel
            case "type": val = matchedNode.displayType
            case "role": val = matchedNode.role
            case "identifier": val = matchedNode.identifier
            default: val = matchedNode.displayLabel
            }
            if globals.json {
                print(Output.json(FindGetResult(found: matchedRef, action: "get", property: prop, value: val ?? "")))
            } else {
                print(val ?? "")
            }
        default:
            Output.printError(code: "INVALID_ARGS", message: "Unknown action: \(action)",
                            hint: "Use: press, fill, or get", useJson: globals.json)
            throw ExitCode(2)
        }
    }
}

// MARK: - Screenshot

struct ScreenshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screenshot", abstract: "Capture app screenshot")

    @OptionGroup var globals: GlobalOptions

    @Argument(help: "Output file path (default: /tmp/agent-swift-screenshot.png)")
    var path: String?

    struct ScreenshotResult: Codable {
        let path: String
        let success: Bool
    }

    func run() throws {
        let store = SessionStore()
        let session = store.load()

        guard session.isConnected, let pid = session.pid else {
            Output.printError(code: "NOT_CONNECTED", message: "No active session",
                            hint: "Run: agent-swift connect --bundle-id <id>", useJson: globals.json)
            throw ExitCode(2)
        }

        guard AXClient.isProcessRunning(pid: pid) else {
            Output.printError(code: "APP_NOT_RUNNING", message: "Target app (PID \(pid)) is no longer running",
                            hint: "Reconnect with: agent-swift connect", useJson: globals.json)
            throw ExitCode(2)
        }

        let outputPath = path ?? "/tmp/agent-swift-screenshot.png"
        let success = AXClient.captureScreenshot(pid: pid, path: outputPath)

        if success {
            if globals.json {
                print(Output.json(ScreenshotResult(path: outputPath, success: true)))
            } else {
                print("Screenshot saved to \(outputPath)")
            }
        } else {
            Output.printError(code: "SCREENSHOT_FAILED", message: "Failed to capture screenshot",
                            hint: "Ensure the app window is visible on screen", useJson: globals.json)
            throw ExitCode(2)
        }
    }
}
