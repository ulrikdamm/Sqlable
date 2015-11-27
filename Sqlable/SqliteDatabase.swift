//
//  SqliteDatabase.swift
//  SqliteDatabase
//
//  Created by Ulrik Damm on 24/10/2015.
//  Copyright © 2015 Ufd.dk. All rights reserved.
//

import Foundation

protocol SqlPrintable {
	var sqlDescription : String { get }
}

enum SqlType {
	case Integer
	case Real
	case Text
	case Date
	case Boolean
	indirect case Nullable(SqlType)
}

enum SqlValue : CustomStringConvertible {
	case Integer(Int)
	case Real(Double)
	case Text(String)
	case Date(NSDate)
	case Boolean(Bool)
	case Null
	
	var description : String {
		switch self {
		case .Integer(let i): return "\(i)"
		case .Real(let d): return "\(d)"
		case .Text(let s): return "\(s)"
		case .Date(let d): return "\(d)"
		case .Boolean(let b): return b ? "true" : "false"
		case .Null: return "null"
		}
	}
}

struct Filter : SqlPrintable {
	enum Predicate {
		case Equal
		case NotEqual
	}
	
	let key : String
	let value : SqlValue
	let predicate : Predicate
	
	init(_ key : String, _ predicate : Predicate, _ value : SqlValue) {
		self.key = key
		self.value = value
		self.predicate = predicate
	}
	
	var sqlDescription : String {
		let sep : String
		
		switch (predicate, value) {
		case (.Equal, .Null): sep = "is"
		case (.NotEqual, .Null): sep = "is not"
		case (.Equal, _): sep = "="
		case (.NotEqual, _): sep = "!="
		}
		
		return "\(key) \(sep) ?"
	}
}

extension Array where Element : SqlPrintable {
	var sqlDescription : String {
		return self.map { $0.sqlDescription }.joinWithSeparator(" and ")
	}
}

struct Order : SqlPrintable {
	enum Direction {
		case Asc
		case Desc
	}
	
	let column : String
	let direction : Direction
	
	init(_ column : String, _ direction : Direction) {
		self.column = column
		self.direction = direction
	}
	
	var sqlDescription : String {
		return "\(column) " + (direction == .Desc ? "desc" : "")
	}
}

protocol ColumnOption : SqlPrintable {
	
}

struct PrimaryKey : ColumnOption {
	let autoincrement : Bool
	
	var sqlDescription : String {
		return "primary key" + (autoincrement ? " autoincrement" : "")
	}
}

enum Rule : SqlPrintable {
	case Ignore, Cascade, SetNull, SetDefault
	
	var sqlDescription : String {
		switch self {
		case .Ignore: return "no action"
		case .Cascade: return "cascade"
		case .SetNull: return "set null"
		case .SetDefault: return "set default"
		}
	}
}

struct ForeignKey<To : Sqlable> : ColumnOption, SqlPrintable {
	let column : String
	let onDelete : Rule
	let onUpdate : Rule
	
	init(column : String = "id", onDelete : Rule = .Ignore, onUpdate : Rule = .Ignore) {
		self.column = column
		self.onDelete = onDelete
		self.onUpdate = onUpdate
	}
	
	var sqlDescription : String {
		return "references \(To.tableName)(\(column)) on update \(onUpdate.sqlDescription) on delete \(onDelete.sqlDescription)"
	}
}

struct Column {
	let name : String
	let type : SqlType
	let options : [ColumnOption]
	
	init(_ name : String, _ type : SqlType, _ options : ColumnOption...) {
		self.name = name
		self.type = type
		self.options = options
	}
}

extension SqlType : SqlPrintable {
	var sqlDescription : String {
		switch self {
		case .Integer: return "integer not null"
		case .Real: return "double not null"
		case .Text: return "text not null"
		case .Date: return "timestamp not null"
		case .Boolean: return "integer not null"
		case .Nullable(.Integer): return "integer"
		case .Nullable(.Real): return "double"
		case .Nullable(.Text): return "text"
		case .Nullable(.Date): return "timestamp"
		case .Nullable(.Boolean): return "integer"
		case .Nullable(.Nullable(_)): fatalError("Nice try")
		}
	}
}

