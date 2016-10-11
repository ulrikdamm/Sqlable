//
//  SqliteDatabase.swift
//  Thermo2
//
//  Created by Ulrik Damm on 28/07/15.
//  Copyright © 2015 Robocat. All rights reserved.
//

/// Errors to occur when running SQL commands.
public enum SqlError : Error {
	/// Error when data returned from the database didn't match the defined data types.
	case readError(String)
	
	/// Sqlite IO error (database is locked, busy or file IO failed)
	case sqliteIOError(Int)
	/// Sqlite error when database has been corrupted.
	case sqliteCorruptionError(Int)
	/// Sqlite error when a constraint was violated (e.g. duplicate primary keys, broken foreign keys)
	case sqliteConstraintViolation(Int)
	/// Sqlite error when trying to insert a non-integer as a primary key.
	case sqliteDatatypeMismatch(Int)
	/// Sqlite error when trying to execute an invalid query.
	case sqliteQueryError(Int)
}

/// Something which can be expressed in SQL.
public protocol SqlPrintable {
	var sqlDescription : String { get }
}

/// Class for managing a single database connection.
public class SqliteDatabase {
	let db : OpaquePointer!
	let filepath : String
	
	var parent : SqliteDatabase?
	
	/// The queue associated with this database connection.
	/// All operations using this connection should always run on this queue.
	/// This is also the queue that change notifications are delivered on. You are free to change this value.
	public var queue = DispatchQueue.main
	
	/// Enables or disables print debugging. Will print out all SQL statements executed, and all results returned.
	public var debug = false
	
	static let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
	static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
	
	var transactionLevel = 0
	
	/// The type of change from an update notifications.
	public enum Change {
		case insert, update, delete
	}
	
	///	Update callback. This block will be called every time there was an update in the database connection, or any child connection.
	public var didUpdate : ((String, Int, Change) -> Void)?
	
	///	Failure callback. This block will be called whenever an error is delivered via `fail(_:)`.
	///	- SeeAlso: `fail(_:)`
	public var didFail : ((String) -> Void)?
	
	var eventHandlers : [String : (change : Change?, tableName : String, id : Int?, callback : (Int) throws -> Void)] = [:]
	
	var pendingUpdates : [[(change : Change, tableName : String, id : Int)]] = []
	
