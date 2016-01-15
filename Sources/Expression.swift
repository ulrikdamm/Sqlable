//
//  Expression.swift
//  Sqlable
//
//  Created by Ulrik Damm on 16/12/2015.
//  Copyright © 2015 Ufd.dk. All rights reserved.
//

import Foundation

public enum ColumnOrValue : SqlPrintable {
	case TableColumn(Column)
	case Value(SqlValue)
	
	var value : SqlValue? {
		if case .Value(let value) = self {
			return value
		} else {
			return nil
		}
	}
	
	var column : Column? {
		if case .TableColumn(let column) = self {
			return column
		} else {
			return nil
		}
	}
	
	public var sqlDescription : String {
		switch self {
		case .TableColumn(let column): return column.expressionName
		case .Value(_): return "?"
		}
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
	case Function(name : String, operands : [ColumnOrValue])
	
	public var sqlDescription : String {
		switch self {
		case .And(let lhs, let rhs): return "(\(lhs.sqlDescription)) and (\(rhs.sqlDescription))"
		case .Or(let lhs, let rhs): return "(\(lhs.sqlDescription)) or (\(rhs.sqlDescription))"
		case .Inverse(let expr): return "not (\(expr.sqlDescription))"
		case .LessThan(let lhs, _): return "(\(lhs.expressionName)) < ?"
		case .LessThanOrEqual(let lhs, _): return "(\(lhs.expressionName)) <= ?"
		case .GreaterThan(let lhs, _): return "(\(lhs.expressionName)) > ?"
		case .GreaterThanOrEqual(let lhs, _): return "(\(lhs.expressionName)) >= ?"
		case .EqualsValue(let column, is Null): return "\(column.expressionName) is null"
		case .EqualsValue(let column, _): return "\(column.expressionName) == ?"
		case .In(let column, let values):
			let placeholders = values.map { _ in "?" }.joinWithSeparator(", ")
			return "\(column.expressionName) in (\(placeholders))"
		case .Function(let name, let operands):
			let placeholders = operands.map { $0.sqlDescription }.joinWithSeparator(", ")
			return "\(name)(\(placeholders))"
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
		case .Function(_, let operands): return operands.flatMap { $0.value }
		}
	}
}

extension Column {
	public func contains(values : [SqlValue]) -> Expression {
		return .In(self, values)
	}
	
	public func like(string : String) -> Expression {
		return .Function(name: "like", operands: [.Value(string), .TableColumn(self)])
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
