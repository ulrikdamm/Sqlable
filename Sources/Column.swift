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
		var sql = ["primary key"]
		
		if autoincrement {
			sql.append("autoincrement")
		}
		
		return sql.joinWithSeparator(" ")
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
		var sql = ["references \(To.tableName)(\(column.name))"]
		
		if onUpdate != .Ignore {
			sql.append("on update \(onUpdate.sqlDescription)")
		}
		
		if onDelete != .Ignore {
			sql.append("on delete \(onDelete.sqlDescription)")
		}
		
		return sql.joinWithSeparator(" ")
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
		var statement = ["\(name) \(type.sqlDescription)"]
		
		for option in options {
			statement.append(option.sqlDescription)
		}
		
		return statement.joinWithSeparator(" ")
	}
}