	///	Opens a connection to the database at the specified file location. If there is no database file, a new one is created.
	///	
	///	- Parameters:
	///		- filePath: The path of the database file
	/// - Throws: SqlError if the database couldn't be created
	public init(filepath : String) throws {
		self.filepath = filepath
		
		do {
			db = try SqliteDatabase.openDatabase(filepath)
		} catch let error {
			db = nil
			throw error
		}
		
		try execute("pragma foreign_keys = on")
		try execute("pragma journal_mode = WAL")
		try execute("pragma busy_timeout = 1000000")
		
		sqlite3_update_hook(db, onUpdate, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
	}
	
	
	///	Deletes the database at the specified file location. This also removes any files created by Sqlite, so use this istead of removing the database file manually.
	///	
	///	- Parameters:
	///		- filePath: The path of the database file
	/// - Throws: Eventual errors from `NSFileManager`
	public static func deleteDatabase(at filepath : String) throws {
		try FileManager.default.removeItem(atPath: filepath)
		try FileManager.default.removeItem(atPath: filepath + "-shm")
		try FileManager.default.removeItem(atPath: filepath + "-wal")
	}
	
	/// Begin observing a change in the database.
	/// 
	/// - Parameters:
	///		- change: Which change to notify on (insert, update or delete). If nil, notifies on any change.
	///		- on: Which table (Sqlable type) to observe changes on.
	///		- id: Which id to observe changes on. If nil, observes any id.
	///		- doThis: The block called when the specified change has occured in the database.
	///			Any errors thrown from this call will be passed to `didFail(_:)`.
	///			- id: The id of the inserted/updated/deleted object.
	///	- Returns: A string handle you can use for removing the observer if you don't need it anymore.
	public func observe<T : Sqlable>(_ change : Change? = nil, on : T.Type, id : Int? = nil, doThis : @escaping (Int) throws -> Void) -> String {
		let handlerId = UUID().uuidString
		eventHandlers[handlerId] = (change, on.tableName, id, doThis)
		
		return handlerId
	}
	
	/// Unregisters an observer.
	///
	/// Parameters:
	///		- id: The handle returned from `observe(change:on:id:doThis:)`
	public func removeObserver(_ id : String) {
		eventHandlers.removeValue(forKey: id)
	}
	
	static func openDatabase(_ filepath : String) throws -> OpaquePointer {
		var db : OpaquePointer? = nil
		
		let result = sqlite3_open(filepath, &db)
		if result != SQLITE_OK {
			throw sqlErrorForCode(Int(result))
		}
		
		return db!
	}
	
	deinit {
		if let db = db {
			sqlite3_close(db)
		}
	}
	
	/// Creates a child database. Use this if you want to use the database on a separate thread/queue.
	/// All update notifications from a child connection will also happen in the parent, but not the other way around.
	///
	/// - Throws: SqlError if the database connection couldn't be created.
	public func createChild() throws -> SqliteDatabase {
		let db = try SqliteDatabase(filepath: filepath)
		db.parent = self
		return db
	}
	
	/// Pass a received error to the database. This will create an error with description and return it via `didFail(_:)`
	///
	/// Parameters:
	///		- error: The error to notify of. Should probably be a SqlError, but any error will also work.
	public func fail(_ error : Error) {
		let message : String
		
		if let error = error as? SqlError {
			switch error {
			case .readError(let reason): message = "Read error: " + reason
			case .sqliteIOError(let code): message = "IO error (code \(code))"
			case .sqliteCorruptionError(let code): message = "Corruption error (code \(code))"
			case .sqliteConstraintViolation(let code): message = "Constraint violation (code \(code))"
			case .sqliteDatatypeMismatch(let code): message = "Datatype mismatch (code \(code))"
			case .sqliteQueryError(let code): message = "Invalid query (code \(code))"
			}
		} else {
			message = (error as NSError).localizedDescription
		}
		
		didFail?(message)
	}
	
	func notifyAboutUpdate(_ update : (change : Change, tableName : String, id : Int)) {
		didUpdate?(update.tableName, update.id, update.change)
		
		for (_, eventHandler) in eventHandlers {
			if update.tableName == eventHandler.tableName {
				if let change = eventHandler.change, change != update.change {
					continue
				}
				
				if let id = eventHandler.id, id != update.id {
					continue
				}
				
				do {
					try eventHandler.callback(update.id)
				} catch let error {
					fail(error)
				}
			}
		}
		
		if let parent = parent {
			parent.queue.async {
				parent.notifyAboutUpdate(update)
			}
		}
	}
	
	/// Execute a raw SQL command.
	/// Please don't pass any parameters in to this function. This is considered very unsafe. `statement` should be a string literal.
	///
	/// - Parameters:
	///		- statement: The SQL command to run.
	/// - Throws: SqlError if any errors happened running the command.
	public func execute(_ statement : String) throws {
		let sql = statement.cString(using: String.Encoding.utf8)!
		
		if debug {
			let indentation = (0..<transactionLevel).map { _ in "  " }.joined(separator: "")
			print("\(indentation)SQL: \(statement)")
		}
		
		if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
			try throwLastError(db)
		}
	}
	
	/// Begin a SQL transaction.
	/// Should be completed with a call to either `commitTransaction()` or `rollbackTransaction()`.
	/// You can start transactions inside other transactions.
	/// 
	/// - Throws: SqlError if the transaction couldn't start.
	public func beginTransaction() throws -> Int {
		if transactionLevel == 0 {
			try execute("begin deferred transaction")
		} else {
			try execute("savepoint level_\(transactionLevel + 1)")
		}
		
		pendingUpdates.append([])
		transactionLevel += 1
		return transactionLevel
	}
	
