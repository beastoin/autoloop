import ArgumentParser

@main
struct AgentSwift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-swift",
        abstract: "CLI for AI agents to control macOS apps via Accessibility API",
        version: "0.1.0",
        subcommands: [Doctor.self, Connect.self, Disconnect.self, Status.self, Snapshot.self, Press.self]
    )
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check prerequisites and diagnose issues")
    func run() throws { print("doctor: not implemented") }
}
struct Connect: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Connect to a macOS app")
    @Option(name: .long, help: "Process ID") var pid: Int?
    @Option(name: .long, help: "Bundle identifier") var bundleId: String?
    func run() throws { print("connect: not implemented") }
}
struct Disconnect: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Disconnect from app")
    func run() throws { print("disconnect: not implemented") }
}
struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show connection state")
    func run() throws { print("status: not implemented") }
}
struct Snapshot: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Capture element tree with refs")
    func run() throws { print("snapshot: not implemented") }
}
struct Press: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Press element by ref")
    @Argument(help: "Element ref (e.g. @e1)") var ref: String
    func run() throws { print("press: not implemented") }
}