extension Column : SqlPrintable {
	var sqlDescription : String {
		var statement =  "\(name) \(type.sqlDescription)"
		
		if options.count > 0 {
			let optionsString = options.map { $0.sqlDescription }.joinWithSeparator(" ")
			statement += " \(optionsString)"
		}
		
		return statement
	}
}

struct ReadRow<T : Sqlable> {
	private let handle : COpaquePointer
	let type = T.self
	
	func get(name : String) -> Int {
		let index = type.tableLayout.indexOf { $0.name == name }!
		return Int(sqlite3_column_int64(handle, Int32(index)))
	}
	
	func get(name : String) -> Double {
		let index = type.tableLayout.indexOf { $0.name == name }!
		return Double(sqlite3_column_double(handle, Int32(index)))
	}
	
	func get(name : String) -> String {
		let index = type.tableLayout.indexOf { $0.name == name }!
		return String.fromCString(UnsafePointer<Int8>(sqlite3_column_text(handle, Int32(index))))!
	}
	
	func get(name : String) -> NSDate {
		let timestamp : Int = get(name)
		return NSDate(timeIntervalSince1970: NSTimeInterval(timestamp))
	}
	
	func get(name : String) -> Bool {
		let index = type.tableLayout.indexOf { $0.name == name }!
		return sqlite3_column_int(handle, Int32(index)) == 0 ? false : true
	}
	
	func get(name : String) -> Int? {
		let index = type.tableLayout.indexOf { $0.name == name }!
		if sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL {
			return nil
		} else {
			let i : Int = get(name)
			return i
		}
	}
	
	func get(name : String) -> Double? {
		let index = type.tableLayout.indexOf { $0.name == name }!
		if sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL {
			return nil
		} else {
			let i : Double = get(name)
			return i
		}
	}
	
	func get(name : String) -> String? {
		let index = type.tableLayout.indexOf { $0.name == name }!
		if sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL {
			return nil
		} else {
			let i : String = get(name)
			return i
		}
	}
	
	func get(name : String) -> NSDate? {
		let index = type.tableLayout.indexOf { $0.name == name }!
		if sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL {
			return nil
		} else {
			let i : NSDate = get(name)
			return i
		}
	}
	
	func get(name : String) -> Bool? {
		let index = type.tableLayout.indexOf { $0.name == name }!
		if sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL {
			return nil
		} else {
			let i : Bool = get(name)
			return i
		}
	}
}

protocol Sqlable {
	static var tableName : String { get }
	static var tableLayout : [Column] { get }
	
	static func columnForName(name : String) -> Column?
	func valueForColumn(column : Column) -> SqlValue?
	init(row : ReadRow<Self>) throws
}

enum Operation {
	case Select([Column])
	case Insert([(Column, SqlValue)])
	case Update([(Column, SqlValue)])
	case Count
	case Delete
}

struct Statement<T : Sqlable, Return> {
	let operation : Operation
	let filters : [Filter]
	let orderBy : [Order]
	let limit : Int?
	
	init(operation : Operation, filters : [Filter] = [], orderBy : [Order] = [], limit : Int? = nil) {
		self.operation = operation
		self.filters = filters
		self.orderBy = orderBy
		self.limit = limit
	}
	
	func filter(filter : Filter) -> Statement {
		return Statement(operation: operation, filters: filters + [filter], orderBy: orderBy, limit: limit)
	}
	
	func filter(key : String, _ predicate : Filter.Predicate, _ value : SqlValue) -> Statement {
		let filter = Filter(key, predicate, value)
		return Statement(operation: operation, filters: filters + [filter], orderBy: orderBy, limit: limit)
	}
	
