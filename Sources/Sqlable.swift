//
//  Sqlable.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

public protocol TableConstraint : SqlPrintable {}

public struct Unique : TableConstraint {
	public let columns : [Column]
	
	public init(_ columns : [Column]) {
		self.columns = columns
	}
	
	public init(_ columns : Column...) {
		self.columns = columns
	}
	
	public var sqlDescription : String {
		let columnList = columns.map { $0.name }.joinWithSeparator(", ")
		return "constraint unique (\(columnList)) on conflict abort"
	}
}

public protocol Sqlable {
	static var tableName : String { get }
	static var tableLayout : [Column] { get }
	static var tableConstraints : [TableConstraint] { get }
	
	func valueForColumn(column : Column) -> SqlValue?
	init(row : ReadRow<Self>) throws
}

public extension Sqlable {
	static var tableName : String {
		let typeName = "table_\(Mirror(reflecting: self).subjectType)"
		return typeName
			.substringToIndex(typeName.endIndex.advancedBy(-5))
			.lowercaseString
	}
	
	static var tableConstraints : [TableConstraint] {
		return []
	}
	
	static func createTable() -> String {
		let columns = tableLayout.map { $0.sqlDescription }
		let constraints = tableConstraints.map { $0.sqlDescription }
		let fields = (columns + constraints).joinWithSeparator(", ")
		return "create table if not exists \(tableName) (\(fields))"
	}
	
	static func columnForName(name : String) -> Column? {
		return Self.tableLayout.filter { column in column.name == name }.first
	}
	
	static func primaryColumn() -> Column? {
		let index = Self.tableLayout.indexOf { $0.options.contains { $0 is PrimaryKey } }
		return index.flatMap { Self.tableLayout[$0] }
	}
	
	@warn_unused_result
	func update() -> Statement<Self, Void> {
		guard let primaryColumn = Self.primaryColumn() else { fatalError("\(self) doesn't have a primary key") }
		guard let primaryValue = valueForColumn(primaryColumn) else { fatalError("\(self) doesn't have a primary key value") }
		let values = Self.tableLayout.flatMap { column in valueForColumn(column).flatMap { (column, $0) } }
		return Statement(operation: .Update(values)).filter(primaryColumn == primaryValue)
	}
	
	@warn_unused_result
	func insert() -> Statement<Self, Int> {
		let values = Self.tableLayout.flatMap { column in valueForColumn(column).flatMap { (column, $0) } }
		return Statement(operation: .Insert(values))
	}
	
	@warn_unused_result
	func delete() -> Statement<Self, Void> {
		guard let primaryColumn = Self.primaryColumn() else { fatalError("\(self) doesn't have a primary key") }
		guard let primaryValue = valueForColumn(primaryColumn) else { fatalError("\(self) doesn't have a primary key value") }
		return Statement(operation: .Delete).filter(primaryColumn == primaryValue)
	}
	
	@warn_unused_result
	static func count() -> Statement<Self, Int> {
		return Statement(operation: .Count)
	}
	
	@warn_unused_result
	static func delete(filter : Expression) -> Statement<Self, Void> {
		return Statement(operation: .Delete).filter(filter)
	}
	
	@warn_unused_result
	static func read() -> Statement<Self, [Self]> {
		return Statement(operation: .Select(Self.tableLayout))
	}
	
	@warn_unused_result
	static func byId(id : SqlValue) -> Statement<Self, Self?> {
		guard let primary = primaryColumn() else { fatalError("\(self.dynamicType) have no primary key") }
		return Statement(operation: .Select(Self.tableLayout))
			.filter(primary == id)
			.limit(1)
			.singleResult()
	}
}
