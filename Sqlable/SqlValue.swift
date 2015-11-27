//
//  SqlValue.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

public protocol SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws
}

extension Int : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_int64(handle, index, Int64(self)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension String : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_text(handle, index, self, -1, SqliteDatabase.SQLITE_TRANSIENT) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension NSDate : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_int64(handle, index, Int64(self.timeIntervalSince1970)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension Double : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_double(handle, index, self) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension Float : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_double(handle, index, Double(self)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension Bool : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_int(handle, index, Int32(self ? 1 : 0)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

public struct Null : NilLiteralConvertible {
	public init() {}
	public init(nilLiteral : Void) {}
}

extension Null : SqlValue {
	public func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_null(handle, index) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}
