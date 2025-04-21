import SwiftUI

struct AlbumView: View {
  let folder: Folder
  @State private var tracks: [URL] = []

  var body: some View {
    List(tracks, id: \.self) { track in
      Text(track.lastPathComponent)
    }
    .navigationTitle(folder.name)
    .onAppear {
      loadTracks()
    }
  }

  func loadTracks() {
    var request = URLRequest(url: folder.url)
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
        .filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".m4a") || $0.hasSuffix(".ogg") }
        .map { URL(string: "https://cloud.ag.uy" + ($0.removingPercentEncoding ?? $0))! }

      DispatchQueue.main.async {
        tracks = matches
      }
    }.resume()
  }
}
