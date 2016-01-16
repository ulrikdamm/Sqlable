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
		_ = try? NSFileManager.defaultManager().removeItemAtPath(path)
		db = try! SqliteDatabase(filepath: path)
		
		try! db.createTable(TestTable.self)
	}
	
	func testDidUpdateInsert() {
		var didCall = false
		
		db.didUpdate = { table, row, change in
			XCTAssert(table == TestTable.tableName)
			XCTAssert(row == 2)
			XCTAssert(change == .Insert)
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
			XCTAssert(change == .Update)
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
			XCTAssert(change == .Delete)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").delete().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerInsert() {
		var didCall = false
		
		db.on(.Insert, to: TestTable.self) { _ in
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		XCTAssert(didCall)
	}
	
	func testEventHandlerUpdate() {
		var didCall = false
		
		try! TestTable(id: 2, value1: 1, value2: "").insert().run(db)
		
		db.on(.Update, to: TestTable.self) { id in
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
		
		db.on(.Update, to: TestTable.self, id: 2) { id in
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
		
		db.on(.Delete, to: TestTable.self) { id in
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
		
		db.on(.Delete, to: TestTable.self, id: 2) { id in
			XCTAssert(didCall == false)
			XCTAssert(id == 2)
			didCall = true
		}
		
		try! TestTable(id: 2, value1: 1, value2: "hi!").update().run(db)
		try! TestTable(id: 2, value1: 1, value2: "hi!").delete().run(db)
		try! TestTable(id: 3, value1: 1, value2: "hi!").delete().run(db)
		
		XCTAssert(didCall)
	}
}
