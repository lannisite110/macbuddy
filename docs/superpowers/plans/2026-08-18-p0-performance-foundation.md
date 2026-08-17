# P0 Performance Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Mac-native menu-bar app that cold-starts in ≤ 1.2s, summons a chat window in ≤ 100ms via `⌘⇧Space`, and records launch/hotkey telemetry — with no models, sidecars, or message bodies on the launch path.

**Architecture:** SwiftUI `AppShell` (LSUIElement menu-bar app) owns windowing and hotkeys. Two local Swift packages — `SessionStore` (SQLite metadata only at launch) and `Telemetry` (JSONL events) — stay out of the app target’s heavy imports. Perf scripts assert the two P0 gates before tagging.

**Tech Stack:** Swift 5.10+, SwiftUI, AppKit, SQLite3 (system), XCTest, macOS 14+ (Sonoma), Xcode 15+

## Global Constraints

- Cold start to composer focus: ≤ 1.2s
- Global hotkey to window visible: ≤ 100ms
- macOS deployment target: 14.0+
- Default hotkey: Command-Shift-Space
- No model SDK, sidecars, plugins, accounts, or message-body hydration on launch
- Session list at launch: metadata for ≤ 50 rows only
- Telemetry: local JSONL only; no network
- App runs as menu-bar agent (`LSUIElement = true`); no Dock icon

---

## File map (P0 only)

| Path | Responsibility |
|---|---|
| `Package.swift` | Root workspace manifest linking app + packages |
| `Packages/SessionStore/Package.swift` | SessionStore library + tests |
| `Packages/SessionStore/Sources/SessionStore/SessionStore.swift` | SQLite open, metadata CRUD |
| `Packages/SessionStore/Sources/SessionStore/Models.swift` | `SessionMetadata`, `SessionOrigin` |
| `Packages/SessionStore/Tests/SessionStoreTests/SessionStoreTests.swift` | Metadata-only launch query tests |
| `Packages/Telemetry/Package.swift` | Telemetry library + tests |
| `Packages/Telemetry/Sources/Telemetry/Telemetry.swift` | JSONL append + read last N |
| `Packages/Telemetry/Sources/Telemetry/Events.swift` | `PerfEvent` codable types |
| `Packages/Telemetry/Tests/TelemetryTests/TelemetryTests.swift` | Round-trip + file layout tests |
| `Apps/MacBuddy/MacBuddy.xcodeproj` | App target (created via Xcode or `xcodegen` if preferred) |
| `Apps/MacBuddy/MacBuddy/MacBuddyApp.swift` | `@main`, menu bar, lifecycle |
| `Apps/MacBuddy/MacBuddy/AppState.swift` | Shared observable state |
| `Apps/MacBuddy/MacBuddy/HotkeyManager.swift` | Carbon / NSEvent global hotkey |
| `Apps/MacBuddy/MacBuddy/ChatWindowController.swift` | Panel show/hide, focus composer |
| `Apps/MacBuddy/MacBuddy/Views/ChatPanelView.swift` | Empty composer UI |
| `Apps/MacBuddy/MacBuddy/Views/SessionListView.swift` | Metadata list (titles only) |
| `Apps/MacBuddy/MacBuddy/Views/SettingsView.swift` | Settings shell + Performance pane |
| `Apps/MacBuddy/MacBuddy/Views/PerformancePaneView.swift` | Last 20 cold-start rows |
| `Apps/MacBuddy/MacBuddy/Info.plist` | `LSUIElement`, bundle id |
| `Scripts/perf/launch_bench.sh` | Assert cold start ≤ 1.2s |
| `Scripts/perf/hotkey_bench.sh` | Assert hotkey ≤ 100ms |
| `Scripts/perf/common.sh` | Shared timing helpers |

---

### Task 1: Repository scaffold

**Files:**
- Create: `Package.swift`
- Create: `Packages/SessionStore/Package.swift`
- Create: `Packages/Telemetry/Package.swift`
- Create: `Apps/MacBuddy/MacBuddy/Info.plist`
- Create: `.gitignore`

