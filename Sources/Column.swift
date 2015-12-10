//
//  Column.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

public protocol ColumnOption : SqlPrintable {
	
}

public struct PrimaryKey : ColumnOption {
	public let autoincrement : Bool
	
	public init(autoincrement : Bool) {
		self.autoincrement = autoincrement
	}
	
	public var sqlDescription : String {
		return "primary key" + (autoincrement ? " autoincrement" : "")
	}
}

public enum Rule : SqlPrintable {
	case Ignore, Cascade, SetNull, SetDefault
	
	public var sqlDescription : String {
		switch self {
		case .Ignore: return "no action"
		case .Cascade: return "cascade"
		case .SetNull: return "set null"
		case .SetDefault: return "set default"
		}
	}
}

public struct ForeignKey<To : Sqlable> : ColumnOption, SqlPrintable {
	public let column : Column
	public let onDelete : Rule
	public let onUpdate : Rule
	
	public init(column : Column = Column("id", .Integer), onDelete : Rule = .Ignore, onUpdate : Rule = .Ignore) {
		self.column = column
		self.onDelete = onDelete
		self.onUpdate = onUpdate
	}
	
	public var sqlDescription : String {
		return "references \(To.tableName)(\(column.name)) on update \(onUpdate.sqlDescription) on delete \(onDelete.sqlDescription)"
	}
}

public struct Column : Equatable {
	public let name : String
	public let type : SqlType
	public let options : [ColumnOption]
	
	public init(_ name : String, _ type : SqlType, _ options : ColumnOption...) {
		self.name = name
		self.type = type
		self.options = options
	}
}

public func ==(lhs : Column, rhs : Column) -> Bool {
	return lhs.name == rhs.name && lhs.type == rhs.type
}

public func ~=(lhs : Column, rhs : Column) -> Bool {
	return lhs.name == rhs.name
}

extension Column : SqlPrintable {
	public var sqlDescription : String {
		var statement = "\(name) \(type.sqlDescription)"
		
		if options.count > 0 {
			let optionsString = options.map { $0.sqlDescription }.joinWithSeparator(" ")
			statement += " \(optionsString)"
		}
		
		return statement
	}
}

public indirect enum Expression : SqlPrintable {
	case And(Expression, Expression)
	case Or(Expression, Expression)
	case EqualsValue(Column, SqlValue)
	case Inverse(Expression)
	case LessThan(Column, SqlValue)
	case LessThanOrEqual(Column, SqlValue)
	case GreaterThan(Column, SqlValue)
	case GreaterThanOrEqual(Column, SqlValue)
	case In(Column, [SqlValue])
	
	public var sqlDescription : String {
		switch self {
		case .And(let lhs, let rhs): return "(\(lhs.sqlDescription)) and (\(rhs.sqlDescription))"
		case .Or(let lhs, let rhs): return "(\(lhs.sqlDescription)) or (\(rhs.sqlDescription))"
		case .Inverse(let expr): return "not (\(expr.sqlDescription))"
		case .LessThan(let lhs, _): return "(\(lhs.name)) < ?"
		case .LessThanOrEqual(let lhs, _): return "(\(lhs.name)) <= ?"
		case .GreaterThan(let lhs, _): return "(\(lhs.name)) > ?"
		case .GreaterThanOrEqual(let lhs, _): return "(\(lhs.name)) >= ?"
		case .EqualsValue(let column, is Null): return "\(column.name) is null"
		case .EqualsValue(let column, _): return "\(column.name) == ?"
		case .In(let column, let values):
			let placeholders = values.map { _ in "?" }.joinWithSeparator(", ")
			return "\(column.name) in (\(placeholders))"
		}
	}
	
	var values : [SqlValue] {
		switch self {
		case .And(let lhs, let rhs): return lhs.values + rhs.values
		case .Or(let lhs, let rhs): return lhs.values + rhs.values
		case .Inverse(let expr): return expr.values
		case .EqualsValue(_, is Null): return []
		case .EqualsValue(_, let value): return [value]
		case .LessThan(_, let rhs): return [rhs]
		case .LessThanOrEqual(_, let rhs): return [rhs]
		case .GreaterThan(_, let rhs): return [rhs]
		case .GreaterThanOrEqual(_, let rhs): return [rhs]
		case .In(_, let rhs): return rhs
		}
	}
}

public func contains(lhs : Column, _ rhs : [SqlValue]) -> Expression {
	return .In(lhs, rhs)
}

infix operator ∈ {}

public func ∈(lhs : Column, rhs : [SqlValue]) -> Expression {
	return .In(lhs, rhs)
}

public func ==(lhs : Column, rhs : SqlValue) -> Expression {
	return .EqualsValue(lhs, rhs)
}

public func !=(lhs : Column, rhs : SqlValue) -> Expression {
	return .Inverse(.EqualsValue(lhs, rhs))
}

public func <(lhs : Column, rhs : SqlValue) -> Expression {
	return .LessThan(lhs, rhs)
}

public func <=(lhs : Column, rhs : SqlValue) -> Expression {
	return .LessThanOrEqual(lhs, rhs)
}

public func >(lhs : Column, rhs : SqlValue) -> Expression {
	return .GreaterThan(lhs, rhs)
}

public func >=(lhs : Column, rhs : SqlValue) -> Expression {
	return .GreaterThanOrEqual(lhs, rhs)
}

public func &&(lhs : Expression, rhs : Expression) -> Expression {
	return .And(lhs, rhs)
}

public func ||(lhs : Expression, rhs : Expression) -> Expression {
	return .Or(lhs, rhs)
}

public prefix func !(value : Expression) -> Expression {
	return .Inverse(value)
}

public prefix func !(column : Column) -> Expression {
	return column == Null()
}