	/// Commit a SQL transaction.
	/// Should be called in correspondance to a `beginTransaction()`.
	///
	/// - Throws: SqlError if the transaction couldn't commit.
	public func commitTransaction() throws {
		if transactionLevel == 1 {
			try execute("commit transaction")
		} else {
			try execute("release level_\(transactionLevel)")
		}
		
		transactionLevel -= 1
		
		if transactionLevel == 0 {
			for update in pendingUpdates.popLast()! {
				notifyAboutUpdate(update)
			}
		} else {
			pendingUpdates[pendingUpdates.count - 2] += pendingUpdates.popLast()!
		}
	}
	
	/// Rolls back changes in a SQL transaction.
	/// Should be called in correspondance to a `beginTransaction()`.
	/// 
	/// - Throws: SqlError if the transaction couldn't roll back.
	public func rollbackTransaction(_ level : Int? = nil) throws {
		let finalLevel = level ?? transactionLevel
		
		guard finalLevel <= transactionLevel else { return }
		
		if finalLevel == 1 {
			try execute("rollback transaction")
		} else {
			try execute("rollback to level_\(finalLevel)")
		}
		
		transactionLevel = finalLevel - 1
		_ = pendingUpdates.popLast()
	}
	
	/// Perform a SQL transaction.
	/// Runs the code within the block in a SQL transaction.
	/// If any errors occurs in the block, the changes are rolled back.
	/// Otherwise, they are committed.
	/// You can start transactions inside other transactions.
	///
	/// Parameters:
	///		- block: The code to be run inside of the transaction.
	///		The database connection is passed to the block, and any value returned will be the return value of the `transaction(block:)` call.
	///	Returns: The value returned from the block call.
	/// Throws: SqlError if the transaction couldn't be started, committed or rolled back, or any error thrown from the block.
	public func transaction<T>(_ block : (SqliteDatabase) throws -> T) throws -> T {
		let level = try beginTransaction()
		
		let value : T
		do {
			value = try block(self)
		} catch let error {
			try rollbackTransaction(level)
			throw error
		}
		
		try commitTransaction()
		return value
	}
	
	/// Creates the SQL table for a Sqlable type.
	/// If the table already exists, no operation is performed.
	///
	/// - Parameters:
	///		- _: A Sqlable type (use e.g. Table.self)
	/// - Throws: A SqlError if the table couldn't be created.
	public func createTable<T : Sqlable>(_ : T.Type) throws {
		try execute(T.createTable())
	}
	
