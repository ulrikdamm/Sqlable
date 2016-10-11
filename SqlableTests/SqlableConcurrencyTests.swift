//
//  SqlableConcurrencyTests.swift
//  Sqlable
//
//  Created by Ulrik Damm on 21/01/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Sqlable

class SqliteConcurrencyTests : XCTestCase {
	let path = documentsPath() + "/test.sqlite"
	var db : SqliteDatabase!
	let background = DispatchQueue.global()
	
	override func setUp() {
		_ = try? SqliteDatabase.deleteDatabase(at: path)
		db = try! SqliteDatabase(filepath: path)
		
		try! db.createTable(TestTable.self)
	}
	
	func testChildCreation() {
		let child = try! db.createChild()
		try! TestTable(id: nil, value1: 1, value2: "Hi!").insert().run(child)
		
		XCTAssert(try! TestTable.read().run(child).count == 1)
		XCTAssert(try! TestTable.read().run(db).count == 1)
	}
	
	func testBackgroundedChild() {
		let child = try! db.createChild()
		
		let lock = DispatchSemaphore(value: 0)
		
		background.async {
			try! TestTable(id: nil, value1: 1, value2: "Hi!").insert().run(child)
			lock.signal()
		}
		
		lock.wait(timeout: DispatchTime.distantFuture)
		
		XCTAssert(try! TestTable.read().run(child).count == 1)
		XCTAssert(try! TestTable.read().run(db).count == 1)
	}
	
	func testConcurrentChild() {
		let child = try! db.createChild()
		
		let lock = DispatchSemaphore(value: 0)
		
		background.async {
			for i in (0..<100) {
				try! TestTable(id: nil, value1: i, value2: "background").insert().run(child)
			}
			
			lock.signal()
		}
		
		for i in (0..<100) {
			try! TestTable(id: nil, value1: i, value2: "foreground").insert().run(db)
		}
		
		lock.wait(timeout: DispatchTime.distantFuture)
		
		XCTAssert(try! TestTable.read().run(child).count == 200)
		XCTAssert(try! TestTable.read().run(db).count == 200)
	}
	
	func testChildUpdateNotifications() {
		let child = try! db.createChild()
		
		var didCall = false
		
		db.observe(.insert, on: TestTable.self) { _ in
			didCall = true
		}
		
		background.async {
			try! TestTable(id: nil, value1: 1, value2: "background").insert().run(child)
		}
		
		RunLoop.main.run(until: Date().addingTimeInterval(1))
		
		XCTAssert(didCall)
	}
	
	func testChildUpdatesInTransactions() {
		let child = try! db.createChild()
		
		var didCallUpdate = false
		var didCallBackground = false
		
		db.observe(.insert, on: TestTable.self) { id in
			XCTAssert(id == 3)
			didCallUpdate = true
		}
		
		try! db.beginTransaction()
		
		try! TestTable(id: 1, value1: 1, value2: "foreground").insert().run(db)
		
		background.async {
			didCallBackground = true
			
			try! child.transaction { child in
				try! TestTable(id: 3, value1: 3, value2: "background").insert().run(child)
			}
		}
		
		sleep(1)
		XCTAssert(didCallBackground)
		XCTAssert(!didCallUpdate)
		
		try! TestTable(id: 2, value1: 2, value2: "foreground").insert().run(db)
		
		try! db.rollbackTransaction()
		
		RunLoop.main.run(until: Date().addingTimeInterval(1))
		
		XCTAssert(didCallUpdate)
		XCTAssert(try! TestTable.read().run(db).count == 1)
	}
}
