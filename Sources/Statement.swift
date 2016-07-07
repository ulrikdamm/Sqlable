//
//  Statement.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

/// A SQL operation
public enum Operation {
	/// Read the specified columns from rows in a table
	case select([Column])
	/// Insert a new row with the specified value for each column
	case insert([(Column, SqlValue)])
	/// Update a row with the specified value for each updated column
	case update([(Column, SqlValue)])
	/// Count rows
	case count
	/// Delete rows
	case delete
}

/// What to do in case of conflict
public enum OnConflict {
	/// Abort the operation and fail with an error
	case abort
	/// Ignore the operation
	case ignore
	/// Perform the operation anyway
	case replace
}

/// A single result, which might not exist (really just an optional)
public enum SingleResult<T> {
	case noResult
	case result(T)
	
	public var value : T? {
		switch self {
		case .result(let value): return value
		case .noResult: return nil
		}
	}
}

/// A statement that can be run against a database
/// T: The table to run the statement on
/// Return: The return type
public struct Statement<T : Sqlable, Return> {
	let operation : Operation
	let filterBy : Expression?
	private let orderBy : [Order]
	let limit : Int?
	let single : Bool
	let onConflict : OnConflict
	
	/// Create a statement for a certain operation
	public init(operation : Operation) {
		self.operation = operation
		self.filterBy = nil
		self.orderBy = []
		self.limit = nil
		self.single = false
		self.onConflict = .abort
	}
	
	private init(operation : Operation, filter : Expression? = nil, orderBy : [Order] = [], limit : Int? = nil, single : Bool = false, onConflict : OnConflict = .abort) {
		self.operation = operation
		self.filterBy = filter
		self.orderBy = orderBy
		self.limit = limit
		self.single = single
		self.onConflict = onConflict
	}
	
	/// Add an expression filter to the statement
	@warn_unused_result
	public func filter(_ expression : Expression) -> Statement {
		guard filterBy == nil else { fatalError("You can only add one filter to an expression. Combine filters with &&") }
		
		return Statement(operation: operation, filter: expression, orderBy: orderBy, limit: limit, single: single, onConflict: onConflict)
	}
	
	/// Add an ordering to the statement
	@warn_unused_result
	public func orderBy(_ column : Column, _ direction : Order.Direction = .asc) -> Statement {
		let order = Order(column, direction)
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy + [order], limit: limit, single: single, onConflict: onConflict)
	}
	
	/// Add a row return limit to the statement
	@warn_unused_result
	public func limit(_ limit : Int) -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: single, onConflict: onConflict)
	}
	
	/// Only select a single row
	@warn_unused_result
	public func singleResult() -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: true, onConflict: onConflict)
	}
	
	/// Ignore the operation if there are any conflicts caused by the statement
	@warn_unused_result
	public func ignoreOnConflict() -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: single, onConflict: .ignore)
	}
    
    /// Replace row if there are any conflicts caused by the statement
    public func replaceOnConflict() -> Statement {
        return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: single, onConflict: .replace)
    }
	
	var sqlDescription : String {
		var sql : [String]
		
		let conflict : String
		switch onConflict {
		case .abort: conflict = "or abort"
		case .ignore: conflict = "or ignore"
		case .replace: conflict = "or replace"
		}
		
		switch operation {
		case .select(let columns):
			let columnNames = columns.map { $0.name }.joined(separator: ", ")
			sql = ["select \(columnNames) from \(T.tableName)"]
		case .insert(let ops):
			let columnNames = ops.map { column, value in column.name }.joined(separator: ", ")
			let values = ops.map { _ in "?" }.joined(separator: ", ")
			sql = ["insert \(conflict) into \(T.tableName) (\(columnNames)) values (\(values))"]
		case .update(let ops):
			let values = ops.map { column, _ in "\(column.name) = ?" }.joined(separator: ", ")
			sql = ["update \(conflict) \(T.tableName) set \(values)"]
		case .count:
			sql = ["select count(*) from \(T.tableName)"]
		case .delete:
			sql = ["delete from \(T.tableName)"]
		}
		
		if let filter = filterBy {
			sql.append("where " + filter.sqlDescription)
		}
		
		if orderBy.count > 0 {
			sql.append("order by " + orderBy.map { $0.sqlDescription }.joined(separator: ", "))
		}
		
		if let limit = limit {
			sql.append("limit \(limit)")
		}
		
		return sql.joined(separator: " ")
	}
	
	var values : [SqlValue] {
		var values : [SqlValue] = []
		
		switch operation {
		case .select(_): break
		case .insert(let ops): values += ops.map { column, value in value }
		case .update(let ops): values += ops.map { column, value in value }
		case .count: break
		case .delete: break
		}
		
		if let filter = filterBy {
			values += filter.values
		}
		
		return values
	}
	
	/// Run the statement against a database instance
	public func run(_ db : SqliteDatabase) throws -> Return {
		return try db.run(self) as! Return
	}
}

/// Ordering of selected rows
public struct Order : SqlPrintable {
	/// Ordering direction
	public enum Direction {
		/// Order ascending
		case asc
		/// Order descending
		case desc
	}
	
	let column : Column
	let direction : Direction
	
	/// Create an ordering
	/// 
	///	- Parameters:
	///		- column: The column to order by
	///		- direction: The direction to order in
	public init(_ column : Column, _ direction : Direction) {
		self.column = column
		self.direction = direction
	}
	
	public var sqlDescription : String {
		return "\(column.name) " + (direction == .desc ? "desc" : "")
	}
}
