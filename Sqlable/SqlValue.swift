//
//  SqlValue.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

protocol SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws
}

extension Int : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_int64(handle, index, Int64(self)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension String : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_text(handle, index, self, -1, SqliteDatabase.SQLITE_TRANSIENT) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension NSDate : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_int64(handle, index, Int64(self.timeIntervalSince1970)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension Double : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_double(handle, index, self) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension Float : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_double(handle, index, Double(self)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

extension Bool : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_int(handle, index, Int32(self ? 1 : 0)) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}

struct Null : NilLiteralConvertible {
	init() {}
	init(nilLiteral : Void) {}
}

extension Null : SqlValue {
	func bind(db : COpaquePointer, handle : COpaquePointer, index : Int32) throws {
		if sqlite3_bind_null(handle, index) != SQLITE_OK {
			try throwLastError(db)
		}
	}
}
