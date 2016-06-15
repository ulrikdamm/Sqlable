//
//  SqlableUpdateCallbackTests.swift
//  Sqlable
//
//  Created by Ulrik Damm on 16/01/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Sqlable

class SqliteUpdateCallbackTests : XCTestCase {
	let path = documentsPath() + "/test.sqlite"
	var db : SqliteDatabase!
	
	override func setUp() {
		_ = try? SqliteDatabase.deleteDatabase(at: path)
		db = try! SqliteDatabase(filepath: path)
		
		try! db.createTable(TestTable.self)
	}
	
	func testTransaction() {
		var inTransaction = false
		var updateCalls = 0
		
		db.didUpdate = { table, row, change in
			XCTAssert(inTransaction == false)
			updateCalls += 1
		}
		
		try! db.transaction { db in
			inTransaction = true
			try TestTable(id: 1, value1: 0, value2: "").insert().run(db)
			try TestTable(id: 2, value1: 0, value2: "").insert().run(db)
			try TestTable(id: 2, value1: 0, value2: "hi!").update().run(db)
			inTransaction = false
		}
		
		XCTAssert(updateCalls == 3)
	}
	
	func testTransactionRollback() {
		var inTransaction = false
		var updateCalls = 0
		
		db.didUpdate = { table, row, change in
			XCTAssert(inTransaction == false)
			updateCalls += 1
		}
		
		try! db.beginTransaction()
		inTransaction = true
		try! TestTable(id: 1, value1: 0, value2: "").insert().run(db)
		try! TestTable(id: 2, value1: 0, value2: "").insert().run(db)
		try! TestTable(id: 2, value1: 0, value2: "hi!").update().run(db)
		inTransaction = false
		try! db.rollbackTransaction()
		
		XCTAssert(updateCalls == 0)
	}
	
	func testNestedTransactions() {
		var inTransaction = false
		var updateCalls = 0
		
		db.didUpdate = { table, row, change in
			XCTAssert(inTransaction == false)
			updateCalls += 1
		}
		
		try! db.transaction { db in
			inTransaction = true
			try TestTable(id: 1, value1: 0, value2: "").insert().run(db)
			try db.transaction { db in
				try TestTable(id: 2, value1: 0, value2: "").insert().run(db)
			}
			try TestTable(id: 2, value1: 0, value2: "hi!").update().run(db)
			inTransaction = false
		}
		
		XCTAssert(updateCalls == 3)
	}
	
	func testNestedTransactionRollback() {
		var inTransaction = false
		var updateCalls = 0
		
		db.didUpdate = { table, row, change in
			XCTAssert(inTransaction == false)
			updateCalls += 1
		}
		
		try! db.transaction { db in
			inTransaction = true
			try TestTable(id: 1, value1: 0, value2: "").insert().run(db)
			try db.beginTransaction()
			try TestTable(id: 2, value1: 0, value2: "").insert().run(db)
			try db.rollbackTransaction()
			try TestTable(id: 1, value1: 0, value2: "hi!").update().run(db)
			inTransaction = false
		}
		
		XCTAssert(updateCalls == 2)
	}
	
	func testDidUpdateInsert() {
		var didCall = false
		
		db.didUpdate = { table, row, change in
			XCTAssert(table == TestTable.tableName)
			XCTAssert(row == 2)
			XCTAssert(change == .insert)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall)
	}
	
	func testDidUpdateUpdate() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		db.didUpdate = { table, row, change in
			XCTAssert(table == TestTable.tableName)
			XCTAssert(row == 2)
			XCTAssert(change == .update)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").update().run(db)
		
		XCTAssert(didCall)
	}
	
	func testDidUpdateDelete() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		db.didUpdate = { table, row, change in
			XCTAssert(table == TestTable.tableName)
			XCTAssert(row == 2)
			XCTAssert(change == .delete)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").delete().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerInsert() {
		var didCall = false
		
		db.observe(.insert, on: TestTable.self) { _ in
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerUpdate() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		db.observe(.update, on: TestTable.self) { id in
			XCTAssert(didCall == false)
			XCTAssert(id == 2)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").update().run(db)
		try! TestTable(id: 3, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerUpdateSpecific() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		try! TestTable(id: 3, value1: 1, value2: "").insert().run(db)
		
		db.observe(.update, on: TestTable.self, id: 2) { id in
			XCTAssert(didCall == false)
			XCTAssert(id == 2)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").update().run(db)
		try! TestTable(id: 3, value1: 1, value2: "hi!").update().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerDelete() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		db.observe(.delete, on: TestTable.self) { id in
			XCTAssert(didCall == false)
			XCTAssert(id == 2)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "").delete().run(db)
		try! TestTable(id: 3, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerDeleteSpecific() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		try! TestTable(id: 3, value1: 1, value2: "").insert().run(db)
		
		db.observe(.delete, on: TestTable.self, id: 2) { id in
			XCTAssert(didCall == false)
			XCTAssert(id == 2)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").update().run(db)
		try! TestTable(id: 2, value1: 1, value2: "hi!").delete().run(db)
		try! TestTable(id: 3, value1: 1, value2: "hi!").delete().run(db)
		
		XCTAssert(didCall)
	}
	
	func testMultipleEventHandlers() {
		var didCall = 0
		
		db.observe(.insert, on: TestTable.self, id: 1) { id in
			XCTAssert(id == 1)
			didCall += 1
		}
		
		db.observe(.insert, on: TestTable.self, id: 2) { id in
			XCTAssert(id == 2)
			didCall += 1
		}
		
		try! TestTable(id: 1, value1: 1, value2: "").insert().run(db)
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall == 2)
	}
	
	func testEventHandlerWithoutSpecificChange() {
		var didCall = 0
		
		db.observe(on: TestTable.self) { _ in
			didCall += 1
		}
		
		try! TestTable(id: 1, value1: 1, value2: "").insert().run(db)
		try! TestTable(id: 1, value1: 1, value2: "Hi!").update().run(db)
		try! TestTable(id: 1, value1: 1, value2: "Hi!").delete().run(db)
		
		XCTAssert(didCall == 3)
	}
	
	func testDeregisterEventHandler() {
		var didCall = 0
		
		let id = db.observe(on: TestTable.self) { _ in
			didCall += 1
		}
		
		try! TestTable(id: 1, value1: 1, value2: "").insert().run(db)
		
		db.removeObserver(id)
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall == 1)
	}
}
