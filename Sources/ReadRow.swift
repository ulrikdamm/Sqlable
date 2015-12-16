//
//  ReadRow.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

public struct ReadRow<T : Sqlable> {
	private let handle : COpaquePointer
	let type = T.self
	
	let columnIndex : [String: Int]
	
	public init(handle : COpaquePointer) {
		self.handle = handle
		
		var columnIndex : [String: Int] = [:]
		
		for i in (0..<sqlite3_column_count(handle)) {
			let name = String.fromCString(sqlite3_column_name(handle, i))!
			columnIndex[name] = Int(i)
		}
		
		self.columnIndex = columnIndex
	}
	
	public func get(column : Column) throws -> Int {
		let index = try columnIndex(column)
		return Int(sqlite3_column_int64(handle, index))
	}
	
	public func get(column : Column) throws -> Double {
		let index = try columnIndex(column)
		return Double(sqlite3_column_double(handle, index))
	}
	
	public func get(column : Column) throws -> String {
		let index = try columnIndex(column)
		return String.fromCString(UnsafePointer<Int8>(sqlite3_column_text(handle, index)))!
	}
	
	public func get(column : Column) throws -> NSDate {
		let timestamp : Int = try get(column)
		return NSDate(timeIntervalSince1970: NSTimeInterval(timestamp))
	}
	
	public func get(column : Column) throws -> Bool {
		let index = try columnIndex(column)
		return sqlite3_column_int(handle, index) == 0 ? false : true
	}
	
	public func get(column : Column) throws -> Int? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Int = try get(column)
			return i
		}
	}
	
	public func get(column : Column) throws -> Double? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Double = try get(column)
			return i
		}
	}
	
	public func get(column : Column) throws -> String? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : String = try get(column)
			return i
		}
	}
	
	public func get(column : Column) throws -> NSDate? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : NSDate = try get(column)
			return i
		}
	}
	
	public func get(column : Column) throws -> Bool? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Bool = try get(column)
			return i
		}
	}
	
	private func columnIndex(column : Column) throws -> Int32 {
		guard let index = columnIndex[column.name] else {
			throw SqlError.ReadError("Column \"\(column.name)\" not found on \(type)")
		}
		
		return Int32(index)
	}
}
