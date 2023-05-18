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
		groupAndReorganizeImagesByDamage(subset: "hold")
		groupAndReorganizeImagesByDamage(subset: "test")
		groupAndReorganizeImagesByDamage(subset: "train")
	}

	func groupAndReorganizeImagesByDamage(subset: String) {
		let fileManager = FileManager.default
		let subsetDirectory = dataDirectory.appending(path: subset)
		let labelDirectory = subsetDirectory.appending(path: "labels")
		let groupedDataDirectory = dataDirectory
			.appending(path: "..")
			.appending(path: "grouped-data")
		let imageDirectory = subsetDirectory.appending(path: "images")
		for labelFile in try! fileManager.contentsOfDirectory(atPath: labelDirectory.path(percentEncoded: false)) {
			let damage = calculateDamageLevel(from: labelDirectory.appending(path: labelFile).path(percentEncoded: false))
			let imageCopyDirectory = groupedDataDirectory
				.appending(path: subset)
				.appending(path: String(damage))
			try! fileManager.createDirectory(
				at: imageCopyDirectory,
				withIntermediateDirectories: true
			)
			let labelFileURL = URL(string: labelFile)
			let imageFile = labelFileURL!
				.deletingPathExtension()
				.appendingPathExtension("png")
				.path()
			try! fileManager.copyItem(
				at: imageDirectory.appending(path: imageFile),
				to: imageCopyDirectory
					.appending(path: imageFile)
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
