import SwiftUI

struct Folder: Identifiable {
  let id = UUID()
  let name: String
  let url: URL
}

struct ContentView: View {
  @State private var folders: [Folder] = []

  var body: some View {
    NavigationView {
      List(folders) { folder in
        NavigationLink(destination: AlbumView(folder: folder)) {
          Text(folder.name)
        }
      }
      .navigationTitle("Albums")
      .onAppear {
        loadFolders()
      }
    }
  }

  func loadFolders() {
    var request = URLRequest(url: Config.url)
    request.httpMethod = "PROPFIND"
    request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
    request.setValue("1", forHTTPHeaderField: "Depth")

    let login = "\(Config.username):\(Config.password)"
    let loginData = login.data(using: .utf8)!
    let base64Login = loginData.base64EncodedString()
    request.setValue("Basic \(base64Login)", forHTTPHeaderField: "Authorization")

    URLSession.shared.dataTask(with: request) { data, _, _ in
      guard let data = data,
            let xml = String(data: data, encoding: .utf8) else { return }

      let matches = xml.components(separatedBy: "<d:href>")
        .compactMap { $0.components(separatedBy: "</d:href>").first }
        .filter { $0.hasSuffix("/") && !$0.contains("._") && !$0.hasSuffix("/Music/") }

    print(matches)

      let items = matches.map {
        let decoded = $0.removingPercentEncoding ?? $0
          let name = decoded.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/").last ?? "?"
        let fullURL = URL(string: "https://cloud.ag.uy" + decoded)!
        return Folder(name: name, url: fullURL)
      }

      DispatchQueue.main.async {
        folders = Array(items)
      }
    }.resume()
  }
}
