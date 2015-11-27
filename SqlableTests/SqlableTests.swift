//
//  SqlableTests.swift
//  SqlableTests
//
//  Created by Ulrik Damm on 26/10/2015.
//  Copyright © 2015 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Sqlable

func documentsPath() -> String {
	return NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
}

struct User {
	let id : Int?
	var name : String
	var avatarURL : String?
	var groupId : Int
}

struct Group {
	let id : Int
}

extension Group : Sqlable {
	init(row : ReadRow<Group>) throws {
		id = row.get("id")
	}
	
	static let tableLayout : [Column] = [
		Column("id", .Integer, PrimaryKey(autoincrement: true))
	]
	
	func valueForColumn(column : Column) -> SqlValue? {
		switch column.name {
		case "id": return .Integer(id)
		case _: return nil
		}
	}
}

extension User : Sqlable {
	init(row : ReadRow<User>) throws {
		id = row.get("id")
		name = row.get("name")
		avatarURL = row.get("avatar_url")
		groupId = row.get("group_id")
	}
	
	static let tableLayout : [Column] = [
		Column("id", .Integer, PrimaryKey(autoincrement: true)),
		Column("name", .Text),
		Column("avatar_url", .Nullable(.Text)),
		Column("group_id", .Integer, ForeignKey<Group>())
	]
	
	func valueForColumn(column : Column) -> SqlValue? {
		switch column.name {
		case "id": return id.flatMap { .Integer($0) } ?? nil
		case "name": return .Text(name)
		case "avatar_url": return avatarURL.flatMap { .Text($0) } ?? .Null
		case "group_id": return .Integer(groupId)
		case _: return nil
		}
	}
}

class SqliteDatabaseTests: XCTestCase {
	let path = documentsPath() + "/test.sqlite"
	var db : SqliteDatabase!
	
	override func setUp() {
		_ = try? NSFileManager.defaultManager().removeItemAtPath(path)
		db = try! SqliteDatabase(filepath: path)
	}
	
	func testExecute() {
		try! db.execute("create table test (id integer)")
	}
	
	func testCreateTable() {
		try! db.createTable(User.self)
	}
	
	func testInsert() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user.insertStatement().run(db)
	}
	
	func testDelete() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user.insertStatement().run(db)
		
		try! user.deleteStatement().run(db)
		try! group.deleteStatement().run(db)
	}
	
	func testCount() {
		try! db.createTable(Group.self)
		try! Group(id: 0).insertStatement().run(db)
		try! Group(id: 1).insertStatement().run(db)
		
		let count = try! Group.countStatement().run(db)
		XCTAssert(count == 2)
	}
	
	func testRead() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user1 = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		let user2 = User(id: nil, name: "Luz", avatarURL: "", groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user1.insertStatement().run(db)
		try! user2.insertStatement().run(db)
		
		let users = try! User.readStatement().run(db)
		XCTAssert(users.count == 2)
		
		XCTAssert(users[0].id == 1)
		XCTAssert(users[0].name == "Ulrik")
		XCTAssert(users[0].avatarURL == nil)
		XCTAssert(users[0].groupId == 0)
		
		XCTAssert(users[1].id == 2)
		XCTAssert(users[1].name == "Luz")
		XCTAssert(users[1].avatarURL == "")
		XCTAssert(users[1].groupId == 0)
	}
	
	func testFilter() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user1 = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		let user2 = User(id: nil, name: "Luz", avatarURL: "", groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user1.insertStatement().run(db)
		try! user2.insertStatement().run(db)
		
		let users = try! User.readStatement().filter("name", .Equal, .Text("Luz")).run(db)
		XCTAssert(users.count == 1)
		
		XCTAssert(users[0].id == 2)
		XCTAssert(users[0].name == "Luz")
		XCTAssert(users[0].avatarURL == "")
		XCTAssert(users[0].groupId == 0)
	}
	
	func testOrder() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user1 = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		let user2 = User(id: nil, name: "Luz", avatarURL: "", groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user1.insertStatement().run(db)
		try! user2.insertStatement().run(db)
		
		let users = try! User.readStatement().orderBy("name").run(db)
		XCTAssert(users.count == 2)
		
		XCTAssert(users[0].id == 2)
		XCTAssert(users[0].name == "Luz")
		XCTAssert(users[0].avatarURL == "")
		XCTAssert(users[0].groupId == 0)
		
		XCTAssert(users[1].id == 1)
		XCTAssert(users[1].name == "Ulrik")
		XCTAssert(users[1].avatarURL == nil)
		XCTAssert(users[1].groupId == 0)
	}
	
	func testLimit() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user1 = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		let user2 = User(id: nil, name: "Luz", avatarURL: "", groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user1.insertStatement().run(db)
		try! user2.insertStatement().run(db)
		
		let users = try! User.readStatement().orderBy("name", .Desc).limit(1).run(db)
		XCTAssert(users.count == 1)
		
		XCTAssert(users[0].id == 1)
		XCTAssert(users[0].name == "Ulrik")
		XCTAssert(users[0].avatarURL == nil)
		XCTAssert(users[0].groupId == 0)
	}
	
	func testUpdate() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		var user1 = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		let user2 = User(id: nil, name: "Luz", avatarURL: "", groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user1.insertStatement().run(db)
		try! user2.insertStatement().run(db)
		
		user1.avatarURL = "http://"
		try! user1.updateStatement([Filter("id", .Equal, .Integer(1))]).run(db)
		
		let users = try! User.readStatement().orderBy("name").run(db)
		XCTAssert(users.count == 2)
		
		XCTAssert(users[0].id == 2)
		XCTAssert(users[0].name == "Luz")
		XCTAssert(users[0].avatarURL == "")
		XCTAssert(users[0].groupId == 0)
		
		XCTAssert(users[1].id == 1)
		XCTAssert(users[1].name == "Ulrik")
		XCTAssert(users[1].avatarURL == "http://")
		XCTAssert(users[1].groupId == 0)
	}
	
	func testLimitedCount() {
		try! db.createTable(User.self)
		try! db.createTable(Group.self)
		
		let group = Group(id: 0)
		let user1 = User(id: nil, name: "Ulrik", avatarURL: nil, groupId: 0)
		let user2 = User(id: nil, name: "Luz", avatarURL: "", groupId: 0)
		
		try! group.insertStatement().run(db)
		try! user1.insertStatement().run(db)
		try! user2.insertStatement().run(db)
		
		let count = try! User.countStatement().filter("name", .Equal, .Text("Luz")).run(db)
		XCTAssert(count == 1)
	}
}
