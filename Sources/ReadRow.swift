//
//  ReadRow.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

/// A row returned from the SQL database, from which you can read column values
public struct ReadRow {
	private let handle : COpaquePointer
	private let tablename : String
	
	let columnIndex : [String: Int]
	
	/// Create a read row from a SQLite handle
	public init(handle : COpaquePointer, tablename : String) {
		self.handle = handle
		self.tablename = tablename
		
		var columnIndex : [String: Int] = [:]
		
		for i in (0..<sqlite3_column_count(handle)) {
			let name = String.fromCString(sqlite3_column_name(handle, i))!
			columnIndex[name] = Int(i)
		}
		
		self.columnIndex = columnIndex
	}
	
	/// Read an integer value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The integer value for that column in the current row
	public func get(column : Column) throws -> Int {
		let index = try columnIndex(column)
		return Int(sqlite3_column_int64(handle, index))
	}
	
	/// Read a double value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The double value for that column in the current row
	public func get(column : Column) throws -> Double {
		let index = try columnIndex(column)
		return Double(sqlite3_column_double(handle, index))
	}
	
	/// Read a string value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The string value for that column in the current row
	public func get(column : Column) throws -> String {
		let index = try columnIndex(column)
		return String.fromCString(UnsafePointer<Int8>(sqlite3_column_text(handle, index)))!
	}
	
	/// Read a date value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The date value for that column in the current row
	public func get(column : Column) throws -> NSDate {
		let timestamp : Int = try get(column)
		return NSDate(timeIntervalSince1970: NSTimeInterval(timestamp))
	}
	
	/// Read a boolean value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The boolean value for that column in the current row
	public func get(column : Column) throws -> Bool {
		let index = try columnIndex(column)
		return sqlite3_column_int(handle, index) == 0 ? false : true
	}
	
	/// Read an optional integer value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The integer value for that column in the current row or nil if null
	public func get(column : Column) throws -> Int? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Int = try get(column)
			return i
		}
	}
	
	/// Read an optional double value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The double value for that column in the current row or nil if null
	public func get(column : Column) throws -> Double? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Double = try get(column)
			return i
		}
	}
	
	/// Read an optional string value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The string value for that column in the current row or nil if null
	public func get(column : Column) throws -> String? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : String = try get(column)
			return i
		}
	}
	
	/// Read an optional date value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The date value for that column in the current row or nil if null
	public func get(column : Column) throws -> NSDate? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : NSDate = try get(column)
			return i
		}
	}
	
	/// Read an optional boolean value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The boolean value for that column in the current row or nil if null
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
			throw SqlError.ReadError("Column \"\(column.name)\" not found on \(tablename)")
		}
		
		return Int32(index)
	}
}
