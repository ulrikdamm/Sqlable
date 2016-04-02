//
//  SqlType.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

/// A SQL type
public enum SqlType : Equatable {
	/// An integer
	case Integer
	/// A double
	case Real
	/// A string
	case Text
	/// A date
	case Date
	/// A boolean
	case Boolean
	/// A nullable SQL type
	indirect case Nullable(SqlType)
}

public func ==(lhs : SqlType, rhs : SqlType) -> Bool {
	switch (lhs, rhs) {
	case (.Integer, .Integer): fallthrough
	case (.Real, .Real): fallthrough
	case (.Text, .Text): fallthrough
	case (.Date, .Date): fallthrough
	case (.Boolean, .Boolean): return true
	case (.Nullable(let t1), .Nullable(let t2)) where t1 == t2: return true
	case _: return false
	}
}

extension SqlType : SqlPrintable {
	public var sqlDescription : String {
		switch self {
		case .Integer: return "integer not null"
		case .Real: return "double not null"
		case .Text: return "text not null"
		case .Date: return "timestamp not null"
		case .Boolean: return "integer not null"
		case .Nullable(.Integer): return "integer"
		case .Nullable(.Real): return "double"
		case .Nullable(.Text): return "text"
		case .Nullable(.Date): return "timestamp"
		case .Nullable(.Boolean): return "integer"
		case .Nullable(.Nullable(_)): fatalError("Nice try")
		}
	}
}
