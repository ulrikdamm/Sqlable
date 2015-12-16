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
