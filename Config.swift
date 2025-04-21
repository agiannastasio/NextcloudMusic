//
//  Config.swift
//  NextcloudMusic
//
//  Created by agustin on 21/4/25.
//


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
          let rawPlist = try? PropertyListSerialization.propertyList(from: data, format: nil)
    else { return [:] }

    if let dict = rawPlist as? [String: String] {
      return dict
    }

    if let outerDict = rawPlist as? [String: Any],
       let nested = outerDict["Root"] as? [String: String] {
      return nested
    }

    return [:]
  }()
}
