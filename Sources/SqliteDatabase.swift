//
//  SqliteDatabase.swift
//  Thermo2
//
//  Created by Ulrik Damm on 28/07/15.
//  Copyright © 2015 Robocat. All rights reserved.
//

public enum SqlError : ErrorType {
	case ParseError(String)
	case ReadError(String)
	
	case SqliteIOError(Int)
	case SqliteCorruptionError(Int)
	case SqliteConstraintViolation(Int)
	case SqliteDatatypeMismatch(Int)
	case SqliteQueryError(Int)
}

public protocol SqlPrintable {
	var sqlDescription : String { get }
}
public class SqliteDatabase {
	let db : COpaquePointer!
	
	public var debug = false
	
	static let SQLITE_STATIC = unsafeBitCast(0, sqlite3_destructor_type.self)
	static let SQLITE_TRANSIENT = unsafeBitCast(-1, sqlite3_destructor_type.self)
	
	static let errorDomain = "dk.ufd.Sqlable"
	
	var transactionLevel = 0
	
	public enum Change {
		case Insert, Update, Delete
	}
	
	public var didUpdate : ((table : String, id : Int, change : Change) -> Void)?
	public var didFail : (String -> Void)?
	
	var eventHandlers : [String : (change : Change?, tableName : String, id : Int?, callback : Int throws -> Void)] = [:]
	
	var pendingUpdates : [[(change : Change, tableName : String, id : Int)]] = []
	
	public init(filepath : String) throws {
		do {
			db = try SqliteDatabase.openDatabase(filepath)
		} catch let error {
			db = nil
			throw error
		}
		
		try execute("pragma foreign_keys = on")
		
		sqlite3_update_hook(db, onUpdate, unsafeBitCast(self, UnsafeMutablePointer<Void>.self))
	}
	
	public func observe<T : Sqlable>(change : Change? = nil, on : T.Type, id : Int? = nil, doThis : (id : Int) throws -> Void) -> String {
		let handlerId = NSUUID().UUIDString
		eventHandlers[handlerId] = (change, on.tableName, id, doThis)
		return handlerId
	}
	
	public func removeObserver(id : String) {
		eventHandlers.removeValueForKey(id)
	}
	
	static func openDatabase(filepath : String) throws -> COpaquePointer {
		var db : COpaquePointer = nil
		
		let result = sqlite3_open(filepath, &db)
		if result != SQLITE_OK {
			throw sqlErrorForCode(Int(result))
		}
		
		return db
	}
	
	deinit {
		if let db = db {
			sqlite3_close(db)
		}
	}
	
	public func fail(error : ErrorType) {
		let message : String
		
		if let error = error as? SqlError {
			switch error {
			case .ParseError(let reason): message = "Parse error: " + reason
			case .ReadError(let reason): message = "Read error: " + reason
			case .SqliteIOError(let code): message = "IO error (code \(code))"
			case .SqliteCorruptionError(let code): message = "Corruption error (code \(code))"
			case .SqliteConstraintViolation(let code): message = "Constraint violation (code \(code))"
			case .SqliteDatatypeMismatch(let code): message = "Datatype mismatch (code \(code))"
			case .SqliteQueryError(let code): message = "Invalid query (code \(code))"
			}
		} else {
			message = (error as NSError).localizedDescription
		}
		
		didFail?(message)
	}
	
	func notifyAboutUpdate(update : (change : Change, tableName : String, id : Int)) {
		didUpdate?(table: update.tableName, id: update.id, change: update.change)
		
		for (_, eventHandler) in eventHandlers {
			if update.tableName == eventHandler.tableName {
				if let change = eventHandler.change where change != update.change {
					continue
				}
				
				if let id = eventHandler.id where id != update.id {
					continue
				}
				
				do {
					try eventHandler.callback(update.id)
				} catch let error {
					fail(error)
				}
			}
		}
	}
	
