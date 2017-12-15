// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Sqlable",
	dependencies: [
		.package(url: "https://github.com/vapor-community/csqlite", from: "1.0.0")
	],
	targets: [
		.target(name: "Sqlable", dependencies: ["csqlite"])
	]
)
