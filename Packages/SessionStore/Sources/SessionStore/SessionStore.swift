import Foundation
import SQLite3

public final class SessionStore {
    private var db: OpaquePointer?
    private let databaseURL: URL
    private(set) public var lastInsertedSessionId: UUID?
    private var lastLaunchSQL: String = ""

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
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

    public func insertMessage(sessionId: UUID, role: String, body: String, status: MessageStatus = .complete) throws -> UUID {
        let messageId = UUID()
        let inlineBody: String?
        let bodyPath: String?

        if body.utf8.count > 32_768 {
            let path = try writeBodyFile(sessionId: sessionId, messageId: messageId, body: body)
            inlineBody = nil
            bodyPath = path
        } else {
            inlineBody = body
            bodyPath = nil
        }

        let sql = """
        INSERT INTO messages(id, session_id, role, created_at, body_inline, body_path, status)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, messageId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, sessionId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, role, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
        if let inlineBody {
            sqlite3_bind_text(stmt, 5, inlineBody, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        if let bodyPath {
            sqlite3_bind_text(stmt, 6, bodyPath, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_text(stmt, 7, status.rawValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw SessionStoreError.execFailed }
        return messageId
    }

    public func updateMessage(id: UUID, body: String, status: MessageStatus) throws {
        let sql = """
        UPDATE messages SET body_inline = ?, body_path = NULL, status = ? WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, id.uuidString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw SessionStoreError.execFailed }
    }

    public func fetchMessages(sessionId: UUID) throws -> [StoredMessage] {
        let sql = """
        SELECT id, session_id, role, created_at, body_inline, body_path, status
        FROM messages
        WHERE session_id = ?
        ORDER BY created_at ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId.uuidString, -1, SQLITE_TRANSIENT)

        var rows: [StoredMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idC = sqlite3_column_text(stmt, 0),
                let sessionC = sqlite3_column_text(stmt, 1),
                let roleC = sqlite3_column_text(stmt, 2)
            else { continue }
            let id = UUID(uuidString: String(cString: idC))!
            let sessionId = UUID(uuidString: String(cString: sessionC))!
            let role = String(cString: roleC)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            let body: String
            if let inlineC = sqlite3_column_text(stmt, 4) {
                body = String(cString: inlineC)
            } else if let pathC = sqlite3_column_text(stmt, 5) {
                body = (try? String(contentsOfFile: String(cString: pathC), encoding: .utf8)) ?? ""
            } else {
                body = ""
            }
            let statusRaw = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? MessageStatus.complete.rawValue
            let status = MessageStatus(rawValue: statusRaw) ?? .complete
            rows.append(StoredMessage(id: id, sessionId: sessionId, role: role, body: body, createdAt: createdAt, status: status))
        }
        return rows
    }

    public func touchSession(id: UUID, title: String?) throws {
        let sql = """
        UPDATE sessions SET updated_at = ?, title = COALESCE(?, title) WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SessionStoreError.execFailed }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        if let title {
            sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        sqlite3_bind_text(stmt, 3, id.uuidString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw SessionStoreError.execFailed }
    }

    private func writeBodyFile(sessionId: UUID, messageId: UUID, body: String) throws -> String {
        let dir = databaseDirectory().appendingPathComponent("message-bodies", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(sessionId.uuidString)-\(messageId.uuidString).txt")
        try body.write(to: file, atomically: true, encoding: .utf8)
        return file.path
    }

    private func databaseDirectory() -> URL {
        databaseURL.deletingLastPathComponent()
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
                let titleC = sqlite3_column_text(stmt, 1),
                let originC = sqlite3_column_text(stmt, 3)
            else { continue }
            let id = UUID(uuidString: String(cString: idC))!
            let title = String(cString: titleC)
            let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
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
          body_path TEXT,
          status TEXT NOT NULL DEFAULT 'complete'
        );
        CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at DESC);
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SessionStoreError.execFailed
        }
        _ = sqlite3_exec(db, "ALTER TABLE messages ADD COLUMN status TEXT NOT NULL DEFAULT 'complete';", nil, nil, nil)
    }
}

public enum SessionStoreError: Error {
    case openFailed
    case execFailed
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