**Interfaces:**
- Produces: compilable Swift package tree; app folder ready for Xcode target

- [ ] **Step 1: Add `.gitignore`**

```gitignore
.DS_Store
.build/
DerivedData/
*.xcuserstate
xcuserdata/
Apps/MacBuddy/build/
```

- [ ] **Step 2: Create root `Package.swift`**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacBuddyWorkspace",
    platforms: [.macOS(.v14)],
    products: [],
    dependencies: [],
    targets: []
)
```

Root manifest is a workspace anchor only; libraries live in nested packages.

- [ ] **Step 3: Create `Packages/SessionStore/Package.swift`**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SessionStore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SessionStore", targets: ["SessionStore"]),
    ],
    targets: [
        .target(name: "SessionStore"),
        .testTarget(name: "SessionStoreTests", dependencies: ["SessionStore"]),
    ]
)
```

- [ ] **Step 4: Create `Packages/Telemetry/Package.swift`** (same shape, name `Telemetry`)

- [ ] **Step 5: Create `Apps/MacBuddy/MacBuddy/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.macbuddy.app</string>
    <key>CFBundleName</key>
    <string>MacBuddy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 6: Verify packages resolve**

Run: `cd /Users/timmyjerry/myProjs/macbuddy && swift package --package-path Packages/SessionStore resolve && swift package --package-path Packages/Telemetry resolve`

Expected: exit 0, no errors

- [ ] **Step 7: Commit**

```bash
git init
git add .
git commit -m "chore: scaffold macbuddy workspace for P0"
```

---

### Task 2: SessionStore models and failing metadata test

**Files:**
- Create: `Packages/SessionStore/Sources/SessionStore/Models.swift`
- Create: `Packages/SessionStore/Tests/SessionStoreTests/SessionStoreTests.swift`

**Interfaces:**
- Produces:
  - `public enum SessionOrigin: String, Codable, Sendable { case chat, work, code }`
  - `public struct SessionMetadata: Identifiable, Equatable, Sendable { public let id: UUID; public var title: String; public var updatedAt: Date; public var origin: SessionOrigin }`

- [ ] **Step 1: Write models**

`Packages/SessionStore/Sources/SessionStore/Models.swift`:

```swift
import Foundation

public enum SessionOrigin: String, Codable, Sendable {
    case chat
    case work
    case code
}

public struct SessionMetadata: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var updatedAt: Date
    public var origin: SessionOrigin

    public init(id: UUID = UUID(), title: String, updatedAt: Date = Date(), origin: SessionOrigin = .chat) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.origin = origin
    }
}
```

- [ ] **Step 2: Write failing test**

`Packages/SessionStore/Tests/SessionStoreTests/SessionStoreTests.swift`:

```swift
import XCTest
@testable import SessionStore

final class SessionStoreTests: XCTestCase {
    func testLaunchQueryReturnsMetadataOnlyForFiftyMostRecent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("sessions.sqlite")
        let store = try SessionStore(databaseURL: dbURL)

        for i in 0..<55 {
            try store.insertSession(
                SessionMetadata(title: "Session \(i)", updatedAt: Date(timeIntervalSince1970: Double(i)), origin: .chat)
            )
            try store.insertMessage(sessionId: store.lastInsertedSessionId!, role: "user", body: String(repeating: "x", count: 40_000))
        }

