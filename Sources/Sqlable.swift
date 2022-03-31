
//
//  Sqlable.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

///	Something that can be a constraint on a SQL table.
public protocol TableConstraint : SqlPrintable {}

/// A unique constraint on a SQL table. Ensures that a column, or a combination of columns, have a unique value.
public struct Unique : TableConstraint {
	/// The columns to check for uniqueness.
	public let columns : [Column]
	
	/// Creates a Unique constraint on the specified columns
	///
	/// - Parameters:
	//		- _: The columns to constrain.
	public init(_ columns : [Column]) {
		self.columns = columns
	}
	
	/// Creates a Unique constraint on the specified columns
	///
	/// - Parameters:
	//		- _: The columns to constrain.
	public init(_ columns : Column...) {
		self.columns = columns
	}
	
	/// Get the SQL description of the unique constraint.
	public var sqlDescription : String {
		let columnList = columns.map { $0.name }.joined(separator: ", ")
		return "unique (\(columnList)) on conflict abort"
	}
}

/// Something that can work as a SQL table.
public protocol Sqlable {
	/// The name of the table in the database. Optional, defaults to `table_{type name}`.
	static var tableName : String { get }
	
	/// The columns of the table.
	static var tableLayout : [Column] { get }
	
	/// The constraints of the table. Optional, defaults to no table constraints (but individual columns can still have value constraints).
	static var tableConstraints : [TableConstraint] { get }
	
	/// Returns the current value of a column. For when inserting values into the Sqlite database.
	///
	/// - Parameters:
	///		- column: The Column to get the value for. Will be one of the colums specified in `tableLayout`.
	///	- Returns: A SqlValue to insert into the row.
	///		For null, return a Null().
	///		When returning nil, the column will be omitted completely, and will need to have a default value.
	func valueForColumn(_ column : Column) -> SqlValue?
	
	/// Reads a row from the Sqlite database.
	///
	/// - Parameters:
	///		- row: An object which can be used to access data from a row returned from the database.
	///	- Throws: A SqlError, preferrebly ReadError, if the row couldn't be parsed correctly.
	init(row : ReadRow) throws
}

public extension Sqlable {
	static var tableName : String {
		let typeName = "table_\(Mirror(reflecting: self).subjectType)"
		return String(typeName[..<typeName.index(typeName.endIndex, offsetBy: -5)])
			.lowercased()
	}
	
	static var tableConstraints : [TableConstraint] {
		return []
	}
	
	/// SQL statement for creating a Sqlable as a table in Sqlite.
	///
	/// - Returns: A SQL statement string.
	static func createTable() -> String {
		let columns = tableLayout.map { $0.sqlDescription }
		let constraints = tableConstraints.map { $0.sqlDescription }
		let fields = (columns + constraints).joined(separator: ", ")
		return "create table if not exists \(tableName) (\(fields))"
	}
	
	/// Returns the Column object for a specified column name.
	///
	/// - Parameters:
	///		- name: The name of the column
	///	- Returns: The found column, or nil if none found.
	static func columnForName(_ name : String) -> Column? {
		return Self.tableLayout.lazy.filter { column in column.name == name }.first
	}
	
	/// Finds and returns the primary key column.
	///
	/// - Returns: The primary key column or nil.
	static func primaryColumn() -> Column? {
		return Self.tableLayout.lazy.filter { $0.options.contains { $0 is PrimaryKey } }.first
	}
	
	/// Create an update statement, which can be run against a database.
	/// Will run a SQL update on the object it's called from.
	///
	/// - Precondition:
	///		- Self needs to have a primary key
	///		- self needs to have a value for its primary key
	/// - Returns: An update statement instance.
	func update() -> Statement<Self, Void> {
		guard let primaryColumn = Self.primaryColumn() else { fatalError("\(self) doesn't have a primary key") }
		guard let primaryValue = valueForColumn(primaryColumn) else { fatalError("\(self) doesn't have a primary key value") }
		let values = Self.tableLayout.flatMap { column in valueForColumn(column).flatMap { (column, $0) } }
		return Statement(operation: .update(values)).filter(primaryColumn == primaryValue)
	}
	
	/// Create an insert statement, which can be run against a database.
	/// Will run an insert statement on the object it's called from.
	///
	/// - Returns: An insert statement instance.
	func insert() -> Statement<Self, Int> {
		let values = Self.tableLayout.flatMap { column in valueForColumn(column).flatMap { (column, $0) } }
		return Statement(operation: .insert(values))
	}
	
	/// Create a delete statement, which can be run against a database.
	/// Will run a delete statement on the object it's called from.
	///
	/// - Precondition:
	///		- Self needs to have a primary key
	///		- self needs to have a value for its primary key
	/// - Returns: A delete statement instance
	func delete() -> Statement<Self, Void> {
		guard let primaryColumn = Self.primaryColumn() else { fatalError("\(self) doesn't have a primary key") }
		guard let primaryValue = valueForColumn(primaryColumn) else { fatalError("\(self) doesn't have a primary key value") }
		return Statement(operation: .delete).filter(primaryColumn == primaryValue)
	}
	
	/// Create a count statement, which can be run against a database.
	/// Will run a count statement on all matched objects.
	///
	/// - Returns: A count statement instance.
	static func count() -> Statement<Self, Int> {
		return Statement(operation: .count)
	}
	
	/// Create a delete statement, which can be run against a database.
	/// Will run a delete statement on all matched objects.
	///
	/// - Parameters:
	///		- filter: A filter on which objects should be deleted.
	/// - Returns: A count statement instance.
	static func delete(_ filter : Expression) -> Statement<Self, Void> {
		return Statement(operation: .delete).filter(filter)
	}
	
	/// Create a read statement, which can be run against a database.
	/// Will run a read statement on all matched objects.
	///
	/// - Returns: A read statement instance.
	static func read() -> Statement<Self, [Self]> {
		return Statement(operation: .select(Self.tableLayout))
	}
	
	/// Will create a read statement, which can be run against a database.
	/// Will read an object with the specified id.
	///
	/// - Precondition:
	///		- self needs to have a value for its primary key
	/// - Returns: A read statement instance.
	static func byId(_ id : SqlValue) -> Statement<Self, SingleResult<Self>> {
		guard let primary = primaryColumn() else { fatalError("\(type(of: self)) have no primary key") }
		return Statement(operation: .select(Self.tableLayout))
			.filter(primary == id)
			.limit(1)
			.singleResult()
	}
}