	public func execute(statement : String) throws {
		let sql = statement.cStringUsingEncoding(NSUTF8StringEncoding)!
		
		if debug {
			let indentation = (0..<transactionLevel).map { _ in "  " }.joinWithSeparator("")
			print("\(indentation)SQL: \(statement)")
		}
		
		if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
			try throwLastError(db)
		}
	}
	
	public func beginTransaction() throws -> Int {
		try execute("savepoint level_\(transactionLevel + 1)")
		pendingUpdates.append([])
		transactionLevel += 1
		return transactionLevel
	}
	
	public func commitTransaction() throws {
		try execute("release level_\(transactionLevel)")
		
		transactionLevel -= 1
		
		if transactionLevel == 0 {
			for update in pendingUpdates.popLast()! {
				notifyAboutUpdate(update)
			}
		} else {
			pendingUpdates[pendingUpdates.count - 2] += pendingUpdates.popLast()!
		}
	}
	
	public func rollbackTransaction(level : Int? = nil) throws {
		let finalLevel = level ?? transactionLevel
		
		guard finalLevel <= transactionLevel else { return }
		
		try execute("rollback to level_\(finalLevel)")
		transactionLevel = finalLevel - 1
		pendingUpdates.popLast()
	}
	
	public func transaction<T>(block : SqliteDatabase throws -> T) throws -> T {
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
	
	public func createTable<T : Sqlable>(_ : T.Type) throws {
		try execute(T.createTable())
	}
	
	func run<T : Sqlable, Return>(statement : Statement<T, Return>) throws -> Any {
		guard let sql = statement.sqlDescription.cStringUsingEncoding(NSUTF8StringEncoding) else { fatalError("Invalid SQL") }
		
		if debug {
			let indentation = (0..<transactionLevel).map { _ in "  " }.joinWithSeparator("")
			print("\(indentation)SQL: \(statement.sqlDescription) \(statement.values)")
		}
		
		var handle : COpaquePointer = nil
		if sqlite3_prepare_v2(db, sql, -1, &handle, nil) != SQLITE_OK {
			try throwLastError(db)
		}
		
		try bindValues(db, handle: handle, values: statement.values, from: 1)
		
		let returnValue : Any
		
		switch statement.operation {
		case .Update, .Delete:
			if sqlite3_step(handle) != SQLITE_DONE {
				try throwLastError(db)
			}
			
			returnValue = Void()
		case .Insert:
			if sqlite3_step(handle) != SQLITE_DONE {
				try throwLastError(db)
			}
			
			returnValue = Int(sqlite3_last_insert_rowid(db))
		case .Count:
			if sqlite3_step(handle) != SQLITE_ROW { try throwLastError(db) }
			returnValue = Int(sqlite3_column_int64(handle, Int32(0)))
			
			if debug {
				let indentation = (0..<transactionLevel).map { _ in "  " }.joinWithSeparator("")
				print("\(indentation)SQL result: \(returnValue)") }
		case .Select:
			var rows : [T] = []
			
			while sqlite3_step(handle) == SQLITE_ROW {
				rows.append(try T(row: ReadRow<T>(handle: handle)))
			}
			
			if statement.single {
				returnValue = rows.first
			} else {
				returnValue = rows
			}
			
			if debug {
				let indentation = (0..<transactionLevel).map { _ in "  " }.joinWithSeparator("")
				print("\(indentation)SQL result: \(returnValue)") }
		}
		
		if sqlite3_finalize(handle) != SQLITE_OK {
			try throwLastError(db)
		}
		
		return returnValue
	}
	
	private func bindValues(db : COpaquePointer, handle : COpaquePointer, values : [SqlValue], from : Int) throws {
		for (i, value) in values.enumerate().map({ i, value in (Int32(i + from), value) }) {
			try value.bind(db, handle: handle, index: i)
		}
	}
}

func throwLastError(db : COpaquePointer) throws {
	let errorCode = Int(sqlite3_errcode(db))
	let reason = String.fromCString(sqlite3_errmsg(db))
	
	print("SQL ERROR \(errorCode): \(reason ?? "Unknown error")")
	
	throw sqlErrorForCode(errorCode)
}

private func sqlErrorForCode(code : Int) -> SqlError {
	switch Int32(code) {
	case SQLITE_CONSTRAINT, SQLITE_TOOBIG, SQLITE_ABORT: return SqlError.SqliteConstraintViolation(code)
	case SQLITE_ERROR, SQLITE_RANGE: return SqlError.SqliteQueryError(code)
	case SQLITE_MISMATCH: return SqlError.SqliteDatatypeMismatch(code)
	case SQLITE_CORRUPT, SQLITE_FORMAT, SQLITE_NOTADB: return SqlError.SqliteCorruptionError(code)
	case _: return SqlError.SqliteIOError(code)
	}
}

private func onUpdate(thisPointer : UnsafeMutablePointer<Void>, changeRaw : Int32, database : UnsafePointer<Int8>, tableNameRaw : UnsafePointer<Int8>, rowid : sqlite3_int64) {
	let this = unsafeBitCast(thisPointer, SqliteDatabase.self)
	
	let change : SqliteDatabase.Change
	
	switch changeRaw {
	case SQLITE_INSERT: change = .Insert
	case SQLITE_UPDATE: change = .Update
	case SQLITE_DELETE: change = .Delete
	case _: return
	}
	
	let tableName = String.fromCString(UnsafePointer<Int8>(tableNameRaw))!
	
	let update = (change, tableName, Int(rowid))
	
	if this.transactionLevel > 0 {
		this.pendingUpdates[this.pendingUpdates.count - 1].append(update)
	} else {
		this.notifyAboutUpdate(update)
	}
}
