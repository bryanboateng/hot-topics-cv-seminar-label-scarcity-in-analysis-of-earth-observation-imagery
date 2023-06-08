import ArgumentParser
import Foundation

@main
struct DataCreator: ParsableCommand {

	@Argument(help: "directory", transform: URL.init(fileURLWithPath:))
	var dataDirectory: URL

	mutating func validate() throws {
		try validateDirectoryExists(atURL: dataDirectory)
	}

	private func validateDirectoryExists(atURL url: URL) throws {
		let path = url.path
		guard FileManager.default.fileExists(atPath: path) else {
			throw ValidationError("Folder does not exist at \(path)")
		}
	}

	func run() {
		//		groupAndReorganizeImagesByDamage(subset: "hold")
		groupAndReorganizeImagesByDamage(subset: "test")
		groupAndReorganizeImagesByDamage(subset: "train")
	}

	func groupAndReorganizeImagesByDamage(subset: String) {
		let fileManager = FileManager.default
		let subsetDirectory = dataDirectory.appendingPathComponent(subset, isDirectory: true)
		let labelDirectory = subsetDirectory.appendingPathComponent("labels", isDirectory: true)
		let groupedDataDirectory = dataDirectory
			.appendingPathComponent("..", isDirectory: true)
			.appendingPathComponent("grouped-data", isDirectory: true)
		let imageDirectory = subsetDirectory.appendingPathComponent("images", isDirectory: true)
		for labelFile in try! fileManager.contentsOfDirectory(atPath: labelDirectory.path) {
			guard labelFile.contains("_post") else { continue }
			let damage = calculateDamageLevel(from: labelDirectory.appendingPathComponent(labelFile).path)
			let imageCopyDirectory = groupedDataDirectory
				.appendingPathComponent(subset, isDirectory: true)
				.appendingPathComponent(String(damage), isDirectory: true)
			try! fileManager.createDirectory(
				at: imageCopyDirectory,
				withIntermediateDirectories: true
			)
			let labelFileURL = URL(string: labelFile)
			let imageFile = labelFileURL!
				.deletingPathExtension()
				.appendingPathExtension("png")
				.path
			try! fileManager.copyItem(
				at: imageDirectory.appendingPathComponent(imageFile),
				to: imageCopyDirectory
					.appendingPathComponent(imageFile)
			)
		}
	}

	func calculateDamageLevel(from path: String) -> Int {
		let json = try! JSONSerialization.jsonObject(
			with: try! Data(contentsOf: URL(fileURLWithPath: path)),
			options: []
		) as! [String: Any]
		let features = json["features"] as! [String: [[String: Any]]]
		let lngLatFeatures = features["lng_lat"]!
		guard !lngLatFeatures.isEmpty else { return 0 }
		//		lngLatFeatures.compactMap { feature in
		//			<#code#>
		//		}
		let averageDamageLevel: Float = lngLatFeatures.reduce(0.0) { partialResult, feature in
			let properties = feature["properties"] as! [String: String]
			let numericDamageLevel = {
				switch properties["subtype"] {
				case "un-classified":
					return 0
				case "no-damage":
					return 1
				case "minor-damage":
					return 2
				case "major-damage":
					return 3
				case "destroyed":
					return 4
				default:
					fatalError("Unknown subtype")
				}
			}()
			return partialResult + Float(numericDamageLevel)
		} / Float(lngLatFeatures.count)
		return Int(averageDamageLevel.rounded())
	}
}
