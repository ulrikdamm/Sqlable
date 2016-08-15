//
//  ReadRow.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

/// A row returned from the SQL database, from which you can read column values
public struct ReadRow<T : Sqlable> {
	private let handle : OpaquePointer
	let type = T.self
	
	let columnIndex : [String: Int]
	
	/// Create a read row from a SQLite handle
	public init(handle : OpaquePointer) {
		self.handle = handle
		
		var columnIndex : [String: Int] = [:]
		
		for i in (0..<sqlite3_column_count(handle)) {
			let name = String(validatingUTF8: sqlite3_column_name(handle, i))!
			columnIndex[name] = Int(i)
		}
		
		self.columnIndex = columnIndex
	}
	
	/// Read an integer value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The integer value for that column in the current row
	public func get(_ column : Column) throws -> Int {
		let index = try columnIndex(column)
		return Int(sqlite3_column_int64(handle, index))
	}
	
	/// Read a double value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The double value for that column in the current row
	public func get(_ column : Column) throws -> Double {
		let index = try columnIndex(column)
		return Double(sqlite3_column_double(handle, index))
	}
	
	/// Read a string value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The string value for that column in the current row
	public func get(_ column : Column) throws -> String {
		let index = try columnIndex(column)
		return String(cString: sqlite3_column_text(handle, index))
	}
	
	/// Read a date value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The date value for that column in the current row
	public func get(_ column : Column) throws -> Date {
		let timestamp : Int = try get(column)
		return Date(timeIntervalSince1970: TimeInterval(timestamp))
	}
	
	/// Read a boolean value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The boolean value for that column in the current row
	public func get(_ column : Column) throws -> Bool {
		let index = try columnIndex(column)
		return sqlite3_column_int(handle, index) == 0 ? false : true
	}
	
	/// Read an optional integer value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The integer value for that column in the current row or nil if null
	public func get(_ column : Column) throws -> Int? {
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
	public func get(_ column : Column) throws -> Double? {
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
	public func get(_ column : Column) throws -> String? {
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
	public func get(_ column : Column) throws -> Date? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Date = try get(column)
			return i
		}
	}
	
	/// Read an optional boolean value for a column
	/// 
	///	- Parameters:
	///		- column: A column from a Sqlable type
	/// - Returns: The boolean value for that column in the current row or nil if null
	public func get(_ column : Column) throws -> Bool? {
		let index = try columnIndex(column)
		if sqlite3_column_type(handle, index) == SQLITE_NULL {
			return nil
		} else {
			let i : Bool = try get(column)
			return i
		}
	}
	
	private func columnIndex(_ column : Column) throws -> Int32 {
		guard let index = columnIndex[column.name] else {
			throw SqlError.readError("Column \"\(column.name)\" not found on \(type)")
		}
		
		return Int32(index)
	}
}
