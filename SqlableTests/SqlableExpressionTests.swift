//
//  SqlableExpressionTests.swift
//  Sqlable
//
//  Created by Ulrik Damm on 15/01/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Sqlable

struct TestTable {
	let id : Int?
	let value1 : Int
	let value2 : String
}

extension TestTable : Sqlable {
	static let id = Column("id", .integer, PrimaryKey(autoincrement: true))
	static let value1 = Column("value_1", .integer)
	static let value2 = Column("value_2", .text)
	static let tableLayout = [id, value1, value2]
	
	func valueForColumn(_ column : Column) -> SqlValue? {
		switch column {
		case TestTable.id: return id
		case TestTable.value1: return value1
		case TestTable.value2: return value2
		case _: return nil
		}
	}
	
	init(row : ReadRow) throws {
		id = try row.get(TestTable.id)
		value1 = try row.get(TestTable.value1)
		value2 = try row.get(TestTable.value2)
	}
}

class SqliteExpressionTests : XCTestCase {
	let path = documentsPath() + "/test.sqlite"
	var db : SqliteDatabase!
	
	override func setUp() {
		_ = try? SqliteDatabase.deleteDatabase(at: path)
		db = try! SqliteDatabase(filepath: path)
		
		try! db.createTable(TestTable.self)
	}
	
	func testLikeOperator() {
		try! TestTable(id: 1, value1: 123, value2: "string").insert().run(db)
		try! TestTable(id: 2, value1: 123, value2: "ring").insert().run(db)
		try! TestTable(id: 3, value1: 123, value2: "last").insert().run(db)
		
		let results = try! TestTable.read().filter(TestTable.value2.like("%ing")).run(db)
		
		XCTAssert(results.contains { $0.id == 1 })
		XCTAssert(results.contains { $0.id == 2 })
		XCTAssert(!results.contains { $0.id == 3 })
		
		let results2 = try! TestTable.read().filter(TestTable.value2.like("%st%")).run(db)
		
		XCTAssert(results2.contains { $0.id == 1 })
		XCTAssert(!results2.contains { $0.id == 2 })
		XCTAssert(results2.contains { $0.id == 3 })
	}
	
	func testUppercaseFunction() {
		try! TestTable(id: 1, value1: 123, value2: "String").insert().run(db)
		XCTAssert(try! TestTable.read().filter(TestTable.value2.uppercase() == "STRING").run(db).first!.value2 == "String")
		XCTAssert(try! TestTable.read().filter(TestTable.value2.uppercase() == "String").run(db).first == nil)
	}
	
	func testLowercaseFunction() {
		try! TestTable(id: 1, value1: 123, value2: "String").insert().run(db)
		db.debug = true
		XCTAssert(try! TestTable.read().filter(TestTable.value2.lowercase() == "string").run(db).first!.value2 == "String")
		XCTAssert(try! TestTable.read().filter(TestTable.value2.lowercase() == "String").run(db).first == nil)
	}
}
