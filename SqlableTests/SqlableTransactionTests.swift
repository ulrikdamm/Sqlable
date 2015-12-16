//
//  SqlableTransactionTests.swift
//  Sqlable
//
//  Created by Ulrik Damm on 16/12/2015.
//  Copyright © 2015 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Sqlable

class SqliteTransactionTests: XCTestCase {
	let path = documentsPath() + "/test.sqlite"
	var db : SqliteDatabase!
	
	override func setUp() {
		_ = try? NSFileManager.defaultManager().removeItemAtPath(path)
		db = try! SqliteDatabase(filepath: path)
		
		try! db.createTable(Table.self)
	}
	
	func testTransaction() {
		try! db.transaction { db in
			try Table(id: nil, value1: 1, value2: 1).insert().run(db)
			try Table(id: nil, value1: 1, value2: 2).insert().run(db)
		}
		
		XCTAssert(try! Table.count().run(db) == 2)
	}
	
	func testTransactionReturn() {
		let count = try! db.transaction { db -> Int in
			try Table(id: nil, value1: 1, value2: 1).insert().run(db)
			try Table(id: nil, value1: 1, value2: 2).insert().run(db)
			return try Table.count().run(db)
		}
		
		XCTAssert(count == 2)
	}
	
	func testTransactionRollback() {
		try! db.beginTransaction()
		try! Table(id: nil, value1: 1, value2: 1).insert().run(db)
		try! Table(id: nil, value1: 1, value2: 2).insert().run(db)
		try! db.rollbackTransaction()
		
		XCTAssert(try! Table.count().run(db) == 0)
	}
	
	func testTransactionErrorRollback() {
		var constraintViolation = false
		
		do {
			try db.transaction { db in
				try Table(id: nil, value1: 1, value2: 1).insert().run(db)
				try Table(id: nil, value1: 1, value2: 1).insert().run(db)
			}
		} catch SqlError.SqliteConstraintViolation(_) {
			constraintViolation = true
		} catch let error {
			XCTAssert(false, "Error: \(error)")
		}
		
		XCTAssert(constraintViolation)
		XCTAssert(try! Table.count().run(db) == 0)
	}
}