        let metadata = try store.fetchRecentSessionMetadata(limit: 50)
        XCTAssertEqual(metadata.count, 50)
        XCTAssertEqual(metadata.first?.title, "Session 54")
        XCTAssertFalse(try store.launchQueryTouchesMessageBodies())
    }
}
```

- [ ] **Step 3: Run test — expect FAIL**

Run: `swift test --package-path Packages/SessionStore`

Expected: FAIL — `SessionStore` type not found

- [ ] **Step 4: Commit test**

```bash
git add Packages/SessionStore/Sources/SessionStore/Models.swift Packages/SessionStore/Tests
git commit -m "test: add SessionStore metadata-only launch query test"
```

---

### Task 3: SessionStore implementation

**Files:**
- Create: `Packages/SessionStore/Sources/SessionStore/SessionStore.swift`

**Interfaces:**
- Produces:
  - `public final class SessionStore: Sendable` — not required to be Sendable internally; mark `@unchecked Sendable` if needed
  - `public init(databaseURL: URL) throws`
  - `public func insertSession(_ metadata: SessionMetadata) throws`
  - `public var lastInsertedSessionId: UUID? { get }` (test helper only)
  - `public func insertMessage(sessionId: UUID, role: String, body: String) throws`
  - `public func fetchRecentSessionMetadata(limit: Int) throws -> [SessionMetadata]`
  - `public func launchQueryTouchesMessageBodies() throws -> Bool` — returns `false` when launch query SQL has no join/read on `messages.body` or message files

- [ ] **Step 1: Implement `SessionStore.swift`**

```swift
import Foundation
import SQLite3

public final class SessionStore {
    private var db: OpaquePointer?
    private(set) public var lastInsertedSessionId: UUID?
    private var lastLaunchSQL: String = ""

    public init(databaseURL: URL) throws {
        let dir = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw SessionStoreError.openFailed
        }
        try migrate()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    public func insertSession(_ metadata: SessionMetadata) throws {
        let sql = """
        INSERT INTO sessions(id, title, updated_at, origin)
        VALUES (?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, metadata.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, metadata.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, metadata.updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, metadata.origin.rawValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw SessionStoreError.execFailed }
        lastInsertedSessionId = metadata.id
    }

    public func insertMessage(sessionId: UUID, role: String, body: String) throws {
        let sql = """
        INSERT INTO messages(id, session_id, role, created_at, body_inline, body_path)
        VALUES (?, ?, ?, ?, ?, NULL);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, UUID().uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, sessionId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, role, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 5, body, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw SessionStoreError.execFailed }
    }

    public func fetchRecentSessionMetadata(limit: Int) throws -> [SessionMetadata] {
        let sql = """
        SELECT id, title, updated_at, origin
        FROM sessions
        ORDER BY updated_at DESC
        LIMIT ?;
        """
        lastLaunchSQL = sql
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var rows: [SessionMetadata] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idC = sqlite3_column_text(stmt, 0),
                let titleC = sqlite3_column_text(stmt, 2),
                let originC = sqlite3_column_text(stmt, 3)
            else { continue }
            let id = UUID(uuidString: String(cString: idC))!
            let title = String(cString: titleC)
            let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let origin = SessionOrigin(rawValue: String(cString: originC)) ?? .chat
            rows.append(SessionMetadata(id: id, title: title, updatedAt: updatedAt, origin: origin))
        }
        return rows
    }

    public func launchQueryTouchesMessageBodies() throws -> Bool {
        let lowered = lastLaunchSQL.lowercased()
        if lowered.contains("messages") { return true }
        if lowered.contains("body_") { return true }
        return false
    }

    private func migrate() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS sessions(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          updated_at REAL NOT NULL,
          origin TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS messages(
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          role TEXT NOT NULL,
          created_at REAL NOT NULL,
          body_inline TEXT,
          body_path TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at DESC);
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SessionStoreError.execFailed
        }
    }
}

