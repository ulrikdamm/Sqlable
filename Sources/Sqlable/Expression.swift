//
//  Expression.swift
//  Sqlable
//
//  Created by Ulrik Damm on 16/12/2015.
//  Copyright © 2015 Ufd.dk. All rights reserved.
//

import Foundation

/// A value which can either be a column reference or a primitive value
public enum ColumnOrValue : SqlPrintable {
	case tableColumn(Column)
	case Value(SqlValue)
	
	var value : SqlValue? {
		if case .Value(let value) = self {
			return value
		} else {
			return nil
		}
	}
	
	var column : Column? {
		if case .tableColumn(let column) = self {
			return column
		} else {
			return nil
		}
	}
	
	public var sqlDescription : String {
		switch self {
		case .tableColumn(let column): return column.expressionName
		case .Value(_): return "?"
		}
	}
}

/// A SQL expression for filters
public indirect enum Expression : SqlPrintable {
	/// Both expressions must be true
	case and(Expression, Expression)
	/// Either expression must be true
	case or(Expression, Expression)
	/// A column must have a specific value
	case equalsValue(Column, SqlValue)
	/// An expression must be false
	case inverse(Expression)
	/// A column must have a value less than the specified
	case lessThan(Column, SqlValue)
	/// A column must have a value less than or equal to the specified
	case lessThanOrEqual(Column, SqlValue)
	/// A column must have a value greater than the specified
	case greaterThan(Column, SqlValue)
	/// A column must have a value greater than or equal to the specified
	case greaterThanOrEqual(Column, SqlValue)
	/// A column must have a value in the specified list of values
	case `in`(Column, [SqlValue])
	/// Access a raw SQL function and run it with the given operands
	case function(name : String, operands : [ColumnOrValue])
	
	public var sqlDescription : String {
		switch self {
		case .and(let lhs, let rhs): return "(\(lhs.sqlDescription)) and (\(rhs.sqlDescription))"
		case .or(let lhs, let rhs): return "(\(lhs.sqlDescription)) or (\(rhs.sqlDescription))"
		case .inverse(let expr): return "not (\(expr.sqlDescription))"
		case .lessThan(let lhs, _): return "(\(lhs.expressionName)) < ?"
		case .lessThanOrEqual(let lhs, _): return "(\(lhs.expressionName)) <= ?"
		case .greaterThan(let lhs, _): return "(\(lhs.expressionName)) > ?"
		case .greaterThanOrEqual(let lhs, _): return "(\(lhs.expressionName)) >= ?"
		case .equalsValue(let column, is Null): return "\(column.expressionName) is null"
		case .equalsValue(let column, _): return "\(column.expressionName) == ?"
		case .in(let column, let values):
			let placeholders = values.map { _ in "?" }.joined(separator: ", ")
			return "\(column.expressionName) in (\(placeholders))"
		case .function(let name, let operands):
			let placeholders = operands.map { $0.sqlDescription }.joined(separator: ", ")
			return "\(name)(\(placeholders))"
		}
	}
	
	var values : [SqlValue] {
		switch self {
		case .and(let lhs, let rhs): return lhs.values + rhs.values
		case .or(let lhs, let rhs): return lhs.values + rhs.values
		case .inverse(let expr): return expr.values
		case .equalsValue(_, is Null): return []
		case .equalsValue(_, let value): return [value]
		case .lessThan(_, let rhs): return [rhs]
		case .lessThanOrEqual(_, let rhs): return [rhs]
		case .greaterThan(_, let rhs): return [rhs]
		case .greaterThanOrEqual(_, let rhs): return [rhs]
		case .in(_, let rhs): return rhs
        case .function(_, let operands): return operands.compactMap { $0.value }
		}
	}
}

extension Column {
	/// A column must have a value in the specified list of values (for use in filters) 
	public func contains(_ values : [SqlValue]) -> Expression {
		return .in(self, values)
	}
	
	/// A string column must have a value 'like' the given string (see the SQLite documentation for 'like') (for use in filters)
	public func like(_ string : String) -> Expression {
		return .function(name: "like", operands: [.Value(string), .tableColumn(self)])
	}
}

/// A column must have a value in the specified list of values (for use in filters)
public func contains(_ lhs : Column, _ rhs : [SqlValue]) -> Expression {
	return .in(lhs, rhs)
}

infix operator ∈

/// A column must have a value in the specified list of values
public func ∈(lhs : Column, rhs : [SqlValue]) -> Expression {
	return .in(lhs, rhs)
}

/// A column must have a specific value
public func ==(lhs : Column, rhs : SqlValue) -> Expression {
	return .equalsValue(lhs, rhs)
}

/// A column must not have a specific value
public func !=(lhs : Column, rhs : SqlValue) -> Expression {
	return .inverse(.equalsValue(lhs, rhs))
}

/// A column must have a value less than the specified
public func <(lhs : Column, rhs : SqlValue) -> Expression {
	return .lessThan(lhs, rhs)
}

/// A column must have a value less than or equal to the specified
public func <=(lhs : Column, rhs : SqlValue) -> Expression {
	return .lessThanOrEqual(lhs, rhs)
}

/// A column must have a value greater than the specified
public func >(lhs : Column, rhs : SqlValue) -> Expression {
	return .greaterThan(lhs, rhs)
}

/// A column must have a value greater than or equal to the specified
public func >=(lhs : Column, rhs : SqlValue) -> Expression {
	return .greaterThanOrEqual(lhs, rhs)
}

/// Both expressions must be true
public func &&(lhs : Expression, rhs : Expression) -> Expression {
	return .and(lhs, rhs)
}

/// Either expression must be true
public func ||(lhs : Expression, rhs : Expression) -> Expression {
	return .or(lhs, rhs)
}

/// An expression must be false
public prefix func !(value : Expression) -> Expression {
	return .inverse(value)
}

/// An column must be null
public prefix func !(column : Column) -> Expression {
	return column == Null()
}