	func run<T : Sqlable, Return>(_ statement : Statement<T, Return>) throws -> Any {
		guard let sql = statement.sqlDescription.cString(using: String.Encoding.utf8) else { fatalError("Invalid SQL") }
		
		if debug {
			let indentation = (0..<transactionLevel).map { _ in "  " }.joined(separator: "")
			print("\(indentation)SQL: \(statement.sqlDescription) \(statement.values)")
		}
		
		var handlePointer : OpaquePointer? = nil
		if sqlite3_prepare_v2(db, sql, -1, &handlePointer, nil) != SQLITE_OK {
			try throwLastError(db)
		}
		
		guard let handle = handlePointer else { fatalError("No SQL handle received") }
		
		try bindValues(db, handle: handle, values: statement.values, from: 1)
		
		let returnValue : Any
		
		switch statement.operation {
		case .insert, .update, .delete:
			var waits = 1000
			
			loop: while true {
				switch sqlite3_step(handle) {
				case SQLITE_ROW: continue
				case SQLITE_DONE: break loop
				case SQLITE_BUSY:
					if waits == 0 { try throwLastError(db) }
					waits -= 1
					usleep(10000)
				case _: try throwLastError(db)
				}
			}
			
			if case .insert = statement.operation {
				returnValue = Int(sqlite3_last_insert_rowid(db))
			} else {
				returnValue = Void()
			}
		case .count:
			var waits = 1000
			
			loop: while true {
				switch sqlite3_step(handle) {
				case SQLITE_ROW: break loop
				case SQLITE_DONE: break loop
				case SQLITE_BUSY:
					if waits == 0 { try throwLastError(db) }
					waits -= 1
					usleep(10000)
				case _: try throwLastError(db)
				}
			}
			
			returnValue = Int(sqlite3_column_int64(handle, 0))
		case .select:
			var rows : [T] = []
			
			var waits = 1000
			loop: while true {
				switch sqlite3_step(handle) {
				case SQLITE_ROW:
					rows.append(try T(row: ReadRow(handle: handle, tablename: T.tableName)))
					continue
				case SQLITE_DONE: break loop
				case SQLITE_BUSY:
					if waits == 0 { try throwLastError(db) }
					waits -= 1
					usleep(10000)
				case _: try throwLastError(db)
				}
			}
			
			if statement.single {
				if let first = rows.first {
					returnValue = SingleResult.result(first)
				} else {
					returnValue = SingleResult<T>.noResult
				}
			} else {
				returnValue = rows
			}
		}
		
		if debug {
			switch statement.operation {
			case .count, .select:
				let indentation = (0..<transactionLevel).map { _ in "  " }.joined(separator: "")
				print("\(indentation)SQL result: \(returnValue)")
			case _: break
			}
		}
		
		if sqlite3_finalize(handle) != SQLITE_OK {
			try throwLastError(db)
		}
		
		return returnValue
	}
	
	private func bindValues(_ db : OpaquePointer, handle : OpaquePointer, values : [SqlValue], from : Int) throws {
		for (i, value) in values.enumerated().map({ i, value in (Int32(i + from), value) }) {
			try value.bind(db, handle: handle, index: i)
		}
	}
}

func throwLastError(_ db : OpaquePointer) throws {
	let errorCode = Int(sqlite3_errcode(db))
	let reason = String(validatingUTF8: sqlite3_errmsg(db))
	let extendedError = Int(sqlite3_extended_errcode(db))
	
	print("SQL ERROR \(errorCode) (\(extendedError)): \(reason ?? "Unknown error")")
	
	throw sqlErrorForCode(errorCode)
}

private func sqlErrorForCode(_ code : Int) -> SqlError {
	switch Int32(code) {
	case SQLITE_CONSTRAINT, SQLITE_TOOBIG, SQLITE_ABORT: return SqlError.sqliteConstraintViolation(code)
	case SQLITE_ERROR, SQLITE_RANGE: return SqlError.sqliteQueryError(code)
	case SQLITE_MISMATCH: return SqlError.sqliteDatatypeMismatch(code)
	case SQLITE_CORRUPT, SQLITE_FORMAT, SQLITE_NOTADB: return SqlError.sqliteCorruptionError(code)
	case _: return SqlError.sqliteIOError(code)
	}
}

private func onUpdate(_ thisPointer : UnsafeMutableRawPointer?, changeRaw : Int32, database : UnsafePointer<Int8>?, tableNameRaw : UnsafePointer<Int8>?, rowid : sqlite3_int64) {
	let this = unsafeBitCast(thisPointer, to: SqliteDatabase.self)
	
	let change : SqliteDatabase.Change
	
	switch changeRaw {
	case SQLITE_INSERT: change = .insert
	case SQLITE_UPDATE: change = .update
	case SQLITE_DELETE: change = .delete
	case _: return
	}
	
	let tableName = String(validatingUTF8: UnsafePointer<Int8>(tableNameRaw!))!
	
	let update = (change, tableName, Int(rowid))
	
	if this.transactionLevel > 0 {
		this.pendingUpdates[this.pendingUpdates.count - 1].append(update)
	} else {
		this.notifyAboutUpdate(update)
	}
}
