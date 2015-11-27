//
//  Statement.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

public enum Operation {
	case Select([Column])
	case Insert([(Column, SqlValue)])
	case InsertOrReplace([(Column, SqlValue)])
	case Update([(Column, SqlValue)])
	case Count
	case Delete
}

public struct Statement<T : Sqlable, Return> {
	let operation : Operation
	let filterBy : Expression?
	private let orderBy : [Order]
	let limit : Int?
	let single : Bool
	
	public init(operation : Operation) {
		self.operation = operation
		self.filterBy = nil
		self.orderBy = []
		self.limit = nil
		self.single = false
	}
	
	private init(operation : Operation, filter : Expression? = nil, orderBy : [Order] = [], limit : Int? = nil, single : Bool = false) {
		self.operation = operation
		self.filterBy = filter
		self.orderBy = orderBy
		self.limit = limit
		self.single = single
	}
	
	public func filter(expression : Expression) -> Statement {
		guard filterBy == nil else { fatalError("You can only add one filter to an expression. Combine filters with &&") }
		
		return Statement(operation: operation, filter: expression, orderBy: orderBy, limit: limit, single: single)
	}
	
	public func orderBy(column : Column, _ direction : Order.Direction = .Asc) -> Statement {
		let order = Order(column, direction)
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy + [order], limit: limit, single: single)
	}
	
	public func limit(limit : Int) -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: single)
	}
	
	public func singleResult() -> Statement {
		return Statement(operation: operation, filter: filterBy, orderBy: orderBy, limit: limit, single: true)
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
		case .InsertOrReplace(let ops):
			let columnNames = ops.map { column, value in column.name }.joinWithSeparator(", ")
			let values = ops.map { _ in "?" }.joinWithSeparator(", ")
			sql = ["insert or replace into \(T.tableName) (\(columnNames)) values (\(values))"]
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
		case .InsertOrReplace(let ops): values += ops.map { column, value in value }
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
