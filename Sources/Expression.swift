//
//  Expression.swift
//  Sqlable
//
//  Created by Ulrik Damm on 16/12/2015.
//  Copyright © 2015 Ufd.dk. All rights reserved.
//

import Foundation

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