	func orderBy(order : Order) -> Statement {
		return Statement(operation: operation, filters: filters, orderBy: orderBy + [order], limit: limit)
	}
	
	func orderBy(columnName : String, _ direction : Order.Direction = .Asc) -> Statement {
		let order = Order(columnName, direction)
		return Statement(operation: operation, filters: filters, orderBy: orderBy + [order], limit: limit)
	}
	
	func limit(limit : Int) -> Statement {
		return Statement(operation: operation, filters: filters, orderBy: orderBy, limit: limit)
	}
	
	var sqlDescription : String {
		var sql : [String]
		
		switch operation {
		case .Select(let columns):
			let columnNames = columns.map { $0.name }.joinWithSeparator(", ")
			sql = ["select \(columnNames) from \(T.tableName)"]
		case .Insert(let ops):
			let columnNames = ops.map { column, value in column.name }.joinWithSeparator(", ")
			let values = ops.map { _ in "?" }.joinWithSeparator(", ")
			sql = ["insert into \(T.tableName) (\(columnNames)) values (\(values))"]
		case .Update(let ops):
			let values = ops.map { column, _ in "\(column.name) = ?" }.joinWithSeparator(", ")
			sql = ["update \(T.tableName) set \(values)"]
		case .Count:
			sql = ["select count(*) from \(T.tableName)"]
		case .Delete:
			sql = ["delete from \(T.tableName)"]
		}
		
		if filters.count > 0 {
			sql.append("where " + filters.sqlDescription)
		}
		
		if orderBy.count > 0 {
			sql.append("order by " + orderBy.sqlDescription)
		}
		
		if let limit = limit {
			sql.append("limit \(limit)")
		}
		
		return sql.joinWithSeparator(" ")
	}
	
	var values : [SqlValue] {
		var values : [SqlValue] = []
		
		switch operation {
		case .Select(_): break
		case .Insert(let ops): values += ops.map { column, value in value }
		case .Update(let ops): values += ops.map { column, value in value }
		case .Count: break
		case .Delete: break
		}
		
		for filter in filters {
			values.append(filter.value)
		}
		
		return values
	}
	
	func run(db : SqliteDatabase) throws -> Return {
		return try db.run(self) as! Return
	}
}

extension Sqlable {
	static var tableName : String {
		let typeName = "table_\(Mirror(reflecting: self).subjectType)"
		return typeName
			.substringToIndex(typeName.endIndex.advancedBy(-5))
			.lowercaseString
	}
	
	static func createTable() -> String {
		let columns = tableLayout.map { $0.sqlDescription }.joinWithSeparator(", ")
		return "create table if not exists \(tableName) (\(columns))"
	}
	
	static func columnForName(name : String) -> Column? {
		return Self.tableLayout.filter { column in column.name == name }.first
	}
	
	func updateStatement(filters : [Filter]) -> Statement<Self, Void> {
		let values = Self.tableLayout.flatMap { column in valueForColumn(column).flatMap { (column, $0) } }
		return Statement(operation: .Update(values), filters: filters)
	}
	
	func insertStatement() -> Statement<Self, Void> {
		let values = Self.tableLayout.flatMap { column in valueForColumn(column).flatMap { (column, $0) } }
		return Statement(operation: .Insert(values))
	}
	
	static func countStatement() -> Statement<Self, Int> {
		return Statement(operation: .Count)
	}
	
	func deleteStatement() -> Statement<Self, Void> {
		return Statement(operation: .Delete)
	}
	
	static func readStatement() -> Statement<Self, [Self]> {
		return Statement(operation: .Select(Self.tableLayout))
	}
}

class SqliteDatabase {
	let db : COpaquePointer!
	
	static let SQLITE_STATIC = unsafeBitCast(0, sqlite3_destructor_type.self)
	static let SQLITE_TRANSIENT = unsafeBitCast(-1, sqlite3_destructor_type.self)
	
	static let errorDomain = "cat.robo.Thermo.SqliteDatabase"
	