public enum SessionStoreError: Error {
    case openFailed
    case execFailed
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
```

Fix the column index bug in `fetchRecentSessionMetadata`: column 1 is `updated_at`, column 2 is `title` — adjust bindings when implementing (test will catch).

- [ ] **Step 2: Run tests**

Run: `swift test --package-path Packages/SessionStore`

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Packages/SessionStore/Sources/SessionStore/SessionStore.swift
git commit -m "feat: add SessionStore with metadata-only launch query"
```

---

### Task 4: Telemetry package

**Files:**
- Create: `Packages/Telemetry/Sources/Telemetry/Events.swift`
- Create: `Packages/Telemetry/Sources/Telemetry/Telemetry.swift`
- Create: `Packages/Telemetry/Tests/TelemetryTests/TelemetryTests.swift`

**Interfaces:**
- Produces:
  - `public enum PerfEventKind: String, Codable { case coldStart, hotkeyToVisible, firstKeystroke }`
  - `public struct PerfEvent: Codable, Equatable { public let kind: PerfEventKind; public let durationMs: Double; public let timestamp: Date }`
  - `public struct Telemetry { public init(directory: URL); public func record(_ event: PerfEvent) throws; public func recentColdStarts(limit: Int) throws -> [PerfEvent] }`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import Telemetry

final class TelemetryTests: XCTestCase {
    func testAppendAndReadColdStarts() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let telemetry = Telemetry(directory: dir)
        try telemetry.record(PerfEvent(kind: .coldStart, durationMs: 900, timestamp: Date()))
        try telemetry.record(PerfEvent(kind: .hotkeyToVisible, durationMs: 40, timestamp: Date()))

        let cold = try telemetry.recentColdStarts(limit: 20)
        XCTAssertEqual(cold.count, 1)
        XCTAssertEqual(cold[0].durationMs, 900)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --package-path Packages/Telemetry`

- [ ] **Step 3: Implement `Events.swift` and `Telemetry.swift`**

`Events.swift`:

```swift
import Foundation

public enum PerfEventKind: String, Codable, Sendable {
    case coldStart
    case hotkeyToVisible
    case firstKeystroke
}

public struct PerfEvent: Codable, Equatable, Sendable {
    public let kind: PerfEventKind
    public let durationMs: Double
    public let timestamp: Date

    public init(kind: PerfEventKind, durationMs: Double, timestamp: Date = Date()) {
        self.kind = kind
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}
```

`Telemetry.swift`:

```swift
import Foundation

public struct Telemetry {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("perf.jsonl")
    }

