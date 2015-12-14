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
	
	var inTransaction = false
	var updated = false
	
	public  var didUpdate : (Void -> Void)?
	public  var didFail : (String -> Void)?
	
	public init(filepath : String) throws {
		do {
			db = try SqliteDatabase.openDatabase(filepath)
		} catch let error {
			db = nil
			throw error
		}
		
		try execute("pragma foreign_keys = on")
		
//		sqlite3_update_hook(db, { _, change, _, tableName, rowid in
//			let c : String
//			
//			switch change {
//			case SQLITE_INSERT: c = "insert"
//			case SQLITE_UPDATE: c = "update"
//			case SQLITE_DELETE: c = "delete"
//			case _: c = "?"
//			}
//			
//			print("Change: \(c) \(String.fromCString(UnsafePointer<Int8>(tableName))!) \(rowid)")
//			}, nil)
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
		sqlite3_close(db)
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
	
	func update() {
		if inTransaction {
			updated = true
		} else {
			didUpdate?()
		}
	}
	
	public func execute(statement : String) throws {
		let sql = statement.cStringUsingEncoding(NSUTF8StringEncoding)!
		
		if debug { print("\(inTransaction ? "  " : "")SQL: \(statement)") }
		
		if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
			try throwLastError(db)
		}
	}
	
	public func beginTransaction() throws {
		try execute("begin transaction")
		inTransaction = true
	}
	
	public func commitTransaction() throws {
		try execute("commit transaction")
		inTransaction = false
		
		if updated {
			updated = false
			update()
		}
	}
	
	public func rollbackTransaction() throws {
		try execute("rollback transaction")
		inTransaction = false
		updated = false
	}
	
	public func transaction<T>(block : SqliteDatabase throws -> T) throws -> T {
		try beginTransaction()
		let value = try block(self)
		try commitTransaction()
		return value
	}
	
	public func createTable<T : Sqlable>(_ : T.Type) throws {
		try execute(T.createTable())
		update()
	}
	
	func run<T : Sqlable, Return>(statement : Statement<T, Return>) throws -> Any {
		guard let sql = statement.sqlDescription.cStringUsingEncoding(NSUTF8StringEncoding) else { fatalError("Invalid SQL") }
		
		if debug { print("\(inTransaction ? "  " : "")SQL: \(statement.sqlDescription) \(statement.values)") }
		
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
			update()
		case .Insert:
			if sqlite3_step(handle) != SQLITE_DONE {
				try throwLastError(db)
			}
			
			returnValue = Int(sqlite3_last_insert_rowid(db))
			update()
		case .Count:
			if sqlite3_step(handle) != SQLITE_ROW { try throwLastError(db) }
			returnValue = Int(sqlite3_column_int64(handle, Int32(0)))
			
			if debug { print("\(inTransaction ? "  " : "")SQL result: \(returnValue)") }
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
			
			if debug { print("\(inTransaction ? "  " : "")SQL result: \(returnValue)") }
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
	case SQLITE_CONSTRAINT, SQLITE_TOOBIG: return SqlError.SqliteConstraintViolation(code)
	case SQLITE_RANGE: return SqlError.SqliteQueryError(code)
	case SQLITE_MISMATCH: return SqlError.SqliteDatatypeMismatch(code)
	case SQLITE_CORRUPT, SQLITE_FORMAT, SQLITE_NOTADB: return SqlError.SqliteCorruptionError(code)
	case _: return SqlError.SqliteIOError(code)
	}
}
