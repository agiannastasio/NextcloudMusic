import Foundation

struct Config {
  static var url: URL {
    URL(string: values["nextcloudURL"] ?? "")!
  }

  static var username: String {
    values["username"] ?? ""
  }

  static var password: String {
    values["password"] ?? ""
  }

  private static var values: [String: String] = {
    guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
          let data = try? Data(contentsOf: url),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] ??
                      (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    else { return [:] }

    return plist.reduce(into: [:]) {
      if let value = $1.value as? String {
        $0[$1.key] = value
      } else if let dict = $1.value as? [String: String] {
        dict.forEach { $0[$0.key] = $0.value }
      }
    }
  }()
}