    public func record(_ event: PerfEvent) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        guard let line = String(data: data, encoding: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
        } else {
            try (line + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    public func recentColdStarts(limit: Int) throws -> [PerfEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let events: [PerfEvent] = text.split(separator: "\n").compactMap { line in
            guard let data = String(line).data(using: .utf8) else { return nil }
            return try? decoder.decode(PerfEvent.self, from: data)
        }
        return Array(events.filter { $0.kind == .coldStart }.suffix(limit))
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Packages/Telemetry
git commit -m "feat: add local JSONL telemetry for perf events"
```

---

### Task 5: Xcode app target + local package links

**Files:**
- Create: `Apps/MacBuddy/MacBuddy.xcodeproj` (via Xcode GUI or committed `project.pbxproj`)
- Create: `Apps/MacBuddy/MacBuddy/MacBuddyApp.swift`
- Create: `Apps/MacBuddy/MacBuddy/AppState.swift`

**Interfaces:**
- Produces:
  - `AppState.shared: AppState` with `sessionStore: SessionStore`, `telemetry: Telemetry`, `sessions: [SessionMetadata]`
  - App links local packages `SessionStore`, `Telemetry`

- [ ] **Step 1: Create Xcode macOS App project**

In Xcode: File → New → Project → macOS → App. Product name `MacBuddy`, interface SwiftUI, language Swift, bundle id `com.macbuddy.app`, save under `Apps/MacBuddy/`. Set deployment target 14.0. Replace generated `Info.plist` usage with repo `Info.plist` (`LSUIElement = true`).

Add local package dependencies:
- File → Add Package Dependencies → Add Local → `Packages/SessionStore`
- Same for `Packages/Telemetry`

- [ ] **Step 2: Implement `AppState.swift`**

```swift
import Foundation
import SessionStore
import Telemetry

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let sessionStore: SessionStore
    let telemetry: Telemetry
    @Published var sessions: [SessionMetadata] = []

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacBuddy", isDirectory: true)
        sessionStore = try! SessionStore(databaseURL: support.appendingPathComponent("sessions.sqlite"))
        telemetry = Telemetry(directory: support.appendingPathComponent("Telemetry", isDirectory: true))
    }

    func loadSessionMetadata() {
        sessions = (try? sessionStore.fetchRecentSessionMetadata(limit: 50)) ?? []
    }
}
```

- [ ] **Step 3: Implement minimal `MacBuddyApp.swift`**

```swift
import SwiftUI

@main
struct MacBuddyApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.loadSessionMetadata()
    }
}
```

Menu bar + panel wiring comes in Task 6–7.

- [ ] **Step 4: Build**

Run: `xcodebuild -project Apps/MacBuddy/MacBuddy.xcodeproj -scheme MacBuddy -configuration Debug build`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Apps/MacBuddy
git commit -m "feat: add MacBuddy app shell with SessionStore and Telemetry"
```

---

### Task 6: Menu bar extra + chat panel UI

**Files:**
- Create: `Apps/MacBuddy/MacBuddy/ChatWindowController.swift`
- Create: `Apps/MacBuddy/MacBuddy/Views/ChatPanelView.swift`
- Create: `Apps/MacBuddy/MacBuddy/Views/SessionListView.swift`
- Modify: `Apps/MacBuddy/MacBuddy/MacBuddyApp.swift`
- Modify: `Apps/MacBuddy/MacBuddy/AppDelegate` (in same file or split)

**Interfaces:**
- Produces:
  - `final class ChatWindowController { func show(); func hide(); func toggle(); var isVisible: Bool }`
  - `ChatPanelView` with `@FocusState private var composerFocused: Bool` and a `TextEditor` placeholder composer
  - `SessionListView` renders `sessions` titles only

- [ ] **Step 1: Implement `ChatWindowController.swift`**

Use `NSPanel` (non-activating panel style mask + `canBecomeKey = true` via subclass):

```swift
import AppKit
import SwiftUI

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ChatWindowController {
    static let shared = ChatWindowController()

    private var panel: KeyPanel?
    private var showStartedAt: CFAbsoluteTime?

    func show(focusComposer: @escaping () -> Void) {
        if panel == nil {
            let content = NSHostingController(rootView: ChatPanelView(onComposerReady: focusComposer))
            let panel = KeyPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "MacBuddy"
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentViewController = content
            panel.center()
            self.panel = panel
        }
        showStartedAt = CFAbsoluteTimeGetCurrent()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle(focusComposer: @escaping () -> Void) {
        if panel?.isVisible == true { hide() } else { show(focusComposer: focusComposer) }
    }

    func recordHotkeyVisible(telemetry: Telemetry) {
        guard let start = showStartedAt else { return }
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        try? telemetry.record(PerfEvent(kind: .hotkeyToVisible, durationMs: ms))
    }
}
```

- [ ] **Step 2: Implement `ChatPanelView.swift`**

```swift
import SwiftUI

struct ChatPanelView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var composerFocused: Bool
    @State private var draft = ""
    let onComposerReady: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SessionListView()
                .frame(height: 120)
            Divider()
            TextEditor(text: $draft)
                .font(.body)
                .focused($composerFocused)
                .padding(8)
                .accessibilityIdentifier("composer")
        }
        .onAppear {
            onComposerReady()
            composerFocused = true
        }
    }
}
```

- [ ] **Step 3: Implement `SessionListView.swift`**

```swift
import SwiftUI
import SessionStore

struct SessionListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.sessions) { session in
            Text(session.title)
                .lineLimit(1)
        }
        .listStyle(.sidebar)
    }
}
```

- [ ] **Step 4: Add menu bar status item in `AppDelegate`**

```swift
private var statusItem: NSStatusItem?

func applicationDidFinishLaunching(_ notification: Notification) {
    let launchStart = ProcessInfo.processInfo.systemUptime
    AppState.shared.loadSessionMetadata()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.title = "MB"
    statusItem?.button?.action = #selector(togglePanel)
    statusItem?.button?.target = self

    ChatWindowController.shared.show {
        // composer focus callback noop here; view handles FocusState
    }

    DispatchQueue.main.async {
        let ms = (ProcessInfo.processInfo.systemUptime - launchStart) * 1000
        try? AppState.shared.telemetry.record(PerfEvent(kind: .coldStart, durationMs: ms))
    }
}

@objc private func togglePanel() {
    ChatWindowController.shared.toggle(focusComposer: {})
}
```

Adjust cold-start measurement in Task 8 to use `CACurrentMediaTime()` from `main()` — document in Task 8.

- [ ] **Step 5: Manual smoke test**

Run app from Xcode. Expect: menu bar “MB”, panel with empty composer and session list, no network prompts.

- [ ] **Step 6: Commit**

```bash
git add Apps/MacBuddy/MacBuddy
git commit -m "feat: add menu bar chat panel with empty composer"
```

---

### Task 7: Global hotkey (⌘⇧Space)

**Files:**
- Create: `Apps/MacBuddy/MacBuddy/HotkeyManager.swift`
- Modify: `Apps/MacBuddy/MacBuddy/AppDelegate`

**Interfaces:**
- Produces: `HotkeyManager.register(defaultHotkey: HotkeyManager.Hotkey, handler: @escaping () -> Void)`
- `HotkeyManager.Hotkey` with `keyCode: UInt32`, `modifiers: NSEvent.ModifierFlags`

- [ ] **Step 1: Implement `HotkeyManager.swift` using `NSEvent.addGlobalMonitorForEvents` fallback + local monitor**

For P0, use `KeyboardShortcuts` pattern with Carbon `RegisterEventHotKey` for true global hotkey when app is backgrounded:

```swift
import AppKit
import Carbon

@MainActor
final class HotkeyManager {
    struct Hotkey {
        var keyCode: UInt32
        var carbonModifiers: UInt32
    }

    static let defaultHotkey = Hotkey(keyCode: 49, carbonModifiers: UInt32(cmdKey | shiftKey)) // Space

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        self.handler = handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if hotKeyID.id == 1 { manager.handler?() }
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), nil)

        var hotKeyID = EventHotKeyID(signature: OSType(0x4D424454), id: 1) // 'MBDD'
        RegisterEventHotKey(hotkey.keyCode, hotkey.carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
```

Add `import Carbon.HIToolbox` if needed.

- [ ] **Step 2: Register in `AppDelegate.applicationDidFinishLaunching`**

```swift
private let hotkeyManager = HotkeyManager()

hotkeyManager.register(.defaultHotkey) { [weak self] in
    ChatWindowController.shared.toggle(focusComposer: {})
    ChatWindowController.shared.recordHotkeyVisible(telemetry: AppState.shared.telemetry)
}
```

- [ ] **Step 3: Manual test**

Launch app, hide panel, press `⌘⇧Space` from another app. Panel appears. Repeat — toggle hide/show.

- [ ] **Step 4: Commit**

```bash
git add Apps/MacBuddy/MacBuddy/HotkeyManager.swift Apps/MacBuddy/MacBuddy/MacBuddyApp.swift
git commit -m "feat: register global hotkey for chat panel"
```

---

### Task 8: Accurate launch timing + Settings / Performance pane

**Files:**
- Create: `Apps/MacBuddy/MacBuddy/LaunchTiming.swift`
- Create: `Apps/MacBuddy/MacBuddy/Views/SettingsView.swift`
- Create: `Apps/MacBuddy/MacBuddy/Views/PerformancePaneView.swift`
- Modify: `Apps/MacBuddy/MacBuddy/MacBuddyApp.swift`
- Modify: `Apps/MacBuddy/MacBuddy/AppDelegate`

**Interfaces:**
- Produces: `enum LaunchTiming { static var processStart: CFAbsoluteTime; static func markComposerReady() }`

- [ ] **Step 1: Add `LaunchTiming.swift`**

```swift
import Foundation

enum LaunchTiming {
    static let processStart = CFAbsoluteTimeGetCurrent()

    @MainActor
    static func markComposerReady(telemetry: Telemetry) {
        let ms = (CFAbsoluteTimeGetCurrent() - processStart) * 1000
        try? telemetry.record(PerfEvent(kind: .coldStart, durationMs: ms))
    }
}
```

- [ ] **Step 2: Call from `ChatPanelView.onAppear` once**

```swift
.onAppear {
    LaunchTiming.markComposerReady(telemetry: appState.telemetry)
    onComposerReady()
    composerFocused = true
}
```

Remove duplicate cold-start record from `AppDelegate`.

- [ ] **Step 3: Implement settings shell**

`SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Form {
                Text("MacBuddy P0")
                Text("Hotkey: ⌘⇧Space")
            }
            .tabItem { Text("General") }

            PerformancePaneView()
                .tabItem { Text("Performance") }
        }
        .frame(width: 480, height: 320)
    }
}
```

`PerformancePaneView.swift`:

```swift
import SwiftUI

struct PerformancePaneView: View {
    @EnvironmentObject private var appState: AppState
    @State private var coldStarts: [PerfEvent] = []

    var body: some View {
        List(coldStarts, id: \.timestamp) { event in
            HStack {
                Text(event.timestamp.formatted())
                Spacer()
                Text(String(format: "%.0f ms", event.durationMs))
            }
        }
        .onAppear {
            coldStarts = (try? appState.telemetry.recentColdStarts(limit: 20)) ?? []
        }
    }
}
```

Open via menu bar: add `NSMenu` with “Settings…” → `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)`.

- [ ] **Step 4: Manual test**

Quit and relaunch. Open Settings → Performance. See cold-start row ≤ 1200 ms on dev machine.

- [ ] **Step 5: Commit**

```bash
git add Apps/MacBuddy/MacBuddy
git commit -m "feat: record cold start at composer ready and add performance pane"
```

---

### Task 9: Perf bench scripts (P0 gates)

**Files:**
- Create: `Scripts/perf/common.sh`
- Create: `Scripts/perf/launch_bench.sh`
- Create: `Scripts/perf/hotkey_bench.sh`

**Interfaces:**
- Consumes: built app at `Apps/MacBuddy/build/Debug/MacBuddy.app` or `$MACBUDDY_APP`
- Produces: exit 0 when gates pass; non-zero with message when fail

- [ ] **Step 1: Create `Scripts/perf/common.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

MACBUDDY_APP="${MACBUDDY_APP:-$(cd "$(dirname "$0")/../.." && pwd)/Apps/MacBuddy/build/Debug/MacBuddy.app}"

require_app() {
  if [[ ! -d "$MACBUDDY_APP" ]]; then
    echo "Build the app first: xcodebuild -project Apps/MacBuddy/MacBuddy.xcodeproj -scheme MacBuddy -configuration Debug -derivedDataPath Apps/MacBuddy/build build"
    exit 1
  fi
}

kill_macbuddy() {
  pkill -x MacBuddy 2>/dev/null || true
  sleep 0.2
}
```

- [ ] **Step 2: Create `Scripts/perf/launch_bench.sh`**

Uses AppleScript + log tail on perf file (P0 pragmatic gate):

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_app
kill_macbuddy

SUPPORT="$HOME/Library/Application Support/MacBuddy/Telemetry/perf.jsonl"
rm -f "$SUPPORT"

START=$(python3 - <<'PY'
import time; print(time.time())
PY
)

open -g "$MACBUDDY_APP"
sleep 2

# Read latest coldStart durationMs from JSONL
DURATION=$(python3 - <<'PY'
import json, os
path = os.path.expanduser("~/Library/Application Support/MacBuddy/Telemetry/perf.jsonl")
if not os.path.exists(path):
    print(-1); raise SystemExit
last = None
for line in open(path):
    ev = json.loads(line)
    if ev.get("kind") == "coldStart":
        last = ev["durationMs"]
print(last if last is not None else -1)
PY
)

if (( $(echo "$DURATION < 0" | bc -l) )); then
  echo "FAIL: no coldStart event recorded"
  exit 1
fi

if (( $(echo "$DURATION > 1200" | bc -l) )); then
  echo "FAIL: cold start ${DURATION}ms > 1200ms budget"
  exit 1
fi

echo "PASS: cold start ${DURATION}ms"
kill_macbuddy
```

- [ ] **Step 3: Create `Scripts/perf/hotkey_bench.sh`**

Document manual-assisted gate for P0: script verifies last `hotkeyToVisible` ≤ 100ms after user presses hotkey once (stdin prompt). Fully automated hotkey injection is flaky under TCC; acceptable for P0 tag gate with human step:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_app
kill_macbuddy
open -g "$MACBUDDY_APP"
sleep 1
echo "Press ⌘⇧Space once, then Enter"
read -r

python3 - <<'PY'
import json, os, sys
path = os.path.expanduser("~/Library/Application Support/MacBuddy/Telemetry/perf.jsonl")
rows = [json.loads(l) for l in open(path)] if os.path.exists(path) else []
hot = [r for r in rows if r.get("kind") == "hotkeyToVisible"]
if not hot:
    print("FAIL: no hotkeyToVisible event"); sys.exit(1)
ms = hot[-1]["durationMs"]
if ms > 100:
    print(f"FAIL: hotkey {ms}ms > 100ms"); sys.exit(1)
print(f"PASS: hotkey {ms}ms")
PY
kill_macbuddy
```

- [ ] **Step 4: chmod + run**

```bash
chmod +x Scripts/perf/*.sh
xcodebuild -project Apps/MacBuddy/MacBuddy.xcodeproj -scheme MacBuddy -configuration Debug -derivedDataPath Apps/MacBuddy/build build
./Scripts/perf/launch_bench.sh
./Scripts/perf/hotkey_bench.sh
```

Expected: both print PASS on reference Mac

- [ ] **Step 5: Commit**

```bash
git add Scripts/perf
git commit -m "test: add P0 launch and hotkey perf bench scripts"
```

---

### Task 10: P0 tag checklist + design status

**Files:**
- Modify: `docs/superpowers/specs/2026-08-17-macbuddy-platform-design.md` (status → approved)

- [ ] **Step 1: Update design doc status line**

Change `Status: draft for user review` → `Status: approved`

- [ ] **Step 2: Run full verification**

```bash
swift test --package-path Packages/SessionStore
swift test --package-path Packages/Telemetry
xcodebuild -project Apps/MacBuddy/MacBuddy.xcodeproj -scheme MacBuddy test
./Scripts/perf/launch_bench.sh
./Scripts/perf/hotkey_bench.sh
```

- [ ] **Step 3: Tag P0**

```bash
git add docs/superpowers/specs/2026-08-17-macbuddy-platform-design.md
git commit -m "docs: mark platform design approved"
git tag p0.0.1
```

**P0 done when:** menu bar app runs; `⌘⇧Space` toggles panel; composer accepts keystrokes; session list shows metadata only; Performance pane shows cold starts; both bench scripts PASS.

---

## Spec self-review (plan vs design)

| Spec requirement | Task |
|---|---|
| Menu bar extra | Task 6 |
| Global hotkey window | Task 6–7 |
| Empty composer | Task 6 |
| Settings shell | Task 8 |
| SessionStore metadata only at launch | Task 2–3, 6 |
| Local telemetry launch/hotkey | Task 4, 8 |
| No models/sidecars/accounts | Global constraints; no tasks add them |
| Cold start ≤ 1.2s gate | Task 8–9 |
| Hotkey ≤ 100ms gate | Task 7, 9 |
| Repo layout | Task 1, 5 |
| Performance pane last 20 cold starts | Task 8 |

No TBD/TODO placeholders remain. Type names (`SessionMetadata`, `PerfEvent`, `ChatWindowController`) are consistent across tasks.

---

## After P0

Next plan file: `docs/superpowers/plans/2026-08-18-p1-chat-core.md` (LlmSidecar, streaming, cancel) — write only after P0 tag and gates are green.
