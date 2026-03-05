import Foundation
import SQLite3
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "FTS5Index")

// MARK: - FTS5Error

enum FTS5Error: Error, LocalizedError {
    case openFailed(String)
    case execFailed(String)
    case prepareFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "SQLite open failed: \(msg)"
        case .execFailed(let msg): return "SQLite exec failed: \(msg)"
        case .prepareFailed(let msg): return "SQLite prepare failed: \(msg)"
        case .stepFailed(let msg): return "SQLite step failed: \(msg)"
        }
    }
}

// MARK: - FTS5Index

final class FTS5Index: @unchecked Sendable {

    // MARK: Properties

    private nonisolated(unsafe) let db: OpaquePointer
    private let lock: NSLock = NSLock()

    // MARK: Init

    init(databasePath: String) throws {
        var dbPointer: OpaquePointer?
        let result = sqlite3_open_v2(
            databasePath,
            &dbPointer,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let db = dbPointer else {
            let msg = dbPointer.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw FTS5Error.openFailed(msg)
        }
        self.db = db

        try Self.configure(db: db)
        try Self.createSchema(db: db)
        logger.info("FTS5Index: opened database at \(databasePath)")
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: Configuration

    private static func configure(db: OpaquePointer) throws {
        try exec(db: db, sql: "PRAGMA journal_mode=WAL;")
        try exec(db: db, sql: "PRAGMA mmap_size=268435456;")   // 256 MB
        try exec(db: db, sql: "PRAGMA cache_size=-64000;")      // ~64 MB
        try exec(db: db, sql: "PRAGMA synchronous=NORMAL;")
    }

    // MARK: Schema

    private static func createSchema(db: OpaquePointer) throws {
        let ddl = """
        CREATE VIRTUAL TABLE IF NOT EXISTS captures_fts
        USING fts5(
            capture_id UNINDEXED,
            ocr_text,
            tags,
            source_app
        );
        """
        try exec(db: db, sql: ddl)
    }

    // MARK: Insert

    func insert(captureID: UUID, ocrText: String, tags: String, sourceApp: String?) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = "INSERT INTO captures_fts(capture_id, ocr_text, tags, source_app) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FTS5Error.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        let idStr = captureID.uuidString
        sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))
        sqlite3_bind_text(stmt, 2, ocrText, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))
        sqlite3_bind_text(stmt, 3, tags, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))
        if let sourceApp {
            sqlite3_bind_text(stmt, 4, sourceApp, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))
        } else {
            sqlite3_bind_null(stmt, 4)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw FTS5Error.stepFailed(errorMessage())
        }
    }

    // MARK: Update

    func update(captureID: UUID, ocrText: String?, tags: String?) throws {
        lock.lock()
        defer { lock.unlock() }

        let idStr = captureID.uuidString

        // FTS5 update: delete + re-insert
        let deleteSql = "DELETE FROM captures_fts WHERE capture_id = ?;"
        var deleteStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSql, -1, &deleteStmt, nil) == SQLITE_OK else {
            throw FTS5Error.prepareFailed(errorMessage())
        }
        sqlite3_bind_text(deleteStmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))
        guard sqlite3_step(deleteStmt) == SQLITE_DONE else {
            sqlite3_finalize(deleteStmt)
            throw FTS5Error.stepFailed(errorMessage())
        }
        sqlite3_finalize(deleteStmt)

        let insertSql = "INSERT INTO captures_fts(capture_id, ocr_text, tags, source_app) VALUES (?, ?, ?, NULL);"
        var insertStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSql, -1, &insertStmt, nil) == SQLITE_OK else {
            throw FTS5Error.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(insertStmt) }

        sqlite3_bind_text(insertStmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))

        let ocrValue = ocrText ?? ""
        sqlite3_bind_text(insertStmt, 2, ocrValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))

        let tagsValue = tags ?? ""
        sqlite3_bind_text(insertStmt, 3, tagsValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))

        guard sqlite3_step(insertStmt) == SQLITE_DONE else {
            throw FTS5Error.stepFailed(errorMessage())
        }
    }

    // MARK: Delete

    func delete(captureID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = "DELETE FROM captures_fts WHERE capture_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FTS5Error.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        let idStr = captureID.uuidString
        sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw FTS5Error.stepFailed(errorMessage())
        }
    }

    // MARK: Search

    func search(query: String, limit: Int, offset: Int) throws -> [(captureID: UUID, rank: Double)] {
        lock.lock()
        defer { lock.unlock() }

        let sanitized = sanitize(query: query)
        let sql = """
            SELECT capture_id, rank
            FROM captures_fts
            WHERE captures_fts MATCH ?
            ORDER BY rank
            LIMIT ? OFFSET ?;
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FTS5Error.prepareFailed(errorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, sanitized, -1, unsafeBitCast(-1, to: sqlite3_destructor_type?.self))
        sqlite3_bind_int(stmt, 2, Int32(limit))
        sqlite3_bind_int(stmt, 3, Int32(offset))

        var results: [(captureID: UUID, rank: Double)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
            let idStr = String(cString: cStr)
            guard let uuid = UUID(uuidString: idStr) else { continue }
            let rank = sqlite3_column_double(stmt, 1)
            results.append((captureID: uuid, rank: rank))
        }

        return results
    }

    // MARK: Rebuild

    func rebuildIndex() throws {
        lock.lock()
        defer { lock.unlock() }

        try Self.exec(db: db, sql: "INSERT INTO captures_fts(captures_fts) VALUES('rebuild');")
        logger.info("FTS5Index: index rebuilt")
    }

    // MARK: Helpers

    private func errorMessage() -> String {
        String(cString: sqlite3_errmsg(db))
    }

    private static func exec(db: OpaquePointer, sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw FTS5Error.execFailed(msg)
        }
    }

    /// Wraps a user query in double-quotes for phrase matching and escapes internal quotes.
    private func sanitize(query: String) -> String {
        let escaped = query.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
