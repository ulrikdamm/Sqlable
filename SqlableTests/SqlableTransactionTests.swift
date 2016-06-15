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
		_ = try? SqliteDatabase.deleteDatabase(at: path)
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
		let transaction = try! db.beginTransaction()
		try! Table(id: nil, value1: 1, value2: 1).insert().run(db)
		try! Table(id: nil, value1: 1, value2: 2).insert().run(db)
		try! db.rollbackTransaction(transaction)
		
		XCTAssert(try! Table.count().run(db) == 0)
	}
	
	func testTransactionErrorRollback() {
		var constraintViolation = false
		
		do {
			try db.transaction { db in
				try Table(id: nil, value1: 1, value2: 1).insert().run(db)
				try Table(id: nil, value1: 1, value2: 1).insert().run(db)
			}
		} catch SqlError.sqliteConstraintViolation(_) {
			constraintViolation = true
		} catch let error {
			XCTAssert(false, "Error: \(error)")
		}
		
		XCTAssert(constraintViolation)
		XCTAssert(try! Table.count().run(db) == 0)
	}
	
	func testNestedTransaction() {
		try! db.transaction { db in
			try db.transaction { db in
				try Table(id: nil, value1: 1, value2: 1).insert().run(db)
				try Table(id: nil, value1: 1, value2: 2).insert().run(db)
			}
		}
		
		XCTAssert(try! Table.count().run(db) == 2)
	}
	
	func testManyNestedTransaction() {
		try! db.transaction { db in
			try db.transaction { db in
				try db.transaction { db in
					try db.transaction { db in
						try db.transaction { db in
							try db.transaction { db in
								try db.transaction { db in
									try db.transaction { db in
										try db.transaction { db in
											try Table(id: nil, value1: 1, value2: 1).insert().run(db)
											try Table(id: nil, value1: 1, value2: 2).insert().run(db)
										}
									}
								}
							}
						}
					}
				}
			}
		}
		
		XCTAssert(try! Table.count().run(db) == 2)
	}
	
	func testNestedTransactionRollback() {
		try! db.transaction { db in
			let transaction = try! db.beginTransaction()
			try! Table(id: nil, value1: 1, value2: 1).insert().run(db)
			try! Table(id: nil, value1: 1, value2: 2).insert().run(db)
			try! db.rollbackTransaction(transaction)
			
			try! Table(id: nil, value1: 1, value2: 3).insert().run(db)
			try! Table(id: nil, value1: 1, value2: 4).insert().run(db)
		}
		
		XCTAssert(try! Table.count().run(db) == 2)
		XCTAssert(try! Table.count().filter(Table.value2 > 2).run(db) == 2)
	}
	
	func testMultipleLevelRollback() {
		try! db.beginTransaction()
		try! Table(id: nil, value1: 1, value2: 1).insert().run(db)
		try! Table(id: nil, value1: 1, value2: 2).insert().run(db)
		
		let transaction2 = try! db.beginTransaction()
		try! Table(id: nil, value1: 1, value2: 3).insert().run(db)
		try! Table(id: nil, value1: 1, value2: 4).insert().run(db)
		
		try! db.beginTransaction()
		try! Table(id: nil, value1: 1, value2: 5).insert().run(db)
		try! Table(id: nil, value1: 1, value2: 6).insert().run(db)
		
		try! db.rollbackTransaction(transaction2)
		
		XCTAssert(try! Table.count().run(db) == 2)
	}
	
	func testInnerTransactionErrorHandling() {
		try! db.transaction { db in
			do {
				try db.transaction { db in
					try Table(id: nil, value1: 1, value2: 2).insert().run(db)
					
					try db.transaction { db in
						try Table(id: nil, value1: 1, value2: 1).insert().run(db)
						try Table(id: nil, value1: 1, value2: 1).insert().run(db)
					}
					
					try Table(id: nil, value1: 1, value2: 3).insert().run(db)
				}
			} catch SqlError.sqliteConstraintViolation(_) {
				
			} catch let error {
				throw error
			}
			
			try! Table(id: nil, value1: 1, value2: 4).insert().run(db)
		}
		
		XCTAssert(try! Table.count().run(db) == 1)
		XCTAssert(try! Table.count().filter(Table.value2 == 4).run(db) == 1)
	}
}
