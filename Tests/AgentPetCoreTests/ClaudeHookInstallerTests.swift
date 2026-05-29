import XCTest
@testable import AgentPetCore

final class ClaudeHookInstallerTests: XCTestCase {
    private let cmd = "\"/Applications/AgentPet.app/Contents/MacOS/agentpet\" hook"

    private func groups(_ settings: [String: Any], _ event: String) -> [[String: Any]] {
        (settings["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
    }

    func testInstallIntoEmptyAddsAllEvents() {
        let result = ClaudeHookInstaller.install(into: [:], command: cmd)
        XCTAssertTrue(ClaudeHookInstaller.isInstalled(in: result))
        for event in ClaudeHookInstaller.events {
            XCTAssertEqual(groups(result, event).count, 1, "event \(event)")
        }
    }

    func testInstallIsIdempotent() {
        let once = ClaudeHookInstaller.install(into: [:], command: cmd)
        let twice = ClaudeHookInstaller.install(into: once, command: cmd)
        for event in ClaudeHookInstaller.events {
            XCTAssertEqual(groups(twice, event).count, 1, "no duplicate on \(event)")
        }
    }

    func testInstallPreservesForeignHooks() {
        let existing: [String: Any] = [
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo done"]]]]],
        ]
        let result = ClaudeHookInstaller.install(into: existing, command: cmd)
        XCTAssertEqual(groups(result, "Stop").count, 2, "foreign + ours")
    }

    func testUninstallRemovesOursKeepsForeign() {
        let existing: [String: Any] = [
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo done"]]]]],
        ]
        let installed = ClaudeHookInstaller.install(into: existing, command: cmd)
        let removed = ClaudeHookInstaller.uninstall(from: installed)
        XCTAssertFalse(ClaudeHookInstaller.isInstalled(in: removed))
        XCTAssertEqual(groups(removed, "Stop").count, 1, "foreign hook survives")
        // Events that were only ours are dropped entirely.
        XCTAssertTrue(groups(removed, "SessionStart").isEmpty)
    }

    func testUninstallFromCleanIsNoop() {
        let removed = ClaudeHookInstaller.uninstall(from: [:])
        XCTAssertNil(removed["hooks"])
    }

    func testDiskRoundTrip() throws {
        let path = NSTemporaryDirectory() + "settings-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try ClaudeHookInstaller.installToDisk(command: cmd, path: path)
        XCTAssertTrue(ClaudeHookInstaller.isInstalledOnDisk(path: path))
        try ClaudeHookInstaller.uninstallFromDisk(path: path)
        XCTAssertFalse(ClaudeHookInstaller.isInstalledOnDisk(path: path))
    }
}