	init(filepath : String) throws {
		do {
			db = try SqliteDatabase.openDatabase(filepath)
		} catch let error {
			db = nil
			throw error
		}
		
		try execute("pragma foreign_keys = on")
	}
	
	static func openDatabase(filepath : String) throws -> COpaquePointer {
		var db : COpaquePointer = nil
		
		if sqlite3_open(filepath, &db) != SQLITE_OK {
			throw NSError(domain: errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't open database"])
		}
		
		return db
	}
	
	deinit {
		sqlite3_close(db)
	}
	
	func execute(statement : String) throws {
		let sql = statement.cStringUsingEncoding(NSUTF8StringEncoding)!
		
		print("SQL: \(statement)")
		
		if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
			try throwLastError(db)
		}
	}
	
	func transaction(block : Void throws -> Void) throws {
		try execute("begin transaction")
		try block()
		try execute("commit transaction")
	}
	
	func createTable<T : Sqlable>(_ : T.Type) throws {
		try execute(T.createTable())
	}
	
	private func run<T : Sqlable, Return>(statement : Statement<T, Return>) throws -> Any? {
		guard let sql = statement.sqlDescription.cStringUsingEncoding(NSUTF8StringEncoding) else { fatalError("Invalid SQL") }
		
		print("SQL: \(statement.sqlDescription)")
		
		var handle : COpaquePointer = nil
		if sqlite3_prepare_v2(db, sql, -1, &handle, nil) != SQLITE_OK {
			try throwLastError(db)
		}
		
		try bindValues(db, handle: handle, values: statement.values, from: 1)
		
		let returnValue : Any?
		
		switch statement.operation {
		case .Delete: fallthrough
		case .Insert: fallthrough
		case .Update:
			if sqlite3_step(handle) != SQLITE_DONE {
				try throwLastError(db)
			}
			
			returnValue = Void()
		case .Count:
			if sqlite3_step(handle) != SQLITE_ROW { try throwLastError(db) }
			returnValue = Int(sqlite3_column_int64(handle, Int32(0)))
		case .Select:
			var rows : [T] = []
			
			while sqlite3_step(handle) == SQLITE_ROW {
				rows.append(try T(row: ReadRow<T>(handle: handle)))
			}
			
			returnValue = rows
		}
		
		if sqlite3_finalize(handle) != SQLITE_OK {
			try throwLastError(db)
		}
		
		return returnValue
	}
	
	private func bindValues(db : COpaquePointer, handle : COpaquePointer, values : [SqlValue], from : Int) throws {
		guard values.count > 0 else { return }
		
		print("SQL bind: \(values)")
		
		for (i, value) in values.enumerate().map({ i, value in (Int32(i + from), value) }) {
			let result : Int32
			
			switch value {
			case .Integer(let value): result = sqlite3_bind_int64(handle, i, Int64(value))
			case .Real(let value): result = sqlite3_bind_double(handle, i, value)
			case .Text(let value): result = sqlite3_bind_text(handle, i, value, -1, SqliteDatabase.SQLITE_TRANSIENT)
			case .Date(let value): result = sqlite3_bind_int64(handle, i, Int64(value.timeIntervalSince1970))
			case .Boolean(let value): result = sqlite3_bind_int(handle, i, Int32(value ? 1 : 0))
			case .Null: result = sqlite3_bind_null(handle, i)
			}
			
			if result != SQLITE_OK {
				try throwLastError(db)
			}
		}
	}
}

private func throwLastError(db : COpaquePointer) throws {
	var userInfo : [String: AnyObject] = [:]
	let errorCode = Int(sqlite3_errcode(db))
	
	if let errorMessage = String.fromCString(sqlite3_errmsg(db)) {
		userInfo[NSLocalizedDescriptionKey] = errorMessage
		print("SQL ERROR: \(errorMessage)")
	}
	
	throw NSError(domain: "", code: errorCode, userInfo: userInfo)
}
