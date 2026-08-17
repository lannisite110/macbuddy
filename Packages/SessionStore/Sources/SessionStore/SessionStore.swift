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
