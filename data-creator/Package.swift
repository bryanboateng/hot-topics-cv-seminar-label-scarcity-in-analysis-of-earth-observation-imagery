// swift-tools-version: 5.7

import PackageDescription

let package = Package(
	name: "DataCreator",
	platforms: [.macOS(.v13)],
	products: [
		.executable(
			name: "DataCreator",
			targets: ["DataCreator"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
	],
	targets: [
		.executableTarget(
			name: "DataCreator",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			],
			resources: [
			]
		),
	]
)
