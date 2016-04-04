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
	let background = dispatch_get_global_queue(0, 0)
	
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
		
		let lock = dispatch_semaphore_create(0)
		
		dispatch_async(background) {
			try! TestTable(id: nil, value1: 1, value2: "Hi!").insert().run(child)
			dispatch_semaphore_signal(lock)
		}
		
		dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER)
		
		XCTAssert(try! TestTable.read().run(child).count == 1)
		XCTAssert(try! TestTable.read().run(db).count == 1)
	}
	
	func testConcurrentChild() {
		let child = try! db.createChild()
		
		let lock = dispatch_semaphore_create(0)
		
		dispatch_async(background) {
			for i in (0..<100) {
				try! TestTable(id: nil, value1: i, value2: "background").insert().run(child)
			}
			
			dispatch_semaphore_signal(lock)
		}
		
		for i in (0..<100) {
			try! TestTable(id: nil, value1: i, value2: "foreground").insert().run(db)
		}
		
		dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER)
		
		XCTAssert(try! TestTable.read().run(child).count == 200)
		XCTAssert(try! TestTable.read().run(db).count == 200)
	}
	
	func testChildUpdateNotifications() {
		let child = try! db.createChild()
		
		var didCall = false
		
		db.observe(.Insert, on: TestTable.self) { _ in
			didCall = true
		}
		
		dispatch_async(background) {
			try! TestTable(id: nil, value1: 1, value2: "background").insert().run(child)
		}
		
		NSRunLoop.main().run(until: NSDate().addingTimeInterval(1))
		
		XCTAssert(didCall)
	}
	
	func testChildUpdatesInTransactions() {
		let child = try! db.createChild()
		
		var didCallUpdate = false
		var didCallBackground = false
		
		db.observe(.Insert, on: TestTable.self) { id in
			XCTAssert(id == 3)
			didCallUpdate = true
		}
		
		try! db.beginTransaction()
		
		try! TestTable(id: 1, value1: 1, value2: "foreground").insert().run(db)
		
		dispatch_async(background) {
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
		
		NSRunLoop.main().run(until: NSDate().addingTimeInterval(1))
		
		XCTAssert(didCallUpdate)
		XCTAssert(try! TestTable.read().run(db).count == 1)
	}
}
