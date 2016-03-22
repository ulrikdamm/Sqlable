//
//  Statement.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

public enum Operation {
	case Select([Column])
	case Insert([(Column, SqlValue)])
	case Update([(Column, SqlValue)])
	case Count
	case Delete
}

public enum OnConflict {
	case Abort
	case Ignore
	case Replace
}

public enum SingleResult<T> {
	case NoResult
	case Result(T)
	
	var value : T? {
		switch self {
		case .Result(let value): return value
		case .NoResult: return nil
		}
	}
}

public struct Statement<T : Sqlable, Return> {
	let operation : Operation
	let filterBy : Expression?
	private let orderBy : [Order]
	let limit : Int?
	let single : Bool
	let onConflict : OnConflict
	
	public init(operation : Operation) {
		self.operation = operation
		self.filterBy = nil
		self.orderBy = []
		self.limit = nil
		self.single = false
		self.onConflict = .Abort
	}
	
	private init(operation : Operation, filter : Expression? = nil, orderBy : [Order] = [], limit : Int? = nil, single : Bool = false, onConflict : OnConflict = .Abort) {
		self.operation = operation
		self.filterBy = filter
		self.orderBy = orderBy
		self.limit = limit
		self.single = single
		self.onConflict = onConflict
	}
	
	public func filter(expression : Expression) -> Statement {
		guard filterBy == nil else { fatalError("You can only add one filter to an expression. Combine filters with &&") }
		
		return Statement(operation: operation, filter: expression, orderBy: orderBy, limit: limit, single: single, onConflict: onConflict)
	}
	
	public func orderBy(column : Column, _ direction : Order.Direction = .Asc) -> Statement {
		let order = Order(column, direction)
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy + [order], limit: limit, single: single, onConflict: onConflict)
	}
	
	public func limit(limit : Int) -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: single, onConflict: onConflict)
	}
	
	public func singleResult() -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: true, onConflict: onConflict)
	}
	
	public func ignoreOnConflict() -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: single, onConflict: .Ignore)
	}
	
	var sqlDescription : String {
		var sql : [String]
		
		let conflict : String
		switch onConflict {
		case .Abort: conflict = "or abort"
		case .Ignore: conflict = "or ignore"
		case .Replace: conflict = "or replace"
		}
		
		switch operation {
		case .Select(let columns):
			let columnNames = columns.map { $0.name }.joinWithSeparator(", ")
			sql = ["select \(columnNames) from \(T.tableName)"]
		case .Insert(let ops):
			let columnNames = ops.map { column, value in column.name }.joinWithSeparator(", ")
			let values = ops.map { _ in "?" }.joinWithSeparator(", ")
			sql = ["insert \(conflict) into \(T.tableName) (\(columnNames)) values (\(values))"]
		case .Update(let ops):
			let values = ops.map { column, _ in "\(column.name) = ?" }.joinWithSeparator(", ")
			sql = ["update \(conflict) \(T.tableName) set \(values)"]
		case .Count:
			sql = ["select count(*) from \(T.tableName)"]
		case .Delete:
			sql = ["delete from \(T.tableName)"]
		}
		
		if let filter = filterBy {
			sql.append("where " + filter.sqlDescription)
		}
		
		if orderBy.count > 0 {
			sql.append("order by " + orderBy.map { $0.sqlDescription }.joinWithSeparator(", "))
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
		
		if let filter = filterBy {
			values += filter.values
		}
		
		return values
	}
	
	public func run(db : SqliteDatabase) throws -> Return {
		return try db.run(self) as! Return
	}
}

public struct Order : SqlPrintable {
	public enum Direction {
		case Asc
		case Desc
	}
	
	let column : Column
	let direction : Direction
	
	public init(_ column : Column, _ direction : Direction) {
		self.column = column
		self.direction = direction
	}
	
	public var sqlDescription : String {
		return "\(column.name) " + (direction == .Desc ? "desc" : "")
	}
}
